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
--     Size         [Bar Width]           [Bar Height]
--     Bar          [Bar Texture]                        (solo)
--                  [Bar Color]           [Use Class Color]
--                  [Bar Opacity]                        (solo)
--     Background   [Background Texture]                 (solo)
--                  [Background Color]    [Use Class Color]
--     Border       [Border Style]        [Border Thickness]
--                  [Border Color]        [Use Class Color]
--     Text         [Font Face]           [Font Size]
--                  [Text Color]          [Use Class Color]
--                  [Font Outline]                       (solo)
--
-- TAB ORDER IS DECLARATION ORDER. H.RenderTabbedSchema partitions a page's rows by `group` in the
-- order the rows were registered, so the array below IS the strip, and each group's rows must stay
-- contiguous -- a row filed under a group the page has already left prints that heading twice.
--
-- Size leads because dimensions are what a player opens this page for; the three surface tabs
-- (Bar / Background / Border) sit in a run because they are read together, front to back; Text is
-- last because it is set once. The three colored surfaces plus Text all run the SAME two lines --
-- `[<surface> Color] [Use Class Color]` -- so a reader who has learned one tab has learned four.
--
-- Every row is generated once per unit in NS.Units.LIST: the path is prefixed with `units.<unit>.`
-- and tagged `unit = unit`, so Helpers.RenderUnitPanel can filter the page to the selected unit
-- (settings/Schema.lua: SchemaForPage). The `default =` values come from NS.unitDefaults so all
-- three units share one canonical default.

local addonName, NS = ...

local unitDefaults = NS.unitDefaults

local PAGE = "appearance"

local fontFlagOptions = {
    [""]                          = "None",
    ["OUTLINE"]                   = "Outline",
    ["THICKOUTLINE"]              = "Thick Outline",
    ["MONOCHROME"]                = "Monochrome",
    ["MONOCHROME, OUTLINE"]       = "Monochrome, Outline",
    ["MONOCHROME, THICKOUTLINE"]  = "Monochrome, Thick Outline",
}

local fontFlagSorting = {
    "", "OUTLINE", "THICKOUTLINE",
    "MONOCHROME", "MONOCHROME, OUTLINE", "MONOCHROME, THICKOUTLINE",
}

