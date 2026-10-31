# Analysis — 20261101-001603

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** 6d934ed3fcdbbcc60ab216d775232b032135978d (feat/2026-10-31-findings-remediation)
- **Previous run:** 20261031-212003

## Headline

This run measures the LibKa0s v1.84.0 re-vendor. All four suites pass on a clean tree, with no
function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). The
suite grew by one case, and `appearancePass` fell from 418.0 to 141.0 bytes/iter, which matches the
library's `ApplyLevel` no longer allocating. One small follow-up is listed under Actions.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261031-212003 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 80 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 973 passed, 1 skipped, 0 failed, 974 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 973 → 974 total; the same one skip |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; only `appearancePass` moved in calls or bytes |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | small growth in totals; avg tokens down 0.1; avg NLOC, avg CCN, max and band unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 16942 |
| Functions | 2589 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.8 |
| Max CCN | 14 |
| Avg tokens / function | 49.1 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests: one declared skip.** [`tests.txt`](tests.txt) line 948: *diagnostics contract: an addon
that opts out lands the report and leaves logging off*. The addon keeps the default, so its report
turns logging on and the kit skips the opt-out branch with that reason. It is folded into neither
passed nor failed. It is a pre-existing condition, the same skip as the previous runs, and at the
release gate it is NOT EVALUATED rather than passed.

## What moved

The window is the 3 commits from `e8ba948` to `6d934ed`: the previous run's own record, the v1.84.0
re-vendor, and the citation correction that followed it.

- **lint**: did not move, 0/0 over 80 files ([`lint.txt`](lint.txt)). The exclusions are unchanged
  (`libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/`, per `RESULTS.md`), so the
  re-vendored library is outside this count.
- **tests**: 973 → 974 total, 972 → 973 passed, 0 failed, 1 skip. Comparing
  [`test-cases.md`](test-cases.md) with the previous bundle's shows one added case and nothing else:
  *the degraded stub answers OptionsCompose minor 15's PositionBlock with no rows and an inert hook*,
  which takes `test_optionssetup.lua` from 22 to 23.
- **perf**: `appearancePass` moved from 418.0 to 141.0 bytes/iter and held 81.0 api/iter
  ([`perf.json`](perf.json)). `tests/perf.lua` did not change in the window, so unlike the previous
  run this is not a change to the measurement. The likely cause is `libs/LibKa0s/WidgetsDragHandle.lua`
  minor 9, where `ApplyLevel` and the repaint stopped building a throwaway table per call. That is an
  attribution from the diff and the re-vendor's delta, not a separate measurement. The other six
  scenarios hold their `api/iter` and `bytes/iter`. `ms/iter` is host timing, for orientation only,
  and is not compared here. The `failures` table in [`perf.json`](perf.json) is empty.
- **complexity**: NLOC 16935 → 16942 and functions 2586 → 2589; avg tokens 49.2 → 49.1. Avg NLOC 6.4,
  avg CCN 1.8 and max CCN 14 did not move ([`complexity.txt`](complexity.txt)), so the addon did not
  get denser. The window's authored source change is the new stub in `settings/OptionsSetup.lua` and
  the new case in `tests/test_optionssetup.lua`. Both runs are sighted.
- **band**: 1 file, unchanged. `tests/test_schema.lua` holds at 1084. Nothing newly crossed.

## Complexity watch list

Functions `lizard` warned on:

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

Files by `layout-§1` band:

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1084 | Accepted — watch, carried forward from `RESULTS.md`. The entry did not change, so no new ruling is owed. |

## Actions

1. New here: `tests/perf.lua`'s `APPEARANCE_BYTES_CEILING` predates this reading and now sits well
   above it, so a regression could give back most of the `appearancePass` saving without tripping
   the assert. Tighten it to the new reading. No deviation ID or review finding owns this yet.
