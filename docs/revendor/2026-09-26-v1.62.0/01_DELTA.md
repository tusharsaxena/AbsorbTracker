Delta: LibKa0s v1.61.0 -> v1.62.0

# The delta (AbsorbTracker)

Copied from the tag `v1.62.0` (`e660362`) with `git -C ../LibKa0s archive v1.62.0 LibKa0s testkit`,
never from a working tree. Item `AT-ATS-RV` of the 2026-09-26 automated-tests sweep
(`Ka0sAddonsCommonTasks/docs/2026-09-26-AUTOMATED_TESTS_SWEEP/`, `ATS-20`, `ATS-21`).

## Base (3a, 3b)

`grep -n '[Bb]undles' CLAUDE.md` named **v1.61.0**. The last payload commit, `1c27f7a`
(`git log -1 --format=%h -- libs/LibKa0s tests/_kit`), carries the same line, and the minors on disk
were v1.61.0's (Options 25, OptionsWidgets 31, OptionsTabs 5). No disagreement. Step 0: the newest
single-tag bundle, `2026-09-26-v1.61.0`, states base v1.60.0, which is what `1c27f7a^` carried.

## Per-file minors (3c), from the tag's `LibKa0s.xml`

| File | Old | New |
|---|---|---|
| `Options.lua` | 25 | 26 |
| `OptionsRegistry.lua` | (new) | `REGISTRY_MINOR` 1 |
| `OptionsWidgets.lua` | 31 | 32 |
| `OptionsIds.lua` | (new) | `IDS_MINOR` 1 |
| `OptionsIdList.lua` | (new) | `IDLIST_MINOR` 1 |
| `OptionsTabs.lua` | 5 | 6 |
| `OptionsCombat.lua` | (new) | `COMBAT_MINOR` 1 |

Every other file is unchanged: Core 8, Env 1, Compat 1, Lifecycle 2, Bus 2, Schema 2, Pool 3,
Item 2, Media 4, Widgets 10, WidgetsDragHandle 3, DebugLog 14, DebugLogDiagnostics 1, Slash 16,
Launcher 4, OptionsCompose 7, OptionsScroll 4, OptionsNav 1, Perf 13, PerfPanel 5. No cross-major
skew. The Options key moves from `25.31.5.7.4.1` to `26.1.32.1.1.6.1.7.4.1`.

## Both diffs (3d), before the copy

`diff -rq --strip-trailing-cr` and plain `diff -rq`, tag against the vendored folders, gave the same
list. In the library, `LibKa0s.xml`, `Options.lua`, `OptionsTabs.lua` and `OptionsWidgets.lua`
differ, and `OptionsCombat.lua`, `OptionsIdList.lua`, `OptionsIds.lua` and `OptionsRegistry.lua` are
only in the tag. In the kit, `README.md`, `framework.lua`, `run-automated-tests.sh`,
`test_layout_cap.lua` and `test_prose.lua` differ, and `inventory.lua`, `prose_coverage.lua` and
`prose_selftests.lua` are only in the tag. Nothing is only in the addon, so nothing is deleted. Every
hunk is the library's own v1.61.0..v1.62.0 change: no fork. After the copy both diffs, content and
bytes, are empty.

## Consumption (3e)

Unchanged. `settings/OptionsSetup.lua:71` is still the one Options lookup, and no major is new.

## Kit revision (3f)

`Kit.VERSION` 27 -> 31. Revisions 28 to 31 are the inventory peel, the prose-gate peel, `None.` under
an empty watch-list table, and generated files left out of the band table. Both payloads move
together, in one commit.

## Contract delta (3g)

None. The v1.62.0 changelog states: "No `NEEDS_*` floor rises, no major is added, and no member,
descriptor field or row field changes." The id members (`IdInput`, `IdList`, `ResolveId`,
`UnnamedCandidates`, `ID_NAME_HINT`) and the registry members (`RegisterOptionsPage`,
`CreateOptionsPanel`, `OpenOptionsPanel`) moved file, unchanged, onto the same instance. No blockers.

## Span (3h)

The audit's listing printed nothing: every tag this addon vendored has a bundle.
