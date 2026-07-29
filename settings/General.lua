-- AbsorbTracker: settings/General.lua
--
-- General sub-page — what `/at config` opens by default. Visibility,
-- show-only-in-combat, lock, a Debug console show/hide toggle, update
-- throttle, plus a Reset Position / Reset All Settings button pair.
--
-- Schema rows below double as the source for `/at list/get/set` on
-- these paths.

local addonName, NS = ...

local print = NS.Print

local flatDefaults = NS.flatDefaults

-- Master controls layout produces:
--     [Enable Player Bar]     | [Lock Position]
--     [Enable Target Bar]     | [Show only in combat]
--     [Enable Focus Bar]      | [Debug console]        ← window show/hide, via pairWith
--     [Reset Position]        | [Reset All Settings]   ← inline button pair
-- Performance section produces:
--     [Update throttle (sec)]                          (solo: only one row)
--
-- The LEFT column is the per-unit enable toggles — the primary control on this page, since there
-- is no master "Show Bar" any more. They write `units.<unit>.enabled` (the same paths
-- `/at set units.target.enabled true` uses) but live here rather than behind the Bar page's Unit
-- dropdown: enabling a bar is a master control, not an appearance choice, and all three visible
-- at once means turning a bar on costs no dropdown switch.
--
-- Interleaved orders (10/15/20/25/30) are what pair each enable toggle with a global on the same
-- line; RenderRows fills left-then-right in schema order, so changing one order re-columns the
-- whole group. tests/test_widgets.lua asserts the three pairs by label.
--
-- [Debug console] shows/hides the debug console window (same as bare /at debug) — it does NOT
-- change the debug logging flag. NOT a schema row (window visibility is transient UI, never
-- persisted); injected as Enable Focus Bar's right partner through RenderSchema's pairWith seam,
-- which needs it to be the lone widget on its row — true only because the five schema rows above
-- pair off as 2 + 2 + 1. Its get/set lives in NS.DebugLog:ConsoleCheckbox().

NS.RegisterSchemaRows({
    {
        path    = "showOnlyInCombat",
        page    = "general",
        group   = "Master controls",
        order   = 25,
        type    = "bool",
        label   = "Show only in combat",
        desc    = "When on, the bar is hidden except while you're in combat.",
        default = flatDefaults.showOnlyInCombat,
        onChange = function()
            NS.bus:SendMessage(NS.MSG.VISIBILITY)
            if NS.ShouldShowBar() then NS.bus:SendMessage(NS.MSG.REPAINT) end
        end,
    },
    {
        path    = "locked",
        page    = "general",
        group   = "Master controls",
        order   = 15,
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

-- Per-unit enable toggles, one per NS.Units.LIST entry, generated so adding a fourth tracked unit
-- needs no edit here. Orders 10 / 20 / 30 interleave with the globals above (15 / 25) to fill the
-- LEFT column. Each row keeps its `unit` tag: the General page renders with ctx.unit nil, and
-- SchemaForPage(page, nil) returns every unit's rows, so the tag is inert here — it is kept so the
-- row is still identifiable as per-unit by anything walking the schema.
--
-- These are the only visibility switch the addon has; `onChange` therefore also re-syncs the
-- per-unit event registrations (core/AbsorbTracker.lua), so a disabled unit costs no event
-- dispatch at all.
for i, unit in ipairs(NS.Units.LIST) do
    NS.RegisterSchemaRows({
        {
            path    = "units." .. unit .. ".enabled",
            page    = "general",
            unit    = unit,
            -- Honoured per-unit even while that unit mirrors the player, so settings/Slash.lua
            -- must not tag `/at get units.focus.enabled` with the "(mirrored)" note. Still load
            -- bearing after the move off the Bar page — that note is keyed off this flag.
            alwaysPerUnit = true,
            group   = "Master controls",
            order   = i * 10,
            type    = "bool",
            label   = "Enable " .. NS.Units.LABEL[unit] .. " Bar",
            desc    = ("Track and display absorbs on your %s. Target and focus bars additionally "
                .. "need that unit to exist before they appear."):format(NS.Units.LABEL[unit]:lower()),
            default = (unit == "player"),
            onChange = function()
                -- UNITS first: it re-syncs the event registrations, so a unit that was just
                -- enabled is already listening by the time the repaint below lands.
                NS.bus:SendMessage(NS.MSG.UNITS)
                NS.bus:SendMessage(NS.MSG.APPEARANCE)
                -- Only when the bar is now ON. A bar being turned off needs no paint work, and
                -- one that was just turned on is still holding whatever value it had when it went
                -- away — the repaint is what makes it current. Reads live state rather than the
                -- onChange argument so `/at set`, the checkbox and ApplyDefault all behave alike.
                if NS.Units.IsEnabled(unit) then
                    NS.bus:SendMessage(NS.MSG.REPAINT)
                end
            end,
        },
    })
end

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
    -- Parked, not wired: the Defaults button does not exist yet — it is built
    -- on first OnShow (see Helpers.EnsureDefaultsButton).
    ctx.panel.defaultsOnClick = function()
        H.RestoreDefaults("general", ctx)
    end

    -- Defer the AceGUI render until the panel becomes visible: build
    -- happens at PLAYER_LOGIN when ctx.body has 0 width, and AceGUI
    -- lays children out against the container's current width.
    local rendered = false
    ctx.panel:SetScript("OnShow", function()
        H.EnsureDefaultsButton(ctx.panel)
        if rendered then return end
        rendered = true
        H.RenderSchema(ctx, "general", {
            ["Master controls"] = function(ctxRef)
                H.InlineButtonPair(ctxRef,
                    {
                        text    = "Reset Position",
                        tooltip = "Move every bar back to its default position.",
                        -- Same shared helper `/at resetposition` calls, so the button and the
                        -- slash verb can never diverge. They did once: this body used to nil
                        -- `db.profile.position`, the pre-v3 flat key the v3 migration deletes,
                        -- which made the button a silent no-op (see Helpers.ResetAllPositions).
                        onClick = function() H.ResetAllPositions() end,
                    },
                    {
                        text    = "Reset All Settings",
                        tooltip = "Reset every General, Bar, Border, and Font setting on this profile to defaults and recenter the bar.",
                        onClick = function() StaticPopup_Show("ABSORBTRACKER_RESET_ALL") end,
                    })
            end,
        }, {
            -- "Debug console" as Enable Focus Bar's right partner: shows/hides the console window
            -- (not a schema row — transient UI); get/set live in DebugLog.
            ["units.focus.enabled"] = function(ctxRef, rowGroup)
                if NS.DebugLog and NS.DebugLog.ConsoleCheckbox then
                    H.SessionCheckbox(ctxRef, rowGroup, 0.5, NS.DebugLog:ConsoleCheckbox())
                end
            end,
        })
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "General")
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage("general", "General", build)
end
