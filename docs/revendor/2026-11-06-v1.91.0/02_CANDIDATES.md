# Candidates, LibKa0s v1.90.0 -> v1.91.0

Sources: `git -C ../LibKa0s log --oneline v1.90.0..v1.91.0`, the tag's `CHANGELOG.md` block v1.91.0,
and the `docs/api/` documents of every major whose minor moved (Core 16 -> 17.1, Widgets
25.6.13.7.6.8.5 -> 26.1.6.13.7.8.5, Skin 17.1.27.8.19.18.17.4.9 -> 17.1.27.8.19.19.1.1.17.4.9). No
contract blocker (01_DELTA 3g).

## Class A: delivered on the copy

- **The line chart's lines in physical pixels** (CHANGELOG v1.91.0, *The line chart's lines in
  physical pixels (`FU-L1`)*; WidgetsLineChart minor 7; `docs/api/Widgets/version-26.1.6.13.7.8.5-docs.md:33`,
  "What a host owes: nothing"). AbsorbTracker draws no line chart (`grep -rn LineChart core modules
  settings` finds nothing), so this reaches it only as payload bytes.
- **The band-file peels** (CHANGELOG v1.91.0, *The band files peeled (`FU-L2`)*): Core 17 + CorePixel 1,
  Widgets 26 + WidgetsDropdown 1, SkinPaintExtras 19 + SkinPaintHud 1 + SkinAceConfirm 1. Pure moves with
  no member, option or behavior change. `S.BarGloss` and `S.HudFont`, which this addon uses, now live in
  `SkinPaintHud.lua` and load through the vendored `LibKa0s.xml` with no host change.

## Class B: host change required

None. The range adds no public surface, descriptor field or row type.

## Class C: whole-module adoption

None. No major is new in this range.
