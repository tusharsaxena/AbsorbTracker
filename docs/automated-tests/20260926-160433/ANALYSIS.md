# Analysis — 20260926-160433

- **Addon:** AbsorbTracker 1.10.0
- **Verdict:** green
- **Commit:** cc46bab71a457202627ec0b2b9041f47862340df (master)
- **Previous run:** 20260924-112145

## Headline

All four suites pass on a clean `master` ([`manifest.json`](manifest.json)). No function is above
CCN 15 and no file is over the `layout-§1` cap. The previous bundle measured `e84b6d8`, 23 commits
behind this one; since then the addon took the LibKa0s v1.60.0 and v1.61.0 re-vendors, the
`/at diagnostics` rollout (DR-AT-01..07) and the NavRail stub (NR-AT-01). The suite grew from 766
to 810 cases and the averages held, so the addon is bigger and no denser. Nothing new to act on;
this is not a release run.

## Suites

| Suite | Status | Result | Artifact | Moved since 20260924-112145 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 66 files | [`lint.txt`](lint.txt) | files 63 → 66; still 0/0 |
| tests | pass | 810 passed, 0 skipped, 0 failed, 810 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 766 → 810 cases, all passing |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 6 scenarios; every `api/iter` and `bytes/iter` figure unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | totals up, averages flat except avg tokens 46.2 → 46.5; max CCN 14 in both |

| Metric | Value |
|---|---|
| Total NLOC | 13366 |
| Functions | 1920 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.7 |
| Max CCN | 14 |
| Avg tokens / function | 46.5 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 3 |
| Files over the 1500 cap | 0 |

Every suite passed cleanly, so no suite needs a paragraph of its own.

## What moved

- **lint:** 63 → 66 files, 0/0 in both runs ([`lint.txt`](lint.txt)). The three new authored
  files in scope are `modules/Diagnostics.lua`, `tests/mock_menu.lua` and
  `tests/test_diagnostics.lua`. The other `.lua` files that arrived
  (`libs/LibKa0s/DebugLogDiagnostics.lua`, `libs/LibKa0s/OptionsNav.lua`,
  `tests/_kit/test_diagnostics_contract.lua`) sit under `.luacheckrc`'s `libs/` and `tests/_kit/`
  exclusions and are not in the count.
- **tests:** 766 → 810, 0 skipped in both ([`tests.txt`](tests.txt)). The new cases are the
  diagnostics suite and the kit's diagnostics contract, plus cases added to the launcher,
  visibility, drag-handle, disabled, docs, timer and debug-log suites.
  [`test-cases.md`](test-cases.md) is the authority on which cases ran.
- **perf:** the same six scenarios, and every `api/iter` and `bytes/iter` figure matches the
  previous run ([`perf.txt`](perf.txt)): `paintPass` 12.0 / 48.0, `appearancePass` 48.0 / 97.8,
  `probeOverheadOff` 12.0 / 48.0 and `probeOverheadOn` 12.0 / 48.3. The probe is still free with
  the capture off. `ms/iter` is for orientation only and is not compared across runs.
- **complexity:** NLOC 12353 → 13366 and functions 1783 → 1920. Avg NLOC 6.4 and avg CCN 1.7 in
  both runs; avg tokens 46.2 → 46.5. Max CCN is 14 in both, with 0 warnings
  ([`complexity.txt`](complexity.txt)); the two functions at 14 are `addon` in
  `core/AbsorbTracker.lua` (229–250) and `NS.ResolveColor` in `core/CoreSetup.lua` (54–65). That
  is growth, not densification. The band held at three files on notice and none over; only
  `tests/test_slashcmds.lua` moved (1318 → 1321, DR-AT-01).

## Complexity watch list

**Functions warned on (CCN > 15)**

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

**Files by `layout-§1` band**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_helpers.lua` | 1447 | **Peel next by helper group, carried forward** (AbsorbTracker-R-14). Unchanged since the previous run; 53 lines short of the cap. |
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1321 | **Back under the cap, watch.** 1318 → 1321 with DR-AT-01. Re-check at 1400; the next seam is the `/at profile` cases. |
| 1000–1500 (on notice) | `tests/test_widgets.lua` | 1073 | **Accepted, watch.** Unchanged since the previous run. Re-check at 1300. |

The full dispositions are in [`../RESULTS.md`](../RESULTS.md).

## Actions

1. `tests/test_helpers.lua`: peel by helper group before the next change that adds cases to it.
   This is already tracked as review finding AbsorbTracker-R-14 and is not new here.
