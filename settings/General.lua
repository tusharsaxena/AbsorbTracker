-- AbsorbTracker: settings/General.lua
--
-- General sub-page — what `/at config` opens by default. The addon-wide controls, which bars exist,
-- and how the ones that do behave.

local _, NS = ...

local print = NS.Print

local flatDefaults = NS.flatDefaults

local H = NS.Helpers

-- TWO TABS (options-ui-§13), and the strip is the schema array's own order:
--
--     [ Master controls ][ Bars ]
--
--     Master controls  [Enable Absorb Tracker]  [General visibility]
--                      [Master scale]           [Master alpha]
--                      [Lock frame]             [Debug console]
--                      [Test mode]                                     <- own line, startsLine
--                      [Reset position]         [Reset all settings]   <- button pair, afterGroup
--     Bars             -- Tracked units --                             <- subgroup, options-ui-§7
--                      [Enable Player Bar]      [Enable Target Bar]
--                      [Enable Focus Bar]
--                      -- Updates --
--                      [Update throttle]
--
-- THERE IS NO `Behavior` TAB ANY MORE, and it is the move of `locked` that ended it rather than a
-- redesign. Behavior held lock, the combat gate and the throttle; lock is canonical and belongs on
-- Master controls, the combat gate became the `visibility` dropdown there, and what was left was
-- one slider. A tab holding one control is not a subject, it is a click that reveals one widget, so
-- the throttle merged into the tab whose subject contains it -- which bars exist and how they
-- behave -- and the merged tab carries a subsection heading per kind, which is exactly what
-- options-ui-§7 asks of a tab that mixes them. Neither heading repeats the tab's own name, which
-- that rule forbids outright.
--
-- MASTER CONTROLS LEADS, AND IS NOT OPTIONAL (options-ui-§15). The one thing every player looks for
-- first -- how do I turn this off, how do I make it smaller, how do I put it back -- is in the same
-- place, under the same words, in every Ka0s addon. The set is canonical rather than a menu: it may
-- not be reordered, renamed or split, and this addon draws all nine rows because it HAS a movable
-- frame (modules/Bar.lua calls SetMovable(true) on every bar), so nothing is omitted. That includes
-- Test mode: every addon with a positionable display ships one (preview-mode).
--
-- IT IS COMPOSED, NEVER TYPED OUT. H.MasterControls emits the nine from one declaration, so nine
-- addons cannot drift into nine orders; hand-writing the block is anti-pattern #73. What this file
-- supplies is the part that is genuinely ours -- the defaults each row starts from and the
-- `onChange` each one fires.
--
-- WHAT MOVED HERE, AND IS THEREFORE GONE FROM WHERE IT WAS. Two controls over one setting is the
-- failure this pass exists to remove, so each of these has exactly ONE declaration now:
--
--   * `locked`             was the Behavior tab's "Lock Position"
--   * `state.debugConsole` was a bespoke SessionCheckbox hung off the throttle row through the
--                          `pairWith` seam. The console itself is untouched -- only how the toggle
--                          is DECLARED changed, and it is a schema row now, so `/at get` and
--                          `/at set` can reach it where before no CLI verb could.
--   * Reset position       were the Bars tab's afterGroup button pair
--   * Reset all settings
--
-- WHAT IS NEW. `enabled`, `visibility`, `scale` and `alpha` did not exist. `visibility` REPLACES the
-- old `showOnlyInCombat` boolean, which could only ever answer two of the dropdown's four states;
-- that is a stored-value type change and so takes a migration (core/Database.lua's v5) in the same
-- change as the row.
--
-- WHAT DID NOT MOVE. The per-unit `barAlpha` on the Appearance page is NOT Master alpha
-- (options-ui-§15 forbids conflating an addon-wide row with a per-instance one): one dims all three
-- bars, the other dims one, and NS.GetBarAlpha multiplies them. Nor are the three per-unit `enabled`
-- toggles the addon-wide `Enable` row -- they are which bars exist, and they stay on the Bars tab.
--
-- Schema rows below double as the source for `/at list/get/set` on these paths.

-- The console toggle's stored path, VERBATIM and unprefixed: session state lives outside the
-- block's own prefix, and this is the literal the composer defaults to. Named once because the
-- registration below has to spell the same string.
-- Re-entrancy guard for the in-combat unlock refusal in the `locked` onChange below: the corrective
-- NS.SetByPath fires that same onChange, which would test the combat condition again and recurse.
local unlockGuard = false

local DEBUG_CONSOLE_PATH = "state.debugConsole"

-- Bind that path to the console WINDOW's own show/hide state rather than to the profile
-- (options-ui-§15: the row is session-only, and a console left open is not a setting the next
-- character inherits). `ConsoleCheckbox` is the `{ label, tooltip, get, set }` pair
-- LibKa0s-DebugLog already answers for exactly this, and BOTH arms of core/DebugLogSetup.lua
-- publish it -- so a library-less build gets an honest toggle rather than a row wired to nothing.
if NS.DebugLog and NS.DebugLog.ConsoleCheckbox then
    NS.RegisterSessionSetting(DEBUG_CONSOLE_PATH, NS.DebugLog:ConsoleCheckbox())
end

-- The canonical block. `defaults` names this addon's own starting values without changing any
-- stored path: every leaf here already IS the path the composer derives, so `keys` is unnecessary
-- and nothing about what is stored moves.
local masterRows, masterTail = H.MasterControls({
    prefix           = "",
    page             = "general",
    addonName        = "Absorb Tracker",
    -- Not frameless: the bars are movable, so master scale, master alpha, lock frame and reset
    -- position all apply. Stated rather than left to the default, because `frameless` is the one
    -- field that silently REMOVES four mandated rows.
    frameless        = false,
    debugConsolePath = DEBUG_CONSOLE_PATH,
    -- The minimap button's row (launcher-§3, compose minor 7). Parallel to the console path and
    -- taken just as VERBATIM, and for a related but distinct reason: the console's value is session
    -- state and this one is stored, but BOTH live outside the block's own profile prefix -- this one
    -- in the GLOBAL store, because a button is furniture the player arranged once and a profile
    -- switch must not move it (core/Constants.lua).
    --
    -- The row is unconditional and carries `default = true`, its own SHOWN sense; the composer
    -- emits it wherever this key is present. This addon declares no `testModePath` (the lock is its
    -- preview), so the fourth line of the canonical set renders as [Minimap button] alone.
    minimapPath      = NS.Constants.MINIMAP_PATH,
    defaults         = {
        enabled    = flatDefaults.enabled,
        visibility = flatDefaults.visibility,
        scale      = flatDefaults.scale,
        alpha      = flatDefaults.alpha,
        locked     = flatDefaults.locked,
    },
    -- The same shared helper `/at resetposition` calls, so the button and the slash verb can never
    -- diverge. They did once: the old body nil'd `db.profile.position`, the pre-v3 flat key the v3
    -- migration deletes, which made the button a silent no-op (see Helpers.ResetAllPositions).
    -- Resolved at CLICK time, not captured: settings/UnitPanel.lua decorates the helper onto the
    -- instance AFTER this file loads, and tests/test_helpers.lua swaps it out to spy on it.
    onResetPosition  = function() NS.Helpers.ResetAllPositions() end,
    -- options-ui-§12's global reset, through the confirmation the act has always carried.
    onResetAll       = function() StaticPopup_Show("ABSORBTRACKER_RESET_ALL") end,
})

-- The composer emits DATA; `onChange` is the host's half and is attached here. Keyed by PATH rather
-- than by index, so a change to the canonical order upstream cannot silently move a handler onto
-- the wrong row -- it would simply stop firing, which is visible.
local masterOnChange = {
    -- THE ADDON-WIDE SWITCH, AND IT IS NOT A DRAW GATE. It used to be exactly that: publish
    -- VISIBILITY, let ShouldShowBar's second rung answer no, and leave every registration live on
    -- an addon the player had switched off. slash-commands-§7 calls that shape what it is -- the
    -- addon did not stop watching, it stopped reacting, and it still paid the dispatch on every
    -- UNIT_ABSORB_AMOUNT_CHANGED the client sent it.
    --
    -- ONE LINE NOW, and it is the same line the two verbs, `/at set enabled`, a Defaults press and
    -- a profile switch all reach, because they all land in this seam. NS.SyncEnabledHold re-reads
    -- the STORE and moves the `disabled` hold on the one latch (core/Lifecycle.lua); the latch
    -- calls StandDown or StandUp on the edge, and the stand-down publishes VISIBILITY itself before
    -- it takes the bus down. Publishing here as well would be a second pass, and on the way UP it
    -- would fire onto a bus that has not been resubscribed yet.
    ["enabled"] = function() NS.SyncEnabledHold() end,

    ["visibility"] = function()
        NS.bus:SendMessage(NS.MSG.VISIBILITY)
        -- Evaluated per enabled unit, not once for the player. NS.ShouldShowBar defaults its
        -- argument to "player" and returns false as soon as the PLAYER bar is disabled
        -- (modules/Display.lua), so a bare NS.ShouldShowBar() answered a question about one bar and
        -- gated all three: with only the target bar on, changing this setting published VISIBILITY
        -- -- the bar appeared -- and then skipped the repaint that fills it, leaving whatever it
        -- last painted on screen until the next absorb event.
        local anyVisible = false
        NS.ForEachUnit(function(unit)
            if NS.ShouldShowBar(unit) then anyVisible = true end
        end)
        if anyVisible then NS.bus:SendMessage(NS.MSG.REPAINT) end
    end,

    -- Both multipliers are read inside the appearance pass (modules/Display.lua), so the ordinary
    -- restyle broadcast is all either needs.
    ["scale"] = function() NS.bus:SendMessage(NS.MSG.APPEARANCE) end,
    ["alpha"] = function() NS.bus:SendMessage(NS.MSG.APPEARANCE) end,

    ["locked"] = function()
        -- THE ONE PREVIEW SWITCH (options-ui-§15). This addon ships no Test mode row: unlocking
        -- already paints the placeholder, and since the visibility and unit-exists rungs of
        -- NS.ShouldShowBar moved onto the lock, unlocking also shows a target or focus bar with
        -- nothing targeted — which is the whole of what the removed row did. Two switches for one
        -- state was the finding (anti-pattern #80).
        --
        -- UNLOCKING IS REFUSED IN COMBAT. That refusal came off the removed row, which would not
        -- start in a fight because combat ended it the moment it began; combat now re-locks
        -- (core/AbsorbTracker.lua), so the same reasoning lands here. Re-LOCKING is always allowed,
        -- so this can never strand a player unlocked mid-fight. Enforced at the onChange rather
        -- than in the verbs because this is the single seam every writer goes through, and
        -- `unlockGuard` stops the corrective write re-entering it.
        if not NS.GetSetting("locked") and not unlockGuard
           and (UnitAffectingCombat("player") or InCombatLockdown()) then
            unlockGuard = true
            NS.SetByPath("locked", true)
            unlockGuard = false
            print("Cannot unlock the bars during combat")
            if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
            return
        end

        -- Both directions of the lock end preview mode (preview-mode): re-locking drops any live
        -- `/at test <value>` hold so the bar returns to live data instead of keeping the fake
        -- value, and unlocking drops it too so what the user drags is the placeholder fill. The
        -- APPEARANCE pass is what paints, or stops painting, that placeholder — and it re-runs the
        -- visibility ladder itself (NS.UpdateBarAppearance calls NS.ApplyVisibility), which is why
        -- no separate VISIBILITY publish is needed even though the lock now decides which bars show.
        --
        -- Wired here rather than in the lock/unlock verbs because this is the single seam every
        -- writer goes through — the checkbox, `/at lock`, `/at unlock`, `/at set locked`,
        -- `/at reset locked` and the Defaults button all land in NS.SetByPath (the two resets by
        -- way of NS.ApplyDefault), which fires this. A profile switch or reset does not write the
        -- row, so it does not fire this; NS.OnProfileChanged repaints.
        NS.ClearPreview()
        NS.bus:SendMessage(NS.MSG.APPEARANCE)
        NS.bus:SendMessage(NS.MSG.REPAINT)
    end,

    -- EXPLICITLY NOTHING, and that is the whole content of this entry. Without it the row falls
    -- through to settings/Schema.lua's `defaultOnChange`, which publishes APPEARANCE -- a full
    -- three-bar restyle costing 48 WoW API calls and 384.5 bytes per pass (tests/perf.lua's
    -- `appearancePass`, measured 2026-09-08) for a checkbox that only shows and hides a window.
    -- The console's own visibility is the ConsoleCheckbox's `set`, registered above as a session
    -- setting; nothing about a bar depends on it.
    --
    -- Written as a declared no-op rather than by changing `defaultOnChange`: APPEARANCE is the
    -- right default for the appearance rows, which are the overwhelming majority. A row that
    -- deliberately publishes nothing has to SAY so, or the next reader reads the absence as an
    -- oversight and "fixes" it back.
    [DEBUG_CONSOLE_PATH] = function() end,

    -- EXPLICITLY NOTHING, for the same reason and with the same cost avoided: a checkbox that shows
    -- and hides a minimap button has no business restyling three bars. The button itself is moved
    -- by the `set` side of core/Data.lua's seam, which calls NS.Launcher:SetShown -- so this is not
    -- a handler that was forgotten, it is one that would have nothing left to do.
    [NS.Constants.MINIMAP_PATH] = function() end,

}

for _, row in ipairs(masterRows) do
    local fn = masterOnChange[row.path]
    if fn then row.onChange = fn end
end

NS.RegisterSchemaRows(masterRows)

-- Per-unit enable toggles, one per NS.Units.LIST entry, generated so adding a fourth tracked unit
-- needs no edit here. Each row keeps its `unit` tag: the General page renders with ctx.unit nil, and
-- SchemaForPage(page, nil) returns every unit's rows, so the tag is inert here — it is kept so the
-- row is still identifiable as per-unit by anything walking the schema.
--
-- These are the per-BAR visibility switch, a different setting from the Master controls tab's
-- addon-wide `enabled`; `onChange` therefore also re-syncs the per-unit event registrations
-- (core/AbsorbTracker.lua), so a disabled unit costs no event dispatch at all.
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
            group    = "Bars",
            subgroup = "Tracked units",
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
        -- The last row of the old Behavior tab, under its own subsection heading on Bars. See the
        -- note at the head of this file for why the tab it used to share is gone.
        --
        -- `solo` went with the bespoke debug-console checkbox it existed for: this row HOSTED that
        -- checkbox through the `pairWith` seam, which needs its host to be alone on its line.
        -- Nothing pairs with it now, and a subsection heading already breaks the line before it, so
        -- declaring the layout by hand would state a fact the flow engine produces.
        path     = "throttleWindow",
        page     = "general",
        group    = "Bars",
        subgroup = "Updates",
        order    = 40,
        type    = "number",
        label   = "Update throttle (in sec)",
        desc    = "Fastest the bar repaints during a burst of changes. Lower = snappier but more CPU.",
        default = flatDefaults.throttleWindow,
        min = 0.05, max = 1, step = 0.05, fmt = "%.2f sec",
        -- Same declared no-op, same reason, and here the cost is per SLIDER STEP: a drag from 0.05
        -- to 1 is nineteen restyles of three bars. Nothing needs republishing either -- the next
        -- arm reads the value fresh (`NS.GetSetting("throttleWindow")` at modules/Timer.lua's
        -- ScheduleTimer call), so a window already in flight finishes on the old value and every
        -- window after it uses the new one, which is what a throttle change should do.
        onChange = function() end,
    },
})

