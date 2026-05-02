-- AbsorbTracker: Options/Bar.lua
--
-- Bar sub-page: dimensions, fill texture/color, background texture/color.
-- Class-color toggles use disabledIf to grey out the matching color
-- picker when their toggle is on.

local AddonName, AddonTable = ...

local flatDefaults = AddonTable.flatDefaults

local function lsmValues(mediaType)
    return function()
        local LSM = AddonTable.GetLSM()
        local list, out = LSM and LSM:HashTable(mediaType) or {}, {}
        for k in pairs(list) do out[k] = k end
        return out
    end
end

AddonTable.RegisterSchemaRows({
    {
        path    = "barWidth",
        page    = "bar",
        group   = "Size",
        order   = 10,
        type    = "number",
        label   = "Bar Width",
        default = flatDefaults.barWidth,
        min = 50, max = 500, step = 1,
    },
    {
        path    = "barHeight",
        page    = "bar",
        group   = "Size",
        order   = 20,
        type    = "number",
        label   = "Bar Height",
        default = flatDefaults.barHeight,
        min = 10, max = 100, step = 1,
    },
    {
        path    = "barTexture",
        page    = "bar",
        group   = "Bar Fill",
        order   = 10,
        type    = "string",
        label   = "Bar Texture",
        default = flatDefaults.barTexture,
        dialogControl = "LSM30_Statusbar",
        values = lsmValues("statusbar"),
    },
    {
        path    = "useClassColorBar",
        page    = "bar",
        group   = "Bar Fill",
        order   = 20,
        type    = "bool",
        label   = "Use Class Color",
        desc    = "Use your class color for the bar fill.",
        default = flatDefaults.useClassColorBar,
    },
    {
        path     = "barColor",
        page     = "bar",
        group    = "Bar Fill",
        order    = 30,
        type     = "color",
        label    = "Bar Color",
        default  = flatDefaults.barColor,
        hasAlpha = true,
        disabledIf = "useClassColorBar",
    },
    {
        path    = "bgTexture",
        page    = "bar",
        group   = "Background",
        order   = 10,
        type    = "string",
        label   = "Background Texture",
        default = flatDefaults.bgTexture,
        dialogControl = "LSM30_Statusbar",
        values = lsmValues("statusbar"),
    },
    {
        path    = "useClassColorBg",
        page    = "bar",
        group   = "Background",
        order   = 20,
        type    = "bool",
        label   = "Use Class Color",
        desc    = "Use a darkened class color for the background.",
        default = flatDefaults.useClassColorBg,
    },
    {
        path     = "bgColor",
        page     = "bar",
        group    = "Background",
        order    = 30,
        type     = "color",
        label    = "Background Color",
        default  = flatDefaults.bgColor,
        hasAlpha = true,
        disabledIf = "useClassColorBg",
    },
})

local function build()
    return AddonTable.BuildPageOptions("bar", "Bar")
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("bar", "Bar", build)
end
