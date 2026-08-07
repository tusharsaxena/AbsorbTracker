# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

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

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260807-110443`](20260807-110443/) | 1.9.0 | 0/0 | 28 | 489/489 | pass | 7766 | 1088 | 6.5 | 1.7 | 15 | 0 | **green** |
| [`20260807-022551`](20260807-022551/) | 1.9.0 | 0/0 | 28 | 489/489 | pass | 7766 | 1088 | 6.5 | 1.7 | 15 | 0 | **green** |
| [`20260804-233138`](20260804-233138/) | 1.9.0 | 0/0 | 28 | 470/470 | pass | 7574 | 1063 | 6.4 | 1.7 | 15 | 0 | **green** |
| [`20260804-214639`](20260804-214639/) | 1.9.0 | 0/0 | 28 | 470/470 | pass | 7574 | 1063 | 6.4 | 1.7 | 0 | 0 | **green** |
| [`20260804-182031`](20260804-182031/) | 1.9.0 | 0/0 | 28 | 469/469 | pass | 7532 | 1047 | 6.5 | 1.7 | 21 | 2 | **green** |

**Reading the Max CCN column: the `0` on the `20260804-214639` row is an instrument fault, not a
measurement.** One run stamp is affected — `20260804-214639`, and only that one. Test kits before
rev 6 derived max CCN by scanning `lizard`'s `!!!! Warnings` block, which does not exist once an
addon reaches zero warnings, so the field fell through to `0` at exactly the moment it was most
worth reading. The true figure for that run is in its own bundle:
[`20260804-214639/complexity.txt`](20260804-214639/complexity.txt) puts the maximum at **15**
(`Helpers.BuildMainContent`, `settings/About.lua`) — the same value the run after it records, over
byte-identical `complexity.txt` output. The generated row is left as generated: a hand-corrected
record is worse than a wrong one, because it reads as measured (`automated-tests-§1`,
`performance-§10`). So the `21 → 0 → 15` trend is really `21 → 15 → 15`.

## Test suite

489 cases as of [`20260807-022551`](20260807-022551/), up 19 from the 470 that stood across the three
runs before it — the count had been flat since [`20260804-214639`](20260804-214639/), and it has now
moved. The growth is spread across six existing files plus one new one: `test_surface_parity.lua`
(new, 4 cases), `test_display.lua` (39 → 44), `test_loadorder.lua` (10 → 13), `test_perf.lua`
(27 → 29), `test_slashcmds.lua` (109 → 111), `test_widgets.lua` (48 → 50) and `test_database.lua`
(28 → 29). Zero cases skipped and zero failed. The suite covers the absorb pipeline, the coalescing
throttle, the bar/display modules and the settings schema; frame rendering and taint stay in
`docs/smoke-tests.md`. The generated inventory `test-cases.md` in each bundle is the authority on
what exists at that point — [`20260807-022551/test-cases.md`](20260807-022551/test-cases.md) for the
current state — and the README badge tracks the same number.

## Lint

Clean over 28 files as of [`20260807-022551`](20260807-022551/): 0 warnings, 0 errors
([`lint.txt`](20260807-022551/lint.txt)). **Those 28 files are the addon's own runtime source only.**
`.luacheckrc` sets `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }`,
so the vendored `libs/` and the vendored `tests/_kit/` are out of scope — neither is this repo's to
fix — but the blanket `tests/` entry also takes this addon's **own** test files with it. The harness
is checked by running, not by linting; a `0/0` row here says nothing about `tests/`. That exclusion
is why the file count held at 28 while the suite grew by 19 cases: every new case landed under
`tests/`, and none of it is linted. The two `docs/` entries are the frozen evidence bundles only
(`lint-§`); the rest of `docs/` is linted, so the count would rise the day a doc directory carries
Lua. It carries none today.

## Perf

Six scenarios as of [`20260807-022551`](20260807-022551/) — `absorbEvent`, `paintPass`,
`appearancePass`, `settingsRead`, `probeOverheadOff` and `probeOverheadOn`
([`perf.txt`](20260807-022551/perf.txt)). The last pair is the **zero-overhead** case
`performance-§2` requires as evidence that instrumentation is free when off. The suite has run —
this addon ships `tests/perf.lua`, so `perf` is a real pass and neither of `automated-tests-§3`'s
two sanctioned skip reasons applies here. Timings are orientation only: compare scenarios within a
run, never across machines. The **api/iter** and **bytes/iter** columns are not timings and are worth
reading across runs; `appearancePass` moved from 33.0 to 45.0 api/iter between
[`20260804-233138`](20260804-233138/) and this run, with `bytes/iter` unchanged at 893.7 and every
other scenario's call count identical. In-game captures cannot come from a script and keep their own
store at [`../perf-runs/`](../perf-runs/).

## Complexity watch list

Current state as of [`20260807-022551`](20260807-022551/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions on the CCN watch list

**`lizard` warned on nothing.** Zero functions in this addon's own source exceed CCN 15
([`20260807-022551/complexity.txt`](20260807-022551/complexity.txt), `Warning cnt` 0), so the warned
set is empty — which is a result, not an absent section. The table below is therefore the **watch**
list rather than the warned list: every function at or above CCN 12, highest first, each with its
disposition. An empty table would carry the same verdict and none of the signal.

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `Helpers.BuildMainContent` | 15 | `settings/About.lua` | **At the line, not over it.** The one to watch: the About page is a straight-line builder, so one more content block puts it over — and over is a blocked tag, not just a warning. Peel the block sequence into a data table the day it grows. |
| `addon:OnAbsorbChanged` | 14 | `core/AbsorbTracker.lua` | **Accepted.** `lizard` reports it as `addon`. Dense guarding rather than tangled control flow: the branching is the per-unit relevance ladder the event handler exists to be, and splitting it would move the ladder, not shorten it. |
| `NS.ValidateSchema` | 14 | `settings/Schema.lua` | **Accepted.** The integrity checks are a flat list of independent row assertions; each `if` is one rule, and merging any two would hide which rule fired. Revisit only if a rule needs branching of its own. |
| `build` | 12 | `settings/Profiles.lua` | **Accepted.** Well under the line and falling — CCN flat at 12 while NLOC fell 31 → 26 this run. The lazy-`OnShow` work is the direction of travel here, not a peel. |

Nothing **newly** crossed since the previous run: all four CCN values are unchanged between
[`20260804-233138`](20260804-233138/) and [`20260807-022551`](20260807-022551/). The span shifts on
`NS.ValidateSchema` (224–261 → 227–264) and `build` (16–66 → 16–71) are edits above and around them,
not new branching.

**On the shelf life of these dispositions (`automated-tests-§4`).** The three-consecutive-**release**
-runs clock has not started: no run recorded here is a release run — all four manifests carry
`"release": null` — so none of the three `Accepted` entries above has yet spent a release cycle in
that state. The first `--release` bundle starts the count, and at the third the accepted entries owe
either a fix or a tracked deviation ID with an owner. `Helpers.BuildMainContent` is not on that clock
at all: its disposition is *watch*, not *accepted*.

The last run that warned on anything was [`20260804-182031`](20260804-182031/), and it listed
exactly two functions: `runProfile` (`settings/Slash.lua`) at CCN 21 and `NS:RunMigrations`
(`core/Database.lua`) at CCN 19. Both were peeled on `feat/fix-ccn` rather than accepted or
deferred — `runProfile` onto a `PROFILE_VERBS` dispatch table with its help rows in `PROFILE_HELP`
(both `settings/Slash.lua`), and `RunMigrations` onto a `SCHEMA_STEPS` ladder plus the two backfill
helpers `backfillFlatKeys` and `backfillUnitKeys` (all `core/Database.lua`). Neither disposition
carries forward, because neither function is on the list any more.

**Max CCN reads `15` again from [`20260804-233138`](20260804-233138/) onward.** The `0` on the
`20260804-214639` row is the pre-rev-6 kit parser fault described under the table above, not a
measurement — that run's own `complexity.txt` says 15. Test kit rev 6, vendored in with LibKa0s
v1.7.0, takes the CCN column of every function row instead of the `!!!! Warnings` block. Fixed
upstream and re-vendored rather than patched here (automated-tests-§2).

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1282 | **Accepted.** Still the only file in the band, and not newly crossed — it was already there at 1256 on [`20260804-233138`](20260804-233138/) and grew 26 lines with its two new cases. A flat list of independent cases, avg CCN 1.2 — length is case count, not tangle. Peel by verb group if it crosses 1400. |

No file is over the 1500 cap.
