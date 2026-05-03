-- AbsorbTracker: OptionsPanel module
--
-- Settings UI registration shell. The Helpers toolkit (CreatePanel /
-- Section / InlineButtonPair / EnsureScroll / Tooltip /
-- restore-and-refresh) lives in Panel/Helpers.lua; the always-visible
-- scrollbar patch in Panel/ScrollPatch.lua; the schema → AceGUI
-- widget translation (RenderField / RenderSchema + the four widget
-- makers) in Panel/Widgets.lua; the about-page builder in
-- Panel/About.lua. This file publishes an empty AddonTable.Helpers
-- before those slices load so each one can decorate the same table,
-- and owns the PLAYER_LOGIN-time category registration plus the
-- combat-gated /at config entry point.
--
-- The schema-driven sub-pages (General / Bar / Border / Font) render
-- their schema rows as AceGUI widgets (CheckBox / Slider / Dropdown /
-- ColorPicker / Heading) inside an AceGUI ScrollFrame parented to
-- ctx.body, so the visual style matches AceGUI-using addons (e.g.
-- KickCD, Consumable Master).
--
-- The same schema feeds /at list|get|set (see Schema.lua + SlashCommands.lua),
-- so adding a new option = one row that auto-wires UI and CLI.

local AddonName, AddonTable = ...

local print = AddonTable.Print

-- ---------------------------------------------------------------------
-- Helpers toolkit publish — empty table so Panel/*.lua slices that load
-- after this file can decorate it. Options/*.lua read AddonTable.Helpers
-- at PLAYER_LOGIN, well after every decoration is complete.
-- ---------------------------------------------------------------------

AddonTable.Helpers = AddonTable.Helpers or {}
local Helpers = AddonTable.Helpers

-- Brand string used by Panel/Helpers.lua's buildHeader prefix and by
-- the top-level canvas registration in registerMain below. Published
-- on AddonTable so a single source of truth survives the file split.
AddonTable.PARENT_TITLE = "Ka0s Absorb Tracker"
local PARENT_TITLE = AddonTable.PARENT_TITLE

-- ---------------------------------------------------------------------
-- Module state
-- ---------------------------------------------------------------------

-- File-load-time queue. Options/*.lua files load after this file (per
-- TOC order) and append their builders here.
local pendingPages = {}

-- Post-registration tracking.
local mainCategory             -- Settings.RegisterCanvasLayoutCategory return
local mainCategoryID           -- numeric ID for OpenToCategory
local subCategoriesByKey = {}  -- key → subcategory return from RegisterCanvasLayoutSubcategory

-- ---------------------------------------------------------------------
-- Page registration (file-load-time)
-- ---------------------------------------------------------------------

--- Register a sub-page builder.
-- @param key       Unique short key ("general", "bar", ...).
-- @param name      Display name shown in Blizzard Settings as the
--                  sub-page title.
-- @param builder   function(mainCategory) -> sub-category | nil. Called
--                  at PLAYER_LOGIN once db is ready. Return nil to skip
--                  the page (e.g. AceDBOptions missing → no Profiles).
function AddonTable.RegisterOptionsPage(key, name, builder)
    pendingPages[#pendingPages + 1] = {
        key     = key,
        name    = name,
        builder = builder,
    }
end

-- ---------------------------------------------------------------------
-- PLAYER_LOGIN-time registration
-- ---------------------------------------------------------------------

local function registerMain()
    if not (Settings and Settings.RegisterCanvasLayoutCategory
            and Settings.RegisterAddOnCategory) then
        return
    end

    local mainCtx = Helpers.CreatePanel("AbsorbTrackerMainPanel", PARENT_TITLE,
        { isMain = true })

    -- Defer body render until first OnShow: AceGUI's ScrollFrame lays
    -- out children against the parent's current width, which is zero at
    -- PLAYER_LOGIN, and there's no point building widgets for a panel
    -- the user may never open.
    local mainRendered = false
    mainCtx.panel:SetScript("OnShow", function()
        if mainRendered then return end
        mainRendered = true
        if Helpers.BuildMainContent then
            Helpers.BuildMainContent(mainCtx)
        end
    end)

    mainCategory   = Settings.RegisterCanvasLayoutCategory(mainCtx.panel, PARENT_TITLE)
    Settings.RegisterAddOnCategory(mainCategory)
    mainCategoryID = mainCategory:GetID()
end

function AddonTable.CreateOptionsPanel()
    if not LibStub then return end
    local AceGUI = LibStub("AceGUI-3.0", true)
    if not AceGUI then
        print("AceGUI-3.0 not available; settings panel unavailable.")
        return
    end

    AddonTable.ValidateSchema()

    registerMain()
    if not mainCategory then return end

    for _, page in ipairs(pendingPages) do
        local sub = page.builder(mainCategory)
        if sub then
            subCategoriesByKey[page.key] = sub
        end
    end
end

-- ---------------------------------------------------------------------
-- Open / refresh
-- ---------------------------------------------------------------------

-- Expand the parent category in the Blizzard Settings left tree so
-- every sub-page is visible. Wrapped in pcall: SettingsPanel internals
-- (CategoryList, GetCategoryEntry, SetExpanded) are private API and
-- could shift between patches; if any call goes missing we just open
-- the panel without forcing expansion rather than erroring out.
local function expandMainCategory()
    if not (mainCategory and SettingsPanel) then return end
    pcall(function()
        local list = SettingsPanel.GetCategoryList
            and SettingsPanel:GetCategoryList()
            or SettingsPanel.CategoryList
        if not (list and list.GetCategoryEntry) then return end
        local entry = list:GetCategoryEntry(mainCategory)
        if entry and entry.SetExpanded then
            entry:SetExpanded(true)
        end
    end)
end

function AddonTable.OpenOptionsPanel()
    -- Settings UI is protected during combat.
    if InCombatLockdown() then
        print("Cannot open settings panel during combat. Try again after combat ends.")
        return
    end
    if not (Settings and Settings.OpenToCategory) then return end
    if not mainCategoryID then return end
    Settings.OpenToCategory(mainCategoryID)
    expandMainCategory()
end

-- AceDB profile changes (OnProfileChanged callback in Events.lua) call
-- this so any open page re-reads its values from the new profile. /at
-- set, /at reset, and /at resetall also call this so an open panel
-- reflects the change immediately.
function AddonTable.RefreshOptionsPanel()
    Helpers.RefreshAllPanels()
end
