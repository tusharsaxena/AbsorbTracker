-- AbsorbTracker: settings/Appearance.lua
--
-- The one per-unit appearance page. It replaces the three that used to stand beside each other --
-- settings/Bar.lua, settings/Border.lua and settings/Font.lua -- and the reason is the Unit picker,
-- not the row count: each of those pages carried its OWN copy of it, `ctx.unit` is per-panel state,
-- and so styling the target bar meant picking "Target" three times. options-ui-§14 says the picker
-- belongs in the page banner and that there must be exactly ONE of it; one banner over one page is
-- the shape that rule describes.
--
-- The page draws (settings/UnitPanel.lua does the drawing):
--
--     [ Unit v ]                                  <- the banner (chrome), options-ui-§14
--     ------------------------------------------
--     [ Size ][ Bar ][ Background ][ Border ][ Text ]   <- the tab strip (chrome), options-ui-§13
--
--     Size         [Bar Width]              [Bar Height]
--     Bar          [Bar texture]            [Bar opacity]
--                  [Bar color]              [Use class color]
--     Background   [Background Texture]
--                  [Background color]       [Use class color]
--     Border       [Border style]           [Border thickness (px)]
--                  [Border color]           [Use class color]
--     Text         [Font]                   [Font size]
--                  [Font color]             [Use class color]
--                  [Font flags]             [Font shadow]
--
-- THREE OF THE FIVE TABS ARE COMPOSED, NOT TYPED OUT (options-ui-§16). H.BarGroup, H.BorderGroup and
-- H.FontGroup emit the canonical block from one declaration each, and H.ColorPair emits the
-- Background tab's swatch and its companion. A hand-written copy of any of them is anti-pattern #73:
-- the composer is what makes the order, the labels, the ranges and the class-color companion
-- identical in nine addons without nine people agreeing to be careful.
--
-- NOTHING STORED MOVED. `keys` and `defaults` carry this addon's own paths and starting values into
-- the composer, so `units.<unit>.border` is still `border` (not `borderStyle`) and
-- `useClassColorText` is still `useClassColorText` (not `useClassColorFont`). What changed is what
-- is DECLARED and how it is laid out -- labels, tooltips, ranges and line breaks.
--
-- WHAT THE COMPOSERS ADDED. `fontShadow` is a new stored key: the canonical font block has six rows
-- and this addon had five. It is honored in modules/Display.lua's appearance pass, beside SetFont,
-- because a setting that is declared and not honored is worse than one that is absent.
--
-- WHAT WENT. `barTexture` carried `solo = true` purely to keep the Bar tab's pairs from splitting
-- across lines -- a parity count done by hand, which any added row would have broken silently. The
-- composer's `startsLine` does that job properly and by construction, so the flag is gone. So are
-- this file's private `fontFlagOptions` / `fontFlagSorting` tables: the flag set is H.FONT_FLAGS
-- now, which is the whole point of having one.
--
-- THE BACKGROUND TAB IS NOT A BAR GROUP, and options-ui-§16 says so: a group over a background takes
-- the swatch and its companion and nothing else. Its texture row survives because this addon's
-- backdrop genuinely HAS a fill texture (modules/Display.lua sets `backdropInfo.bgFile` from it) --
-- it is a control wired to something, not a texture picker invented to fill a tab out. It carries no
-- `subgroup`, for the same reason none of the other four tabs does: options-ui-§7 asks for a
-- subsection heading only where a tab MIXES KINDS of control, and every row on every tab here
-- belongs to that tab's one subject. A `subgroup` repeating its tab's name is forbidden outright.
--
-- TAB ORDER IS DECLARATION ORDER. H.RenderTabbedSchema partitions a page's rows by `group` in the
-- order the rows were registered, so the array below IS the strip, and each group's rows must stay
-- contiguous -- a row filed under a group the page has already left prints that heading twice.
--
-- Size leads because dimensions are what a player opens this page for; the three surface tabs
-- (Bar / Background / Border) sit in a run because they are read together, front to back; Text is
-- last because it is set once. The three colored surfaces plus Text all run the SAME two lines --
-- `[<surface> color] [Use class color]` -- so a reader who has learned one tab has learned four.
--
-- Every row is generated once per unit in NS.Units.LIST: the path is prefixed with `units.<unit>.`
-- and tagged `unit = unit`, so Helpers.RenderUnitPanel can filter the page to the selected unit
-- (settings/Schema.lua: SchemaForPage). The `default =` values come from NS.unitDefaults so all
-- three units share one canonical default.

local addonName, NS = ...

local unitDefaults = NS.unitDefaults

local H = NS.Helpers

local PAGE = "appearance"

