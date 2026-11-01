# Analysis — 20261101-141517

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** ab4def24dfdb78116d03ef7bc1d57ff531f14c91 (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-141345

## Headline

All four suites pass on a clean tree, with no function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). This run measures the second refresh of the re-cut LibKa0s v1.85.0, whose only payload change is `Toast.lua` minor 2, and clears the previous run's `eol` failure on the refresh note. One action is carried.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-141345 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 81 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 997 passed, 1 skipped, 0 failed, 998 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | fail → pass, the `eol` case |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | call and byte counts unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 17511 |
| Functions | 2669 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.8 |
| Max CCN | 14 |
| Avg tokens / function | 49.7 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

The totals did not move from the previous run, and neither did the averages.

## What moved

- **lint:** clean, same 81 files.
- **tests:** same 998 cases, same one skip, the diagnostics contract's opt-out case. The note's repair on disk cleared the one failure of the previous run.
- **perf:** every scenario's api/iter and bytes/iter match the previous run. `appearancePass` reads 136.1 bytes for the second run running, against 146.4 at 20261101-135534, under the unmoved 442 ceiling. The previous run's analysis did not establish a cause for that step, and this run does not either.
- **complexity:** unchanged, max CCN 14.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1084 | Carried from `RESULTS.md`. |

## Actions

1. Carried from 20261101-001603, still open: `tests/perf.lua`'s `APPEARANCE_BYTES_CEILING` is 442 and the reading is now 136.1. Tighten it to the settled reading. No deviation ID or review finding owns this yet.
