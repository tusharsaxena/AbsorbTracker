# AbsorbTracker — Execution Plan (2026-08-05 review)

Ten changes across five milestones. No upstream milestone: **this review raised no `[upstream]`
findings**, and no task below touches `libs/` or `tests/_kit/`.

Every milestone that moves the case count carries the inventory regeneration **inside** the same
task, never as a follow-up (`testing-§7`).

---

## Milestone M1 — Perf evidence integrity

**Why first.** F-001 makes every capture produced from now on wrong, and `03_SMOKE_TESTS.md`'s perf
section is the verification for several later claims. Fixing the report before anything else means
the rest of the work is measured against a correct instrument.

**Done when:** `core/PerfSetup.lua` declares exactly one `within`; a new case pins that every declared
`within` is reached from inside its parent's bracket; `docs/performance.md` leads with the bucket
table; `tests/perf.lua`'s zero-overhead assertion is falsifiable; the suite is green at 471 and
`lua tests/perf.lua` exits 0.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **T1.1** | perf-instrumentation | A1 (F-001) | `core/PerfSetup.lua` |
| **T1.2** | test-author | A1 regression case + inventory | `tests/test_perf.lua`, `docs/test-cases.md`, `README.md` |
| **T1.3** | docs-editor | A2 (F-007) | `docs/performance.md` |
| **T1.4** | perf-instrumentation | A3 (F-006) | `tests/perf.lua` |

**Serialization.** T1.1 → T1.2 (the case asserts the corrected descriptor). T1.3 and T1.4 are
**parallelizable** with each other and with T1.1/T1.2 — disjoint file sets.

---

## Milestone M2 — Functional and honesty gaps

**Done when:** `/at test` self-restores; the combat-gate toggle repaints unconditionally; the Reset
All popup's acknowledgment sits inside its guard and matches the slash wording; suite green at 474.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **T2.1** | lua-refactorer | B1 (F-002) | `settings/Slash.lua` |
| **T2.2** | test-author | B1 case + inventory | `tests/test_slashcmds.lua`, `docs/test-cases.md`, `README.md` |
| **T2.3** | ux-cleanup | B2 (F-003) | `settings/General.lua` |
| **T2.4** | ux-cleanup | B3 (F-004) | `settings/General.lua` |
| **T2.5** | test-author | B2 + B3 cases + inventory | `tests/test_visibility.lua`, `tests/test_slashcmds.lua`, `docs/test-cases.md`, `README.md` |

**Serialization — read this before parallelizing.**

- **T2.3 and T2.4 both edit `settings/General.lua` → MUST serialize.** They are in different
  functions (the `showOnlyInCombat` row's `onChange` at ~`:50` and the StaticPopup `OnAccept` at
  ~`:133`), but the same file; run T2.3 then T2.4.
- **T2.2 and T2.5 both edit `tests/test_slashcmds.lua`, `docs/test-cases.md` and `README.md` → MUST
  serialize.** The inventory and the badge are single-writer artifacts for the whole milestone; the
  cleanest sequencing is to let T2.5 do the single regeneration for M2 after T2.2's case is written,
  rather than regenerating twice.
- **T2.1 is parallelizable** with T2.3/T2.4 (disjoint files).

**Recommendation:** collapse T2.2 into T2.5 as one "M2 test + inventory" task to keep the badge
single-writer.

---

## Milestone M3 — Harness blind spots

**Done when:** the runner's suite list is asserted against the suites on disk; the vendor-sync case
names disclose the missing-sibling condition; suite green at 475.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **T3.1** | test-author | C1 (F-005) | `tests/run.lua`, `tests/test_loadorder.lua` |
| **T3.2** | test-author | C2 (F-013) | `tests/test_vendor_sync.lua` |
| **T3.3** | test-author | inventory + badge for M3 | `docs/test-cases.md`, `README.md` |

**Serialization.** T3.1 and T3.2 are **parallelizable** (disjoint files). T3.3 runs last and alone —
it regenerates the inventory for both.

**Note for T3.1.** `tests/run.lua` currently inlines the suite table into `Kit.run{}`; lifting it to
a named local and publishing it through `Kit.expose` is part of this task. Do **not** modify
`tests/_kit/framework.lua` to make a missing suite fail — that file is vendored, and its skip
behavior is deliberate.

---

## Milestone M4 — Comment and duplication cleanup

**Done when:** `core/Database.lua` has no private `deepcopy`; four comments describe the code they
sit above; suite still green at 475 (no count change).

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **T4.1** | lua-refactorer | D1 code half (F-009) | `core/Database.lua` |
| **T4.2** | docs-editor | D1 comment half (F-009 partial, F-010, F-011, F-012) | `core/Units.lua`, `settings/Schema.lua`, `modules/Bar.lua`, `core/Data.lua` |

**Serialization.** T4.1 and T4.2 are **parallelizable** — disjoint files (`core/Database.lua` vs. the
other four). Neither touches a test.

**Checkpoint before M5:** run `lua tests/run.lua` after T4.1. `tests/test_database.lua:50` and `:206`
already assert nested-table isolation on the migration path; if either reddens, the `DeepCopy`
substitution is wrong and must be reverted before proceeding.

---

## Milestone M5 — Migration ladder

**Why last.** It is the only change that alters saved-variable behavior, and it wants a clean, green
tree beneath it so a red suite unambiguously points here.

**Done when:** `NS.defaults.global.schemaVersion` is 1; a case pins that a DB whose `global` section
is created by copyDefaults still runs the ladder to 4; suite green at 476.

