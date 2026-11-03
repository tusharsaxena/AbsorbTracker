# Analysis — 20261101-135329

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** amber
- **Commit:** e1cae29e83960cd989fdd11cb0ef2ea81aca14ea (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-122832

## Headline

Lint and tests pass on a clean tree, but `perf` failed two of its assertions ([`perf.txt`](perf.txt)): the move onto `S.HudFont` and `S.BarGloss` took `appearancePass` past both of its pins. This is a regression in e1cae29, not a pre-existing condition, and the next commit answers it. Complexity is clean.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-122832 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 81 files | [`lint.txt`](lint.txt) | unchanged, 81 files |
| tests | pass | 997 passed, 1 skipped, 0 failed, 998 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 992 → 998 total; the same one skip |
| perf | fail | 7 scenarios, 2 assertions failed | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `appearancePass` api/iter 81.0 → 87.0, bytes/iter 130.0 → 1296.8 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | NLOC 17411 → 17511, functions 2654 → 2669, avg tokens 49.6 → 49.7 |

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

The totals rose with the re-vendored library's size; the averages did not move but for 0.1 of a token, so this is size and not density.

**perf.** `perf.txt` names two failures: `appearancePass makes 87.0 API calls/pass, expected 81` and `appearancePass allocated 1296.8 bytes/pass, over the 442-byte ceiling`. A regression. The `opts` table `applyValueFont` builds per bar is the bytes; the six calls are the library's kind checks on each bar's status bar and value text. `perf` does not gate this commit, and it would gate a tag.

## What moved

- **lint:** clean as before.
- **tests:** six more cases since that run, from FS-AT-FIX debfe91 and e1cae29; the one skip is as before.
- **perf:** as above; every other scenario's `api/iter` is unchanged.
- **complexity:** max CCN stays 14.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1084 | Carried from `RESULTS.md`. |

## Actions

1. `modules/Display.lua`: reuse one `opts` table. New here, answered by the next commit.
2. `tests/perf.lua`: `APPEARANCE_API_CALLS` re-derived for the library's two reads per bar. New here, answered by the next commit.
3. Carried from 20261101-001603, still open: `tests/perf.lua`'s `APPEARANCE_BYTES_CEILING`. No deviation ID or review finding owns this yet.
