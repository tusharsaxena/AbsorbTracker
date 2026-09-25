# 05 — Summary: LibKa0s v1.58.0 -> v1.60.0

Plan item DR-AT-01 of the 2026-09-25 diagnostics rollout, run 2026-09-26 on branch
`feat/2026-09-25-diagnostics-rollout`. Nothing was pushed, no issue was filed and the addon version
was not bumped. `libs/` and `tests/_kit/` were not touched after the copy.

## The move

The vendored LibKa0s moved from **v1.58.0** to **v1.60.0** (tag object `ac59511`, commit `bed0eb1`),
spanning v1.59.0, which was never vendored here on its own. One `DR-AT-01:` commit copied both
payloads whole, rolled the `CLAUDE.md` provenance line and the prose restatement in
`docs/testing.md`, and carried every edit the suite needed to stay green. Three files move a minor
and one is added (`01_DELTA.md` 3c): `WidgetsDragHandle.lua` 2 -> 3, `DebugLog.lua` 13 -> 14,
`Slash.lua` 15 -> 16, and the new `DebugLogDiagnostics.lua` at 1. The kit moves 26 -> 27. Nothing
was deleted: neither diff showed an `Only in` line on this side.

## Delivered for free (class A)

The 3000-line console buffer and its 128-line slack, the copy-timing switch, `diagnostics` live
while disabled (through the `liveVerbs` builder, which reads `SlashLib.LIVE_VERBS`), and the kit's
diagnostics contract suite, declared and skipping until the report is wired.

## Contract blocker (3g)

One, resolved in the copy commit: the degraded DebugLog stub in `core/DebugLogSetup.lua` gained
`RunDiagnostics` (the collection's library-absent line naming `/at diagnostics`, nothing written,
returns 0), `BuildDiagnostics` (an empty report) and `DebugVerb` (`diagnostics`, `on` and `off`
answered, anything else left to the host). Evidence: `docs/api/DebugLog/version-14.1-docs.md:616-619`
and CHANGELOG v1.60.0 "What a consumer owes". A new case in `tests/test_debuglog.lua` pins the
stub's line, count and routing.

## Also in the copy commit

- `tests/run.lua` declares `{ name = "test_diagnostics_contract", dir = "tests/_kit/" }`.
- The spelled-out live-verb sets (`tests/test_disabled.lua` step 7, `tests/test_slashcmds.lua`
  `LIVE_WHILE_DISABLED`) gain `diagnostics`, and the builder comment in `settings/Slash.lua` says
  thirteen reserved verbs. Both sets are walked over `NS.COMMANDS`, so the row is inert until
  DR-AT-03 ships the verb.
- `docs/test-cases.md` regenerated; README badge 776/776 -> 777/778 (one declared skip).

## Adopted, declined, skipped

- **Adopted later in this branch** (`03_DECISIONS.md`): the diagnostics report (DR-AT-03) and the
  DragHandle close mark on every bar (DR-AT-06).
- **Declined**: none, so no issue was filed.
- **Deferred to their own items**: the docs that still say 1500 lines, twelve reserved verbs,
  twenty-one library files or kit revision 26 (`docs/ARCHITECTURE.md:49`, `:191`,
  `docs/module-map.md:808`, `:855`, `:888`, `:908`, `docs/performance.md:390`) are DR-AT-05's and
  DR-AT-07's (`sync-docs`).

## Gates after the copy commit

All run through `/home/tushar/.claude/wow-addon/bin/ka0s-bounded`.

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 64 files |
| `lua tests/run.lua` | 777 passed, 0 failed, 1 skipped (the kit's diagnostics contract), 778 total |
| `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | no thresholds exceeded, no function above CCN 15 |
| layout-§1 cap | largest authored file `tests/test_helpers.lua`, 1447 lines |

Before the stub edit the copy alone ran 775 passed, 1 failed (the DebugLog parity case), 1 skipped.
