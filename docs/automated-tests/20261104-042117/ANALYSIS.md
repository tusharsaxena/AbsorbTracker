# Analysis — 20261104-042117

- **Addon:** AbsorbTracker 1.12.0
- **Verdict:** green
- **Commit:** 6529089 (feat/2026-11-01-full-skinning)
- **Previous run:** 20261102-115815

## Headline

All four suites pass on a clean tree, with no function above CCN 15, no blind file and no crashed file ([`manifest.json`](manifest.json)). This is round 6's closing run (R6-AT): it measures the 20 commits since `a58d9fb`, among them the LibKa0s v1.85.0 re-cuts, the picker-preview eye (R6-PV), the Sim mode checkbox (R6-SIM) and the README rename (R6-NAME). Nothing needs action.

## Suites

| Suite | Status | Result | Artifact | Moved since 20261102-115815 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 85 files | [`lint.txt`](lint.txt) | 84 → 85 files (new `tests/test_skin_picker_preview.lua`) |
| tests | pass | 1058 passed, 1 skipped, 0 failed, 1059 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 1034 → 1059 cases (+25) |
| perf | pass (recorded; gates the tag, not the commit) | 7 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 7 scenarios; api/iter unchanged, timings slower (see below) |
| complexity | pass (recorded; gates the tag, not the commit) | see below | [`complexity.txt`](complexity.txt) | totals rose, averages held |

| Metric | Value |
|---|---|
| Total NLOC | 18425 |
| Functions | 2832 |
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

Every suite is a clean pass. The one skipped case is the standing diagnostics-contract skip: this addon keeps `Kit.diagnostics.enablesLogging` at its default, so the opt-out branch does not apply and the case above it covers the behavior ([`tests.txt`](tests.txt)). It is a skip carrying its reason, not a pass. It has been there since 20261009-191726.

## What moved

- **lint:** 0/0 held; the file count rose 84 → 85 with the new `tests/test_skin_picker_preview.lua` ([`lint.txt`](lint.txt)).
- **tests:** 1034 → 1059 cases, 1033 → 1058 passed, skipped held at 1, failed held at 0 ([`tests.txt`](tests.txt)). The +25 are the picker-preview eye and unlock-mode pins (R6-PV), the Sim mode checkbox on Master controls (R6-SIM), the no-title-separator pin (R4-SEP) and cases repinned for the LibKa0s v1.85.0 re-cuts.
- **perf:** the same 7 scenarios, and `api/iter` did not move in any of them ([`perf.txt`](perf.txt)). `bytes/iter` held everywhere except `appearancePass`, 147.0 → 146.3. Timings were slower across the board: `appearancePass` 0.18943 → 0.29055 ms/iter, `repaintPass` 0.01228 → 0.01602, `paintBars` 0.01231 → 0.01302, `probeOverheadOn` 0.01308 → 0.01455. The tests suite's wall time also more than doubled, 14947 → 35122 ms ([`manifest.json`](manifest.json)), and this run shared the machine with the other repos' finish runs. That points to host load, not code, since call and allocation counts are unchanged. As the runner itself says, these timings are for orientation within a run and are not comparable across runs.
- **complexity:** NLOC 17996 → 18425 and functions 2763 → 2832, so the addon grew. Avg NLOC held at 6.4, avg CCN at 1.8 and max CCN at 14, while avg tokens moved 49.3 → 49.2. The code grew without getting denser. Warnings, blind files and crashed files all stayed at 0 ([`complexity.txt`](complexity.txt)).

## Complexity watch list

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_schema.lua` | 1097 | Carried forward: accepted, a single subject (schema integrity) whose length comes from its case count, not from tangle. It grew 1087 → 1097 this run. Re-check at 1300. |

## Actions

None.
