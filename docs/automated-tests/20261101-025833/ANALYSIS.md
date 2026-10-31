# Analysis — 20261101-025833

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** 30b31c0b7a083e1bf5190303d332d9f19c9ea3ff (feat/2026-10-31-findings-remediation)
- **Previous run:** 20261101-001603

## Headline

This is the final pre-merge run, and it measures the addon after AceGUI-3.0-SharedMediaWidgets was
dropped for the `Ka0sMedia_*` pickers. All four suites pass on a clean tree, with no function above
CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). The suite grew by one
case net, and the one open action is the `appearancePass` byte ceiling carried from the previous run.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-001603 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 80 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 974 passed, 1 skipped, 0 failed, 975 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 974 → 975 total; the same one skip |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; `api/iter` and `bytes/iter` unchanged in all seven |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | every footer figure unchanged; three files moved, netting to zero |

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

**tests: one declared skip.** [`tests.txt`](tests.txt) line 949: *diagnostics contract: an addon
that opts out lands the report and leaves logging off*. The addon keeps the default, so its report
turns logging on and the kit skips the opt-out branch with that reason. It is folded into neither
passed nor failed. It is a pre-existing condition, the same skip as the previous runs, and at the
release gate it is NOT EVALUATED rather than passed.

## What moved

The window is the 5 commits from `6d934ed` to `30b31c0`: the previous run's own record, the refresh
to the re-cut v1.84.0 tag, the removal of the shared-media widgets, and two commits of notes on it.

- **lint**: did not move, 0/0 over 80 files ([`lint.txt`](lint.txt)). The authored file count held,
  because the removed library sits under `libs/`, which the lint excludes.
- **tests**: 974 → 975 total, 973 → 974 passed, 0 failed, 1 skip. Comparing
  [`test-cases.md`](test-cases.md) with the previous bundle's shows the changes all belong to the
  removal. One case left `test_optionssetup.lua` (23 → 22): *the live arm patches LSM30_Border
  through the library, not through a private copy*. `test_widgets.lua` went 44 → 46: two cases were
  reworded for the media rows and two were added, *every media row asks for a Ka0sMedia_* picker,
  none for an LSM30_* widget* and *the addon vendors and loads no AceGUI-3.0-SharedMediaWidgets*.
- **perf**: all seven scenarios hold their `api/iter` and `bytes/iter`, and `appearancePass` stays
  at 81.0 and 141.0 ([`perf.json`](perf.json)). The `failures` table is empty. Every `ms/iter` rose,
  but this is host timing, for orientation only, and is not compared here. The run's own duration
  also rose, from 20110 to 28748 ms in the two manifests, which is consistent with a busier host.
- **complexity**: every footer figure is identical to the previous run, and that is a real reading
  rather than a stale one. [`complexity.txt`](complexity.txt) shows `tests/test_widgets.lua` at 504
  → 523 NLOC and 72 → 74 functions, `tests/test_optionssetup.lua` at 383 → 365 and 54 → 52, and
  `settings/OptionsSetup.lua` at 109 → 108 with 53 functions. Those net to 0 NLOC and 0 functions.
  Both runs are sighted.
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

1. Carried from 20261101-001603, still open: `tests/perf.lua`'s `APPEARANCE_BYTES_CEILING` is 442
   and the reading is 141.0, so a regression could give back most of the saving without tripping
   the assert. Tighten it to the new reading. No deviation ID or review finding owns this yet.
