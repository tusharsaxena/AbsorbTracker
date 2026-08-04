# 04 — Execution plan

Ordered milestones for implementing `02_PROPOSED_CHANGES.md`. Every task names its finding/change IDs, the
files it touches, and whether it can run in parallel with its siblings.

**Hard rule for the whole plan:** no task edits anything under `libs/` or `tests/_kit/`. The one upstream item
(U-1) is its own milestone with a cross-repo handoff and a re-vendor commit as its exit criterion.

**Green gate applies per task** (testing): `lua tests/run.lua` green and `luacheck .` clean before any
commit. A task that adds a case regenerates `docs/test-cases.md` **only** at the point M5 says to, so the
badge is not chased through five intermediate numbers.

---

## Milestone M1 — User-facing correctness

**Done when:** `/at profile` cannot error, wipe, or lie for any input; the `showOnlyInCombat` repaint gap is
closed; both are covered by cases that redden against the pre-change code.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| **T1.1** | `lua-refactorer` | C-1 (F-001, F-002, F-003, F-018) | `settings/Slash.lua`, `tests/test_slashcmds.lua` |
| **T1.2** | `lua-refactorer` | C-2 (F-004) | `settings/General.lua`, `tests/test_visibility.lua` |

**Concurrency:** T1.1 and T1.2 touch disjoint files — **parallelizable**.

**Mutation check (required for both):** each new case must be shown to **fail** against the unchanged code
before the fix lands. A guard case that passes either way is not testing the guard. This repo already holds
itself to that (`docs/pending/LEDGER.md`, rows `LIBKA0S-03` and `LIBKA0S-07`, both record mutation
verification).

---

## Milestone M2 — Design corrections

**Done when:** the background class color derives from the live API, and the Profiles page builds its body
lazily like the other four.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| **T2.1** | `lua-refactorer` | C-3 (F-005) | `core/Data.lua`, `tests/test_data.lua` |
| **T2.2** | `ux-cleanup` | C-5 (F-009) | `settings/Profiles.lua`, `tests/test_optionssetup.lua` |

**Concurrency:** disjoint files — **parallelizable**, and both are independent of M1.

**Note for T2.1:** the change is user-visible for a class the API does not resolve (white → dark gray). Record
that in the commit body; it is the only rendered difference.

---

## Milestone M3 — Hot-path allocation

**Done when:** `doRepaint` and the three Display bus handlers allocate no closure per invocation, an offline
allocation scenario asserts it, and every stub-based display test is still green.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| **T3.1** | `perf-engineer` | C-4 (F-008) — `doRepaint` loop | `modules/Timer.lua` |
| **T3.2** | `perf-engineer` | C-4 (F-008) — hoisted handler bodies | `modules/Display.lua` |
| **T3.3** | `perf-engineer` | C-4 (F-008) — allocation scenario | `tests/perf.lua` |

**Concurrency:** T3.1 and T3.2 touch different files and are **parallelizable**; **T3.3 must follow both**
(it measures their combined effect).

**Serialization callout:** T3.2 touches `modules/Display.lua`, which **no other task in this plan touches** —
no conflict. T3.1 touches `modules/Timer.lua`, which M6's T6.5 also touches (the `NS.addon` guard) → **T3.1
and T6.5 must serialize**; run T3.1 first.

**Constraint (do not violate):** the assertion in T3.3 is **bytes allocated / API calls**, never wall-clock
(performance-§9). And the Display handlers must keep looking their functions up on `NS` at dispatch time —
`tests/test_display.lua`'s stub-based cases are the regression proof and must not be relaxed to make T3.2
pass.

---

## Milestone M4 — Upstream (LibKa0s) — cross-repo

**Done when:** LibKa0s has released the spelling fix with per-file minor bumps, and **this repo carries a
re-vendor commit** whose `diff -r` against the library's ship folder is empty.

This milestone edits **nothing** in this addon except the vendored folder as a whole-folder copy, the README's
LibKa0s version line, and the ledger row.