-- StaticPopup for "Reset all settings" — irreversible, so confirm
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

    -- Declared THROUGH SetRenderer rather than a hand-wired OnShow, and the combat refusal is the
    -- whole reason (options-ui-§11). The Blizzard AddOns sidebar reaches a canvas directly, never
    -- through OpenOptionsPanel, so the gate docs/settings-panel.md describes covered `/at config`
    -- and a `/run` caller and missed the one path a player is most likely to take mid-pull.
    -- SetRenderer's OnShow builds the Defaults button, refuses under InCombatLockdown and closes
    -- the Settings window, and only then renders -- so the refusal arrives by adopting the library
    -- rather than by this file growing a second copy of it.
    --
    -- The deferral the old comment here explained is still why the body is not drawn in the
    -- builder: ctx.body has zero width at PLAYER_LOGIN and AceGUI lays children out against the
    -- container's current width. SetRenderer defers to first show for exactly that reason, and for
    -- the skinning race EnsureDefaultsButton documents.
    --
    -- The `rendered` one-shot flag that used to guard this is gone because SetRenderer owns WHEN:
    -- first show draws, and a page marked dirty while hidden draws again on its next show. That
    -- second draw is newly reachable, so ClearScroll leads the body -- RenderTabbedSchema appends
    -- to the scroll, and appending twice is how a page grows two of every control.
    H.SetRenderer(ctx, function(c)
        H.ClearScroll(c)
        -- RenderTabbedSchema, not RenderSchema: the page's two groups become the strip
        -- (options-ui-§13). THE GROUP NAME IS THE HOOK KEY -- H.MASTER_GROUP is both the literal
        -- the composer filed its rows under and the tab's label, so it is read off the instance
        -- rather than spelled again here. A rename reaching only one of the two would detach the
        -- button pair, and nothing would error.
        --
        -- No `pairWith` any more: its one user was the bespoke debug-console checkbox, which is a
        -- schema row on the Master controls tab now.
        H.RenderTabbedSchema(c, "general", { [H.MASTER_GROUP] = masterTail })
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "General")
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage("general", "General", build)
end
