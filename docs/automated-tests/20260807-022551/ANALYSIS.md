# Analysis — 20260807-022551

- **Addon:** AbsorbTracker 1.9.0
- **Verdict:** green
- **Commit:** 087140f9f5bd3cd0ed1483f4800b93c13d232736 (master), clean
- **Previous run:** [`20260804-233138`](../20260804-233138/)

## Headline

All four suites ran and all four passed — nothing was skipped, so the green reading is a measurement
rather than an absence. The test suite grew by 19 cases (470 → 489), the first movement in the count
since `20260804-214639`, and it brought a new file with it (`tests/test_surface_parity.lua`, 4
cases). Complexity is flat where it matters: max CCN is still 15, avg CCN still 1.7, and `lizard`
warned on nothing, so the totals that rose (NLOC 7574 → 7766, functions 1063 → 1088) rose because
the addon's test surface grew, not because it got denser. Nothing to act on.

## Suites

Every row links its artifact, so a reader can get from a figure to the evidence in one click.

| Suite | Status | Result | Artifact | Moved since `20260804-233138` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 28 files | [`lint.txt`](lint.txt) | No change — same 28 files, same clean result |
| tests | pass | 489 passed, 0 skipped, 0 failed, 489 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +19 cases (470 → 489); one new file |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | Same 6 scenarios; `appearancePass` api/iter 33.0 → 45.0 |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | Totals up with the tree; averages and max flat |

**Complexity is reported in full**, because a single figure cannot be compared across a change in
size. Every value below is `manifest.json`'s `suites.complexity`, which records all eight fields of
`lizard`'s footer ([`complexity.txt`](complexity.txt)):

| Metric | Value |
|---|---|
| Total NLOC | 7766 |
| Functions | 1088 |
| Avg NLOC / function | 6.5 |
| Avg CCN | 1.7 |
| Max CCN | 15 |
| Avg tokens / function | 45.6 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 0 |

Every suite was a clean pass, and no suite was skipped: `manifest.json`'s `host` block records
Lua 5.1.5, Luacheck 1.2.0 and lizard 1.23.0, so all four tools were present and all four ran.

## What moved

- **lint** — unchanged. 0 warnings / 0 errors over the same 28 files. The file count is stable
  because `.luacheckrc`'s scope did not change and no new runtime source file was added; the 19 new
  cases all landed under `tests/`, which the config excludes.
- **tests** — 470 → 489, **+19**. The first movement since `20260804-214639`, and it is spread
  across six existing files plus one new one: `test_surface_parity.lua` (**new**, 4),
  `test_display.lua` (39 → 44), `test_loadorder.lua` (10 → 13), `test_perf.lua` (27 → 29),
  `test_slashcmds.lua` (109 → 111), `test_widgets.lua` (48 → 50), `test_database.lua` (28 → 29).
  Counts from [`test-cases.md`](test-cases.md) against the previous bundle's copy.
- **perf** — pass on both runs, same 6 scenarios, so the scenario set did not move. One figure did:
  `appearancePass` reports **45.0 api/iter** against the previous run's 33.0
  ([`perf.txt`](perf.txt)). That is an API-call count, not a timing, so it is deterministic and not
  machine noise — the appearance pass now makes 12 more client calls per iteration. `bytes/iter`
  is unchanged at 893.7 and the other five scenarios' api/iter are identical, so the change is
  confined to that one path. Timings themselves are orientation only and are not compared here.
- **complexity** — totals rose, averages did not. NLOC 7574 → 7766 (**+192**), functions
  1063 → 1088 (**+25**), avg tokens/function 45.4 → 45.6. Avg NLOC/function moved 6.4 → 6.5 and
  avg CCN held at 1.7. Max CCN held at **15** and the warning count held at **0**. The rise tracks
  the +19 test cases, which is growth rather than density — the signal to watch is the average, and
  it did not move.

## Complexity watch list

`lizard` warned on nothing this run (`Warning cnt` 0, [`complexity.txt`](complexity.txt) footer), so
the **warned** set is empty. The table below is therefore the **watch** list — every function at or
above CCN 12, highest first — because an empty table would carry the same verdict and none of the
signal.

| Function | CCN | Location | Disposition |
|---|---|---|---|
| `Helpers.BuildMainContent` | 15 | `settings/About.lua` | **At the line, not over it.** Unchanged from the previous run, same span (38–104). Still the one to watch: a straight-line builder where one more content block puts it over. Peel the block sequence into a data table the day it grows. |
| `addon:OnAbsorbChanged` | 14 | `core/AbsorbTracker.lua` | **Accepted — unchanged.** `lizard` reports it as `addon`. Dense *guarding*, not tangle: the branching is the per-unit relevance ladder the handler exists to be. |
| `NS.ValidateSchema` | 14 | `settings/Schema.lua` | **Accepted — unchanged.** CCN flat at 14; the span shifted 224–261 → 227–264 from edits above it, not from new branching. A flat list of independent row assertions, one `if` per rule. |
| `build` | 12 | `settings/Profiles.lua` | **Accepted — unchanged.** CCN flat at 12 while NLOC fell 31 → 26. Well under the line and getting shorter. |

Nothing **newly** crossed. No function is above CCN 15, so a release run cut from this state would
clear `automated-tests-§3`'s release gate on complexity.

**Files by `layout-§1` band:**

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1282 | **Accepted — not newly crossed.** Already in the band on the previous run at 1256; +26 lines with the +2 cases. A flat list of independent cases (avg CCN 1.2), so length is case count, not tangle. Peel by verb group if it crosses 1400. |

No file is over the 1500 cap (`overCapFiles` 0).

## Actions

None.

Two things are worth a reader's eye next run rather than an action now:

1. `appearancePass`'s api/iter (`tests/perf.lua`) went 33.0 → 45.0. Confirm that is the intended
   consequence of whatever changed in the appearance path, not an accidental extra client call per
   widget. Non-gating either way.
2. `settings/About.lua`'s `Helpers.BuildMainContent` sits at CCN 15 for the third run running. It is
   not warned and not over the release gate, but it has no headroom: the next content block warns
   it, and that would block a tag.
