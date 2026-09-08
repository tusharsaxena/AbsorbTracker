# Analysis — 20260908-180922

- **Addon:** AbsorbTracker 1.9.0
- **Verdict:** green
- **Commit:** 697dc55b4aefed9f81a769bad43fee5799d31ae8 (`feat/2026-09-07-audit-review-remediation`), clean
- **Previous run:** [`20260825-103352`](../20260825-103352/)

## Headline

All four suites pass. Lint is 0/0 over 53 files, the harness runs 557 cases with none failed and
none skipped, six perf scenarios record, and `lizard` warns on nothing at max CCN 15 across 1261
functions. Nothing here needs acting on.

What this run is actually for is the record rather than the result. It is the first bundle written
by test-kit revision 15, and the first one whose `RESULTS.md` was produced end to end by the runner:
the lead-in, the four standing suite sections and the complexity watch list all come out of this
run's own manifest and `lizard` output instead of being typed by hand and left to rot. Until today
the runner wrote one table row and a fixed paragraph, so the two tables `automated-tests-§4` asks
for had no producer, and this repository's watch list still described `20260807-114413` — two runs
and a whole remediation cycle ago.

The addon also grew a great deal between the two runs, and every counter says so at once: 29 → 53
linted files, 508 → 557 cases, 7997 → 9043 NLOC, 1126 → 1261 functions. That is this cycle's work
landing, not a measurement artefact.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260825-103352` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 53 files | [`lint.txt`](lint.txt) | File count 29 → 53; the 0/0 is unchanged |
| tests | pass | 557 passed, 0 skipped, 0 failed, 557 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | 508 → 557 |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | Same six scenarios; allocation per iteration fell sharply — see *What moved* |
| complexity | pass | 0 warnings, max CCN 15 | [`complexity.txt`](complexity.txt) | Totals up with the addon; averages flat |

**Complexity in full**, because one figure cannot be compared across a change in size. Every value
comes from [`manifest.json`](manifest.json)'s `suites.complexity` and is corroborated by
[`complexity.txt`](complexity.txt)'s footer.

| Metric | `20260825-103352` | This run |
|---|---|---|
| Total NLOC | 7997 | 9043 |
| Functions | 1126 | 1261 |
| Avg NLOC / function | 6.5 | 6.5 |
| Avg CCN | 1.7 | 1.7 |
| Max CCN | 14 | 15 |
| Avg tokens / function | 45.2 | 46.7 |
| Warnings (CCN > 15) | 0 | 0 |
| Warn rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 | 0.00 / 0.00 |
| Files 1000–1500 | 1 | 2 |
| Files over 1500 | 0 | 0 |

The averages are the point. NLOC rose 13% and function count rose 12%, and average NLOC per
function did not move at all — the addon got bigger without getting denser, which is the only
combination in which a rising total is not a complexity signal. Average tokens per function moved
45.2 → 46.7, about 3%, which is within the same reading.

No suite was skipped: `lua 5.1.5`, `luacheck 1.2.0` and `lizard 1.24.0` were all present and all ran
([`manifest.json`](manifest.json), `host`).

## What moved

- **lint** — 29 → 53 files at 0 warnings and 0 errors. The file count nearly doubled because this
  cycle put files into the linted scope, not because the exclusions changed; `.luacheckrc` still
  excludes `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/` and `tests/_kit/`.
- **tests** — 508 → 557, a gain of 49 cases, none failed and none skipped. `docs/test-cases.md` and
  the README badge already read 557, so nothing in this commit moves a count claim; the bundle's own
  [`test-cases.md`](test-cases.md) is byte-identical to `docs/test-cases.md` at HEAD.
- **perf** — the same six scenarios, and the interesting column is `bytes/iter`, which fell in three
  of them: `paintPass` 312.0 → 48.0, `probeOverheadOff` 312.0 → 48.0, `probeOverheadOn` 312.3 →
  48.3, and `appearancePass` 893.7 → 384.5. `api/iter` is unchanged on all but `appearancePass`
  (45.0 → 48.0). Allocation per repaint dropped by roughly six-sevenths while the API call count
  held, which is what this cycle's paint work was for. `ms/iter` rose in the same scenarios
  (`paintPass` 0.00556 → 0.00932); timings are for orientation only and are not comparable across
  runs or machines (`performance-§9`), so the allocation figures are the ones to read here and the
  milliseconds are not.
- **complexity** — no function is above CCN 15, and the maximum is `NS.ValidateSchema`
  (`settings/Schema.lua@243-285`) at exactly 15, up from 14 at the previous run. The three next
  highest are `addon:OnAbsorbChanged` at 14 (`core/AbsorbTracker.lua@167-188`), `NS.ResolveColor` at
  14 (`core/CoreSetup.lua@53-64`) and an anonymous case at 12 in `tests/test_schema.lua`.
- **Band** — `tests/test_helpers.lua` entered the 1000–1500 on-notice band. It was 893 lines at the
  previous run's commit and is 1171 now, crossing at 1044 when the settings panel became three pages
  with tab strips. `tests/test_slashcmds.lua` moved 1282 → 1296 in the same change. Both carry a
  disposition in `RESULTS.md`; no file is over the 1500 cap.

## What this run removed from the record, deliberately

The `RESULTS.md` watch list this run replaced was hand-written, and it carried a table the runner
does not produce: four functions at CCN 12–15 that `lizard` never warned on, listed as a *watch*
list rather than a warned list. `automated-tests-§4` keys the generated table on `lizard`'s own
warnings block, so those rows had no producer and are gone. Their content is not lost — it is
recorded here, which is where a judgment about a run belongs:

- `Helpers.BuildMainContent` (`settings/About.lua`) was held at "at the line, not over it", with the
  note that one more content block would push the About page's straight-line builder over. It is
  **no longer in the top four at all**, and does not appear above CCN 12 in this run's output.
- `NS.ValidateSchema` (`settings/Schema.lua`) was accepted as a flat list of independent row
  assertions where each `if` is one rule. It has moved 14 → 15 and is now this addon's maximum. That
  reading still holds, and the headroom is now zero: one more rule warns, and a warning blocks a
  tag.
- `addon:OnAbsorbChanged` (`core/AbsorbTracker.lua`) was accepted as the per-unit relevance ladder
  the handler exists to be. Unchanged at 14.
- `build` (`settings/Profiles.lua`) was accepted well under the line at 12. Unchanged at 12, span
  now `16-80`.

## The `ANALYSIS.md` gap, noted once

Six of this repository's seven earlier bundles carry an `ANALYSIS.md`; `20260825-103352` does not,
and it is not getting one. Writing an analysis today into a folder stamped in August would be a
record of a reading nobody took, dated to a day nobody took it — which is worse than a gap, because
a gap is legible. The fix is forward: this bundle has one, and every bundle from here on gets one at
the time of its run. Collection-wide the same gap stands at 37 of 95 bundles and is closed the same
way.

## Actions

None. Four green suites, no warned function, no file over cap, nothing regressed, and no
disposition due for conversion — the three-consecutive-release-runs clock (`automated-tests-§4`) has
still not started, because every manifest in this directory carries `"release": null`, this one
included.
