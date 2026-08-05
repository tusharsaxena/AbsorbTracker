# "Show only in combat" bar visibility — design

**Date:** 2026-07-13
**Issue:** [#13](https://github.com/tusharsaxena/absorbtracker/issues/13) — "Add option to toggle visibility in combat" (enhancement)
**Status:** approved (pending spec review)
**Standard:** Ka0s WoW Addon Standard — no deviation (see §Standards)

## Problem

The bar has a single visibility control: the `hidden` bool ("Show Bar", `/at toggle`). Issue #13
asks for an option to only show the bar in combat — a common request so the bar isn't cluttering
the screen when no absorb activity is happening.

## Goal

Add a `showOnlyInCombat` boolean. When **on**, the bar is shown during combat and hidden out of
combat. When **off** (the default), behavior is exactly as today. It composes with the existing
`hidden` master toggle: `hidden` always wins.

## Non-goals

- "Hide during combat" or a 3-way visibility mode — issue #13 and the confirmed scope is the
  single "show only in combat" toggle only.
- "Show only when I have an absorb" — a different feature, out of scope.

## Behavior

Effective visibility resolves from two inputs, master first:

| `hidden` | `showOnlyInCombat` | In combat? | Bar |
|---|---|---|---|
| true | — | — | hidden |
| false | false | — | shown (today's behavior) |
| false | true | yes | shown |
| false | true | no | hidden |

## Design

### 1. Setting (`defaults/Profile.lua`, `settings/General.lua`)

- `defaults/Profile.lua`: add `showOnlyInCombat = false`.
- `settings/General.lua`: new schema row, **Master controls** group, **order 15** (between
  `hidden` @10 and `locked` @20):
  ```lua
  {
      path    = "showOnlyInCombat",
      page    = "general",
      group   = "Master controls",
      order   = 15,
      type    = "bool",
      label   = "Show only in combat",
      desc    = "When on, the bar is hidden except while you're in combat.",
      default = flatDefaults.showOnlyInCombat,
      onChange = function()
          NS.ApplyVisibility()
          if NS.ShouldShowBar() then NS.UpdateAbsorbBar() end
      end,
  }
  ```
  No `inverse`, no `solo`.

**Panel layout (verified against `settings/Widgets.lua:262-290`).** Bool rows pair 50/50 two per
row; the group-boundary `flushRow()` before the `afterGroup` button pair drops a lone trailing
row. Order 10/15/20 in Master controls therefore renders exactly the confirmed layout:
```
[Show Bar]        [Show Only in Combat]
[Lock Position]
[Reset Position]  [Reset All Settings]   (existing afterGroup InlineButtonPair)
```

### 2. Visibility resolution (`modules/Display.lua`)

Two new functions:
```lua
-- Effective bar visibility. The `hidden` master toggle wins; then the combat gate. The bar is a
-- plain (non-secure) frame, so Show/Hide is taint-free even mid-combat.
function NS.ShouldShowBar()
    if NS.GetSetting("hidden") then return false end
    if NS.GetSetting("showOnlyInCombat") and not InCombatLockdown() then return false end
    return true
end

function NS.ApplyVisibility()
    if NS.ShouldShowBar() then NS.bar:Show() else NS.bar:Hide() end
end
```

Wire the two existing paint paths through it:
- `UpdateBarAppearance`: replace the `if NS.GetSetting("hidden") then bar:Hide() else bar:Show() end`
  block with `NS.ApplyVisibility()`.
- `UpdateAbsorbBar`: change the early-return guard from `if NS.GetSetting("hidden")` to
  `if not NS.ShouldShowBar()` (skip the repaint whenever the bar is not visible), debug message
  `"Skipped: bar not visible"`.

### 3. Combat wiring (`core/AbsorbTracker.lua`)

In `OnEnable`, register the combat-state events (general events; no unit filter):
```lua
self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")
```
Handlers:
```lua
function addon:OnEnterCombat()
    NS.ApplyVisibility()
    NS.RequestRepaint()          -- fill the bar fresh if it just appeared
end

function addon:OnLeaveCombat()
    NS.ApplyVisibility()
    NS.RequestRepaint()
    -- Central owner of PLAYER_REGEN_ENABLED: drain a combat-deferred /at config (see §4).
    if NS.State and NS.State.panelOpenPending then
        NS.State.panelOpenPending = nil
        NS.OpenOptionsPanel()
    end
end
```
Also add `NS.ApplyVisibility()` to the start of `OnEnterWorld` (before its existing
`NS.RequestRepaint()`), so logging in / zoning while in combat sets the right initial state.

`OnEnable` already calls `NS.UpdateBarAppearance()` (now routing through `ApplyVisibility`), so the
initial visibility at login is correct for the current combat state via `InCombatLockdown()`.

### 4. Deferred-config integration (`settings/Panel.lua`)

**Why this changes.** AceEvent registers **one handler per event per object**.
`NS.OpenOptionsPanel` currently registers its own one-shot `PLAYER_REGEN_ENABLED` on `NS.addon` to
replay a combat-deferred open (options-ui-§2). Our `OnLeaveCombat` also needs `PLAYER_REGEN_ENABLED`; two
registrations on the same object collide (the second overwrites the first, and Panel's one-shot
then unregisters it — silently killing combat visibility).

Fix: make `OnLeaveCombat` the single owner. `OpenOptionsPanel`'s in-combat branch becomes just a
flag set (no event registration):
```lua
if InCombatLockdown() then
    if not NS.State.panelOpenPending then
        NS.State.panelOpenPending = true
        print("In combat \226\128\148 settings will open when you leave combat.")
    end
    return
end
```
`OnLeaveCombat` (§3) drains `panelOpenPending` and calls `OpenOptionsPanel()` (now out of combat,
so it opens). The options-ui-§2 behavior is preserved exactly: still opens on combat end, still idempotent
(one pending open no matter how many times `/at config` is hammered mid-pull).

### 5. Migration

**Additive** — the only change is a new default key. `NS:RunMigrations`' v1 backfill loop already
copies every missing `flatDefaults` key into the active profile on each init, so existing profiles
gain `showOnlyInCombat = false` automatically. **No `schemaVersion` bump** (bumps are for
structural/destructive changes like the v2 `updateInterval` deletion; an additive, default-covered
key flows through the existing seam). Confirmed with the user.

## Testing

Green gate stays `lua tests/run.lua` + `luacheck .` (0/0). The loader binds WoW globals live
through the mock table (`tests/loader.lua` `__index`), and `tests/test_slash.lua:59` already
toggles `mocks.InCombatLockdown`, so combat state is fully simulable.

New tests (in `tests/test_timer.lua` or a small `tests/test_visibility.lua` — plan decides):
- **`ShouldShowBar` truth table**, driving `mocks.InCombatLockdown` and the two settings:
  - `hidden = true` → false (regardless of the others).
  - `hidden = false`, `showOnlyInCombat = false` → true.
  - `hidden = false`, `showOnlyInCombat = true`, combat = true → true.
  - `hidden = false`, `showOnlyInCombat = true`, combat = false → false.
  Restore mutated settings/`mocks.InCombatLockdown` at the end of each test.
- **`OnLeaveCombat` drains the deferred panel**: stub `NS.OpenOptionsPanel` with a spy;
  with `NS.State.panelOpenPending = true`, calling `NS.addon:OnLeaveCombat()` calls the spy once
  and clears the flag; with the flag unset, the spy is not called.

`ApplyVisibility`'s actual Show/Hide isn't asserted directly (the headless `stubFrame` `Show`/`Hide`
are no-ops); `ShouldShowBar` carries the decision logic and is what the tests cover.

## Docs

- `README.md` — General-panel bullet (add "show only in combat"); a FAQ/troubleshooting line
  ("Why is my bar gone out of combat?" → the new toggle). No Version History row / no version bump.
- `docs/schema.md` — new `showOnlyInCombat` row.
- `docs/settings-panel.md` — Master controls layout note.
- `docs/scope.md` — visibility model (two composing inputs).
- `docs/data-flow.md` — `PLAYER_REGEN_DISABLED`/`ENABLED` → `ApplyVisibility` + repaint; note
  `OnLeaveCombat` now owns the deferred-config replay.

## Standards compliance

**No deviation.** Combat events use AceEvent (library-stack-§1/architecture-§2), not a raw event frame. The setting is a
schema row driven through the existing registry (§9.x). Centralizing `PLAYER_REGEN_ENABLED` in
`OnLeaveCombat` preserves the options-ui-§2 combat-deferred-open contract (a cleanup, not a behavior
change). Additive migration uses the existing `RunMigrations` backfill seam (toc-file-§2/savedvariables-§1).

## Risks & mitigations

- **AceEvent single-handler collision** (the main risk): resolved by §4 — one owner for
  `PLAYER_REGEN_ENABLED`. The `OnLeaveCombat` deferred-open drain test guards the options-ui-§2 behavior.
- **Confusing interaction with `/at toggle`**: with `showOnlyInCombat` on and out of combat,
  `/at toggle` (flipping `hidden`) won't reveal the bar. This is the intended composition
  (`hidden` is master, combat gate is secondary); documented in the FAQ.
- **`/at test` out of combat while the mode is on**: the bar is hidden, so a test paint isn't
  visible. Existing `/at test` already warns when the bar is hidden; leaving that check as-is
  (it reads the master `hidden`); acceptable — noted, not fixed.
