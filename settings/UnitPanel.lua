-- AbsorbTracker: settings/UnitPanel.lua
--
-- The two pieces of the old settings/Helpers.lua that are genuinely this addon's and did not go
-- upstream: the Appearance page (the Unit banner, the mirror header, the tab strip over the unit's
-- own groups, and the two-tier refresher that keeps them honest) and the single reset-position
-- implementation.
--
-- Neither generalizes. RenderUnitPanel reads NS.Units and the mirror partition, which no other Ka0s
-- addon has; ResetAllPositions clears a per-unit saved frame position, which is this addon's data
-- model. Everything they stand on — ClearScroll, EnsureScroll, RenderGrid, RenderRows, PageBanner,
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
-- Appearance page rendering — Unit banner, mirror header, tab strip
-- ---------------------------------------------------------------------

--- Render the per-unit Appearance page: the Unit banner, the mirror header for target/focus, then
--- the selected tab's rows.
---
--- THREE BANDS, top to bottom, and which of them is drawn depends on the mirror:
---
---   1. THE BANNER (chrome, options-ui-§14) -- always. The Unit picker, pinned above everything, in
---      the library's chrome slot rather than in the scroll. It is the ONLY unit picker in the
---      panel now: the three pages this one replaced each drew their own into their own scroll, so
---      styling one bar meant picking the same unit three times over three copies of one piece of
---      state.
---   2. THE MIRROR HEADER (scroll) -- target and focus only. The mirror checkbox and the
---      "Copy styling from Player" button, still bespoke: neither has a schema path, so neither can
---      be a row, which is exactly the case options-ui-§13 exempts from the two-controls-per-tab
---      rule rather than loosening it.
---   3. THE TAB STRIP (chrome, options-ui-§13) plus the active tab's rows -- only while the unit is
---      NOT mirrored. Every appearance row on this page is hidden by the mirror, so a mirrored unit
---      has five tabs of nothing to click through; the hint line takes their place instead.
---
--- The strip is drawn with H.TabStrip directly rather than through H.RenderTabbedSchema, for the
--- reason MultiMeters' Columns page gives for the same choice: RenderTabbedSchema owns the whole
--- page body, and its tab click does ClearScroll + re-render of ITSELF, which would drop the mirror
--- header this page draws above the rows. A tab click here re-renders the whole page instead, which
--- is the same path the Unit picker and the mirror checkbox already take.
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
--- @return table  group names in declaration order
--- @return table  { [group] = { row, ... } }
local function partitionTabs(rows)
    local order, byGroup = {}, {}
    for _, row in ipairs(rows) do
        if row.group then
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

--- The Unit banner. Decorated onto the instance rather than kept file-local so a suite can reach
--- the widget the way a click would; the library keeps its own chrome private.
local function renderBanner(ctx, pageKey)
    if not Helpers.PageBanner then return end
    local list, order = {}, {}
    for i, u in ipairs(NS.Units.LIST) do
        list[u] = NS.Units.LABEL[u]
        order[i] = u
    end
    ctx.__bannerWidget = Helpers.PageBanner(ctx, {
        label   = "Unit",
        tooltip = "Which bar the settings on this page apply to. Each unit is styled independently unless it is linked to the Player.",
        list    = list,
        order   = order,
        value   = ctx.unit,
        onSelect = function(value)
            if value == ctx.unit then return end
            ctx.unit = value
            Helpers.RenderUnitPanel(ctx, pageKey)
        end,
    })
end

