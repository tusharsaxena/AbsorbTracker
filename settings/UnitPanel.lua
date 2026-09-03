-- AbsorbTracker: settings/UnitPanel.lua
--
-- The two pieces of the old settings/Helpers.lua that are genuinely this addon's and did not go
-- upstream: the Appearance page (the chrome block holding the Unit picker and the mirror controls,
-- the tab strip over the unit's own groups, and the two-tier refresher that keeps them honest) and
-- the single reset-position implementation.
--
-- Neither generalizes. RenderUnitPanel reads NS.Units and the mirror partition, which no other Ka0s
-- addon has; ResetAllPositions clears a per-unit saved frame position, which is this addon's data
-- model. Everything they stand on — ClearScroll, EnsureScroll, RenderGrid, RenderRows, PageHeader,
-- TabStrip, AttachTooltip — is LibKa0s-Options-1.0's, reached through the same NS.Helpers table, which IS the library instance
-- (settings/OptionsSetup.lua). Decorating it rather than sitting beside it is what lets a page file
-- call H.RenderUnitPanel and H.RenderSchema without knowing or caring which is which.

local addonName, NS = ...

local Helpers = NS.Helpers

-- ---------------------------------------------------------------------
-- Reset position
-- ---------------------------------------------------------------------

-- Clear EVERY unit's saved position and republish POSITION so all three bars re-anchor to their
-- stacked defaults. This is the single "reset position" implementation: `/at resetposition`
-- (settings/Slash.lua), the General page's "Reset Position" button (settings/General.lua) and the
-- descriptor's afterRestoreAll hook (settings/OptionsSetup.lua) all call it, so the CLI, the panel
-- and Reset All can never diverge.
--
-- They diverged here once already: the panel button nil'd `db.profile.position`, the pre-v3 FLAT
-- key that the v3 migration DELETES, so the assignment cleared an already-nil key and the POSITION
-- publish re-anchored every bar from its untouched NS.Units.Position. The button was a silent
-- no-op. Do not re-inline the loop at any call site.
function Helpers.ResetAllPositions()
    for _, unit in ipairs(NS.Units.LIST) do
        NS.Units.SetPosition(unit, nil)
    end
    NS.bus:SendMessage(NS.MSG.POSITION)
end

-- ---------------------------------------------------------------------
-- Appearance page rendering — the chrome block, the tab strip, the rows
-- ---------------------------------------------------------------------

--- Render the per-unit Appearance page: the page's one chrome block, the tab strip, then the
--- selected tab's rows.
---
--- TWO BANDS, top to bottom, and both are drawn on EVERY render:
---
---   1. THE CHROME BLOCK (chrome, options-ui-§14) -- always, and there is exactly ONE of it. It
---      holds everything that applies to the page AS A WHOLE: the Unit picker, plus -- for target
---      and focus -- the "Use same styling as Player" checkbox and the "Copy styling from Player"
---      button.
---
---      H.PageHeader, not H.PageBanner, and that is the RULE rather than a preference. §14 puts
---      page-wide controls in this band, "above the strip -- never in the scroll below it", and
---      names copy among the acts it covers. Both mirror controls govern all five tabs: mirroring
---      replaces every tab's rows with the hint below, and CopyFromPlayer copies every appearance
---      key on every one of them. Drawn in the SCROLL they read as belonging to whichever tab
---      happens to be selected and vanish on the next click -- which is the exact failure §14
---      describes, and what this page did while the mirror header went through RenderGrid.
---
---      A page draws AT MOST ONE such block: PageHeader and PageBanner release the same ledger and
---      write the same ctx.__bannerHeight, so a second call replaces the first rather than stacking
---      a second band. So the picker is built INSIDE this frame and PageBanner is not called at all
---      -- §14's own instruction for a page that needs a picker and other page-wide controls.
---
---      Neither mirror control is a schema row and neither can be: neither has a path, which is why
---      the mirror flag's own row carries `skipRender`. That is the case options-ui-§13 exempts from
---      its two-controls-per-tab rule -- and it says nothing about which BAND they are drawn in,
---      which is §14's question and was answered wrongly here once already.
---
---      The picker is the panel's ONLY unit picker: the three pages this one replaced each drew
---      their own into their own scroll, so styling one bar meant picking the same unit three times
---      over three copies of one piece of state.
---
---   2. THE TAB STRIP (chrome, options-ui-§13) plus the active tab's content -- ALWAYS, including
---      for a mirrored unit. It used to be skipped there, on the argument that a mirrored unit has
---      five tabs of nothing to click through. That argument was answered the wrong way round:
---      options-ui-§13 makes the strip a property of the page rather than of its state, so a page
---      that loses its chrome for one state is the page that looks broken, and there is no exemption
---      for it to claim -- the two exemptions are pages this engine never renders at all. So the
---      strip is drawn under the block and unconditionally, and the mirrored state is CONTENT
---      INSIDE the page: a one-line hint, under the strip where the rows would be.
---
--- The strip is drawn with H.TabStrip directly rather than through H.RenderTabbedSchema, for the
--- reason MultiMeters' Columns page gives for the same choice: RenderTabbedSchema owns the whole
--- page body -- it renders the active group's rows and nothing else, and its tab click is a
--- ClearScroll plus a re-render of ITSELF. This page substitutes a hint for those rows whenever the
--- unit is mirrored, which is a body RenderTabbedSchema has no way to draw and its tab click would
--- overwrite. A tab click here re-renders the whole page instead, which is the same path the Unit
--- picker and the mirror checkbox already take.
---
--- Full rebuild on every call rather than a persistent header widget: AceGUI's widget pool exists
--- exactly to make release-and-recreate cheap, so each call clears ctx.scroll and rebuilds.
---
--- The body is a private local so the public entry point below can pcall it — see the re-entrancy
--- guard there. Call Helpers.RenderUnitPanel, never this.

--- The page's tabs, in strip order: one per distinct `group` among the unit's rows, in the order
--- the rows were registered (settings/Appearance.lua's array IS the strip). Derived rather than
--- listed, for the reason options-ui-§13 gives against a second selector: a tab list declared apart
--- from the rows goes stale the first time a section is renamed and nothing says so.
---
--- `skipRender` rows are EXCLUDED, and that exclusion is what lets every row on this page carry a
--- `group` (options-ui-§13) without the mirror flag becoming a tab of its own holding one invisible
--- widget. Its `group` names its subject for anything walking the schema; its widget is the bespoke
--- mirror checkbox, which is drawn in the page's chrome block above the strip and belongs to no tab.
--- @return table  group names in declaration order
--- @return table  { [group] = { row, ... } }
local function partitionTabs(rows)
    local order, byGroup = {}, {}
    for _, row in ipairs(rows) do
        if row.group and not row.skipRender then
            if not byGroup[row.group] then
                byGroup[row.group] = {}
                order[#order + 1] = row.group
            end
            local bucket = byGroup[row.group]
            bucket[#bucket + 1] = row
        end
    end
    return order, byGroup
end
Helpers.__partitionTabs = partitionTabs

-- The chrome block's own arithmetic.
--
-- BANNER_H and ROW_VSPACER are the LIBRARY's numbers, read off the instance rather than restated
-- here (a host copy of a library constant is the copy that goes stale). CONTROL_H and PAIR_GAP are
-- not the library's to publish: its flow engine sizes a row through AceGUI's own layout and never
-- has to know either number, while a raw frame anchored by its two top corners does.
--
--   CONTROL_H -- AceGUI's own CheckBox and Button frame height.
--   PAIR_GAP  -- half the gutter between the two halves of a paired row. The flow engine states the
--                same split as BUTTON_PAIR_REL (0.492 a side), which is a RELATIVE width and cannot
--                be applied to a frame anchored to its parent's TOP.
local CONTROL_H = 24
local PAIR_GAP  = 4

--- How tall the page's one chrome block is, before the library widens it by the divider band.
--- @return number
local function chromeBlockHeight(unit)
    if unit == "player" then return Helpers.BANNER_H end
    return Helpers.BANNER_H + Helpers.ROW_VSPACER + CONTROL_H
end

--- Anchor one AceGUI widget's frame inside the block. `half` is "LEFT", "RIGHT", or nil for the
--- full width. This is the same reparent-and-anchor the library's own PageBanner does with its
--- dropdown; what a host draws INSIDE the frame PageHeader hands it is the host's to place.
local function place(widget, frame, y, height, half)
    local f = widget and widget.frame
    if not f then return end
    f:SetParent(frame)
    f:ClearAllPoints()
    if half == "LEFT" then
        f:SetPoint("TOPLEFT",  frame, "TOPLEFT", 0, -y)
        f:SetPoint("TOPRIGHT", frame, "TOP",     -PAIR_GAP, -y)
    elseif half == "RIGHT" then
        f:SetPoint("TOPLEFT",  frame, "TOP",      PAIR_GAP, -y)
        f:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -y)
    else
        f:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, -y)
        f:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -y)
    end
    f:SetHeight(height)
    f:Show()
end

--- Build the page's one chrome block into the frame H.PageHeader pinned in the band: the Unit
--- picker, and for target/focus the two mirror controls beside each other under it.
---
--- Returns the mirror checkbox (nil for the player) so the refresher at the bottom of the render
--- can re-sync it. Every widget it creates is recorded on ctx.__chromeWidgets, which is both the
--- release ledger (see releaseStaleChromeWidgets) and the test seam — the library keeps its own
--- chrome private, and a suite otherwise has no handle on a widget a click would reach.
---
--- PageHeader pcalls this and reports a raise, so a failure here costs the block rather than the
--- strip and every row under it.
local function buildChromeBlock(ctx, pageKey, frame, mirrored)
    local AceGUI = NS.AceGUI
    local kids = ctx.__chromeWidgets

    local list, order = {}, {}
    for i, u in ipairs(NS.Units.LIST) do
        list[u]  = NS.Units.LABEL[u]
        order[i] = u
    end

    local dd = AceGUI:Create("Dropdown")
    kids[#kids + 1] = dd
    dd:SetLabel("Unit")
    dd:SetList(list, order)
    dd:SetValue(ctx.unit)
    dd:SetCallback("OnValueChanged", function(_, _, value)
        if value == ctx.unit then return end
        ctx.unit = value
        Helpers.RenderUnitPanel(ctx, pageKey)
    end)
    Helpers.AttachTooltip(dd, "Unit",
        "Which bar the settings on this page apply to. Each unit is styled independently unless it is linked to the Player.")
    place(dd, frame, 0, Helpers.BANNER_H)
    ctx.__bannerWidget = dd

    -- The player IS the mirror source, so it gets the picker and nothing else.
    if ctx.unit == "player" then return nil end

    local y = Helpers.BANNER_H + Helpers.ROW_VSPACER

    local cb = AceGUI:Create("CheckBox")
    kids[#kids + 1] = cb
    cb:SetLabel("Use same styling as Player")
    cb:SetValue(mirrored)
    cb:SetCallback("OnValueChanged", function(_, _, value)
        NS.SetByPath("units." .. ctx.unit .. ".mirror", value and true or false)
        Helpers.RenderUnitPanel(ctx, pageKey)
    end)
    Helpers.AttachTooltip(cb, "Use same styling as Player",
        "Mirror every Player bar appearance setting. Position and enable stay independent.")
    place(cb, frame, y, CONTROL_H, "LEFT")

    local btn = AceGUI:Create("Button")
    kids[#kids + 1] = btn
    btn:SetText("Copy styling from Player")
    btn:SetCallback("OnClick", function()
        NS.Units.CopyFromPlayer(ctx.unit)
        NS.bus:SendMessage(NS.MSG.APPEARANCE)
        Helpers.RenderUnitPanel(ctx, pageKey)
    end)
    Helpers.AttachTooltip(btn, "Copy styling from Player",
        "Take a one-time snapshot of the Player bar's appearance. Unlinks this unit so you can then edit it freely.")
    place(btn, frame, y, CONTROL_H, "RIGHT")

    return cb
end

--- Return the PREVIOUS render's chrome widgets to AceGUI's pool.
---
--- The library's chrome ledger hides and unparents the FRAME the block was drawn on; it knows
--- nothing about AceGUI widgets a host parented into it, and AceGUI recycles a widget only when it
--- is released. Without this the page would mint a fresh Dropdown, CheckBox and Button on every
--- unit switch, tab click and mirror toggle — and a WoW frame, once created, is never destroyed.
--- (ClearScroll gets this for free: ReleaseChildren releases everything in the scroll. The chrome
--- band has no equivalent because the library does not own what is in it.)
---
--- RUN AFTER THE RENDER, never before it, and that is the whole reason the stale set is held aside
--- rather than released on the way in. A render is very often reached FROM one of these widgets'
--- own callbacks — the Unit dropdown, the mirror checkbox — and a widget released on the way in is
--- back in the pool in time for this very render to hand it straight back out, re-initialized,
--- while its callback is still on the stack. Released on the way out it cannot be reacquired until
--- the next render, by which time no callback of its own is running.
local function releaseStaleChromeWidgets(ctx)
    local AceGUI = NS.AceGUI
    local stale = ctx.__staleChromeWidgets
    ctx.__staleChromeWidgets = nil
    if not (AceGUI and AceGUI.Release and stale) then return end
    for _, w in ipairs(stale) do AceGUI:Release(w) end
end
Helpers.__releaseStaleChromeWidgets = releaseStaleChromeWidgets


--- The mirrored unit's empty state, drawn UNDER the strip where that tab's rows would be.
---
--- It used to be the last item of the mirror header, above the strip, back when a mirrored unit got
--- no strip at all. Under options-ui-§13 the strip is unconditional, so the state it describes is
--- ordinary page content: one line, in the place the thing it is explaining the absence of would be.
--- Handed to RenderGrid as data like every other bespoke item on this page, so a raise inside it
--- costs the line rather than the whole page.
local function renderMirroredHint(ctx)
    Helpers.RenderGrid(ctx, { { wide = true, make = function(_, parent)
        local hint = NS.AceGUI:Create("Label")
        -- An em dash (\226\128\148), never a figure dash: the figure dash is missing from the
        -- settings-panel font and renders as an empty box.
        hint:SetText("Linked to Player \226\128\148 uncheck to customize.")
        hint:SetFullWidth(true)
        parent:AddChild(hint)
    end } })
end

local function renderUnitPanelBody(ctx, pageKey)
    ctx.unit = ctx.unit or "player"
    Helpers.ClearScroll(ctx)
    local scroll = Helpers.EnsureScroll(ctx)
    Helpers.__lastUnitCtx = ctx   -- test seam: the harness has no other handle on a live ctx

    local mirrored = NS.Units.IsMirrored(ctx.unit)
    local cb                                   -- hoisted: the refresher at the bottom re-syncs it

    -- 1. The block, always, and BEFORE the strip: PageHeader records its own share of the chrome
    --    band in ctx.__bannerHeight, which TabStrip then adds to the rows it reserves for itself.
    --    Called the other way round, the strip's reservation would not know about it and the tabs
    --    would draw on top of the picker.
    --
    --    The widgets it built LAST time are set aside here and released after the render (see
    --    releaseStaleChromeWidgets), because this render is usually running inside one of their
    --    callbacks.
    ctx.__staleChromeWidgets = ctx.__chromeWidgets
    ctx.__chromeWidgets = {}
    -- Cleared with them, not left pointing at a widget this render is about to release: PageHeader
    -- answers nil and draws nothing when it has no chrome to draw into, and a seam still naming the
    -- last render's picker would be a handle on a released widget.
    ctx.__bannerWidget = nil
    Helpers.PageHeader(ctx, {
        height = chromeBlockHeight(ctx.unit),
        build  = function(_, frame)
            cb = buildChromeBlock(ctx, pageKey, frame, mirrored)
        end,
    })

    -- 2. The strip, ALWAYS (options-ui-§13), and then either the active tab's rows or -- for a
    --    mirrored unit, whose appearance rows are all hidden -- the hint that takes their place.
    --    The mirror row itself carries skipRender, so partitionTabs leaves it out of the strip and
    --    RenderRows leaves it to the block above.
    local rows = NS.SchemaForPage(pageKey, ctx.unit)
    local tabs, byGroup = partitionTabs(rows)
    if #tabs > 0 then
        -- A stale pointer heals to the first tab rather than being trusted, exactly as the
        -- library's own RenderTabbedSchema does: a tab naming a group this page no longer has
        -- would render an empty page under a full strip.
        if not (ctx.activeTab and byGroup[ctx.activeTab]) then
            ctx.activeTab = tabs[1]
        end
        local spec = {}
        for i, name in ipairs(tabs) do spec[i] = { key = name, label = name } end
        Helpers.TabStrip(ctx, {
            tabs  = spec,
            value = ctx.activeTab,
            onSelect = function(key)
                if key == ctx.activeTab then return end
                ctx.activeTab = key
                -- The whole page, not just the rows: a mirrored unit's body is the hint rather
                -- than the tab's rows, and a schema-only redraw would put the rows back.
                Helpers.RenderUnitPanel(ctx, pageKey)
            end,
        })
        if mirrored then
            renderMirroredHint(ctx)
        else
            Helpers.RenderRows(ctx, byGroup[ctx.activeTab], nil, nil, { noHeadings = true })
        end
    end

    if scroll and scroll.DoLayout then scroll:DoLayout() end

    -- Register the BLOCK's refresher. The mirror checkbox and the "Copy styling from Player"
    -- button above are built inline here, not through RenderField, so neither appends a refresher
    -- of its own — RefreshAllPanels structurally could not update them, and nothing re-ran the
    -- mirrored/unmirrored row partition. Concretely: RestoreDefaults("appearance", ctx) resets
    -- units.focus.mirror to its default `true`, then runs only the refreshers, so the checkbox
    -- still read unchecked and the appearance rows stayed on screen over a now-mirrored unit
    -- (same stale state after `/at set units.focus.mirror true` and after a profile switch).
    --
    -- TWO-TIER, and the split matters. Every schema widget's write calls RefreshAllPanels, so this
    -- closure runs on EVERY checkbox click, slider drag and LSM pick on this page:
    --
    --   * Always — re-sync the checkbox in place. Cheap, tears nothing down.
    --   * Only when the mirror state actually CHANGED since this render — re-render, because that
    --     is the only thing that can invalidate the mirrored/unmirrored partition.
    --
    -- An unconditional re-render here would rebuild the whole page on every ordinary appearance
    -- write, and the mechanism (not the waste) is the problem: ClearScroll releases the very
    -- widget whose OnValueChanged is still on the stack — an LSM30_* dropdown with an open pullout,
    -- a slider mid-drag — and destroys scroll position and tooltips with it. The library's color
    -- picker already declines to call RefreshAllPanels for exactly this class of reason.
    --
    -- Registered LAST so the row refreshers above have already run; RefreshAllPanels iterates the
    -- pre-render table, so a closure registered by a re-render is not re-invoked in the same pass.
    local renderedUnit, renderedMirrored = ctx.unit, mirrored
    ctx.refreshers[#ctx.refreshers + 1] = function()
        local nowMirrored = NS.Units.IsMirrored(renderedUnit)
        if cb then cb:SetValue(nowMirrored) end
        if nowMirrored ~= renderedMirrored then
            Helpers.RenderUnitPanel(ctx, pageKey)
        end
    end
end

--- The public entry point. Every caller — the page files' OnShow, the Unit dropdown, the mirror
--- checkbox, the block's refresher — goes through here.
---
--- Re-entrancy guard. The last thing a render does is register a refresher that re-renders the
--- whole panel, and a render registers a fresh refresher of its own. Without this flag, any
--- refresher pass fired from INSIDE a render — a widget's onChange reaching RefreshAllPanels while
--- the page is being built — would recurse. The flag makes the inner call a no-op; the outer render
--- finishes and leaves the panel correct.
---
--- The flag is cleared on BOTH paths, which is why the body is pcall'd. Cleared only on the normal
--- exit, a single raise anywhere inside the render — an AceGUI widget error, a malformed schema
--- row, a nil NS.Units.LABEL entry — latches it, and every later render returns silently at the
--- guard: the page looks frozen for the rest of the session and only /reload recovers it. The
--- library pcalls each refresher for the same reason. The failure is reported rather than
--- swallowed, because a page that silently declines to draw is the same bug wearing a hat.
function Helpers.RenderUnitPanel(ctx, pageKey)
    if not NS.AceGUI then return end
    if ctx.__rendering then return end

    ctx.__rendering = true
    local ok, err = pcall(renderUnitPanelBody, ctx, pageKey)
    ctx.__rendering = false

    -- On BOTH paths, and outside the pcall on purpose: the widgets the last render put in the
    -- chrome block are stale whether this one finished or raised, and a set left unreleased is a
    -- set of frames AceGUI can never hand out again.
    releaseStaleChromeWidgets(ctx)

    if not ok then
        NS.Print(("Unit panel render failed: %s"):format(NS.SafeToString(err)))
    end
end
