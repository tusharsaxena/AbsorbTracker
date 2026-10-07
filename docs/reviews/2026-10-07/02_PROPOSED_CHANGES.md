# Proposed changes — AbsorbTracker (2026-10-07)

Derived from `01_FINDINGS.md` (F-001 … F-008). **Standard resolved: Ka0s WoW Addon Standard v2.76.1 (2026-10-07).** The index was fetched with `curl`; the section files were read verbatim from `../WowAddonStandards` `master` `f472389` (see `01_FINDINGS.md` for why). Nothing here targets a path under `libs/` or `tests/_kit/`.

---

## HLD

### Theme A: Make the offline perf evidence measure the shipped repaint pass (F-001, F-002)

The perf runner exists to catch a new allocation on the repaint path. Today it measures a fan-out the test wrote itself, so the `repaintPass` bracket and `doRepaint`'s own allocation are outside it. Two moves, and their order matters:

1. **Measure first.** Give `tests/perf.lua` a scenario that runs the real `doRepaint`, and point the zero-overhead pair at it (performance-§9: "the addon's hottest bracketed path"). `doRepaint` is a file-local, so it needs a seam. The smallest one is a suite-only handle published beside the existing ones (`NS.Timer.__doRepaint = doRepaint`). That mirrors `NS.__busLib` and `NS.__schemaLib`, which the code already publishes "for the suite only".
2. **Then fix what it shows.** Replace the per-pass closure in `doRepaint` with a plain `for _, unit in ipairs(NS.Units.LIST) do` loop. That loop allocates nothing under Lua 5.1, and it keeps the `painted` and `parent` locals as ordinary locals.

*Alternatives rejected.* (a) Keep `ForEachUnit` and hoist a module-level callback that reads module-level `painted`/`parent` state. That swaps a local for shared mutable module state on a re-entrant-looking path, which is worse than a three-line loop. (b) Drive `doRepaint` through `NS.RequestRepaint(); mocks.__fireTimers()`. That measures AceTimer's per-schedule table and the mock's timer machinery along with the pass, which is the wrong denominator for a ceiling meant to bound the addon's code. (c) Leave the code and only re-word `docs/performance.md`. That leaves performance-§9's required evidence pointing at the wrong function.

*Trade-off.* The `PROBE_OFF_BYTES_CEILING` re-derivation has to be redone against the new scenario, filling in the three lines its own comment demands ("Raise it only by filling in those three lines again"). The figure is expected to fall to the real path's figure, not rise.

### Theme B: Close the two preview/stand-down edges (F-003, F-004)

Both edges come from a check that answers a narrower question than the one the code needs:

- `runHold` asks "is the addon *enabled*?" but needs "is it *stood down*?" Gate on `NS.IsStoodDown()` and keep the existing refusal line. A hold during a perf arm B should refuse, for the same reason a disabled addon refuses: there is nothing to paint.
- The combat re-lock lives only in `PLAYER_REGEN_DISABLED`. A stand-up (or `OnEnable`) that lands *inside* combat needs the same act. Extract `OnEnterCombat`'s re-lock block into one local (`relockForCombat()`), and call it from `OnEnterCombat` and from the end of `StandUp`/`OnEnable` when `UnitAffectingCombat("player")` is true. That is one seam, so the "Bars locked — combat started" line and the panel refresh stay identical everywhere.

*Rejected.* A second preview flag that combat consults. options-ui-§15 and anti-pattern #80 make the lock the one preview switch, and a second flag is exactly that anti-pattern.

### Theme C: Master scale should not move placed bars (F-005), gated on the in-client confirmation

