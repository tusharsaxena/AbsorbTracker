# Review findings — AbsorbTracker (2026-10-07)

**Verdict: minor issues.** Nothing is blocking, and nothing is High or Critical. Lint is clean, the suite passes 876 of 877 (the one skip is a kit contract case the addon opts out of, and it is disclosed). The offline perf assertions hold, no function is above CCN 15, the vendored LibKa0s payload and test kit are byte-identical to their source, and the four-class cross-addon pass is clean across all eleven addons. The one Medium is about evidence, not shipped behavior: the offline perf runner's "coalesced repaint" and "zero-overhead" scenarios run a fan-out the test wrote itself, not the shipped `doRepaint`, so the hottest bracket (`repaintPass`) is never measured. The Lows are two edge cases in the preview/stand-down interplay, one UX question about Master scale that needs an in-client check, two stale test or doc claims, and two upstream items.

**Resolved scope:** the whole repository (`all`), reviewed at `4cedffa` on `feat/2026-10-07-review-audit-remediation`. The working tree was clean apart from this bundle. Addon version 1.11.0, `## Interface: 120100`, vendored LibKa0s v1.70.0 (`CLAUDE.md`: "Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).").

**Standards cross-check: performed** against the Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**. The index `standards/STANDARDS.md` was fetched verbatim with `curl` from `raw.githubusercontent.com/.../master`. The section-file fetch stalled on the network, so the 27 section files were read verbatim from the local sibling checkout `../WowAddonStandards/standards/standards/`. That checkout's `master` is `f472389`, and its index carries the same `v2.76.1, 2026-10-07` header as the fetched copy. No rule was reconstructed from memory.

---

## Measurement run (Step 0b: everything in this block was executed today, 2026-10-07)

Every run used the bounded runner at `/home/tushar/.claude/dev-copilot/bin/ka0s-bounded` (written `B` below), ran from the repo root, and wrote its output to a session scratch directory outside the repo. No committed artifact was written or modified.

