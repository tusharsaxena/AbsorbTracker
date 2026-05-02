-- AbsorbTracker: Options/General.lua
--
-- General sub-page — what `/at config` opens by default. Visibility,
-- lock, update interval, plus a Reset Position / Reset All Settings
-- button pair.
--
-- Schema rows below double as the source for `/at list/get/set` on
-- these paths.

local AddonName, AddonTable = ...

local print = AddonTable.Print

local flatDefaults = AddonTable.flatDefaults

-- Master controls layout produces:
--     [Show Bar]              | [Lock Position]
--     [Reset Position]        | [Reset All Settings]   ← inline button pair
-- Performance section produces:
--     [Update Interval (sec)]                          (solo: only one row)

AddonTable.RegisterSchemaRows({
    {
        path    = "hidden",
        page    = "general",
        group   = "Master controls",
        order   = 10,
        type    = "bool",
        label   = "Show Bar",
        desc    = "Toggle the absorb bar on or off.",
        default = flatDefaults.hidden,
        inverse = true,
        onChange = function()
            AddonTable.UpdateBarAppearance()
            if not AddonTable.GetSetting("hidden") then
                AddonTable.lastAbsorb = -1
                AddonTable.UpdateAbsorbBar()
            end
        end,
    },
    {
        path    = "locked",
        page    = "general",
        group   = "Master controls",
        order   = 20,
        type    = "bool",
        label   = "Lock Position",
        desc    = "When locked, the bar can't be dragged.",
        default = flatDefaults.locked,
    },
    {
        path    = "updateInterval",
        page    = "general",
        group   = "Performance",
        order   = 10,
        type    = "number",
        label   = "Update Interval (in sec)",
        desc    = "How often the bar refreshes. Lower = smoother but more CPU.",
        default = flatDefaults.updateInterval,
        min = 0.1, max = 10, step = 0.1, fmt = "%.1f sec",
        solo    = true,
        onChange = function() AddonTable.RestartUpdateTicker() end,
    },
})

-- StaticPopup for "Reset All Settings" — irreversible, so confirm
-- before wiping. The OnAccept body shares the helper with /at resetall
-- so the popup and the slash never diverge.
StaticPopupDialogs["ABSORBTRACKER_RESET_ALL"] = {
    text         = "Reset every General, Bar, Border, and Font setting on this profile to defaults? Profiles are left alone.",
    button1      = "Yes",
    button2      = "No",
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function()
        if AddonTable.Helpers and AddonTable.Helpers.RestoreAllDefaults then
            AddonTable.Helpers.RestoreAllDefaults()
        end
        print("All settings reset to defaults.")
    end,
}

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local H   = AddonTable.Helpers
    local ctx = H.CreatePanel("AbsorbTrackerGeneralPanel", "General", {
        pageKey         = "general",
        defaultsButton  = true,
        defaultsTooltip = "Restore every General setting on this profile to its addon default.",
    })
    if ctx.panel.defaultsBtn then
        ctx.panel.defaultsBtn:SetCallback("OnClick", function()
            H.RestoreDefaults("general", ctx)
        end)
    end

    -- Defer the AceGUI render until the panel becomes visible: build
    -- happens at PLAYER_LOGIN when ctx.body has 0 width, and AceGUI
    -- lays children out against the container's current width.
    local rendered = false
    ctx.panel:SetScript("OnShow", function()
        if rendered then return end
        rendered = true
        H.RenderSchema(ctx, "general", {
            ["Master controls"] = function(ctxRef)
                H.InlineButtonPair(ctxRef,
                    {
                        text    = "Reset Position",
                        tooltip = "Move the bar back to the screen center.",
                        onClick = function()
                            if AddonTable.db and AddonTable.db.profile then
                                AddonTable.db.profile.position = nil
                            end
                            if AddonTable.RestoreBarPosition then
                                AddonTable.RestoreBarPosition()
                            end
                        end,
                    },
                    {
                        text    = "Reset All Settings",
                        tooltip = "Reset every General, Bar, Border, and Font setting on this profile to defaults.",
                        onClick = function() StaticPopup_Show("ABSORBTRACKER_RESET_ALL") end,
                    })
            end,
        })
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "General")
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("general", "General", build, { isDefault = true })
end
