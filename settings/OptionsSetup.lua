local addonName, NS = ...

-- settings/OptionsSetup.lua — wires the addon into LibKa0s-Options-1.0.
--
-- The settings-canvas shell, the schema-row to AceGUI translation and the two-column flow engine
-- live in libs/LibKa0s/{Options,OptionsWidgets,OptionsScroll}.lua and are shared across every Ka0s
-- addon. This file is only the part that is ours: where a value lives, which rows belong to which
-- page, what a colour looks like on disk, and what "reset everything" has to clear that no schema
-- row owns.
--
-- It replaces four files that used to be this addon's own toolkit — settings/Panel.lua,
-- settings/Helpers.lua, settings/ScrollPatch.lua and settings/Widgets.lua. `NS.Helpers` keeps its
-- name and keeps answering every member it answered before: forty-odd call sites across the page
-- files and the suites index it directly, and renaming it would have been churn with no reader on
-- the other side. What changed is where the implementations come from.
--
-- Loads immediately after settings/Slash.lua and BEFORE every settings/<page>.lua, because those
-- files call NS.Helpers.LSMValues at file load. See the stub below for what that costs.

local print = NS.Print

-- Brand string, read by the library's header builder and by the top-level canvas registration.
NS.PARENT_TITLE = "Ka0s Absorb Tracker"

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

-- ---------------------------------------------------------------------
-- The descriptor
-- ---------------------------------------------------------------------

local descriptor = {
    parentTitle   = NS.PARENT_TITLE,
    mainPanelName = "AbsorbTrackerMainPanel",

    print = function(line) print(line) end,
    debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,

    -- The schema seams. SetByPath rather than a bare write, so a panel change takes exactly the
    -- path a `/at set` takes: the [Set] debug line, the row's onChange, and the panel refresh.
    get          = function(path) return NS.GetSetting(path) end,
    set          = function(path, value) NS.SetByPath(path, value) end,
    applyDefault = function(row) NS.ApplyDefault(row) end,
    allRows      = function() return NS.Schema end,

    -- `filter` is ctx.unit, which the library passes through without interpreting. That is what
    -- makes a per-unit page render only the selected unit's rows while a page with ctx.unit nil
    -- (General) gets every unit's.
    rowsForPage  = function(pageKey, filter) return NS.SchemaForPage(pageKey, filter) end,

    -- Profiles is skipped on purpose: its rows are AceDBOptions-supplied and resetting them would
    -- delete user data, which is not what "restore defaults" means to anyone.
    skipRestoreAll = function(row) return row.page == "profiles" end,

    -- `position` is written by dragging, not by a schema row, so ApplyDefault never touches it. It
    -- must be cleared explicitly, once per unit, or a target bar dragged off-screen would survive a
    -- Reset All. Delegated to the single shared helper (settings/UnitPanel.lua) so this and
    -- `/at resetposition` and the General page's button stay one implementation — they diverged
    -- here once already.
    afterRestoreAll = function()
        if NS.Helpers and NS.Helpers.ResetAllPositions then NS.Helpers.ResetAllPositions() end
    end,

    -- AceTimer through the addon object (Ka0s standard §3.1) rather than a raw C_Timer. Backs the
    -- colour picker's 50 ms drag throttle; the library takes it as a descriptor field because
    -- embedding AceTimer would be its second dependency-budget breach.
    scheduleTimer = function(fn, delay) return NS.addon:ScheduleTimer(fn, delay) end,

    getLSM   = function() return NS.GetLSM() end,
    validate = function() NS.ValidateSchema() end,

    -- Ka0s standard §3.4: resolve AceGUI once and read the upvalue. settings/About.lua and the
    -- page builders read NS.AceGUI, so the library hands it over rather than keeping it private.
    onAceGUI = function(AceGUI) NS.AceGUI = AceGUI end,

    -- The About page's body, built on the main panel's first OnShow (settings/About.lua decorates
    -- NS.Helpers.BuildMainContent, which does not exist yet at this point in the load).
    buildMain = function(ctx)
        if NS.Helpers and NS.Helpers.BuildMainContent then NS.Helpers.BuildMainContent(ctx) end
    end,

    -- Colours are stored as {r=, g=, b=, a=} named keys (core/Data.lua's GetBarColor / GetBgColor /
    -- GetBorderColor read that shape). That is also the library's default, so these two are written
    -- out rather than omitted only because the shape is a real contract with the rest of the addon
    -- and a silent default is a poor place for it to live.
    colorDecode = function(c)
        if type(c) ~= "table" then c = {} end
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end,
    colorEncode = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 1 } end,
}

