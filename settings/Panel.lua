local addonName, NS = ...

-- Settings UI registration shell. The Helpers toolkit (CreatePanel / Section / InlineButtonPair /
-- EnsureScroll / Tooltip / restore-and-refresh) lives in settings/Helpers.lua; the always-visible
-- scrollbar patch in settings/ScrollPatch.lua; the schema → AceGUI widget translation
-- (RenderField / RenderSchema + the four widget makers) in settings/Widgets.lua; the about-page
-- builder in settings/About.lua. This file publishes an empty NS.Helpers before those slices load
-- so each one can decorate the same table, and owns the enable-time category registration plus the
-- combat-gated /at config entry point.

local print = NS.Print

-- Helpers toolkit publish — empty table so settings/*.lua slices that load after this file can
-- decorate it. settings/<page>.lua read NS.Helpers at enable time, after every decoration.
NS.Helpers = NS.Helpers or {}
local Helpers = NS.Helpers

-- Brand string used by the header builder and the top-level canvas registration.
NS.PARENT_TITLE = "Ka0s Absorb Tracker"
local PARENT_TITLE = NS.PARENT_TITLE

-- File-load-time queue. settings/<page>.lua files load after this file (per TOC order) and append
-- their builders here.
local pendingPages = {}

local mainCategory             -- Settings.RegisterCanvasLayoutCategory return
local mainCategoryID           -- numeric ID for OpenToCategory

--- Register a sub-page builder.
-- @param key       Unique short key ("general", "bar", ...).
-- @param name      Display name shown in Blizzard Settings.
-- @param builder   function(mainCategory) -> sub-category | nil. Called at enable time once db is
--                  ready. Return nil to skip the page (e.g. AceDBOptions missing → no Profiles).
function NS.RegisterOptionsPage(key, name, builder)
    pendingPages[#pendingPages + 1] = {
        key     = key,
        name    = name,
        builder = builder,
    }
end

local function registerMain()
    if not (Settings and Settings.RegisterCanvasLayoutCategory
            and Settings.RegisterAddOnCategory) then
        return
    end

    local mainCtx = Helpers.CreatePanel("AbsorbTrackerMainPanel", PARENT_TITLE,
        { isMain = true })

    -- Defer body render until first OnShow: AceGUI's ScrollFrame lays out children against the
    -- parent's current width, which is zero at enable time.
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

function NS.CreateOptionsPanel()
    if not LibStub then return end
    local AceGUI = LibStub("AceGUI-3.0", true)
    if not AceGUI then
        print("AceGUI-3.0 not available; settings panel unavailable.")
        return
    end
    -- Stash AceGUI once (Ka0s standard §3.4) so the panel toolkit / widget makers / about page
    -- read the upvalue instead of re-fetching via LibStub in every builder. Set before any
    -- builder runs (registerMain and the page builders both fire below).
    NS.AceGUI = AceGUI

    NS.ValidateSchema()

    registerMain()
    if not mainCategory then return end

    -- Each builder registers its own Blizzard subcategory (RegisterCanvasLayoutSubcategory) as a
    -- side effect; a nil return means the page opted out (e.g. Profiles without AceDBOptions).
    for _, page in ipairs(pendingPages) do
        page.builder(mainCategory)
    end
end

-- Expand the parent category in the Blizzard Settings left tree so every sub-page is visible.
-- Wrapped in pcall: SettingsPanel internals are private API and could shift between patches.
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

function NS.OpenOptionsPanel()
    if InCombatLockdown() then
        -- Blizzard's category-switch (Settings.OpenToCategory) is protected; calling it under
        -- lockdown taints the panel for the rest of the session. Per Ka0s standard options-ui-§2
        -- the open MUST REFUSE with a grey, NS.PREFIX-tagged notice and return — it MUST NOT
        -- defer-and-replay on PLAYER_REGEN_ENABLED (a panel that auto-opens the instant combat
        -- drops steals focus during post-pull recovery). The user re-runs /at config when ready.
        -- The gate lives HERE (inside the open fn) so every caller — the /at config verb, /run
        -- scripts, future internal callers — is refused, not just the slash dispatcher. `print` is
        -- the file-local `local print = NS.Print`, so the line still carries the cyan [AT] tag.
        print("|cffaaaaaacannot open settings during combat \226\128\148 Blizzard's category-switch is protected|r")
        return
    end
    if not (Settings and Settings.OpenToCategory) then return end
    if not mainCategoryID then return end
    Settings.OpenToCategory(mainCategoryID)
    expandMainCategory()
end

-- AceDB profile changes (NS.OnProfileChanged) call this so any open page re-reads its values. /at
-- set, /at reset, and /at resetall also call it so an open panel reflects the change immediately.
function NS.RefreshOptionsPanel()
    Helpers.RefreshAllPanels()
end
