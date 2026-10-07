# Execution plan — AbsorbTracker (2026-10-07)

This plan implements `02_PROPOSED_CHANGES.md`. Finding IDs are F-001 … F-008, and change IDs are C-1 … C-6 plus U-1 and U-2. The green gate before every commit is `lua tests/run.lua` and `luacheck .` (0/0), both through `~/.claude/dev-copilot/bin/ka0s-bounded`. No version bump. Nothing is pushed or merged without the owner's go-ahead.

## Milestones

### M1: Perf evidence measures the shipped pass (F-001 → C-1)

- **Done when:** `tests/perf.lua` has a `repaintPass` scenario calling `NS.Timer.__doRepaint`. `probeOverheadOff`/`On` run it. `PROBE_OFF_BYTES_CEILING`'s three comment lines are re-derived from three fresh runs. `docs/performance.md:72-77` names the scenarios truthfully. The perf runner exits 0, and the gate is green.

| Task | Role | Implements | Files |
|---|---|---|---|
| T1.1 | test-author | C-1 (F-001) | `modules/Timer.lua` (seam only), `tests/perf.lua`, `docs/performance.md` |

### M2: Remove the per-pass closure (F-002 → C-2), measured against M1's baseline

- **Done when:** `doRepaint` iterates `NS.Units.LIST` directly. C-1's `repaintPass` bytes/iter is recorded before and after, in one run each, in the commit message. The gate is green and the perf runner exits 0.

| Task | Role | Implements | Files |
|---|---|---|---|
| T2.1 | lua-refactorer | C-2 (F-002) | `modules/Timer.lua` |

### M3: Preview/stand-down edges (F-003 → C-3, F-004 → C-5)

- **Done when:** `runHold` refuses on `NS.IsStoodDown()`. `NS.RelockForCombat()` is the one re-lock, reached from `OnEnterCombat`, `StandUp` and `OnEnable` (the last two only in combat). Three new cases, each with a `-- red under:` line. `docs/test-cases.md` is regenerated, and the README badge moves `876/876` → `879/879` **in the same commits that add the cases**.

| Task | Role | Implements | Files |
|---|---|---|---|
| T3.1 | wow-lua-fixer | C-3 (F-003) | `settings/Slash.lua`, `tests/test_debughold.lua`, `docs/test-cases.md`, `README.md` |
| T3.2 | wow-lua-fixer | C-5 (F-004) | `core/AbsorbTracker.lua`, `core/Lifecycle.lua`, `tests/test_disabled.lua`, `tests/test_events.lua` (or `tests/test_visibility.lua`), `docs/test-cases.md`, `README.md`, and `docs/lifecycle.md` / `docs/ARCHITECTURE.md` → *The disabled state is total* (one sentence on the in-combat stand-up) |

### M4: Stale-evidence cleanup (F-006 → C-4)

- **Done when:** The degraded Perf stub carries no `suspended`, `tests/test_perf.lua:538`'s assertion is gone, and the gate is green with an unchanged case count.

| Task | Role | Implements | Files |
|---|---|---|---|
| T4.1 | test-author | C-4 (F-006) | `core/PerfSetup.lua`, `tests/test_perf.lua` |

### M5: Upstream handoff (F-007 → U-1, F-008 → U-2): a cross-repo milestone

- **Done when:** LibKa0s has released U-1 (`Kit.VERSION` bumped) and U-2 (doc-only), **and** this repo has its own re-vendor commit. That commit copies the whole `tests/_kit/` folder (and `libs/LibKa0s/` if the release touched it), bumps the `CLAUDE.md` provenance line, and regenerates `docs/test-cases.md` with Totals that agree with the badge. The commit that edits LibKa0s files lives in the LibKa0s repo, never here.

| Task | Role | Implements | Repo / files |
|---|---|---|---|
| T5.1 | upstream-author (LibKa0s) | U-1 | `../LibKa0s/testkit/framework.lua`, its tests, `CHANGELOG.md` |
| T5.2 | upstream-author (LibKa0s) | U-2 | `../LibKa0s/docs/api/Perf/` (the current docs version) |
| T5.3 | re-vendor (`/dev-copilot:wow-revendor-libka0s`) | the re-vendor commit | `tests/_kit/` (whole), `libs/LibKa0s/` (whole, if changed), `CLAUDE.md`, `docs/test-cases.md` |

### M6: F-005 (conditional on S-05)

- **Done when:** Either S-05 is **Refuted**, so F-005 is closed in the sign-off table with no code change, or S-05 is **Confirmed** and C-6 has a spec (a stored-shape change with a v6 ladder step) approved by the owner before any code is written.

| Task | Role | Implements | Files |
|---|---|---|---|
| T6.1 | owner (in-client) | S-05 | none |
| T6.2 | wow-lua-fixer (only if Confirmed) | C-6 (F-005) | `modules/Display.lua`, `modules/Bar.lua`, `core/Database.lua`, `docs/schema.md`, `tests/test_database.lua`, `tests/test_display.lua` |

## Critical path and concurrency map

- **T1.1 → T2.1 must serialize.** Both touch `modules/Timer.lua`, and T2.1's evidence is T1.1's scenario. The "before" figure has to be taken at T1.1's commit.
- **T3.1 and T3.2 must serialize** on `docs/test-cases.md` and `README.md`, because each regenerates the inventory and moves the badge. Their source files are disjoint (`settings/Slash.lua` vs `core/AbsorbTracker.lua` + `core/Lifecycle.lua`).
- **T4.1** touches `core/PerfSetup.lua` and `tests/test_perf.lua`, which no other task touches. It is **parallelizable** with M1–M3.
- **T5.1 / T5.2** run in another repo and are **parallelizable** with everything here. **T5.3 must come last** among the tasks that regenerate `docs/test-cases.md` (it serializes after T3.1 and T3.2), so the regenerated inventory carries the new cases and the fixed Totals together.
- **T6.2** (if it happens) touches `modules/Display.lua`, which nothing else here edits. It serializes only on `docs/test-cases.md`/`README.md` if it adds cases.

## Checkpoints

1. **After M1:** Review the re-derived ceiling comment. The three lines must show the measurement, the ceiling and the derived margin, as the existing comment requires.
2. **After M3:** Run S-03 and S-04 in the client before moving on, because these are the behavior changes a player can see.
3. **Before M5's T5.3:** Confirm that LibKa0s has tagged the release, and that the provenance line to be written matches the tag.
4. **M6 gate:** Do not start T6.2 without an S-05 result in the sign-off table.

## Commit strategy (one commit per task, on `feat/2026-10-07-review-audit-remediation`)

| Task | Suggested subject |
|---|---|
| T1.1 | `AT-RV-01: perf runner measures the shipped repaint pass (F-001)` |
| T2.1 | `AT-RV-02: doRepaint iterates the unit list without a per-pass closure (F-002)` |
| T3.1 | `AT-RV-03: /at debug hold refuses while the addon is stood down (F-003)` |
| T3.2 | `AT-RV-04: one combat re-lock, reached from an in-combat stand-up (F-004)` |
| T4.1 | `AT-RV-05: drop the unread Perf.suspended stub member and its assertion (F-006)` |
| T5.3 | `chore: re-vendor LibKa0s vX.Y.Z (kit N; inventory totals exclude skips) (F-007, F-008)` |
| T6.2 | `AT-RV-06: Master scale keeps placed bars where they were (F-005)` (only if S-05 confirms) |

Each message ends with the session's attribution trailers. The commit-id prefix follows the cross-repo bundle's id scheme if the owner assigns one there.
