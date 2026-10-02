Delta: LibKa0s v1.66.0 -> v1.67.0

# 01 — Delta (AbsorbTracker)

Run: 2026-10-02, plan item CA-AT-RV of the 2026-10-02 LibKa0s census adoption
(`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_CENSUS_ADOPTION/`, milestone M2). An orchestrated
session ran the `/wow-addon:revendor-libka0s` mechanics. Adoption candidates are **not** interviewed:
the census-adoption plan already assigns each new surface to an item (`02_CANDIDATES.md`). Target:
this repo, branch `feat/2026-10-02-libka0s-census-adoption`, cut from `master` @ `b70362b`.

Source: the sibling checkout `../LibKa0s`, **local tag `v1.67.0` (tag object `749c42e` -> commit
`0bccf4c`)**. The checkout's `HEAD` is that commit and its tree is clean; the payloads were still
extracted with `git -C ../LibKa0s archive v1.67.0 LibKa0s testkit | tar -x -C <scratch>/`, never a
branch tip. `git -C ../LibKa0s log --oneline v1.66.0..v1.67.0` lists 6 commits: GI-LK-13 and its
merge, CA-LK-01, CA-LK-02 and two CA-LK-03 release commits.

## Base pre-flight

The newest single-tag bundle is `2026-10-01-v1.66.0`, and v1.66.0 is the tag `CLAUDE.md` names. No
tag went unrecorded, so there is no span bundle. No misstated base was found.

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` -> `CLAUDE.md:43: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
v1.66.0 (MIT).` Payload check against the claimed tag: `diff -r <v1.66.0>/LibKa0s libs/LibKa0s` and
`diff -r <v1.66.0>/testkit tests/_kit` are both empty. `docs/testing.md:170` restates the tag in prose
and moves with it. `README.md` has no provenance line.

## 3b — Actual version, before this run

The vendored minors are v1.66.0's (left column of 3c) and `Kit.VERSION` is 35. Claim and bytes agree.

## 3c — Per-file minor delta

The tag's `LibKa0s.xml` is unchanged: 32 script rows, the same order.

| File | v1.66.0 | v1.67.0 |
|---|---|---|
| **`Core.lua`** | 9 | **10** |
| `Env.lua` | 1 | 1 |
| `Compat.lua` | 1 | 1 |
| `Lifecycle.lua` | 3 | 3 |
| `Bus.lua` | 2 | 2 |
| `Schema.lua` | 2 | 2 |
| `Pool.lua` | 3 | 3 |
| `Item.lua` | 2 | 2 |
| `Media.lua` | 4 | 4 |
| `Widgets.lua` | 12 | 12 |
| `WidgetsReorder.lua` (`REORDER_MINOR`) | 1 | 1 |
| `WidgetsDragHandle.lua` (`DRAG_MINOR`) | 3 | 3 |
| `DebugLog.lua` | 19 | 19 |
| `DebugLogDiagnostics.lua` (`DIAG_MINOR`) | 2 | 2 |
| `DebugLogGates.lua` (`GATES_MINOR`) | 1 | 1 |
| `Slash.lua` | 19 | 19 |
| `SlashParse.lua` (`PARSE_MINOR`) | 1 | 1 |
| `Launcher.lua` | 5 | 5 |
| **`Options.lua`** | 27 | **28** |
| `OptionsRegistry.lua` | 2 | 2 |
| `OptionsWidgets.lua` (`WIDGETS_MINOR`) | 34 | 34 |
| `OptionsIds.lua` | 2 | 2 |
| **`OptionsIdList.lua`** (`IDLIST_MINOR`) | 2 | **3** |
| `OptionsTabs.lua` (`TABS_MINOR`) | 8 | 8 |
| `OptionsCombat.lua` | 1 | 1 |
| `OptionsCompose.lua` | 7 | 7 |
| `OptionsScroll.lua` | 4 | 4 |
| `OptionsNav.lua` | 2 | 2 |
| `Perf.lua` | 14 | 14 |
| `PerfSampler.lua` (`SAMPLER_MINOR`) | 1 | 1 |
| `PerfCommands.lua` (`COMMANDS_MINOR`) | 1 | 1 |
| `PerfPanel.lua` (`PANEL_MINOR`) | 6 | 6 |

Three files move a minor and none is added. No major is added (fifteen majors, thirty-two files). No
`NEEDS_*` floor rises. The Options key moves 27.2.34.2.2.8.1.7.4.2 -> 28.2.34.2.3.8.1.7.4.2. The
consumer was behind on no file before the copy (no cross-major skew).

## 3d — Both diffs

Before the copy:

- `libs/LibKa0s`: `Core.lua`, `Options.lua`, `OptionsIdList.lua` differ (125 insertions, 36
  deletions). No `Only in` line on either side.
- `tests/_kit`: no difference. The kit is byte-identical between v1.66.0 and v1.67.0.

Nothing is deleted. After the copy, `diff -r <scratch>/LibKa0s libs/LibKa0s` and
`diff -r <scratch>/testkit tests/_kit` are both empty, as are `diff -r --strip-trailing-cr
../LibKa0s/LibKa0s libs/LibKa0s` and `diff -r ../LibKa0s/testkit tests/_kit`. The archive writes
CRLF, as the v1.66.0 copy did, so the vendored files keep their line endings.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' core modules settings`: Core
(`core/CoreSetup.lua:26`), DebugLog (`core/DebugLogSetup.lua:14`), Lifecycle (`core/Lifecycle.lua:61`),
Media (`core/MediaSetup.lua:82`), Launcher (`core/LauncherSetup.lua:70`), Bus (`core/Bus.lua:36`), Env
(`core/EnvSetup.lua:62`), Perf (`core/PerfSetup.lua:16`), Widgets (`modules/Display.lua:26`,
`modules/Bar.lua:15`), Schema (`settings/Schema.lua:328`), Slash (`settings/Schema.lua:496`,
`settings/Slash.lua:24`), Options (`settings/OptionsSetup.lua:71`). Unchanged from the v1.66.0
bundle.

The TOC loads the library through `libs\LibKa0s\LibKa0s.xml` (`AbsorbTracker.toc:29`), and
`tests/run.lua` derives its library list from the same XML. No file was added, so no row is needed
anywhere.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua` -> **35 -> 35**. The
kit does not move, so there is no new suite to declare and `tests/run.lua` is untouched.

## 3g — Contract delta

Majors that moved a minor and that this addon consumes: Core and Options.

- **Core 10** (`docs/api/Core/version-10-docs.md`, "The resize grip"): `MakeResizable` takes three
  optional fields, `canResize`, `onResizeStop` and `gripParent`. `grep -rn MakeResizable core modules
  settings` finds no host call; the only callers are the library's own console, copy window and perf
  panel, which pass none of the three and behave as on v1.66.0. No member is added, so
  `core/CoreSetup.lua`'s degradation stubs need nothing.
- **Options 28 / OptionsIdList 3** (`docs/api/Options/version-28.2.34.2.3.8.1.7.4.2-docs.md`): an
  `O.IdList` help mark's default art takes the descriptor's `addonName` only when the client reports
  that addon loaded, and a fall past that rung writes one `Cfg` debug line per instance. Options 28
  is a docblock correction. This addon draws no `O.IdList`, so `idHelpIcon` is never reached and no
  line is written. `settings/OptionsSetup.lua`'s descriptor passes no `addonName` today; CA-AT-NM
  adds it.

`grep -rn '__Attach[A-Za-z]*' core modules settings` finds no site, so no host-supplied callback
moved. **No blockers.** The suite was green on the copy with only the provenance line changed
(`05_SUMMARY.md`).
