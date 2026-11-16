Delta: LibKa0s v1.94.0 -> v1.105.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.105.0 LibKa0s testkit tools` (tag commit 79b1d9c, a local tag, not yet on origin). Run under item RV-AT of Ka0sAddonsCommonTasks `docs/2026-11-16-LIBKA0S_ISSUES_75_PLUS/` (the copy and bundle half of `/dev-copilot:wow-revendor-libka0s` 2.10.0; adoption is that run's phase [3]).

## 3a Base
- `grep -n 'Bundles' CLAUDE.md` named v1.94.0 before the roll (CLAUDE.md:47).
- Last payload commit, `git log -1 --format=%h -- libs/LibKa0s tests/_kit` = 03998d9 (W1-AT-03); its CLAUDE.md names v1.94.0. They agree.
- Payload before the copy equalled the library at v1.94.0: `diff -rq --strip-trailing-cr` of both payloads against a v1.94.0 extract printed nothing beyond the icons the declaration prunes (payload-matches).
- Library range: `git -C ../LibKa0s log --oneline v1.94.0..v1.105.0` is 114 commits; tags in it: v1.95.0 to v1.105.0 (eleven). `git -C ../LibKa0s diff --shortstat v1.94.0 v1.105.0`: 653 files changed, 341739 insertions(+), 1603 deletions(-) (most of it the voice packs and docs).
- Step 0 pre-flight for this addon: the newest single-tag bundle, `2026-11-07-v1.93.0`, states base v1.92.0, and the provenance before its re-vendor (f9153a8) was v1.92.0. ok, no correction.

## 3b/3c Per-file minors that moved (old = this addon, new = v1.105.0)
```
Core.lua  old: local MAJOR, MINOR = "LibKa0s-Core-1.0", 17  new: local MAJOR, MINOR = "LibKa0s-Core-1.0", 18
Tooltip.lua  old:   new: local MAJOR, MINOR = "LibKa0s-Tooltip-1.0", 1
Role.lua  old:   new: local MAJOR, MINOR = "LibKa0s-Role-1.0", 1
Callout.lua  old:   new: local MAJOR, MINOR = "LibKa0s-Callout-1.0", 4
CalloutSettings.lua  old:   new: local SETTINGS_MINOR = 5
WaypointArrow.lua  old:   new: local MAJOR, MINOR = "LibKa0s-WaypointArrow-1.0", 2
WaypointArrowSettings.lua  old:   new: local SETTINGS_MINOR = 2
Charts.lua  old: local MAJOR, MINOR = "LibKa0s-Charts-1.0", 1  new: local MAJOR, MINOR = "LibKa0s-Charts-1.0", 2
Media.lua  old: local MAJOR, MINOR = "LibKa0s-Media-1.0", 12  new: local MAJOR, MINOR = "LibKa0s-Media-1.0", 13
SkinDefs.lua  old: local DEFS_MINOR = 27  new: local DEFS_MINOR = 28
SkinDefsOthers.lua  old: local OTHERS_MINOR = 8  new: local OTHERS_MINOR = 10
Widgets.lua  old: local MAJOR, MINOR = "LibKa0s-Widgets-1.0", 26  new: local MAJOR, MINOR = "LibKa0s-Widgets-1.0", 27
WidgetsDropdown.lua  old: local DROPDOWN_MINOR = 1  new: local DROPDOWN_MINOR = 2
WidgetsReorder.lua  old: local REORDER_MINOR = 6  new: local REORDER_MINOR = 7
WidgetsDragHandle.lua  old: local DRAG_MINOR = 13  new: local DRAG_MINOR = 14
WidgetsDragHandleTip.lua  old:   new: local DRAGTIP_MINOR = 1
WidgetsCopyWindow.lua  old: local COPY_MINOR = 5  new: local COPY_MINOR = 6
WidgetsHeader.lua  old:   new: local HEADER_MINOR = 1
WidgetsBar.lua  old:   new: local BAR_MINOR = 1
DebugLog.lua  old: local MAJOR, MINOR = "LibKa0s-DebugLog-1.0", 22  new: local MAJOR, MINOR = "LibKa0s-DebugLog-1.0", 23
DebugLogDiagnostics.lua  old: local DIAG_MINOR = 7  new: local DIAG_MINOR = 11
DebugLogWindow.lua  old: local WINDOW_MINOR = 4  new: local WINDOW_MINOR = 5
Launcher.lua  old: local MAJOR, MINOR = "LibKa0s-Launcher-1.0", 9  new: local MAJOR, MINOR = "LibKa0s-Launcher-1.0", 11
OptionsWidgets.lua  old: local WIDGETS_MINOR = 45  new: local WIDGETS_MINOR = 46
OptionsNav.lua  old: local NAV_MINOR = 6  new: local NAV_MINOR = 7
OptionsSkinPicker.lua  old: local PICKER_MINOR = 11  new: local PICKER_MINOR = 12
OptionsSkinPickerQueue.lua  old:   new: local QUEUE_MINOR = 1
IconBrowserWindow.lua  old: local WINDOW_MINOR = 1  new: local WINDOW_MINOR = 2
IconBrowser.lua  old: local BROWSER_MINOR = 1  new: local BROWSER_MINOR = 2
PerfPanel.lua  old: local PANEL_MINOR = 13  new: local PANEL_MINOR = 14
Sim.lua  old: local MAJOR, MINOR = "LibKa0s-Sim-1.0", 2  new: local MAJOR, MINOR = "LibKa0s-Sim-1.0", 3
SimPanel.lua  old: local SIM_PANEL_MINOR = 10  new: local SIM_PANEL_MINOR = 11
SimPanelRender.lua  old: local RENDER_MINOR = 3  new: local RENDER_MINOR = 4
```
An empty `old:` is a file new in this range (Tooltip, Role, Callout, CalloutSettings, WaypointArrow, WaypointArrowSettings, WidgetsDragHandleTip, WidgetsHeader, WidgetsBar, OptionsSkinPickerQueue). Every file not listed matched v1.94.0 before the copy, so there is no cross-major skew. No file was removed upstream (`ls` of both trees differs only by additions), so nothing in `libs/` was deleted by hand.

## 3d Diffs
Before the prune, `diff -r --strip-trailing-cr` of both payloads against the v1.105.0 extract printed nothing. After the prune the only differences are the undeclared icons and the voice packs under `media/sounds/` (this addon has no `LibKa0s sounds:` line, so sounds is none). `tests/test_vendor_sync.lua` is green under both profiles.

## 3e Consumption map
`grep -rnoE 'LibStub\("LibKa0s-[A-Za-z]+-1\.0", true\)'` over the addon's own source (not libs, not tests):
```
core/Bus.lua:36           LibKa0s-Bus-1.0
core/CoreSetup.lua:26     LibKa0s-Core-1.0
core/Database.lua:174,285 LibKa0s-Skin-1.0
core/DebugLogSetup.lua:14 LibKa0s-DebugLog-1.0
core/EnvSetup.lua:62      LibKa0s-Env-1.0
core/LauncherSetup.lua:79 LibKa0s-Launcher-1.0
core/Lifecycle.lua:61     LibKa0s-Lifecycle-1.0
core/MediaSetup.lua:82    LibKa0s-Media-1.0
core/PerfSetup.lua:16     LibKa0s-Perf-1.0
core/SkinSetup.lua:83     LibKa0s-Skin-1.0
core/WidgetsSetup.lua:24  LibKa0s-Widgets-1.0
modules/Sim.lua:160       LibKa0s-Sim-1.0
settings/OptionsSetup.lua:76 LibKa0s-Options-1.0
settings/Schema.lua:328   LibKa0s-Schema-1.0
settings/Schema.lua:497   LibKa0s-Slash-1.0
settings/Slash.lua:24     LibKa0s-Slash-1.0
```
Majors in the payload with no lookup here: Charts, Compat, Glow, IconBrowser, Item, Pool, Toast, and the new Tooltip, Role, Callout and WaypointArrow.

## 3f Kit revision
```
testkit/framework.lua:20:Kit.VERSION = 57   (new)
tests/_kit/framework.lua:20:Kit.VERSION = 53 (old)
```
Kit revision 57 pairs with v1.105.0, and both payloads are copied whole in one commit (the pairing rule). New kit file: `mock_screen.lua`. The kit-57 frame hold turned nothing red here.

## 3g Contract delta and Blockers
Majors that moved a minor and that this addon looks up: Core, Media, Skin, Widgets, DebugLog, Launcher, Options, Perf, Sim. `__Attach*` sites in this addon: none.

**Blocker 1, the drag strip's tooltip fallback (Widgets, WidgetsDragHandle minor 14 / WidgetsDragHandleTip minor 1, LibKa0s#92 part B).** Through v1.94.0 a host `tooltipPlace` hook that answered anything but `true` made the widget re-own GameTooltip at `ANCHOR_CURSOR`. From v1.105.0 it falls back to the library's attached placement below the strip (`Tooltip.PlaceAttached`, and with unreadable geometry a relative `TOP` on the strip's `BOTTOM`, 0, -2), never the cursor (anti-pattern #119). The signature of `tooltipPlace` did not move. Source: `libs/LibKa0s/WidgetsDragHandleTip.lua` header "WHERE IT OPENS" and `dhPlaceAttached` / `dhShowTooltip`. This addon's hook, `NS.Util.PlaceTooltipBeside` (modules/Bar.lua), is unchanged and still wins whenever it places; only the fallback moved. The pin in `tests/test_draghandle.lua` ("falls back to the cursor tooltip": two owners, the second `ANCHOR_CURSOR`, no point) went red and is re-pinned on the new contract: one owner (UIParent, `ANCHOR_NONE`), one point `TOP`/strip/`BOTTOM`/0/-2. The comments in modules/Bar.lua and the descriptions in docs/ARCHITECTURE.md and docs/module-map.md that named the cursor fallback now name the attached one. Fixed in this commit.

**Blocker 2, surface parity (stub members the release added).** `tests/test_surface_parity.lua` compares by name:
- Options instance `SideTabs` (OptionsNav minor 7, v1.100.0): added to the settings/OptionsSetup.lua stub as an inert no-op.
- DebugLog instance `Report` and `Serialize` (DebugLog minor 23, v1.105.0; `docs/api/DebugLog/version-23.11.1.5-docs.md`, "What a host owes at its re-vendor"): added to the core/DebugLogSetup.lua stub as the library's suggested stub (the report streamed to chat with no pointer; a serialize answers one line).
No other stub moved: the Sim stub here is not compared by name for `SAMPLE`/`Sample`, Compat is not looked up, and the loader list is derived from the XML (`tests/test_loadorder.lua`), so the new payload files needed no hand-written line.

## 3h Unrecorded vendored tags
```
v1.94.0
```
One tag vendored without a bundle (fb0963c and 03998d9, the WoW Forever port wave 1). Its records-only span bundle is `../2026-11-16-v1.94.0-v1.94.0/`.

## 3i Icon declaration
- `grep -n 'LibKa0s icons:' CLAUDE.md`: 48:LibKa0s icons: chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.
- Kept as written, the next non-blank line under the provenance line. No `LibKa0s sounds:` line, so sounds is none.
- Prune, `lua <scratch>/tools/prune-icons.lua .`: icons kept 14 of 5840 files (13 declared plus the Open Iconic license), removing 5826 undeclared icon files the whole copy brought back; sounds kept 0, removing all 362 voice-pack files. A second run removed 0.

## 3j Tests that assume the whole icon folder
```
tests/test_mediasetup.lua:121   for _, name in ipairs(lib.ICONS) do known[name] = true end   (a name check, not a file open)
tests/test_mediasetup.lua:153   io.open of each DECLARED name
tests/test_optionssetup.lua:562 io.open("libs/LibKa0s/media/icons/info.tga")   (info is declared)
```
None assumes the whole folder; nothing to fix.

## Dead stub mirrors
`grep -rn '__releaseChrome'` outside libs and the kit: none.
