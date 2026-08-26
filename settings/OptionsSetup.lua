local addonName, NS = ...

-- settings/OptionsSetup.lua — wires the addon into LibKa0s-Options-1.0.
--
-- The settings-canvas shell, the schema-row to AceGUI translation and the two-column flow engine
-- live in libs/LibKa0s/{Options,OptionsWidgets,OptionsScroll}.lua and are shared across every Ka0s
-- addon. This file is only the part that is ours: where a value lives, which rows belong to which
-- page, what a color looks like on disk, and what "reset everything" has to clear that no schema
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

-- Brand string, read by the library's header builder and by the top-level canvas registration. A
-- file-scope local, not an NS export: it reaches the library as descriptor.parentTitle, and the two
-- files that used to read it off the namespace (settings/Panel.lua, settings/Helpers.lua) are inside
-- the library now.
local PARENT_TITLE = "Ka0s Absorb Tracker"

-- The one rule about what a global reset must not touch. Profiles rows are AceDBOptions-supplied and
-- resetting them deletes user data, which is not what "restore defaults" means to anyone. Named once
-- because it is enforced TWICE: by the library, through descriptor.skipRestoreAll below, and by the
-- degradation stub's own reset loop, which has to keep working with no library at all. Two literal
-- copies of the rule — which is what this file used to carry, in opposite polarity — is one added
-- page away from a degraded `/at resetall` that deletes profiles.
--
-- EVERY PROFILE-BACKED ROW IS VETOED TOO (options-ui-§12). The global reset IS a profile reset now —
-- see resetProfile below — so walking the schema first and writing each row's default into the
-- profile would fire the panel refresh once per row for values about to be discarded whole. What the
-- walk is left with is exactly what a profile reset cannot reach: the sessionOnly rows, whose
-- storage is their own `set()` rather than the db.
local function vetoedFromResetAll(row)
    if row.page == "profiles" then return true end
    return not row.sessionOnly
end

local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)

-- ---------------------------------------------------------------------
-- The descriptor
-- ---------------------------------------------------------------------

