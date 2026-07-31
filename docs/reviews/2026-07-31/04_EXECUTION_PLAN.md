# Execution plan — 2026-07-31 review

Implements `02_PROPOSED_CHANGES.md` (C-1 … C-14) against
`docs/reviews/2026-07-31/01_FINDINGS.md` (F-001 … F-018).

**Gate on every commit:** `lua tests/run.lua` green **and** `luacheck .` 0/0 (testing-§4,
anti-patterns #23). TDD — the failing test lands first (testing-§4).

**Working branch:** stay on `feature/libka0s-five-module-extraction`; this is remediation of the
branch under review, not new feature work (versioning-git, anti-patterns #21).

---

## Milestone M0 — Upstream library work (blocks nothing, but has the longest lead time)

Start this first because it involves a second repo, a minor bump, a changelog entry and a re-vendor
commit back here. Everything else is independent of it.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M0.1 | `lua-refactorer` (in **LibKa0s** repo) | C-9 / F-016 | `LibKa0s/LibKa0s/OptionsWidgets.lua`, its suite, `CHANGELOG.md` |
| M0.2 | `ux-cleanup` (in **LibKa0s** repo) | C-10 / F-017 | `LibKa0s/LibKa0s/Core.lua`, `OptionsWidgets.lua`, `Slash.lua`, `CHANGELOG.md` |
| M0.3 | `wow-addon-vendor` (in **AbsorbTracker**) | re-vendor for C-9 + C-10 | `libs/LibKa0s/*` (copy only — never hand-edited) |

**Done when:** upstream is green; `OptionsWidgets`, `Core` and `Slash` each carry a bumped LibStub
file minor with a matching CHANGELOG line (library-stack-§7 — **not** bumped in lockstep);
`diff -r ../LibKa0s/LibKa0s libs/LibKa0s` is empty in this repo; M0.3 is its **own commit** so the
sync is legible in history.

**Hazard:** M0.3 overwrites the whole `libs/LibKa0s/` tree. If any other task has (wrongly) edited a
file there, it is silently reverted — which is the correct outcome, but confusing mid-review. No
other task in this plan touches `libs/`.

---

## Milestone M1 — User-facing correctness (T1)

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M1.1 | `lua-refactorer` | C-1 / F-001 | `settings/Slash.lua`, `tests/test_slashcmds.lua` |
| M1.2 | `docs-writer` | C-2 / F-003 | `README.md` |
| M1.3 | `ux-cleanup` | C-13 / F-013 | `core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua` |

**Done when:** `/at resetall` cannot print success without having reset (covered by a new headless
case); `grep -nE "<[a-z|]+>" README.md` returns only the deliberate `<br>` tags; a degraded login
prints one cause clause in every seam.

**Concurrency:** M1.1 and M1.3 **both touch `settings/Slash.lua` → serialize** (M1.1 first — it is
the behavioral one). M1.2 is disjoint and **parallelizable** with everything.

---

## Milestone M2 — Collapse the duplicates (T2)

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M2.1 | `lua-refactorer` | C-3 / F-004 | `settings/OptionsSetup.lua`, `tests/test_helpers.lua` |
| M2.2 | `lua-refactorer` | C-5 + C-6 / F-007, F-015 | `settings/Schema.lua`, `tests/test_schema.lua` |
| M2.3 | `test-author` | C-4 / F-006 | `tests/test_slashcmds.lua`, `settings/Slash.lua` (comment only) |

**Done when:** the Profiles veto exists once in `settings/OptionsSetup.lua` and a headless case
proves the degraded reset honours it; `FormatSchemaValue` resolves `LibStub` once at file scope and
its library-absent arm renders colors, `fmt`-ed numbers and `(none)`; the degraded and live
dispatchers are compared on five inputs.

**Concurrency:** M2.1 touches `settings/OptionsSetup.lua`, which **M1.3 and M3.1 also touch →
serialize M2.1 after M1.3, before M3.1**. M2.2 is disjoint (`settings/Schema.lua`) →
**parallelizable**. M2.3 touches `settings/Slash.lua` (comment) and `tests/test_slashcmds.lua`,
both also touched by M1.1 → **serialize M2.3 after M1.1**.

---

## ⛳ Checkpoint A — after M1 + M2

Human/coordinator verification before any refresh-path refactor:

1. `lua tests/run.lua` green, `luacheck .` 0/0.
2. In-client: run smoke tests C-1, C-2, C-3, C-4, C-5/C-6, C-12 (the degraded write-and-read-back
   case) and C-13.
3. Confirm the **degraded arm still loads the full schema** — this is the one regression that would
   invalidate the whole extraction, and M2.1 edits the file that guarantees it.

Do not proceed to M3 until the degraded arm is green.

---

## Milestone M3 — Refresh contract + render safety (T4)

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M3.1 | `lua-refactorer` | C-8 / F-009 | `settings/UnitPanel.lua`, `tests/test_helpers.lua` |
| M3.2 | `lua-refactorer` | C-7 / F-008 | `settings/UnitPanel.lua`, `settings/Bar.lua`, `settings/Border.lua`, `settings/Font.lua`, `tests/test_helpers.lua` |

**Done when:** a raising render leaves `ctx.__rendering` false and reports through `NS.Print`; a
mirror write re-renders only the on-screen page and marks the others dirty; each dirty page renders
exactly once on its next `OnShow`.

**Concurrency:** M3.1 and M3.2 **both rewrite `RenderUnitPanel` → serialize**. Do M3.1 first: it
extracts the render body into an inner function, which is the shape M3.2's dirty-flag branch is
easiest to add to. Both also touch `tests/test_helpers.lua`, reinforcing the serialization.
M3.2 additionally touches the three page files, which **nothing else in this plan touches**.

---

## ⛳ Checkpoint B — after M3

1. Green gate.
2. In-client: smoke tests C-7 and C-8, plus the **whole regression suite** — M3 is the only
   milestone that changes rendering behavior, so this is where a UI regression would appear.
3. Run the C-7 performance spot-check and record the before/after CPU figures for
   `05_FINAL_SUMMARY.md`.

---

## Milestone M4 — Text, comments and cleanup (T3, T5, T6)

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M4.1 | `ux-cleanup` | C-11 / F-002 | `settings/OptionsSetup.lua`, `settings/Slash.lua`, `settings/UnitPanel.lua`, `settings/Schema.lua`, `README.md`, `CLAUDE.md`, `tests/*.lua` |
| M4.2 | `docs-writer` | C-12 / F-005, F-011, F-014 | `settings/OptionsSetup.lua`, `core/CoreSetup.lua`, `settings/Slash.lua` |
| M4.3 | `lua-refactorer` | C-14 / F-010, F-012, F-018 | `settings/OptionsSetup.lua`, `settings/Slash.lua`, `settings/UnitPanel.lua`, `tests/test_helpers.lua`, `tests/test_widgets.lua` |

**Done when:** the British-spelling grep is clean outside `libs/` and the frozen `docs/audits/`,
`docs/reviews/` bundles; the OptionsSetup stub's rationale names `LSMValues` alone as load-time and
no longer ships the three layout constants; `PARENT_TITLE`, `CliVersion` and `__lastUnitCtx` are
gone.

**Concurrency:** M4.1, M4.2 and M4.3 **all touch `settings/OptionsSetup.lua` and
`settings/Slash.lua` → fully serialize this milestone.** Order M4.1 → M4.2 → M4.3: the sweep first
(it rewrites comment text M4.2 then corrects), the rationale second, the deletions last so the
final diff is smallest. M4.3 additionally touches `settings/UnitPanel.lua`, which M3 rewrote →
**M4.3 must run after M3.2**.

---

## Milestone M5 — Documentation roll-forward

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M5.1 | `test-author` | regenerate the inventory | `docs/test-cases.md` (`lua tests/run.lua --list > docs/test-cases.md`) |
| M5.2 | `docs-writer` | badge lockstep | `README.md` (`[tests]` X/Y) |
| M5.3 | `docs-writer` | member/line-count drift | `docs/file-index.md`, `docs/module-map.md`, `docs/settings-panel.md`, `docs/schema.md`, `docs/ARCHITECTURE.md` |
| M5.4 | `docs-writer` | complexity report | `docs/complexity.md` (re-run `lizard`, report-only) |

**Done when:** `docs/test-cases.md` is regenerated (never hand-edited) and the README badge matches
its grand total in the **same commit** (testing-§5, documentation-§1); every doc row naming a
removed member (`ParseSchemaValue` is already handled; add `PARENT_TITLE`, `SlashCommands`,
`__lastUnitCtx`) is corrected.

**Concurrency:** M5.1 must run **last** among code-touching tasks — it derives from the final suite.
M5.2 depends on M5.1. M5.3/M5.4 are **parallelizable** with each other.

---

## Critical path

```
M0.1 ─┐
M0.2 ─┴─> M0.3 (re-vendor, own commit)        [independent lane, join before release]

M1.1 ──> M1.3 ──> M2.1 ──> ⛳A ──> M3.1 ──> M3.2 ──> ⛳B ──> M4.1 ──> M4.2 ──> M4.3 ──> M5.1 ──> M5.2
M1.2 ────────────────────────────────────────────────────────────────────────────────┘ (join at M5)
M2.2 ──────────────────> ⛳A                                        (parallel with M1.3/M2.1)
M2.3 ──> (after M1.1) ─> ⛳A
                                                                    M5.3, M5.4 (parallel, any time after ⛳B)
```

**Serialization callouts**

| Shared file | Tasks | Order |
|---|---|---|
| `settings/Slash.lua` | M1.1, M1.3, M2.3, M4.1, M4.2, M4.3 | M1.1 → M1.3 → M2.3 → M4.1 → M4.2 → M4.3 |
| `settings/OptionsSetup.lua` | M1.3, M2.1, M4.1, M4.2, M4.3 | M1.3 → M2.1 → M4.1 → M4.2 → M4.3 |
| `settings/UnitPanel.lua` | M3.1, M3.2, M4.1, M4.3 | M3.1 → M3.2 → M4.1 → M4.3 |
| `tests/test_helpers.lua` | M2.1, M3.1, M3.2, M4.3 | follows the owning task order |
| `settings/Schema.lua` | M2.2, M4.1 | M2.2 → M4.1 |
| `README.md` | M1.2, M4.1, M5.2 | M1.2 → M4.1 → M5.2 |
| `libs/LibKa0s/**` | **M0.3 only** | nothing else may touch it |

**Parallelizable (disjoint file sets):** M1.2 ∥ M1.1; M2.2 ∥ (M1.3, M2.1); M5.3 ∥ M5.4; the whole
M0 lane ∥ M1–M4.

---

## Checkpoints (summary)

| Checkpoint | After | Verifier checks |
|---|---|---|
| ⛳A | M1 + M2 | green gate; degraded arm loads the **full** schema and can write+read a setting; combat refusal still refuses |
| ⛳B | M3 | green gate; full in-client regression suite; C-7 perf figures recorded |
| ⛳C | M0.3 | `diff -r` empty; inline button pairs survive a `/reload` |
| ⛳D | M5 | `docs/test-cases.md` regenerated and the README badge matches it exactly |

---

## Incremental commit strategy

One commit per task, message in the repo's existing Conventional-Commits style, each referencing its
finding IDs so `git log --grep=F-0` reconstructs the review.

| Task | Suggested message |
|---|---|
| M0.1 | `fix(options): stop RenderRows mutating the host's afterGroup/pairWith tables` *(LibKa0s repo)* |
| M0.2 | `style: US English across Core, OptionsWidgets and Slash comments` *(LibKa0s repo)* |
| M0.3 | `chore(libs): re-vendor LibKa0s — OptionsWidgets/Core/Slash minor bumps (F-016, F-017)` |
| M1.1 | `fix(slash): /at resetall acknowledges inside its guard (F-001)` |
| M1.2 | `docs(readme): drop the last angle-bracket placeholder from the reset row (F-003)` |
| M1.3 | `refactor(setup): one cause clause for the missing-LibKa0s message (F-013)` |
| M2.1 | `refactor(options): one predicate for the profiles reset veto (F-004)` |
| M2.2 | `refactor(schema): resolve LibKa0s-Slash once; restore the degraded formatter (F-007, F-015)` |
| M2.3 | `test(slash): pin degraded/live dispatcher parity (F-006)` |
| M3.1 | `fix(settings): clear the unit-panel render guard on the failure path (F-009)` |
| M3.2 | `perf(settings): rebuild only the on-screen unit panel; flag the rest dirty (F-008)` |
| M4.1 | `style: US English across the files this branch added (F-002)` |
| M4.2 | `docs(comments): correct the degradation rationales (F-005, F-011, F-014)` |
| M4.3 | `refactor: drop PARENT_TITLE, CliVersion and __lastUnitCtx (F-010, F-012, F-018)` |
| M5.1+M5.2 | `test: regenerate the case inventory and sync the README badge` |
| M5.3+M5.4 | `docs: roll the file index, module map and complexity report forward` |