| Suite | Result | Command | Counts |
|---|---|---|---|
| luacheck | **pass** | `B luacheck .` | `0 warnings / 0 errors in 69 files` |
| Headless suite | **pass** (1 declared skip) | `B lua5.1 tests/run.lua` | `876 passed, 0 failed, 1 skipped, 877 total`. The skip is `diagnostics contract: an addon that opts out lands the report and leaves logging off` (the addon keeps the default; the case above it covers the addon's real path) |
| `--list` inventory | **pass** (matches committed) | `B lua5.1 tests/run.lua --list > <scratch>/list.md` | `diff <(tr -d '\r' < docs/test-cases.md) <(tr -d '\r' < <scratch>/list.md)` is empty. The inventory's Totals row reads `877` (`docs/test-cases.md:1050`) and the README badge reads `Tests-876%2F876_passing` (`README.md:7`). See F-007 for why the two differ |
| Offline perf runner | **ran**, all assertions held (exit 0) | `B lua5.1 tests/perf.lua` | 1000 absorb events coalesced into 1 repaint. api/iter · bytes/iter: absorbEvent 0.0 · 0.0; paintPass 12.0 · 48.0; appearancePass 48.0 · 97.8; settingsRead 0.0 · 0.0; probeOverheadOff 12.0 · 48.0; probeOverheadOn 12.0 · 48.3 |
| Complexity (sighted) | **pass** | `B bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | `0 warnings (fun rate 0.00), 14461 NLOC / 2219 funcs, avg CCN 1.8 (max 14)`. Kit revision 37 (`tests/_kit/framework.lua:20`, `Kit.VERSION = 37`), so the run is sighted. The console line reports no blind files |
| `make test` | **not applicable** | none | No root `Makefile` |
| Vendor sync | **pass** | `diff -rq libs/LibKa0s ../LibKa0s/LibKa0s` and `diff -rq tests/_kit ../LibKa0s/testkit` | Both diffs are empty. The LibKa0s checkout is on `feat/2026-10-07-review-audit-remediation` at `353f286`, clean; `git describe --tags --abbrev=0` gives `v1.70.0` |
| Cross-addon (4 classes) | **pass**, clean | The four loops of the overlay's *cross-addon pass*, run from `GIT/` over the 11 rows of `WowAddonStandards/standards/ADDONS.md` | **Class 1:** 22 roots across 11 addons; `cut -f1 roots.txt \| uniq -d` printed nothing, and there are zero raw `SLASH_*` assignments in TOC-loaded source. **Class 2:** one line: `Bus:2 Compat:1 Core:10 DebugLog:19 Env:1 Item:2 Launcher:5 Lifecycle:3 Media:4 Options:28 Perf:14 Pool:3 Schema:2 Slash:19 Widgets:12`. **Class 3:** `diff -rq AbsorbTracker/libs/LibKa0s <each>/libs/LibKa0s` is empty for all 11 (the reference is AbsorbTracker). **Class 4:** one value, `## Interface: 120100`. The tag moved from the overlay baseline's v1.56.0 to v1.70.0, so the class-2 line differs from the baseline. That is a stale brief, not drift |

**Committed artifacts that disagree with today's run.** These are recorded as observations. Stale is not non-compliant, and regenerating them is release work.

- `docs/automated-tests/RESULTS.md`. Its newest bundle is `20260927-030336` (`manifest.json`: sha `9b5a369`, 810/0/810, 1919 functions, NLOC 13377). The runner reports it as "57 commit(s) behind HEAD". Today's run shows 2219 functions and NLOC 14461, still with max CCN 14 and 0 warnings. The watch list's `tests/test_slashcmds.lua | 1321` row is stale: the file is **1079** lines today (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | tr '\n' '\0' | xargs -0 wc -l | awk '$2!="total" && $1>1000'`, default scope). It shrank when the `/at profile` cases moved to `tests/test_slashprofile.lua` (`05f1f8c`). `tests/test_widgets.lua` is still at 1073, as recorded.
- `docs/performance.md:74` describes `paintPass` as "What does one coalesced repaint over three bars cost?" The scenario's numbers match today's run, but the scenario does not measure the coalesced repaint. See F-001.

In-client checks are not in this block. They are in `03_SMOKE_TESTS.md`.

---

## Medium

### F-001 — The offline "coalesced repaint" and "zero-overhead" scenarios measure a test-written fan-out, not the shipped `doRepaint`, so the `repaintPass` bracket is never measured `[tests]` `[perf]`

- **Where:** `tests/perf.lua:196-197` (`local paintPass = measure("paintPass", BURST, function()` / `NS.ForEachUnit(function(unit) NS.UpdateAbsorbBar(unit) end)`), the same body at `tests/perf.lua:224-225` (`probeOverheadOff`) and `:228-229` (`probeOverheadOn`). The ceiling comment `tests/perf.lua:241` reads `measured   48.0 bytes/pass, three consecutive runs`, and the constant `:252` is `local PROBE_OFF_BYTES_CEILING = 72`. The shipped path is `modules/Timer.lua:22` (`local t0 = Perf.on and debugprofilestop()`), `:40-41` (`NS.ForEachUnit(function(unit)` / `if NS.UpdateAbsorbBar(unit, parent) then painted = true end`) and `:48` (`if t0 then Perf.Note("repaintPass", debugprofilestop() - t0) end`).
- **Problem:** All three scenarios call `NS.UpdateAbsorbBar` through a closure the test builds itself. None of them enters `doRepaint`, so the `repaintPass` bracket and `doRepaint`'s own per-pass closure (which captures `painted` and `parent`) are never measured. performance-§9 requires the zero-overhead scenario to run "the addon's **hottest bracketed path**" (`performance.md:200`). `docs/performance.md:74` says `paintPass` answers the cost of "one coalesced repaint over three bars", which is `doRepaint`.
- **Evidence:** Today's 48.0 bytes/iter equals the cost of one 1-upvalue closure. A scratch Lua 5.1 probe measured `function(u) NS.UpdateAbsorbBar(u) end` at **48.8 B** per creation. So the 72-byte ceiling most likely bounds the test's own closure, not the addon's repaint pass. The same probe measured the shape `doRepaint` actually builds, a closure that closes over two fresh locals plus `NS`, at **144 B** per pass, above the 72-byte ceiling. That number is for the shape only, measured outside the addon, and is not a measurement of `doRepaint` (see F-002).
- **Impact:** The one regression the ceiling exists to catch, more allocation on the repaint path, can land in `doRepaint` and stay green. The "free when off" claim for the `repaintPass` bracket is unverified.
- **Reachability:** Only the offline perf evidence and the docs that cite it. The shipped code behaves correctly. The test cannot see `doRepaint`. Capped at Medium.
- **Coverage note:** `tests/test_timer.lua` covers `doRepaint` functionally (coalescing, the clear-before-paint order). The gap is only in the measurement.

---

## Low

### F-002 — `doRepaint` allocates a fresh closure on every coalesced pass `[perf]`

- **Where:** `modules/Timer.lua:40-42`: `NS.ForEachUnit(function(unit)` / `if NS.UpdateAbsorbBar(unit, parent) then painted = true end` / `end)`.
- **Problem:** Every throttled pass builds a new closure over two fresh locals. The file's own header (`modules/Timer.lua:13-16`) hoisted `doRepaint` "so RequestRepaint reuses ONE callback instead of allocating a fresh closure on every arm", and the inner fan-out then re-introduces one allocation per pass.
- **Impact:** Negligible in absolute terms. The newest committed capture, `docs/perf-analysis/20260909-013016/report.md`, records `repaintPass 130 calls, 9.16 ms total, 0.101 ms/s` over a 90.7 s active arm, and the throttle caps passes at 10/s. At the scratch shape figure of ~144 B per pass, the worst case is about 1.4 KB/s of garbage in sustained combat. **Unverified** for the real function, because no scenario measures it (F-001).
- **Reachability:** Any player with any bar enabled, on every coalesced repaint in combat.

### F-003 — `/at debug hold` arms its expiry timer while the addon is stood down for a perf capture `[correctness]`

- **Where:** `settings/Slash.lua:323` (`if NS.GetSetting("enabled") == false then`) is the only gate in `runHold`, and `:349` (`NS.HoldPreview(secs)`) arms the timer at `modules/Display.lua:115` (`previewTimer = NS.addon:ScheduleTimer(function()`).
- **Problem:** `runHold` checks the stored `enabled` path, not the latch. While the `perf` hold is taken (Experiment B), `paintHold` paints nothing because `NS.ShouldShowBar` answers false (`settings/Slash.lua:311`), but the verb still prints `Holding … on the bars` and arms a one-shot timer. When the timer expires it publishes `REPAINT` onto a stood-down bus. `core/Lifecycle.lua:43-44` says every timer is canceled while down. That holds for timers armed before the stand-down, not for one armed during it.
- **Impact:** One stray timer and a misleading chat line inside the suspended arm of a capture. Nothing is drawn and nothing is written.
- **Reachability:** Only a developer who types `/at debug hold` between `/at perf measure b` and `/at perf finish`. That is a debug sub-verb during a capture, so the finding is capped.

### F-004 — Standing up during combat leaves unlocked bars in preview for the whole fight `[correctness]` `[ux]`

- **Where:** The only combat re-lock is `core/AbsorbTracker.lua:318-320` (`local relocked = not NS.GetSetting("locked")` / `if relocked then` / `NS.SetByPath("locked", true)`), inside `OnEnterCombat`. `core/Lifecycle.lua:120` (`local function StandUp()`) and `OnEnable` (`core/AbsorbTracker.lua:67`) do not re-lock.
- **Problem:** preview-mode says a fight always starts on live data, and the addon enforces that only at `PLAYER_REGEN_DISABLED`. A stand-up that happens during combat, or a login or `/reload` during combat, brings the bars up in whatever lock state is stored. If that state is unlocked, the bars show the "Absorb" placeholder, live repaints stand down (`modules/Display.lua:437`, `if NS.InPreview() then`), and the bars stay draggable until the next combat starts.
- **Impact:** For that fight, the player sees a placeholder instead of their absorb.
- **Reachability:** The player has to disable the addon while unlocked (combat cannot re-lock a disabled addon, because its events are unregistered), then re-enable it mid-combat with `/at enable` or the minimap menu's Enabled entry. Both routes stay live in combat. A second route is a `/reload` or reconnect mid-combat on a profile that has never been locked. A fresh install ships `locked = false` (`docs/scope.md:12`). Both routes are rare.

### F-005 — Changing Master scale moves bars the player has dragged `[ux]` (**unverified in-client**)

- **Where:** `modules/Display.lua:234` (`bar:SetScale(NS.GetMasterScale())`), `modules/Display.lua:160` (`bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)`) and `modules/Bar.lua:21` (`local point, _, relPoint, x, y = bar:GetPoint()`).
- **Problem:** A dragged bar's position is saved as anchor offsets in the bar's own scaled coordinate space and restored unchanged. A frame's `SetPoint` offsets are scaled by that frame's effective scale, so raising Master scale from 1.0 to 2.0 should double each dragged bar's distance from its anchor. Nothing compensates. The default stack is unaffected, because its offsets are meant to scale with the bar.
- **Impact:** A player who places the bars and then changes Master scale finds them somewhere else, possibly clamped at a screen edge, and has to unlock and re-place them.
- **Reachability:** Any player who drags a bar and then moves the Master scale slider or uses `/at set scale`. **Unverified:** this follows from client frame semantics, not from a headless measurement. Smoke check S-05 confirms or refutes it. If it is confirmed, regrade to Medium.

### F-006 — A degraded-load case asserts a field the show ladder no longer reads `[tests]`

- **Where:** `tests/test_perf.lua:538` (`assertEqual(NS2.Perf.suspended, false, "and the show ladder sees a running addon")`). The stub field is at `core/PerfSetup.lua:26` (`suspended = false,`). The ladder's rung 0 is `modules/Display.lua:335` (`if NS.IsStoodDown() then return false end`).
- **Problem:** Since Perf minor 12, the ladder asks the latch, not `Perf.suspended` (`modules/Display.lua:315-316` says so in its own comment). The assertion message claims coverage of the show ladder, but the assertion only reads back a literal written into a table. It cannot fail for any reason connected to the ladder (testing-§12). The stub carries the field because LibKa0s's documented stub template still prints it (F-008).
- **Impact:** One inventory case reads as degraded-path ladder coverage and provides none. The ladder's degraded behavior is covered elsewhere: `tests/test_disabled.lua`, and `tests/test_bus.lua` on the degraded load.
- **Reachability:** The test inventory only. The shipped code is correct.

---

## Upstream (these land in LibKa0s, not here; never an edit under `libs/` or `tests/_kit/`)

### F-007 — The testkit's `--list` Totals count declared skips, while its own preamble says the badge must agree with that total `[upstream]` `[tests]`

- **Owner:** LibKa0s, `testkit/framework.lua`. It is vendored here as `tests/_kit/framework.lua:569` (`out(string.format("| **Total** | **%d** |", #tests))`) and `:576-577` ("The `## Totals` table below is the **authoritative pass count** — the README test badge and any count quoted in the docs must agree with it.").
- **Problem:** `#tests` includes declared skips, so the inventory's Totals row reads **877** (`docs/test-cases.md:1050`). testing-§5 (`testing.md:88-90`) says a skip "MUST NOT be folded into either the passed count or the total". The addon's badge follows that rule correctly at `876/876` (`README.md:7`), and so contradicts the generated preamble.
- **Impact:** Two committed figures disagree, and the generated text tells the reader that the compliant one is wrong. This applies to every consumer whose suite carries a declared skip, and the diagnostics-contract opt-out is one most addons inherit.
- **Reachability:** Docs and the test inventory only. No runtime effect.
- **Remediation:** Fix upstream in LibKa0s's `testkit/framework.lua`: total the passes-eligible cases, or add a `Skipped` row and word the preamble so the badge's X/Y is derivable. Bump `Kit.VERSION`, release, then re-vendor the whole `tests/_kit/` folder here as its own commit and regenerate `docs/test-cases.md` in that commit. **This is not a local edit.**

### F-008 — LibKa0s's Perf degradation-stub template still prints `suspended = false` `[upstream]` `[docs]`

- **Owner:** LibKa0s, `docs/api/Perf/version-14.1.1.6-docs.md:357` (`suspended = false,`), inside the host stub template that consumers copy.
- **Problem:** Perf minor 12 made `suspended` a view of the lifecycle latch. Hosts' show ladders ask the latch, so a stub member nobody reads is the "stub that re-implements" shape the overlay warns about, and it led to F-006's assertion.
- **Reachability:** Documentation only. No runtime effect.
- **Remediation:** Drop the field from the template upstream (doc-only, no minor bump). Each consumer then removes it from its own stub and any test that pins it. That part is F-006's local half.

---

## Non-findings worth recording (checked, clean)

- **Degradation stubs answer every member the addon calls.** Census over the TOC-derived load list (`tr -d '\r' < AbsorbTracker.toc | grep -iE '\.lua$' | grep -v '^#' | grep -v '^libs' | sed 's|\\|/|g'`) of `NS.Perf.*`, `NS.DebugLog.*`/`:*`, `NS.Launcher:*`, `NS.lifecycle:*` and `NS.Slash*`: every member called is present in its stub (`core/PerfSetup.lua:24-31`, `core/DebugLogSetup.lua:45-97`, `core/LauncherSetup.lua:90-103`, `core/Lifecycle.lua:168-190`, `settings/Slash.lua:642-700`).
- **Buckets match brackets.** Five declared (`core/PerfSetup.lua:62-75`) and five reached: `absorbEvent` `core/AbsorbTracker.lua:272`, `repaintPass` `modules/Timer.lua:48`, `paintBar` `modules/Display.lua:459`, `appearance` `:276`, `visibility` `:389`. The `within` declarations agree with the parents the brackets supply.
- **Disabled state is total.** One latch with two holds, no second teardown path, and `tests/test_disabled.lua` asserts on the mock's registration set.
- **Suite list.** `tests/run.lua` names exactly the 34 `tests/test_*.lua` files tracked (`diff` of `git ls-files 'tests/test_*.lua'` against the list is empty), and the kit hard-errors on a declared suite missing from disk (`tests/_kit/framework.lua:290`).
- **Localization.** English-only is a ratified `localization-§1` row in `docs/ARCHITECTURE.md` → Documented deviations. It is not re-filed here.
