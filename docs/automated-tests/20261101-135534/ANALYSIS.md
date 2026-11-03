# Analysis — 20261101-135534

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** 88c47ea130dc57f2e7806a568876e00dc1678927 (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-135329

## Headline

All four suites pass on a clean tree, with no function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). This run measures the bars on the library's `S.BarGloss`, `S.HudFont` and `Skin.FollowOnce` from the re-cut v1.85.0, and clears the two `appearancePass` failures of the run before it. One action is carried.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-135329 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 81 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 997 passed, 1 skipped, 0 failed, 998 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | fail → pass; `appearancePass` bytes/iter 1296.8 → 146.4, api/iter 87.0, the pin re-derived |
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
- **tests:** same 998 cases, same one skip, the diagnostics contract's opt-out case.
- **perf:** `appearancePass` is 87.0 calls and 146.4 bytes. Against the last green run, 20261101-122832, that is six more calls, the library's `GetObjectType` read on each bar's status bar and value text, recorded in `tests/perf.lua`, and 16.4 more bytes, under the unmoved 442 ceiling. The mock client has no `CreateFont` and its bars are no StatusBar, so `appearancePass` measures neither the font object nor the gloss layer a live client uses.
- **complexity:** unchanged, max CCN 14.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1084 | Carried from `RESULTS.md`. |

## Actions

1. Carried from 20261101-001603, still open: `tests/perf.lua`'s `APPEARANCE_BYTES_CEILING` is 442 and the reading is now 146.4. Tighten it to the new reading. No deviation ID or review finding owns this yet.
