# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

**`lint` and `tests` gate. `perf` and `complexity` are recorded and never fail a run** —
they are read and compared, not thresholded. A `skip` is a suite that did not run at all,
which is never the same as a pass.

| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| [`20260804-214639`](20260804-214639/) | 1.9.0 | 0/0 | 28 | 470/470 | pass | 7574 | 1063 | 6.4 | 1.7 | 0 | 0 | **green** |
| [`20260804-182031`](20260804-182031/) | 1.9.0 | 0/0 | 28 | 469/469 | pass | 7532 | 1047 | 6.5 | 1.7 | 21 | 2 | **green** |

## Test suite

470 cases. Covers the absorb pipeline, the coalescing throttle, the bar/display modules and the settings schema; frame rendering and taint stay in `docs/smoke-tests.md`. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 28 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

Six scenarios, including the **zero-overhead** case `performance-§2` requires as evidence that instrumentation is free when off. Timings are orientation only — compare scenarios within a run, never across machines.

## Complexity watch list

Current state as of [`20260804-214639`](20260804-214639/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

**None.** No function in this addon's own source exceeds CCN 15.

That is a result, not an empty section: the previous run listed `runProfile` (CCN 21) and
`NS:RunMigrations` (CCN 19), and both were peeled on `feat/fix-ccn` rather than accepted or
deferred — `runProfile` onto a `PROFILE_VERBS` dispatch table, `RunMigrations` onto a
`SCHEMA_STEPS` ladder plus two backfill helpers. Neither disposition carries forward, because
neither function is on the list any more. The closest to the line now is
`Helpers.BuildMainContent` (`settings/About.lua`) at CCN **15** — at the threshold, not over it,
and so not warned on; it is the one to watch if the About page grows another block.

**The Max CCN column reads `0` for this run, and that is the kit's bug, not the measurement.** The
runner derives max CCN by scanning `lizard`'s `!!!! Warnings` block; with no warnings there is no
block, so the parser falls through to zero. The real maximum is the 15 above. Left as generated —
`tests/_kit/` is vendored and a local patch is reverted silently by the next re-vendor
(automated-tests-§2), so the fix belongs in LibKa0s `testkit/`.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1256 | **Accepted.** Still the only file in the band, and untouched by the CCN work. A flat list of independent cases, avg CCN 1.2 — length is case count, not tangle. Peel by verb group if it crosses 1400. |