-- ---------------------------------------------------------------------
-- The degradation stub — LOAD-COMPLETING, not member-answering
-- ---------------------------------------------------------------------
--
-- Every other setup file in this addon degrades to a table that answers each member with an honest
-- "not installed" line. That calculus does not survive contact with this one, and the reason is not
-- importance — it is WHEN the missing code is reached.
--
-- settings/Bar.lua evaluates `NS.Helpers.LSMValues("statusbar")` inside a schema-row literal, at
-- FILE LOAD. Border.lua and Font.lua do the same. With LSMValues nil that is `attempt to call field
-- 'LSMValues' (a nil value)`, so settings/Bar.lua never finishes loading, so NS.RegisterSchemaRows
-- never runs for the bar page, so a third of NS.Schema is missing — and `/at list`,
-- `/at set units.player.barWidth`, `/at reset` and the profile defaults all break with it. The
-- addon would not degrade; it would half-load, and nothing would say so.
--
-- So this stub publishes every member a page file touches AT LOAD TIME. Verified to be exactly
-- three: LSMValues, SECTION_HEADING_H (settings/About.lua) and RestoreAllDefaults (the
-- StaticPopup body in settings/General.lua, which is a table literal evaluated at load). Everything
-- else is reached from CreateOptionsPanel or from a page builder, both of which are user-triggered,
-- so those are no-ops.
--
-- tests/test_perf.lua's `loadDegraded()` loads the whole TOC without the library and asserts
-- #NS.Schema against the fully-loaded environment. That case is the only thing standing between
-- this stub and a silent half-load, so do not weaken either.
--
-- Note what is NOT here: no copy of a widget maker, no copy of the flow engine, no copy of the
-- header. Hand-copying the code whose drift the extraction exists to end is the one duplicate
-- testing-§8 most specifically forbids.
if not lib then
    local MISSING = "The settings panel is unavailable: the LibKa0s library is missing from this " ..
        "installation of Absorb Tracker (expected in libs/LibKa0s)."

    local Helpers = {}
    NS.Helpers = Helpers

    -- Reached at load, so they must be real enough for the file to finish.
    Helpers.LSMValues         = function() return function() return {} end end
    Helpers.SECTION_HEADING_H = 26
    Helpers.ROW_VSPACER       = 8
    Helpers.BUTTON_PAIR_REL   = 0.492
    Helpers.RestoreAllDefaults = function()
        -- The rows are the schema's and the schema loaded fine, so a reset still works without any
        -- panel at all. Losing the panel is survivable; losing the reset would not be.
        for _, row in ipairs(NS.Schema or {}) do
            if row.page ~= "profiles" then NS.ApplyDefault(row) end
        end
        if Helpers.ResetAllPositions then Helpers.ResetAllPositions() end
    end

    -- Reached only from a builder or a user action, so a no-op is the honest answer.
    for _, name in ipairs({
        "CreatePanel", "EnsureDefaultsButton", "EnsureScroll", "ClearScroll", "Section",
        "AddSpacer", "AttachTooltip", "InlineButtonPair", "RenderField", "RenderRows",
        "RenderSchema", "SessionCheckbox", "RefreshAllPanels", "RestoreDefaults",
        "PatchAlwaysShowScrollbar",
        -- RenderUnitPanel is deliberately absent: settings/UnitPanel.lua loads after this file and
        -- publishes the real one either way, and it already bails on a nil NS.AceGUI. A no-op here
        -- would read as though the degraded build had its own, which it does not.
    }) do
        Helpers[name] = function() end
    end
    Helpers.__panels   = function() return {} end
    Helpers.__panelFor = function() return nil end

    NS.RegisterOptionsPage = function() end
    NS.RefreshOptionsPanel = function() end
    -- One honest line, exactly as this already did when AceGUI was the thing missing.
    NS.CreateOptionsPanel  = function() print(MISSING) end
    NS.OpenOptionsPanel    = function() print(MISSING) end
    return
end

-- ---------------------------------------------------------------------
-- The live wiring
-- ---------------------------------------------------------------------

-- NS.Helpers IS the library instance, not a table decorated from it. Two things then hold that a
-- copy-across would break: settings/UnitPanel.lua and settings/About.lua decorate the same table
-- the library's own members live on (so RenderUnitPanel can call RenderRows through `Helpers` like
-- every other page does), and a test that swaps a member out to spy on it — tests/test_helpers.lua
-- does exactly that with ResetAllPositions — is swapping the one the library's own callers see.
NS.Helpers = lib:New(descriptor)
local Helpers = NS.Helpers

NS.RegisterOptionsPage = function(key, name, builder) Helpers.RegisterOptionsPage(key, name, builder) end
NS.CreateOptionsPanel  = function() Helpers.CreateOptionsPanel() end
NS.OpenOptionsPanel    = function() Helpers.OpenOptionsPanel() end

-- AceDB profile changes (NS.OnProfileChanged) call this so any open page re-reads its values, and
-- so do `/at set`, `/at reset` and `/at resetall`.
NS.RefreshOptionsPanel = function() Helpers.RefreshAllPanels() end
