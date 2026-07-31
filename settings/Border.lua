-- AbsorbTracker: settings/Border.lua
--
-- Border sub-page: style, thickness, color (with class-color toggle).
--
-- Layout produces:
--     [Border Style]  | [Border Thickness (in px)]
--     [Border Color]  | [Use Class Color]

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
            path    = p .. "border",
            page    = "border",
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
            page    = "border",
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
            path    = p .. "useClassColorBorder",
            page    = "border",
            unit    = unit,
            group   = "Border",
            order   = 40,
            type    = "bool",
            label   = "Use Class Color",
            desc    = "Use your class color for the border. Grays out the Border Color picker.",
            default = unitDefaults.useClassColorBorder,
        },
        {
            path     = p .. "borderColor",
            page     = "border",
            unit     = unit,
            group    = "Border",
            order    = 30,
            type     = "color",
            label    = "Border Color",
            desc     = "RGBA border color (only used when Use Class Color is off).",
            default  = unitDefaults.borderColor,
            hasAlpha = true,
            disabledIf = p .. "useClassColorBorder",
        },
    }

    NS.RegisterSchemaRows(rows)
end

for _, unit in ipairs(NS.Units.LIST) do addUnitRows(unit) end

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local H   = NS.Helpers
    local ctx = H.CreatePanel("AbsorbTrackerBorderPanel", "Border", {
        pageKey         = "border",
        defaultsButton  = true,
        defaultsTooltip = "Restore every Border setting on this profile to its addon default.",
    })
    -- Parked, not wired: the Defaults button does not exist yet — it is built
    -- on first OnShow (see Helpers.EnsureDefaultsButton).
    ctx.panel.defaultsOnClick = function()
        H.RestoreDefaults("border", ctx)
    end

    ctx.panel:SetScript("OnShow", function()
        H.EnsureDefaultsButton(ctx.panel)
        H.RenderUnitPanel(ctx, "border")
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "Border")
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage("border", "Border", build)
end