Only if smoke check S-05 confirms the drift. Compensate in `RestoreBarPosition`: store positions in **screen** units (divide by the bar's effective scale on save, and multiply by it on restore). Alternatively, keep stored offsets as they are and re-anchor through `UIParent`'s scale. Either way this is a stored-shape question. If saved positions change meaning, that is a `savedvariables-§1` ladder step (v6) in the same change: existing positions were saved at the scale in force when the player dragged, which the profile does not record, so the migration has to assume the current Master scale. **If S-05 refutes the drift, F-005 closes with no code change.**

*Rejected.* Applying Master scale only to the bar's children. The scale is documented as "the whole frame, so the drag handle and the value text ride with it" (`modules/Display.lua:231-233`), and splitting it would make the handle and the bar disagree in size.

### Theme D: Retire stale evidence claims (F-006)

Drop the `suspended = false` member from the degraded Perf stub (`core/PerfSetup.lua:26`) and the assertion that pins it (`tests/test_perf.lua:538`). Keep the two assertions in that case that do pin something real: `Perf.on == false` and `Note` being a function. This follows the upstream template change (F-008). If the owner prefers to keep the stub byte-for-byte on the template until LibKa0s ships it, the minimum is to correct the assertion's message so it no longer claims ladder coverage.

---

## Upstream change-set (separate; cross-repo handoff)

| ID | Owning repo / file | Fix | Version bump | Then, in this addon |
|---|---|---|---|---|
| U-1 (F-007) | LibKa0s `testkit/framework.lua` (`renderTotals`, `renderInventory`) | Make the Totals row exclude declared skips (or add a separate `Skipped` row), and word the preamble so the README badge's X/Y follows from the table, per testing-§5 | `Kit.VERSION` +1, in a LibKa0s release | A re-vendor commit of the whole `tests/_kit/` folder plus a `CLAUDE.md` provenance-line bump, with `docs/test-cases.md` regenerated **in the same commit** (`lua tests/run.lua --list > docs/test-cases.md`). The badge stays `876/876` |
| U-2 (F-008) | LibKa0s `docs/api/Perf/version-14.1.1.6-docs.md` (and the next Perf docs version) | Drop `suspended = false` from the host stub template, and note that the ladder asks the latch | none (doc-only) | Change C-4 below |

Neither is an edit under `libs/` or `tests/_kit/` here.

---

## LLD

### C-1: A real-pass perf scenario, and the zero-overhead pair moved onto it (F-001)

- **Files:** `modules/Timer.lua` (one suite seam), `tests/perf.lua`, `docs/performance.md`.
- **Timer seam** (after `doRepaint`'s definition):
  ```lua
  -- Suite seam only: tests/perf.lua measures the shipped coalesced pass (performance-§9).
  NS.Timer = NS.Timer or {}
  NS.Timer.__doRepaint = doRepaint
  ```
  `NS.Timer` is already created at `modules/Timer.lua:83`. Move that line above the seam, or reuse the table.
- **perf.lua.** Rename the current `paintPass` body to `paintBars` (it really is "three direct `UpdateAbsorbBar` calls"). Add `repaintPass` = `NS.Timer.__doRepaint()` per iteration, and change `probeOverheadOff`/`On` to call `NS.Timer.__doRepaint()`. Re-derive `PROBE_OFF_BYTES_CEILING` from three consecutive fresh runs against the real pass. Measure the one-table delta again (the comment's method: add one `{}` and record the step) and write the three comment lines again. Keep `assert_(paintPass.apiPerIter == 12, …)` on the scenario that still makes 12 calls.
- **docs/performance.md:** Update the scenario table (`:72-77`) so `repaintPass` is "one coalesced repaint over three bars (`doRepaint`)" and `paintBars` is "three direct paints".
- **Risk:** Low. Perf output is outside the green gate. `tests/test_loadorder.lua` pins that `tests/perf.lua` derives its load list, and this change keeps that.
- **Test count:** The headless pass count does not move (perf scenarios are not cases, testing-§7).

### C-2: Drop the per-pass closure in `doRepaint` (F-002) — after C-1, so C-1 measures the before

- **File:** `modules/Timer.lua:40-42`.
  ```lua
  -- before
  NS.ForEachUnit(function(unit)
      if NS.UpdateAbsorbBar(unit, parent) then painted = true end
  end)
  -- after: no closure per pass (the hoisting rationale at :13-16 applies here too)
  for _, unit in ipairs(NS.Units.LIST) do
      if NS.UpdateAbsorbBar(unit, parent) then painted = true end
  end
  ```
- **Risk:** `NS.ForEachUnit`'s order is `NS.Units.LIST` order (`modules/Display.lua`, `function NS.ForEachUnit`), and this loop uses the same list, so the order is identical. `tests/test_timer.lua` stubs or observes `NS.UpdateAbsorbBar`, not `ForEachUnit`. Confirm with a grep before landing: if any suite stubs `NS.ForEachUnit` to observe `doRepaint`, it must move to the `UpdateAbsorbBar` spy.
- **Evidence it worked:** C-1's `repaintPass` scenario bytes/iter before and after, in one run each, on one machine.

### C-3: Refuse `/at debug hold` while stood down for any reason (F-003)

- **File:** `settings/Slash.lua:323`.
  ```lua
  -- before
  if NS.GetSetting("enabled") == false then
  -- after: the latch is the one answer to "is this addon inert" (core/Lifecycle.lua)
  if NS.IsStoodDown() then
  ```
  Keep the debug line, and keep `Sl:DisabledLine()` when the `disabled` hold is taken. For the perf-only case, print one line naming the cause: `"A performance capture has the bars suspended; /at perf finish restores them"`. That line comes from the host, so it is not the dispatcher's refusal string, and slash-commands-§7's single-wording rule does not bind it.
- **Tests:** Add one case to `tests/test_debughold.lua`: with the `perf` hold taken (`NS.lifecycle:Hold("perf")`), `/at debug hold 5` arms no timer (`#mocks.__timers` unchanged) and prints the suspended line. Add `-- red under: revert C-3` beside it, so the negative assertion is falsifiable (testing-§12).
- **Test count:** +1. Regenerate `docs/test-cases.md` and the README badge (`877` → `878` cases, badge `877/877`) **in the same commit**.

### C-4: Drop the dead stub member and its assertion (F-006)

- **Files:** `core/PerfSetup.lua:26` (delete `suspended = false,`) and `tests/test_perf.lua:538` (delete the assertion; the case keeps its other two).
- **Risk:** Grep first. `tests/test_coresetup.lua:79` builds its own Perf double with `suspended = false`, which is test-local and unaffected. No shipped reader exists (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs grep -n "Perf.suspended"` lists only comments and the test).
- **Test count:** Unchanged (an assertion is removed from a case, and no case is removed).

### C-5: One combat re-lock, reached from the stand-up path too (F-004)

- **File:** `core/AbsorbTracker.lua`. Extract lines `318-326` into a local and publish it on NS for the latch:
  ```lua
  --- The ONE combat re-lock (preview-mode: a fight starts on live data). Returns whether it locked.
  function NS.RelockForCombat()
      if NS.GetSetting("locked") then return false end
      NS.SetByPath("locked", true)
      NS.Print("Bars locked \226\128\148 combat started")
      if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
      return true
  end
  ```
  `OnEnterCombat` becomes `local relocked = NS.RelockForCombat()` followed by its existing `else` branch. At the end of `StandUp` (`core/Lifecycle.lua:120`), and in `OnEnable` after the gate, call it `if UnitAffectingCombat("player") then NS.RelockForCombat() end`.
- **Risk:** Medium-low. In `StandUp`, call it **after** the four publishes, so the `locked` onChange's `APPEARANCE`/`REPAINT` land on a live bus. `UnitAffectingCombat` is already in `.luacheckrc`'s `read_globals`.
- **Tests:** Add one case to `tests/test_disabled.lua`: disable while unlocked, set the mock in combat, enable, then assert `locked == true` and that no placeholder is painted. Add one case to `tests/test_visibility.lua` or `tests/test_events.lua` for `OnEnable` in combat with a stored unlock. Annotate both with `-- red under:` lines. +2 cases. Regenerate the inventory and badge in the same commit.

### C-6: Master scale compensation (F-005) — **only if S-05 confirms**

Design in Theme C. LLD is deferred until the smoke result exists, because the migration shape depends on it. If it lands: a `SCHEMA_STEPS` row `{ to = 6, … }` in `core/Database.lua` (savedvariables-§1), a `docs/schema.md` update, and cases in `tests/test_database.lua` and `tests/test_display.lua`.

---

## Expected movement for the next release run (note only; not to be run now)

- `docs/automated-tests/RESULTS.md`: C-2 removes one anonymous function, and C-5 adds one (`NS.RelockForCombat`) while shrinking `OnEnterCombat`. Max CCN should stay at 14. `tests/test_slashcmds.lua` (1079 today) should leave the 1000–1500 band in the next regeneration.

## Standards conformance (per change)

| Change | Introduces a deviation? | Rule that shaped it |
|---|---|---|
| C-1 | No | performance-§9 (`performance.md:200`, zero-overhead scenario on the hottest bracketed path); testing-§7 (scenarios are not cases); testing-§9 (the load list stays TOC-derived) |
| C-2 | No | performance-§2 (nothing allocated on the dormant path) |
| C-3 | No | slash-commands-§7 (the dispatcher's refusal wording is the library's, so the perf-suspended line is a host line, not a reworded refusal); testing-§12 (`red under`) |
| C-4 | No | options-ui-§1 (a stub answers the members the addon calls); testing-§12 |
| C-5 | No | preview-mode and options-ui-§15 (the lock is the one preview switch, so no second flag, anti-pattern #80); architecture-§5 (the write goes through `NS.SetByPath`) |
| C-6 | No, if it ships its ladder step | savedvariables-§1 (a stored-meaning change takes a ladder step in the same change) |
| U-1, U-2 | Not in this repo | library-stack-§5 and testing-§1 (fix upstream, re-vendor, never patch the copy) |

Rejected for standards reasons: patching `tests/_kit/framework.lua` locally for F-007 (library-stack-§5 and testing-§1), and adding a `Test mode` row or `/at test` verb to make preview combat-aware (options-ui-§15, anti-pattern #80).
