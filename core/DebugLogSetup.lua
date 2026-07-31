local addonName, NS = ...

-- core/DebugLogSetup.lua — wires the addon into LibKa0s-DebugLog (issue #17).
--
-- The console window, the copy window, the two formatters, the buffer and the enable seam live in
-- libs/LibKa0s/DebugLog.lua and are shared across every Ka0s addon. This file supplies only the part
-- that is ours: the frame-name prefix, the title, the monospace font, where the debug flag actually
-- lives, and what the [Init] session summary says.
--
-- Sits in core/DebugLog.lua's old TOC slot, which puts it after core/Constants.lua (FONT_MONO),
-- core/State.lua (the debug flag) and core/CoreSetup.lua (NS.Print / NS.SafeToString), and before
-- everything that calls NS.Debug.

local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)

if not lib then
    -- A missing vendored lib must degrade, not error at load. The stub covers EVERY member the
    -- addon calls — settings/Slash.lua's `/at debug`, settings/General.lua's console checkbox and
    -- core/PerfSetup.lua's log sink all reach for one — and the flag itself still works, because
    -- NS.State.debug is ours and a user who types `/at debug on` should not be told nothing
    -- happened. What is lost is the window, and the stub says so once, honestly.
    local missing = NS.LIBKA0S_MISSING .. ", so the debug console window is unavailable."
    local announced = false
    local function sayOnce()
        if announced then return end
        announced = true
        if NS.Print then NS.Print(missing) end
    end

    -- No formatters here. Nothing in the addon calls them — they exist only inside the library's
    -- own Add — and hand-copying the exact strings whose seven-way drift this extraction exists to
    -- end would be the one duplicate testing-§8 most specifically forbids.
    NS.DebugLog = {
        buffer = {},
        Add             = function() end,
        Debug           = function() end,
        Clear           = function() end,
        Show            = function() sayOnce() end,
        Hide            = function() end,
        Toggle          = function() sayOnce() end,
        IsShown         = function() return false end,
        IsEnabled       = function() return NS.State and NS.State.debug or false end,
        SetEnabled      = function(_, on)
            on = not not on
            if NS.State then NS.State.debug = on end
            if NS.Print then
                NS.Print("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))
            end
            if on then sayOnce() end
        end,
        RefreshHeader   = function() end,
        ShowCopy        = function() sayOnce() end,
        UpdateScrollBar = function() end,
        UpdateStatus    = function() end,
        BufferSize      = function() return 0 end,
        LastLine        = function() return nil end,
        FindLine        = function() return nil end,
        MakeCloseButton = function() return nil end,
        ConsoleCheckbox = function()
            return {
                label   = "Debug console",
                tooltip = missing,
                get = function() return false end,
                set = function() sayOnce() end,
            }
        end,
    }
    NS.Debug = NS.DebugLog.Debug
    return
end

NS.DebugLog = lib:New({
    name  = addonName,
    title = "Absorb Tracker",
    font  = NS.Constants.FONT_MONO,
    slash = "/at",

    -- The flag stays ours. NS.State.debug is session-only and is read by NS.ShouldShowBar's ladder
    -- and by the settings panel, so a second copy inside the library would be a second truth.
    isEnabled  = function() return NS.State and NS.State.debug or false end,
    setEnabled = function(on) if NS.State then NS.State.debug = on end end,

    -- Both resolved at CALL time, not captured. NS.Print is reclaimed from AceConsole's embed in
    -- core/AbsorbTracker.lua, which loads after this file — a captured reference would freeze to
    -- whichever function happened to be there at load.
    print        = function(line) NS.Print(line) end,
    safeToString = function(v) return NS.SafeToString(v) end,

    -- The [Init] line the console brackets a session with. The library owns WHEN it is emitted —
    -- on enable, because the flag is off at login and a load-time summary would always be gated
    -- off — and only we can know what it says.
    initSummary = function()
        local schemaVer = NS.db and NS.db.global and NS.db.global.schemaVersion
        local profile = NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()
        return ("%s v%s, schema v%s, profile '%s'"):format(
            NS.SafeToString(NS.name), NS.SafeToString(NS.version),
            NS.SafeToString(schemaVer or "?"), NS.SafeToString(profile or "?"))
    end,

    -- The General page's console checkbox mirrors the window's visibility, so a console opened from
    -- `/at debug` has to move the checkbox on an options panel that is already open.
    onVisibilityChanged = function()
        if NS.Helpers and NS.Helpers.RefreshAllPanels then NS.Helpers.RefreshAllPanels() end
    end,
})

-- The global gated sink (Ka0s debug-logging §4), published under the name sixteen call sites across
-- five files already use. Bound bare rather than wrapped: it is a plain function precisely so
-- `NS.Debug("Absorb", "value=%s", total)` keeps working unchanged.
NS.Debug = NS.DebugLog.Debug
