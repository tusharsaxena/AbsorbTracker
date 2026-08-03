# Design — Debug-logging overhaul (conform to debug-logging §8/§9/§10)

**Date:** 2026-07-15
**Status:** Approved (brainstorm) → spec review → implementation plan
**Standard:** Ka0s WoW Addon Standard **debug-logging v1.11.0** (2026-07-15), which added
**§8 Coverage**, **§9 Coalescing**, **§10 Settings-changes**. This work brings AbsorbTracker in
line with those three new sections. No deviation is introduced.
**References:** LootHistory `modules/DebugLog.lua` + `core/Util.lua` (coverage + secret-safe sink);
ConsumableMaster `eab4d50` (coalescing pattern).

---

## 1. Problem / current state

AbsorbTracker's debug **infrastructure already conforms**: the on-screen console
(`core/DebugLog.lua`), the two pure formatters (`FormatPlain` / `FormatColored`), the
`<HH:MM:SS> | [<tag>] <msg>` format, `date("%H:%M:%S")` timestamp, the `Debug: ON/OFF` header
toggle, Copy/Clear, and the `/at debug [on|off]` verb all match the standard. **The gaps are
behavioral:**

1. **§8 Coverage** — only three functional debug call sites exist; lifecycle, combat transitions,
   profile changes, config open/refuse, and migrations are logged nowhere.
2. **§9 Coalescing** — the two hot paths spam:
   - `AbsorbTracker.lua:74` `OnAbsorbChanged` logs on **every** player absorb event.
   - `Display.lua:81,97` `UpdateAbsorbBar` logs on **every** repaint and every skipped repaint.
3. **§10 Settings** — no `[Set] <path> = <value>` logging.
4. **Secret-safety of the sink (§6 / events-frames-taint-§8)** — the canonical sink
   `NS.Debug(tag, fmt, ...)` (`DebugLog.lua:253`) calls `fmt:format(...)` **without** the
   secret-safe stringifier. Only the separate `NS.DebugPrint` (`Util.lua:56`) is secret-safe. The
   absorb total is *the* canonical secret value, so the sink must be made safe.
5. **Tags** — current tags are event-name-style (`UNIT_ABSORB_AMOUNT_CHANGED`, `UpdateAbsorbBar`);
   the standard wants short Titlecase words.

## 2. Goals / non-goals

**Goals:** conform to §8/§9/§10; unify on one secret-safe sink; make the log read as a story of what
the addon did, at a few lines per fight, not per frame.

**Non-goals:** no changes to the console window, formatters, timestamp format, or the `/at debug`
verb (already compliant). No new SavedVariables. No millisecond timestamps (standard is `HH:MM:SS`).

## 3. Design

### 3.1 Sink unification + secret-safety

Make `NS.Debug(tag, fmt, ...)` secret-safe by porting LootHistory's sink verbatim in shape:

```lua
function NS.Debug(tag, fmt, ...)
    if not (NS.State and NS.State.debug) then return end   -- gate first; zero-alloc when off
    local n = select("#", ...)
    local msg = fmt
    if n > 0 then
        local parts = {}
        for i = 1, n do parts[i] = NS.SafeToString((select(i, ...))) end
        msg = fmt:format(unpack(parts))
    end
    NS.DebugLog:Add(tag, msg)
end
```

- Every vararg passes through `NS.SafeToString` (already defined, `Util.lua:30`), so a combat
  secret renders as `<secret>` instead of raising in `string.format`.
- **Format strings are `%s`-only** at every call site (args arrive pre-stringified).
- **Retire `NS.DebugPrint`** (`Util.lua:56`) — now redundant. Migrate its call sites to `NS.Debug`.
  `NS.SafeToString` / `NS.IsConcatSafe` / `NS.Print` stay.

### 3.2 Tag scheme (short Titlecase)

`Init`, `Set`, `Combat`, `Bar`, `Absorb`, `World`, `Profile`, `Cfg`, `Migrate`, plus the existing
`Debug` (logging enabled/disabled). Tags are rendered verbatim, no padding.

### 3.3 Coverage (§8) — call sites to add

| Tag | Location | Emitted line (example) |
|-----|----------|------------------------|
| `Init` | `addon:OnEnable` (`core/AbsorbTracker.lua`) | `enabled — schema v%s, profile "%s", bar %s` (one boot summary: schema version, active profile, shown/hidden) |
| `World` | `addon:OnEnterWorld` | `entering world` |
| `Combat` | `addon:OnEnterCombat` | `entered` (also resets the coalescing counters, §3.4) |
| `Combat` | `addon:OnLeaveCombat` | `left: %s events, %s repaints` (+ `final=%s` from the post-combat read when it is non-secret) |
| `Bar` | `NS.ApplyVisibility` (`modules/Display.lua`) | `shown (%s)` / `hidden (%s)` — **only on a shown↔hidden transition**, reason = `combat` / `showOnlyInCombat` / `hidden toggle` |
| `Profile` | `NS.OnProfileChanged` (`core/AbsorbTracker.lua`) — all three AceDB callbacks (changed/copied/reset, registered in `core/Database.lua`) route here, so one log point covers all | `changed → "%s"` |
| `Cfg` | `NS.OpenOptionsPanel` (`settings/Panel.lua`) | `opened` / `refused (in combat)` |
| `Migrate` | `NS.RunMigrations` (`core/Database.lua`) | `v%s → v%s` — **only when a migration actually runs** |
| `Set` | `NS.SetByPath` (`settings/Schema.lua`) | `%s = %s` (§10, single seam) — see 3.5 |

