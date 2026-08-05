# Event-driven, coalesced absorb-bar repaint — design

**Date:** 2026-07-13
**Status:** approved (pending spec review)
**Standard:** Ka0s WoW Addon Standard — no deviation (see §7)

## Problem

The absorb bar currently repaints on a fixed-interval repeating ticker
(`modules/Timer.lua`, `updateInterval`, default 1.0s). The `UNIT_ABSORB_AMOUNT_CHANGED`
event *is* registered (`core/AbsorbTracker.lua`) but only drives a gated debug print — it
does **not** trigger a repaint. So the visible bar is poll-driven:

- **Idle waste:** the bar repaints every `updateInterval` even when nothing changed and the
  player has no shield.
- **Latency:** a real absorb change can lag up to `updateInterval` (1s default) before it shows.

This is the opposite of what the event exists for. Blizzard's own unit-frame absorb overlays
are driven purely by `UNIT_ABSORB_AMOUNT_CHANGED` + `UNIT_MAXHEALTH` with no polling.

## Goal

Repaint the bar **on the events that actually change what it displays**, coalesced through a
short throttle so a combat burst can't cause a repaint storm. Result:

| Scenario | Old (poll) | New (event + throttle) |
|---|---|---|
| Idle / no shield | repaints every 1s | **zero repaints** |
| Absorb changes | up to 1s late | ≤ `throttleWindow` late (0.1s) |
| Heavy combat burst | 1 repaint/interval | ≤ 1 repaint / `throttleWindow` |

Pure event-driven — **no backup/safety ticker** (decision below).

## Non-goals

- Heal absorbs (`UnitGetTotalHealAbsorbs` / `UNIT_HEAL_ABSORB_AMOUNT_CHANGED`) — this bar reads
  `UnitGetTotalAbsorbs` (damage absorbs only), so heal-absorb events are out of scope.
- Changing the bar's appearance, position, or `UpdateAbsorbBar`'s read/paint logic.

## Design decisions (resolved during brainstorming)

1. **Update model:** event-driven with a coalescing throttle. **No backup ticker** — pure
   event-driven. Rationale: Blizzard trusts these same events with no polling; the input set
   (`UnitGetTotalAbsorbs` + `UnitHealthMax`) is complete for what we display; a periodic no-op
   read buys little. Accepted risk: if an expected event is ever dropped, the bar can hold a
   stale value until the next absorb/max-health event or a manual `/at`. No auto-self-heal.
2. **Throttle edge:** **trailing-edge**. First event schedules a repaint `throttleWindow` later;
   all events inside the window collapse into that one repaint. Latency ≤ `throttleWindow`.
3. **Settings surface:** one setting, `throttleWindow` (replaces `updateInterval`).

## Architecture & data flow

```
UNIT_ABSORB_AMOUNT_CHANGED ┐
UNIT_MAXHEALTH             ├─► NS.RequestRepaint() ─► [trailing throttle: ≤1 / throttleWindow] ─► UpdateAbsorbBar()
PLAYER_ENTERING_WORLD      ┘
OnEnable (login)           ──────────────────── direct ─────────────────────────────────────────► UpdateAbsorbBar()
OnProfileChanged           ──────────────────── direct ─────────────────────────────────────────► UpdateAbsorbBar()
```

`UpdateAbsorbBar` (`modules/Display.lua`) is **unchanged**. It already self-guards on `hidden`
and `testHoldUntil` and reads both `UnitGetTotalAbsorbs` + `UnitHealthMax`, so every path simply
funnels into it. Immediate one-shot paints (login, profile change) call it directly rather than
through the throttle, so there is no startup latency.

## Component changes

### `modules/Timer.lua` — becomes the coalescing throttle

Remove entirely: `updateTicker`, `currentTickerInterval`, `NS.RestartUpdateTicker`,
`NS.ResetTickerInterval`.

Add:

```lua
local addonName, NS = ...

-- Coalescing repaint scheduler (Ka0s standard library-stack-§1 — one-shot AceTimer, same pattern as
-- settings/Widgets.lua). Repaints are event-driven; this trailing-edge throttle caps the repaint
-- rate to one per throttleWindow so a burst of UNIT_ABSORB_AMOUNT_CHANGED events during combat
-- can't cause a repaint storm. Idle = zero repaints; there is no polling fallback.

local pending

function NS.RequestRepaint()
    if pending then return end            -- a repaint is already queued; coalesce into it
    pending = NS.addon:ScheduleTimer(function()
        pending = nil
        NS.UpdateAbsorbBar()
    end, NS.GetSetting("throttleWindow"))
end
```

- `pending` guards re-arming: while a repaint is queued, further requests are no-ops.
- After the timer fires it clears `pending`, so the next event re-arms cleanly.
- Reads `throttleWindow` live at schedule time — no `onChange`/restart plumbing needed.

### `core/AbsorbTracker.lua` — wire events to `RequestRepaint`

- `OnEnable`:
  - **Remove** `NS.RestartUpdateTicker(true)` (line 29).
  - Keep the direct `NS.UpdateAbsorbBar()` (line 28) for the immediate login paint.
  - **Add** `self:RegisterEvent("UNIT_MAXHEALTH", "OnMaxHealthChanged")`.
- `OnAbsorbChanged`: keep the existing gated debug print, **add** `NS.RequestRepaint()` when
  `unit == "player"`.
