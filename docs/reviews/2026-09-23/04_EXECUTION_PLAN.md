# Execution plan — AbsorbTracker (2026-09-23)

Branch: `feat/2026-09-23-review-audit-remediation`, which is already checked out. Every task ends green: `lua tests/run.lua` and `luacheck .` at 0/0, both run through `~/.claude/wow-addon/bin/ka0s-bounded`. Per the user's plan for this sweep, **upstream work lands first**: M0 must be complete before any addon-side milestone that depends on it.

## M0 — Upstream: fix the kit's AceDB fake, then re-vendor (F-006 / U-01)

**Done when:** the LibKa0s kit revision is bumped and released, and this repo carries a re-vendor commit whose `diff -r tests/_kit ../LibKa0s/testkit` is empty, with the suite green.

| Task | Owner | Covers | Files |
|---|---|---|---|
| M0-T1 | lib-maintainer (in the LibKa0s repo) | U-01 | `LibKa0s/testkit/mock_record.lua`, kit revision doc, CHANGELOG |
| M0-T2 | revendor-agent (this repo) | U-01 | `tests/_kit/**` (whole-folder copy only) |

This milestone is a cross-repo hand-off. M0-T2 is **a copy, never an edit**. If the collection-wide sweep re-vendors all of LibKa0s (`libs/LibKa0s/` and `testkit/`) in one pass, M0-T2 is that pass's commit for this repo.

**Checkpoint CP0:** the suite is green on the re-vendored kit before M1 starts. If a case goes red, it is a real bug being exposed. Log it, and do not patch the kit locally.

## M1 — Truthful host verbs (F-001, F-002, F-003, F-011)

**Done when:** C-01, C-02, C-03 and C-10 are in place, each with red-first tests; `docs/test-cases.md` and the README badge are regenerated in the same commit; the suite shows 716/716.

| Task | Owner | Covers | Files |
|---|---|---|---|
| M1-T1 | lua-refactorer | F-001, F-002 (C-01, C-02) | `settings/Slash.lua` (PROFILE_VERBS), `tests/test_slashcmds.lua`, `docs/profiles.md`, `docs/smoke-tests.md` |
| M1-T2 | ux-cleanup | F-003 (C-03) | `settings/Slash.lua` (COMMANDS lock/unlock, `setEnabled`), `tests/test_slashcmds.lua`, `README.md`/`docs/slash-dispatch.md` if they quote the old line |
| M1-T3 | ux-cleanup | F-011 (C-10) | `settings/Slash.lua` (`runTestHold`), `tests/test_slashcmds.lua` |
| M1-T4 | docs | inventory | `docs/test-cases.md` (regenerated), `README.md` badge |

**Concurrency.** T1, T2 and T3 all touch `settings/Slash.lua` and `tests/test_slashcmds.lua`, so they **must be serialized** in the order T1 → T2 → T3. T4 runs last, in the same commit as the final case addition or as the closing commit of the milestone. The standard wants the badge to move with the count, so fold T4 into each task's commit if the tasks are committed separately.

**Checkpoint CP1:** a human runs smoke tests C-01, C-02 and C-03 in the client.

## M2 — Test hygiene (F-004)

**Done when:** no test addresses a flat `barWidth` or the pages `bar`/`border`, and the suite is green.

| Task | Owner | Covers | Files |
|---|---|---|---|
| M2-T1 | test-hygiene | F-004 (C-04) | `tests/test_slashcmds.lua` |

This must come after M1, because it edits the same file. The next command confirms there are no leftovers:

```sh
git grep -n 'RestoreDefaults("bar")\|RestoreDefaults("border")\|rawSet("barWidth"' tests/
```

It must print nothing.

## M3 — Comments, lint, dead code, brand (F-005, F-007, F-008, F-009, F-012, F-013)

**Done when:** C-05 through C-08, C-11 and C-12 are applied; lint is 0/0; the suite is green with the same count.

| Task | Owner | Covers | Files | Parallel? |
|---|---|---|---|---|
| M3-T1 | docs/naming | F-005 (C-05) | `settings/Slash.lua` (comment) | after M1 (same file) |
| M3-T2 | docs/naming | F-007 (C-06) | `settings/General.lua`, `core/PerfSetup.lua`, `core/CoreSetup.lua`, `core/AbsorbTracker.lua`, `defaults/Profile.lua`, `core/Constants.lua`, `docs/ARCHITECTURE.md` | parallel with T3, T4, T5; serialize with M4 on `core/AbsorbTracker.lua` |
| M3-T3 | lint | F-008 (C-07) | `.luacheckrc` | parallel |
| M3-T4 | lua-refactorer | F-009, F-012 (C-08, C-11) | `settings/OptionsSetup.lua`, `settings/Schema.lua` | parallel |
| M3-T5 | test-hygiene | F-013 (C-12) | `modules/Bar.lua`, `tests/test_display.lua`, `tests/test_data.lua`, `tests/test_slashcmds.lua` | after M2 (same test file) |

## M4 — Profile-adopt de-duplication (F-010)

**Done when:** a characterization test pins the pre-change publish counts, the change lands, and the off→on edge drops from 2 APPEARANCE deliveries to 1.

| Task | Owner | Covers | Files |
|---|---|---|---|
| M4-T1 | lua-refactorer | F-010 (C-09) | `core/AbsorbTracker.lua`, `tests/test_disabled.lua` or `tests/test_database.lua` |

M4-T1 **must be serialized with M3-T2**, because both edit `core/AbsorbTracker.lua`.

**Checkpoint CP2:** a human runs the full `03_SMOKE_TESTS.md` regression suite and the cross-addon root check.

## Critical path

M0 → CP0 → M1 (T1 → T2 → T3 → T4) → CP1 → M2 → M3-T5, with M3-T1 after M1. M3-T2, T3 and T4 can run alongside M2. M4-T1 runs after M3-T2 → CP2.

## Commit strategy

One commit per task. Suggested messages:

- M0-T2: `Re-vendor LibKa0s testkit rev <N> (AceDB fake raises like AceDB)`
- M1-T1: `Refuse /at profile new on an existing name; name-check copy and delete`
- M1-T2: `lock/unlock echo the stored value in the set shape and refresh the panel`
- M1-T3: `Validate /at test's duration and announce what it holds`
- M2-T1: `Point profile and reset tests at units.player.* and the appearance page`
- M3-T1/T2: `Correct comments that describe removed mechanisms`
- M3-T3: `Drop eight unused read_globals from .luacheckrc`
- M3-T4: `Options title reads C.BRAND; drop the dead printer fallback`
- M3-T5: `Move the player-bar aliases out of production into the tests`
- M4-T1: `Profile adopt: no second appearance pass on an enable edge`

Push to origin after M1 and after M3/M4. Merging needs the user's go-ahead.