-- NO `disabledIf` ON ANY COLOR ROW, and that is a reversal worth stating.
--
-- Each of these three swatches used to gray itself out while its "Use Class Color" partner was on,
-- and each toggle's own desc advertised that it would. The argument was that a control the code is
-- not currently reading should say so. What it cost is the ordinary order of operations: setting a
-- color BEFORE deciding you want the class one is normal, and a grayed swatch makes that a
-- two-visit job -- turn the toggle off, set the color, turn the toggle back on.
--
-- The half of the old argument that survives is that the row IS unread under the other mode, and
-- that is what the desc says now instead of graying the widget. The alpha channel was always live
-- (core/Data.lua's color getters take the class RGB and keep the swatch's `a`), so the swatch was
-- never fully dead even under the old design -- which is the clearest evidence the graying was
-- overstating the case. `disabledIf` itself is untouched, and is a LibKa0s-Options-1.0 feature this
-- addon simply no longer asks for; tests/test_widgets.lua still pins it against a synthetic row.
local function addUnitRows(unit)
    local p = "units." .. unit .. "."
    local rows = {
        -- ── Size ──────────────────────────────────────────────────────────────
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

        -- ── Bar ───────────────────────────────────────────────────────────────
        {
            path    = p .. "barTexture",
            page    = PAGE,
            unit    = unit,
            group   = "Bar",
            order   = 10,
            type    = "string",
            label   = "Bar Texture",
            desc    = "LibSharedMedia statusbar texture used for the bar fill.",
            default = unitDefaults.barTexture,
            dialogControl = "LSM30_Statusbar",
            values = NS.Helpers.LSMValues("statusbar"),
            solo   = true,
        },
        {
            path     = p .. "barColor",
            page     = PAGE,
            unit     = unit,
            group    = "Bar",
            order    = 20,
            type     = "color",
            label    = "Bar Color",
            desc     = "RGBA fill color for the bar. Not read while Use Class Color is on, except for its opacity, which always applies.",
            default  = unitDefaults.barColor,
            hasAlpha = true,
        },
        {
            path    = p .. "useClassColorBar",
            page    = PAGE,
            unit    = unit,
            group   = "Bar",
            order   = 30,
            type    = "bool",
            label   = "Use Class Color",
            desc    = "Use your class color for the bar fill, keeping the opacity set beside it.",
            default = unitDefaults.useClassColorBar,
        },
        {
            -- Promoted out of modules/Display.lua, where the bar's alpha was the literal 1 written
            -- at two paint sites. The default IS that 1, so an install that never touches this row
            -- is drawn exactly as it was. It dims the WHOLE frame -- border and text with the fill
            -- -- which is what makes it a different question from the alpha channel on the three
            -- color swatches, and why it is a row of its own rather than folded into one of them.
            path    = p .. "barAlpha",
            page    = PAGE,
            unit    = unit,
            group   = "Bar",
            order   = 40,
            type    = "number",
            label   = "Bar Opacity",
            desc    = "Overall opacity of the whole bar \226\128\148 fill, background, border and text together.",
            default = unitDefaults.barAlpha,
            min = 0.1, max = 1, step = 0.05, fmt = "%.2f",
            solo    = true,
        },

        -- ── Background ────────────────────────────────────────────────────────
        {
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
            values = NS.Helpers.LSMValues("statusbar"),
            solo   = true,
        },
        {
            path     = p .. "bgColor",
            page     = PAGE,
            unit     = unit,
            group    = "Background",
            order    = 20,
            type     = "color",
            label    = "Background Color",
            desc     = "RGBA color drawn behind the bar. Not read while Use Class Color is on, except for its opacity, which always applies.",
            default  = unitDefaults.bgColor,
            hasAlpha = true,
        },
        {
            path    = p .. "useClassColorBg",
            page    = PAGE,
            unit    = unit,
            group   = "Background",
            order   = 30,
            type    = "bool",
            label   = "Use Class Color",
            desc    = "Use a darkened class color for the background, keeping the opacity set beside it.",
            default = unitDefaults.useClassColorBg,
        },

        -- ── Border ────────────────────────────────────────────────────────────
        {
            path    = p .. "border",
            page    = PAGE,
            unit    = unit,
            group   = "Border",
            order   = 10,
            type    = "string",
            label   = "Border Style",
            desc    = "LibSharedMedia border texture (edge style) used to draw the bar's border.",
            default = unitDefaults.border,
            dialogControl = "LSM30_Border",
            values = NS.Helpers.LSMValues("border"),
        },
        {
            path    = p .. "borderSize",
            page    = PAGE,
            unit    = unit,
            group   = "Border",
            order   = 20,
            type    = "number",
            label   = "Border Thickness (in px)",
            desc    = "Border edge size in pixels.",
            default = unitDefaults.borderSize,
            min = 1, max = 32, step = 1, fmt = "%d px",
        },
        {
            path     = p .. "borderColor",
            page     = PAGE,
            unit     = unit,
            group    = "Border",
            order    = 30,
            type     = "color",
            label    = "Border Color",
            desc     = "RGBA border color. Not read while Use Class Color is on, except for its opacity, which always applies.",
            default  = unitDefaults.borderColor,
            hasAlpha = true,
        },
        {
            path    = p .. "useClassColorBorder",
            page    = PAGE,
            unit    = unit,
            group   = "Border",
            order   = 40,
            type    = "bool",
            label   = "Use Class Color",
            desc    = "Use your class color for the border, keeping the opacity set beside it.",
            default = unitDefaults.useClassColorBorder,
        },

        -- ── Text ──────────────────────────────────────────────────────────────
        {
            path    = p .. "font",
            page    = PAGE,
            unit    = unit,
            group   = "Text",
            order   = 10,
            type    = "string",
            label   = "Font Face",
            desc    = "LibSharedMedia font used for the absorb amount text.",
            default = unitDefaults.font,
            dialogControl = "LSM30_Font",
            values = NS.Helpers.LSMValues("font"),
        },
        {
            path    = p .. "fontSize",
            page    = PAGE,
            unit    = unit,
            group   = "Text",
            order   = 20,
            type    = "number",
            label   = "Font Size",
            desc    = "Absorb-amount text size in pixels.",
            default = unitDefaults.fontSize,
            min = 6, max = 32, step = 1,
        },
        {
            -- The absorb amount had no color row at all: the FontString was created without one and
            -- drew at a FontString's own default, opaque white. That default is what ships here, so
            -- nothing on screen moves for an install that leaves it alone -- and the surface now
            -- reads the same as the three above it.
            path     = p .. "fontColor",
            page     = PAGE,
            unit     = unit,
            group    = "Text",
            order    = 30,
            type     = "color",
            label    = "Text Color",
            desc     = "RGBA color of the absorb amount. Not read while Use Class Color is on, except for its opacity, which always applies.",
            default  = unitDefaults.fontColor,
            hasAlpha = true,
        },
        {
            path    = p .. "useClassColorText",
            page    = PAGE,
            unit    = unit,
            group   = "Text",
            order   = 40,
            type    = "bool",
            label   = "Use Class Color",
            desc    = "Use your class color for the absorb amount, keeping the opacity set beside it.",
            default = unitDefaults.useClassColorText,
        },
        {
            path    = p .. "fontFlags",
            page    = PAGE,
            unit    = unit,
            group   = "Text",
            order   = 50,
            type    = "string",
            label   = "Font Outline",
            desc    = "Outline / monochrome flags applied to the absorb-amount text.",
            default = unitDefaults.fontFlags,
            values  = fontFlagOptions,
            sorting = fontFlagSorting,
            solo    = true,
        },
    }

    -- The mirror flag. Not rendered in the page body — Helpers.RenderUnitPanel draws it as a
    -- header checkbox above the tab strip — but kept in the schema so
    -- `/at set units.focus.mirror false` works. The player is the mirror SOURCE and gets no row.
    --
    -- Deliberately group-less, and now for a second reason on top of the original one. It was left
    -- group-less because RenderRows emits a group's Section heading BEFORE it checks skipRender, so
    -- naming a group would have drawn an empty heading; under RenderTabbedSchema a group here would
    -- be a whole TAB holding one invisible row.
    if unit ~= "player" then
        rows[#rows + 1] = {
            path       = p .. "mirror",
            page       = PAGE,
            unit       = unit,
            alwaysPerUnit = true,
            skipRender = true,
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

    local H   = NS.Helpers
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