| Task | Owner-agent role | Implements | Repo | Files touched |
|---|---|---|---|---|
| **T4.1** | `library-maintainer` | U-1 (F-010) — sweep spellings | **LibKa0s** | `LibKa0s/{Perf,Core,DebugLog,Options,OptionsWidgets,Slash}.lua` |
| **T4.2** | `library-maintainer` | U-1 — per-file LibStub minor bumps + changelog (the three `Perf.lua` strings are user-visible) | **LibKa0s** | same files, `README.md`, changelog |
| **T4.3** | `library-maintainer` | U-1 — add the US-spelling case to the library's own suite | **LibKa0s** | `tests/` |
| **T4.4** | `vendor-sync` | U-1 — whole-folder re-vendor, **own commit** | **AbsorbTracker** | `libs/LibKa0s/` (copy), `README.md` (Credits line), `docs/pending/LEDGER.md` |

**Concurrency:** T4.1-T4.3 are in another repo and run **fully in parallel with M1-M3**. **T4.4 depends on
T4.1-T4.3 shipping** and must not start before the library tag exists.

**Exit criteria for T4.4 (all must hold):**
- `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` → empty.
- `diff -r ../LibKa0s/tests/_kit tests/_kit` → empty (re-vendor the kit too if the release moved it).
- `tests/test_vendor_sync.lua` passes against the new tag.
- The re-vendor is **its own commit**, touching no addon source (library-stack-§7).
- Every other LibKa0s consumer gets the same re-vendor commit — a partially re-vendored collection is
  anti-pattern #45 in slow motion.

**Explicitly forbidden:** patching `libs/LibKa0s/*.lua` in this repo to fix the spellings locally. The next
whole-folder copy reverts it, and the resulting regression has no cause in this repo's history.

---

## Milestone M5 — Documentation truth + gates

**Done when:** the README's `[tests]` badge, `docs/test-cases.md` and the live suite all report the same
number; `## What's new` and the top Version History row agree; and both facts are enforced by a case that can
fail.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| **T5.1** | `docs-writer` | C-7 (F-007) — rewrite the 1.9.0 Version History row + fix its date | `README.md` |
| **T5.2** | `docs-writer` | C-8 (F-016) — version-drift case + `/at profile` README row | `tests/test_docs.lua`, `README.md` |
| **T5.3** | `docs-writer` | C-6 (F-006) — badge case, then regenerate the inventory and set the badge | `tests/test_docs.lua`, `docs/test-cases.md`, `README.md` |

**Concurrency and ordering — this is the plan's one real critical path.** All three touch `README.md`;
T5.2 and T5.3 both touch `tests/test_docs.lua`. They **must serialize**, in the order T5.1 → T5.2 → T5.3.

More importantly, **M5 must run last among the code milestones**: every case added in M1, M2, M3 and T5.2
moves the suite total, and T5.3 regenerates `docs/test-cases.md` and sets the badge from it. Running T5.3
early means chasing the number through five intermediate values, which is precisely the drift the case exists
to stop.

**T5.3 is self-referential** — the badge case is itself a case. Regenerate, then set the badge, then re-run;
the number must be stable on the second run.

---

## Milestone M6 — Dead-code and comment sweep

**Done when:** the two dead functions are gone, the four misleading comments are corrected, the two
unreachable branches are removed, and the suite and lint are unchanged-green.

| Task | Owner-agent role | Implements | Files touched |
|---|---|---|---|
| **T6.1** | `lua-refactorer` | C-9 / F-011, F-012 | `core/Units.lua` |
| **T6.2** | `lua-refactorer` | C-9 / F-013 | `modules/Bar.lua` |
| **T6.3** | `lua-refactorer` | C-9 / F-014 | `core/DebugLogSetup.lua` |
| **T6.4** | `lua-refactorer` | C-9 / F-017 | `settings/Slash.lua` |
| **T6.5** | `lua-refactorer` | C-9 / F-015 | `modules/Timer.lua` |

**Concurrency:** T6.1, T6.2, T6.3 are **parallelizable** (disjoint files).
**Serialization:** T6.4 touches `settings/Slash.lua` → **must follow T1.1**. T6.5 touches `modules/Timer.lua`
→ **must follow T3.1**.

**Pre-flight for T6.1:** re-run the zero-caller grep across `core/ modules/ settings/ defaults/ locales/
tests/` immediately before deleting. A caller added between this review and implementation changes the
answer, and a deletion is the one change class that fails loudest and latest.

---

## Critical-path / concurrency map

