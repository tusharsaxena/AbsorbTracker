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
