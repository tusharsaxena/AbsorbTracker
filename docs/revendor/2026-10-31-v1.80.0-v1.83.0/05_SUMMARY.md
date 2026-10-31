# 05 — Summary: LibKa0s v1.77.0 -> v1.83.0

Recorded 2026-10-31 by FX-AT-DOCS. This is a span record written afterwards, so it holds what the
carrying commits and the tree show. The candidate interview a re-vendor run does was not repeated.

## The move

The vendored LibKa0s moved from **v1.77.0** to **v1.83.0**, through v1.80.0, v1.81.0, v1.82.0 and three
cuts of v1.83.0. `libs/LibKa0s/` went from 41 to 55 Lua files. New majors: `LibKa0s-Skin-1.0` and
`LibKa0s-Toast-1.0`. The kit moved from revision 42 to 46.

## What the addon took

- v1.80.0: the skin seam (`core/SkinSetup.lua`), the Skin tab, the first-run picker and the bars
  following the skin.
- v1.81.0: the picker's title and `frame.ownerLabel`.
- v1.82.0: the Font outline, `/at skin`, From skin flags and the HUD size scale.
- v1.83.0: the `hud` outline default, the media pickers' previews and the picker's rows.

## What a consumer owed, met

- The Options degradation stub gained `AppearanceTab`, `AppearanceRows`, `SkinPicker`,
  `HideSkinPicker` and `SkinVerb`.
- The degraded Skin facade gained `FontFlags` and `HudFontSize`.

The carrying commits hold the detail. The owner's smoke pass for the span is in
`docs/smoke-tests.md`.
