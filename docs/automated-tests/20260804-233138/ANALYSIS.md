# Analysis — 20260804-233138

- **Addon:** AbsorbTracker 1.9.0
- **Verdict:** green
- **Commit:** ab2603e05d9a747acb0a455acc919f39ce515ca0 (feat/fix-ccn), dirty
- **Started:** 2026-08-04T23:31:38+05:30
- **Previous run:** [`20260804-214639`](../20260804-214639/)

## Headline

**This is the run that closes the CCN work, and it closes it by fixing the instrument, not the
code.** The source is identical to the previous run — [`complexity.txt`](complexity.txt) is
byte-for-byte the same file as `../20260804-214639/complexity.txt` — but this run was taken with
test kit rev 6, which reads the CCN column of every function row instead of scanning `lizard`'s
`!!!! Warnings` block. So [`manifest.json`](manifest.json) records `"maxCcn": 15` where the previous
run recorded `0`, and the record can finally say what it always meant: **zero functions above CCN
15, with the highest at exactly 15.** Both gating suites stay clean — 0 warnings / 0 errors across
28 files, 470 of 470 cases passing — and nothing moved in either.

## Suites

Every row links its artifact, so a reader gets from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since 20260804-214639 |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 28 files | [`lint.txt`](lint.txt) | unchanged — 0/0 in 28 files |
| tests | pass | 470 passed, 0 failed, 470 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | unchanged — 470/470, no case added or removed |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 6 scenarios; timings within run-to-run noise |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | source identical; **Max CCN 0 → 15**, an instrument fix |

### Complexity in full

Every field of `lizard`'s footer, plus the two derived file counts, from
[`manifest.json`](manifest.json)'s `suites.complexity` and the footer of
[`complexity.txt`](complexity.txt). The **averages** are the point: a total that rose because the
addon grew is a different fact from an average that rose because it got denser, and only the second
is a complexity signal. Here nothing rose at all — every figure but one is identical to the previous
run, and the one that changed changed because the kit learned to read it.

| Metric | Value | Previous run | Moved |
|---|---|---|---|
| Total NLOC | 7574 | 7574 | — |
| Functions | 1063 | 1063 | — |
| Avg NLOC / function | 6.4 | 6.4 | — |
| Avg CCN | 1.7 | 1.7 | — |
| Max CCN | **15** | 0 *(kit bug — the true value was 15)* | reported, not changed |
| Avg tokens / function | 45.4 | 45.4 | — |
| Warnings (CCN > 15) | 0 | 0 | — |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.00 / 0.00 | 0.00 / 0.00 | — |
| Files in the 1000–1500 band | 1 | 1 | — |
| Files over the 1500 cap | 0 | 0 | — |

All four suites ran. `perf` and `complexity` are **recorded, non-gating** — they inform, they do not
fail the run. No suite was skipped, so nothing here is a silence dressed as a pass.

## What moved

Almost nothing, and that is the finding. The commit under test (`ab2603e`) touched generated
artifacts and docs, not source; the peel itself landed in the previous run's commit (`fa9035c`).

- **Max CCN 0 → 15 — the instrument, not the code.** The previous run's kit derived max CCN from
  `lizard`'s `!!!! Warnings` block, which does not exist once an addon has zero warnings, so it fell
  through to `0` exactly when the number was most worth reading. Rev 6, vendored in with LibKa0s
  v1.7.0, takes the CCN column of every function row. Both runs' `complexity.txt` say **15**; only
  this run's manifest does. Fixed upstream and re-vendored rather than patched here
  (automated-tests-§2), and the previous row stands as generated (automated-tests-§1).
- **Complexity source figures: unchanged, all of them.** Total NLOC 7574, 1063 functions, avg NLOC
  6.4, avg CCN 1.7, avg tokens 45.4, warning rate 0.00 / 0.00. `diff` over the two bundles'
  `complexity.txt` is empty.
- **Lint: unchanged.** 0 warnings / 0 errors over the same 28 files ([`lint.txt`](lint.txt)).
- **Tests: unchanged.** 470 passed, 0 failed, 470 total — no case added since the previous run,
  which is what a docs-and-artifacts commit should look like ([`tests.txt`](tests.txt)).
- **Perf: unchanged in shape.** The same 6 scenarios, including the zero-overhead pair
  `probeOverheadOff` / `probeOverheadOn` ([`perf.txt`](perf.txt)). `appearancePass` reads 0.02176
  ms/iter against 0.02066 the previous run; API calls per pass (33.0) and bytes per pass (893.7) are
  identical, so that is wall-clock noise and not a cost change.

## Complexity watch list

### Functions `lizard` warned on

**None.** No function in this addon's own source exceeds CCN 15, and
[`complexity.txt`](complexity.txt)'s footer confirms it: `Warning cnt 0`, and
`No thresholds exceeded (cyclomatic_complexity > 15 …)`.

Exactly **one** function sits *at* the threshold rather than over it: `Helpers.BuildMainContent`
(`settings/About.lua`, lines 38–104) at CCN **15**. Behind it, two at CCN 14 — `addon:OnAbsorbChanged`
(`core/AbsorbTracker.lua`, lines 164–185; `lizard` reports it as `addon`) and `NS.ValidateSchema` (`settings/Schema.lua`, lines
224–261) — then `build` (`settings/Profiles.lua`, lines 16–66) at 12. That is the full set at or
above 12. `BuildMainContent` is the one to watch if the About page grows another block; none of the
four is warned on, and none needs a disposition.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1256 | **Accepted.** Still the only file in the band, and untouched by this commit. A flat list of independent cases, avg CCN 1.2 — length is case count, not tangle. Peel by verb group if it crosses 1400. |

## Actions

1. **`docs/automated-tests/RESULTS.md` — nothing further on max CCN.** The kit parser fault is fixed
   upstream in LibKa0s and re-vendored (test kit rev 6); the `0` in the `20260804-214639` row stands
   as generated, with the standing prose naming it. Do not hand-correct that row —
   `automated-tests-§1` and `performance-§10`: a hand-edited record reads as measured.
2. Nothing else. The watch list is empty by result, not by omission, and no suite was skipped.
