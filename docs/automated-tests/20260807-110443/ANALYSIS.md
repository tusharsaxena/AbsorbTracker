# Analysis — 20260807-110443

- **Addon:** AbsorbTracker 1.9.0
- **Verdict:** green
- **Commit:** 788fb06b8118ef45de5a730b2644a58a677c8f49 (master), dirty — this run was cut mid-change,
  with the LibKa0s v1.8.2 re-vendor staged. That is deliberate: the run exists to prove the
  re-vendored payload is green *before* it is committed, so `git.dirty` is `true` by design here
  rather than by oversight.
- **Previous run:** [`20260807-022551`](../20260807-022551/)

## Headline

This run exists to gate a re-vendor, not to record a code change. `libs/LibKa0s/` and `tests/_kit/`
were re-taken wholesale from LibKa0s **v1.8.2** (testkit revision 10) and `CLAUDE.md`'s provenance
line moved with them, so the two `tests/test_vendor_sync.lua` cases — which resolve that line to a
tag and compare both payloads against it byte by byte — are the cases that matter, and both pass.

Every measured figure is **flat** against the previous run: same 28 lint files, same 489 cases, same
6 perf scenarios, identical `complexity.txt` byte for byte. That is the expected reading. `luacheck`
excludes both vendored trees via `exclude_files` and `lizard` excludes them via `-x "./libs/*" -x
"./tests/_kit/*"`, so a payload swap cannot move lint or complexity, and it did not. Nothing to act
on.

The run also demonstrates the kit fix that v1.8.2 shipped: **every file this bundle wrote is CRLF on
disk**, matching the repo's `.gitattributes` pin. Before revision 10 the runner's plain shell
redirects bypassed git's filters and left every bundle LF — a stray crop `git status` never mentions
and `git add --renormalize` never fixes. See *What moved* below for the counts.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260807-022551` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 28 files | [`lint.txt`](lint.txt) | None — `lint.txt` is byte-identical |
| tests | pass | 489 passed, 0 failed, 489 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | Count flat at 489; one case *renamed* |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | Same 6 scenarios; api/iter and bytes/iter all identical |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | None — `complexity.txt` is byte-identical |

Nothing was skipped: `manifest.json`'s `host` block records Lua 5.1.5, Luacheck 1.2.0 and lizard
1.23.0, so all four tools were present and all four ran. The green reading is a measurement, not an
absence.

**Complexity in full** (`manifest.json`'s `suites.complexity`, all eight footer fields from
[`complexity.txt`](complexity.txt)):

| Metric | Value | vs previous |
|---|---|---|
| Total NLOC | 7766 | flat |
| Functions | 1088 | flat |
| Avg NLOC / function | 6.5 | flat |
| Avg CCN | 1.7 | flat |
| Max CCN | 15 | flat |
| Avg tokens / function | 45.6 | flat |
| Warnings (CCN > 15) | 0 | flat |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 | flat |
| Files in the 1000–1500 band | 1 | flat |
| Files over the 1500 cap | 0 | flat |

## What moved

- **The vendored payload** — `libs/LibKa0s/` and `tests/_kit/` moved from v1.8.1 (kit revision 9) to
  **v1.8.2** (kit revision 10), taken from the tag rather than from LibKa0s' working tree. Four
  files actually changed content: `libs/LibKa0s/Options.lua`, `tests/_kit/README.md`,
  `tests/_kit/framework.lua` and `tests/_kit/run-automated-tests.sh`. The runner now hashes
  `4fa4d26d80f111eec53518ef77f57681` on both the `testkit/` and `tests/_kit/` paths at the tag,
  which is the byte-identity `tests/test_kitsync.lua` enforces upstream.
- **The two vendor-sync cases** — *"libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon
  bundles"* and *"tests/_kit is the test kit that shipped with that release"* both **pass**. They
  were the red pair on the previous attempt, which vendored from untagged `master`; comparing
  against the tag is the gate's design, not a limitation of it.
- **lint** — nothing. `lint.txt` is byte-identical to the previous run's. Both vendored trees sit
  outside `luacheck .` via `exclude_files`, so a payload swap is invisible here, which is what the
  identical file says.
- **tests** — 489 → 489, **no movement in the count**. One case name changed:
  `SetByPath logs one [Set] path = value line (§10)` became `… (debug-logging-§10)`, from commit
  788fb06's citation-form sweep, not from this re-vendor. That is the only line that differs between
  the two `test-cases.md` files.
- **perf** — pass on both runs, same 6 scenarios. Every **api/iter** and **bytes/iter** figure is
  identical (`appearancePass` still 45.0 / 893.7, `paintPass` still 12.0 / 312.0). Only wall-clock
  timings differ, in the fourth decimal, which is machine noise and is orientation only.
  `appearancePass`'s api/iter therefore *held* at 45.0 rather than moving again — see Actions.
- **complexity** — nothing. `complexity.txt` is byte-identical. `lizard` excludes `./libs/*` and
  `./tests/_kit/*`, so the swapped payload is outside what it counts.
- **Bundle line endings** — the point of the exercise. All seven files this run wrote carry CRLF on
  disk, CR count equal to LF count in every one:

  | File | CR | LF |
  |---|---|---|
  | `complexity.txt` | 1156 | 1156 |
  | `lint.txt` | 30 | 30 |
  | `manifest.json` | 19 | 19 |
  | `perf.json` | 1 | 1 |
  | `perf.txt` | 13 | 13 |
  | `test-cases.md` | 590 | 590 |
  | `tests.txt` | 491 | 491 |

  The previous bundle's same seven files were LF on disk (CR 0 against those same LF counts) and
  were the whole of this repo's working-tree stray population. They have been restored through git's
  filter in this changeset; the check from `line-endings-§7` now reads **0**.

## Complexity watch list

`lizard` warned on nothing (`Warning cnt` 0), so the table below is the **watch** list — every
function at or above CCN 12, highest first. It is unchanged from the previous run in every row,
because `complexity.txt` is unchanged.

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `Helpers.BuildMainContent` | 15 | `settings/About.lua` | **At the line, not over it.** Fourth run running at 15, same span. No headroom: one more content block warns it, and a warned function blocks a release tag. Peel the block sequence into a data table the day it grows. |
| `addon:OnAbsorbChanged` | 14 | `core/AbsorbTracker.lua` | **Accepted — unchanged.** Dense *guarding*, not tangle: the branching is the per-unit relevance ladder the handler exists to be. |
| `NS.ValidateSchema` | 14 | `settings/Schema.lua` | **Accepted — unchanged.** A flat list of independent row assertions, one `if` per rule. |
| `build` | 12 | `settings/Profiles.lua` | **Accepted — unchanged.** Well under the line. |

Nothing newly crossed. No function is above CCN 15, so a release run cut from this state would clear
`automated-tests-§3`'s release gate on complexity.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1282 | **Accepted — not newly crossed and not moved.** Same 1282 as the previous run. A flat list of independent cases (avg CCN 1.2), so length is case count, not tangle. Peel by verb group if it crosses 1400. |

No file is over the 1500 cap (`overCapFiles` 0).

## Actions

None.

Two things for a reader's eye next run rather than an action now:

1. `appearancePass`'s api/iter **held at 45.0** after last run's 33.0 → 45.0 step. Holding confirms
   the step was a real, deterministic change in the appearance path rather than a one-run artifact —
   it is now the baseline. It is still worth confirming that the extra client calls per iteration
   were intended. Non-gating either way.
2. `settings/About.lua`'s `Helpers.BuildMainContent` sits at CCN 15 for a fourth run. Not warned and
   not over the release gate, but it has no room left.
