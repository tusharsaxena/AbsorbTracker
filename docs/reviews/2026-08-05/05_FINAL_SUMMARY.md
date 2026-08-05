# AbsorbTracker — Final Summary (2026-08-05 review cycle)

> **Status: forward-looking.** This document is written for the state of the repo *after*
> `04_EXECUTION_PLAN.md` has been executed and every check in `03_SMOKE_TESTS.md` has passed. Until
> the sign-off table in that file is filled in, treat the sections below as the intended record
> rather than the achieved one. Numbers marked **(measured 2026-08-05)** are real observations from
> the review's Step 0 and are true today.

---

## Headline

This cycle fixed the addon's performance evidence, closed three small promises the code was not
keeping, and made two silent blind spots in the test harness visible. The largest item is not a
crash or a leak: it is that every perf report AbsorbTracker produced was declaring that two of its
five buckets ran *inside* a third when they never do, which both mis-indented the report and told
whoever read it to exclude real cost from the addon's total. Alongside it, `/at test` now actually
ends when it says it will, the "show only in combat" toggle refreshes every bar rather than only the
player's, and the Reset All confirmation no longer announces success it never checked for. Nothing in
this cycle changes what the addon does in combat or how it stores your settings, with one deliberate
exception (the schema-version default, below), which is invisible to anyone whose saved variables
already carry a version stamp.

---

## Counts

**Critical fixed: 0** (none were found)
**High fixed: 1** — F-001
**Medium fixed: 6** — F-002, F-003, F-004, F-005, F-006, F-007
**Low fixed: 6** — F-008, F-009, F-010, F-011, F-012, F-013

**Deferred: none.** Every finding raised has a change in `02_PROPOSED_CHANGES.md`. The list was kept
short deliberately — twelve of thirteen findings are single-file, and the review declined to raise
style opinions that lint and the existing suites already govern.

**Not fixed because not broken:** the taint surface, the secret-value handling, the deprecated-API
sweep, the event-registration model, the single-write-path discipline, the degradation stubs, and
the TOC-derived load lists were all checked and are clean. `01_FINDINGS.md` records what was
examined so a later reviewer does not re-derive it.

---

## Changes by theme

### Theme A — the perf report now describes the call graph it actually has

**What changed.** The perf descriptor stopped declaring `appearance` and `visibility` as nested
inside `repaintPass`; only `paintBar` genuinely runs inside it. `docs/performance.md` was re-headlined
to lead with the bucket table rather than the frame-time delta. The offline runner's zero-overhead
assertion was rewritten so it can go red for the failure it names.

**Why it mattered.** The library renders `within` as report indentation *and* as an explicit
"repaintPass contains X — do not sum" note. Two of those notes were false, so every capture instructed
its reader to discard genuine, un-nested cost. Meanwhile the write-up pointed that reader at the one
number the standard calls unresolved, and the runner's overhead check (`probeOff <= probeOn + 1`) was
satisfied by any dormant bracket that allocates, as long as the armed one allocated at least as much.
Three separate ways for a future performance decision to be made from something that is not evidence.

**Findings covered:** F-001, F-006, F-007. **Changes implemented:** A1, A2, A3.

**Files touched:**
- `core/PerfSetup.lua`
- `tests/perf.lua`
- `tests/test_perf.lua`
- `docs/performance.md`

### Theme B — three promises the code was not keeping

**What changed.** `/at test <value> <seconds>` now arms a one-shot AceTimer that publishes a repaint
when the hold expires, so the preview ends when the chat line says it does. The `showOnlyInCombat`
toggle publishes its repaint unconditionally instead of gating it on the player bar. The Reset All
confirmation dialog moved its acknowledgment inside the guard that checks the reset actually ran, and
now prints the same string the slash verb prints.

