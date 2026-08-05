# AbsorbTracker — Proposed Changes (HLD + LLD), 2026-08-05

**Standard resolved:** Ka0s WoW Addon Standard **v2.21.0** (2026-08-04), fetched from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` — index plus every section
file linked from its Sections map. The standards cross-check below was **performed**, not skipped.

**Scope rule observed:** no change in this document targets a path under `libs/` or `tests/_kit/`.
There are no upstream findings in this review, so there is no upstream change-set section.

---

## HLD — themes

### Theme A — make the perf report describe the call graph it actually has

**Covers:** F-001, F-007, F-006

The perf harness is this addon's most-cited evidence, and three separate things currently make it say
more than it knows: a descriptor that declares containment the code does not have (F-001), a write-up
that points the reader at the one figure the standard calls unresolved (F-007), and an offline
assertion that cannot go red for the property it names (F-006).

The rationale for grouping them is that they fail *together* in the reader's hands: a mis-nested
bucket table plus "read the delta first" plus an unfalsifiable zero-overhead check means a future
perf decision is made from a number that is wrong, a number that is noise, and a green check that
proves nothing. Fixing one without the others leaves the reader with the same conclusion.

**Alternatives considered.**

- *Re-nest the code so the declaration becomes true* — i.e. call `ApplyVisibility` from inside
  `doRepaint`. **Rejected.** It would add per-bar visibility work to the hottest coalesced path to
  satisfy a report, which inverts the purpose of instrumentation and would show up as real cost in
  the very bucket it was meant to explain.
- *Leave `within` and fix only the doc* — **rejected.** The containment note and the "do not sum"
  instruction are emitted by the library from the descriptor
  (`libs/LibKa0s/Perf.lua:212-244`); no amount of prose in `docs/performance.md` changes what the
  in-game report prints.
- *Add a wall-clock assertion to `tests/perf.lua` to strengthen the overhead check* — **rejected
  outright**, `performance-§9`: a wall-clock assertion in an ungated runner is a flake generator.

**Trade-off.** After A1, `appearance` and `visibility` render un-indented and their totals become
summable with `repaintPass`. That is a *change in reported shape* for anyone comparing a new capture
against `docs/perf-runs/2026-07-30-ingame-post-extraction.json`. Since `docs/perf-runs/` is
append-only evidence, the old record stays exactly as it is; the interpretation difference is called
out in the note added by A2.

### Theme B — close the two functional gaps and the one honesty gap

**Covers:** F-002, F-003, F-004

Three small defects that share a shape: a user-visible promise the code does not keep. `/at test`
promises a duration it does not honor; the show-only-in-combat toggle promises a refreshed bar and
delivers a stale one when the player bar is off; the Reset All popup promises success it did not
check for. Each fix is a few lines and each goes through a seam the addon already has — the AceTimer
on the addon object, the payload-free bus publish, and the existing guarded-acknowledgment idiom in
`settings/Slash.lua`.

**Alternatives considered.**

- *For F-002, clear `testHoldUntil` with an `OnUpdate` poll* — **rejected**, `performance-§`: an
  `OnUpdate` for a once-per-command deadline is exactly the unthrottled per-frame handler the
  standard names as an anti-pattern, when a one-shot AceTimer already exists in the addon
  (`modules/Timer.lua:50`).
- *For F-002, use `C_Timer.After`* — **rejected**, the Ace3 substrate rule: timers go through the
  addon object's AceTimer mixin, which is what `settings/OptionsSetup.lua:76` already routes the
  library's own throttle through.
- *For F-003, special-case "any enabled unit" inline in the onChange* — **accepted in the
  simplest form**: publish `REPAINT` unconditionally. The repaint is already coalesced
  (`modules/Timer.lua:44-51`) and `UpdateAbsorbBar` early-outs per bar, so the guard was saving
  nothing measurable and was the only thing making the handler unit-aware.

### Theme C — make the harness's own blind spots visible

**Covers:** F-005, F-013

Two places where a green row means less than it appears: a suite that is listed but absent contributes
nothing and does not fail, and a provenance check that cannot see its sibling repo passes silently.
Neither is fixed by making anything fail — the kit's skip semantics and the vendor test's
missing-sibling quiet are both deliberate and correct. What is missing is the **assertion** in one
case and the **disclosure** in the other.

**Alternative considered.** *Make a missing sibling checkout fail `tests/test_vendor_sync.lua`* —
**rejected**, and the file's own header explains why: it would redden the gate on every machine that
does not happen to have LibKa0s beside this repo, and the natural response to that red is to weaken
the check. `testing-§` treats a suite that fails for environmental reasons as one that gets disabled.

### Theme D — comments that no longer describe the code

**Covers:** F-009, F-010, F-011, F-012, and the doc half of F-008

Four comments assert things that are not true of the current code, and each one sends a reader to the
wrong file. Comment-only edits with one small code consolidation (the duplicate `deepcopy`). Cheap,
zero risk, and the kind of drift that compounds silently in a codebase whose comments are otherwise
this load-bearing.

### Theme E — un-deaden the migration ladder

**Covers:** F-008

One-line default change plus a case. Deferred-safe (today's impact is nil), but the ladder is
explicitly designed to be extended and the next extension is the one that would be hurt.

---

## LLD — change-set

### A1 — drop the false `within` declarations

**Findings:** F-001
**Files:** `core/PerfSetup.lua`

Before (`core/PerfSetup.lua:42-48`):

```lua
buckets = {
    { key = "absorbEvent" },
    { key = "repaintPass" },
    { key = "paintBar",    within = "repaintPass" },
    { key = "appearance",  within = "repaintPass" },
    { key = "visibility",  within = "repaintPass" },
},
```

After:

```lua
-- Ordered for the report. `within` is DECLARED nesting and must match the call graph: only
-- paintBar is opened inside repaintPass's bracket (modules/Timer.lua's doRepaint calls
-- NS.UpdateAbsorbBar and nothing else). `appearance` and `visibility` are driven by the
-- APPEARANCE / VISIBILITY bus messages, so they are top-level totals — declaring them nested
-- made every report assert a containment that never happens and told the reader to exclude
-- real cost from the addon's total.
buckets = {
    { key = "absorbEvent" },
    { key = "repaintPass" },
    { key = "paintBar",   within = "repaintPass" },
    { key = "appearance" },
    { key = "visibility" },
},
```

**Risk.** Report shape changes: two buckets lose their indentation and leave the "contains" note.
No behavior change, no allocation change — `within` is read only at report-render time
(`libs/LibKa0s/Perf.lua:214`, `:348`, `:561`).

**Regression pressure.** Add one case to `tests/test_perf.lua` asserting that every bucket declaring
`within = X` is reached from inside X's bracket — expressible without the client by driving
`doRepaint` with `Perf.on` true and checking which bucket keys accrued calls. **This adds one case,
so `docs/test-cases.md` and the README `[Tests]` badge must move from 470 to 471 in the same change**
(`testing-§7`) — regenerate the inventory with `lua tests/run.lua --list`, never by hand.

**Standards conformance.** `performance-§2` (buckets and nesting must reflect the instrumented call
graph). The rejected alternative — restructuring `doRepaint` to make the declaration true — would
have added work to the hottest path, which the same section forbids.

### A2 — re-headline `docs/performance.md` on the bucket figures

**Findings:** F-007
**Files:** `docs/performance.md`

- At `:242`, replace *"**`delta` is the headline.**"* with a bucket-first reading: the bucket table is
  the addon's own cost; the delta is corroboration and is **unresolved** below the harness's
  run-to-run spread.
- Move the resolution-floor caveat currently at `:258` up to the point of first use so the reader
  meets it with the number, not after it.
- Add one line under the nesting note (`:239`, `:273`) recording that captures taken **before** A1
  carry `within: "repaintPass"` on `visibility` (and would have on `appearance`), so
  `docs/perf-runs/2026-07-30-ingame-post-extraction.json` must be read with that correction. **Do not
  edit or delete that record** — `docs/perf-runs/` is append-only.

**Standards conformance.** `performance-§` — *MUST read the bucket figures as the addon's cost, and
treat the frame-time delta as unresolved below the harness's measured run-to-run spread.*

### A3 — make the zero-overhead assertion falsifiable

**Findings:** F-006
**Files:** `tests/perf.lua`

Before (`tests/perf.lua:228-231`):

```lua
assert_(probeOff.bytesPerIter <= probeOn.bytesPerIter + 1,
  "a dormant bracket allocated more than an armed one — the gating idiom is wrong")
