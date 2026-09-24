local _, NS = ...
NS.Util = NS.Util or {}
local Util = NS.Util

-- core/CoreSetup.lua — wires the addon into LibKa0s-Core (issue #17).
--
-- The secret guard, the concat-safe stringifier and the prefixed chat printer used to live here as
-- core/Util.lua. They are identical in every Ka0s addon and wrong in slightly different ways in
-- several of them, so they now live in libs/LibKa0s/Core.lua and this file is only the part that is
-- ours: which tag the lines carry, and what happens when the library is not there.
--
-- Sits in core/Util.lua's old TOC slot for two reasons that both matter: core/Namespace.lua defines
-- NS.PREFIX just above it, and everything below it — core/Lifecycle.lua, then core/PerfSetup.lua
-- (the TOC order is CoreSetup -> Lifecycle -> PerfSetup) — either calls NS.Print or takes it as a
-- load-time upvalue.

-- The one cause clause, shared by every seam that has to explain the same absence: this file,
-- core/DebugLogSetup.lua, core/PerfSetup.lua, settings/OptionsSetup.lua and settings/Slash.lua.
-- Each appends its own "so <what> is unavailable" and its own terminal punctuation, so a degraded
-- install says the same thing about WHY five times and a different thing about WHAT each time.
-- Set outside the branch below because the seams that read it are reached on both paths, and set
-- HERE because core/CoreSetup.lua is the first of the five the TOC loads.
NS.LIBKA0S_MISSING = "The LibKa0s library is missing from this installation of Absorb Tracker " ..
    "(expected in libs/LibKa0s)"

local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)