The `Bar` transition line requires tracking the last-applied visibility state in a module local so
the line fires on change, not on every `ApplyVisibility` call.

### 3.4 Coalescing (§9) — the hot path, secret-aware

`OnAbsorbChanged` and `UpdateAbsorbBar` **stop emitting per-event / per-repaint lines** (delete the
three current call sites). Instead:

- Two module-scope counters, `absorbEvents` and `repaints`, incremented in those handlers **only
  when `NS.State.debug` is on** (zero work when off).
- Reset at `OnEnterCombat`; flushed as one `[Combat] left: N events, M repaints` line at
  `OnLeaveCombat`, then cleared. A `final=<value>` is appended only if the post-combat
  `UnitGetTotalAbsorbs` read is non-secret (`issecretvalue` guard). **No `peak`** — a running max
  would require comparing secret values in combat, which is forbidden.
- **Value transitions** (`[Absorb] shield up: A → B`, `shield gone: B → 0`) are logged **only when
  the value is not secret** — guarded by `issecretvalue(v)` (12.0). Track `lastAbsorb` (the last
  *non-secret* value seen). When a new read is non-secret and crosses 0↔nonzero versus `lastAbsorb`,
  log the transition; otherwise update silently. When the read **is** secret (in combat), skip the
  comparison entirely — no leak, no line; the combat counts carry the story.
- **Zero-alloc gate:** all counter maintenance and all string building sit behind the
  `NS.State.debug` check. Off = nothing allocated, nothing counted.

Rationale: this is the ConsumableMaster "one summary per pass" pattern with the *pass* = a combat
session; the per-event negative trace is deleted outright.

### 3.5 Settings (§10)

One line at the single write seam `NS.SetByPath(path, value)` (`settings/Schema.lua:93`):
`NS.Debug("Set", "%s = %s", path, formatValue(value))`. Value formatting reuses the existing
schema value formatter where possible (booleans → `true`/`false`, colors → `{r,g,b,a}`, numbers
verbatim). No downstream reactor re-echoes the change (§10 forbids a second `[Cfg]` restatement).
Position writes (non-schema, written outside `SetByPath`) are **not** logged per §10.

### 3.6 Secret-value handling (accepted constraint)

In combat, `UnitGetTotalAbsorbs("player")` returns a **secret** value. Consequences, accepted:
- The pretty `A → B` value transitions and `peak=` are an **out-of-combat / non-secret** feature.
  **In combat the [Absorb] story is counts + `<secret>`**, not values. This is a WoW 12.0
  constraint, not a design gap.
- Detection uses `issecretvalue(v)` when present; the log path stays safe regardless because every
  arg still funnels through `NS.SafeToString` (a secret prints `<secret>`).
- The code **never** compares or branches on a value that may be secret without an `issecretvalue`
  guard first.

## 4. Files to change

- `core/DebugLog.lua` — make `NS.Debug` secret-safe (§3.1).
- `core/Util.lua` — remove `NS.DebugPrint`; keep `SafeToString`/`IsConcatSafe`/`Print`.
- `core/AbsorbTracker.lua` — `Init` boot summary; `World`; `Combat` enter/leave + counters +
  rollup; drop the `OnAbsorbChanged` per-event log, add gated event counter + non-secret transition;
  `Profile` line in `NS.OnProfileChanged`.
- `modules/Display.lua` — drop the two `UpdateAbsorbBar` logs; add gated repaint counter; add `Bar`
  visibility-transition line in `ApplyVisibility`.
- `settings/Schema.lua` — `Set` line in `SetByPath`.
- `settings/Panel.lua` — `Cfg` opened/refused lines in `OpenOptionsPanel`.
- `core/Database.lua` — `Migrate` line in `RunMigrations` when a migration actually runs.

## 5. Testing

- `tests/test_util.lua` — migrate the `DebugPrint` secret-safety test to `NS.Debug`; assert a
  secret vararg renders `<secret>` and does not raise.
- `tests/test_debuglog.lua` — assert `NS.Debug` routes varargs through `SafeToString`.
- New/extended: `[Set]` line emitted at `SetByPath`; `[Combat] left: N events, M repaints` rollup
  after enter→(events/repaints)→leave; non-secret `[Absorb]` transition detection; `[Init]` boot
  summary. Use the mock's debug capture; the mock must expose `issecretvalue` (stub) and a secret
  sentinel.
- Green gate unchanged: `lua tests/run.lua`, `luacheck .` (0/0), `luac -p` on touched files.

## 6. Docs to sync

`docs/file-index.md`, `docs/ARCHITECTURE.md` (event/debug notes), `docs/midnight-quirks.md` (secret
section already exists — extend for the debug sink), and any debug-logging topic doc. Framed as
conformance to debug-logging §8/§9/§10 — no deviation recorded.

## 7. Out of scope

Console window / formatter / timestamp changes; SavedVariables; millisecond timestamps; structured
`/at debug <topic>` dump verbs (MAY, not now).