| Task | Role | Implements | Files touched |
|---|---|---|---|
| **T5.1** | savedvariables-migrator | E1 (F-008) | `defaults/Profile.lua`, `core/Database.lua` (comment only) |
| **T5.2** | test-author | E1 case + inventory | `tests/test_database.lua`, `docs/test-cases.md`, `README.md` |

**Serialization.** T5.1 → T5.2, strictly. **T5.1 touches `core/Database.lua`, which T4.1 also
touches → M4 must complete before M5 begins.**

---

## Critical path and concurrency map

```
M1 ──┬── T1.1 ──> T1.2                    (core/PerfSetup.lua -> tests/test_perf.lua + inventory)
     ├── T1.3                             ∥ docs/performance.md
     └── T1.4                             ∥ tests/perf.lua
        │
        ▼  [CHECKPOINT 1]
M2 ──┬── T2.1                             ∥ settings/Slash.lua
     └── T2.3 ──> T2.4                    SERIAL: both edit settings/General.lua
        └────────> T2.5 (+T2.2)           SERIAL, last: single inventory/badge write for M2
        │
        ▼  [CHECKPOINT 2]
M3 ──┬── T3.1                             ∥ tests/run.lua + test_loadorder.lua
     └── T3.2                             ∥ tests/test_vendor_sync.lua
        └────────> T3.3                   SERIAL, last: inventory/badge
        │
        ▼
M4 ──┬── T4.1                             ∥ core/Database.lua
     └── T4.2                             ∥ core/Units.lua, settings/Schema.lua, modules/Bar.lua, core/Data.lua
        │
        ▼  [CHECKPOINT 3]
M5 ───── T5.1 ──> T5.2                    SERIAL; blocked on T4.1 (shared core/Database.lua)
```

**Shared-file collisions, stated explicitly:**

| File | Tasks | Rule |
|---|---|---|
| `settings/General.lua` | T2.3, T2.4 | **serialize** |
| `tests/test_slashcmds.lua` | T2.2, T2.5 | **serialize** (or merge) |
| `core/Database.lua` | T4.1, T5.1 | **serialize across milestones** — M4 before M5 |
| `docs/test-cases.md`, `README.md` | T1.2, T2.5, T3.3, T5.2 | **single writer per milestone**; never two open at once |

---

## Checkpoints

**CHECKPOINT 1 — after M1, before M2.** Human verification required.
Run the pre-flight line from `03_SMOKE_TESTS.md`, then execute **smoke test A1 in-client** and commit
the resulting capture under `docs/perf-runs/`. The corrected bucket nesting is the instrument every
later perf claim is read through; verifying it later means re-running the capture.

**CHECKPOINT 2 — after M2, before M3.** Human verification required.
Execute smoke tests **B1, B2, B3** plus regression rows **R4, R5, R7**. These are the only changes in
the whole plan with user-visible behavior; if any is wrong, stop before the harness work makes the
diff harder to read.

**CHECKPOINT 3 — after M4, before M5.** Coordinator verification.
`lua tests/run.lua` green, and smoke test **D1** (the two-profile independence check) executed. M5
edits the same file M4 just touched and changes migration behavior; entering it on an unverified tree
is how a saved-variable bug gets attributed to the wrong commit.

**Final gate — after M5.** Full `03_SMOKE_TESTS.md` pass including the E1 upgrade rehearsal, the
taint section, and the committed perf capture. Fill in the sign-off table.

---

## Incremental commit strategy

One commit per task, except where the map above merges two. Suggested messages:

| Commit | Message |
|---|---|
| T1.1 | `perf: drop the false within nesting on the appearance and visibility buckets (F-001)` |
| T1.2 | `tests: pin that a declared within is reached from inside its parent bracket (F-001)` |
| T1.3 | `docs: lead performance.md with the bucket table, demote the frame-time delta (F-007)` |
| T1.4 | `perf: make the zero-overhead assertion able to go red (F-006)` |
| T2.1 | `fix: /at test restores the real value when its hold expires (F-002)` |
| T2.3 | `fix: repaint every enabled bar when the combat gate flips, not just the player's (F-003)` |
| T2.4 | `fix: the Reset All popup stops claiming success it did not verify (F-004)` |
| T2.5 | `tests: cover the test-hold restore, the multi-unit combat gate and the guarded reset ack` |
| T3.1 | `tests: assert the runner's suite list is exactly the suites on disk (F-005)` |
| T3.2 | `tests: disclose the missing-sibling skip in the vendor-sync case names (F-013)` |
| T3.3 | `tests: regenerate the case inventory and badge for the harness changes` |
| T4.1 | `refactor: one deep copy — Database uses NS.Units.DeepCopy (F-009)` |
| T4.2 | `docs: correct four comments that no longer describe the code (F-009, F-010, F-011, F-012)` |
| T5.1 | `fix: default the account-wide schema stamp to 1 so the ladder stays reachable (F-008)` |
| T5.2 | `tests: pin that a copyDefaults-created global section still runs the ladder (F-008)` |

**Rules that hold for every commit:**

- A commit that changes the case count carries the regenerated `docs/test-cases.md` **and** the
  updated README `[Tests]` badge. Never hand-edit either; regenerate with
  `lua tests/run.lua --list`.
- The commit gate is `lint` + the harness only (`testing-§4`). `tests/perf.lua` and `lizard` are
  **not** commit gates — they are read at release (`automated-tests-§3`). Do not add a threshold to a
  pre-commit hook.
- No commit in this plan may touch `libs/` or `tests/_kit/`. If one appears to need to, it is the
  wrong change — re-read `01_FINDINGS.md`'s upstream section (which is empty, deliberately).
- A full `docs/automated-tests/<stamp>/` bundle is produced at **release** by
  `/wow-addon:bump-version`, not by any task here.
