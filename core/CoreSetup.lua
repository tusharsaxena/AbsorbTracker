local addonName, NS = ...
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
-- NS.PREFIX just above it, and everything below it — core/PerfSetup.lua first — either calls
-- NS.Print or takes it as a load-time upvalue.

local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)

if not lib then
    -- A missing vendored lib must degrade, not error at load. Silence is not an option here the way
    -- it is for a diagnostics harness: five settings files do `local print = NS.Print` at load, so a
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

    local announced = false
    function NS.Print(...)
        local parts = { NS.PREFIX }
        for i = 1, select("#", ...) do parts[i + 1] = NS.SafeToString((select(i, ...))) end
        if not DEFAULT_CHAT_FRAME then return end
        if not announced then
            announced = true
            DEFAULT_CHAT_FRAME:AddMessage(NS.SafeToString(NS.PREFIX) .. " The LibKa0s library is " ..
                "missing from this installation of Absorb Tracker (expected in libs/LibKa0s); " ..
                "running on reduced built-in fallbacks.")
        end
        DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
    end
    Util.print = NS.Print
    return
end

NS.IsConcatSafe = lib.IsConcatSafe
NS.SafeToString = lib.SafeToString

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
