local addonName, NS = ...

-- core/Bus.lua — the closed cross-module message bus (architecture-§4).
--
-- Modules never reach into each other's tables to trigger work. The event layer
-- (core/AbsorbTracker.lua), the slash surface (settings/Slash.lua), the settings
-- pages (settings/*.lua) and the reset helpers PUBLISH named messages on NS.bus;
-- the display modules SUBSCRIBE, each on its OWN target from NS.NewBusTarget() —
-- never two receivers on one target (anti-pattern #32). CallbackHandler keys
-- callbacks by (message, target), so a second RegisterMessage on a *shared* object
-- would silently overwrite the first; a per-receiver target makes that impossible.
--
-- Message catalogue (also documented in docs/ARCHITECTURE.md → Message Bus). Every
-- message is payload-free: the consumer re-reads live state (settings / absorbs)
-- when it fires, so there is nothing to pass.
--   Ka0s_AbsorbTracker_RepaintRequested   sender: event / slash / lifecycle layer.
--       consumer: modules/Timer.lua — coalesced into one throttled repaint by
--       NS.RequestRepaint (which then paints via NS.UpdateAbsorbBar).
--   Ka0s_AbsorbTracker_AppearanceChanged  sender: settings / lifecycle layer.
--       consumer: modules/Display.lua — NS.UpdateBarAppearance (size / texture /
--       colors / border / font).
--   Ka0s_AbsorbTracker_VisibilityChanged  sender: event / settings layer.
--       consumer: modules/Display.lua — NS.ApplyVisibility (the show/hide gate).
--   Ka0s_AbsorbTracker_PositionChanged    sender: slash / lifecycle / reset layer.
--       consumer: modules/Display.lua — NS.RestoreBarPosition (restore from profile).
--   Ka0s_AbsorbTracker_UnitsChanged       sender: settings / slash / reset layer, whenever a
--       per-unit `enabled` flag changes. consumer: core/AbsorbTracker.lua —
--       addon:SyncUnitEventFrames, which registers absorb/max-health events ONLY for units that
--       are currently enabled, so a disabled unit costs no event dispatch. Distinct from
--       VISIBILITY on purpose: VISIBILITY also fires on combat and target-swap transitions, which
--       must not churn event registrations.
--   Ka0s_AbsorbTracker_PerfStateChanged   sender: core/Perf.lua, on every phase transition of a
--       perf run (started, experiment armed, recording opened/closed, finished). consumer:
--       core/PerfPanel.lua — the step panel re-reads NS.Perf.Progress() and re-renders. Payload-free
--       like the rest: the panel asks for the state rather than being handed it.

local AceEvent = LibStub("AceEvent-3.0")

-- The shared publish target. AceEvent embeds its :SendMessage/:RegisterMessage
-- mixins here; every embedded object funnels through AceEvent's one message
-- registry, so a SendMessage on NS.bus reaches receivers registered on any target.
NS.bus = NS.bus or {}
AceEvent:Embed(NS.bus)

-- A fresh AceEvent-embedded table per receiver, so each subscription is isolated
-- and no two receivers ever share one target (architecture-§4 receiver rule).
function NS.NewBusTarget()
    local t = {}
    AceEvent:Embed(t)
    return t
end

-- Message-name catalogue. Prefixed Ka0s_<Addon>_ to avoid cross-addon collision.
NS.MSG = {
    REPAINT    = "Ka0s_AbsorbTracker_RepaintRequested",
    APPEARANCE = "Ka0s_AbsorbTracker_AppearanceChanged",
    VISIBILITY = "Ka0s_AbsorbTracker_VisibilityChanged",
    POSITION   = "Ka0s_AbsorbTracker_PositionChanged",
    UNITS      = "Ka0s_AbsorbTracker_UnitsChanged",
    PERF       = "Ka0s_AbsorbTracker_PerfStateChanged",
}
