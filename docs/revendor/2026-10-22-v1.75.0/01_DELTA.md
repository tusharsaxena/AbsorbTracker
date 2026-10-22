Delta: LibKa0s v1.71.0 -> v1.75.0

# 01 — Delta (AbsorbTracker)

Run: 2026-10-22, plan item **AT-RV** of the LibKa0s issues #45-#58 run
(`Ka0sAddonsCommonTasks/docs/2026-10-22-LIBKA0S_ISSUES_45_58/`), on branch
`feat/2026-10-22-libka0s-issues-45-58`. The run follows the installed `/dev-copilot:wow-revendor-libka0s`
(dev-copilot 2.4.0) mechanically under the owner's scope ruling: no interview and no GitHub issue
filing. AbsorbTracker is an adopter of none of this release's new surfaces (OWNER_SCOPE A), so every
candidate is listed as not adopted in this run.

Source: the sibling checkout `../LibKa0s`, **local tag `v1.75.0` (commit `265a89e`)**, not yet pushed
(`git -C ../LibKa0s ls-remote --tags origin v1.75.0` prints nothing). The payloads were extracted with
`git -C ../LibKa0s archive v1.75.0 LibKa0s testkit tools | tar -x -C <scratch>`, never a branch tip;
`tools/` only for `prune-icons.lua`, which is not copied into the addon.
`git -C ../LibKa0s log --oneline v1.71.0..v1.75.0` lists 56 commits.
`git -C ../LibKa0s diff --shortstat v1.71.0 v1.75.0 -- LibKa0s` reports 5744 files changed (8165
insertions, 69 deletions; almost all of them the icon TGAs v1.74.0 added), and `-- testkit` 8 files
(633 insertions, 52 deletions).

v1.72.0, v1.73.0 and v1.74.0 were never vendored here. They ride in this range, and no span bundle
is owed for them (3h).

## 3a — Claimed version, before this run

`grep -n '[Bb]undles' CLAUDE.md` gave `CLAUDE.md:43:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.71.0 (MIT).`,
the file's last line. The last payload commit (`git log -1 --format=%H -- libs/LibKa0s tests/_kit`,
`7db2f36`) leaves the same line. Payload check against the claimed tag: `diff -rq` of `<v1.71.0>/LibKa0s`
against `libs/LibKa0s` and of `<v1.71.0>/testkit` against `tests/_kit` both printed nothing
(`payload-matches`). **Base: v1.71.0.** Step 0: the newest single-tag bundle,
`docs/revendor/2026-10-07-v1.71.0/`, states `v1.70.0 -> v1.71.0`, which agrees with the history.

## 3b — Actual version, before this run

The vendored `LibStub` minors were v1.71.0's (the left column of 3c) and `Kit.VERSION` was **38**
(`grep -n 'Kit.VERSION' tests/_kit/framework.lua`). Claim and bytes agree.

## 3c — Per-file minor delta

Walked over the tag's `LibKa0s.xml` rows (34 files -> 40):

