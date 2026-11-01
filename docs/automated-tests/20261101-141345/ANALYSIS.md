# Analysis — 20261101-141345

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** red
- **Commit:** 3460805e11de2160420fa438de2a935dc1d1ef09 (feat/2026-11-01-full-skinning)
- **Previous run:** 20261101-135534

## Headline

Red: one `eol` case failed ([`tests.txt`](tests.txt)), because the refresh note `docs/revendor/2026-11-01-v1.85.0/07_REFRESH_2.md` sat on disk with bare LF after a shell write. No addon or library behaviour failed. The note's terminators were repaired after this run; the next run measures the repaired tree.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261101-135534 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 81 files | [`lint.txt`](lint.txt) | unchanged |
| tests | fail | 996 passed, 1 skipped, 1 failed, 998 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | pass → fail, one `eol` case |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | `appearancePass` bytes/iter 146.4 → 136.1, api/iter unchanged |
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

**tests:** `eol: every tracked file carries the terminator .gitattributes declares for it` reports 18 of 18 bare LF terminators in the note. This is a regression of this tree, introduced by the refresh commit's note and not by the library. `git` stored the note correctly, so the fault was on disk only and the commit's content does not change.

## What moved

- **lint:** clean, same 81 files.
- **tests:** same 998 cases and the same one skip; 997 → 996 passed, the one failure above.
- **perf:** call counts are unchanged in all 7 scenarios. `appearancePass` reads 136.1 bytes against 146.4. The only code change since the previous run is `libs/LibKa0s/Toast.lua`, which is not on that path by anything this run shows, so the cause of that movement is not established.
- **complexity:** unchanged, max CCN 14.

## Complexity watch list

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1084 | Carried from `RESULTS.md`. |

## Actions

1. Repair `docs/revendor/2026-11-01-v1.85.0/07_REFRESH_2.md` with `rm` and `git checkout --`, then rerun. New here.
2. Carried, still open: `tests/perf.lua`'s `APPEARANCE_BYTES_CEILING` is 442 and the reading is 136.1. Tighten it to the settled reading. No deviation ID or review finding owns this yet.
