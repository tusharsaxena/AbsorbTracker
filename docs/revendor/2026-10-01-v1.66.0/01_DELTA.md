Delta: LibKa0s v1.65.0 -> v1.66.0

# 01 — Delta (AbsorbTracker)

Run: 2026-10-01, plan item GI-AT-RV of the 2026-10-01 GitHub issue pass
(`Ka0sAddonsCommonTasks/docs/2026-10-01-GITHUB_ISSUE_PASS/`, milestone M2, spec S4). An orchestrated
session ran the `/wow-addon:revendor-libka0s` mechanics. The plan says adoption candidates are
**not** interviewed this cycle (`03_DECISIONS.md`). Target: this repo, branch
`feat/2026-10-01-github-issue-pass`, cut from `master` @ `f9f3645`.

Source: the sibling checkout `../LibKa0s`, **local tag `v1.66.0` (tag object `178ee0b` -> commit
`e4c5ef7`)**, extracted with `git -C ../LibKa0s archive v1.66.0 LibKa0s testkit | tar -x -C <scratch>/`,
never a branch tip. `git -C ../LibKa0s log --oneline v1.65.0..v1.66.0` lists 24 commits, GI-LK-01 to
GI-LK-12 with their `R` fixes.

## Base pre-flight

Two tags vendored here since the newest single-tag bundle (`2026-09-29-v1.63.0`) had no bundle:
v1.64.0 and v1.65.0. They are recorded in the span bundle `docs/revendor/2026-10-01-v1.64.0-v1.65.0/`.
No misstated base was found.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:43: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.65.0 (MIT).` The last payload commit is `1469a8b` (DG-AT-01), whose line names v1.65.0. Payload
check against the claimed tag: `diff -rq <v1.65.0>/LibKa0s libs/LibKa0s && diff -rq <v1.65.0>/testkit
tests/_kit` prints `payload-matches`. `docs/testing.md:170` restates the tag in prose and moves with it.
`README.md` has no provenance line.

## 3b — Actual version, before this run

The vendored minors are v1.65.0's (left column of 3c) and `Kit.VERSION` is 34. Claim and bytes agree.

## 3c — Per-file minor delta

The tag's `LibKa0s.xml` has 32 script rows against the vendored 28: it adds `WidgetsReorder.lua`
(after `Widgets.lua`), `SlashParse.lua` (after `Slash.lua`), and `PerfSampler.lua` and
`PerfCommands.lua` (after `Perf.lua`).

| File | v1.65.0 | v1.66.0 |
|---|---|---|
| `Core.lua` | 9 | 9 |
| `Env.lua` | 1 | 1 |
| `Compat.lua` | 1 | 1 |
| `Lifecycle.lua` | 3 | 3 |
| `Bus.lua` | 2 | 2 |
| `Schema.lua` | 2 | 2 |
| `Pool.lua` | 3 | 3 |
| `Item.lua` | 2 | 2 |
| `Media.lua` | 4 | 4 |
| **`Widgets.lua`** | 11 | **12** |
| **`WidgetsReorder.lua`** (`REORDER_MINOR`) | — | **1** (new file) |
| `WidgetsDragHandle.lua` (`DRAG_MINOR`) | 3 | 3 |
| **`DebugLog.lua`** | 18 | **19** |
| `DebugLogDiagnostics.lua` (`DIAG_MINOR`) | 2 | 2 |
| `DebugLogGates.lua` (`GATES_MINOR`) | 1 | 1 |
| **`Slash.lua`** | 18 | **19** |
| **`SlashParse.lua`** (`PARSE_MINOR`) | — | **1** (new file) |
| `Launcher.lua` | 5 | 5 |
| `Options.lua` | 27 | 27 |
| `OptionsRegistry.lua` | 2 | 2 |
| **`OptionsWidgets.lua`** (`WIDGETS_MINOR`) | 33 | **34** |
| `OptionsIds.lua` | 2 | 2 |
| `OptionsIdList.lua` | 2 | 2 |
| **`OptionsTabs.lua`** (`TABS_MINOR`) | 7 | **8** |
| `OptionsCombat.lua` | 1 | 1 |
| `OptionsCompose.lua` | 7 | 7 |
| `OptionsScroll.lua` | 4 | 4 |
| `OptionsNav.lua` | 2 | 2 |
| **`Perf.lua`** | 13 | **14** |
| **`PerfSampler.lua`** (`SAMPLER_MINOR`) | — | **1** (new file) |
| **`PerfCommands.lua`** (`COMMANDS_MINOR`) | — | **1** (new file) |
| `PerfPanel.lua` (`PANEL_MINOR`) | 6 | 6 |

Six files move a minor and four are added. No major is added (fifteen majors, thirty-two files). No
`NEEDS_*` floor rises. The consumer was behind on no file before the copy (no cross-major skew).

## 3d — Both diffs

Before the copy, content and bytes agree:

- `libs/LibKa0s`: `DebugLog.lua`, `LibKa0s.xml`, `OptionsTabs.lua`, `OptionsWidgets.lua`, `Perf.lua`,
  `Slash.lua`, `Widgets.lua` differ; `Only in <scratch>/LibKa0s`: `PerfCommands.lua`,
  `PerfSampler.lua`, `SlashParse.lua`, `WidgetsReorder.lua`.
- `tests/_kit`: `README.md`, `asserts.lua`, `framework.lua`, `inventory.lua`, `mock_base.lua`,
  `run-automated-tests.sh`, `test_eol.lua` differ; `Only in <scratch>/testkit`: `lizard_sighted.lua`,
  `test_lizard_sighted.lua`.

No `Only in libs/LibKa0s` or `Only in tests/_kit` line, so nothing is deleted. After the copy,
`diff -r <scratch>/LibKa0s libs/LibKa0s` and `diff -r <scratch>/testkit tests/_kit` are both empty.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua'` outside `libs/` and
`tests/`: Core (`core/CoreSetup.lua:26`), DebugLog (`core/DebugLogSetup.lua:14`), Lifecycle
(`core/Lifecycle.lua:61`), Media (`core/MediaSetup.lua:82`), Launcher (`core/LauncherSetup.lua:70`),
Bus (`core/Bus.lua:36`), Env (`core/EnvSetup.lua:62`), Perf (`core/PerfSetup.lua:16`), Widgets
(`modules/Display.lua:26`, `modules/Bar.lua:15`), Schema (`settings/Schema.lua:328`), Slash
(`settings/Schema.lua:496`, `settings/Slash.lua:24`), Options (`settings/OptionsSetup.lua:71`).
Unchanged from the v1.63.0 bundle. Pool, Item and Compat are reached only through the library.