assert_(probeOff.apiPerIter == probeOn.apiPerIter, "the probe changed how many API calls a pass makes")
```

After:

```lua
-- The claim is performance-§2's "a dormant bracket is free", and it needs an assertion that can
-- go RED when the off path starts allocating. `probeOff <= probeOn` cannot: a regression that
-- makes the dormant bracket allocate lands on the armed path too, so the comparison stays true.
--
-- Pinned by CONSTANCY instead, against a bracket-identical arm from the same run: paintPass runs
-- exactly the same code with capture off, so any divergence between them is the instrumentation.
-- A true "instrumentation absent" arm cannot be built in-process — the brackets are compiled into
-- the functions under test — and saying so beats an assertion that pretends otherwise.
assert_(probeOff.bytesPerIter == paintPass.bytesPerIter,
  ("a capture-off pass allocated %.1f B/iter here vs %.1f B/iter in paintPass; the dormant " ..
   "bracket is not free"):format(probeOff.bytesPerIter, paintPass.bytesPerIter))
assert_(probeOn.bytesPerIter - probeOff.bytesPerIter < 8,
  ("arming the probe added %.1f B/iter; a bracket must not allocate per call")
    :format(probeOn.bytesPerIter - probeOff.bytesPerIter))
assert_(probeOff.apiPerIter == probeOn.apiPerIter, "the probe changed how many API calls a pass makes")
```

Today's run supports both bounds: `paintPass` and `probeOverheadOff` both read exactly 312.0 B/iter,
and the armed delta is 0.3 B/iter against a ceiling of 8.

**Risk.** The equality is exact, so a genuinely nondeterministic allocation would redden the runner.
`tests/perf.lua` is **outside** the green gate by design (`performance-§9`), so that reddens a report,
not a commit. No case count changes — scenarios are not test cases (`testing-§7`).

**Standards conformance.** `performance-§2` (zero-overhead evidence), `performance-§9` (ungated
runner, deterministic quantities only, no wall-clock assertion).

### B1 — `/at test` restores when its hold expires

**Findings:** F-002
**Files:** `settings/Slash.lua`, `modules/Timer.lua` (no change expected; the seam already exists)

Before (`settings/Slash.lua:291`):

```lua
    NS.testHoldUntil = GetTime() + hold
