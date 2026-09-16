# Analysis — 20260916-094435

- **Addon:** AbsorbTracker 1.10.0
- **Verdict:** green
- **Commit:** fcc9ebc80bb1e52582c0332e6ef81bceef4c02a0 (master), clean
- **Previous run:** [`20260910-234511`](../20260910-234511/)

## Headline

Green on all four suites, with zero functions above CCN 15 — the pair the tag is gated on. Nothing
regressed: 49 new test cases, lint unchanged at 0/0 over 54 files, perf unchanged at 6 scenarios, and
the addon grew by 852 NLOC without getting denser. The one thing to act on is size, not correctness:
`tests/test_slashcmds.lua` crossed the `layout-§1` 1500-line cap this run (1304 → 1539) and
`tests/test_helpers.lua` passed the 1400 trigger its own disposition set (1171 → 1415). Both are
flat lists of independent cases, so both want a peel, not a refactor.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260910-234511` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 54 files | [`lint.txt`](lint.txt) | unchanged |
| tests | pass | 610 passed, 0 skipped, 0 failed, 610 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +49 cases |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

| Metric | Value |
|---|---|
| Total NLOC | 10092 |
| Functions | 1425 |
| Avg NLOC / function | 6.4 |
| Avg CCN | 1.7 |
| Max CCN | 15 |
| Avg tokens / function | 45.8 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 1 |

Every figure above is [`manifest.json`](manifest.json)'s `suites.complexity`, which carries all eight
of `lizard`'s footer fields; the per-file rows behind the band counts are in
[`complexity.txt`](complexity.txt). No suite was skipped in this run, so no figure here stands in for
something that was not measured.

## What moved

- **lint** — 0 warnings / 0 errors over 54 files, identical to the previous run in every cell. The
  scope is unchanged too: `.luacheckrc` still excludes `libs/`, `docs/audits/`, `docs/reviews/`,
  `_dev/` and `tests/_kit/`.
- **tests** — 561 → 610 passed (+49), still 0 failed and 0 skipped, so passed and total agree and
  nothing claims coverage it did not exercise. The growth is the test-mode and settings-panel work
  landed since the previous run.
- **perf** — 6 scenarios in both runs, same names, same iteration counts, same allocation profile
  (`paintPass` 12.0 api/iter and 48.0 bytes/iter in both). Wall times moved within the noise a
  same-machine comparison allows — `appearancePass` 0.03922 → 0.02994 ms/iter, `probeOverheadOn`
  0.01057 → 0.00939 — and timings are orientation only, so the reading that matters is that the
  probe still costs nothing measurable when off: `probeOverheadOff` 0.00927 against `probeOverheadOn`
  0.00939, with identical api/iter.
- **complexity** — NLOC 9240 → 10092 (+852) over 1266 → 1425 functions (+159). Avg NLOC 6.6 → 6.4
  and avg tokens 46.9 → 45.8: the addon got **bigger and slightly less dense**, which is growth, not
  degradation. Avg CCN flat at 1.7, max CCN flat at 15, zero warned functions in both runs. The band
  counts moved: 2 files on notice and 0 over cap becomes 1 on notice and 1 over cap — not a third
  file crossing, but `tests/test_slashcmds.lua` moving up a band.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on
every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

None. `lizard` reports *No thresholds exceeded* and max CCN is 15, one below the warn line — the same
reading as the previous four runs.

### Files by `layout-§1` band

1 file on notice and 1 over the cap; both carry a disposition in
[`RESULTS.md`](../RESULTS.md#files-by-layout-1-band), and both are ruled **Peel next** rather than
accepted again. Neither is a complexity signal in the CCN sense: `tests/test_helpers.lua` averages
CCN 1.5 over 137 functions and `tests/test_slashcmds.lua` CCN 1.2 over 172, so what these numbers
measure is case count in one file, not tangled control flow. The band is not part of the release
gate, but the cap is a `layout-§1` MUST and an over-cap file has exactly three terminal states —
peeled, issue-tracked, or recorded in the deviation register. This run records the crossing and
picks none of the three on the owner's behalf.

## Actions

1. Peel `tests/test_slashcmds.lua` (1539 lines) by verb group, back under the 1500 cap — or give it
   one of `layout-§1`'s other two terminal states. It is over cap as of this run and
   `docs/ARCHITECTURE.md`'s `## Documented deviations` register has no row for it, so it is
   currently untracked in the addon's own bookkeeping. New here.
2. Peel `tests/test_helpers.lua` (1415 lines) by helper group. Its previous disposition named 1400
   as the trigger and the trigger has fired; acting now keeps it from repeating item 1.
