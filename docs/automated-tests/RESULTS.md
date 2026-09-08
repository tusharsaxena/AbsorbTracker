# Automated test results

<!-- Regenerated whole by tests/_kit/run-automated-tests.sh on every run. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->
<!-- Everything here is generated EXCEPT the watch list's Disposition column. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate the run and gate the commit** (`testing-§4`).
**`perf` and `complexity` never fail a run and never block a commit** — they are recorded,
read and compared, not thresholded (`performance-§9`, `performance-§10`).

**The tag is gated on all four suites at `pass`, plus zero functions above CCN 15**
(`automated-tests-§3`, *The release gate*), evaluated by `/wow-addon:bump-version` from the
`manifest.json` the release run writes — not by this script, whose exit code is unchanged.

A `skip` is a suite that did not run at all. It is never a pass, and at the release gate it is
**NOT EVALUATED** rather than passed: install the tool and re-run. A `—` is a suite that was
not selected, which is a different fact again.

The **Tests** cell reads `passed/skipped/total`.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260908-180922`](20260908-180922/) | 1.9.0 | 0/0 | 53 | 557/0/557 | pass | 9043 | 1261 | 6.5 | 1.7 | 15 | 0 | **green** |
| [`20260825-103352`](20260825-103352/) | 1.9.0 | 0/0 | 29 | 508/508 | pass | 7997 | 1126 | 6.5 | 1.7 | 14 | 0 | **green** |
| [`20260807-114413`](20260807-114413/) | 1.9.0 | 0/0 | 28 | 489/489 | pass | 7766 | 1088 | 6.5 | 1.7 | 15 | 0 | **green** |
| [`20260807-110443`](20260807-110443/) | 1.9.0 | 0/0 | 28 | 489/489 | pass | 7766 | 1088 | 6.5 | 1.7 | 15 | 0 | **green** |
| [`20260807-022551`](20260807-022551/) | 1.9.0 | 0/0 | 28 | 489/489 | pass | 7766 | 1088 | 6.5 | 1.7 | 15 | 0 | **green** |
| [`20260804-233138`](20260804-233138/) | 1.9.0 | 0/0 | 28 | 470/470 | pass | 7574 | 1063 | 6.4 | 1.7 | 15 | 0 | **green** |
| [`20260804-214639`](20260804-214639/) | 1.9.0 | 0/0 | 28 | 470/470 | pass | 7574 | 1063 | 6.4 | 1.7 | 0 | 0 | **green** |
| [`20260804-182031`](20260804-182031/) | 1.9.0 | 0/0 | 28 | 469/469 | pass | 7532 | 1047 | 6.5 | 1.7 | 21 | 2 | **green** |

## Test suite

**557 cases** — 557 passed, 0 failed, 0 skipped. The generated inventory
[`20260908-180922/test-cases.md`](20260908-180922/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **508 → 557** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 53 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` sets `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`, so those paths
are not in it. A `0/0` that never moves is partly a statement about what was never looked at, which
is why the exclusion is restated on every run.

## Perf

**6 scenarios** from `tests/perf.lua`; the measurements are in
[`20260908-180922/perf.json`](20260908-180922/perf.json).

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260908-180922`](20260908-180922/) — **this run's measurement, not its diff.** Max CCN **15** across 1261
functions, **0** of them warned on; 2 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_helpers.lua` | 1171 | **Accepted.** Newly in the band, and the crossing is dated: 893 lines at the previous run's commit, 1044 when the settings panel became three pages with tab strips, 1171 today. It is a flat list of independent helper cases at avg CCN 1.2, so the length is case count and not tangle — the same reading `test_slashcmds.lua` has carried since it crossed. Peel by helper group if it crosses 1400. |
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1296 | **Accepted.** Not newly crossed — it entered the band at 1256 on [`20260804-233138`](20260804-233138/), sat at 1282 through the August runs, and took 14 lines to 1296 when the settings panel became three pages. No longer the only file in the band. A flat list of independent cases, avg CCN 1.2 — length is case count, not tangle. Peel by verb group if it crosses 1400. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

