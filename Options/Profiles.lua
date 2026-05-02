-- AbsorbTracker: Options/Profiles.lua
--
-- Profiles sub-page. Uses the unified header (no Defaults button —
-- profile management has its own destructive controls inside the
-- AceDBOptions UI). The body hosts an AceGUI SimpleGroup container
-- into which AceConfigDialog renders the AceDBOptions options table on
-- first show.
--
-- Optional dependency: if AceDBOptions / AceConfigDialog isn't loaded
-- the page is skipped silently.

local AddonName, AddonTable = ...

local APPNAME = "AbsorbTracker-Profiles"

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end
    if not LibStub then return nil end

    local AceDBOptions    = LibStub("AceDBOptions-3.0",    true)
    local AceConfig       = LibStub("AceConfig-3.0",       true)
    local AceConfigDialog = LibStub("AceConfigDialog-3.0", true)
    local AceGUI          = LibStub("AceGUI-3.0",          true)
    if not (AceDBOptions and AceConfig and AceConfigDialog and AceGUI) then
        return nil
    end
    if not (AddonTable.db and AddonTable.db.profile) then return nil end

    local H = AddonTable.Helpers
    if not (H and H.CreatePanel) then return nil end

    -- Register the AceConfig options once. AceDBOptions returns a fully
    -- formed options table covering create / switch / copy / reset /
    -- delete plus per-character / per-class / per-realm / per-faction /
    -- default scope dropdowns.
    local opts = AceDBOptions:GetOptionsTable(AddonTable.db)
    AceConfig:RegisterOptionsTable(APPNAME, opts)

    local ctx = H.CreatePanel("AbsorbTrackerProfilesPanel", "Profiles", {
        pageKey        = "profiles",
        defaultsButton = false,
    })

    -- AceGUI SimpleGroup parented to our body. AceConfigDialog:Open
    -- accepts any AceGUI container as the rendering target; we point
    -- it at this group so the AceDBOptions widgets land inside our
    -- canvas frame instead of opening their own window.
    local container = AceGUI:Create("SimpleGroup")
    container:SetLayout("Fill")
    container.frame:SetParent(ctx.body)
    container.frame:ClearAllPoints()
    container.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      8, -8)
    container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8, 8)

    -- Open lazily on first show. Re-Open()ing on every show is cheap
    -- (AceConfigDialog reuses the existing widget tree if one exists)
    -- and ensures the UI reflects the current profile after a switch.
    ctx.panel:SetScript("OnShow", function()
        AceConfigDialog:Open(APPNAME, container)
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "Profiles")
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("profiles", "Profiles", build)
end
