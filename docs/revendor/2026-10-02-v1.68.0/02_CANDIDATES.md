# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.67.0..v1.68.0`, the `CHANGELOG.md` v1.68.0 block (lines
13-60 at the tag), and `docs/api/Widgets/version-12.1.4-docs.md` at the tag. Widgets is the only major
whose minor moved.

## A. Delivered on the copy

- The evaluate/draw split of the drag handle's tooltip (`dhTooltipLines` / `dhDrawTooltip`). A host
  with no hook gets minor 3's calls in minor 3's order (`version-12.1.4-docs.md:44`), so nothing
  changes for this addon's three strips, their help marks or their close marks.

## B. New surfaces (host change required)

| # | Surface | Evidence | Would touch | Blast radius |
|---|---|---|---|---|
| B1 | `spec.tooltipPlace(tip, frame) -> true`, and the descriptor's own `place`, which wins over the spec's (WidgetsDragHandle 4) | CHANGELOG v1.68.0, "WidgetsDragHandle minor 4"; `version-12.1.4-docs.md:20-48`, `:692`, `:725-745`; `libs/LibKa0s/WidgetsDragHandle.lua:636` | `modules/Bar.lua` (`buildHandle`), `tests/test_draghandle.lua`, `docs/smoke-tests.md` BAR-12 | **Replaces** behavior: a spec-level hook takes over all three tooltips (strip, `?`, X), because owner and anchor are not read while a hook is in force (`:692`) |

**Recommendation for B1: decline. The strip already owns its tooltip by the strip.** `modules/Bar.lua:65-113`
sets no `tooltipOwner`, so the strip's tooltip uses the widget's frame owner at `ANCHOR_TOP`
(`libs/LibKa0s/WidgetsDragHandle.lua:285-292`): the tooltip sits on the strip, not at the cursor. The
owner's request (AuraMaster#22, plan `00_PLAN.md` "Why") was to move a cursor-owned tooltip beside
the strip. This host does not have that defect. Full reasoning is in `03_DECISIONS.md`.

## C. Whole-module adoption

None. No major is added, and every major this addon did not consume at v1.67.0 is unchanged.
