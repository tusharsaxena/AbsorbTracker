# Analysis — 20261102-115815

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** a58d9fb (feat/2026-11-01-full-skinning), SG-AT-1
- **Previous run:** 20261102-023612

## Headline

All four suites pass on a clean tree, with no function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). This run records SG-AT-1: `/at sim` is now a LibKa0s-Sim-1.0 session with the step window (`modules/Sim.lua`), replacing the timer-chained script.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-023612 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 84 files | [`lint.txt`](lint.txt) | 82 → 84 files (modules/Sim.lua and one more tracked Lua file) |
| tests | pass | 1033 passed, 0 failed, 1 skipped, 1034 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1024 → 1034 cases |
| perf | pass (recorded, non-gating) | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | single offline reading; the sim is not on a perf path |
| complexity | pass (recorded, non-gating) | max CCN 14, 0 warnings | [`complexity.txt`](complexity.txt) | totals rose, averages held |

| Metric | Value |
|---|---|
| Total NLOC | 17996 |
| Functions | 2763 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.8 |
| Max CCN | 14 |
| Avg tokens / function | 49.3 |
| Warnings (CCN > 15) | 0 |
| Blind files | 0 |
| Crashed files | 0 |

NLOC rose from 17795 and functions from 2713 with the new module. Avg NLOC and avg CCN held (6.4, 1.8) and avg tokens fell from 49.7, so this is growth, not density.

## What moved

- **tests:** `tests/test_sim.lua` was rewritten for the session: the verb row, the seam wrapping nothing, three scenarios with step waits, a start that holds and plays to the last step, a manual step, stop, a cleared preview and a debug hold ending the session, the unlocked placeholder, the disabled refusal and the launcher's Sim mode row.
- **lint, perf, complexity:** nothing beyond the above; the same one skip, the diagnostics contract's opt-out case.

## Complexity watch list

None.
