# Analysis — 20261031-212003

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** e8ba9484925183eabe153da87e658e1581a0def1 (feat/2026-10-31-findings-remediation)
- **Previous run:** 20261031-202021

## Headline

This is the post-remediation run. All four suites pass on a clean tree, with no function above CCN
15, no blind file and no crashed file ([`manifest.json`](manifest.json)). Two of the three files in
the 1000–1500 band left it, and `appearancePass` now reads 81.0 api/iter and 418.0 bytes/iter because
the scenario's counting layer was corrected. Nothing is left to act on in this repo.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261031-202021 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 80 files | [`lint.txt`](lint.txt) | 78 → 80 files, still 0/0 |
| tests | pass | 972 passed, 1 skipped, 0 failed, 973 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged in total; 23 cases moved between files; the same one skip |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; only `appearancePass` moved in calls or bytes |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | small growth in totals; averages and max unchanged; band 3 → 1 |

| Metric | Value |
|---|---|
| Total NLOC | 16935 |
| Functions | 2586 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.8 |
| Max CCN | 14 |
| Avg tokens / function | 49.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests: one declared skip.** [`tests.txt`](tests.txt) line 947: *diagnostics contract: an addon
that opts out lands the report and leaves logging off*. The addon keeps the default, so its report
turns logging on and the kit skips the opt-out branch with that reason. It is folded into neither
passed nor failed. It is a pre-existing condition, the same skip as the previous two runs, and at the
release gate it is NOT EVALUATED rather than passed.

## What moved

The window is the 8 commits from `c873518` to `e8ba948`, which include the merge of the skin runs and
the FX-AT remediation items.

- **lint**: 0/0, now over 80 files (78 before). The two added files are `tests/test_realpages.lua`
  and `tests/test_slashgate.lua`. The exclusions are unchanged (`libs/`, `docs/audits/`,
  `docs/reviews/`, `_dev/`, `tests/_kit/`, per `RESULTS.md`).
- **tests**: did not move in total, 973 with 972 passed, 0 failed, 1 skip. The per-file counts in
  [`test-cases.md`](test-cases.md) confirm the peels as moves: `tests/test_widgets.lua` 57 → 44 with
  `tests/test_realpages.lua` at 13, and `tests/test_slashcmds.lua` 67 → 57 with
  `tests/test_slashgate.lua` at 10.
- **perf**: `appearancePass` moved from 51.0 to 81.0 api/iter and from 2560.9 to 418.0 bytes/iter
  ([`perf.json`](perf.json)). This is a change to the measurement, not to the addon: commit `f064a38`
  edited `tests/perf.lua` and no shipped file, so the two rows do not compare as a before and after of
  the code. Per that commit, the scenario had not been counting `bar.border`, `bar.overlay` or
  `handle:ApplyLevel`, and the mock's per-lookup closures were being booked as the addon's garbage.
  `absorbEvent`, `paintBars`, `repaintPass`, `settingsRead`, `probeOverheadOff` and `probeOverheadOn`
  hold their `api/iter` and `bytes/iter`. `ms/iter` is host timing, for orientation only, and is not
  compared here. `appearancePass` now carries asserted ceilings in `tests/perf.lua`, and the suite
  passed with an empty `failures` table in [`perf.json`](perf.json).
- **complexity**: NLOC 16866 → 16935 and functions 2575 → 2586. Avg NLOC 6.4, avg CCN 1.8, avg tokens
  49.2 and max CCN 14 are all unchanged ([`complexity.txt`](complexity.txt)), so the addon did not get
  denser. Both runs are sighted.
- **band**: 3 → 1 files. `tests/test_widgets.lua` and `tests/test_slashcmds.lua` left the band.
  `tests/test_schema.lua` holds at 1084 and is the only entry. Nothing newly crossed.

**A correction to the previous analysis.** [`../20261031-202021/ANALYSIS.md`](../20261031-202021/ANALYSIS.md)
linked the `appearancePass` rise to the skin-resolving getters, from reading the code, and said it
had not bisected. Commit `f064a38` records the bisect, which puts the rise at `59147e7`, the
frame-layering commit, and not at the getters. That bundle stands as what was believed at the time.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1084 | Carried from `RESULTS.md`: accepted, watch; one subject, schema integrity; case count, not tangle. Re-check at 1300. |

No new row arrived, so no disposition was owed. Neither of the two rows that left the band remains
on the list, which closes the three-release concern the previous analysis raised for
`tests/test_widgets.lua`.

## Actions

None. Both actions of the previous analysis are closed: `tests/test_widgets.lua` was peeled
(`a00ab64`), and the `appearancePass` rise was read and pinned (`f064a38`). That commit reports part
of the remaining allocation as a LibKa0s gap in `handle:ApplyLevel`, which is outside this repo and
is not this addon's action.
