# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate. `perf` and `complexity` are recorded and never fail a run** —
they are read and compared, not thresholded. A `skip` is a suite that did not run at all,
which is never the same as a pass.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260804-233138`](20260804-233138/) | 1.9.0 | 0/0 | 28 | 470/470 | pass | 7574 | 1063 | 6.4 | 1.7 | 15 | 0 | **green** |
| [`20260804-214639`](20260804-214639/) | 1.9.0 | 0/0 | 28 | 470/470 | pass | 7574 | 1063 | 6.4 | 1.7 | 0 | 0 | **green** |
| [`20260804-182031`](20260804-182031/) | 1.9.0 | 0/0 | 28 | 469/469 | pass | 7532 | 1047 | 6.5 | 1.7 | 21 | 2 | **green** |

**Reading the Max CCN column: the `0` on the `20260804-214639` row is an instrument fault, not a
measurement.** One run stamp is affected — `20260804-214639`, and only that one. Test kits before
rev 6 derived max CCN by scanning `lizard`'s `!!!! Warnings` block, which does not exist once an
addon reaches zero warnings, so the field fell through to `0` at exactly the moment it was most
worth reading. The true figure for that run is in its own bundle:
[`20260804-214639/complexity.txt`](20260804-214639/complexity.txt) puts the maximum at **15**
(`Helpers.BuildMainContent`, `settings/About.lua`) — the same value the run after it records, over
byte-identical `complexity.txt` output. The generated row is left as generated: a hand-corrected
record is worse than a wrong one, because it reads as measured (`automated-tests-§1`,
`performance-§10`). So the `21 → 0 → 15` trend is really `21 → 15 → 15`.

## Test suite

470 cases, and it has not moved since [`20260804-214639`](20260804-214639/) — expected, since the
runs between then and now carried docs and generated artifacts rather than behavior. Covers the
absorb pipeline, the coalescing throttle, the bar/display modules and the settings schema; frame
rendering and taint stay in `docs/smoke-tests.md`. The generated inventory `test-cases.md` in each
bundle is the authority on what exists at that point — [`20260804-233138/test-cases.md`](20260804-233138/test-cases.md)
for the current state — and the README badge tracks the same number.

## Lint

Clean over 28 files as of [`20260804-233138`](20260804-233138/): 0 warnings, 0 errors
([`lint.txt`](20260804-233138/lint.txt)). **Those 28 files are the addon's own runtime source only.**
`.luacheckrc` sets `exclude_files = { "libs/", "docs/", "_dev/", "tests/" }`, so the vendored `libs/`
and the vendored `tests/_kit/` are out of scope — neither is this repo's to fix — but the blanket
`tests/` entry also takes this addon's **own** test files with it. The harness is checked by running,
not by linting; a `0/0` row here says nothing about `tests/`.

## Perf

Six scenarios as of [`20260804-233138`](20260804-233138/) — `absorbEvent`, `paintPass`,
`appearancePass`, `settingsRead`, `probeOverheadOff` and `probeOverheadOn`
([`perf.txt`](20260804-233138/perf.txt)). The last pair is the **zero-overhead** case
`performance-§2` requires as evidence that instrumentation is free when off. The suite has run —
this addon ships `tests/perf.lua`, so `perf` is a real pass and not a skip. Timings are orientation
only: compare scenarios within a run, never across machines. In-game captures cannot come from a
script and keep their own store at [`../perf-runs/`](../perf-runs/).

## Complexity watch list

Current state as of [`20260804-233138`](20260804-233138/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

**None.** No function in this addon's own source exceeds CCN 15.

That is a result, not an empty section. The last run that warned on anything was
[`20260804-182031`](20260804-182031/), and it listed exactly two functions: `runProfile`
(`settings/Slash.lua`) at CCN 21 and `NS:RunMigrations` (`core/Database.lua`) at CCN 19. Both were
peeled on `feat/fix-ccn` rather than accepted or deferred — `runProfile` onto a `PROFILE_VERBS`
dispatch table (`settings/Slash.lua:328`) with its help rows in `PROFILE_HELP`
(`settings/Slash.lua:299`), and `RunMigrations` onto a `SCHEMA_STEPS` ladder
(`core/Database.lua:167`) plus the two backfill helpers `backfillFlatKeys`
(`core/Database.lua:141`) and `backfillUnitKeys` (`core/Database.lua:152`). Neither disposition
carries forward, because neither function is on the list any more.

Nothing is over the line and exactly **one** function is *at* it: `Helpers.BuildMainContent`
(`settings/About.lua:38-104`) at CCN **15**. Naming the rest of the top of the list so the count is
not a bare number — behind it sit `addon:OnAbsorbChanged` (`core/AbsorbTracker.lua:164-185`, which `lizard` reports as
`addon`) and `NS.ValidateSchema`
(`settings/Schema.lua:224-261`), both at CCN 14, then `build` (`settings/Profiles.lua:16-66`) at 12;
that is every function at or above 12 in
[`20260804-233138/complexity.txt`](20260804-233138/complexity.txt). `BuildMainContent` is the one to
watch if the About page grows another block.

**Max CCN reads `15` again from [`20260804-233138`](20260804-233138/) onward.** The `0` on the
`20260804-214639` row is the pre-rev-6 kit parser fault described under the table above, not a
measurement — that run's own `complexity.txt` says 15. Test kit rev 6, vendored in with LibKa0s
v1.7.0, takes the CCN column of every function row instead of the `!!!! Warnings` block. Fixed
upstream and re-vendored rather than patched here (automated-tests-§2).

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1256 | **Accepted.** Still the only file in the band, and untouched by the CCN work. A flat list of independent cases, avg CCN 1.2 — length is case count, not tangle. Peel by verb group if it crosses 1400. |