```

After:

```lua
    NS.testHoldUntil = GetTime() + hold
    -- The message above states a duration, so honor it. Without this, the fake value clears only
    -- when the next absorb / max-health / world / combat event happens to arrive — which, standing
    -- still out of combat previewing your styling, may be never. One-shot AceTimer through the
    -- addon object (the same seam modules/Timer.lua's throttle uses), publishing the payload-free
    -- REPAINT every other transition publishes.
    if NS.testHoldTimer and NS.addon.CancelTimer then NS.addon:CancelTimer(NS.testHoldTimer) end
    NS.testHoldTimer = NS.addon:ScheduleTimer(function()
        NS.testHoldTimer = nil
        NS.bus:SendMessage(NS.MSG.REPAINT)
    end, hold)
```

**Risk.** A second `/at test` before the first expires must not leave two timers racing — hence the
cancel-then-rearm. `hold` is user-supplied via `tonumber(args[2]) or 5`
(`settings/Slash.lua:269`); a negative or zero value schedules an immediate fire, which is the
correct degenerate behavior (the guard at `modules/Display.lua:186` is already open).

**Regression pressure.** One case in `tests/test_slashcmds.lua`: `/at test` arms a timer whose fire
publishes REPAINT and clears the preview. **+1 case → 471 (or 472 with A1); `docs/test-cases.md` and
the README badge move in the same change.**

**Standards conformance.** Ace3 substrate — AceTimer through the addon object, not `C_Timer`
(matches `settings/OptionsSetup.lua:76`); `architecture-§4` — publish the bus message, do not call
`NS.RequestRepaint` across the module boundary.

### B2 — repaint every bar when the combat gate flips

**Findings:** F-003
**Files:** `settings/General.lua`

Before (`settings/General.lua:50-53`):

```lua
onChange = function()
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
    if NS.ShouldShowBar() then NS.bus:SendMessage(NS.MSG.REPAINT) end
end,
```

After:

```lua
onChange = function()
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
    -- Unconditional. `showOnlyInCombat` is global but the old guard read
    -- NS.ShouldShowBar(), which defaults to the PLAYER unit — so with the player bar disabled
    -- and target/focus enabled, the bars this toggle just revealed kept whatever value they
    -- last held. The repaint is coalesced by modules/Timer.lua and UpdateAbsorbBar early-outs
    -- per hidden bar, so publishing it always costs one throttled pass at most.
    NS.bus:SendMessage(NS.MSG.REPAINT)
end,
```

**Risk.** One extra coalesced pass when the option is toggled with every bar hidden — bounded by the
throttle and by `UpdateAbsorbBar`'s early-outs. Measurable ceiling from today's run: a full
three-bar `paintPass` is 312 B and 12 API calls.

**Regression pressure.** One case in `tests/test_visibility.lua` or `tests/test_slashcmds.lua`:
toggling `showOnlyInCombat` with the player bar disabled and target enabled publishes REPAINT. **+1
case.**

**Standards conformance.** `architecture-§4` — payload-free publish, consumer re-reads live state.

### B3 — the Reset All popup stops claiming unverified success

**Findings:** F-004
**Files:** `settings/General.lua`

Before (`settings/General.lua:133-138`):

```lua
OnAccept     = function()
    if NS.Helpers and NS.Helpers.RestoreAllDefaults then
        NS.Helpers.RestoreAllDefaults()
    end
    print("All settings reset to defaults.")
end,
```

After:

```lua
-- The acknowledgment lives INSIDE the guard, for the reason settings/Slash.lua's runResetAll
-- spells out: on a load where the settings library never registered there is nothing to
-- delegate to, and printing the ack anyway claims success for work that did not happen. Same
-- string as the slash verb, so the same action reads the same wherever it was triggered.
OnAccept     = function()
    if NS.Helpers and NS.Helpers.RestoreAllDefaults then
        NS.Helpers.RestoreAllDefaults()
        print("All settings reset to defaults")
    else
        print("Cannot reset settings \226\128\148 the settings helpers failed to load")
    end
end,
```

**Risk.** None. Note the trailing period is dropped to match `settings/Slash.lua:171` exactly; if the
period is preferred, change **both** sites in this same edit.

**Regression pressure.** One case in `tests/test_slashcmds.lua` (which already covers the slash twin's
degraded arm): the popup's `OnAccept` prints the failure line when `NS.Helpers.RestoreAllDefaults` is
absent. **+1 case.**

**Standards conformance.** `slash-commands-§4` (prefixed printer; unchanged — this goes through
`local print = NS.Print` at `settings/General.lua:12`). No new deviation.

### C1 — assert the suite list covers the suites on disk

**Findings:** F-005
**Files:** `tests/test_loadorder.lua` (new case); `tests/run.lua` (publish the list)

`tests/run.lua` already publishes `loadedAddonFiles` for exactly this purpose
(`tests/run.lua:53`). Publish the suite list the same way:

```lua
-- tests/run.lua
local SUITES = { "test_loadorder", ... }        -- the existing literal, lifted to a named local

_G.AT_TEST = Kit.expose{
  NS = NS, mocks = mocks,
  loadedAddonFiles = ADDON_FILES,
  suiteList = SUITES,                            -- so a case can compare it against disk
}
Kit.run{ dir = "tests/", suites = SUITES }
```

Then in `tests/test_loadorder.lua`:

```lua
test("loadorder: the runner's suite list is exactly the suites on disk", function()
  -- The FIFTH load list, and the only one nothing pinned. tests/_kit/framework.lua SKIPS a listed
  -- suite whose file is missing rather than failing (its own comment says so), and nothing
  -- asserted the converse — so a renamed suite silently stops contributing cases while the run
  -- stays green and the badge quietly drops. Both directions are checked here.
  local onDisk = {}
  local p = io.popen('ls tests/test_*.lua')       -- or a directory walk the kit already provides
  ...
  assertEqual(table.concat(onDisk, "\n"), table.concat(sorted(T.suiteList), "\n"))
end)
```

**Risk.** `io.popen` is not available in every Lua build; prefer whatever directory enumeration the
kit's loader already exposes, or fall back to `io.open`-probing a list derived from the suite list
plus a `find`-free scan. Implementation detail for the task, not a design question.

**Regression pressure.** **+1 case.**

**Standards conformance.** `testing-§9` — load lists must not be hand-maintained where derivation is
possible; this pins the one list that cannot be derived from the TOC. Note the change does **not**
touch `tests/_kit/` — the kit's skip behavior is left exactly as vendored.

### C2 — disclose the vendor-sync skip in the case name

**Findings:** F-013
**Files:** `tests/test_vendor_sync.lua`

Rename the two cases so the condition is in the inventory:

```lua
test("libs/LibKa0s matches the release the README claims, when the LibKa0s checkout is beside this repo", ...)
test("tests/_kit matches the test kit of that release, when the LibKa0s checkout is beside this repo", ...)
```

and fix the comment at `:106-109`, which currently claims the disclosure already exists.

**Risk.** Renaming a case changes two lines of `docs/test-cases.md` without changing the count —
regenerate the inventory in the same change.

**Regression pressure.** Case **count unchanged** (470 → 470 from this change alone); two inventory
lines move.

**Standards conformance.** `testing-§12` — a case that passes without exercising anything must not
read as coverage. The compliant remedy here is disclosure, not failure: making a missing sibling
redden the gate is the environmental flake `testing-§` warns gets a suite switched off.

### D1 — one table-copy, and comments that match the code

**Findings:** F-009, F-010, F-011, F-012
**Files:** `core/Database.lua`, `core/Units.lua`, `settings/Schema.lua`, `modules/Bar.lua`,
`core/Data.lua`

- `core/Database.lua:26-31` — delete the private `deepcopy` and use `NS.Units.DeepCopy`
  (`core/Units.lua:42`), which loads earlier in the TOC. Gives the export its first production
  caller and removes a byte-identical duplicate.
- `settings/Schema.lua:158` — reword to say the loop is a **one-level** copy and why that is
  sufficient for a flat `{r,g,b,a}` default.
- `core/Units.lua:78-85` — correct `Units.Set`'s comment: the slash CLI writes through
  `NS.SetByPath` → `NS.SetPath`, not this function; state plainly that it currently has no
  production caller.
- `modules/Bar.lua:5-6`, `:86-87` — the aliases exist for the **tests**; `core/DebugLog.lua` has not
  existed since the LibKa0s extraction and `/at test` reads `NS.bars[unit]`.
- `core/Data.lua:6-9` — say that the *toggles* are re-read per call while the resolved class color is
  memoized once, because a character's class cannot change in-session.

**Risk.** One real code change (the `deepcopy` consolidation) on a migration path.
`tests/test_database.lua:50` and `:206` already assert nested-table isolation across that path, so
the existing gate covers it. Everything else is comment-only.

**Regression pressure.** No case-count change.

**Standards conformance.** No new deviation. `Units.Set` is **kept**, not deleted — it is namespace
API with a test, and `public-api` treats removal of a published member as a separate decision from
correcting its documentation.

### E1 — the account-wide schema stamp defaults to 1

**Findings:** F-008
**Files:** `defaults/Profile.lua`, `core/Database.lua` (comment only)

Before (`defaults/Profile.lua:74-79`):

```lua
NS.defaults.global = {
    schemaVersion = 4,
}
```

After:

```lua
NS.defaults.global = {
    -- 1, not 4, and for the same load-bearing reason the per-profile stamp above is 1: AceDB's
    -- copyDefaults fills every absent key the first time `db.global` is touched, which happens
    -- BEFORE NS:RunMigrations reads it. Defaulting to the current version stamps any DB whose
    -- `global` section first materializes on this build as already-migrated, and the whole
    -- SCHEMA_STEPS ladder becomes dead code for that user. Every step is idempotent and a no-op
    -- on fresh data, so running the ladder once on a brand-new install costs nothing.
    schemaVersion = 1,
}
```

**Risk.** On a fresh install the ladder now runs all three steps against empty data. v2 nils an
absent key, v3 is a no-op by construction (`core/Database.lua:174`), v4's `dropKeyEverywhere`
returns 0 and logs nothing. The visible difference is three `[Migrate] vX → vY` debug lines on a
first login **with debug already on** — which cannot happen, since the flag is session-only and off
at login (`core/State.lua`, `core/AbsorbTracker.lua:78-80`).

Also update the comment at `core/Database.lua:190` — `g.schemaVersion = g.schemaVersion or 1` stops
being AceDB-unreachable and becomes the ordinary path.

**Regression pressure.** One case in `tests/test_database.lua`: a DB whose `global` section is created
by copyDefaults still runs the ladder to 4. **+1 case.**

**Standards conformance.** `savedvariables-§` — the migration seam must be reachable. The tempting
alternative (leave the default at 4 and special-case detection of a "new" global section) was
rejected: it re-derives from shape what a version stamp exists to state.

---

## Cumulative test-count movement

| Change | Cases added | Running total |
|---|---|---|
| baseline (measured today) | — | **470** |
| A1 | +1 | 471 |
| B1 | +1 | 472 |
| B2 | +1 | 473 |
| B3 | +1 | 474 |
| C1 | +1 | 475 |
| C2 | 0 (two names change) | 475 |
| E1 | +1 | 476 |

`docs/test-cases.md` is regenerated with `lua tests/run.lua --list` and the README `[Tests]` badge
updated **in the same commit as the change that moves the count** (`testing-§7`) — never as a
follow-up, and never hand-edited.

## Complexity expectation

None of these changes adds a branch to a function near the line. `runTest`
(`settings/Slash.lua:265`) gains two statements and no branch; the `showOnlyInCombat` `onChange`
loses one. `Helpers.BuildMainContent` (`settings/About.lua:38`), the sole function *at* CCN 15 on
today's run, is untouched. Expect the next release regeneration to show **no** movement in
`RESULTS.md`'s watch list — a note for the release, not a tool to run now.
