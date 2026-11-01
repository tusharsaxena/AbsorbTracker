# Analysis — 20261101-122832

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** d3c434abee756436c9251eeb22ed973ebd482f8c (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-025833

## Headline

This run measures the full skinning work on LibKa0s v1.85.0: the re-vendor, the bars' colors and shadow on the skin, schema v8 and the gloss layer. All four suites pass on a clean tree, with no function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). The suite grew by 17 cases; the one open action is the `appearancePass` byte ceiling, carried again.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-025833 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 81 files | [`lint.txt`](lint.txt) | 80 → 81 files, `tests/test_skin_flip.lua` |
| tests | pass | 991 passed, 1 skipped, 0 failed, 992 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 975 → 992 total; the same one skip |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; `appearancePass` bytes/iter 141.0 → 130.0, other `api/iter` and `bytes/iter` unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 16942 → 17411, functions 2589 → 2654, avg tokens 49.1 → 49.6 |

| Metric | Value |
|---|---|
| Total NLOC | 17411 |
| Functions | 2654 |
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

The totals rose because the addon and the vendored kit grew; average CCN and average NLOC did not move, so this is size and not density.

## What moved

- **lint:** clean as before, one more file in scope.
- **tests:** 17 more cases, all 17 in `tests/test_skin_flip.lua`; the one skip is the diagnostics contract's opt-out case, as before.
- **perf:** the seven scenarios and their `api/iter` are unchanged. The appearance pass allocates less. The mock client has no `CreateFont`, so `appearancePass` runs the FontString arm and does not measure the font object a live client uses.
- **complexity:** max CCN stays 14; `UpdateBarAppearance` lost its shadow branch to `applyValueFont` and `NS.GetFontShadow`.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1084 | Carried from `RESULTS.md`. |

## Actions

1. Carried from 20261101-001603, still open: `tests/perf.lua`'s `APPEARANCE_BYTES_CEILING` is 442 and the reading is now 130.0. Tighten it to the new reading. No deviation ID or review finding owns this yet.
