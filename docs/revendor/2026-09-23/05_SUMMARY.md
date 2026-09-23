# 05 - Summary: LibKa0s v1.54.2 -> v1.55.0

Steps 5-8 of `/wow-addon:revendor-libka0s`, run on 2026-09-23 on branch
`suite/2026-09-22-standards-sweep` under the owner's delegation (CP-6 of the suite sweep) in place of
the Step 6 interview. Steps 2-4 are `01_DELTA.md` (copy: `27ccce6`, badge follow-up: `d5e37d6`).

## The tag, and the per-file minors

v1.54.2 -> v1.55.0 (commit `6f9c5e0`). No existing file's LibStub minor moved; three majors are new:
`Compat.lua` (Compat 1), `Bus.lua` (Bus 1), `Schema.lua` (Schema 1). Test kit revision 24 -> 25.
The full table is `01_DELTA.md` section 3c.

## Delivered for free (class A)

- Test kit revision 25: the layout-section-1 cap census gate, the `.gitattributes` body case in
  `test_eol`, the (basename, directory) suite key and the commit SHA in the automated-test record.
  Wired in `27ccce6`.
- The three new majors register from the XML; the copy alone changed no behavior.

## Contract blockers

None (`01_DELTA.md` section 3g).

## Adopted

| Candidate | Commit | Tests added or re-pinned |
|---|---|---|
| C1 `LibKa0s-Bus-1.0` (record + `Catalog`) | `92c48d8` | Characterization first (2): the catalog's five names by `pairs`; the five bus (message, target) pairs through a full disable/enable, each consumer reached once. With the change (7): the live build is on the library; the catalog is strict; the degraded load (untracked-target stub: a working private target, 0 / 0 from the latch calls, a plain catalog); the stub's parity by name; a registration made while down is not live until the stand-up; an owner's unregister is not resurrected; the record's counts and the refused bare stand-up. |
| C2 `LibKa0s-Schema-1.0` (full adopter) | `0e72839` | Characterization first (3): the write's order; the lock verbs and the combat re-lock writing the store on a degraded load. With the change (5 new): the live runtime is the library's and the host names are its members; the minimap row survives a sweep and a named reset still resets it; an unknown path is refused (replaces the case that pinned the opposite); a table value is stored as a copy; the stub's lib-level and instance parity (2). Re-pinned: `SetSetting`'s four cases to `SetByPath`; the two degraded Reset All log cases to "the write landed, the line is absent"; the probe rows to registered rows carrying their own `get`/`set`; one `test_slash` case off a legacy row-less path. |

What each adoption changed for a player: nothing visible on a LibKa0s-present install. On a
LibKa0s-less install, a disable now leaves the five bus subscriptions registered (C1; the handlers
still answer to the latch, so nothing draws), recorded in `docs/ARCHITECTURE.md` Known Limitations.
C2's degraded build stops writing debug lines the degraded console already discarded.

`docs/ARCHITECTURE.md` now names both majors (Module Map row, Message Bus, "What stands down",
Settings Schema, the minimap reset paragraph); no Documented-deviations row was tied to either seam,
so none was retired. `docs/module-map.md`, `schema.md`, `data-flow.md`, `settings-panel.md`,
`profiles.md` and `common-tasks.md` were brought to the new seam names in the same commits.

## Declined

| Candidate | Decision | Issue | Labels |
|---|---|---|---|
| C3 `LibKa0s-Compat-1.0` | never | https://github.com/tusharsaxena/AbsorbTracker/issues/31 | `state:will-not-do`, `severity:low` |

Why: the spec (`compat.md` section 8.8) records AbsorbTracker as re-vendor only; the addon has no
spell, specialization or secret reader for the major to route. The issue is **open**: closing it
(the shape the earlier LibKa0s declines #26-#28 carry) was refused by the session's permission
check, so that is left to the owner.

## Skipped or unreached

None. Every candidate was decided.

## Suite results at each gate

Every figure is from `~/.claude/wow-addon/bin/ka0s-bounded lua tests/run.lua` and the linter under
the same wrapper, run on the tree being committed.

| Gate | Tests | Linter |
|---|---|---|
| Baseline (`d5e37d6`) | 674 passed, 0 failed, 0 skipped, 674 total | 0 warnings / 0 errors in 60 files |
| C1 characterization, old code | 676 passed, 0 failed, 0 skipped | not run (no code change) |
| C1 commit `92c48d8` | 683 passed, 0 failed, 0 skipped, 683 total | 0 / 0 in 60 files |
| C2 characterization, old code | 686 passed, 0 failed, 0 skipped | not run (no code change) |
| C2 commit `0e72839` | 691 passed, 0 failed, 0 skipped, 691 total | 0 / 0 in 60 files |
| Bundle commit | 691 passed, 0 failed, 0 skipped, 691 total | 0 / 0 in 60 files |

`lua tests/perf.lua` (same wrapper) after C2: `probeOverheadOff` 48.0 bytes/iter against its 72
ceiling (48.0 at baseline), `settingsRead` 0.0 (0.0), `appearancePass` 385.8 (384.2; no ceiling).
Lizard was not run: no playbook step here asks for it, and no function's shape was the question.

`docs/test-cases.md` was regenerated with each code commit (`lua tests/run.lua --list`) and reads
691; the README badge moved with it.

## Upstream findings

None against the payload. Two notes for the spec owners, neither blocking: the Schema spec's
"values, no wrappers" for the descriptors' `set` / `applyDefault` would drop this addon's Slash
panel refresh and its suite's spy seam (kept as closures, `03_DECISIONS.md`); and the Schema spec's
`notMinimap` predicate for the reset count omits the profiles-page exclusion this host had.
