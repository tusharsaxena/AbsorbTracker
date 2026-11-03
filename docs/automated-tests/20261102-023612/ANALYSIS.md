# Analysis — 20261102-023612

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** 2a1f66e (feat/2026-11-01-full-skinning), SF-AT-2
- **Previous run:** 20261102-004215

## Headline

All four suites pass on a clean tree, with no function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). This run records SF-AT-2: `/at sim [stop]`, a made-up absorb fight played on the bars through the existing value hold.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-004215 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 82 files | [`lint.txt`](lint.txt) | 81 → 82 files (tests/test_sim.lua) |
| tests | pass | 1023 passed, 1 skipped, 0 failed, 1024 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1018 → 1024 cases |
| perf | pass (recorded, non-gating) | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `appearancePass` 87.0 api/iter, unchanged; ms/iter is a single offline reading |
| complexity | pass (recorded, non-gating) | max CCN 14, 0 warnings | [`complexity.txt`](complexity.txt) | totals rose, averages held |

| Metric | Value |
|---|---|
| Total NLOC | 17795 |
| Functions | 2713 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.8 |
| Max CCN | 14 |
| Avg tokens / function | 49.7 |
| Warnings (CCN > 15) | 0 |
| Blind files | 0 |
| Crashed files | 0 |

NLOC rose from 17673 and functions from 2699 with the sim code and its tests. Averages did not move, so this is no density signal.

## What moved

- **tests:** six new cases in `tests/test_sim.lua`: the verb row, bad word usage, `stop` with nothing running, a full run holding and releasing the bars, `stop` clearing the hold, and the disabled refusal.
- **A red run was discarded before this one.** A first run of this commit failed the eol case because `tests/test_sim.lua` had one bare LF terminator; it was fixed in the same commit and that unrecorded bundle removed.
- **lint, perf, complexity:** nothing beyond the above; the same one skip, the diagnostics contract's opt-out case.

## Complexity watch list

None.
