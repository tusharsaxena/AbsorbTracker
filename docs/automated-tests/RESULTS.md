# Automated test results

<!-- The newest run is prepended by tests/_kit/run-automated-tests.sh. -->
<!-- This file is OVERWRITTEN IN PLACE — the git history of this one path is the trend line. -->

One row per run. The frozen evidence for each is in the dated folder beside this file;
the analysis of a given run is its `ANALYSIS.md`.

| Run | Version | Lint w/e | Tests | Perf | CCN warn | Max CCN | Verdict |
|---|---|---|---|---|---|---|---|
| [`20260804-122459`](20260804-122459/) | 1.9.0 | 0/0 | 469/469 | pass | 2 | 21 | **green** |

## Complexity watch list

Current state as of [`20260804-122459`](20260804-122459/) — not that run's diff.
Every function `lizard` warned on and every file in `layout-§1`'s 1000–1500 on-notice band,
each with a one-line disposition.

| `runProfile` | 21 | `settings/Slash.lua` | **Peel next — already tracked.** The 2026-08-03 review's change **C-1** rewrites exactly this function. |
| `NS:RunMigrations` | 19 | `core/Database.lua` | **Accepted.** A schema-migration ladder: one rung per shipped version, run once at load. |

**Files in the 1000–1500 band:** `tests/test_slashcmds.lua` (1256) — accepted; a flat list of independent cases, avg CCN 1.2. Peel at 1400.
