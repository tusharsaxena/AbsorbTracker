# Refresh 3 of v1.85.0

The tag is still local-only and was re-cut for the owner's rulings of 2026-11-01 and the gate (`FS-FIX`, `FS-GATE`), so this is a third refresh and not a new re-vendor. It lands in `FS-AT-GATE`.

- **Old:** `9776130`. `libs/LibKa0s/` and `tests/_kit/` matched it before this copy.
- **New:** `2ad1a5080112cc1323fe79f7e134b00768a7ebca`.
- **Kit:** revision 49 -> 50. `test_skin_values` and `test_skin_switch` are declared by the pair and adopted.

**Copy:** both folders removed and copied from `git archive v1.85.0`, so a file the tag dropped goes too; both `diff -r` empty before the prune. **Prune:** 12 icons declared, kept 13 files, the declaration unchanged.

**Blockers, fixed in this commit:**

- The degraded Skin facade gains `BarBorder`, which answers its three, and `HoverArt`. `HudFont` takes the documented stub, so `"@skin"` never reaches `SetFont`. The Widgets stub gains `ContextMenu`.
- A bar family `disabledIf` is a function: `tests/test_schema.lua`, `tests/test_skin_hud.lua` and `tests/test_skin_flip.lua` move.
- A skin's None defers, so the shipped `Blizzard Tooltip` would have drawn on every Ka0s Default bar. `border` ships `None` with the v9 step, which leaves a real pick alone. `borderSize` stays 12, the size a real pick draws at, and a following bar with no edge reads the skin's size, so the inset does not move.

**Not owed:** a numeric path. `Skin.FollowOnce` takes `units.<unit>.<key>`, with string units, so no repair step. No `S.Mark` or `S.HoverArt` call in this addon, so nothing to untrack on release. No Show border row, so `NS.GetBorder` stays on `S.Resolve`, which defers the same way. No `spec.extra` stamper.

**Gate:** see the `FS-AT-REC` bundle.
