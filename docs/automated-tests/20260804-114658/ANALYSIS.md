# Analysis — 20260804-114658

- **Addon:** AbsorbTracker 1.9.0
- **Verdict:** green
- **Commit:** 17142645fb4f (master), dirty
- **Previous run:** none — this is the first recorded run

## Headline

The first automated-test record for this addon, produced while adopting `automated-tests`
(standard v2.19.0). Both gating suites are clean: `luacheck` reports 0 warnings / 0 errors across
28 files and the headless harness passes 469 of 469 cases. The offline perf scenarios run clean. Every figure below is a **baseline** —
there is no previous run to diff against, so nothing here is a regression and nothing is an
improvement.

## Suites

| Suite | Status | Result | Moved since previous run |
|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 28 files (`lint.txt`) | — first run |
| tests | pass | 469 passed, 0 failed, 469 total (`tests.txt`) | — first run |
| perf | pass | pass — 6 scenarios | — first run |
| complexity | pass | 2 warnings, max CCN 21, 7532 NLOC / 1047 functions (`complexity.txt`) | — first run |

All four suites ran. `perf` and `complexity` are **recorded, non-gating** — they inform, they do not fail the run.

## What moved

**First run — nothing to diff against; every figure above is a baseline reading.** The next run is
the first one that can say something moved, and this record is what it will be read against.

## Complexity watch list

| `runProfile` | 21 | `settings/Slash.lua` | **Peel next — already tracked.** The 2026-08-03 review's change **C-1** rewrites exactly this function. |
| `NS:RunMigrations` | 19 | `core/Database.lua` | **Accepted.** A schema-migration ladder: one rung per shipped version, run once at load. |

**Files in the 1000–1500 band:** `tests/test_slashcmds.lua` (1256) — accepted; a flat list of independent cases, avg CCN 1.2. Peel at 1400.

## Actions

None arising from this run. The dispositions above are carried forward from the complexity reports
written against the same measurements earlier today; each was recorded with its evidence at the
time, and none is new here.
