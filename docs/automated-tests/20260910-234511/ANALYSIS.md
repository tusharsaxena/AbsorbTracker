# Analysis — 20260910-234511

- **Addon:** AbsorbTracker 1.9.0 → 1.10.0
- **Verdict:** green
- **Commit:** 3d559c9b3a9e (master), clean
- **Previous run:** [`20260908-180922`](../20260908-180922/)

## Headline

The release run for **1.10.0**, and it is green on all four suites with zero functions above CCN 15 — the two conditions the tag is gated on. Nothing regressed against the previous run: four new test cases, one new lint file, and 197 more NLOC, all of it the interface bump and the settings work settling. There is nothing to act on.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260908-180922` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 54 files | [`lint.txt`](lint.txt) | see below |
| tests | pass | 561 passed, 0 skipped, 0 failed, 561 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | see below |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 9240 |
| Functions | 1266 |
| Avg NLOC / function | 6.6 |
| Avg CCN | 1.7 |
| Max CCN | 15 |
| Avg tokens / function | 46.9 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 2 |
| Files over the 1500 cap | 0 |

## What moved

- **lint** — 54 files, up one from 53. Still 0 warnings / 0 errors.
- **tests** — 561 passed, up 4 from 557. No skips, no failures, in either run.
- **perf** — 6 scenarios, unchanged.
- **complexity** — NLOC 9043 → 9240 (+197) over 1261 → 1266 functions (+5). Avg NLOC 6.5 → 6.6 and avg tokens 46.7 → 46.9: the addon grew slightly, it did not get denser. Avg CCN flat at 1.7, max CCN flat at 15, zero warnings in both runs. Two files in the 1000–1500 band in both runs, none over the cap.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. Zero functions above CCN 15 is what the release gate required, and it is what this run measured — max CCN 15.

### Files by `layout-§1` band

2 file(s) in the 1000–1500 on-notice band, 0 over the 1500 cap. Each carries a disposition in [`RESULTS.md`](../RESULTS.md#files-by-layout-1-band). The band is not part of the release gate.

## Actions

None. Both band entries carry a current disposition and neither newly crossed this cycle.
