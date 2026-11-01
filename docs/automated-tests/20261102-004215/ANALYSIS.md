# Analysis — 20261102-004215

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** ef652f7 (feat/2026-11-01-full-skinning), SF-AT-1
- **Previous run:** 20261101-201807

## Headline

All four suites pass on a clean tree, with no function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). This run records SF-AT-1: the value text now spans the bar, so a wider skin face is not clipped to "Absor".

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-201807 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 81 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1017 passed, 1 skipped, 0 failed, 1018 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1017 → 1018 cases |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `appearancePass` 87.0 api/iter, unchanged; ms/iter is a single offline reading |
| complexity | pass | max CCN 14, 0 warnings | [`complexity.txt`](complexity.txt) | totals rose, averages held |

| Metric | Value |
|---|---|
| Total NLOC | 17673 |
| Functions | 2699 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.8 |
| Max CCN | 14 |
| Avg tokens / function | 49.7 |
| Warnings (CCN > 15) | 0 |
| Blind files | 0 |
| Crashed files | 0 |

NLOC rose from 17661 and functions from 2698 with the new test case. Averages did not move, so this is no density signal.

## What moved

- **tests:** one new case pinning the value text's two-sided anchor, centered justification and no word wrap.
- **lint, perf, complexity:** nothing beyond the above; the same one skip, the diagnostics contract's opt-out case.

## Complexity watch list

None.
