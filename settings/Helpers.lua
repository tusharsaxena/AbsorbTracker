-- AbsorbTracker: settings/Helpers.lua
--
-- Settings-panel toolkit. Layout constants, header builder, the
-- canvas-frame factory (Helpers.CreatePanel), section heading, inline
-- button pair, the lazy AceGUI scroll factory, tooltip plumbing, and
-- the panel registry that drives RestoreDefaults / RestoreAllDefaults
-- / RefreshAllPanels.
--
-- Decorates NS.Helpers, which OptionsPanel.lua publishes empty
-- before this file loads. Other Panel/*.lua slices (ScrollPatch /
-- Widgets / About) extend the same Helpers table; Options/*.lua
-- consume it at PLAYER_LOGIN to build their pages.

local addonName, NS = ...

local print = NS.Print
local Helpers = NS.Helpers

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

-- Relative width of each button in a cell-filling paired-button row
-- (options-ui-§8). A flat 0.5/0.5 lets AceGUI's Flow layout push the right
-- button's border into the ScrollFrame's clip rectangle, shaving it; the
-- 0.492 inset clears the clip while staying visually a 50/50 split.
local BUTTON_PAIR_REL      = 0.492

-- Cross-slice constants that Panel/Widgets.lua and Panel/About.lua need
-- to read. Exposed on Helpers rather than copied into each file so the
-- spacing stays in lockstep across the whole panel.
Helpers.ROW_VSPACER       = ROW_VSPACER
Helpers.SECTION_HEADING_H = SECTION_HEADING_H
Helpers.BUTTON_PAIR_REL   = BUTTON_PAIR_REL

-- ---------------------------------------------------------------------
-- Panel registry — every CreatePanel ctx is appended here so
-- RefreshAllPanels can re-run their refreshers after a profile change
-- or /at set.
-- ---------------------------------------------------------------------

local renderedPanels = {}

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
-- Spacer — invisible full-width AceGUI row used between sections,
-- between widget rows, and between blocks on the about page.
-- ---------------------------------------------------------------------

local function addSpacer(scroll, height)
    local AceGUI = NS.AceGUI
    local sp = AceGUI:Create("SimpleGroup")
    sp:SetLayout(nil)
    sp:SetFullWidth(true)
    sp:SetHeight(height)
    scroll:AddChild(sp)
end
Helpers.AddSpacer = addSpacer

-- ---------------------------------------------------------------------
-- Header (title + Defaults button + divider)
-- ---------------------------------------------------------------------

local function buildHeader(panel, title, opts)
    -- Sub-pages render with a "Ka0s Absorb Tracker ▸ <Page>" breadcrumb
    -- prefix. The separator is an inline atlas escape (|A:atlas:h:w|a),
    -- not a font glyph, so it renders the same regardless of the
    -- FontString's font or any locale fallback. The parent/main page
    -- opts in to the unprefixed form via opts.isMain (otherwise it
    -- would read "Ka0s Absorb Tracker ▸ Ka0s Absorb Tracker"). The
    -- Blizzard left-tree label is driven by panel.name in CreatePanel
    -- and stays unprefixed so the tree indents under the parent without
    -- visual repetition.
    local PARENT_TITLE = NS.PARENT_TITLE or ""
    local displayTitle = title
    if not opts.isMain then
        local sep = " |A:common-icon-forwardarrow:16:16|a "
        displayTitle = PARENT_TITLE .. sep .. title
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

    -- The Defaults button is only DECLARED here, never created — the widget
    -- is built on the panel's first OnShow by Helpers.EnsureDefaultsButton
    -- below (read the comment there before "simplifying" this back).
    panel.wantsDefaultsButton = opts.defaultsButton and true or false
    panel.defaultsTooltip     = opts.defaultsTooltip

    return titleFS, divider
end

-- ---------------------------------------------------------------------
-- EnsureDefaultsButton — builds the header's Defaults button once, on
-- the owning panel's FIRST OnShow. Idempotent; a no-op on a panel that
-- did not ask for one.
-- ---------------------------------------------------------------------

-- WHY this is lazy, and why it must stay that way (options-ui-§5,
-- anti-patterns #42):
--
-- AceGUI-3.0 is a SHARED library — whichever copy loads first serves every
-- addon in the session. UI-skinning addons (ElvUI, AddOnSkins, Masque-likes)
-- restyle AceGUI widgets by hooking `AceGUI:RegisterAsWidget`. A widget
-- created BEFORE that hook is installed never passes through it, so it keeps
-- Blizzard's stock `UI-Panel-Button-Up` art — the red stone button — for the
-- rest of the session, while every widget created afterwards comes out
-- skinned.
--
-- Page builders run at enable time (CreateOptionsPanel, driven by
-- PLAYER_LOGIN off ADDON_LOADED), i.e. still inside the load window. Creating
-- the button there is a straight race against every other addon's load order:
-- this addon wins it only because it happens to sort after the skinner today.
-- Rename the folder, or add a skin, and the identical code renders red.
--
-- First OnShow is after every addon has loaded, so the race is gone. It is
-- also the same deferral the panel BODY already uses (for the separate reason
-- that ctx.body has 0 width at enable time) — the two are unrelated causes
-- with the same fix, so do not collapse the reasoning.
function Helpers.EnsureDefaultsButton(panel)
    if not panel then return end
    if panel.defaultsBtn or not panel.wantsDefaultsButton then return end

    local AceGUI = NS.AceGUI
    if not AceGUI then return end

    local defaultsBtn = AceGUI:Create("Button")
    if not (defaultsBtn and defaultsBtn.frame) then return end
    defaultsBtn:SetText("Defaults")
    defaultsBtn:SetWidth(DEFAULTS_W)
    defaultsBtn.frame:SetParent(panel)
    defaultsBtn.frame:ClearAllPoints()
    defaultsBtn.frame:SetPoint("TOPRIGHT", panel, "TOPRIGHT",
                               -PADDING_X, -HEADER_TOP)
    defaultsBtn.frame:Show()
    attachTooltip(defaultsBtn, "Defaults", panel.defaultsTooltip)

    panel.defaultsBtn = defaultsBtn

    -- The page builder parks its click handler on the panel (the button did
    -- not exist when it ran), so it is wired up here.
    if panel.defaultsOnClick then
        defaultsBtn:SetCallback("OnClick", panel.defaultsOnClick)
    end
end

-- ---------------------------------------------------------------------
-- CreatePanel — Frame compatible with RegisterCanvasLayoutSubcategory
-- with the unified header stamped on top. Returns a `ctx` table the
-- caller threads through Section / RenderField / RenderSchema /
-- InlineButtonPair / RestoreDefaults.
-- ---------------------------------------------------------------------

function Helpers.CreatePanel(name, title, opts)
    opts = opts or {}

    local panel = CreateFrame("Frame", name)
    panel.name = title
    panel:Hide()

    -- No defaultsBtn here: buildHeader only records whether this panel wants
    -- one; Helpers.EnsureDefaultsButton creates it on first OnShow.
    local titleFS, divider = buildHeader(panel, title, opts)
    panel.title   = titleFS
    panel.divider = divider

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
-- ensureScroll — lazy AceGUI ScrollFrame parented to ctx.body. The
-- always-visible-scrollbar override (Helpers.PatchAlwaysShowScrollbar)
-- lives in Panel/ScrollPatch.lua; this function calls it after the
-- scroll is created so every panel's scrollbar gutter stays consistent.
-- ---------------------------------------------------------------------

local function ensureScroll(ctx)
    if ctx.scroll then return ctx.scroll end
    local AceGUI = NS.AceGUI
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

    if Helpers.PatchAlwaysShowScrollbar then
        Helpers.PatchAlwaysShowScrollbar(scroll)
    end

    ctx.scroll = scroll
    return scroll
end
Helpers.EnsureScroll = ensureScroll

-- ---------------------------------------------------------------------
-- Section heading — AceGUI Heading (full-width label flanked by side
-- divider textures).
-- ---------------------------------------------------------------------

function Helpers.Section(ctx, label)
    local scroll = ensureScroll(ctx)
    local AceGUI = NS.AceGUI

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
-- Inline action buttons (not settings)
-- ---------------------------------------------------------------------

-- Two side-by-side action buttons sharing one Flow row, each inset to
-- BUTTON_PAIR_REL so the right button clears the ScrollFrame clip
-- (options-ui-§8). Each spec is { text = ..., tooltip = ..., onClick = function }.
function Helpers.InlineButtonPair(ctx, leftSpec, rightSpec)
    local AceGUI = NS.AceGUI
    local scroll = ensureScroll(ctx)

    local row = AceGUI:Create("SimpleGroup")
    row:SetLayout("Flow")
    row:SetFullWidth(true)
    row:SetHeight(28)

    local function makeBtn(spec)
        if not spec then return end
        local btn = AceGUI:Create("Button")
        btn:SetText(spec.text or "")
        btn:SetRelativeWidth(BUTTON_PAIR_REL)
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
-- Reset / refresh
-- ---------------------------------------------------------------------

-- Reset every Schema entry for `pageKey` back to its default. Used by
-- the per-panel Defaults button.
function Helpers.RestoreDefaults(pageKey, ctx)
    for _, row in ipairs(NS.SchemaForPage(pageKey)) do
        NS.ApplyDefault(row)
    end
    if ctx and ctx.refreshers then
        for _, fn in ipairs(ctx.refreshers) do pcall(fn) end
    end
end

-- Reset every schema-driven page (general / bar / border / font) to its
-- per-row default, clear the saved bar position (recentering the bar),
-- then refresh every open panel so live widgets reflect the new state.
-- Profiles is skipped on purpose — resetting profiles would delete user
-- data. This is the single "reset all" implementation; both the "Reset
-- All Settings" popup and the `/at resetall` slash command call it, so
-- the two can never diverge (they historically did on position).
function Helpers.RestoreAllDefaults()
    for _, row in ipairs(NS.Schema or {}) do
        if row.page ~= "profiles" then
            NS.ApplyDefault(row)
        end
    end
    -- Clear the saved position and recenter. `position` is not a schema
    -- row (it's set by dragging the bar), so ApplyDefault above never
    -- touches it — it must be cleared explicitly.
    if NS.db and NS.db.profile then
        NS.db.profile.position = nil
    end
    NS.bus:SendMessage(NS.MSG.POSITION)
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
-- LibSharedMedia values factory — returns a deferred closure that
-- pulls the live LSM hash table at dropdown-render time. Used by every
-- LSM-backed schema row (Options/Bar.lua / Border.lua / Font.lua).
-- ---------------------------------------------------------------------

function Helpers.LSMValues(mediaType)
    return function()
        local LSM = NS.GetLSM()
        local list, out = LSM and LSM:HashTable(mediaType) or {}, {}
        for k in pairs(list) do out[k] = k end
        return out
    end
end