The TOC loads the library through `libs\LibKa0s\LibKa0s.xml` (`AbsorbTracker.toc:29`), and
`tests/run.lua` derives its library list from the same XML, so the four new files need no TOC or
runner row.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **34 -> 35**. Both
payloads move together in one commit, and `tests/run.lua` declares the kit's new suite
`{ name = "test_lizard_sighted", dir = "tests/_kit/" }` in the same commit (kit 35 adoption step 1).

## 3g — Contract delta

Majors that moved a minor and that this addon consumes: Widgets, DebugLog, Slash, Options and Perf.

- **Slash 19** (`docs/api/Slash/version-19.1-docs.md`): `ParseValue` / `FormatValue` take an optional
  third argument, and a host `parse` receives it. `grep -rn 'parse *=' settings core modules` finds no
  host `parse`; `settings/Schema.lua:504` calls the two-argument `FormatValue`, which answers as before.
- **DebugLog 19**, **Slash 19** `lib:New`: descriptor reads hoisted to file-level helpers, no field,
  default or string moves.
- **Widgets 12**: `ReorderList` moved to `WidgetsReorder.lua`; this addon draws no reorder list.
- **OptionsWidgets 34**: `RenderGrid` takes `parent` and `opts`; a failed wide item no longer leaves
  a blank row and spacer. `settings/UnitPanel.lua:272` calls the two-argument form.
- **OptionsTabs 8**: three opt-in fields, all off by default.
- **Perf 14**: `BuildRecord` emits a declared ancestor with zero counts when only its child fired;
  `core/PerfSetup.lua:65` and `:74` declare `within`, so a capture where only `paintBar` or
  `visibility` fired now carries `repaintPass` / `appearance` as zero rows. Additive within schema 2.

`grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no
site, so no host-supplied callback moved. **No blockers.** The suite was green on the copy with only
the provenance line and the suite wiring changed (`05_SUMMARY.md`).
