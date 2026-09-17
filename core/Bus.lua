local _, NS = ...

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
-- Message catalog (also documented in docs/ARCHITECTURE.md → Message Bus). Every
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

-- ── the subscription register, and why the bus owns it ────────────────────────────────────────
--
-- A RegisterMessage is a REGISTRATION, and slash-commands-§7 names it beside RegisterEvent: a
-- stood-down addon has unregistered it, not gated the handler behind a flag. But the subscribing
-- modules hold their targets as file-locals (modules/Display.lua's `ev`), so nothing outside them
-- could reach a subscription to take it down.
--
-- So subscribing goes through here, and the bus remembers the triple. core/Lifecycle.lua's
-- StandDown calls NS.BusUnsubscribeAll and its StandUp calls NS.BusResubscribeAll, and neither
-- module learns that the latch exists. The alternative — a suspend/resume pair exported from each
-- subscribing module — is three copies of one rule and a fourth module that forgets it.
--
-- The register is APPEND-ONLY and keyed by nothing: a module subscribes once, at file load, and the
-- same triple is re-registered on the way back up. CallbackHandler keys by (message, target), so a
-- re-register over a live subscription would be a silent overwrite rather than a second callback —
-- which is what makes the resubscribe safe to run when some subscriptions are already in place.
local subscriptions = {}

--- Subscribe `target` to `message`, and record it so the latch can take it down.
function NS.BusSubscribe(target, message, fn)
    subscriptions[#subscriptions + 1] = { target = target, message = message, fn = fn }
    target:RegisterMessage(message, fn)
    return target
end

--- Drop every recorded subscription. Answers how many it dropped, which is what lets a test tell
--- "there was nothing to drop" from "the register was never populated".
function NS.BusUnsubscribeAll()
    for _, s in ipairs(subscriptions) do s.target:UnregisterMessage(s.message) end
    return #subscriptions
end

--- Put every recorded subscription back, with the callback it was registered with.
function NS.BusResubscribeAll()
    for _, s in ipairs(subscriptions) do s.target:RegisterMessage(s.message, s.fn) end
    return #subscriptions
end

-- Message-name catalog. Prefixed Ka0s_<Addon>_ to avoid cross-addon collision.
NS.MSG = {
    REPAINT    = "Ka0s_AbsorbTracker_RepaintRequested",
    APPEARANCE = "Ka0s_AbsorbTracker_AppearanceChanged",
    VISIBILITY = "Ka0s_AbsorbTracker_VisibilityChanged",
    POSITION   = "Ka0s_AbsorbTracker_PositionChanged",
    UNITS      = "Ka0s_AbsorbTracker_UnitsChanged",
}
