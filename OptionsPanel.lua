-- AbsorbTracker: OptionsPanel module
--
-- Settings UI framework. Every page — top-level + General / Bar /
-- Border / Font / Profiles — is registered as a canvas-layout
-- subcategory and shares one header design: title (left) + Defaults
-- button (right) + atlas divider, all built by Helpers.CreatePanel.
-- Below the header each tab lays out its own body.
--
-- The schema-driven sub-pages (General / Bar / Border / Font) render
-- their schema rows as AceGUI widgets (CheckBox / Slider / Dropdown /
-- ColorPicker / Heading) inside an AceGUI ScrollFrame parented to
-- ctx.body, so the visual style matches AceGUI-using addons (e.g.
-- KickCD, Consumable Master).
--
-- The same schema feeds /at list|get|set (see Schema.lua + SlashCommands.lua),
-- so adding a new option = one row that auto-wires UI and CLI.

local AddonName, AddonTable = ...

local print = AddonTable.Print

-- ---------------------------------------------------------------------
-- Layout constants
-- ---------------------------------------------------------------------

-- Horizontal padding from the panel's left and right edges to its
-- header / divider / body content. Single value used for both edges so
-- the layout stays symmetric.
local PADDING_X     = 16

-- Vertical inset of the title (and the per-panel "Defaults" button next
-- to it) from the top of the panel.
local HEADER_TOP    = 20

-- Distance from the top of the panel to the divider underneath the
-- title. Sits in lockstep with HEADER_TOP so the title-to-divider
-- gap (and divider-to-body gap below it) stay unchanged when the header
-- block is repositioned vertically.
local HEADER_HEIGHT = 54

-- Width of the per-panel "Defaults" button in the header.
local DEFAULTS_W    = 110

-- Inter-row spacing inside RenderSchema's two-column flow.
local ROW_VSPACER          = 8
local SECTION_TOP_SPACER   = 10
local SECTION_BOTTOM_SPACER = 6
local SECTION_HEADING_H    = 26

-- About page block sizing.
local MAIN_LOGO_SIZE      = 300
local MAIN_GAP_AFTER_LOGO = 8
local MAIN_GAP_AFTER_DESC = 12
local MAIN_GAP_BELOW_HEAD = 6

local LOGO_PATH   = [[Interface\AddOns\AbsorbTracker\media\screenshots\absorbracker.logo.v2.tga]]

local PARENT_TITLE = "Ka0s Absorb Tracker"

-- ---------------------------------------------------------------------
-- Module state
-- ---------------------------------------------------------------------

