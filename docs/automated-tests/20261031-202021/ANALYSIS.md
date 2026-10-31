# Analysis — 20261031-202021

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** c873518cc9865cd88a228ec5f01ca299481914cd (feat/2026-10-31-font-pickers-skin-faces)
- **Previous run:** 20261009-191726

## Headline

This is the pre-merge run for the skin work, and all four suites pass on a clean tree, with no
function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). The
addon grew while the averages stayed flat. `tests/test_schema.lua` newly entered the 1000–1500 band,
and `appearancePass` got heavier, which is worth a look but is not on the combat path. No code
change is owed by this run.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261009-191726 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 78 files | [`lint.txt`](lint.txt) | 70 → 78 files, still 0/0 |
| tests | pass | 972 passed, 1 skipped, 0 failed, 973 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 886 → 973 total; the same one skip |
| perf | pass | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; `appearancePass` up, see below |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | grew in totals; averages and max unchanged |

| Metric | Value |
|---|---|
| Total NLOC | 16866 |
| Functions | 2575 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.8 |
| Max CCN | 14 |
| Avg tokens / function | 49.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |
| Blind files (parity mismatch) | 0 |
| Crashed files (lizard raised) | 0 |

**tests: one declared skip.** [`tests.txt`](tests.txt) line 947: *diagnostics contract: an addon
that opts out lands the report and leaves logging off*. This is the skip recorded at the previous
run. The addon keeps the default, so a diagnostics run turns logging on, and the kit skips the
opt-out branch with that reason. It is folded into neither passed nor failed, and it is a
pre-existing condition rather than a regression.

## What moved

The window is the 59 commits from `7c83d8c` to `c873518`: the LibKa0s re-vendors up to v1.83.0, the
keybinds and layout run, the skinning rollout, and the font pickers and skin faces.

- **lint**: 0/0, now over 78 files (70 before). The exclusions are unchanged (`libs/`, `docs/audits/`,
  `docs/reviews/`, `_dev/`, `tests/_kit/`, per `RESULTS.md`). The eight added files are
  `core/SkinSetup.lua` and seven test files.
- **tests**: 886 → 973 total, 885 → 972 passed, 0 failed, 1 skip on both sides.
- **perf**: `appearancePass` moved from 48.0 to 51.0 api/iter and from 97.8 to 2560.9 bytes/iter
  ([`perf.json`](perf.json)). Its `ms/iter` also rose, 0.05147 → 0.16370, but that is host timing,
  which is for orientation only. The scenario drives `NS.UpdateBarAppearance`, which runs from the
  APPEARANCE bus and settings changes, and `modules/Display.lua` gained the skin-resolving getters in
  this window (`0eeb68b`, `ebc071c`). That link comes from reading the code; this run did not bisect
  the allocation. `absorbEvent`, `paintBars`, `repaintPass`, `settingsRead`, `probeOverheadOff` and
  `probeOverheadOn` hold their `api/iter` and `bytes/iter`, so the repaint path did not get heavier.
- **complexity**: NLOC 14702 → 16866 and functions 2249 → 2575. Avg NLOC 6.4, avg CCN 1.8, avg
  tokens 49.2 and max CCN 14 are all unchanged ([`complexity.txt`](complexity.txt)), so the addon grew
  without getting denser. Both runs are sighted, so the whole function delta is real growth.
- **band**: 2 → 3 files. `tests/test_schema.lua` newly crossed at 1084, `tests/test_slashcmds.lua`
  moved 1079 → 1088 and `tests/test_widgets.lua` moved 1073 → 1076.

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1084 | **Newly crossed.** Accepted, watch: first run in the band. 83 functions, avg CCN 2.3, max 12; the growth is the skin seam's cases and the layout partition pins, and the file is one subject, schema integrity. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1088 | Carried: back under the cap, watch. 111 functions, avg CCN 1.4. Second release run in the band stands (2 of 3); this is not a release run. |
| 1000–1500 (on notice) | `tests/test_widgets.lua` | 1076 | Carried: Accepted, watch. 105 functions, avg CCN 2.0. Second release run carried as Accepted stands (2 of 3); this is not a release run. |

No file has reached the three-release limit of anti-pattern #53. `tests/test_widgets.lua` reaches it
at the next release run if it is still carried as Accepted.

## Actions

1. `tests/test_widgets.lua`: peel the four real-page `OnShow` cases and the strip block out (beside
   `tests/test_panelpages.lua`), or record a tracked deviation ID, before the 1.13.0 release run.
   Carried from the previous run; no issue tracks it yet.
2. `modules/Display.lua`: read `appearancePass`'s rise to 2560.9 bytes/iter against
   `tests/perf.lua`, and decide whether it matters on a settings-change path. New here; no issue
   tracks it yet.
