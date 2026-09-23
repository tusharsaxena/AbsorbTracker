local addonName, NS = ...

-- core/Bus.lua — the closed cross-module message bus (architecture-§4), and this addon's seam onto
-- LibKa0s-Bus-1.0 (libs/LibKa0s/Bus.lua; contract in LibKa0s docs/api/Bus/version-1-docs.md).
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

-- Resolved once, at file load (library-stack-§4): libs\LibKa0s\LibKa0s.xml loads in the TOC's lib
-- block, long before this file, so the major is either registered by now or absent for good.
local Bus = LibStub and LibStub("LibKa0s-Bus-1.0", true)
if not Bus then
    -- The untracked-target stub (options-ui-§1 names the shape; the Bus API document's "Worked
    -- example" is its text). Receivers still get a private target, so the receiver rule holds, but
    -- nothing is recorded: on an install with LibKa0s missing, a disable leaves the five bus
    -- subscriptions live. docs/ARCHITECTURE.md → Known Limitations states it. It copies nothing of
    -- the library, and it is not this file's old subscription register kept alive as a fallback:
    -- options-ui-§1 does not admit a completing stub for this major.
    Bus = {
        New = function(_, d)
            return {
                name = d and d.name,
                NewTarget = function()
                    local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
                    if not AceEvent then return nil end
                    local t = {}
                    AceEvent:Embed(t)
                    return t
                end,
                StandDown = function() return 0 end,
                StandUp   = function() return 0, {} end,
            }
        end,
        Catalog = function(_, messages) return messages end,
    }
end
-- Suite seam only: tests/test_bus.lua holds this table to the live library's surface by name
-- (Kit.assertSurfaceParity), which it can only do on a degraded load if the stub is reachable.
NS.__busLib = Bus

-- The shared publish target. Host code, not the library's: sending is not a registration, so it
-- carries nothing a stand-down needs to know about. AceEvent embeds its :SendMessage mixin here;
-- every embedded object funnels through AceEvent's one message registry, so a SendMessage on NS.bus
-- reaches receivers registered on any target.
local AceEvent = LibStub("AceEvent-3.0")
NS.bus = NS.bus or {}
AceEvent:Embed(NS.bus)

-- ── the stand-down record ─────────────────────────────────────────────────────────────────────
--
-- A RegisterMessage is a REGISTRATION, and slash-commands-§7 names it beside RegisterEvent: a
-- stood-down addon has unregistered it, not gated the handler behind a flag. The subscribing
-- modules hold their targets as file-locals (modules/Display.lua's `ev`), so the record has to live
-- with the factory that made them. Every target NS.NewBusTarget() hands out is TRACKED: its
-- register and unregister calls are recorded, core/Lifecycle.lua's StandDown takes them all down
-- through NS.BusStandDown, and its StandUp replays the record AS IT IS NOW through NS.BusStandUp.
-- A receiver that unregisters while up is forgotten, and one that registers while down is recorded
-- and not made live until the stand-up (both are the library's; this file's old append-only
-- register did neither).
--
-- `isDown` is a closure because the latch does not exist yet: core/Lifecycle.lua loads after this
-- file. Inside the latch's own standUp callback it already answers false, so the replay proceeds;
-- anywhere else while a hold is taken it answers true and a bare stand-up of the bus is refused.
NS.busRecord = Bus:New{ name = addonName, isDown = function() return NS.IsStoodDown() end }

--- A fresh tracked AceEvent target, one per receiver (architecture-§4's receiver rule).
function NS.NewBusTarget() return NS.busRecord:NewTarget() end

--- Take every tracked registration down. Answers how many entries the record holds, which is what
--- lets a test tell "there was nothing to drop" from "the record was never populated".
function NS.BusStandDown() return NS.busRecord:StandDown() end

--- Replay the record as it is now. Answers how many entries went live. An entry that raised on the
--- replay is dropped from the record by the library and named here, through the debug seam: the
--- stand-up is inside the latch's callback, so the library never raises out of it.
function NS.BusStandUp()
    local replayed, rejected = NS.busRecord:StandUp()
    if #rejected > 0 and NS.Debug then
        NS.Debug("Bus", "rejected on stand-up: %s", table.concat(rejected, ", "))
    end
    return replayed
end

-- Message-name catalog. Prefixed Ka0s_<Addon>_ to avoid cross-addon collision, and declared through
-- Catalog, which validates the names at load and answers a STRICT copy: reading a key that is not
-- declared raises at the call site, for a publisher as well as a subscriber (a bare SendMessage(nil)
-- is silent in CallbackHandler, so without this a mistyped constant failed only on the receiving
-- side).
NS.MSG = Bus.Catalog(addonName, {
    REPAINT    = "Ka0s_AbsorbTracker_RepaintRequested",
    APPEARANCE = "Ka0s_AbsorbTracker_AppearanceChanged",
    VISIBILITY = "Ka0s_AbsorbTracker_VisibilityChanged",
    POSITION   = "Ka0s_AbsorbTracker_PositionChanged",
    UNITS      = "Ka0s_AbsorbTracker_UnitsChanged",
})
