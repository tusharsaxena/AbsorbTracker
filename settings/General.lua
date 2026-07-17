-- AbsorbTracker: settings/General.lua
--
-- General sub-page — what `/at config` opens by default. Visibility,
-- show-only-in-combat, lock, update throttle, plus a Reset Position /
-- Reset All Settings button pair.
--
-- Schema rows below double as the source for `/at list/get/set` on
-- these paths.

local addonName, NS = ...

local print = NS.Print

local flatDefaults = NS.flatDefaults

-- Master controls layout produces:
--     [Show Bar]              | [Show only in combat]
--     [Lock Position]                                  (odd row-out, alone)
--     [Reset Position]        | [Reset All Settings]   ← inline button pair
-- Performance section produces:
--     [Update throttle (sec)]                          (solo: only one row)

NS.RegisterSchemaRows({
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
            NS.UpdateBarAppearance()
            if not NS.GetSetting("hidden") then
                NS.UpdateAbsorbBar()
            end
        end,
    },
    {
        path    = "showOnlyInCombat",
        page    = "general",
        group   = "Master controls",
        order   = 15,
        type    = "bool",
        label   = "Show only in combat",
        desc    = "When on, the bar is hidden except while you're in combat.",
        default = flatDefaults.showOnlyInCombat,
        onChange = function()
            NS.ApplyVisibility()
            if NS.ShouldShowBar() then NS.UpdateAbsorbBar() end
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
        path    = "throttleWindow",
        page    = "general",
        group   = "Performance",
        order   = 10,
        type    = "number",
        label   = "Update throttle (in sec)",
        desc    = "Fastest the bar repaints during a burst of changes. Lower = snappier but more CPU.",
        default = flatDefaults.throttleWindow,
        min = 0.05, max = 1, step = 0.05, fmt = "%.2f sec",
        solo    = true,
    },
})

-- StaticPopup for "Reset All Settings" — irreversible, so confirm
-- before wiping. The OnAccept body calls NS.Helpers.RestoreAllDefaults,
-- the same helper /at resetall calls, so the popup and the slash never
-- diverge (they historically differed on whether position was cleared).
StaticPopupDialogs["ABSORBTRACKER_RESET_ALL"] = {
    text         = "Reset every General, Bar, Border, and Font setting on this profile to defaults and recenter the bar? Profiles are left alone.",
    button1      = "Yes",
    button2      = "No",
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function()
        if NS.Helpers and NS.Helpers.RestoreAllDefaults then
            NS.Helpers.RestoreAllDefaults()
        end
        print("All settings reset to defaults.")
    end,
}

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local H   = NS.Helpers
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
                            if NS.db and NS.db.profile then
                                NS.db.profile.position = nil
                            end
                            if NS.RestoreBarPosition then
                                NS.RestoreBarPosition()
                            end
                        end,
                    },
                    {
                        text    = "Reset All Settings",
                        tooltip = "Reset every General, Bar, Border, and Font setting on this profile to defaults and recenter the bar.",
                        onClick = function() StaticPopup_Show("ABSORBTRACKER_RESET_ALL") end,
                    })
            end,
        })
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "General")
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage("general", "General", build)
end
