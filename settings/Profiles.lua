-- AbsorbTracker: settings/Profiles.lua
--
-- Profiles sub-page. Uses the unified header (no Defaults button —
-- profile management has its own destructive controls inside the
-- AceDBOptions UI). The body hosts an AceGUI SimpleGroup container
-- into which AceConfigDialog renders the AceDBOptions options table on
-- first show.
--
-- Optional dependency: if AceDBOptions / AceConfigDialog isn't loaded
-- the page is skipped silently.

local addonName, NS = ...

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
    if not (NS.db and NS.db.profile) then return nil end

    local H = NS.Helpers
    if not (H and H.CreatePanel) then return nil end

    -- Register the AceConfig options once. AceDBOptions returns a fully
    -- formed options table covering create / switch / copy / reset /
    -- delete plus per-character / per-class / per-realm / per-faction /
    -- default scope dropdowns.
    local opts = AceDBOptions:GetOptionsTable(NS.db)
    AceConfig:RegisterOptionsTable(APPNAME, opts)

    local ctx = H.CreatePanel("AbsorbTrackerProfilesPanel", "Profiles", {
        pageKey        = "profiles",
        defaultsButton = false,
    })

    -- The AceGUI SimpleGroup that hosts the rendered options tree.
    -- AceConfigDialog:Open accepts any AceGUI container as its target;
    -- we point it at this group so the AceDBOptions widgets land inside
    -- our canvas frame instead of opening their own window. The group is
    -- created on first OnShow, never in the builder — options-ui-§5 wants
    -- no canvas widget built before the page is first opened.
    local container

    -- Declared THROUGH SetRenderer rather than a hand-wired OnShow (options-ui-§11), and the
    -- combat refusal is why: the Blizzard AddOns sidebar opens a canvas directly, so this page
    -- had no gate at all on the path a player is most likely to take mid-pull. SetRenderer owns
    -- the script and refuses under InCombatLockdown before anything is drawn.
    --
    -- Re-Open()ing on every show was the old reason for owning the script here, and it survives
    -- the move. AceConfigDialog's widget tree is not ours -- it reuses it and re-reads the current
    -- profile on each Open -- so this page does have to draw again after a profile switch, which
    -- is what SetRenderer's dirty flag delivers: AceDB fires OnProfileChanged / Copied / Reset,
    -- NS.OnProfileChanged calls NS.RefreshOptionsPanel, and Helpers.RefreshAllPanels re-renders
    -- this ctx if it is on screen and marks it dirty for its next show if it is not. So the switch
    -- now also lands while the page is OPEN, which the plain OnShow could never see.
    H.SetRenderer(ctx, function()
        if not container then
            container = AceGUI:Create("SimpleGroup")
            container:SetLayout("Fill")
            container.frame:SetParent(ctx.body)
            container.frame:ClearAllPoints()
            container.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      8, -8)
            container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8, 8)
        end
        AceConfigDialog:Open(APPNAME, container)
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "Profiles")
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage("profiles", "Profiles", build)
end
