-- AbsorbTracker: settings/General.lua
--
-- General sub-page — what `/at config` opens by default. Which bars exist, whether they are locked,
-- whether they only show in combat, how fast they repaint, a Debug console show/hide toggle, and a
-- Reset Position / Reset All Settings button pair.

local addonName, NS = ...

local print = NS.Print

local flatDefaults = NS.flatDefaults

-- TWO TABS (options-ui-§13), and the strip is the schema array's own order:
--
--     [ Bars ][ Behavior ]
--
--     Bars       [Enable Player Bar]   [Enable Target Bar]
--                [Enable Focus Bar]
--                [Reset Position]      [Reset All Settings]   <- inline button pair, afterGroup
--     Behavior   [Lock Position]       [Show only in combat]
--                [Update throttle]     [Debug console]        <- window show/hide, via pairWith
--
-- WHY THIS SPLIT. The page's six rows answer two different questions -- WHICH bars exist, and how
-- the ones that do behave -- and each half is three rows, so neither tab is a drawer. Bars leads
-- because turning a bar on is what a player opens this page for; Behavior is what they set once.
--
-- The three enable toggles now run together instead of being interleaved with the globals one for
-- one. The old interleave (orders 10/15/20/25/30) paired [Enable Player Bar] with [Lock Position]
-- for no reason beyond both being on this page; reading across a line is supposed to compare two
-- answers to one question, and those two were answers to different ones. Three toggles in a row
-- read as the set they are.
--
-- They write `units.<unit>.enabled` -- the same paths `/at set units.target.enabled true` uses --
-- but live here rather than on the Appearance page behind the Unit banner: enabling a bar is a
-- master control, not an appearance choice, and all three visible at once means turning a bar on
-- costs no picker switch.
--
-- [Debug console] shows/hides the debug console window (same as bare /at debug) — it does NOT
-- change the debug logging flag. NOT a schema row (window visibility is transient UI, never
-- persisted); injected through RenderSchema's pairWith seam, which needs its host row to be the
-- LONE widget on its line. It hangs off `throttleWindow`, which is `solo = true` and therefore
-- always alone on its line by construction -- where the old host (Enable Focus Bar) was only alone
-- because the five rows above it happened to pair off as 2 + 2 + 1, an accident any added row would
-- have broken silently. Its get/set lives in NS.DebugLog:ConsoleCheckbox().
--
-- Schema rows below double as the source for `/at list/get/set` on these paths.

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
            -- Honored per-unit even while that unit mirrors the player, so settings/Slash.lua
            -- must not tag `/at get units.focus.enabled` with the "(mirrored)" note. Still load
            -- bearing after the move off the Bar page — that note is keyed off this flag.
            alwaysPerUnit = true,
            group   = "Bars",
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

NS.RegisterSchemaRows({
    {
        path    = "showOnlyInCombat",
        page    = "general",
        group   = "Behavior",
        order   = 20,
        type    = "bool",
        label   = "Show only in combat",
        desc    = "When on, the bar is hidden except while you're in combat.",
        default = flatDefaults.showOnlyInCombat,
        onChange = function()
            NS.bus:SendMessage(NS.MSG.VISIBILITY)
            -- Evaluated per enabled unit, not once for the player. NS.ShouldShowBar defaults its
            -- argument to "player" and returns false as soon as the PLAYER bar is disabled
            -- (modules/Display.lua), so a bare NS.ShouldShowBar() answered a question about one
            -- bar and gated all three: with only the target bar on, toggling this setting
            -- published VISIBILITY — the bar appeared — and then skipped the repaint that fills
            -- it, leaving whatever it last painted on screen until the next absorb event.
            local anyVisible = false
            NS.ForEachUnit(function(unit)
                if NS.ShouldShowBar(unit) then anyVisible = true end
            end)
            if anyVisible then NS.bus:SendMessage(NS.MSG.REPAINT) end
        end,
    },
    {
        path    = "locked",
        page    = "general",
        group   = "Behavior",
        order   = 10,
        type    = "bool",
        label   = "Lock Position",
        desc    = "When locked, the bar can't be dragged.",
        default = flatDefaults.locked,
        onChange = function()
            -- Both directions of the lock end preview mode (preview-mode): re-locking drops any
            -- live `/at test` hold so the bar returns to live data instead of keeping the fake
            -- value, and unlocking drops it too so what the user drags is the placeholder fill.
            -- The APPEARANCE pass is what paints, or stops painting, that placeholder.
            --
            -- Wired here rather than in the lock/unlock verbs because this is the single seam every
            -- writer goes through — the checkbox, `/at lock`, `/at unlock`, `/at set locked` and
            -- the Defaults button all land in NS.SetByPath, which fires this.
            NS.ClearPreview()
            NS.bus:SendMessage(NS.MSG.APPEARANCE)
            NS.bus:SendMessage(NS.MSG.REPAINT)
        end,
    },
    {
        path    = "throttleWindow",
        page    = "general",
        group   = "Behavior",
        order   = 30,
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
    -- THE COLLECTION'S ONE WORDING (options-ui-§12), verbatim. It is deliberately addon-agnostic --
    -- no addon enumerates its own nouns -- and deliberately explicit about the destruction: "reset
    -- settings" does not sound like "throw away what I set up", and an OnAccept that does something
    -- the text did not warn about is how a player loses an evening's work. Eight phrasings of one
    -- act is how a collection reads as eight addons.
    text         = "Reset this profile to the addon's defaults? Everything you have configured or added in it is discarded \226\128\148 your other profiles are not affected.",
    button1      = "Yes",
    button2      = "No",
    timeout      = 0,
    whileDead    = true,
    hideOnEscape = true,
    OnAccept     = function()
        -- The acknowledgment lives INSIDE the guard, for the reason settings/Slash.lua's
        -- runResetAll spells out: on a load where settings/OptionsSetup.lua never ran there is
        -- nothing to delegate to, and printing the ack anyway claims success for work that did not
        -- happen. Same two branches as the slash verb; the wording keeps this popup's trailing
        -- period, which docs/smoke-tests.md step 20 checks for.
        if NS.Helpers and NS.Helpers.RestoreAllDefaults then
            NS.Helpers.RestoreAllDefaults()
            print("All settings reset to defaults.")
        else
            print("Cannot reset settings \226\128\148 the settings helpers failed to load.")
        end
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
        -- RenderTabbedSchema, not RenderSchema: the page's two groups become the strip
        -- (options-ui-§13). Both hook tables key off names the schema owns -- the group for
        -- afterGroup, the row's path for pairWith -- so a rename here that is not made in the rows
        -- above simply stops firing rather than drawing in the wrong place.
        H.RenderTabbedSchema(ctx, "general", {
            ["Bars"] = function(ctxRef)
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
                        -- Names the equivalence rather than restating the popup (options-ui-§12).
                        tooltip = "Start over: reset the active profile to the addon defaults. The same thing Profiles > Reset Profile does. Your other profiles are left alone.",
                        onClick = function() StaticPopup_Show("ABSORBTRACKER_RESET_ALL") end,
                    })
            end,
        }, {
            -- "Debug console" as the throttle slider's right partner: shows/hides the console
            -- window (not a schema row — transient UI); get/set live in DebugLog. The throttle row
            -- is `solo`, so it is alone on its line by construction, which is what the pairWith
            -- seam requires of its host.
            ["throttleWindow"] = function(ctxRef, rowGroup)
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
