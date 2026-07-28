-- AbsorbTracker: settings/Font.lua
--
-- Font sub-page: face, size, outline.
--
-- Layout produces:
--     [Font Face]    | [Font Size]
--     [Font Outline]                              (solo: 3rd row)

local addonName, NS = ...

local unitDefaults = NS.unitDefaults

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

-- Every row below is generated once per unit in NS.Units.LIST: the path is prefixed with
-- `units.<unit>.` and tagged `unit = unit`, so Helpers.RenderUnitPanel can filter the page to
-- the currently-selected unit (settings/Schema.lua: SchemaForPage). The `default =` values come
-- from NS.unitDefaults so all three units share one canonical default.
local function addUnitRows(unit)
    local p = "units." .. unit .. "."
    local rows = {
        {
            path    = p .. "font",
            page    = "font",
            unit    = unit,
            group   = "Typography",
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
            page    = "font",
            unit    = unit,
            group   = "Typography",
            order   = 20,
            type    = "number",
            label   = "Font Size",
            desc    = "Absorb-amount text size in pixels.",
            default = unitDefaults.fontSize,
            min = 6, max = 32, step = 1,
        },
        {
            path    = p .. "fontFlags",
            page    = "font",
            unit    = unit,
            group   = "Typography",
            order   = 30,
            type    = "string",
            label   = "Font Outline",
            desc    = "Outline / monochrome flags applied to the absorb-amount text.",
            default = unitDefaults.fontFlags,
            values  = fontFlagOptions,
            sorting = fontFlagSorting,
            solo    = true,
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
    local ctx = H.CreatePanel("AbsorbTrackerFontPanel", "Font", {
        pageKey         = "font",
        defaultsButton  = true,
        defaultsTooltip = "Restore every Font setting on this profile to its addon default.",
    })
    -- Parked, not wired: the Defaults button does not exist yet — it is built
    -- on first OnShow (see Helpers.EnsureDefaultsButton).
    ctx.panel.defaultsOnClick = function()
        H.RestoreDefaults("font", ctx)
    end

    local rendered = false
    ctx.panel:SetScript("OnShow", function()
        H.EnsureDefaultsButton(ctx.panel)
        if rendered then return end
        rendered = true
        H.RenderSchema(ctx, "font")
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "Font")
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage("font", "Font", build)
end