**Why it mattered.** Each was a user-visible statement the implementation did not honor. `/at test`
was the sharpest: standing still, out of combat, with no shield ticking — precisely when you run it to
preview your styling — nothing would ever clear the fake value, because the only thing that reopened
the guard was an event that was never going to arrive. The combat-gate guard read
`NS.ShouldShowBar()`, which defaults to the *player* unit, so a user running target-only bars saw a
stale value on reveal. And the Reset All popup printed "All settings reset to defaults." even when the
settings library was absent and nothing had been reset — the exact silent-lie shape the slash twin's
comment had already been written to avoid.

**Findings covered:** F-002, F-003, F-004. **Changes implemented:** B1, B2, B3.

**Files touched:**
- `settings/Slash.lua`
- `settings/General.lua`
- `tests/test_slashcmds.lua`
- `tests/test_visibility.lua`

### Theme C — the harness's blind spots are visible now

**What changed.** `tests/run.lua`'s suite list is published and asserted against the `test_*.lua`
files actually on disk. The two vendor-sync cases were renamed to disclose that they go quiet when
the LibKa0s checkout is not beside this repo.

**Why it mattered.** Both were places where a green row meant less than it looked like. The vendored
kit skips a listed-but-missing suite rather than failing — correct behavior, documented in the kit —
but nothing asserted the converse, so a renamed suite would have stopped contributing cases while the
run stayed green and the badge quietly dropped. And the vendor-sync pair returns PASS without looking
when the sibling repo is absent, while its own comment claimed that condition was "said in the case
name". It was not, in either name. Neither fix makes anything fail; both make the difference legible
in `docs/test-cases.md`.

**Findings covered:** F-005, F-013. **Changes implemented:** C1, C2.

**Files touched:**
- `tests/run.lua`
- `tests/test_loadorder.lua`
- `tests/test_vendor_sync.lua`

### Theme D — comments that no longer described the code

**What changed.** `core/Database.lua`'s private `deepcopy` was deleted in favor of the identical
`NS.Units.DeepCopy` it duplicated. Four comments were corrected: `Units.Set` no longer claims the
slash CLI reaches it (the CLI writes through `NS.SetByPath`); `modules/Bar.lua` no longer justifies
its player aliases with `core/DebugLog.lua`, a file removed in the LibKa0s extraction;
`settings/Schema.lua` no longer calls a one-level loop a deep copy; `core/Data.lua`'s header now
admits that the resolved class colors are memoized even though the toggles are re-read.

**Why it mattered.** This codebase's comments are unusually load-bearing — several of them are the
only record of *why* a non-obvious thing is written the way it is, and at least two document bugs that
already happened once. That makes a comment which names a deleted file or a caller that does not
exist more expensive here than it would be elsewhere: a reader who trusts it goes to the wrong file.
The `deepcopy` consolidation also gave `Units.DeepCopy` its first production caller.

**Findings covered:** F-009, F-010, F-011, F-012. **Changes implemented:** D1.

**Files touched:**
- `core/Database.lua`
- `core/Units.lua`
- `core/Data.lua`
- `settings/Schema.lua`
- `modules/Bar.lua`

### Theme E — the migration ladder stays reachable

**What changed.** `NS.defaults.global.schemaVersion` now defaults to `1` instead of `4`.

**Why it mattered.** AceDB's `copyDefaults` fills every absent key the first time `db.global` is
touched — which happens *before* `NS:RunMigrations` reads it. Defaulting to the current version
therefore stamped any database whose `global` section first materialized on this build as
already-migrated, and the whole `SCHEMA_STEPS` ladder became dead code for that user. This is the
identical failure mode the *per-profile* stamp defaults to `1` to avoid, and whose reasoning
`defaults/Profile.lua` already spells out at length. Today's cost was nil — the only skipped steps
delete keys nothing reads — but the ladder exists to be extended, and the next step that does real
work would have been silently skipped.

**Findings covered:** F-008. **Changes implemented:** E1.

**Files touched:**
- `defaults/Profile.lua`
- `core/Database.lua` (comment only)
- `tests/test_database.lua`

---

## API / behavior changes

Externally observable changes, in full:

- **`/at test [value] [seconds]`** — now honors its stated duration. Previously the preview persisted
  until an unrelated event arrived; it now restores the real value when the hold expires. The command
  grammar, its arguments and its chat output are unchanged. A second `/at test` issued during an
  active hold cancels the first timer and re-arms from the new command.
- **General → Show only in combat** — toggling it now refreshes every enabled bar. Previously the
  refresh was suppressed unless the *player* bar was showable.
- **General → Reset All Settings (popup)** — the confirmation now prints
  `All settings reset to defaults` (no trailing period, matching `/at resetall`) only when the reset
  actually ran, and prints `Cannot reset settings — the settings helpers failed to load` otherwise.
  Previously it printed the success line unconditionally.
- **`/at perf` report** — `appearance` and `visibility` render as top-level buckets rather than
  indented under `repaintPass`, and the report's nesting note names exactly one containment pair
  (`repaintPass contains paintBar`). Bucket *names*, order and figures are otherwise unchanged; only
  the declared relationship between them moved.
- **No slash subcommand was added, renamed or removed.** `NS.COMMANDS` still holds the same 17
  entries, and `README.md`'s command table is unchanged.
- **No locale string keys added or renamed.** The addon remains English-only with the `NS.L` seam in
  place, exactly as `locales/enUS.lua` documents.

---

## Saved-variable / migration notes

**No schema version bump.** The persisted shape is unchanged: `profile.units.<player|target|focus>.*`
plus the three flat globals, `profile.schemaVersion`, and `global.schemaVersion` at 4.

**One default changed.** `NS.defaults.global.schemaVersion` moved from `4` to `1`.

| | Before | After |
|---|---|---|
| Fresh install | `global.schemaVersion` stamped `4` by copyDefaults; ladder skipped entirely | stamped `1`; ladder runs all three steps against empty data (each a no-op) and lands on `4` |
| Existing DB with a stamp | untouched — the stored value wins over the default | unchanged |
| DB whose `global` section is absent (pre-AceDB-era saves, restored backups) | stamped `4`, ladder permanently skipped | stamped `1`, ladder runs and lands on `4` |

**Auto-migrates: yes, for everyone.** No user action, no `/at reset`, no profile loss. Users in the
third row above gain the two dead-key cleanups (`updateInterval`, `hidden`) they had been silently
missing; users in the first two rows see no difference at all. The per-profile v3 lift
(`NS.MigrateProfileToV3`) is untouched and still gated on `profile.schemaVersion`.

---

## Deprecated-API migrations

**None.** The sweep found no deprecated or removed API in this addon's own source. Recorded here so a
future reviewer does not repeat the search:

| Old API | Status in this addon | Where |
|---|---|---|
| `GetAddOnMetadata` | already shimmed — `C_AddOns.GetAddOnMetadata` preferred, bare global as pre-11.0 fallback | `core/Compat.lua:12-19`, pinned by `tests/test_compat.lua:31` |
| `GetSpellInfo`, `UnitAura`/`UnitBuff`/`UnitDebuff`, `GetContainerItemInfo`, `IsAddOnLoaded`, `InterfaceOptions_AddCategory`, `:Hook` on a secure function | not present | — |
| `SetBackdrop` | correctly used with `BackdropTemplate` | `modules/Bar.lua:17` |
| Settings registration | modern `Settings.RegisterCanvasLayoutSubcategory`, out of combat | `settings/General.lua:195` |

---

## Performance impact

**Baseline, measured 2026-08-05** (`lua5.1 tests/perf.lua`, this machine, orientation-only timings):

| scenario | iters | ms/iter | api/iter | bytes/iter |
|---|---|---|---|---|
| `absorbEvent` | 1000 | 0.00023 | 0.0 | 0.0 |
| `paintPass` | 1000 | 0.00511 | 12.0 | 312.0 |
| `appearancePass` | 200 | 0.02042 | 33.0 | 893.7 |
| `settingsRead` | 10000 | 0.00025 | 0.0 | 0.0 |
| `probeOverheadOff` | 1000 | 0.00509 | 12.0 | 312.0 |
| `probeOverheadOn` | 1000 | 0.00599 | 12.0 | 312.3 |

