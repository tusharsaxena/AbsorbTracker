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
-- The top-level "Ka0s Absorb Tracker" category is rendered as an
-- "about" page: addon title (auto-rendered from the group's `name`),
-- separator, logo, the TOC `Notes` blurb, and the slash-command list.
-- It holds no settings of its own — every Options/*.lua file registers
-- as a sub-page under it. The sub-page flagged `isDefault = true` is
-- the one `/at config` opens — typically General.

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

-- Logo lives in media/screenshots/. Path uses the WoW texture
-- convention (Interface\AddOns\<addon>\...). The .tga is 300×300 and
-- is rendered native — no resize.
local LOGO_PATH   = [[Interface\AddOns\AbsorbTracker\media\screenshots\absorbracker.logo.v2.tga]]
local LOGO_WIDTH  = 300
local LOGO_HEIGHT = 300

-- Custom AceGUI widget: image-only label that always anchors at
-- TOPLEFT. AceGUI's stock Label centers an image when the label text
-- is empty OR when (panel_width − image_width) < 200; on a ~530px
-- Blizzard settings canvas the empty-name branch still triggers
-- regardless of image size, so the image would render dead center
-- regardless of `width = "full"`. This widget renders only the
-- texture, anchored TOPLEFT.
local LEFT_IMAGE_WIDGET = "AbsorbTrackerLeftImage"

local function ensureLeftImageWidget()
    if not LibStub then return end
    local AceGUI = LibStub("AceGUI-3.0", true)
    if not AceGUI then return end
    if AceGUI:GetWidgetVersion(LEFT_IMAGE_WIDGET) then return end

    local function Constructor()
        local frame = CreateFrame("Frame", nil, UIParent)
        frame:Hide()
        local image = frame:CreateTexture(nil, "BACKGROUND")
        image:SetPoint("TOPLEFT")

        local widget = {
            image = image,
            frame = frame,
            type  = LEFT_IMAGE_WIDGET,
        }

        function widget:OnAcquire()
            self:SetWidth(200)
            self:SetImage(nil)
            self:SetImageSize(16, 16)
        end

        -- AceConfigDialog calls these on description controls; ignored
        -- because this widget is image-only.
        function widget:SetText() end
        function widget:SetFontObject() end
        function widget:SetColor() end

        function widget:SetImage(path, ...)
            self.image:SetTexture(path)
            local n = select("#", ...)
            if n == 4 or n == 8 then
                self.image:SetTexCoord(...)
            else
                self.image:SetTexCoord(0, 1, 0, 1)
            end
        end

        function widget:SetImageSize(w, h)
            self.image:SetWidth(w)
            self.image:SetHeight(h)
            self.frame:SetHeight(h)
            self.frame.height = h
        end

        function widget:OnWidthSet() end

        return AceGUI:RegisterAsWidget(widget)
    end

    AceGUI:RegisterWidgetType(LEFT_IMAGE_WIDGET, Constructor, 1)
end

local function getMetadata(field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(AddonName, field)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(AddonName, field)
    end
end

local function buildSlashCommandList()
    local list = AddonTable.SlashCommands
    if not list or #list == 0 then return "" end
    local lines = {}
    for _, entry in ipairs(list) do
        lines[#lines + 1] = ("|cFFFFFF00/at %s|r — %s"):format(entry[1], entry[2])
    end
    return table.concat(lines, "\n")
end

-- Built lazily at registerParent() time so AddonTable.SlashCommands
-- (defined in SlashCommands.lua) and GetAddOnMetadata are both
-- available — OptionsPanel.lua loads before SlashCommands.lua per TOC,
-- but registerParent runs at PLAYER_LOGIN.
local function buildParentOptions()
    local notes = getMetadata("Notes") or ""
    return {
        name = PARENT_NAME,
        type = "group",
        args = {
            separator = {
                order = 10,
                type  = "header",
                name  = "",
            },
            -- width = "full" forces a full-row widget so the image and
            -- text anchor to the panel's left edge rather than centering
            -- in a half-row column. The logo also overrides
            -- dialogControl to bypass AceGUI Label's centered-image
            -- branch (see ensureLeftImageWidget above).
            logo = {
                order         = 20,
                type          = "description",
                dialogControl = LEFT_IMAGE_WIDGET,
                name          = "",
                image         = LOGO_PATH,
                imageWidth    = LOGO_WIDTH,
                imageHeight   = LOGO_HEIGHT,
                width         = "full",
            },
            notes = {
                order    = 30,
                type     = "description",
                name     = "\n" .. notes .. "\n",
                fontSize = "medium",
                width    = "full",
            },
            commandsSeparator = {
                order = 40,
                type  = "description",
                name  = " ",
                width = "full",
            },
            commandsHeader = {
                order = 50,
                type  = "header",
                name  = "Slash Commands",
            },
            commands = {
                order    = 60,
                type     = "description",
                name     = buildSlashCommandList(),
                fontSize = "medium",
                width    = "full",
            },
        },
    }
end

local function registerParent(AceConfig, AceConfigDialog)
    ensureLeftImageWidget()
    AceConfig:RegisterOptionsTable(PARENT_APPNAME, buildParentOptions())
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