```
M1 ─┬─ T1.1 (settings/Slash.lua) ─────────────► T6.4 (settings/Slash.lua)
    └─ T1.2 (settings/General.lua)

M2 ─┬─ T2.1 (core/Data.lua)          [parallel with everything]
    └─ T2.2 (settings/Profiles.lua)  [parallel with everything]

M3 ─┬─ T3.1 (modules/Timer.lua) ─────────────► T6.5 (modules/Timer.lua)
    ├─ T3.2 (modules/Display.lua)
    └─ T3.3 (tests/perf.lua)   [after T3.1 + T3.2]

M4 ── T4.1 → T4.2 → T4.3  [LibKa0s repo — fully parallel with M1-M3]
                    └────► T4.4 (re-vendor commit here)

M6 ─┬─ T6.1, T6.2, T6.3   [parallel]

M5 ── T5.1 → T5.2 → T5.3  [LAST — all touch README.md; T5.3 needs the final suite count]
```

**Shared-file conflicts, stated explicitly:**

- `settings/Slash.lua` — T1.1, T6.4 → **serialize** (T1.1 first).
- `modules/Timer.lua` — T3.1, T6.5 → **serialize** (T3.1 first).
- `README.md` — T5.1, T5.2, T5.3, and T4.4's Credits line → **serialize**; if T4.4 lands after M5, its README
  edit is a one-line change on top and needs no re-run of T5.3 (it does not move the test count).
- `tests/test_docs.lua` — T5.2, T5.3 → **serialize**.
- `docs/test-cases.md` and the badge — touched **only** by T5.3, after every other case has landed.

---

## Checkpoints

| # | After | The human/coordinator verifies |
|---|---|---|
| **CP-1** | M1 | The five new `/at profile` cases each fail against the pre-change handler. Run smoke `C-1` 1.3 in-client — the data-loss path is the one finding here with irreversible consequences, and it is worth confirming by hand before moving on. |
| **CP-2** | M2 | Smoke `C-3` on two classes and `C-5` in-client. Both changes are visual/structural and neither is fully provable headlessly. |
| **CP-3** | M3, before M6 touches the same files | `tests/test_display.lua`'s stub-based cases are green **unchanged** (proof the dispatch-time lookup survived), and T3.3's assertion is allocation-only. |
| **CP-4** | M4 T4.3, before T4.4 | The LibKa0s release exists and is tagged; each touched file's minor moved; the library's own suite now has the spelling case. **Do not re-vendor from an untagged working tree.** |
| **CP-5** | M4 T4.4 | Both `diff -r` checks empty; the re-vendor is its own commit; `tests/test_vendor_sync.lua` green; the other consumers are scheduled. |
| **CP-6** | M5 | Break the badge deliberately → suite red → restore. A gate that cannot fail is decoration. |
| **CP-7** | All | Full `03_SMOKE_TESTS.md` pass, including the regression suite R-1…R-15 and the three taint confirmations. |

---

## Commit strategy

One commit per task, so a bisect lands on a single intent. Suggested subjects (the repo's existing style —
imperative, scope-tagged, and the *why* in the body):

| Task | Suggested subject |
|---|---|
| T1.1 | `fix(slash): /at profile refuses bad names instead of erroring, wiping, or lying` |
| T1.2 | `fix(settings): showOnlyInCombat repaints every bar, not just the player's` |
| T2.1 | `refactor(data): derive the background class color from C_ClassColor, not a second palette` |
| T2.2 | `fix(settings): build the Profiles body on first OnShow (options-ui-§5)` |
| T3.1 | `perf(timer): plain loop on the coalesced repaint pass` |
| T3.2 | `perf(display): hoist the three bus handler bodies to file scope` |
| T3.3 | `test(perf): assert the repaint pass allocates nothing per invocation` |
| T4.4 | `chore(libs): re-vendor LibKa0s vX.Y.Z — US-English sweep` |
| T5.1 | `docs(readme): rewrite the 1.9.0 Version History row to match What's new` |
| T5.2 | `test(docs): pin the version to the TOC and the What's new heading` |
| T5.3 | `docs(readme): tests badge to 469, gated by the inventory` |
| T6.x | `chore: delete two dead Units helpers and correct four stale comments` |

**Never commit on red** (anti-pattern #23), and **never create a branch without an explicit request**
(anti-pattern #21, versioning-git) — this collection is trunk-based.

If the version is bumped as part of shipping this work, the version bump, the `## What's new` roll-forward,
the new Version History row and the `NS.version` change are **one commit** (documentation-§1 item 5,
versioning-git) — which is exactly the coupling T5.2's new case now enforces.