--- The mirror header for target/focus: the link checkbox and the one-time copy button, as DATA
--- handed to the library's flow engine. Returns the checkbox so the refresher can re-sync it.
local function renderMirrorHeader(ctx, pageKey, mirrored)
    local AceGUI = NS.AceGUI
    local cb
    local items = {}

    items[#items + 1] = { make = function(_, parent, relativeWidth)
        cb = AceGUI:Create("CheckBox")
        cb:SetLabel("Use same styling as Player")
        cb:SetValue(mirrored)
        cb:SetRelativeWidth(relativeWidth)
        cb:SetCallback("OnValueChanged", function(_, _, value)
            NS.SetByPath("units." .. ctx.unit .. ".mirror", value and true or false)
            Helpers.RenderUnitPanel(ctx, pageKey)
        end)
        Helpers.AttachTooltip(cb, "Use same styling as Player",
            "Mirror every Player bar appearance setting. Position and enable stay independent.")
        parent:AddChild(cb)
    end }

    items[#items + 1] = { make = function(_, parent, relativeWidth)
        local btn = AceGUI:Create("Button")
        btn:SetText("Copy styling from Player")
        btn:SetRelativeWidth(relativeWidth)
        btn:SetCallback("OnClick", function()
            NS.Units.CopyFromPlayer(ctx.unit)
            NS.bus:SendMessage(NS.MSG.APPEARANCE)
            Helpers.RenderUnitPanel(ctx, pageKey)
        end)
        Helpers.AttachTooltip(btn, "Copy styling from Player",
            "Take a one-time snapshot of the Player bar's appearance. Unlinks this unit so you can then edit it freely.")
        parent:AddChild(btn)
    end }

    if mirrored then
        items[#items + 1] = { wide = true, make = function(_, parent)
            local hint = AceGUI:Create("Label")
            -- An em dash (\226\128\148), never a figure dash: the figure dash is missing from the
            -- settings-panel font and renders as an empty box.
            hint:SetText("Linked to Player \226\128\148 uncheck to customize.")
            hint:SetFullWidth(true)
            parent:AddChild(hint)
        end }
    end

    -- The header used to hand-roll this: a SimpleGroup + SetLayout("Flow") + SetFullWidth(true),
    -- two children at SetRelativeWidth(0.5), then AddSpacer(ROW_VSPACER). RenderGrid's HALF is the
    -- same 0.5 and it emits the same trailing spacer, so the rendered layout is unchanged; what is
    -- gained is that each item is pcall'd individually, where before a single raise in the header
    -- aborted the whole body and left the page half-drawn.
    Helpers.RenderGrid(ctx, items)
    return cb
end

local function renderUnitPanelBody(ctx, pageKey)
    ctx.unit = ctx.unit or "player"
    Helpers.ClearScroll(ctx)
    local scroll = Helpers.EnsureScroll(ctx)
    Helpers.__lastUnitCtx = ctx   -- test seam: the harness has no other handle on a live ctx

    local mirrored = NS.Units.IsMirrored(ctx.unit)
    local cb                                   -- hoisted: the refresher at the bottom re-syncs it

    -- 1. The banner, always, and BEFORE the strip: PageBanner records its own share of the chrome
    --    band in ctx.__bannerHeight, which TabStrip then adds to the rows it reserves for itself.
    --    Called the other way round, the strip's reservation would not know about it and the tabs
    --    would draw on top of the picker.
    renderBanner(ctx, pageKey)

    -- 2. The mirror header, target and focus only.
    if ctx.unit ~= "player" then
        cb = renderMirrorHeader(ctx, pageKey, mirrored)
    end

    -- 3. The strip and its rows, only for a unit that is not mirrored. The mirror row itself carries
    --    skipRender and no group, so it belongs to no tab and RenderRows leaves it to the header.
    if not mirrored then
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
                    -- The whole page, not just the rows: the banner and the mirror header sit above
                    -- the strip and a schema-only redraw would drop them.
                    Helpers.RenderUnitPanel(ctx, pageKey)
                end,
            })
            Helpers.RenderRows(ctx, byGroup[ctx.activeTab], nil, nil, { noHeadings = true })
        end
    end

    if scroll and scroll.DoLayout then scroll:DoLayout() end

    -- Register the HEADER's refresher. The mirror checkbox and the "Copy styling from Player"
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
    --     is the only thing that can invalidate the mirrored/unmirrored partition, and now also the
    --     only thing that can make the tab strip appear or disappear.
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
--- checkbox, the header refresher — goes through here.
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

    if not ok then
        NS.Print(("Unit panel render failed: %s"):format(NS.SafeToString(err)))
    end
end