- **New** `OnMaxHealthChanged(_, unit)`: `if unit == "player" then NS.RequestRepaint() end`.
- `OnEnterWorld`: change the direct `NS.UpdateAbsorbBar()` to `NS.RequestRepaint()`.
- `NS.OnProfileChanged`:
  - **Remove** `NS.ResetTickerInterval()` and `NS.RestartUpdateTicker(true)` (lines 58–59).
  - Keep `NS.UpdateAbsorbBar()` (line 57) for the immediate repaint on profile switch.

`UNIT_MAXHEALTH` and `UNIT_ABSORB_AMOUNT_CHANGED` are registered as general events (not
`RegisterUnitEvent`) and filtered by `unit == "player"`, matching the file's existing convention.

### `settings/General.lua` + `defaults/Profile.lua` — replace the setting

`defaults/Profile.lua`:
- Remove `updateInterval = 1.0`.
- Add `throttleWindow = 0.1`.

`settings/General.lua` — the `updateInterval` schema entry becomes:
```lua
{
    path    = "throttleWindow",
    page    = "general",
    group   = "Performance",
    order   = 10,
    type    = "number",
    label   = "Update throttle (in sec)",
    desc    = "Fastest the bar repaints during a burst of changes. Lower = snappier but more CPU.",
    default = flatDefaults.throttleWindow,
    min = 0.05, max = 1, step = 0.05, fmt = "%.2f sec",
    solo    = true,
    -- no onChange: RequestRepaint reads throttleWindow live at schedule time.
}
```
Remove the old `onChange = function() NS.RestartUpdateTicker() end`.

### `core/Database.lua` — migration `schemaVersion` 1 → 2

Add an idempotent, version-gated step to `NS:RunMigrations` at the existing
`if g.schemaVersion < 2 then ... end` placeholder:

```lua
if g.schemaVersion < 2 then
    if profile then profile.updateInterval = nil end   -- retire the old poll-interval key
    g.schemaVersion = 2
end
```

- `throttleWindow` does **not** need setting here: the runner's existing v1 backfill loop iterates
  `NS.flatDefaults` on every init and adds any missing profile key, so once `throttleWindow` is in
  `flatDefaults` it is written to the active profile automatically. The v2 step's only job is to
  *delete* the now-orphaned `updateInterval` (the backfill loop never removes keys).
- Scope matches the existing runner: it operates on the **active** profile (`NS.db.profile`), not
  every stored profile. A stale `updateInterval` left in some *other* saved profile is an unused
  key — harmless and consistent with how v1 behaves.

The old `updateInterval` value is **deliberately not carried over** — its magnitude (a poll
interval, default 1.0s) is meaningless as a throttle window and would produce a sluggish 1s
repaint latency. Everyone starts on the 0.1s default.

## Testing

Green gate stays `lua tests/run.lua` + `luacheck .` (0/0).

- **`tests/wow_mock.lua`:** make the `ScheduleTimer` mock record scheduled callbacks (id, delay,
  fn) into an inspectable table and expose a helper to "fire" them, instead of the current
  `function() return {} end` no-op. Keep `CancelTimer` a no-op (no longer exercised by Timer.lua,
  but AceTimer internals may still touch it).
- **New throttle test (`tests/run.lua`, `modules/Timer.lua` loaded):**
  1. N consecutive `NS.RequestRepaint()` calls schedule **exactly one** timer (coalescing).
  2. Firing that timer calls `UpdateAbsorbBar` once and clears `pending`.
  3. A `RequestRepaint()` after the fire re-arms (schedules a second timer).
  Use a spy on `NS.UpdateAbsorbBar` to count invocations.
- **Migration test (`tests/test_database.lua`):** a v1 DB with a saved `updateInterval` →
  after `RunMigrations`, `updateInterval` is gone, `throttleWindow` is the default, and
  `schemaVersion == 2`.
- **Schema test (`tests/test_schema.lua`):** update any assertion that references the
  `updateInterval` entry to `throttleWindow` (path, range, default).

## Docs to update

- `docs/data-flow.md` — the event → RequestRepaint → throttle → UpdateAbsorbBar flow diagram;
  remove the poll-ticker description.
- `docs/ARCHITECTURE.md` — event wiring (add `UNIT_MAXHEALTH`), settings schema
  (`updateInterval` → `throttleWindow`), note the ticker removal.
- `docs/settings-panel.md` and `docs/schema.md` — the renamed setting.
- `CHANGELOG` — behavioral change + migration note.
- The library-stack-§1 comment header in `modules/Timer.lua` (rewritten as above).

No version bump and no commit are part of this design — those require an explicit instruction.

## Standards compliance (§7)

**No deviation.** library-stack-§1 (no raw `C_Timer` for repeating work) is satisfied: the coalescing repaint
is a one-shot AceTimer (the same pattern already in `settings/Widgets.lua:198`), and the repeating
poll ticker is *removed*, not replaced with raw `C_Timer`. Splitting/retiring a schema setting via
a versioned, idempotent `RunMigrations` step is the toc-file-§2/savedvariables-§1 flow. Event registration follows the
file's existing `RegisterEvent` + `unit == "player"` convention.

## Risks & mitigations

- **Dropped/missing event → stale bar** (accepted, no backup ticker): mitigated only by the next
  real event or a manual `/at`. Judged acceptable given Blizzard relies on the same events.
- **Call-site removal misses:** `RestartUpdateTicker` / `ResetTickerInterval` are referenced in
  `OnEnable`, `OnProfileChanged`, and `General.lua` — all three must be updated or the load will
  error on a nil global. Covered by the load test in `tests/run.lua`.
- **Throttle latency (0.1s):** imperceptible; tunable via the setting.
