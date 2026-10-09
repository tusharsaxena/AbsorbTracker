# Analysis — 20261009-191726

- **Addon:** AbsorbTracker 1.11.0 → 1.12.0
- **Verdict:** green
- **Commit:** 7c83d8c8dcb2a080dc36518b36a520a26f31bce3 (master)
- **Previous run:** 20260927-030336

## Headline

This is the release run for **1.12.0**. All four suites pass on a clean tree, no function is above
CCN 15 and `lizard` was blind in no file, so all six release-gate conditions hold
([`manifest.json`](manifest.json)). It is the first **sighted** release run: the previous release run
predates the kit revision 35 re-vendor and carries no `blindFiles` figure, so part of the function
count's growth is functions now measured that were always there. One test case is a declared skip
(below). Nothing newly crossed a threshold. Nothing to act on before the tag; `tests/test_widgets.lua`
is owed a decision before 1.13.0.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260927-030336 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 70 files | [`lint.txt`](lint.txt) | 67 → 70 files, still 0/0 |
| tests | pass | 885 passed, 1 skipped, 0 failed, 886 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 810 → 886 total; first skip on a release run |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | 6 → 7; `paintPass` split into `paintBars` and `repaintPass` |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | grew in totals, avg CCN 1.7 → 1.8, max unchanged at 14 |

| Metric | Value |
|---|---|
| Total NLOC | 14702 |
| Functions | 2249 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.8 |
| Max CCN | 14 |
| Avg tokens / function | 49.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |

**tests: one declared skip.** [`tests.txt`](tests.txt) line 860: *diagnostics contract: an addon
that opts out lands the report and leaves logging off*. The kit's diagnostics contract carries a case
for each branch of `Kit.diagnostics.enablesLogging`; this addon keeps the default (a diagnostics run
turns logging on), so the opt-out branch does not apply and the kit skips it with that reason. The
case beside it holds the branch this addon takes. It is folded into neither passed nor failed. It is
not a regression and not a coverage gap in this addon's code; it is the kit saying which half of its
contract this addon is on.

### Release gate

| Gate | Result | Detail |
|---|---|---|
| Lint | PASS | `suites.lint.status` pass, 0 warnings / 0 errors in 70 files |
| Tests | PASS | `suites.tests.status` pass, 0 failed of 886 (885 passed, 1 declared skip) |
| Perf | PASS | `suites.perf.status` pass, 7 scenarios from `tests/perf.lua` (measured, not the no-scenarios exception) |
| Complexity | PASS | `suites.complexity.status` pass, lizard 1.24.0 ran |
| CCN <= 15 | PASS | `suites.complexity.warnings` 0, max CCN 14 |
| Sighted | PASS | `suites.complexity.blindFiles` 0 |

## What moved

The window is the 73 commits from `9b5a369` to `7c83d8c`: the `/at profile <name>` verb, the
bar-strip tooltip placement, the combat re-lock on enable and reload, the Appearance strip moving to
the library's tabbed render, the LibKa0s re-vendors from v1.63.0 to v1.71.0 and the 2026-10-07
review/audit remediation.

- **lint**: 0/0, now over 70 files (67 before). The `.luacheckrc` exclusions (`libs/`,
  `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/`) are unchanged, per `RESULTS.md`.
- **tests**: 810 → 886 total, 885 passing. The count moved for the first time in four runs, which
  ends the flat-at-810 note `RESULTS.md` carried. The new cases come with the new behavior: the
  profile verb, the tooltip placement, the combat re-lock, the debug-coverage suite and the
  characterization cases written ahead of each library adoption. [`test-cases.md`](test-cases.md) is
  the authority on which.
- **perf**: AT-01 (`fde43d7`) made the offline runner measure the shipped repaint pass, so the old
  `paintPass` is now `paintBars` (12.0 api/iter, 48.0 bytes/iter, the old `paintPass` figures) plus a
  new `repaintPass` (12.0 api/iter, 0.0 bytes/iter). `probeOverheadOff` and `probeOverheadOn` fell from
  48.0 / 48.3 to 0.0 / 0.5 bytes/iter, since they now bracket that allocation-free pass
  ([`perf.json`](perf.json)). `absorbEvent`, `appearancePass` and `settingsRead` hold their `api/iter`
  and `bytes/iter`. `ms/iter` is host timing and is not compared across runs.
- **complexity**: NLOC 13377 → 14702 and functions 1919 → 2249, with avg NLOC flat at 6.4, avg CCN
  1.7 → 1.8 and max CCN unchanged at 14 ([`complexity.txt`](complexity.txt)). The totals rose with
  the addon and its test suite, and the function count also includes functions the
  unsighted 1.11.0 run never saw; this bundle cannot separate those two parts. The averages barely
  moved, so the code did not get denser.
- **band**: still 2 files. `tests/test_slashcmds.lua` fell 1321 → 1079 after the `/at profile` cases
  moved to `tests/test_slashprofile.lua`; `tests/test_widgets.lua` holds at 1073.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. Zero functions above CCN 15 is what the release gate required, and this is the first release
run where that claim covers every function (`blindFiles` 0). No function was newly measured above 15.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1079 | Back under the cap, watch. 1321 → 1079 after SD-FIN-01 peeled the `/at profile` cases; sighted, 110 functions, avg CCN 1.4, max 5. Second release run in the band (2 of 3). Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_widgets.lua` | 1073 | Accepted, watch. Unchanged at 1073; sighted, 105 functions (five newly measured), avg CCN 2.0, max 9, so the length is case count. Second release run carried as Accepted (2 of 3). Re-check at 1300. |

Neither file has reached the three-release limit of anti-pattern #53. `tests/test_widgets.lua` reaches
it at the next release if it is still carried as Accepted.

## Actions

1. `tests/test_widgets.lua`: peel the four real-page `OnShow` cases and the strip block out (beside
   `tests/test_panelpages.lua`), or record a tracked deviation ID, before the 1.13.0 release run. New
   here; no issue tracks it yet.
