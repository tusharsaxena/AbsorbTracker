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
(`automated-tests-§3`, *The release gate*), evaluated by `/dev-copilot:bump-version` from the
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
| [`20261009-191726`](20261009-191726/) | `7c83d8c` | clean | 1.11.0 → 1.12.0 | 0/0 | 70 | 885/1/886 | pass | 14702 | 2249 | 6.4 | 1.8 | 14 | 0 | **green** |
| [`20260927-030336`](20260927-030336/) | `9b5a369` | clean | 1.10.0 → 1.11.0 | 0/0 | 67 | 810/0/810 | pass | 13377 | 1919 | 6.4 | 1.7 | 14 | 0 | **green** |
| [`20260926-193105`](20260926-193105/) | `fb55f44` | clean | 1.10.0 | 0/0 | 67 | 810/0/810 | pass | 13377 | 1919 | 6.4 | 1.7 | 14 | 0 | **green** |
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

**886 cases** — 885 passed, 0 failed, 1 skipped. The generated inventory
[`20261009-191726/test-cases.md`](20261009-191726/test-cases.md) is the authority on which cases existed at this run;
`docs/test-cases.md` is that same list at HEAD.

Moved **810 → 886** since the previous run.

**1 case(s) reported a `skip`.** A skip is counted in the total and never in `passed`, and at
the release gate it is NOT EVALUATED rather than passed (`automated-tests-§3`).

## Lint

**0 warnings / 0 errors over 70 files** (`luacheck .`).

Read that figure with its scope attached: `.luacheckrc` excludes 5 path(s) from it — `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`, `tests/_kit/` —
so nothing under them is in the count above. A `0/0` that never moves is partly a statement about
what was never looked at, which is why the exclusions are NAMED here on every run rather than left
to whoever thinks to open `.luacheckrc`.

## Perf

**7 scenarios** from `tests/perf.lua`; the measurements are in
[`20261009-191726/perf.json`](20261009-191726/perf.json).

| `scenario` | `iters` | `ms/iter` | `api/iter` | `bytes/iter` |
|---|---|---|---|---|
| `absorbEvent` | 1000 | 0.00048 | 0.0 | 0.0 |
| `paintBars` | 1000 | 0.01496 | 12.0 | 48.0 |
| `repaintPass` | 1000 | 0.01735 | 12.0 | 0.0 |
| `appearancePass` | 200 | 0.05147 | 48.0 | 97.8 |
| `settingsRead` | 10000 | 0.00044 | 0.0 | 0.0 |
| `probeOverheadOff` | 1000 | 0.01786 | 12.0 | 0.0 |
| `probeOverheadOn` | 1000 | 0.01942 | 12.0 | 0.5 |

`perf` never fails a run and never blocks a commit — it is recorded, read and compared, not
thresholded (`performance-§9`). It does gate the **tag** (`automated-tests-§3`).

## Complexity watch list

Current as of [`20261009-191726`](20261009-191726/) — **this run's measurement, not its diff.** Max CCN **14** across 2249
functions, **0** of them warned on; 2 file(s) in the 1000–1500 band and 0 over the 1500 cap
(`layout-§1`).

Every row below is generated from this run's own `lizard` output. **The `Disposition` column is
the one authored cell in this file** (`automated-tests-§4`, *the one boundary*): it is carried
forward verbatim while its entry is unchanged, and left **blank** when the entry is new — a blank
cell is this file saying something crossed and nobody has ruled on it yet.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|

None.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1079 | **Back under the cap — watch (second release run in the band).** It was 1745 and over the cap at [`20260916-184524`](20260916-184524/); the `/at perf` and `/at debug hold` peels brought it to 1304, the remediation's slash items left it at 1318 at [`20260924-112145`](20260924-112145/), and it was 1321 at the 1.11.0 release run [`20260927-030336`](20260927-030336/). Cases added after that release, the `/at profile <name>` verb's (SP-AT-02) among them, grew it to 1472, and SD-FIN-01 (`05f1f8c`) took the peel the last disposition named: the `/at profile` cases moved to `tests/test_slashprofile.lua` (456), leaving 1079 at the 1.12.0 release run [`20261009-191726`](20261009-191726/). That is its second release run in the band, two of three toward the anti-pattern #53 limit. Sighted, it measures 110 functions, avg CCN 1.4, max 5: a flat case list. A further peel would split by verb group again, the way `perf`, `hold` and `profile` went. Re-check at 1300. |
| 1000–1500 (on notice) | `tests/test_widgets.lua` | 1073 | **Accepted — watch (second release run carried as Accepted).** It was 904 at [`20260916-184524`](20260916-184524/). AT-15 (`19761b8`) took it over 1000 with the Appearance strip pins; 1073 at [`20260926-160433`](20260926-160433/), at the 1.11.0 release run [`20260927-030336`](20260927-030336/), and still 1073 at the 1.12.0 release run [`20261009-191726`](20261009-191726/) (GI-AT-02 rewrote about ten lines for the RenderTabbedSchema strip, net zero). Two of three release runs carried as Accepted: the next release owes anti-pattern #53 a fix or a tracked deviation ID, so the peel should land before 1.13.0. Sighted, it measures 105 functions (100 unsighted at 1.11.0, so five newly measured, not new), avg CCN 2.0, max 9; the length is case count. The seam is unchanged: the four real-page `OnShow` cases and the strip block belong beside `tests/test_panelpages.lua` (676). Re-check at 1300. |

`lizard` counts every `and`/`or` short-circuit as a decision, so in Lua a run of
`t.k = rec.k or D.k` defaulting lines scores high with no visible branching at all: a large CCN
here usually means *this function defaults or guards a lot of fields* rather than *this function
is tangled*, and the two want different fixes (`performance-§10`).

