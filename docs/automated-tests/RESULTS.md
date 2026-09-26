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

**Commit** is the short sha the run measured and **Tree** is whether that tree was clean at the
time. Both are read from git by the runner; neither is ever typed. A **dirty** row measured bytes
that no sha can bring back, so it is kept as an experiment honestly labeled rather than dropped —
and a release record is refused outright on a dirty tree, so no release row can be one.

A row reading `unknown` in both cells was recorded before the runner emitted them. That is what
the record holds about those runs — it is not `clean`, and it is not reconstructed from git
archaeology, for the same reason a skip is never a pass (`automated-tests-§4`).

| Run | Commit | Tree | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260926-160433`](20260926-160433/) | `cc46bab` | clean | 1.10.0 | 0/0 | 66 | 810/0/810 | pass | 13366 | 1920 | 6.4 | 1.7 | 14 | 0 | **green** |
| [`20260924-112145`](20260924-112145/) | `e84b6d8` | clean | 1.10.0 | 0/0 | 63 | 766/0/766 | pass | 12353 | 1783 | 6.4 | 1.7 | 14 | 0 | **green** |
| [`20260916-184524`](20260916-184524/) | unknown | unknown | 1.10.0 | 0/0 | 56 | 635/0/635 | pass | 10555 | 1479 | 6.5 | 1.7 | 14 | 0 | **green** |
| [`20260916-094435`](20260916-094435/) | unknown | unknown | 1.10.0 | 0/0 | 54 | 610/0/610 | pass | 10092 | 1425 | 6.4 | 1.7 | 15 | 0 | **green** |
| [`20260910-234511`](20260910-234511/) | unknown | unknown | 1.9.0 → 1.10.0 | 0/0 | 54 | 561/0/561 | pass | 9240 | 1266 | 6.6 | 1.7 | 15 | 0 | **green** |
| [`20260908-180922`](20260908-180922/) | unknown | unknown | 1.9.0 | 0/0 | 53 | 557/0/557 | pass | 9043 | 1261 | 6.5 | 1.7 | 15 | 0 | **green** |
| [`20260825-103352`](20260825-103352/) | unknown | unknown | 1.9.0 | 0/0 | 29 | 508/508 | pass | 7997 | 1126 | 6.5 | 1.7 | 14 | 0 | **green** |
| [`20260807-114413`](20260807-114413/) | unknown | unknown | 1.9.0 | 0/0 | 28 | 489/489 | pass | 7766 | 1088 | 6.5 | 1.7 | 15 | 0 | **green** |
| [`20260807-110443`](20260807-110443/) | unknown | unknown | 1.9.0 | 0/0 | 28 | 489/489 | pass | 7766 | 1088 | 6.5 | 1.7 | 15 | 0 | **green** |
| [`20260807-022551`](20260807-022551/) | unknown | unknown | 1.9.0 | 0/0 | 28 | 489/489 | pass | 7766 | 1088 | 6.5 | 1.7 | 15 | 0 | **green** |
| [`20260804-233138`](20260804-233138/) | unknown | unknown | 1.9.0 | 0/0 | 28 | 470/470 | pass | 7574 | 1063 | 6.4 | 1.7 | 15 | 0 | **green** |
| [`20260804-214639`](20260804-214639/) | unknown | unknown | 1.9.0 | 0/0 | 28 | 470/470 | pass | 7574 | 1063 | 6.4 | 1.7 | 0 | 0 | **green** |
| [`20260804-182031`](20260804-182031/) | unknown | unknown | 1.9.0 | 0/0 | 28 | 469/469 | pass | 7532 | 1047 | 6.5 | 1.7 | 21 | 2 | **green** |

## Test suite

**810 cases** — 810 passed, 0 failed, 0 skipped. The generated inventory
[`20260926-160433/test-cases.md`](20260926-160433/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **766 → 810** since the previous run.

No case reported a `skip`, so passed and total agree and nothing in this row claims coverage
that was not exercised.

## Lint

**0 warnings / 0 errors over 66 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 5 path(s) from it — `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**6 scenarios** from `tests/perf.lua`; the measurements are in
[`20260926-160433/perf.json`](20260926-160433/perf.json).

| `scenario` | `iters` | `ms/iter` | `api/iter` | `bytes/iter` |
|---|---|---|---|---|
| `absorbEvent` | 1000 | 0.00059 | 0.0 | 0.0 |
| `paintPass` | 1000 | 0.01561 | 12.0 | 48.0 |
| `appearancePass` | 200 | 0.03543 | 48.0 | 97.8 |
| `settingsRead` | 10000 | 0.00025 | 0.0 | 0.0 |
| `probeOverheadOff` | 1000 | 0.01301 | 12.0 | 48.0 |
| `probeOverheadOn` | 1000 | 0.01415 | 12.0 | 48.3 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20260926-160433`](20260926-160433/) — **this run's measurement, not its diff.** Max CCN **14** across 1920
functions, **0** of them warned on; 3 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_helpers.lua` | 1447 | **Peel next by helper group — carried forward.** 893 lines three runs back, 1171 at [`20260910-234511`](20260910-234511/), 1415 at [`20260916-094435`](20260916-094435/) and [`20260916-184524`](20260916-184524/), 1416 at the 2026-09-23 audit, and 1447 today: AT-19 (`de4dac3`) added 31 lines of printer-parts cases. Still a flat list of independent helper cases, avg CCN 1.5 over 139 functions, so the length is case count and not tangled control flow. The 1400 trigger fired two runs ago and the fix has not changed: peel by helper group before it reaches the 1500 cap. It is 53 lines short, so the next change that adds cases here peels first (review finding AbsorbTracker-R-14). |
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1321 | **Back under the cap — watch.** It was 1745 and over the cap at [`20260916-184524`](20260916-184524/). `/at perf` peeled out to `tests/test_perfcmds.lua` (528) and brought it to 1304, and AT-11 (`0e089ae`) moved the value hold to `tests/test_debughold.lua` (249) with its verb. The remediation's slash items (AT-02, AT-03, AT-04, AT-09) then added cases, which left it at 1318 at [`20260924-112145`](20260924-112145/), not the roughly 1200 the plan expected; DR-AT-01 (`8152b9d`) added three more, 1321 today. Avg CCN 1.3 over 140 functions, a flat case list. The seam for the next peel is already visible: the `/at profile` sub-dispatcher cases, split out by verb group the way `perf` and `hold` were. Re-check at 1400. |
| 1000–1500 (on notice) | `tests/test_widgets.lua` | 1073 | **Accepted, newly in the band — watch.** It was 904 at [`20260916-184524`](20260916-184524/) and 944 at the 2026-09-23 audit. AT-15 (`19761b8`) took it over 1000 with the Appearance strip pins (strip keys per unit and per tab, the mirrored-unit hint, chrome-band coverage). Avg CCN 2.0 over 100 functions and max 8, so the length is case count. The seam is the four real-page `OnShow` cases and the strip block, which read as a page-level suite apart from the widget-maker cases. Re-check at 1300. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