**Expected movement: none.** No change in this cycle touches an allocation or an API call on any
measured path. A1 edits a descriptor table read only at report-render time; B1 adds one timer armed
once per `/at test`; B2 removes a branch; the rest are comments, tests and a default value. The
`bytes/iter` and `api/iter` columns above are the durable figures and should reproduce exactly.

**What A3 changes about how this table is read.** The zero-overhead property is now pinned by
constancy — `probeOverheadOff` must equal `paintPass` (both 312.0 above, both capture-off runs of the
same code) and the armed delta must stay under 8 B/iter (0.3 above). The previous assertion could not
have caught a dormant bracket that started allocating; this one can.

**In-client evidence.** The verification capture from `03_SMOKE_TESTS.md` is committed under
`docs/perf-runs/` as `2026-08-05-ingame-<label>.json`. Read its **bucket figures** as the addon's
cost; the frame-time delta is corroboration only and is unresolved below the harness's ±0.3 ms/frame
floor. The prior record, `docs/perf-runs/2026-07-30-ingame-post-extraction.json`, is left exactly as
committed — the directory is append-only — and must be read with the correction that its
`visibility` bucket carries a `within: "repaintPass"` that was never true.

---

## Test and complexity movement

**Pass count: 470 → 476.** Measured before: `470 passed, 0 failed, 470 total`
(`lua5.1 tests/run.lua`, 2026-08-05). Six cases added, one per behavioral change plus the two harness
guards; two case *names* changed with no count movement (C2).

| Change | Case added |
|---|---|
| A1 | a declared `within` is reached from inside its parent's bracket |
| B1 | `/at test` arms a restore timer whose fire clears the preview |
| B2 | the combat gate repaints a target bar while the player bar is disabled |
| B3 | the Reset All popup prints the failure line when the helpers are absent |
| C1 | the runner's suite list is exactly the suites on disk |
| E1 | a copyDefaults-created `global` section still runs the ladder to 4 |

`docs/test-cases.md` was regenerated with `lua tests/run.lua --list` and the README `[Tests]` badge
updated **in the same commit as each change that moved the count** — never hand-edited, never
deferred (`testing-§7`).

**Complexity: no expected movement.** Today's `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` run
reports **0 functions above CCN 15** across 1063 functions and 7574 nloc (avg CCN 1.7), matching the
committed `20260804-233138` bundle exactly. The single function *at* the line,
`Helpers.BuildMainContent` (`settings/About.lua:38-104`, CCN 15), is untouched by every change here.
`runTest` gains two statements and no branch; the `showOnlyInCombat` `onChange` loses one. The
`layout-§1` band entry (`tests/test_slashcmds.lua`, 1256 LOC, accepted) grows by one case and stays
well under its 1400 peel trigger. The next release's regeneration should confirm all of this; no tool
is run into the repo as part of this work.

---

## Known follow-ups

- **A `within`-correctness case exists now; a bucket-*reachability* case does not.** A1's new case
  proves a declared nesting is real, but nothing asserts the converse direction — that every
  bracketed path has a declared bucket. Deferred because all five brackets currently map to declared
  buckets (verified by grep this review) and the check needs a source-scanning case rather than a
  behavioral one.
- **`Units.Set` still has no production caller.** Its comment is corrected (F-010) but the function is
  kept: it is published namespace API with a test, and removing a published member is a separate
  decision from correcting its documentation (`public-api`). Revisit if a per-unit write path is ever
  needed outside `NS.SetByPath`.
- **The vendor-sync check still cannot run without the sibling repo on disk.** C2 makes that visible
  rather than fixing it; a genuine fix would need the library's published tarball checksum vendored
  alongside the payload, which is a LibKa0s-side design question, not this addon's.
