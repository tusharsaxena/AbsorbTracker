-- AbsorbTracker: settings/Bar.lua
--
-- Bar sub-page: dimensions, fill texture/color, background texture/color.
-- Class-color toggles use disabledIf to grey out the matching color
-- picker when their toggle is on.
--
-- Layout produces:
--     [Bar Width]          | [Bar Height]
--     [Bar Texture]
--     [Bar Color]          | [Use Class Color]
--     [Background Texture]
--     [Background Color]   | [Use Class Color]

local addonName, NS = ...

local unitDefaults = NS.unitDefaults

-- Every row below is generated once per unit in NS.Units.LIST: the path is prefixed with
-- `units.<unit>.` and tagged `unit = unit`, so Helpers.RenderUnitPanel can filter the page to
-- the currently-selected unit (settings/Schema.lua: SchemaForPage). The `default =` values come
-- from NS.unitDefaults so all three units share one canonical default.
local function addUnitRows(unit)
    local p = "units." .. unit .. "."
    local rows = {
        {
            path    = p .. "enabled",
            page    = "bar",
            unit    = unit,
            alwaysPerUnit = true,   -- stays editable even while this unit mirrors the player
            group   = "This bar",
            order   = 10,
            type    = "bool",
            label   = "Enable this bar",
            desc    = "Track and display absorbs for this unit.",
            default = (unit == "player"),
            solo    = true,
            onChange = function()
                NS.bus:SendMessage(NS.MSG.APPEARANCE)
                NS.bus:SendMessage(NS.MSG.REPAINT)
            end,
        },
        {
            path    = p .. "barWidth",
            page    = "bar",
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
            page    = "bar",
            unit    = unit,
            group   = "Size",
            order   = 20,
            type    = "number",
            label   = "Bar Height (in px)",
            desc    = "Height of the absorb bar in pixels.",
            default = unitDefaults.barHeight,
            min = 10, max = 100, step = 1, fmt = "%d px",
        },
        {
            path    = p .. "barTexture",
            page    = "bar",
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
            page     = "bar",
            unit     = unit,
            group    = "Bar",
            order    = 20,
            type     = "color",
            label    = "Bar Color",
            desc     = "RGBA fill color for the bar (only used when Use Class Color is off).",
            default  = unitDefaults.barColor,
            hasAlpha = true,
            disabledIf = p .. "useClassColorBar",
        },
        {
            path    = p .. "useClassColorBar",
            page    = "bar",
            unit    = unit,
            group   = "Bar",
            order   = 30,
            type    = "bool",
            label   = "Use Class Color",
            desc    = "Use your class color for the bar fill. Greys out the Bar Color picker.",
            default = unitDefaults.useClassColorBar,
        },
        {
            path    = p .. "bgTexture",
            page    = "bar",
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
            page     = "bar",
            unit     = unit,
            group    = "Background",
            order    = 20,
            type     = "color",
            label    = "Background Color",
            desc     = "RGBA color drawn behind the bar (only used when Use Class Color is off).",
            default  = unitDefaults.bgColor,
            hasAlpha = true,
            disabledIf = p .. "useClassColorBg",
        },
        {
            path    = p .. "useClassColorBg",
            page    = "bar",
            unit    = unit,
            group   = "Background",
            order   = 30,
            type    = "bool",
            label   = "Use Class Color",
            desc    = "Use a darkened class color for the background. Greys out the Background Color picker.",
            default = unitDefaults.useClassColorBg,
        },
    }

    -- The mirror flag. Not rendered in the page body — Helpers.RenderUnitPanel draws it as a
    -- header checkbox — but kept in the schema so `/at set units.focus.mirror false` works.
    -- The player is the mirror SOURCE and gets no row.
    if unit ~= "player" then
        rows[#rows + 1] = {
            path       = p .. "mirror",
            page       = "bar",
            unit       = unit,
            alwaysPerUnit = true,
            skipRender = true,
            group      = "This bar",
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
    local ctx = H.CreatePanel("AbsorbTrackerBarPanel", "Bar", {
        pageKey         = "bar",
        defaultsButton  = true,
        defaultsTooltip = "Restore every Bar setting on this profile to its addon default.",
    })
    -- Parked, not wired: the Defaults button does not exist yet — it is built
    -- on first OnShow (see Helpers.EnsureDefaultsButton).
    ctx.panel.defaultsOnClick = function()
        H.RestoreDefaults("bar", ctx)
    end

    local rendered = false
    ctx.panel:SetScript("OnShow", function()
        H.EnsureDefaultsButton(ctx.panel)
        if rendered then return end
        rendered = true
        H.RenderSchema(ctx, "bar")
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "Bar")
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage("bar", "Bar", build)
end
