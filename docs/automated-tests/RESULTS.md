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
| [`20260804-182031`](20260804-182031/) | 1.9.0 | 0/0 | 28 | 469/469 | pass | 7532 | 1047 | 6.5 | 1.7 | 21 | 2 | **green** |

## Test suite

469 cases. Covers the absorb pipeline, the coalescing throttle, the bar/display modules and the settings schema; frame rendering and taint stay in `docs/smoke-tests.md`. The generated inventory `test-cases.md` in each bundle is the authority on what exists at that point; the README badge tracks the same number.

## Lint

Clean over 28 files: 0 warnings, 0 errors. `luacheck .` runs over the addon's own source and its `tests/`; the vendored `libs/` and `tests/_kit/` are out of scope by config, since neither is this repo's to fix.

## Perf

Six scenarios, including the **zero-overhead** case `performance-§2` requires as evidence that instrumentation is free when off. Timings are orientation only — compare scenarios within a run, never across machines.

## Complexity watch list

Current state as of [`20260804-182031`](20260804-182031/) — not that run's diff.
Every function `lizard` warned on, and every file at or above `layout-§1`'s 1000-LOC
on-notice threshold, each with a one-line disposition.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `runProfile` | 21 | `settings/Slash.lua` | **Peel next — already tracked.** The 2026-08-03 review's change **C-1** rewrites exactly this function; the CCN is expected to fall when it lands. |
| `NS:RunMigrations` | 19 | `core/Database.lua` | **Accepted.** A schema-migration ladder — one rung per shipped version, run once at load. The branch count *is* the migration count. |

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1256 | **Accepted.** The only file in the band; a flat list of independent cases, avg CCN 1.2 — length is case count, not tangle. Peel by verb group if it crosses 1400. |
