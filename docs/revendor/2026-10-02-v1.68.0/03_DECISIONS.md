# 03 — Decisions

No interview was held. The owner delegated every decision for this run (plan
`Ka0sAddonsCommonTasks/docs/2026-10-02-LIBKA0S_TOOLTIP_PLACE/00_PLAN.md`, item TP-AT-01), so the call
below was made in-run, and its reasoning is recorded here and in the re-vendor commit body.

## B1 — `tooltipPlace` (WidgetsDragHandle 4): **declined, not filed**

The owner wants the drag-strip tooltip beside the strip instead of at the cursor: to the right, or
to the left when the strip's right edge plus the tooltip's width would leave the screen. The
question for this host is whether beside-the-strip is a better match for that request than what it
already does. It is not:

1. **The tooltip is not at the cursor here.** `modules/Bar.lua:65-113` passes no `tooltipOwner` and
   no `owner`, so every hover takes the widget's frame-owner path
   (`libs/LibKa0s/WidgetsDragHandle.lua:285-292`). The strip's tooltip is owned by the strip at
   `ANCHOR_TOP`, and the `?` and X tooltips are owned by their marks at `ANCHOR_TOPRIGHT`. The defect
   the owner reported is a tooltip detached from the strip and following the pointer. That happens
   in AuraMaster, where a restricted anchor forces the cursor owner (`version-12.1.4-docs.md:26-31`),
   and it does not happen here.
2. **The flip solves an edge case this host already avoids.** A frame-owned `GameTooltip` is clamped
   to the screen by the client, so `ANCHOR_TOP` over a strip near the right edge stays on screen
   without host geometry code. The left/right choice in the owner's request exists because a
   UIParent-owned, host-placed tooltip has no such anchor.
3. **Adopting replaces more than it adds.** A spec-level hook takes over all three tooltips, because
   owner and anchor are not read while a hook is in force (`version-12.1.4-docs.md:692`). That would
   move the `?` and X tooltips the owner did not ask about. A descriptor-level `place` on the strip
   alone would leave the strip placed by the host and the marks placed by their own frames, which
   is two placement styles on one strip. Either way the host gains rect reads that need guarding,
   plus a fallback path, to reproduce an attachment it already has.
4. **The plan's rule for this case.** `00_PLAN.md`, Scope: where the strip tooltip is already owned
   by the strip, adoption is not necessary, and the commit body records that.

One cost is recorded for completeness. `ANCHOR_TOP` puts the strip's tooltip above the strip, so with
the three bars stacked tightly it can briefly cover the bar above. That happens only while the bars
are unlocked and the pointer is on a strip, which is the moment the player is about to drag. It is
not the problem the owner raised.

**Not filed as a GitHub issue.** This is a decision that the feature is unnecessary here, and it is
not a real gap in the addon or the library. The run instructions file a decline only for a real gap.
If the owner later wants every strip in the collection to place its tooltip the same way, the
re-check trigger is a request that names AbsorbTracker's strip. The adoption would then be a
`place` on all three descriptors in `buildHandle`.

## B1 reversed — `tooltipPlace` **adopted** (TP-AT-02, 2026-10-03)

The decline above is reversed by the owner. Told that this strip already opens its tooltips above
the strip rather than at the cursor, the owner answered: "Yes, have consistency across all ka0s
addons". The re-check trigger named above, a request that covers AbsorbTracker's strip, is met.

What was adopted, in `modules/Bar.lua`:

- A spec-level `tooltipPlace = NS.Util.PlaceTooltipBeside` in `buildHandle`, so the hook covers all
  three tooltips: the strip's, the `?`'s and the X's. Point 3 above counted the marks being moved as a
  cost. Under a one-placement-for-every-strip rule it is the point, because a strip whose marks open
  somewhere else is the inconsistency the owner ruled out.
- `NS.Util.PlaceTooltipBeside` mirrors KickCD's (`core/Util.lua`, TP-KC-01) line for line, so the
  behavior is identical across addons. The tooltip's `TOPLEFT` goes 4 px right of the strip's
  `TOPRIGHT`. When the strip's right edge plus the tooltip's width would pass the screen's right
  edge, its `TOPRIGHT` goes 4 px left of the strip's `TOPLEFT` instead. A hovered `?` or X resolves to
  its strip. Every read is in screen pixels, each times its frame's effective scale, which matters
  here because a bar carries its own scale times the master scale.
- One difference from KickCD, and it is only in the guard's spelling. KickCD asks
  `NS.Compat.IsSecret`. This addon has no Compat module, and the one question it asks of a value
  that may be secret is `NS.IsConcatSafe` (LibKa0s-Core, or the degraded stub's probe), so the
  placement asks that. A missing, nil, secret or non-number read answers nil with nothing anchored,
  and the widget falls back to the cursor. The function returns true only once the tooltip is placed.
- The two descriptor `anchor = "ANCHOR_TOPRIGHT"` fields (help and close) are removed. While a hook
  is in force the widget reads no owner or anchor, so they had become dead configuration.

Point 2's clamp argument does not carry over. The host now measures the screen edge itself, which is
what the left flip is for.

Tests (written first, all nine red before the code) are in `tests/test_draghandle.lua`: six
placement cases (right, left flip, the `?` and the X resolving to the strip, a scaled strip, a
secret read, a nil read) and three hover cases (every strip and both its marks owned once by
UIParent at `ANCHOR_NONE` and anchored beside the strip, the left flip, and the cursor fallback).
In-game check: `docs/smoke-tests.md` BAR-17, owner-run, unmarked.