-- File-load-time queue. Options/*.lua files load after this file (per
-- TOC order) and append their builders here.
local pendingPages = {}

-- Post-registration tracking.
local mainCategory             -- Settings.RegisterCanvasLayoutCategory return
local mainCategoryID           -- numeric ID for OpenToCategory
local defaultCategoryID        -- the page flagged isDefault (what /at config opens)
local subCategoriesByKey = {}  -- key → subcategory return from RegisterCanvasLayoutSubcategory
local renderedPanels = {}      -- list of ctx tables for refresh / reset

local Helpers = {}
AddonTable.Helpers = Helpers

-- ---------------------------------------------------------------------
-- Tooltip helper — works on AceGUI widgets (via SetCallback) and plain
-- Blizzard frames (via HookScript). Anchors on widget.frame when the
-- target is an AceGUI widget.
-- ---------------------------------------------------------------------

local function attachTooltip(widget, label, tooltip)
    if not widget then return end
    local anchor = widget.frame or widget
    if not anchor then return end

    local function show()
        if not GameTooltip then return end
        GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
        if label and label ~= "" then
            GameTooltip:SetText(label, 1, 1, 1)
        end
        if tooltip and tooltip ~= "" then
            GameTooltip:AddLine(tooltip, nil, nil, nil, true)
        end
        GameTooltip:Show()
    end
    local function hide() if GameTooltip then GameTooltip:Hide() end end

    if widget.SetCallback then
        widget:SetCallback("OnEnter", show)
        widget:SetCallback("OnLeave", hide)
    elseif widget.HookScript then
        widget:HookScript("OnEnter", show)
        widget:HookScript("OnLeave", hide)
    end
end
Helpers.AttachTooltip = attachTooltip

-- ---------------------------------------------------------------------
-- Header (title + Defaults button + divider)
-- ---------------------------------------------------------------------

local function buildHeader(panel, title, opts)
    -- Sub-pages render with an "Ka0s Absorb Tracker | <Page>" prefix so
    -- the in-page header reads as a breadcrumb. The parent/main page
    -- opts in to the unprefixed form via opts.isMain (otherwise it
    -- would read "Ka0s Absorb Tracker | Ka0s Absorb Tracker"). The
    -- Blizzard left-tree label is driven by panel.name in CreatePanel
    -- and stays unprefixed so the tree indents under the parent without
    -- visual repetition.
    local displayTitle = title
    if not opts.isMain then
        displayTitle = PARENT_TITLE .. "  |  " .. title
    end

    local titleFS = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
    titleFS:SetPoint("TOPLEFT", panel, "TOPLEFT", PADDING_X, -HEADER_TOP)
    titleFS:SetText(displayTitle)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOPLEFT",  panel, "TOPLEFT",   PADDING_X, -HEADER_HEIGHT)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -PADDING_X, -HEADER_HEIGHT)
    -- Tint to match the title's font color (Blizzard's NORMAL_FONT_COLOR
    -- yellow on GameFontNormalHuge). Reading from the title rather than
    -- hardcoding the gold tracks any future theme retune.
    divider:SetVertexColor(titleFS:GetTextColor())

    local defaultsBtn
    if opts.defaultsButton then
        local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
        if AceGUI then
            defaultsBtn = AceGUI:Create("Button")
            defaultsBtn:SetText("Defaults")
            defaultsBtn:SetWidth(DEFAULTS_W)
            defaultsBtn.frame:SetParent(panel)
            defaultsBtn.frame:ClearAllPoints()
            defaultsBtn.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT",
                                       -PADDING_X, -HEADER_TOP)
            defaultsBtn.frame:Show()
            attachTooltip(defaultsBtn, "Defaults", opts.defaultsTooltip)
        end
    end

    return titleFS, divider, defaultsBtn
end

-- ---------------------------------------------------------------------
-- CreatePanel — Frame compatible with RegisterCanvasLayoutSubcategory
-- with the unified header stamped on top. Returns a `ctx` table the
-- caller threads through Section / RenderField / RenderSchema /
-- InlineButton / RestoreDefaults.
-- ---------------------------------------------------------------------

function Helpers.CreatePanel(name, title, opts)
    opts = opts or {}

    local panel = CreateFrame("Frame", name)
    panel.name = title
    panel:Hide()

    local titleFS, divider, defaultsBtn = buildHeader(panel, title, opts)
    panel.title       = titleFS
    panel.divider     = divider
    panel.defaultsBtn = defaultsBtn

    local body = CreateFrame("Frame", nil, panel)
    body:SetPoint("TOPLEFT",     panel, "TOPLEFT",     0, -(HEADER_HEIGHT + 8))
    body:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", 0, 0)
    panel.body = body

    local ctx = {
        panel       = panel,
        body        = body,
        scroll      = nil,           -- lazy AceGUI ScrollFrame
        refreshers  = {},
        lastGroup   = nil,
        pageKey     = opts.pageKey,
    }
    renderedPanels[#renderedPanels + 1] = ctx
    return ctx
end

-- ---------------------------------------------------------------------
-- Always-visible scrollbar patch
-- ---------------------------------------------------------------------
--
-- AceGUI's stock ScrollFrame.FixScroll auto-hides the scrollbar when
-- content fits inside the viewport. Across our settings tabs that
-- means General (short) shows no scrollbar while Bar (longer) does —
-- visually asymmetric.
--
-- This helper rebinds FixScroll on a single ScrollFrame instance to
-- always keep the scrollbar (and its 20 px right-side gutter) shown,
-- and parks the thumb at the top when there's nothing to scroll. The
-- gutter persists either way so the body content's right edge sits at
-- the same x across every panel.
function Helpers.PatchAlwaysShowScrollbar(scroll)
    if not scroll or scroll._atAlwaysScrollbar then return end
    scroll._atAlwaysScrollbar = true

    local origFixScroll  = scroll.FixScroll
    local origMoveScroll = scroll.MoveScroll
    local origOnRelease  = scroll.OnRelease

    local scrollbar  = scroll.scrollbar
    local thumb      = scrollbar and scrollbar.GetThumbTexture and scrollbar:GetThumbTexture() or nil
    local sbName     = scrollbar and scrollbar.GetName and scrollbar:GetName() or nil
    local upBtn      = sbName and _G[sbName .. "ScrollUpButton"]   or nil
    local downBtn    = sbName and _G[sbName .. "ScrollDownButton"] or nil

    local currentEnabled

    local function setEnabled(want)
        if currentEnabled == want then return end
        currentEnabled = want
        if not scrollbar then return end

        if want then
            if scrollbar.Enable then scrollbar:Enable() end
            if thumb and thumb.SetVertexColor then
                thumb:SetVertexColor(1, 1, 1, 1)
            end
            if upBtn   and upBtn.Enable   then upBtn:Enable()   end
            if downBtn and downBtn.Enable then downBtn:Enable() end
        else
            scrollbar:SetValue(0)
            if scrollbar.Disable then scrollbar:Disable() end
            if thumb and thumb.SetVertexColor then
                thumb:SetVertexColor(0.5, 0.5, 0.5, 0.6)
            end
            if upBtn   and upBtn.Disable   then upBtn:Disable()   end
            if downBtn and downBtn.Disable then downBtn:Disable() end
        end
    end

    scroll.scrollBarShown = true
    if scrollbar then scrollbar:Show() end
    if scroll.scrollframe then
        scroll.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
    end
    if scroll.content and scroll.content.original_width then
        scroll.content.width = scroll.content.original_width - 20
    end

    scroll.FixScroll = function(self)
        if self.updateLock then return end
        self.updateLock = true

        if not self.scrollBarShown then
            self.scrollBarShown = true
            self.scrollbar:Show()
            self.scrollframe:SetPoint("BOTTOMRIGHT", -20, 0)
            if self.content.original_width then
                self.content.width = self.content.original_width - 20
            end
        end

        local status = self.status or self.localstatus
        local height, viewheight =
            self.scrollframe:GetHeight(), self.content:GetHeight()
        local offset = status.offset or 0

        if viewheight < height + 2 then
            setEnabled(false)
            self.scrollbar:SetValue(0)
            self.scrollframe:SetVerticalScroll(0)
            status.offset = 0
        else
            setEnabled(true)
            local value = (offset / (viewheight - height) * 1000)
            if value > 1000 then value = 1000 end
            self.scrollbar:SetValue(value)
            self:SetScroll(value)
            if value < 1000 then
                self.content:ClearAllPoints()
                self.content:SetPoint("TOPLEFT",  0, offset)
                self.content:SetPoint("TOPRIGHT", 0, offset)
                status.offset = offset
            end
        end

        self.updateLock = nil
    end

    scroll.MoveScroll = function(self, value)
        if currentEnabled == false then return end
        if origMoveScroll then return origMoveScroll(self, value) end
    end

    scroll.OnRelease = function(self)
        self.FixScroll  = origFixScroll
        self.MoveScroll = origMoveScroll
        self.OnRelease  = origOnRelease
        self._atAlwaysScrollbar = nil
        currentEnabled  = nil
        if thumb and thumb.SetVertexColor then
            thumb:SetVertexColor(1, 1, 1, 1)
        end
        if scrollbar and scrollbar.Enable then scrollbar:Enable() end
        if upBtn   and upBtn.Enable   then upBtn:Enable()   end
        if downBtn and downBtn.Enable then downBtn:Enable() end
        if origOnRelease then origOnRelease(self) end
    end
end

-- ---------------------------------------------------------------------
-- Lazy AceGUI scroll container.
-- ---------------------------------------------------------------------

local function ensureScroll(ctx)
    if ctx.scroll then return ctx.scroll end
    local AceGUI = LibStub("AceGUI-3.0")
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll.frame:SetParent(ctx.body)
    scroll.frame:ClearAllPoints()
    -- Right-edge inset of PADDING_X+12 leaves room for the scrollbar
    -- (which AceGUI nudges 20px to the right of the scrollframe when
    -- visible) without it being flush against the panel border.
    scroll.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      PADDING_X - 4, -8)
    scroll.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -(PADDING_X + 12), 8)
    scroll.frame:Show()

    -- AceGUI's ScrollFrame normally has its width/height set by a
    -- parent AceGUI container during DoLayout; we parent it to a
    -- Blizzard frame instead, so OnWidthSet/OnHeightSet never fire.
    -- Hook OnSizeChanged to forward the actual size into AceGUI and
    -- then re-run DoLayout + FixScroll so the scrollbar appears
    -- whenever the body resizes.
    scroll.frame:SetScript("OnSizeChanged", function(_, w, h)
        if scroll.OnWidthSet  then scroll:OnWidthSet(w)  end
        if scroll.OnHeightSet then scroll:OnHeightSet(h) end
        if scroll.DoLayout    then scroll:DoLayout()     end
        if scroll.FixScroll   then scroll:FixScroll()    end
    end)

    Helpers.PatchAlwaysShowScrollbar(scroll)

    ctx.scroll = scroll
    return scroll
end

-- ---------------------------------------------------------------------
-- Section header — AceGUI Heading (full-width label flanked by side
-- divider textures).
-- ---------------------------------------------------------------------

local function addSpacer(scroll, height)
    local AceGUI = LibStub("AceGUI-3.0")
    local sp = AceGUI:Create("SimpleGroup")
    sp:SetLayout(nil)
    sp:SetFullWidth(true)
    sp:SetHeight(height)
    scroll:AddChild(sp)
end

function Helpers.Section(ctx, label)
    local scroll = ensureScroll(ctx)
    local AceGUI = LibStub("AceGUI-3.0")

    if ctx.lastGroup ~= nil then
        addSpacer(scroll, SECTION_TOP_SPACER)
    end

    local h = AceGUI:Create("Heading")
    h:SetText(label)
    h:SetFullWidth(true)
    h:SetHeight(SECTION_HEADING_H)
    if h.label and h.label.SetFontObject and _G.GameFontNormalLarge then
        h.label:SetFontObject(_G.GameFontNormalLarge)
    end
    scroll:AddChild(h)

    addSpacer(scroll, SECTION_BOTTOM_SPACER)
    return h
end

-- ---------------------------------------------------------------------
-- Widget makers — bind directly to db.profile via Schema's SetByPath
-- and SetSetting, register a refresher closure for /at set + profile-
-- change re-sync, and add themselves to the panel's AceGUI scroll.
-- ---------------------------------------------------------------------

local function applyWidth(widget, relativeWidth)
    if relativeWidth then
        widget:SetRelativeWidth(relativeWidth)
    else
        widget:SetFullWidth(true)
    end
end

local function get(path) return AddonTable.GetSetting(path) end

-- Write a row's value, fire its onChange, then refresh every widget on
-- every panel. The refresh is what makes paired controls Just Work — a
-- "Use Class Color" toggle flips and the matching color picker greys
-- out (or un-greys) on the same frame. AceGUI SetValue doesn't fire
-- OnValueChanged, so this can't recurse.
local function set(row, value)
    AddonTable.SetSetting(row.path, value)
    if AddonTable.FireSchemaOnChange then
        AddonTable.FireSchemaOnChange(row, value)
    end
    Helpers.RefreshAllPanels()
end

local function makeCheckbox(ctx, row, parent, relativeWidth)
    local AceGUI = LibStub("AceGUI-3.0")
    parent = parent or ensureScroll(ctx)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(row.label or row.path)
    applyWidth(cb, relativeWidth)

    local function readValue()
        local v = get(row.path) and true or false
        if row.inverse then v = not v end
        return v
    end

    cb:SetValue(readValue())

    local function refresh() cb:SetValue(readValue()) end

    cb:SetCallback("OnValueChanged", function(_, _, value)
        local v = value and true or false
        if row.inverse then v = not v end
        set(row, v)
    end)

    attachTooltip(cb, row.label, row.desc)
    parent:AddChild(cb)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return cb
end

local function snapToStep(value, mn, step)
    if not (step and step > 0) then return value end
    return math.floor((value - mn) / step + 0.5) * step + mn
end

local function makeSlider(ctx, row, parent, relativeWidth)
    local AceGUI = LibStub("AceGUI-3.0")
    parent = parent or ensureScroll(ctx)
    local s = AceGUI:Create("Slider")
    s:SetLabel(row.label or row.path)
    s:SetSliderValues(row.min or 0, row.max or 1, row.step or 1)
    s:SetIsPercent(false)
    applyWidth(s, relativeWidth)

    local function refresh()
        local v = get(row.path)
        if type(v) ~= "number" then v = row.default or row.min or 0 end
        s:SetValue(v)
    end

    s:SetCallback("OnMouseUp", function(_, _, value)
        local snapped = snapToStep(value, row.min or 0, row.step or 0)
        set(row, snapped)
    end)

    attachTooltip(s, row.label, row.desc)
    parent:AddChild(s)
    refresh()
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return s
end

local function makeDropdown(ctx, row, parent, relativeWidth)
    local AceGUI = LibStub("AceGUI-3.0")
    parent = parent or ensureScroll(ctx)
    -- LSM dropdowns get the in-tree LSM30_* widget so each row renders
    -- with a swatch / font preview. Everything else uses the stock
    -- AceGUI Dropdown — both share enough of an interface
    -- (SetLabel/SetList/SetValue/OnValueChanged) that the rest of this
    -- function is unchanged either way. Fall back to plain Dropdown if
    -- AceGUI-3.0-SharedMediaWidgets failed to load (no swatch, but the
    -- option still renders).
    local widgetType = row.dialogControl or "Dropdown"
    if widgetType ~= "Dropdown" and not AceGUI:GetWidgetVersion(widgetType) then
        widgetType = "Dropdown"
    end
    local dd = AceGUI:Create(widgetType)
    dd:SetLabel(row.label or row.path)
    applyWidth(dd, relativeWidth)

    local function valuesHash()
        if type(row.values) == "function" then return row.values() or {} end
        return row.values or {}
    end

    local function applyList()
        local items = valuesHash()
        local order
        if row.sorting then
            order = {}
            for i, k in ipairs(row.sorting) do order[i] = k end
        else
            order = {}
            for k in pairs(items) do order[#order + 1] = k end
            table.sort(order)
        end
        dd:SetList(items, order)
    end
    applyList()
    dd:SetValue(get(row.path))

    local function refresh()
        applyList()                            -- LSM lists may grow over time
        dd:SetValue(get(row.path))
    end

    dd:SetCallback("OnValueChanged", function(_, _, value)
        set(row, value)
    end)

    attachTooltip(dd, row.label, row.desc)
    parent:AddChild(dd)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return dd
end

-- AT colors are stored as {r=, g=, b=, a=} named keys (see Settings.lua's
-- GetBarColor / GetBgColor / GetBorderColor). Read/write that shape here
-- so the rest of the addon doesn't have to translate.
local function makeColorPicker(ctx, row, parent, relativeWidth)
    local AceGUI = LibStub("AceGUI-3.0")
    parent = parent or ensureScroll(ctx)
    local cp = AceGUI:Create("ColorPicker")
    cp:SetLabel(row.label or row.path)
    cp:SetHasAlpha(row.hasAlpha and true or false)
    applyWidth(cp, relativeWidth)

    local function readColor()
        local c = get(row.path)
        if type(c) ~= "table" then c = {} end
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end

    cp:SetColor(readColor())

    local function applyDisabled()
        if row.disabledIf then
            cp:SetDisabled(get(row.disabledIf) and true or false)
        end
    end
    applyDisabled()

    local function refresh()
        cp:SetColor(readColor())
        applyDisabled()
    end

    -- AceGUI's ColorPicker fires OnValueChanged during drag (live
    -- preview) and OnValueConfirmed on cancel (with the original color).
    -- Throttle the live-preview commits at 50ms so a sustained drag
    -- doesn't repaint the bar 60×/s; cancel commits immediately so the
    -- bar snaps back to the pre-drag color without waiting on the
    -- throttle window.
    local function commit(r, g, b, a)
        AddonTable.SetSetting(row.path, { r = r, g = g, b = b, a = a or 1 })
        if AddonTable.FireSchemaOnChange then
            AddonTable.FireSchemaOnChange(row, AddonTable.GetSetting(row.path))
        end
    end

    local lastCommit = 0
    local pendingArgs
    local function throttledCommit(r, g, b, a)
        local now = GetTime() and GetTime() or 0
        if now - lastCommit >= 0.05 then
            lastCommit = now
            pendingArgs = nil
            commit(r, g, b, a)
        else
            pendingArgs = { r, g, b, a }
            C_Timer.After(0.05, function()
                if pendingArgs then
                    local p = pendingArgs
                    pendingArgs = nil
                    lastCommit = GetTime() and GetTime() or 0
                    commit(p[1], p[2], p[3], p[4])
                end
            end)
        end
    end

    cp:SetCallback("OnValueChanged",   function(_, _, r, g, b, a) throttledCommit(r, g, b, a) end)
    cp:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a) commit(r, g, b, a) end)

    attachTooltip(cp, row.label, row.desc)
    parent:AddChild(cp)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return cp
end

-- Generic field renderer — dispatches by row.type.
function Helpers.RenderField(ctx, row, parent, relativeWidth)
    if row.type == "bool"   then return makeCheckbox(ctx, row, parent, relativeWidth)    end
    if row.type == "number" then return makeSlider(ctx, row, parent, relativeWidth)      end
    if row.type == "string" then return makeDropdown(ctx, row, parent, relativeWidth)    end
    if row.type == "color"  then return makeColorPicker(ctx, row, parent, relativeWidth) end
end

-- ---------------------------------------------------------------------
-- Inline action buttons (not settings)
-- ---------------------------------------------------------------------

-- Two side-by-side action buttons sharing one Flow row at 50% / 50%
-- width. Each spec is { text = ..., tooltip = ..., onClick = function }.
function Helpers.InlineButtonPair(ctx, leftSpec, rightSpec)
    local AceGUI = LibStub("AceGUI-3.0")
    local scroll = ensureScroll(ctx)

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(28)

    local function makeBtn(spec)
        if not spec then return end
        local btn = AceGUI:Create("Button")
        btn:SetText(spec.text or "")
        btn:SetRelativeWidth(0.5)
        btn:SetCallback("OnClick", function()
            if not spec.onClick then return end
            local ok, err = pcall(spec.onClick)
            if not ok then
                print("button onClick failed: " .. tostring(err))
            end
        end)
        attachTooltip(btn, spec.text, spec.tooltip)
        row:AddChild(btn)
    end

    makeBtn(leftSpec)
    makeBtn(rightSpec)
    scroll:AddChild(row)
    addSpacer(scroll, ROW_VSPACER)
end

-- ---------------------------------------------------------------------
-- Schema-driven render
-- ---------------------------------------------------------------------
--
-- Schema widgets are paired into 50%/50% Flow rows, each row wrapped in
-- a full-width SimpleGroup so AceGUI's layout pass gives both children
-- exactly half the panel width and breaks them onto the same line.
-- Section headings span the full width (one per row), and every row is
-- followed by a small vertical spacer for breathing room. afterGroup
-- callbacks (e.g. inline action buttons) fire after the in-progress row
-- is flushed, so they always start on a fresh line.
function Helpers.RenderSchema(ctx, pageKey, afterGroup)
    local AceGUI = LibStub("AceGUI-3.0")
    local rows   = AddonTable.SchemaForPage(pageKey)
    local scroll = ensureScroll(ctx)
    local pendingRow, pendingCount = nil, 0

    local function flushRow()
        if pendingRow then
            scroll:AddChild(pendingRow)
            addSpacer(scroll, ROW_VSPACER)
            pendingRow, pendingCount = nil, 0
        end
    end

    local function startRow()
        local r = AceGUI:Create("SimpleGroup")
        r:SetLayout("Flow")
        r:SetFullWidth(true)
        return r
    end

    for i, row in ipairs(rows) do
        if row.group and row.group ~= ctx.lastGroup then
            flushRow()                 -- previous group's tail row
            Helpers.Section(ctx, row.group)
            ctx.lastGroup = row.group
        end

        -- row.solo = true means "render this widget alone in the left
        -- half of its own row, leaving the right half empty." Used for
        -- visually-grouping pivots.
        if row.solo and pendingCount > 0 then
            flushRow()
        end

        if not pendingRow then pendingRow = startRow() end
        Helpers.RenderField(ctx, row, pendingRow, 0.5)
        pendingCount = pendingCount + 1
        if row.solo or pendingCount >= 2 then flushRow() end

        local nextRow = rows[i + 1]
        if afterGroup and row.group
           and (not nextRow or nextRow.group ~= row.group)
           and afterGroup[row.group] then
            flushRow()                 -- afterGroup buttons start fresh
            afterGroup[row.group](ctx)
            afterGroup[row.group] = nil  -- one-shot
        end
    end
    flushRow()
    if scroll.DoLayout then scroll:DoLayout() end
end

-- ---------------------------------------------------------------------
-- Reset / refresh
-- ---------------------------------------------------------------------

-- Reset every Schema entry for `pageKey` back to its default. Used by
-- the per-panel Defaults button.
function Helpers.RestoreDefaults(pageKey, ctx)
    for _, row in ipairs(AddonTable.SchemaForPage(pageKey)) do
        AddonTable.ApplyDefault(row)
    end
    if ctx and ctx.refreshers then
        for _, fn in ipairs(ctx.refreshers) do pcall(fn) end
    end
end

-- Reset every schema-driven page (general / bar / border / font) to its
-- per-row default. Profiles is skipped on purpose — resetting profiles
-- would delete user data. After resetting, every open panel's
-- refreshers run so live widgets reflect the new state.
function Helpers.RestoreAllDefaults()
    for _, row in ipairs(AddonTable.Schema or {}) do
        if row.page ~= "profiles" then
            AddonTable.ApplyDefault(row)
        end
    end
    Helpers.RefreshAllPanels()
end

-- Refresh every widget on every panel ctx — called after a slash-cmd
-- /at set so an open panel reflects the new value immediately, and
-- after a profile change so widgets re-read from the new profile.
function Helpers.RefreshAllPanels()
    for _, ctx in ipairs(renderedPanels) do
        for _, fn in ipairs(ctx.refreshers) do pcall(fn) end
    end
end

-- ---------------------------------------------------------------------
-- About page (top-level "Ka0s Absorb Tracker")
-- ---------------------------------------------------------------------

local function getMetadata(field)
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(AddonName, field)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(AddonName, field)
    end
end

local function addBlock(scroll, height)
    local AceGUI = LibStub("AceGUI-3.0")
    local sp = AceGUI:Create("SimpleGroup")
    sp:SetLayout(nil)
    sp:SetFullWidth(true)
    sp:SetHeight(height)
    scroll:AddChild(sp)
    return sp
end

local function buildMainContent(ctx)
    local AceGUI = LibStub("AceGUI-3.0")
    local scroll = ensureScroll(ctx)

    -- 1) Logo. SimpleGroup is a full-width child so AceGUI's List
    -- layout gives it the scroll's full width to live in; the texture
    -- inside is anchored TOPLEFT, sized to the source TGA's native
    -- dimensions, so it renders pixel-exact and left-aligned regardless
    -- of panel width.
    local logoGroup = AceGUI:Create("SimpleGroup")
    logoGroup:SetLayout(nil)
    logoGroup:SetFullWidth(true)
    logoGroup:SetHeight(MAIN_LOGO_SIZE)

    local logoTex = logoGroup.frame:CreateTexture(nil, "ARTWORK")
    logoTex:SetTexture(LOGO_PATH)
    logoTex:SetSize(MAIN_LOGO_SIZE, MAIN_LOGO_SIZE)
    logoTex:SetPoint("TOPLEFT", logoGroup.frame, "TOPLEFT", 0, 0)
    scroll:AddChild(logoGroup)

    addBlock(scroll, MAIN_GAP_AFTER_LOGO)

    -- 2) One-liner — full-width Label, left-aligned, GameFontHighlight.
    local notes = getMetadata("Notes") or ""
    if notes ~= "" then
        local desc = AceGUI:Create("Label")
        desc:SetFullWidth(true)
        desc:SetText(notes)
        if desc.label and desc.label.SetFontObject and _G.GameFontHighlight then
            desc.label:SetFontObject(_G.GameFontHighlight)
        end
        if desc.label and desc.label.SetJustifyH then
            desc.label:SetJustifyH("LEFT")
        end
        scroll:AddChild(desc)

        addBlock(scroll, MAIN_GAP_AFTER_DESC)
    end

    -- 3) Separator + "Slash Commands" heading: a single AceGUI Heading
    -- widget renders as a label flanked by side dividers, so this one
    -- widget delivers both the visual separator and the section title.
    local heading = AceGUI:Create("Heading")
    heading:SetFullWidth(true)
    heading:SetHeight(SECTION_HEADING_H)
    heading:SetText("Slash Commands")
    if heading.label and heading.label.SetFontObject and _G.GameFontNormalLarge then
        heading.label:SetFontObject(_G.GameFontNormalLarge)
    end
    scroll:AddChild(heading)

    addBlock(scroll, MAIN_GAP_BELOW_HEAD)

    -- 4) Slash-command rows pulled from AddonTable.SlashCommands so
    -- this list stays in lockstep with /at help — adding a command in
    -- SlashCommands.lua surfaces here automatically.
    for _, entry in ipairs(AddonTable.SlashCommands or {}) do
        local r = AceGUI:Create("Label")
        r:SetFullWidth(true)
        r:SetText(("|cffffff00/at %s|r  |cffffffff—|r  %s")
            :format(entry[1], entry[2]))
        if r.label and r.label.SetJustifyH then
            r.label:SetJustifyH("LEFT")
        end
        scroll:AddChild(r)
    end

    if scroll.DoLayout then scroll:DoLayout() end
end

-- ---------------------------------------------------------------------
-- Page registration (file-load-time)
-- ---------------------------------------------------------------------

--- Register a sub-page builder.
-- @param key       Unique short key ("general", "bar", ...).
-- @param name      Display name shown in Blizzard Settings as the
--                  sub-page title.
-- @param builder   function(mainCategory) -> sub-category | nil. Called
--                  at PLAYER_LOGIN once db is ready. Return nil to skip
--                  the page (e.g. AceDBOptions missing → no Profiles).
-- @param opts      Optional { isDefault = true } to mark this page as
--                  the one `/at config` opens.
function AddonTable.RegisterOptionsPage(key, name, builder, opts)
    pendingPages[#pendingPages + 1] = {
        key       = key,
        name      = name,
        builder   = builder,
        isDefault = opts and opts.isDefault,
    }
end

-- ---------------------------------------------------------------------
-- PLAYER_LOGIN-time registration
-- ---------------------------------------------------------------------

local function registerMain()
    if not (Settings and Settings.RegisterCanvasLayoutCategory
            and Settings.RegisterAddOnCategory) then
        return
    end

    local mainCtx = Helpers.CreatePanel("AbsorbTrackerMainPanel", PARENT_TITLE,
        { isMain = true })

    -- Defer body render until first OnShow: AceGUI's ScrollFrame lays
    -- out children against the parent's current width, which is zero at
    -- PLAYER_LOGIN, and there's no point building widgets for a panel
    -- the user may never open.
    local mainRendered = false
    mainCtx.panel:SetScript("OnShow", function()
        if mainRendered then return end
        mainRendered = true
        buildMainContent(mainCtx)
    end)

    mainCategory   = Settings.RegisterCanvasLayoutCategory(mainCtx.panel, PARENT_TITLE)
    Settings.RegisterAddOnCategory(mainCategory)
    mainCategoryID = mainCategory:GetID()
end

function AddonTable.CreateOptionsPanel()
    if not LibStub then return end
    local AceGUI = LibStub("AceGUI-3.0", true)
    if not AceGUI then
        print("AceGUI-3.0 not available; settings panel unavailable.")
        return
    end

    AddonTable.ValidateSchema()

    registerMain()
    if not mainCategory then return end

    for _, page in ipairs(pendingPages) do
        local sub = page.builder(mainCategory)
        if sub then
            subCategoriesByKey[page.key] = sub
            if page.isDefault and sub.GetID then
                defaultCategoryID = sub:GetID()
            end
        end
    end
end

-- ---------------------------------------------------------------------
-- Open / refresh
-- ---------------------------------------------------------------------

function AddonTable.OpenOptionsPanel()
    -- Settings UI is protected during combat.
    if InCombatLockdown() then
        print("Cannot open settings panel during combat. Try again after combat ends.")
        return
    end
    if not (Settings and Settings.OpenToCategory) then return end
    -- Prefer the page flagged isDefault (General); fall back to the
    -- main category if no default was registered.
    local target = defaultCategoryID or mainCategoryID
    if target then Settings.OpenToCategory(target) end
end

-- AceDB profile changes (OnProfileChanged callback in Events.lua) call
-- this so any open page re-reads its values from the new profile. /at
-- set, /at reset, and /at resetall also call this so an open panel
-- reflects the change immediately.
function AddonTable.RefreshOptionsPanel()
    Helpers.RefreshAllPanels()
end