| File | v1.71.0 | v1.75.0 |
|---|---|---|
| `Core.lua` | 10 | **11** (comment-only) |
| `Item.lua` | 2 | **3** (`Item.BonusIDsFromLink`) |
| `Glow.lua` | — | **1** (new major `LibKa0s-Glow-1.0`) |
| `Media.lua` | 4 | **5** |
| `MediaIcons.lua` | — | **1** (new file; the three-set catalog, 5,836 names) |
| `Widgets.lua` | 12 | **13** (`W.SearchBox`, `W.TestStrip`) |
| `DebugLog.lua` | 19 | **20** (comment-only) |
| `DebugLogDiagnostics.lua` | 2 | **3** (Glow and Sim in the identity header) |
| `Options.lua` | 28 | **29** (the drawer's attach) |
| `OptionsIdList.lua` | 4 | **5** (comment-only) |
| `OptionsTabs.lua` | 8 | **9** (`O.__releaseChrome` no longer exported) |
| `OptionsDrawer.lua` | — | **1** (new file, `O.Drawer`) |
| `Perf.lua` | 14 | **15** (`Perf.Note` `parentKey = false`) |
| `PerfPanel.lua` | 6 | **7** (comment-only) |
| `Sim.lua` / `SimTimeline.lua` / `SimPanel.lua` | — | **1 / 1 / 1** (new major `LibKa0s-Sim-1.0`) |

Every other file keeps its v1.71.0 minor: Env 2, Compat 1, Lifecycle 3, Bus 2, Schema 2, Pool 3,
WidgetsReorder 1, WidgetsDragHandle 4, WidgetsLineChart 3, WidgetsAutocomplete 2, DebugLogGates 1,
Slash 20 / SlashParse 2, Launcher 5, OptionsRegistry 2, OptionsWidgets 34, OptionsIds 2,
OptionsCombat 1, OptionsCompose 7, OptionsScroll 4, OptionsNav 2, PerfSampler 1, PerfCommands 1.
Keys: Widgets 13.1.4.3.2, DebugLog 20.3.1, Options 29.2.34.2.5.9.1.7.4.2.1, Perf 15.1.1.7, Media 5.1,
Sim 1.1.1. No `NEEDS_*` floor rises. **Seventeen majors across forty files.** `W.StepPanel` is not in
the payload: LK-11 resolved as outcome B, so the step panel is Sim-private (`SimPanel.lua`) with no
public contract. No file is behind the tag after the copy, so there is no cross-major skew.

## 3d — Both diffs

Before the prune, against the whole copy, all four came back **empty**:

```sh
diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s   # empty
diff -r                     <scratch>/LibKa0s libs/LibKa0s   # empty
diff -r --strip-trailing-cr <scratch>/testkit tests/_kit     # empty
diff -r                     <scratch>/testkit tests/_kit     # empty
```

No `Only in libs/LibKa0s` or `Only in tests/_kit` line, so nothing was deleted on inference. The copy
added `Glow.lua`, `MediaIcons.lua`, `OptionsDrawer.lua`, `Sim.lua`, `SimTimeline.lua`, `SimPanel.lua`,
the 5,836-icon `media/icons/` (with `phosphor/` and `game-icons/`) and `tests/_kit/latch.lua`.

**The prune.** From the extract at the tag, `lua <scratch>/tools/prune-icons.lua .` printed one
`removed libs/LibKa0s/media/icons/<file>` line per removal and ended
`prune-icons: .: 4 icon(s) declared; kept 5 file(s), removed 5835`. Afterwards
`find libs/LibKa0s/media/icons -type f | sort` lists exactly `LICENSE-open-iconic.txt`, `clear.tga`,
`close.tga`, `copy.tga`, `help.tga`, and no `phosphor/` or `game-icons/` directory remains.
`media/fonts/` and `media/textures/` are untouched. Against the previous commit, the copy commit
deletes 109 of the 113 Open Iconic TGAs v1.71.0 shipped here and keeps the license file. After the prune,
`diff -r --strip-trailing-cr <scratch>/LibKa0s libs/LibKa0s | grep -v 'Only in .*media/icons'` is
empty: the only lines are 220 `Only in <scratch>/LibKa0s/media/icons: <name>.tga` lines plus one each
for `phosphor` and `game-icons`, which is the declaration working (3i). The kit diff stays empty.

## 3e — Consumption map

`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)' . --include='*.lua' | grep -v '/libs/' | grep -v '/tests/'`:
Env (`core/EnvSetup.lua:62`), Bus (`core/Bus.lua:36`), Media (`core/MediaSetup.lua:82`), Launcher
(`core/LauncherSetup.lua:70`), Core (`core/CoreSetup.lua:26`), Lifecycle (`core/Lifecycle.lua:61`),
DebugLog (`core/DebugLogSetup.lua:14`), Widgets (`core/WidgetsSetup.lua:24`), Perf
(`core/PerfSetup.lua:16`), Options (`settings/OptionsSetup.lua:71`), Schema (`settings/Schema.lua:328`)
and Slash (`settings/Slash.lua:24`, `settings/Schema.lua:498`). **No new major is consumed**: Glow,
Sim, Compat, Pool and Item have no lookup site. Moved and consumed: Core, Media, Widgets, DebugLog,
Options, Perf. `modules/Diagnostics.lua`'s `LIBRARIES` list is the addon's own consumption list and
stays unchanged, since it consumes neither Glow nor Sim.

## 3f — Kit revision, and the pairing rule

`grep -n 'Kit.VERSION' <scratch>/testkit/framework.lua tests/_kit/framework.lua`: **38 -> 41**. Both
payloads are copied whole in one commit, so the pairing rule holds by construction. Revision 39 adds
`latch.lua` (`Kit.assertLatchHoldOrder`) and lets `M.__fireUnconditional` reach method-name and
function handlers; revision 40 gates `media/icons/` against the `LibKa0s icons:` declaration; revision
41 drops `Kit.__deviationRows` / `Kit.__declineFor` and makes a crashed or bounded lizard run a
complexity `fail` with a `crashed` bucket. `docs/test-cases.md` is regenerated: two cases are renamed
(3g c), no case is added or removed, and Total stays **885**, equal to the README badge.

## 3g — Contract delta and blockers

### Contract reads (consumed majors that moved)

- **Core 11, DebugLog 20, OptionsIdList 5, PerfPanel 7: comment-only.** No member or behavior moves.
  The Core and DebugLog comments now say what this addon relies on: `Core.MakeCloseButton` and the
  debug console's CLEAR and COPY buttons draw a **blank** control for a pruned, undeclared icon. All
  three are declared here (3i).
- **Media 5 / MediaIcons 1**: the catalog becomes three sets (5,836 names); unprefixed Open Iconic
  names keep their paths. `core/MediaSetup.lua`'s `NS.Icon` passes plain names and is unaffected.
- **Widgets 13**: additive (`W.SearchBox`, `W.TestStrip`); `lib.DragHandle` and `lib.DRAG_HANDLE`,
  which `modules/Bar.lua` and `modules/Display.lua` read through `core/WidgetsSetup.lua`, are
  unchanged (WidgetsDragHandle stays at 4).
- **Options 29 / OptionsDrawer 1 / OptionsTabs 9**: `O.Drawer` is additive; `O.__releaseChrome` is
  removed. See blockers (a) and (d).
- **Perf 15**: `Perf.Note`'s third argument gains a `false` state; nil and a bucket key keep their
  meaning. This addon passes nil or a bucket key (`modules/Display.lua:276`, `:395`, `:465`), so no
  call site moves; only the nesting footer's wording changes for a declared-but-top-level bucket.
- **DebugLogDiagnostics 3**: the `LibKa0s running:` header names Glow and Sim when the client runs
  them. `Glow.lua` and the Sim files load headless through `LibKa0s.xml` (`tests/run.lua` derives the
  list; `tests/test_loadorder.lua` passes), and both register without LibCustomGlow.
- `grep -rn '__Attach[A-Za-z]*' . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit` finds no
  site.

### Blockers, fixed in the copy commit

The gate on the bare copy plus prune was `882 passed, 3 failed, 1 skipped, 886 total`, with exactly the
three failures (a) and (c) predict.

- **(a) Options parity, `O.Drawer` (OptionsDrawer minor 1, LibKa0s v1.73.0).**
  `tests/test_surface_parity.lua`'s `parity: the Options stub carries every helper the degraded build
  can reach` went red on the new live member. Under that file's own rule (a member with no caller is
  exempt rather than stubbed, the `RefreshPanel` entry), `"Drawer"` joins the exemption list with a
  comment naming the minor, the release, its single roster consumer (QuickComms) and the grep:
  `grep -rn Drawer core modules settings` is empty. `settings/OptionsSetup.lua` is unchanged.
- **(b) Kit 39 `__fireUnconditional`.** The addon's only use is `tests/test_disabled.lua:205`, the
  falsification probe in `disabled 6: firing every baseline event writes nothing, says nothing, shows
  nothing`, which expects `reached == 1`. The case stays green under revision 39 with its SV-write,
  print and shown-frame assertions unchanged. **No change.**
- **(c) Whole-catalog icon tests (3j).** `grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`
  found two cases that the prune turns red:
  - `tests/test_mediasetup.lua`, `MediaSetup: every name the library ships has a file in the vendored
    copy`, iterated `lib.ICONS`. It is rewritten as `MediaSetup: every icon CLAUDE.md declares has a
    file in the vendored copy`: it reads the declaration through the kit's parser
    (`dofile("tests/_kit/vendor_sync.lua").iconDeclaration(<CLAUDE.md text>)`), asserts mode `list`,
    and checks each declared name's `.tga` exists and is non-empty. The FONTS half is unchanged. The
    case before it (`every mark this addon's windows draw is one the library ships`) now also asserts
    the parsed declaration equals exactly `clear, close, copy, help`, so the draw set and the
    declaration are pinned to each other in both directions.
  - `tests/test_optionssetup.lua`, `the art that name points at is vendored on disk`, opened
    `media/icons/info.tga`. `info` is not drawn here, so it is rewritten as `the id-list help mark is
    latent: info is neither declared nor shipped`, asserting `info` is absent from the declaration
    and `libs/LibKa0s/media/icons/info.tga` does not exist; its comment says the case flips the day
    an id list without `helpIcon` lands.
  No second declaration parser is written in the addon.
- **(d) Dead `O.__releaseChrome` mirrors.** `grep -rn __releaseChrome . --include='*.lua' --exclude-dir=libs --exclude-dir=_kit`
  is empty: this addon's Options stub never mirrored it, so there is nothing to delete. Kit 41 also
  drops `Kit.__deviationRows` / `Kit.__declineFor`, which nothing here calls. The kit-41 `crashed`
  complexity bucket changes nothing in the green gate.
- **(e) DebugLogDiagnostics 3** adds Glow and Sim to the library's MAJORS list; the addon's own
  `LIBRARIES` list (`modules/Diagnostics.lua`) is unchanged, and both new majors load headless.

After the fixes: `885 passed, 0 failed, 1 skipped, 886 total`.

## 3h — Tags vendored and never recorded

The audit walk (payload paths plus provenance rolls since the store's first bundle, 2026-08-25) against
the recorded bundle tags prints nothing. **No span bundle is owed.** v1.72.0..v1.74.0 were never
vendored, so they need no record of their own.

## 3i — The icon declaration (decided by the plan)

`grep -n 'LibKa0s icons:' CLAUDE.md` found no line. The provenance line is the file's last line and
does not run on into prose, so nothing is split. The line, pre-decided by the AT-RV item spec and
written as the next non-blank line under the provenance line:

`LibKa0s icons: clear, close, copy, help.`

| Name | Draw site |
|---|---|
| `help` | host seam `NS.Icon` (`core/MediaSetup.lua:120`) from `modules/Bar.lua:133` (`helpIcon = NS.Icon("help")`, the drag handle's ? mark) |
| `close` | host, `modules/Bar.lua:172` (`closeIcon = NS.Icon("close")`, the drag handle's X); library-drawn by `Core.MakeCloseButton` for the debug console and its Copy window (`core/DebugLogSetup.lua` passes `addonName`) and for the perf panel (`core/PerfSetup.lua:45`, `addonName = addonName`) |
| `copy`, `clear` | library-drawn, the debug console's title-bar buttons, wired by `core/DebugLogSetup.lua` |

Not `info`: this addon builds no Options id list (`grep -rn IdList settings modules core` finds only the
inert stub at `settings/OptionsSetup.lua:311`) and hosts no `W.TestStrip`. All four names are Open
Iconic, so only that set and `LICENSE-open-iconic.txt` ship. Hand lists have drifted before (KickCD
`tests/test_mediasetup.lua:28`, WhatGroup `tests/test_mediasetup.lua:19`): a pruned icon still
resolves to a path and draws blank, so the owner's in-client smoke is the backstop.
