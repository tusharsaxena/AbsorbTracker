# Analysis — 20260924-112145

- **Addon:** AbsorbTracker 1.10.0
- **Verdict:** green
- **Commit:** e84b6d895b6d788d6ed51bbf9308978f61691880 (feat/2026-09-23-review-audit-remediation)
- **Previous run:** 20260916-184524

## Headline

All four suites pass on a clean tree. No function is above CCN 15 and no file is over the
`layout-§1` cap ([`manifest.json`](manifest.json)). This run replaces `20260916-184524` as the
current record. That bundle measured `1080857` on `master`, 74 commits behind the one measured
here. Since then the addon has taken the LibKa0s v1.55.0 and v1.56.0 re-vendors, the drag handle
strip and the 2026-09-23 remediation items (finding AbsorbTracker-A-20). The suite grew from 635
to 766 cases. The averages held, so the addon is bigger but no denser. The one file that was over
the cap, `tests/test_slashcmds.lua`, is back under it. There is nothing new to act on, and this is
not a release run.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260916-184524 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 63 files | [`lint.txt`](lint.txt) | files 56 → 63; still 0/0 |
| tests | pass | 766 passed, 0 skipped, 0 failed, 766 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 635 → 766 cases, all passing |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 6 scenarios; `appearancePass` 384.2 → 97.8 bytes/iter, every other api and bytes figure unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | totals up, averages flat, max CCN 14 in both |

| Metric | Value |
|---|---|
| Total NLOC | 12353 |
| Functions | 1783 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.7 |
| Max CCN | 14 |
| Avg tokens / function | 46.2 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

Every suite passed cleanly, so no suite needs a paragraph of its own.

## What moved

- **lint:** 56 → 63 files, 0/0 in both runs ([`lint.txt`](lint.txt)). Seven authored files
  arrived: `core/Lifecycle.lua`, `tests/prose_waivers.lua`, `tests/test_debughold.lua`,
  `tests/test_disabled.lua`, `tests/test_draghandle.lua`, `tests/test_events.lua` and
  `tests/test_perfcmds.lua`. None left. `tests/_kit/` stays in `.luacheckrc`'s exclusions, so the
  kit's files are not in the count.
- **tests:** 635 → 766, with 0 skipped in both ([`tests.txt`](tests.txt)). The new cases are the
  suites above (the stand-down latch, the value hold, the drag handle, event rejection and the
  peeled perf-verb cases), the kit's revision 26 gates, and the red-first cases the remediation
  items added. [`test-cases.md`](test-cases.md) is the authority on which cases ran.
- **perf:** the same six scenarios, and every `api/iter` figure is unchanged
  ([`perf.txt`](perf.txt)). Only `appearancePass` moved on bytes, 384.2 → 97.8. A per-commit
  replay of `tests/perf.lua` over `1080857..aa4c783` puts the whole drop on one commit, `7c43ab4`
  ("Give each unlocked bar the LibKa0s drag handle strip"): 385.8 before it, 97.8 from it on. That
  commit removed the unlocked-only unit label, and the label's font plumbing left
  `UpdateBarAppearance` with it. The 1.6-byte rise before that (384.2 → 385.8) arrived with
  `0e72839`, the Schema runtime adoption. `probeOverheadOff` and `probeOverheadOn` still match
  `paintPass` at 12 api calls per iteration, so the probe is still free with the capture off. The
  `ms/iter` column is for orientation only and is not compared across runs.
- **complexity:** NLOC 10555 → 12353 and functions 1479 → 1783. Avg NLOC went from 6.5 to 6.4 and
  avg tokens from 46.4 to 46.2, and avg CCN stayed at 1.7. Max CCN is 14 in both runs, with 0
  warnings ([`complexity.txt`](complexity.txt)). That is growth, not densification. The band moved
  from one file on notice and one over the cap to three on notice and none over.

## Complexity watch list

**Functions warned on (CCN > 15)**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_helpers.lua` | 1447 | **Peel next by helper group, carried forward** (AbsorbTracker-R-14). It was 1415 at the previous run, and AT-19 added 31 lines. It is 53 lines short of the cap. |
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1318 | **Back under the cap, watch.** It was 1745 and over the cap. The perf-verb and value-hold peels took it under, and the remediation's slash cases left it at 1318. Re-check at 1400; the next seam is the `/at profile` cases. |
| 1000–1500 (on notice) | `tests/test_widgets.lua` | 1073 | **Accepted, newly in the band, watch.** AT-15's Appearance strip pins took it over 1000. Re-check at 1300. |

The full dispositions are in [`../RESULTS.md`](../RESULTS.md).

## Actions

1. `tests/test_helpers.lua`: peel by helper group before the next change that adds cases to it.
   This is already tracked as review finding AbsorbTracker-R-14 and is not new here.