if not lib then
    -- A missing vendored lib must degrade, not error at load. Silence is not an option here the way
    -- it is for a diagnostics harness: four settings files do `local print = NS.Print` at load, so a
    -- nil printer takes the whole settings UI down with it, and a no-op one makes /at answer nothing
    -- at all. So the fallbacks work — they are the pre-library implementations, kept short — and the
    -- honest "it is not installed" line is said ONCE, on the first line the addon prints, rather
    -- than stapled to every one of them.
    local function probeConcat(v) return table.concat({ v }) end
    function NS.IsConcatSafe(v)
        return (pcall(probeConcat, v))
    end

    function NS.SafeToString(v)
        if v == nil then return "nil" end
        if type(v) == "boolean" then return tostring(v) end
        if NS.IsConcatSafe(v) then return tostring(v) end
        return "<secret>"
    end

    -- The class-color resolver, and a working fallback rather than a no-op for the same reason the
    -- two above are: core/Data.lua calls it on every paint pass of every bar, so an absent one
    -- takes all three shared-resolver surfaces down with it. Three rules, the library's
    -- (options-ui-§17) — the stored alpha survives the mode, an unresolvable class falls through to
    -- the stored swatch, and the swatch is read under BOTH modes. What is deliberately not copied
    -- is the memoization: a table index is not worth a second cache with its own invalidation
    -- story, and the one the library keeps is for the player alone.
    function NS.ResolveColor(stored, on, unit)
        if type(stored) ~= "table" then stored = {} end
        local r, g, b, a = stored.r or 1, stored.g or 1, stored.b or 1, stored.a or 1
        if not on then return r, g, b, a end
        -- pcall'd for the reason the library pcalls it: the token is the CALLER's, and one the
        -- client rejects raises rather than answering nil.
        local ok, _, token = pcall(UnitClass, unit or "player")
        local c = (ok and type(token) == "string" and type(RAID_CLASS_COLORS) == "table")
            and RAID_CLASS_COLORS[token] or nil
        if type(c) ~= "table" or type(c.r) ~= "number" then return r, g, b, a end
        return c.r, c.g, c.b, a
    end

    -- The event registration helper (LibKa0s-Core minor 8, events-frames-taint-§1), with the
    -- ONE-RUNG bodies docs/api/Core/version-8-docs.md 'Degradation' prescribes: the pcall and the
    -- rejected-list append, no front gate and no probe frame. A stub is the path for a missing
    -- library, not a second implementation; the pcall alone is what keeps one retired name from
    -- taking the rest of a registration block down with it.
    local function appendOnce(rejected, event)
        if type(rejected) ~= "table" then return end
        for i = 1, #rejected do if rejected[i] == event then return end end
        rejected[#rejected + 1] = event
    end

    function NS.SafeRegisterEvent(target, event, handler, rejected)
        local ok = pcall(target.RegisterEvent, target, event, handler)
        if not ok then appendOnce(rejected, event) end
        return ok
    end

    function NS.SafeRegisterUnitEvent(frame, event, rejected, u1, u2)
        local ok = pcall(frame.RegisterUnitEvent, frame, event, u1, u2)
        if not ok then appendOnce(rejected, event) end
        return ok
    end

    function NS.SafeRegisterEvents(target, events, handler, rejected)
        local n = 0
        for _, event in ipairs(events) do
            if NS.SafeRegisterEvent(target, event, handler, rejected) then n = n + 1 end
        end
        return n
    end

    local announced = false
    function NS.Print(...)
        local parts = { NS.PREFIX }
        for i = 1, select("#", ...) do parts[i + 1] = NS.SafeToString((select(i, ...))) end
        if not DEFAULT_CHAT_FRAME then return end
        if not announced then
            announced = true
            DEFAULT_CHAT_FRAME:AddMessage(NS.SafeToString(NS.PREFIX) .. " " ..
                NS.LIBKA0S_MISSING .. "; running on reduced built-in fallbacks.")
        end
        DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
    end
    Util.print = NS.Print

    return
end

NS.IsConcatSafe = lib.IsConcatSafe
NS.SafeToString = lib.SafeToString

-- ONE class-color resolver for the collection (options-ui-§17). This addon used to own a private
-- one in core/Data.lua reading `C_ClassColor.GetClassColor`, while two sibling addons owned one
-- reading `RAID_CLASS_COLORS` — the table every other unit frame on the player's screen is already
-- reading. That disagreement is exactly what the library settled, so the private copy is gone and
-- core/Data.lua's four color getters come through here. Handed over by reference: it closes over
-- nothing of ours, and the memoized player color is the library's to keep.
NS.ResolveColor = lib.ResolveColor

-- The collection's one pcalled event registration helper (Core minor 8, events-frames-taint-§1).
-- Every registration in core/AbsorbTracker.lua goes through these, so a name a patch retires costs
-- only itself, and the refused name lands once in NS.State.rejectedEvents for `/at debug events`.
-- Handed over by reference: the front gate (C_EventUtils.IsEventValid) and the probe frame are the
-- library's, and the rejected list is ours, passed in on every call.
NS.SafeRegisterEvent = lib.SafeRegisterEvent
NS.SafeRegisterUnitEvent = lib.SafeRegisterUnitEvent
NS.SafeRegisterEvents = lib.SafeRegisterEvents

-- The prefix is passed as a FUNCTION, not as the value of NS.PREFIX. It reads the same here, where
-- core/Namespace.lua has already run — but the printer is built once at load and the function form
-- is what keeps a later change to NS.PREFIX (or an addon whose prefix constant loads after its
-- setup file, which is why the library supports it) from being frozen out.
local printer = lib:New({
    prefix = function() return NS.PREFIX end,
})

-- NS.Print and NS.Util.print MUST be the same function object, not two wrappers around one printer.
-- AceAddon:NewAddon(NS, …) stamps AceConsole's :Print over NS.Print, and core/AbsorbTracker.lua
-- reclaims it by repointing NS.Print at NS.Util.print — which only restores what the settings files
-- captured because it is the identical object. tests/test_slash.lua asserts the identity directly.
NS.Print = printer.Print
Util.print = NS.Print
