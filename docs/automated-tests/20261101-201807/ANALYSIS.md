# Analysis — 20261101-201807

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** 9e7cf8cbb4166c7e1b9f90ac9c96f90cdb147581 (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-141517

## Headline

All four suites pass on a clean tree, with no function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). This run measures the third refresh of the re-cut LibKa0s v1.85.0, kit revision 50, with the typed-value gate and the skin-switch test adopted. One action is carried.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-141517 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 81 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 1016 passed, 1 skipped, 0 failed, 1017 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 998 → 1017 cases |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `appearancePass` 136.1 → 136.7 bytes/iter; every call count unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | totals rose, averages held |

| Metric | Value |
|---|---|
| Total NLOC | 17661 |
| Functions | 2698 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.8 |
| Max CCN | 14 |
| Avg tokens / function | 49.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.0 / 0.0 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

Total NLOC rose from 17511 and functions from 2669, because the addon grew. Avg NLOC and avg CCN did not move, and avg tokens fell from 49.7, so this is no density signal.

## What moved

- **lint:** clean, same 81 files. `STANDARD_TEXT_FONT` joined `.luacheckrc`'s read globals, for the degraded `S.HudFont`.
- **tests:** 19 new cases: 3 for the typed-value gate, 11 for the skin switch and 5 in `test_skin_flip`. Same one skip, the diagnostics contract's opt-out case. The gate needed no allow row.
- **perf:** `appearancePass` stays at 87 api/iter, and its 136.7 bytes/iter sit under the unmoved 442 ceiling. Its ms/iter rose from 0.1945 to 0.2338 in a single offline run, and that figure alone says nothing about a cost. The other scenarios' api/iter and bytes/iter match the previous run.
- **complexity:** max CCN 14, no warning.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1087 | Carried from `RESULTS.md`. |

## Actions

1. Carried from 20261101-001603, still open: `tests/perf.lua`'s `APPEARANCE_BYTES_CEILING` is 442 and the reading is now 136.7. Tighten it to the settled reading. No deviation ID or review finding owns this yet.