-- NO `disabledIf` ON ANY COLOR ROW, and that is a reversal worth stating.
--
-- Each of these four swatches used to gray itself out while its "Use class color" partner was on,
-- and each toggle's own desc advertised that it would. The argument was that a control the code is
-- not currently reading should say so. What it cost is the ordinary order of operations: setting a
-- color BEFORE deciding you want the class one is normal, and a grayed swatch makes that a
-- two-visit job -- turn the toggle off, set the color, turn the toggle back on.
--
-- The half of the old argument that survives is that the row IS unread under the other mode, and
-- that is what the tooltip says now instead of graying the widget. The alpha channel was always live
-- (core/Data.lua's color getters take the class RGB and keep the swatch's `a`), so the swatch was
-- never fully dead even under the old design -- which is the clearest evidence the graying was
-- overstating the case. The composers carry that sentence for us now (H.CLASS_COLOR_NOTE), and
-- options-ui-§17 forbids `disabledIf` on a color row outright. `disabledIf` itself is untouched, and
-- is a LibKa0s-Options-1.0 feature this addon simply no longer asks for; tests/test_widgets.lua
-- still pins it against a synthetic row.

-- WHICH CLASS, declared rather than inferred (options-ui-§17). All four surfaces on this page paint
-- one tracked unit's bar, so all four resolve to THAT unit's class -- not the player's, which is
-- what all four did before this pass. The path prefix is not what decides it and could not be: a
-- control stored under `units.<unit>.` that drew the player's own spells would be player-scoped.
-- This declaration is what an audit reads, and core/Data.lua's getters pass the same unit token.
local function classColorFor(unit)
    return { source = "unit", unit = unit }
end

