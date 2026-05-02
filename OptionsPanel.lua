-- AbsorbTracker: OptionsPanel module
--
-- Registration shell for the multi-page settings UI. Each Options/*.lua
-- file calls AddonTable.RegisterOptionsPage(key, name, builder, opts) at
-- file-load time to queue itself; CreateOptionsPanel() (invoked from
-- Events.lua on PLAYER_LOGIN, after AceDB is initialized) builds each
-- page's options table and registers it with AceConfig +
-- AceConfigDialog:AddToBlizOptions so the pages appear as Blizzard
-- subcategories under "Ka0s Absorb Tracker".
--
-- The top-level "Ka0s Absorb Tracker" category is rendered as an empty
-- title-only page (no options live there). Every Options/*.lua file
-- registers as a sub-page under that parent. The page flagged
-- `isDefault = true` is the one `/at config` opens — typically General.

local AddonName, AddonTable = ...

local print = AddonTable.Print

local PARENT_NAME    = "Ka0s Absorb Tracker"
local PARENT_APPNAME = "AbsorbTracker"

-- File-load-time queue. Options/*.lua files load after this file (per
-- TOC order) and append their builders here.
local pendingPages = {}

-- Post-registration map: key -> { appName, frame, categoryID }. Used by
-- RefreshOptionsPanel to NotifyChange every page.
local pages = {}

local parentCategoryID    -- empty top-level page; fallback for OpenToCategory
local defaultCategoryID   -- sub-page flagged `isDefault`; what /at config opens

-- ---------------------------------------------------------------------
-- File-load-time registration
-- ---------------------------------------------------------------------

--- Register a sub-page builder.
-- @param key       Unique short key ("general", "bar", ...). Used to
--                  build the AceConfig appName ("AbsorbTracker-<key>").
-- @param name      Display name shown in Blizzard Settings as the
--                  sub-page title.
-- @param builder   function() -> AceConfig options table (lazy; called
--                  at PLAYER_LOGIN once db is ready). Return nil to skip
--                  the page (e.g. AceDBOptions missing → no Profiles).
-- @param opts      Optional { isDefault = true } to mark this page as
--                  the one `/at config` opens. Exactly one page should
--                  set this; if more than one does, the first wins.
function AddonTable.RegisterOptionsPage(key, name, builder, opts)
    pendingPages[#pendingPages + 1] = {
        key       = key,
        name      = name,
        builder   = builder,
        isDefault = opts and opts.isDefault,
    }
end

-- ---------------------------------------------------------------------
-- PLAYER_LOGIN-time registration
-- ---------------------------------------------------------------------

-- Empty options table for the top-level category. AceConfigDialog needs
-- *some* table registered against the parent appName so the canvas frame
-- exists; an args-less group renders just the title and an empty body.
local emptyParentOpts = {
    name = PARENT_NAME,
    type = "group",
    args = {},
}

local function registerParent(AceConfig, AceConfigDialog)
    AceConfig:RegisterOptionsTable(PARENT_APPNAME, emptyParentOpts)
    local _, categoryID = AceConfigDialog:AddToBlizOptions(PARENT_APPNAME, PARENT_NAME)
    parentCategoryID = categoryID
end

local function registerPage(AceConfig, AceConfigDialog, page)
    local opts = page.builder()
    if not opts then return end

    local appName = "AbsorbTracker-" .. page.key
    AceConfig:RegisterOptionsTable(appName, opts)

    local frame, categoryID = AceConfigDialog:AddToBlizOptions(
        appName, page.name, PARENT_NAME)

    pages[page.key] = {
        appName    = appName,
        frame      = frame,
        categoryID = categoryID,
    }

    if page.isDefault then
        defaultCategoryID = categoryID
    end
end

function AddonTable.CreateOptionsPanel()
    if not LibStub then return end
    local AceConfig       = LibStub("AceConfig-3.0", true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    if not (AceConfig and AceConfigDialog) then
        print("AceConfig-3.0 not available; settings panel unavailable.")
        return
    end

    registerParent(AceConfig, AceConfigDialog)
    for _, page in ipairs(pendingPages) do
        registerPage(AceConfig, AceConfigDialog, page)
    end
end

-- ---------------------------------------------------------------------
-- Open / refresh
-- ---------------------------------------------------------------------

function AddonTable.OpenOptionsPanel()
    -- Settings UI is protected during combat.
    if InCombatLockdown() then
        print("Cannot open settings panel during combat. Try again after combat ends.")
        return
    end
    if not (Settings and Settings.OpenToCategory) then return end
    -- Prefer the page flagged isDefault (General), fall back to the
    -- empty parent if no default was registered.
    local target = defaultCategoryID or parentCategoryID
    if target then Settings.OpenToCategory(target) end
end

-- AceDB profile changes (OnProfileChanged callback in Events.lua) call
-- this so any open page re-reads its values from the new profile. We
-- NotifyChange every registered page; AceConfigDialog re-renders the
-- one currently shown.
function AddonTable.RefreshOptionsPanel()
    if not LibStub then return end
    local AceConfigRegistry = LibStub("AceConfigRegistry-3.0", true)
    if not AceConfigRegistry then return end
    for _, p in pairs(pages) do
        AceConfigRegistry:NotifyChange(p.appName)
    end
end
