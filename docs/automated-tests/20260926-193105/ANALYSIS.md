# Analysis — 20260926-193105

- **Addon:** AbsorbTracker 1.10.0
- **Verdict:** green
- **Commit:** fb55f4407efb01275711c0cdb8281e422e5a3900 (feat/2026-09-26-automated-tests-sweep)
- **Previous run:** 20260926-160433

## Headline

All four suites pass on a clean tree ([`manifest.json`](manifest.json)). This is the automated-tests
sweep's closing run: since `20260926-160433` (which measured `cc46bab`) the branch took the LibKa0s
v1.62.0 re-vendor (AT-ATS-RV, AT-ATS-RVR) and the `tests/test_helpers.lua` peel (AT-ATS-01). The peel
did what it was for: `tests/test_helpers.lua` dropped out of the 1000–1500 band (1447 → 573 lines),
so the band holds 2 files instead of 3, while the suite stays at exactly 810 cases. No function is
above CCN 15 and nothing newly crossed. Not a release run.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260926-160433 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 67 files | [`lint.txt`](lint.txt) | files 66 → 67 (the new `tests/test_panelpages.lua`); still 0/0 |
| tests | pass | 810 passed, 0 skipped, 0 failed, 810 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged at 810; the 71 moved cases now split 40 in `test_helpers` + 31 in `test_panelpages` |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 6 scenarios; every `api/iter` and `bytes/iter` figure unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 13366 → 13377, functions 1920 → 1919; averages and max unchanged; band 3 → 2 |

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

## What moved

- **lint** — 67 files against 66, the one addition being `tests/test_panelpages.lua`. Still 0/0; the
  `.luacheckrc` exclusions (`libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/`) did not
  change, so the re-vendored `libs/LibKa0s/` is outside this count, as before.
- **tests** — 810 → 810. AT-ATS-01 moved cases verbatim rather than adding any, so an unmoved total is
  the expected result, not a stalled suite ([`test-cases.md`](test-cases.md)).
- **perf** — the same 6 scenarios. `api/iter` and `bytes/iter` are identical in every scenario, which
  is the comparable signal ([`perf.json`](perf.json)). The `ms/iter` figures are a little lower
  everywhere (for example `paintPass` 0.01561 → 0.01268), which is host timing noise and not a claim
  about the code.
- **complexity** — per [`complexity.txt`](complexity.txt): `tests/test_helpers.lua` went 994 NLOC / 139
  functions → 398 / 82, and the new `tests/test_panelpages.lua` carries 601 / 57, so the peel is
  function-neutral (139 = 82 + 57) and adds 5 NLOC of file headers. `tests/test_ltrap.lua` went 140 / 18
  → 145 / 17, touched by the LibKa0s v1.62.0 re-vendor (AT-ATS-RV), which accounts for the one fewer
  function; `tests/run.lua` gained one line for the new suite. All averages and max CCN 14 held.
- **band** — 3 → 2 files. `tests/test_helpers.lua` left it (573 lines). `tests/test_slashcmds.lua`
  (1321) and `tests/test_widgets.lua` (1073) are unchanged in length.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1321 | Back under the cap — watch. Unchanged at 1321; avg CCN 1.3 over 140 functions, max 5, a flat case list. Next peel seam is the `/at profile` sub-dispatcher cases. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_widgets.lua` | 1073 | Accepted — watch (second run in the band). Unchanged at 1073; avg CCN 2.0 over 100 functions, max 8, so the length is case count. Seam is the real-page `OnShow` cases and the strip block. Re-check at 1300. |

Both are test files whose length is case count, not tangle. Neither is at a release-run shelf-life
limit: this is not a release run, and neither has been carried as Accepted across three release runs.

## Actions

None. The one action the previous run named, peeling `tests/test_helpers.lua` (review finding
AbsorbTracker-R-14), landed as AT-ATS-01 and this run confirms it.
