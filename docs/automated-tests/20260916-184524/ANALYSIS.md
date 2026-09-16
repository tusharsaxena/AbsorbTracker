# Analysis — 20260916-184524

- **Addon:** AbsorbTracker 1.10.0
- **Verdict:** green
- **Commit:** 10808576566811d7264d89db486ad6c9b2cad85d (master), clean
- **Previous run:** [`20260916-094435`](../20260916-094435/)

## Headline

Green on all four suites, and for the first time since [`20260804-214639`](../20260804-214639/) max
CCN sits at **14** rather than 15 — the tag gate's "zero functions above CCN 15" now clears with a
margin rather than by one point. Nothing regressed: 25 new test cases, lint still 0/0 but now over
56 files rather than 54, perf unchanged at 6 scenarios. The one thing still owed is the same one the
previous run raised — `tests/test_slashcmds.lua` was over the `layout-§1` cap then and has grown a
further 206 lines since, so the peel is now overdue rather than pending.

## Suites

| Suite | Status | Result | Artifact | Moved since `20260916-094435` |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 56 files | [`lint.txt`](lint.txt) | +2 files, still 0/0 |
| tests | pass | 635 passed, 0 skipped, 0 failed, 635 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | +25 cases |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | unchanged |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | see below |

No suite was skipped in this run, so no figure below stands in for something that was not measured.

| Metric | Value |
|---|---|
| Total NLOC | 10555 |
| Functions | 1479 |
| Avg NLOC / function | 6.5 |
| Avg CCN | 1.7 |
| Max CCN | 14 |
| Avg tokens / function | 46.4 |
| Warnings (CCN > 15) | 0 |
| Warning rate (`Fun Rt` / `nloc Rt`) | 0.00 / 0.00 |
| Files in the 1000–1500 band | 1 |
| Files over the 1500 cap | 1 |

Every figure above is [`manifest.json`](manifest.json)'s `suites.complexity`, which carries all
eight of `lizard`'s footer fields; the per-file rows behind the two band counts are in
[`complexity.txt`](complexity.txt), whose footer reads *No thresholds exceeded*.

Reported in full on purpose. The **totals** rose — NLOC 10092 → 10555 and functions 1425 → 1479 —
because the addon gained a launcher module and its test file, which is growth. The **averages** are
the complexity reading, and they say the new code is ordinary: avg CCN flat at 1.7, max CCN down a
point, avg NLOC 6.4 → 6.5 and avg tokens 45.8 → 46.4, both a fraction denser and both well inside
the range every run in this table has occupied. A total that rose because the addon grew is a
different fact from an average that rose because it got denser, and only the second would be a
signal.

## What moved

- **lint** — 0 warnings / 0 errors in both runs; what changed is scope, 54 → 56 files. The two new
  files are `core/LauncherSetup.lua` and `tests/test_launcher.lua` (diff of the `Checking` lines in
  [`lint.txt`](lint.txt) against the previous run's), which is the launcher / minimap-button work
  committed since `fcc9ebc`. The exclusion set is unchanged: `.luacheckrc` still excludes `libs/`,
  `docs/audits/`, `docs/reviews/`, `_dev/` and `tests/_kit/`, so a 0/0 here is 0/0 over the
  addon's own source and its suite, not over the vendored tree.
- **tests** — 610 → 635 passed (+25), still 0 failed and 0 skipped, so passed and total agree. The
  git log explains the delta plainly: thirteen commits landed since the previous run's `fcc9ebc`,
  among them `a3a2c38` (adopt the launcher, the addon's own icon and a minimap button), `11747ee`
  (vendor LibDataBroker-1.1 and LibDBIcon-1.0), `e0e7466` (`/at enable` and `/at disable`),
  `9157807` (the minimap button survives a page Defaults press) and `830fafb` (a disabled addon
  refuses its feature verbs). A changed test count was expected today and this is what it was.
- **perf** — 6 scenarios in both runs, same names, same iteration counts, same allocation profile:
  `paintPass` 12.0 api/iter and 48.0 bytes/iter in both, `appearancePass` 48.0 / 384.2 in both, and
  1000 absorb events still coalescing into 1 repaint. Wall times are uniformly a little higher than
  the previous run (`paintPass` 0.00842 → 0.01120 ms/iter, `appearancePass` 0.02994 → 0.03461), which
  is a whole-run shift of the kind timings are explicitly not to be read across —
  [`perf.txt`](perf.txt) says so itself. The reading that survives is the within-run one: the probe
  still costs nothing structural when off, `probeOverheadOff` 0.00998 against `probeOverheadOn`
  0.01189, with identical 12.0 api/iter and 48.0 vs 48.3 bytes/iter.
- **complexity** — NLOC 10092 → 10555 (+463) over 1425 → 1479 functions (+54). Max CCN 15 → 14,
  zero warned functions in both runs. Band counts did not move — still 1 file on notice and 1 over
  cap — but the over-cap file itself did: see below.

## Complexity watch list

Both tables are maintained in [`RESULTS.md`](../RESULTS.md), which the runner regenerates whole on
every run; the **Disposition** column there is the authored half and is current as of this run.

### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| — | — | — | None. |

None. `lizard` reports *No thresholds exceeded* and max CCN is 14, two below the warn line — the
best reading in this table since `20260804-214639`, and the first run in five where the margin is
more than a single point. Nothing newly crossed and nothing is owed a ruling here.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_helpers.lua` | 1415 | Carried forward — **Peel next**, unchanged and still true. |
| > 1500 (over cap) | `tests/test_slashcmds.lua` | 1745 | **Peel next — now overdue**, and grown a further 206 lines while over cap. |

Neither entry newly crossed a band this run, so neither arrives with a blank disposition. What did
move is the over-cap file's size: `tests/test_slashcmds.lua` went 1539 → 1745 lines (+206), 172 →
182 functions, while the peel its previous disposition called for did not happen. `tests/test_helpers.lua`
is byte-for-byte where it was — 1415 lines, 973 NLOC, 137 functions, avg CCN 1.5 — so its
disposition is carried forward rather than re-argued.

Neither is a complexity signal in the CCN sense. Both are **dense case lists, not tangled control
flow**: `test_slashcmds.lua` averages CCN 1.3 over 182 functions and `test_helpers.lua` CCN 1.5 over
137, and `lizard` counts every `and`/`or` short-circuit as a decision, so even those small numbers
are mostly Lua defaulting and guarding rather than branching. There is nothing here to unpick — the
fix is to split the file, not to restructure a function.

On shelf life: `automated-tests-§4` puts a clock on an entry carried as **Accepted** across three
consecutive release runs. Neither of these is accepted — both read *Peel next*, an owed action, and
the git history of `RESULTS.md` shows they have carried that ruling since
[`20260916-094435`](../20260916-094435/), one run ago, with exactly one release run
(`eae987a`, Release 1.10.0) in the window. So no entry has crossed the three-release line yet. The
over-cap one is nevertheless the closest thing this record has to a standing debt, and it grew
rather than shrank, which is the fact worth carrying into the next run.

## Actions

1. Peel `tests/test_slashcmds.lua` (1745 lines) by verb group, back under the `layout-§1` 1500-line
   cap — or give it one of the section's other two terminal states, an issue ID or a row in
   `docs/ARCHITECTURE.md`'s `## Documented deviations`. Carried from the previous run's action 1,
   still unowned in the addon's own bookkeeping, and now 245 lines past the cap rather than 39.
2. Peel `tests/test_helpers.lua` (1415 lines) by helper group. Carried from the previous run's
   action 2; its own 1400-line trigger has fired and the file has not moved since, so the action is
   neither more nor less urgent than it was.
