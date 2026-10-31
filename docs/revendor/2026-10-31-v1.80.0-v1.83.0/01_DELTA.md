Delta: LibKa0s v1.77.0 -> v1.83.0 (span: v1.80.0 v1.81.0 v1.82.0 v1.83.0)

# 01 — Delta (span, AbsorbTracker)

Written 2026-10-31 by FX-AT-DOCS, after the fact, because four tags this addon vendored have no bundle
of their own. The last bundle is `docs/revendor/2026-10-24-v1.77.0/`. v1.78.0 and v1.79.0 were never
vendored here: the skinning rollout went straight to v1.80.0.

The carrying commits (`git log --format='%h %ad %s' --date=short edfd27e..HEAD -- libs/LibKa0s tests/_kit`):

```
07be68f 2026-10-29 AT-RV: Re-vendor LibKa0s v1.80.0 from the local tag
48de9d4 2026-10-30 AT-RV: Re-vendor LibKa0s v1.81.0 from the local tag
2456312 2026-10-30 AT-01: Re-vendor LibKa0s v1.82.0 from the local tag
c7a142c 2026-10-31 AT-F01: Re-vendor LibKa0s v1.83.0 and take its outline default, faces and README rule
78b5c6a 2026-10-31 AT-RV2: Take the re-cut LibKa0s v1.83.0 (LK-A1, LK-A2)
c873518 2026-10-31 AT-RV3: Take the re-cut LibKa0s v1.83.0 (LK-A3, the skin picker's rows)
```

`edfd27e` is the last v1.77.0 re-vendor. Across the span, `libs/LibKa0s/` and `tests/_kit/` change 100
paths, media included (+16652/-972). Lua and doc paths alone: 16 added, 28 modified, none deleted. The
kit moves from revision 42 to 46.

## Per-file minors

Read from `MINOR` in each file at `edfd27e` and at the head of this span.

| File | v1.77.0 | v1.83.0 |
|---|---|---|
| `Core.lua` | 12 | 14 |
| `DebugLog.lua` | 21 | 22 |
| `DebugLogDiagnostics.lua` | 3 | 5 |
| `DebugLogWindow.lua` | new | 2 |
| `Media.lua` | 5 | 11 |
| `Options.lua` | 30 | 34 |
| `OptionsAppearance.lua` | new | 5 |
| `OptionsCombat.lua` | 2 | 3 |
| `OptionsCompose.lua` | 11 | 14 |
| `OptionsDrawer.lua` | 1 | 3 |
| `OptionsIdList.lua` | 5 | 7 |
| `OptionsIds.lua` | 3 | 5 |
| `OptionsKeybinds.lua` | 4 | 6 |
| `OptionsMedia.lua` | new | 1 |
| `OptionsNav.lua` | 2 | 4 |
| `OptionsRegistry.lua` | 2 | 4 |
| `OptionsScroll.lua` | 4 | 9 |
| `OptionsSkinPicker.lua` | new | 4 |
| `OptionsSwitch.lua` | new | 1 |
| `OptionsTabs.lua` | 9 | 11 |
| `OptionsWidgets.lua` | 34 | 38 |
| `PerfPanel.lua` | 9 | 11 |
| `SimPanel.lua` | 6 | 8 |
| `Skin.lua` | new | 10 |
| `SkinAce.lua` | new | 5 |
| `SkinDefs.lua` | new | 18 |
| `SkinEUI.lua` | new | 2 |
| `SkinPaint.lua` | new | 13 |
| `SkinPaintControls.lua` | new | 11 |
| `SkinPaintExtras.lua` | new | 7 |
| `Toast.lua` | new | 1 |
| `Widgets.lua` | 15 | 17 |
| `WidgetsAutocomplete.lua` | 3 | 5 |
| `WidgetsCopyWindow.lua` | new | 2 |
| `WidgetsDragHandle.lua` | 5 | 8 |
| `WidgetsLineChart.lua` | 3 | 5 |
| `WidgetsReorder.lua` | 1 | 3 |

A file whose minor did not move is left out.
