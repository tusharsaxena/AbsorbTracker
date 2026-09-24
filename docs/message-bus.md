# Message bus

How the closed cross-module bus (`core/Bus.lua`, architecture-§4) is built, what stands it down, and
what deliberately does not ride it. The catalog itself (the five messages, each one's sender,
consumer and effect) and the one-target-per-receiver rule stay in
[ARCHITECTURE.md → Message Bus](./ARCHITECTURE.md#message-bus); this page is that section's
documentation-§3 spill target. The Tier 2 trigger (more than ten messages) has not fired: there are
five. The page exists because the hub's ~60-line rule names it as the place the section spills to.

## The `LibKa0s-Bus-1.0` seam

**The seam names `LibKa0s-Bus-1.0`** (adopted at the LibKa0s v1.55.0 re-vendor; contract in
LibKa0s `docs/api/Bus/version-1-docs.md`). The publisher stays host code: sending is not a
registration. Every target `NS.NewBusTarget()` hands out is a **tracked** target from the
library's record (`NS.busRecord = Bus:New{ name, isDown }`, `isDown` asking `NS.IsStoodDown()`
through a closure because the latch loads after the bus), so the latch's `StandDown` /
`StandUp` reach every receiver's registrations through `NS.BusStandDown()` / `NS.BusStandUp()`
and no receiver has to ask the latch for its subscription to come down. One asks anyway: the
`UNITS` receiver in `core/AbsorbTracker.lua` returns while `NS.IsStoodDown()`, because with
LibKa0s absent the stub records nothing and its work is a registration (see
[ARCHITECTURE.md → Known Limitations](./ARCHITECTURE.md#known-limitations)). A registration made
while stood down is recorded and goes live at the stand-up; an unregister while up is forgotten, so
a stand-up never resurrects it. The latch itself is described in [lifecycle.md](./lifecycle.md).

`NS.MSG` is declared once through `Bus.Catalog`, which validates each `Ka0s_AbsorbTracker_<Event>`
name at load and answers a strict copy: reading an undeclared key raises at the call site, for a
publisher as well as a subscriber. With LibKa0s absent, `core/Bus.lua` falls back to the
untracked-target stub `options-ui-§1` names (see
[ARCHITECTURE.md → Known Limitations](./ARCHITECTURE.md#known-limitations)).

## Fan-out, and why the messages carry no payload

Each Display handler fans out over `NS.ForEachUnit`, repainting/re-appearancing/re-positioning all
three bars per message — this is what keeps the bus messages payload-free (no "which unit" to
carry).

Each message has exactly one sender concept and one consuming module. The display functions
(`NS.UpdateBarAppearance` / `NS.ApplyVisibility` / `NS.RestoreBarPosition` / `NS.UpdateAbsorbBar`)
and `NS.RequestRepaint` remain defined on `NS` — they are the consumer-side implementations the bus
handlers call, and stay directly unit-testable. Within the display concern, `Timer`'s coalescer
calls `NS.UpdateAbsorbBar` directly (intra-concern), as does `NS.UpdateBarAppearance` calling
`NS.ApplyVisibility`; the debug-counter hook `NS.NoteRepaint` (`modules/Timer.lua`'s pass → `core/AbsorbTracker.lua`
combat rollup) is likewise a direct intra-implementation call, not a bus notification. The bus mock
in `tests/wow_mock.lua` models real `(message, target)` dispatch so `tests/test_bus.lua` asserts
two receivers of one message both fire (anti-pattern #33).

## What is not on the bus

The perf run panel is **not** on this bus. `LibKa0s-Perf-1.0` repaints its own panel directly off the
instance's state (`RefreshPanel`, called at the end of every phase transition inside the lib) rather
than publishing a message this addon's bus would have to carry — the panel and the state it renders
both live inside the vendored library. See [performance.md](./performance.md).

Other cross-cutting refresh stays as explicit calls: `Helpers.RefreshAllPanels` (after `/at set` or
a profile change) is the STRUCTURAL tier: every settings page declares its body through
`Helpers.SetRenderer`, so a page on screen re-renders and a hidden one is flagged dirty for its
next `OnShow`. A panel widget's own write takes `Helpers.RefreshScalars` instead, which walks
`ctx.refreshers` in place. Both implementations are the library's.

## The other callback bus: AceDB

`NS:InitDB` registers one handler per event: `NS.OnProfileChanged`, `NS.OnProfileCopied` and
`NS.OnProfileReset` (`core/AbsorbTracker.lua`). All three share one body: they lift the profile,
republish `UNITS` / `POSITION` / `APPEARANCE` / `REPAINT` on the bus and refresh an open panel.
They differ only in their one debug line, worded by the event (debug-logging-§10):
`[Profile] changed → <name>` for a switch, `[Set] copied profile '<source>' → '<name>'` for a copy,
and `[Set] reset profile '<name>' to defaults (N rows)` for a reset. For a reset, N is the rows
the reset changed, never the schema size: every reset the addon drives goes through
`NS.ResetProfileCounted` (`settings/Schema.lua`), which counts the rows off their default just
before `db:ResetProfile()` and leaves the number for the handler to take once
(`NS.ConsumeResetCount`). The number is cleared when the reset returns or raises, so it cannot
leak into a later reset. A reset the addon did not drive (AceDBOptions' button, a `/run`) has no
count, and its line omits `(N rows)`. That reset line is the only line Reset All logs.
