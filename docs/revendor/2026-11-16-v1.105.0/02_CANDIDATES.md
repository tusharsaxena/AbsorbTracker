# 02 Candidates, LibKa0s v1.94.0 -> v1.105.0

Sources: `git -C ../LibKa0s log --oneline v1.94.0..v1.105.0`; LibKa0s CHANGELOG.md, the v1.95.0 to v1.105.0 blocks; the run bundle's `03_ADOPTION_PLAN.md` and research note R7 (AbsorbTracker rows).

**Class A, delivered on the copy alone**
- The drag strip's tooltip never opens at the cursor (WidgetsDragHandleTip minor 1, LibKa0s#92 part B). The addon's own beside-the-strip hook still places it; only the fallback moved (01_DELTA.md, blocker 1).
- The debug console: plain-text Copy, the 24 px Widgets footer, the title-bar marks on `HeaderButtons` (DebugLog minor 23, Window minor 5; LibKa0s#79, #90, #86).
- The skin picker queue, OptionsWidgets 46 (the slider fix), Media 13 fonts, SkinDefs 28 / SkinDefsOthers 10, Launcher 11, PerfPanel 14, SimPanel 11 / SimPanelRender 4 (the tooltips placed by the Tooltip major).
- Kit revision 57 (`mock_screen.lua`, the frame hold).

**Class B, host change required (owed in phase [3], planned only; not offered here)**
- **#92, tooltip placement.** The strip's tooltips still go through this addon's `tooltipPlace` hook (`NS.Util.PlaceTooltipBeside`, modules/Bar.lua), which places them beside the strip. v2.112.0 of the standard reads a HUD strip as top chrome, attached below by `Tooltip.PlaceAttached`. Candidate: retire the hook and take the library's placement. No own `SetOwner` site (R7).
- **#88, docked test/sim strip.** Bars shown by `/at sim` carry no HUD strip; candidate: `dock = "hud"` per visible bar (03_ADOPTION_PLAN.md, AbsorbTracker named).
- **#86, header buttons.** No addon-owned window; the drag-handle settings mark per addon is the one candidate.
- **#79, reports.** `/at profile list` (settings/Slash.lua:506) and any other multi-line read-out are candidates for `D:Report`; `/at list` stays in chat (the reserved list verb). Confirm each verb against its handler.
- **#87, `Sim.Sample(client)`.** Only if the sim draws sample names; modules/Sim.lua shows none today, so likely not applicable.

**Not applicable here:** #85 (Callout consumers), #89 (no hand-built footer), #80, #81 (Skill Master only).

**Class C, whole-module**: Tooltip (through #92), Role, Callout, WaypointArrow, not looked up. No recorded decline to carry.

**Blockers (3g)**: two, both fixed in the re-vendor commit (01_DELTA.md).
