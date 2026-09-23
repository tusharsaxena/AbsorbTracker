local addonName, NS = ...

-- core/Lifecycle.lua — the ONE latch this addon stands down on (slash-commands-§7).
--
-- ---------------------------------------------------------------------------
-- TWO REASONS TO BE INERT, ONE MECHANISM
-- ---------------------------------------------------------------------------
--
-- The addon has exactly two reasons to stop running, and they are independent:
--
--   `perf`      LibKa0s-Perf-1.0 takes it for Experiment B, the suspended arm of a capture. The
--               probe takes and releases it itself; nothing in this addon ever spells it.
--   `disabled`  the stored `enabled` path — the Master-controls checkbox, `/at enable`,
--               `/at disable`, `/at set enabled`, a Defaults click, and a profile switch that
--               carries a different answer.
--
-- They are HOLDS ON ONE LATCH rather than two booleans, because two booleans have a state nobody
-- designed: the player disables the addon halfway through a capture, the run finishes, and a
-- `resume` that wrote `suspended = false` would bring the addon back to life under a player who
-- switched it off. With a hold set, releasing `perf` leaves `disabled` taken, the set is still
-- non-empty, and nothing is rebuilt. The library has no `:StandUp()` member at all, and the absence
-- is the feature.
--
-- THE SECOND TEARDOWN PATH IS THE ANTI-PATTERN (#85), not an implementation detail. This file's
-- StandDown IS the body core/PerfSetup.lua's `suspend` used to carry, moved here and finished;
-- PerfSetup now hands the latch over and supplies no teardown of its own. One mechanism, so
-- "inert" cannot come to mean two different things.
--
-- ---------------------------------------------------------------------------
-- WHAT STANDING DOWN ACTUALLY MEANS HERE
-- ---------------------------------------------------------------------------
--
-- Not hidden, not quiet, not skipping a repaint. A handler that early-returns did not stop
-- watching — it stopped reacting, and the client still walks the registration list on every
-- UNIT_ABSORB_AMOUNT_CHANGED, still builds the argument frame, still enters Lua. So every
-- registration this addon owns is actually UNREGISTERED:
--
--   * the three per-unit RegisterUnitEvent frames (core/AbsorbTracker.lua)
--   * the five AceEvent registrations on the addon object — the three lifecycle events and the
--     two swap events
--   * every RegisterMessage on the internal bus (the LibKa0s-Bus-1.0 record core/Bus.lua keeps)
--
-- and every timer is canceled: the coalescing repaint (modules/Timer.lua) and the `/at test`
-- preview hold (modules/Display.lua). The bars go down through the SHOW LADDER rather than by an
-- imperative Hide — NS.ShouldShowBar already answers no on both rungs — because a hidden frame
-- comes back on a combat transition, a target swap or a settings change, and then the addon is
-- visibly running while it claims to be off.
--
-- NO SECURE WORK IS HELD PENDING, and that is a statement about this addon rather than an omission.
-- slash-commands-§7 requires UnregisterStateDriver / UnregisterAttributeDriver / a secure-attribute
-- rewrite to wait for PLAYER_REGEN_ENABLED; this addon owns no secure frame, no state driver and no
-- attribute driver (the bars are plain `CreateFrame("Frame", …, "BackdropTemplate")`), so the whole
-- stand-down is combat-safe and completes in the same turn as the write, which is what §7 asks for.
-- The day a secure element arrives here, it holds its half pending and this note is what says so.
--
-- WHAT SURVIVES is setup, not features (§7): the chat command and the dispatcher, NS.COMMANDS, the
-- settings-category registration and the panel body, the AceDB handle and its three profile
-- callbacks, and the launcher's registration. A disabled addon is inert; its command surface is not
-- the addon.

local lib = LibStub and LibStub("LibKa0s-Lifecycle-1.0", true)

-- The five AceEvent registrations core/AbsorbTracker.lua makes on the addon object. Named once,
-- here, so the teardown cannot fall short of the build-up: RegisterLifecycleEvents owns the first
-- three and SyncUnitEventFrames owns the last two, and a sixth added there without a line here
-- would be the survivor the whole section exists to catch. tests/test_disabled.lua compares the
-- sets rather than trusting this list.
local ADDON_EVENTS = {
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
}

--- Make the addon inert, without a /reload and in the same turn as the write.
---
--- ORDER IS LOAD-BEARING. The bars are taken down by publishing VISIBILITY, and the bus
--- subscriptions are torn down AFTER that — publishing onto a bus nobody is listening to would
--- leave three bars on screen over an addon that had stopped watching, which is the exact half-down
--- state the single mechanism exists to prevent.
local function StandDown()
    -- Nothing armed may survive: a repaint queued a moment ago would land inside the stand-down,
    -- and the preview hold's one-shot would repaint a fake value onto a bar that is meant to be
    -- gone.
    if NS.CancelPendingRepaint then NS.CancelPendingRepaint() end
    if NS.ClearPreview then NS.ClearPreview() end

    -- At the SOURCE, never imperatively. NS.ShouldShowBar's rung 0 asks NS.IsStoodDown, and the
    -- latch flips `down` BEFORE it calls this, so the ladder already says no and one pass takes all
    -- three bars down for good.
    if NS.bus then NS.bus:SendMessage(NS.MSG.VISIBILITY) end

    local addon = NS.addon
    if addon then
        local frames = addon.__unitEventFrames
        if frames then
            for _, f in pairs(frames) do f:UnregisterAllEvents() end
        end
        if addon.UnregisterEvent then
            for _, event in ipairs(ADDON_EVENTS) do addon:UnregisterEvent(event) end
        end
    end

    -- The internal bus is a registration set like any other (§7 names RegisterMessage by name), so
    -- it goes too. core/Bus.lua keeps the record (LibKa0s-Bus-1.0); the subscribing modules never
    -- learn about this.
    if NS.BusStandDown then NS.BusStandDown() end
end

--- Rebuild everything StandDown took away, FROM CURRENT STATE and never from a snapshot taken on
--- the way down: a unit toggled, a texture changed or a position reset while the addon was off has
--- to come back as it is NOW (performance-§6).
local function StandUp()
    -- The bus first, so the three publishes at the bottom reach the receivers they exist for.
    if NS.BusStandUp then NS.BusStandUp() end

    local addon = NS.addon
    if addon then
        if addon.RegisterLifecycleEvents then addon:RegisterLifecycleEvents() end
        -- Reads the enabled set as it stands, which is what makes this a rebuild rather than a
        -- restore: the two swap events and the three per-unit frames follow the current profile.
        if addon.SyncUnitEventFrames then addon:SyncUnitEventFrames() end
    end

    if NS.bus then
        -- POSITION first, and it is not in StandDown's mirror image for a reason: a bar that stood
        -- down at LOGIN never had its stored anchor applied (core/AbsorbTracker.lua's OnEnable
        -- skips the position publish while the latch is down), so standing up has to place the
        -- bars before it shows them or a re-enable drops all three back at the default anchor.
        NS.bus:SendMessage(NS.MSG.POSITION)
        NS.bus:SendMessage(NS.MSG.VISIBILITY)
        NS.bus:SendMessage(NS.MSG.APPEARANCE)
        NS.bus:SendMessage(NS.MSG.REPAINT)
    end
end

-- Published so core/PerfSetup.lua's degraded stub and tests/test_disabled.lua can name the same two
-- functions the latch calls, rather than a second copy of them.
NS.StandDown, NS.StandUp = StandDown, StandUp

if not lib then
    -- A missing vendored lib must degrade, not error at load — and here it must degrade into
    -- something that still WORKS, because the alternative is a draw gate: an install with no
    -- LibKa0s would keep every registration live on an addon the player switched off. This is the
    -- hold set and nothing else. It is not a second copy of the library (no edge bookkeeping beyond
    -- empty/non-empty, no PrintHolds formatting, no diagnostics), and there is nothing else in the
    -- major to copy: the library IS a hold set, which is what makes it the one stub in this addon
    -- that can honestly answer instead of reporting itself missing.
    local held, down = {}, false
    local function reevaluate()
        local any = next(held) ~= nil
        if any == down then return false end
        down = any
        if any then StandDown() else StandUp() end
        return true
    end
    NS.lifecycle = {
        name       = addonName,
        Hold       = function(_, key) held[key] = true;  return reevaluate() end,
        Release    = function(_, key) held[key] = nil;   return reevaluate() end,
        Set        = function(self, key, on)
            if on then return self:Hold(key) end
            return self:Release(key)
        end,
        IsHeld     = function(_, key) return held[key] == true end,
        IsDown     = function() return down end,
        Holds      = function()
            local out = {}
            for k in pairs(held) do out[#out + 1] = k end
            table.sort(out)
            return out
        end,
        Reevaluate = function() return reevaluate() end,
        PrintHolds = function(self)
            NS.Print(("%s: %s"):format(addonName,
                #self:Holds() > 0 and table.concat(self:Holds(), ", ") or "no holds"))
            return true
        end,
    }
else
    NS.lifecycle = lib:New({
        -- THE FOLDER NAME. Diagnostic output only — nothing in the major branches on it.
        name      = addonName,
        standDown = StandDown,
        standUp   = StandUp,
        print     = function(line) NS.Print(line) end,
    })
end

-- The exported key rather than the string. Every call site typing `"disabled"` for itself is a
-- chance to type `"Disabled"`, and a hold taken under a name nothing releases never comes back.
-- The degraded arm above answers to the same spelling, which is why the fallback is the literal the
-- library exports rather than one this file invented.
NS.HOLD_DISABLED = lib and lib.HOLD_DISABLED or "disabled"

--- Is the addon stood down right now, for any reason? The one question the show ladder
--- (modules/Display.lua rung 0) and the repaint scheduler (modules/Timer.lua) ask. Never a boolean
--- of this file's own: the latch is the single answer and this reads through to it.
function NS.IsStoodDown()
    return NS.lifecycle:IsDown()
end

--- Re-take or release the `disabled` hold from the STORED enable path. One line, called from every
--- surface that can change the answer — the schema row's onChange, the two verbs, the profile
--- callbacks, and OnEnable before any feature registration is made (core/AbsorbTracker.lua) — so
--- no surface holds a second definition of what disabled means.
---
--- Reads the setting rather than taking an argument, because `enabled` has no state of its own
--- (slash-commands-§2): the store is the single answer and this is a read of it.
function NS.SyncEnabledHold()
    NS.lifecycle:Set(NS.HOLD_DISABLED, NS.GetSetting("enabled") == false)
end
