# Analysis — 20260804-214639

- **Addon:** AbsorbTracker 1.9.0
- **Verdict:** green
- **Commit:** fa9035c4ce03 (feat/fix-ccn), dirty
- **Started:** 2026-08-04T21:46:39+05:30
- **Previous run:** [`20260804-182031`](../20260804-182031/)

## Headline

**The complexity watch list is empty.** `lizard` warns on nothing: the two functions the previous
run carried — `runProfile` at CCN 21 and `NS:RunMigrations` at CCN 19 — are both gone, and no
function in this addon's own source now exceeds CCN 15. That is what the `feat/fix-ccn` branch set
out to do, and this run is the measurement that says it landed. Both gating suites stay clean:
`luacheck` reports 0 warnings / 0 errors across 28 files, and the headless harness passes 470 of 470
cases — one more than the previous run, the characterization test that pins the `[Migrate]` line
ORDER across a v1 → v4 upgrade, which is what makes the migration-ladder rewrite safe to believe.

## Suites

| Suite | Status | Result | Artifact | Moved since previous run |
|---|---|---|---|---|
| lint | pass | 0 warnings / 0 errors in 28 files | [`lint.txt`](lint.txt) | unchanged — 0/0 in 28 files |
| tests | pass | 470 passed, 0 failed, 470 total | [`tests.txt`](tests.txt) · [`test-cases.md`](test-cases.md) | **+1 case** (469 → 470), still 0 failed |
| perf | pass | 6 scenarios | [`perf.txt`](perf.txt) · [`perf.json`](perf.json) | same 6 scenarios; timings within run-to-run noise |
| complexity | pass | see below | [`complexity.txt`](complexity.txt) | **2 warnings → 0**; max CCN 21 → 15 |

### Complexity in full

Every field of `lizard`'s footer, plus the two derived file counts. The **averages** are what make
this run comparable to the previous one across a change in size: a total that rises because the
addon grew is a different fact from an average that rises because it got denser, and only the
second is a complexity signal. Here the total NLOC rose (7532 → 7574) while the average NLOC per
function *fell* (6.5 → 6.4) — the refactor added lines by splitting two long functions into
several short ones and a pair of declarative tables, which is exactly the shape a peel should have.

| Metric | Value | Previous run | Moved |
|---|---|---|---|
| Total NLOC | 7574 | 7532 | +42 |
| Functions | 1063 | 1047 | +16 |
| Avg NLOC / function | 6.4 | 6.5 | −0.1 |
| Avg CCN | 1.7 | 1.7 | — |
| Max CCN | **15** | 21 | **−6** |
| Avg tokens / function | 45.4 | 45.9 | −0.5 |
| Warnings (CCN > 15) | **0** | 2 | **−2** |
| Warning rate — `Fun Rt` / `nloc Rt` | 0.00 / 0.00 | 0.00 / 0.02 | to zero |
| Files in the 1000–1500 band | 1 | 1 | — |
| Files over the 1500 cap | 0 | 0 | — |

All four suites ran. `perf` and `complexity` are **recorded, non-gating** — they inform, they do not
fail the run.

**One field in the manifest is wrong, and it is the runner's, not the addon's.** `manifest.json`
records `"maxCcn": 0` and the RESULTS row shows `0` in the Max CCN column. The kit derives max CCN
by scanning `lizard`'s `!!!! Warnings` block, and with no warnings there is no block to scan, so it
falls through to its `m+0` default. The real max is **15** (`Helpers.BuildMainContent`,
`settings/About.lua`) — at the cap, not over it. Left as generated rather than hand-corrected: the
kit is vendored from LibKa0s and a local patch is reverted silently by the next re-vendor
(automated-tests-§2). The fix belongs upstream; recorded here so the number in the row is not read
as "no functions".

## What moved

The complexity picture is the whole story. Everything else held: lint identical, perf identical in
shape, the file bands unchanged.

- **`runProfile` (`settings/Slash.lua`), CCN 21 → not warned.** The chain of `elseif sub == "…"`
  arms became a `PROFILE_VERBS` dispatch table built once at load, with the four name-taking verbs
  sharing one `needsName(verb, fn)` guard and the help rows moved into a `PROFILE_HELP` array.
  `runProfile` itself is now: guard the DB, split the verb, look it up, call it.
- **`NS:RunMigrations` (`core/Database.lua`), CCN 19 → not warned.** The two backfill loops moved
  into `backfillFlatKeys` / `backfillUnitKeys`, and the three `if g.schemaVersion < N` arms became
  an ordered `SCHEMA_STEPS` ladder the function walks. Adding a schema version is now one row.
- **+1 test case.** `RunMigrations emits the [Migrate] lines for a v1->v4 upgrade in order` — a
  characterization test written *before* the ladder rewrite, asserting the sequence of `[Migrate]`
  lines rather than only their presence. It is what proves the loop did not reorder a step's own
  output relative to its version stamp.

Behavior is identical to `master` on every path the suite reaches.

## Complexity watch list

### Functions `lizard` warned on

**None.** No function in this addon's own source exceeds CCN 15. The two entries the previous run
carried are gone — `runProfile` and `NS:RunMigrations` were both peeled on this branch, and neither
was accepted, deferred or reclassified. The closest function to the line is
`Helpers.BuildMainContent` (`settings/About.lua`) at CCN **15**, which is at the threshold and not
warned on; it is the one to watch if the About page grows another block.

### Files by `layout-§1` band

| Band | File | LOC | Disposition |
|---|---|---|---|
| 1000–1500 (on notice) | `tests/test_slashcmds.lua` | 1256 | **Accepted.** Still the only file in the band, and unchanged by this branch. A flat list of independent cases, avg CCN 1.2 — length is case count, not tangle. Peel by verb group if it crosses 1400. |

## Actions

- **Upstream, not here:** the kit's max-CCN parser reads only the warnings block, so a clean run
  records `maxCcn: 0`. Fix belongs in LibKa0s `testkit/`, then re-vendor. Recorded above.
- Nothing else. The watch list is empty by result, not by omission.