-- The composers return plain arrays of ordinary schema rows and stamp nothing of ours on them.
-- `unit` is this addon's own field -- settings/Schema.lua's SchemaForPage filters the page on it --
-- so it is added here, once, rather than wished for upstream.
local function appendBlock(rows, unit, block)
    for _, row in ipairs(block) do
        row.unit = unit
        rows[#rows + 1] = row
    end
end

local LSM_KIND = {
    LSM30_Statusbar = "statusbar",
    LSM30_Border    = "border",
    LSM30_Font      = "font",
}

-- UPSTREAM DEFECT, WORKED AROUND ON OUR OWN ROWS. OptionsCompose minor 1 declares each media-backed
-- row as `values = function() return O.LSMValues(kind) end` -- a closure returning a CLOSURE, where
-- the flow engine's `enumList` calls it once and expects a table. It gets a function, its
-- `type(v) ~= "table"` arm answers an empty list, and its own "no options" report is gated on
-- `row.values == nil`, so the dropdown renders with nothing in it and nothing says why.
--
-- Corrected on the ROW, which is ours, and never in libs/, which is not: a downstream patch is
-- overwritten by the next re-vendor and takes the fix with it. Reported upstream to LibKa0s; delete
-- this the re-vendor after the fix lands. tests/test_schema.lua pins that every media row answers a
-- populated list, so this cannot rot silently in either direction.
local function fixMediaValues(rows)
    for _, row in ipairs(rows) do
        local kind = LSM_KIND[row.dialogControl]
        if kind then row.values = H.LSMValues(kind) end
    end
    return rows
end

local function addUnitRows(unit)
    local p = "units." .. unit .. "."
    local classColor = classColorFor(unit)

    -- ── Size ──────────────────────────────────────────────────────────────────
    --
    -- Hand-written, and legitimately so: options-ui-§16 names three canonical blocks and a
    -- width/height pair is none of them, so there is no composer to reach for.
    local rows = {
        {
            path    = p .. "barWidth",
            page    = PAGE,
            unit    = unit,
            group   = "Size",
            order   = 10,
            type    = "number",
            label   = "Bar Width (in px)",
            desc    = "Width of the absorb bar in pixels.",
            default = unitDefaults.barWidth,
            min = 50, max = 500, step = 1, fmt = "%d px",
        },
        {
            path    = p .. "barHeight",
            page    = PAGE,
            unit    = unit,
            group   = "Size",
            order   = 20,
            type    = "number",
            label   = "Bar Height (in px)",
            desc    = "Height of the absorb bar in pixels.",
            default = unitDefaults.barHeight,
            min = 10, max = 100, step = 1, fmt = "%d px",
        },
    }

    -- ── Bar ───────────────────────────────────────────────────────────────────
    --
    -- The canonical bar block: [Bar texture][Bar opacity] / [Bar color][Use class color]. Every leaf
    -- name the composer derives already IS this addon's stored path, so no `keys` is needed.
    --
    -- `barAlpha` is the PER-UNIT opacity and stays here. It is not Master alpha, which is the
    -- addon-wide row on the General page's Master controls tab (options-ui-§15 forbids conflating
    -- the two); NS.GetBarAlpha multiplies them.
    appendBlock(rows, unit, fixMediaValues(H.BarGroup({
        prefix     = p,
        page       = PAGE,
        group      = "Bar",
        order      = 10,
        classColor = classColor,
        defaults   = {
            barTexture       = unitDefaults.barTexture,
            barAlpha         = unitDefaults.barAlpha,
            barColor         = unitDefaults.barColor,
            useClassColorBar = unitDefaults.useClassColorBar,
        },
    })))

    -- ── Background ────────────────────────────────────────────────────────────
    --
    -- The texture is this addon's own row, declared ahead of the pair rather than handed over as the
    -- composer's `extra`: an extra is appended AFTER the mandated rows, and the texture reads first
    -- here for the same reason it does on the Bar tab. The swatch carries `startsLine`, so the pair
    -- lands on its own line whatever precedes it.
    rows[#rows + 1] = {
        path    = p .. "bgTexture",
        page    = PAGE,
        unit    = unit,
        group   = "Background",
        order   = 10,
        type    = "string",
        label   = "Background Texture",
        desc    = "LibSharedMedia statusbar texture drawn behind the bar fill.",
        default = unitDefaults.bgTexture,
        dialogControl = "LSM30_Statusbar",
        values = H.LSMValues("statusbar"),
    }
    appendBlock(rows, unit, H.ColorPair({
        prefix       = p,
        page         = PAGE,
        group        = "Background",
        order        = 20,
        key          = "bgColor",
        companionKey = "useClassColorBg",
        label        = "Background color",
        classColor   = classColor,
        defaults     = {
            bgColor         = unitDefaults.bgColor,
            useClassColorBg = unitDefaults.useClassColorBg,
        },
    }))

    -- ── Border ────────────────────────────────────────────────────────────────
    --
    -- No `show = true`: this addon has no "Show border" toggle, and §16 only permits the composer to
    -- prepend one where the addon already has it. Inventing one would be a second control over a
    -- surface the border style's own "None" entry already turns off.
    --
    -- `keys` keeps the stored path `units.<unit>.border`, which is what every profile on disk holds
    -- and what `/at set units.player.border` names.
    appendBlock(rows, unit, fixMediaValues(H.BorderGroup({
        prefix     = p,
        page       = PAGE,
        group      = "Border",
        order      = 10,
        classColor = classColor,
        keys       = { borderStyle = "border" },
        defaults   = {
            borderStyle         = unitDefaults.border,
            borderSize          = unitDefaults.borderSize,
            borderColor         = unitDefaults.borderColor,
            useClassColorBorder = unitDefaults.useClassColorBorder,
        },
    })))

    -- ── Text ──────────────────────────────────────────────────────────────────
    --
    -- The canonical font block, six rows over three lines. `keys` keeps `useClassColorText`, the path
    -- this addon has always stored the companion under; `fontShadow` is the one leaf that had no
    -- stored key at all before this pass.
    appendBlock(rows, unit, fixMediaValues(H.FontGroup({
        prefix     = p,
        page       = PAGE,
        group      = "Text",
        order      = 10,
        classColor = classColor,
        keys       = { useClassColorFont = "useClassColorText" },
        defaults   = {
            font              = unitDefaults.font,
            fontSize          = unitDefaults.fontSize,
            fontColor         = unitDefaults.fontColor,
            useClassColorFont = unitDefaults.useClassColorText,
            fontFlags         = unitDefaults.fontFlags,
            fontShadow        = unitDefaults.fontShadow,
        },
    })))

    -- The mirror flag. Not rendered in the page body — Helpers.RenderUnitPanel draws it as a
    -- header checkbox above the tab strip — but kept in the schema so
    -- `/at set units.focus.mirror false` works. The player is the mirror SOURCE and gets no row.
    --
    -- IT CARRIES A GROUP AND STILL DRAWS NO TAB. options-ui-§13 wants every row attributable to a
    -- section, and a group-less row is the authoring defect the library now reports; but this row's
    -- widget is the bespoke mirror header, not a tab's content, so settings/UnitPanel.lua's
    -- partition skips `skipRender` rows when it builds the strip. Naming the subject and drawing no
    -- tab for it is the honest pair — the alternative was a whole tab holding one invisible row.
    if unit ~= "player" then
        rows[#rows + 1] = {
            path       = p .. "mirror",
            page       = PAGE,
            unit       = unit,
            alwaysPerUnit = true,
            skipRender = true,
            group      = "Link",
            order      = 20,
            type       = "bool",
            label      = "Use same styling as Player",
            desc       = "Mirror every Player bar appearance setting. Position and enable stay independent.",
            default    = true,
        }
    end

    NS.RegisterSchemaRows(rows)
end

for _, unit in ipairs(NS.Units.LIST) do addUnitRows(unit) end

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local ctx = H.CreatePanel("AbsorbTrackerAppearancePanel", "Appearance", {
        pageKey         = PAGE,
        defaultsButton  = true,
        defaultsTooltip = "Restore every Appearance setting on this profile to its addon default, on every unit.",
    })
    -- Parked, not wired: the Defaults button does not exist yet — it is built
    -- on first OnShow (see Helpers.EnsureDefaultsButton).
    ctx.panel.defaultsOnClick = function()
        H.RestoreDefaults(PAGE, ctx)
    end

    ctx.panel:SetScript("OnShow", function()
        H.EnsureDefaultsButton(ctx.panel)
        H.RenderUnitPanel(ctx, PAGE)
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "Appearance")
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage(PAGE, "Appearance", build)
end