local descriptor = {
    parentTitle   = PARENT_TITLE,
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

    -- The veto, named once above and shared with the stub's own reset loop.
    skipRestoreAll = vetoedFromResetAll,

    -- RESET ALL SETTINGS IS A PROFILE RESET (options-ui-§12), and `resetProfile` is the library
    -- field that says so (LibKa0s-Options-1.0 minor 9). It was a hand-written `afterRestoreAll`
    -- here, and in eight sibling addons -- one policy the standard forbids varying, restated once
    -- per repo.
    --
    -- With the field supplied the library narrows its own row walk to the sessionOnly rows before
    -- calling this, so the veto above is belt to that braces on the live path; it is the WHOLE
    -- policy on the degraded one, where there is no library to do the narrowing.
    --
    -- One call, and the same act as the Profiles page's Reset Profile. AceDB empties the ACTIVE
    -- profile -- and only that one; the profile LIST is untouched, which is the line the veto
    -- exists for -- the defaults merge back, and `OnProfileReset` reaches NS.OnProfileChanged
    -- (core/Database.lua), which repaints the bar and refreshes an open panel exactly as it does
    -- for a profile switch.
    --
    -- `position` comes back with it. It is written by dragging rather than by a schema row, so
    -- ApplyDefault never touched it and this hook used to call ResetAllPositions to clear it -- but
    -- a position lives IN THE PROFILE. The helper is untouched and still backs `/at resetposition`
    -- and the General page's button; it simply has no business here any more.
    resetProfile = function()
        local db = NS.db
        if db and db.ResetProfile then db:ResetProfile() end
    end,

    -- AceTimer through the addon object (Ka0s standard library-stack-§1) rather than a raw C_Timer. Backs the
    -- color picker's 50 ms drag throttle; the library takes it as a descriptor field because
    -- embedding AceTimer would be its second dependency-budget breach.
    scheduleTimer = function(fn, delay) return NS.addon:ScheduleTimer(fn, delay) end,

    getLSM   = function() return NS.GetLSM() end,
    validate = function() NS.ValidateSchema() end,

    -- Ka0s standard library-stack-§4: resolve AceGUI once and read the upvalue. settings/About.lua and the
    -- page builders read NS.AceGUI, so the library hands it over rather than keeping it private.
    onAceGUI = function(AceGUI) NS.AceGUI = AceGUI end,

    -- The About page's body, built on the main panel's first OnShow (settings/About.lua decorates
    -- NS.Helpers.BuildMainContent, which does not exist yet at this point in the load).
    buildMain = function(ctx)
        if NS.Helpers and NS.Helpers.BuildMainContent then NS.Helpers.BuildMainContent(ctx) end
    end,

    -- Colors are stored as {r=, g=, b=, a=} named keys (core/Data.lua's GetBarColor / GetBgColor /
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
-- So this stub publishes every member a page file touches AT LOAD TIME. Measured, one member at a
-- time, by deleting it and re-running the library-absent load (tests/degraded_env.lua) to see
-- whether #NS.Schema still matches the fully-loaded environment: LSMValues is the ONLY load-time
-- member. Dropping it gives `settings/Bar.lua:60: attempt to call field 'LSMValues' (a nil value)`
-- and takes the bar, border and font rows out of the schema; dropping anything else changed nothing.
--
-- RestoreAllDefaults is kept even though it measured as call-time, because the call it answers is
-- `/at resetall` and the StaticPopup's OnAccept closure in settings/General.lua — a recovery path,
-- and a user whose panel will not open is exactly the user who needs it.
--
-- What used to sit here and no longer does: SECTION_HEADING_H, ROW_VSPACER and BUTTON_PAIR_REL.
-- They are copies of lib.LAYOUT's values, and their only readers (settings/About.lua's
-- BuildMainContent, settings/UnitPanel.lua's render body) both sit behind an AceGUI a degraded build
-- never gets, so nothing in that build ever read them. A host copy of a library constant is the copy
-- that goes stale.
--
-- tests/test_optionssetup.lua pins that member set, and tests/test_perf.lua asserts #NS.Schema
-- against the fully-loaded environment over a whole library-absent load. Those cases are the only
-- thing standing between this stub and a silent half-load, so do not weaken either.
--
-- Note what is NOT here: no copy of a widget maker, no copy of the flow engine, no copy of the
-- header. Hand-copying the code whose drift the extraction exists to end is the one duplicate
-- testing-§8 most specifically forbids.
if not lib then
    local MISSING = NS.LIBKA0S_MISSING .. ", so the settings panel is unavailable."

    local Helpers = {}
    NS.Helpers = Helpers

    -- Reached at load, so it must be real enough for the page files to finish.
    Helpers.LSMValues = function() return function() return {} end end

    Helpers.RestoreAllDefaults = function()
        -- The rows are the schema's and the schema loaded fine, so a reset still works without any
        -- panel at all. Losing the panel is survivable; losing the reset would not be.
        for _, row in ipairs(NS.Schema or {}) do
            if not vetoedFromResetAll(row) then NS.ApplyDefault(row) end
        end
        -- Then the profile itself, which IS the reset (options-ui-§12). On the live path the
        -- library makes this call through the descriptor's `resetProfile`; here there is no
        -- library, so the stub makes it. The saved positions come back with the profile, which is
        -- why the ResetAllPositions call that used to close this function is gone from it.
        local db = NS.db
        if db and db.ResetProfile then db:ResetProfile() end
    end

    -- Reached only from a builder or a user action, so a no-op is the honest answer.
    for _, name in ipairs({
        "CreatePanel", "EnsureDefaultsButton", "EnsureScroll", "ClearScroll", "Section",
        "AddSpacer", "AttachTooltip", "InlineButtonPair", "RenderField", "RenderGrid", "RenderRows",
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