- **English-only localization.** The `NS.L` seam is in place and unused
  (`locales/enUS.lua:7-12` documents this deliberately). Out of scope here; it is a feature, not a
  defect, and its state is recorded in the addon's audit bundles.
- **`docs/performance.md`'s illustrative capture is from 2026-07-29.** A2 corrects the reading
  guidance around it but leaves the sample. Consider refreshing it with the post-A1 capture at the
  next release so the sample's nesting note matches what the code now emits.

---

## Verification evidence

- **Smoke tests:** `docs/reviews/2026-08-05/03_SMOKE_TESTS.md`, sign-off table filled in — ten change
  rows (A1–E1), twelve regression rows (R1–R12), five taint rows (T1–T5), and the committed perf
  capture row.
- **Findings and measurements:** `docs/reviews/2026-08-05/01_FINDINGS.md`, whose Measurement run block
  records the exact command and result for every out-of-game suite run on 2026-08-05, including the
  two skips (`make test` — no Makefile; vendor-sync `diff` — sibling repo out of scope for that run).
- **Design rationale:** `docs/reviews/2026-08-05/02_PROPOSED_CHANGES.md`, resolved against Ka0s WoW
  Addon Standard **v2.21.0**.
- **Commit range / PR:** _fill in on merge._

---

## Suggested commit message / PR description

```
review 2026-08-05: correct the perf bucket nesting, close three unkept promises,
and make two harness blind spots visible

The perf descriptor declared `appearance` and `visibility` as nested inside
`repaintPass`. Neither is: `doRepaint` calls `NS.UpdateAbsorbBar` and nothing
else, so only `paintBar` is genuinely nested. Every capture therefore printed two
false "contains" lines and told its reader not to sum two buckets of real,
un-nested cost — visible in docs/perf-runs/2026-07-30-ingame-post-extraction.json,
where `visibility` carries a `within` while showing 15 calls against
`repaintPass`'s 24. Dropped the two declarations, re-headlined docs/performance.md
on the bucket table (performance-§ requires the buckets as the addon's cost and
treats the frame-time delta as unresolved), and rewrote the offline zero-overhead
assertion, which compared the dormant arm against the armed one and so could not
go red for a dormant bracket that allocates.

Three user-visible promises the code did not keep: `/at test` stated a duration
and never restored (nothing re-opened the guard, so idle out of combat the fake
value persisted indefinitely) — now arms a one-shot AceTimer that publishes
REPAINT; the `showOnlyInCombat` toggle gated its repaint on `NS.ShouldShowBar()`,
which defaults to the player unit, leaving target-only users with a stale bar on
reveal — now unconditional; the Reset All popup printed its success line outside
the guard that checks the reset ran, the exact shape `runResetAll`'s comment was
written to avoid — now inside, with the matching failure branch and identical
wording.

Two harness blind spots: the runner's suite list was hand-maintained against a kit
that skips a missing suite rather than failing, with nothing asserting the
converse; and the vendor-sync pair returns green without looking when the LibKa0s
checkout is absent, while its own comment claimed that was disclosed in the case
names. Added the set-equality case; renamed the two cases to say the condition.

Also: `global.schemaVersion` defaults to 1 rather than 4, so copyDefaults can no
longer stamp a database as already-migrated before RunMigrations reads it and
deaden the whole ladder — the same reasoning the per-profile stamp already
carries. One deep-copy implementation instead of two. Four comments corrected
that named a deleted file, a caller that does not exist, a copy depth the loop
does not perform, and a cache the header denies.

No taint, secret-value or deprecated-API findings. Nothing under libs/ or
tests/_kit/ was touched; this review raised no upstream findings.

Tests 470 -> 476. Lint 0/0 over 28 files. lizard: 0 functions above CCN 15.

Findings: F-001 .. F-013 (docs/reviews/2026-08-05/01_FINDINGS.md)
Standard: Ka0s WoW Addon Standard v2.21.0
```
