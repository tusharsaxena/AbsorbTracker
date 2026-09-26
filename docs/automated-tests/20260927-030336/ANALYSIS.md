# Analysis — 20260927-030336

- **Addon:** AbsorbTracker 1.10.0 → 1.11.0
- **Verdict:** green
- **Commit:** 9b5a369a95fe9a9bc8eb0fdc1ad448d75d55b8e2 (master)
- **Previous run:** 20260926-193105

## Headline

This is the release run for **1.11.0**. All four suites pass on a clean tree and no function is above
CCN 15, so all five release-gate conditions hold ([`manifest.json`](manifest.json)). Nothing moved
against `20260926-193105`. The eight commits between the two runs changed documentation, a
`.luacheckrc` comment and the previous run's own record, and no Lua a suite measures. Nothing newly
crossed a threshold. Nothing to act on before the tag.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260926-193105 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 67 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 810 passed, 0 skipped, 0 failed, 810 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged; the case inventory is identical |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 6 scenarios; every `api/iter` and `bytes/iter` figure unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | unchanged in every footer field |

| Metric | Value |
|---|---|
| Total NLOC | 13377 |
| Functions | 1919 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.7 |
| Max CCN | 14 |
| Avg tokens / function | 46.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |

Every suite passed cleanly, so no suite needs a paragraph of its own.

### Release gate

| Gate | Result | Detail |
|---|---|---|
| Lint | PASS | `suites.lint.status` pass, 0 warnings / 0 errors in 67 files |
| Tests | PASS | `suites.tests.status` pass, 0 failed of 810 |
| Perf | PASS | `suites.perf.status` pass, 6 scenarios from `tests/perf.lua` (measured, not the no-scenarios exception) |
| Complexity | PASS | `suites.complexity.status` pass, lizard 1.24.0 ran |
| CCN <= 15 | PASS | `suites.complexity.warnings` 0, max CCN 14 |

## What moved

- **lint**: 0/0 over 67 files, as before. The `.luacheckrc` exclusions (`libs/`, `docs/audits/`,
  `docs/reviews/`, `_dev/`, `tests/_kit/`) did not change; the one `.luacheckrc` edit in the window
  (AT-ATS-SDR) repointed a comment citation.
- **tests**: 810 → 810, and [`test-cases.md`](test-cases.md) is identical to the previous run's
  inventory. No test file changed in the window, so an unmoved count is expected here. `RESULTS.md`
  notes the count has been flat at 810 for three runs; the previous two were the automated-tests
  sweep's peel, which moved cases rather than adding them.
- **perf**: the same 6 scenarios, with `api/iter` and `bytes/iter` identical in every one
  ([`perf.json`](perf.json)). `ms/iter` is higher across the board (for example `paintPass`
  0.01268 → 0.01590, `appearancePass` 0.03417 → 0.04675). No source file changed between the runs, so
  this is host timing noise, not a claim about the code.
- **complexity**: every footer field matches the previous run, per
  [`complexity.txt`](complexity.txt): 13377 NLOC, 1919 functions, avg CCN 1.7, max 14, 0 warnings.
- **band**: still 2 files, both unchanged in length: `tests/test_slashcmds.lua` (1321) and
  `tests/test_widgets.lua` (1073).

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None. Zero functions above CCN 15 is what the release gate required, so an empty table is expected.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1321 | Back under the cap, watch. Unchanged at 1321; avg CCN 1.3 over 140 functions, max 5, a flat case list. Next peel seam is the `/at profile` sub-dispatcher cases. Re-check at 1400. First release run in the band (1 of 3). |
| 1000–1500 (on notice) | `tests/test_widgets.lua` | 1073 | Accepted, watch. Unchanged at 1073; avg CCN 2.0 over 100 functions, max 8, so the length is case count. Seam is the real-page `OnShow` cases and the strip block. Re-check at 1300. First release run carried as Accepted (1 of 3). |

Neither file was in the band at the previous release run (`20260910-234511`, 1.10.0), so 1.11.0 is
the first release run for both. Neither is near the three-release limit of anti-pattern #53.

## Actions

None.
