-- AbsorbTracker: settings/UnitPanel.lua
--
-- The two pieces of the old settings/Helpers.lua that are genuinely this addon's and did not go
-- upstream: the Appearance page (the chrome block holding the Unit picker, the unit's enable box
-- and the link controls,
-- the tab strip over the unit's own groups, and the two-tier refresher that keeps them honest) and
-- the single reset-position implementation.
--
-- Neither generalizes. RenderUnitPanel reads NS.Units and the mirror partition, which no other Ka0s
-- addon has; ResetAllPositions clears a per-unit saved frame position, which is this addon's data
-- model. Everything they stand on — ClearScroll, EnsureScroll, PageHeader, RenderTabbedSchema,
-- AttachTooltip — is LibKa0s-Options-1.0's, reached through the same NS.Helpers table, which IS the library instance
-- (settings/OptionsSetup.lua). Decorating it rather than sitting beside it is what lets a page file
-- call H.RenderUnitPanel and H.RenderSchema without knowing or caring which is which.

local _, NS = ...

local Helpers = NS.Helpers

-- ---------------------------------------------------------------------
-- Reset position
-- ---------------------------------------------------------------------

-- Clear EVERY unit's saved position and republish POSITION so all three bars re-anchor to their
-- stacked defaults. This is the single "reset position" implementation: `/at resetposition`
-- (settings/Slash.lua) and the General page's "Reset Position" button (settings/General.lua) both
-- call it, so the CLI and the panel can never diverge. Reset All no longer does: it is a profile
-- reset (settings/OptionsSetup.lua), and the positions come back with the profile. This is one of
-- the two writers of units.<unit>.position that docs/ARCHITECTURE.md -> Settings Schema names.
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
---      holds everything that applies to the page AS A WHOLE, on ONE row of four quarter cells
---      (ABS-L11): the Unit picker, the picked unit's "Enable this unit" box, and -- for target
---      and focus -- the "Link to Player" checkbox and the "Copy from Player" button. The player
---      leaves the last two cells empty, so the band is the same height for every unit.
---
---      THE ENABLE BOX IS A ROW STAMPED TO ANOTHER PAGE (item 020, ABS-L01). `units.<unit>.enabled`
---      keeps `page = "general"` and `skipRender`, so General's Defaults still resets it and both
---      Defaults tooltips say so (options-ui-§14). It is drawn here because §14 makes *enable* on
---      the edited instance a band act and §15 keeps per-instance settings on the instance's page,
---      and it has to be the band rather than a tab: a linked unit's tabs are replaced by the hint
---      (disabledReplaces), and its enable is not part of the link. Its label and tooltip are the
---      row's own; it writes through NS.SetByPath so the row's onChange fires.
---
---      H.PageHeader, not H.PageBanner, and that is the RULE rather than a preference. §14 puts
---      page-wide controls in this band, "above the strip -- never in the scroll below it", and
---      names copy among the acts it covers. Both link controls govern every tab: linking
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
---      The copy button is not a schema row and cannot be: it has no path. The link and enable boxes
---      draw rows that carry `skipRender` for exactly this reason: their widget is here. That is the case options-ui-§13 exempts from
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
---      Drawn by H.RenderTabbedSchema with three opts OptionsTabs minor 8 added for this page
---      (LibKa0s v1.66.0, issue #32). Each replaces a piece the page used to compose itself:
---
---        untabbedSkipRender -- the link row is the Link group's only row and carries skipRender
---                              (its widget is the checkbox in the block above), so Link is no tab.
---                              The strip is one tab per remaining group, in declaration order.
---        disabledReplaces   -- a mirrored unit draws the hint INSTEAD of its rows, never the rows
---                              disabled under it. disabledFor answers the mirror state this render
---                              captured, the same value the refresher below compares against.
---        rerender           -- a tab click re-runs this whole render rather than ClearScroll plus a
---                              rows-only redraw, so the block above and the refresher registered
---                              after the body survive it. It is the path the Unit picker and the
---                              mirror checkbox already take.
---
---      The hint keeps the library's notice font, GameFontHighlightSmall, which is also AceGUI's
---      own Label font, so it reads exactly as the Label this page drew itself before.
---
--- Full rebuild on every call rather than a persistent header widget: AceGUI's widget pool exists
--- exactly to make release-and-recreate cheap, so each call clears ctx.scroll and rebuilds.
---
--- The body is a private local so the public entry point below can pcall it — see the re-entrancy
--- guard there. Call Helpers.RenderUnitPanel, never this.

-- The chrome block's own arithmetic.
--
-- BANNER_H is the LIBRARY's number, read off the instance rather than restated
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
--- ONE ROW for every unit (options-ui-§14, ABS-L11): the band's height must not depend on which
--- unit the picker shows, or the strip and everything under it jumps when the player picks another.
--- @return number
local function chromeBlockHeight()
    return Helpers.BANNER_H
end

--- The block's two halves, as frames the quarter cells hang off. A quarter boundary is the middle
--- of a half, which no point of the block frame names, so each half is a frame of its own anchored
--- to the block's TOPLEFT/TOP or TOP/TOPRIGHT, and a cell takes its half's left or right side.
---
--- Made ONCE per block frame and kept on it: PageHeader hands the same pooled frame back on every
--- render, and a frame created on each build would stack (the client never destroys one).
local function blockHalves(frame)
    local halves = frame.__absHalves
    if not halves then
        halves = { CreateFrame("Frame", nil, frame), CreateFrame("Frame", nil, frame) }
        frame.__absHalves = halves
    end
    local left, right = halves[1], halves[2]
    left:ClearAllPoints()
    left:SetPoint("TOPLEFT",  frame, "TOPLEFT", 0, 0)
    left:SetPoint("TOPRIGHT", frame, "TOP",     -PAIR_GAP, 0)
    right:ClearAllPoints()
    right:SetPoint("TOPLEFT",  frame, "TOP",      PAIR_GAP, 0)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    for _, h in ipairs(halves) do
        h:SetHeight(Helpers.BANNER_H)
        h:Show()
    end
    return halves
end

--- Anchor one AceGUI widget's frame into quarter cell `cell` (1-4, left to right) of the block,
--- `y` below its top. This is the same reparent-and-anchor the library's own PageBanner does with
--- its dropdown; what a host draws INSIDE the frame PageHeader hands it is the host's to place.
local function place(widget, frame, halves, cell, y, height)
    local f = widget and widget.frame
    if not f then return end
    local half = halves[cell <= 2 and 1 or 2]
    f:SetParent(frame)
    f:ClearAllPoints()
    if cell % 2 == 1 then
        f:SetPoint("TOPLEFT",  half, "TOPLEFT", 0, -y)
        f:SetPoint("TOPRIGHT", half, "TOP",     -PAIR_GAP, -y)
    else
        f:SetPoint("TOPLEFT",  half, "TOP",      PAIR_GAP, -y)
        f:SetPoint("TOPRIGHT", half, "TOPRIGHT", 0, -y)
    end
    f:SetHeight(height)
    f:Show()
end

--- Build the page's one chrome block into the frame H.PageHeader pinned in the band: one row of
--- four quarter cells, [Unit picker][enable box][Link to Player][Copy from Player]. The player
--- leaves the last two empty, so every control sits at the same x whichever unit is picked. The
--- checkboxes and the button are bottom-aligned with the dropdown, whose label sits above it.
---
--- Returns the link checkbox (nil for the player) and the enable box, so the refresher at the
--- bottom of the render can re-sync both. Every widget it creates is recorded on ctx.__chromeWidgets, which is both the
--- release ledger (see releaseStaleChromeWidgets) and the test seam — the library keeps its own
--- chrome private, and a suite otherwise has no handle on a widget a click would reach.
---
--- PageHeader pcalls this and reports a raise, so a failure here costs the block rather than the
--- strip and every row under it.
--- One chrome-block widget, painted for this addon's skin (skinning-§3). NS.AceGUI is normally the
--- Options instance's owner proxy, which paints on Create already; the explicit NS.SkinPaintAce
--- repaints in place for the same owner, so the block does not depend on which handle it was
--- given. Nothing is painted while the Scope's Ignore settings panel is on, and
--- releaseStaleChromeWidgets' AceGUI:Release puts the widget back in the shared pool stock (the
--- library chains its restore onto the widget's own OnRelease; this file sets none).
local function acquire(AceGUI, wtype)
    local w = AceGUI:Create(wtype)
    if NS.SkinPaintAce then NS.SkinPaintAce(w) end
    return w
end

local function buildChromeBlock(ctx, pageKey, frame, mirrored)
    local AceGUI = NS.AceGUI
    local kids = ctx.__chromeWidgets
    local halves = blockHalves(frame)
    local rowY = Helpers.BANNER_H - CONTROL_H

    local list, order = {}, {}
    for i, u in ipairs(NS.Units.LIST) do
        list[u]  = NS.Units.LABEL[u]
        order[i] = u
    end

    local dd = acquire(AceGUI, "Dropdown")
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
    place(dd, frame, halves, 1, 0, Helpers.BANNER_H)
    ctx.__bannerWidget = dd

    -- The picked unit's enable box, cell 2, bottom-aligned with the dropdown (whose
    -- label sits above it). Every unit has one, the player included. Its words are the schema row's,
    -- so the panel and `/at list` cannot disagree.
    local enablePath = "units." .. ctx.unit .. ".enabled"
    local enableRow  = NS.FindSchemaRow and NS.FindSchemaRow(enablePath)
    local enableLabel = enableRow and enableRow.label or "Enable this unit"
    local en = acquire(AceGUI, "CheckBox")
    kids[#kids + 1] = en
    en:SetLabel(enableLabel)
    en:SetValue(NS.Units.IsEnabled(ctx.unit) and true or false)
    en:SetCallback("OnValueChanged", function(_, _, value)
        NS.SetByPath(enablePath, value and true or false)
    end)
    Helpers.AttachTooltip(en, enableLabel, enableRow and enableRow.desc)
    place(en, frame, halves, 2, rowY, CONTROL_H)

    -- The player IS the link source, so it gets the picker and its enable box and nothing else:
    -- cells 3 and 4 stay empty, and the band keeps the height it has for target and focus.
    if ctx.unit == "player" then return nil, en end

    local linkRow   = NS.FindSchemaRow and NS.FindSchemaRow("units." .. ctx.unit .. ".mirror")
    local linkLabel = linkRow and linkRow.label or "Link to Player"
    local cb = acquire(AceGUI, "CheckBox")
    kids[#kids + 1] = cb
    cb:SetLabel(linkLabel)
    cb:SetValue(mirrored)
    cb:SetCallback("OnValueChanged", function(_, _, value)
        NS.SetByPath("units." .. ctx.unit .. ".mirror", value and true or false)
        Helpers.RenderUnitPanel(ctx, pageKey)
    end)
    Helpers.AttachTooltip(cb, linkLabel, linkRow and linkRow.desc)
    place(cb, frame, halves, 3, rowY, CONTROL_H)

    local btn = acquire(AceGUI, "Button")
    kids[#kids + 1] = btn
    btn:SetText("Copy from Player")
    btn:SetCallback("OnClick", function()
        -- No APPEARANCE publish of our own any more. CopyFromPlayer writes through NS.SetByPath,
        -- and the schema's default onChange broadcasts APPEARANCE per row, so a publish here was a
        -- twenty-first restyle after twenty that had already run.
        NS.Units.CopyFromPlayer(ctx.unit)
        Helpers.RenderUnitPanel(ctx, pageKey)
    end)
    Helpers.AttachTooltip(btn, "Copy from Player",
        "Copy the Player bar's look once, then unlink so you can edit it.")
    place(btn, frame, halves, 4, rowY, CONTROL_H)

    return cb, en
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


local function renderUnitPanelBody(ctx, pageKey)
    ctx.unit = ctx.unit or "player"
    Helpers.ClearScroll(ctx)
    local scroll = Helpers.EnsureScroll(ctx)
    Helpers.__lastUnitCtx = ctx   -- test seam: the harness has no other handle on a live ctx

    local mirrored = NS.Units.IsMirrored(ctx.unit)
    local cb, en                               -- hoisted: the refresher at the bottom re-syncs them

    -- 1. The block, always, and BEFORE the strip: PageHeader records its own share of the chrome
    --    band in ctx.__bannerHeight, which the strip then adds to the rows it reserves for itself.
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
        height = chromeBlockHeight(),
        build  = function(_, frame)
            cb, en = buildChromeBlock(ctx, pageKey, frame, mirrored)
        end,
    })

    -- 2. The strip, ALWAYS (options-ui-§13), and then either the active tab's rows or -- for a
    --    mirrored unit -- the hint that takes their place. See the doc block above for the opts.
    --    The library heals a stale ctx.activeTab to the first tab, and its RenderRows leaves the
    --    skipRender mirror row to the block above.
    Helpers.RenderTabbedSchema(ctx, pageKey, nil, nil, {
        untabbedSkipRender = true,
        disabledReplaces   = true,
        disabledFor        = function() return mirrored end,
        -- Says which control undoes it and where it is (ABS-L10, XC-15).
        disabledNotice     = "Linked to Player. Untick Link to Player above to give this unit its own look.",
        rerender           = function(c) Helpers.RenderUnitPanel(c, pageKey) end,
    })

    if scroll and scroll.DoLayout then scroll:DoLayout() end

    -- Register the BLOCK's refresher. The link and enable boxes and the "Copy from Player"
    -- button above are built inline here, not through RenderField, so none appends a refresher
    -- of its own — RefreshAllPanels structurally could not update them, and nothing re-ran the
    -- mirrored/unmirrored row partition. Concretely: RestoreDefaults("appearance", ctx) resets
    -- units.focus.mirror to its default `true`, then runs only the refreshers, so the checkbox
    -- still read unchecked and the appearance rows stayed on screen over a now-mirrored unit
    -- (same stale state after `/at set units.focus.mirror true` and after a profile switch).
    --
    -- TWO-TIER, and the split matters. Every schema widget's write calls RefreshAllPanels, so this
    -- closure runs on EVERY checkbox click, slider drag and LSM pick on this page:
    --
    --   * Always — re-sync the link and enable boxes in place. Cheap, tears nothing down; the
    --     enable box follows `/at toggle`, `/at set` and General's Defaults this way.
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
    --
    -- It runs only while the page is SHOWN. The page declares its body through SetRenderer
    -- (settings/Appearance.lua), so the library's refresh gate marks a hidden page dirty without
    -- running its refreshers, and the next OnShow rebuilds it (options-ui-§11, anti-pattern #39).
    -- tests/test_panelmirror.lua pins it (AbsorbTracker#20).
    local renderedUnit, renderedMirrored = ctx.unit, mirrored
    ctx.refreshers[#ctx.refreshers + 1] = function()
        local nowMirrored = NS.Units.IsMirrored(renderedUnit)
        if cb then cb:SetValue(nowMirrored) end
        if en then en:SetValue(NS.Units.IsEnabled(renderedUnit) and true or false) end
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
-- A panel that raises on every refresh is one [Cfg] line, not one per render (debug-logging-§8:
-- once per distinct error). The gate is the console's DebugChanged (DebugLogGates 1), keyed here,
-- so the console's Clear and turning logging on re-arm it; nothing is remembered with logging off.
local RENDER_ERROR_KEY = "unitPanelRender"

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
        NS.Print("Unit panel render failed:", err)
        NS.DebugLog.DebugChanged(RENDER_ERROR_KEY, "Cfg", "unit panel render failed (%s): %s",
            pageKey, err)
    end
end
