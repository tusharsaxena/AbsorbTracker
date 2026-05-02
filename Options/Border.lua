-- AbsorbTracker: Options/Border.lua
--
-- Border sub-page: style, thickness, color (with class-color toggle).

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
        path    = "border",
        page    = "border",
        group   = "Border Style",
        order   = 10,
        type    = "string",
        label   = "Border Style",
        default = flatDefaults.border,
        dialogControl = "LSM30_Border",
        values = lsmValues("border"),
    },
    {
        path    = "borderSize",
        page    = "border",
        group   = "Border Style",
        order   = 20,
        type    = "number",
        label   = "Border Size",
        default = flatDefaults.borderSize,
        min = 1, max = 32, step = 1,
    },
    {
        path    = "useClassColorBorder",
        page    = "border",
        group   = "Border Color",
        order   = 10,
        type    = "bool",
        label   = "Use Class Color",
        desc    = "Use your class color for the border.",
        default = flatDefaults.useClassColorBorder,
    },
    {
        path     = "borderColor",
        page     = "border",
        group    = "Border Color",
        order    = 20,
        type     = "color",
        label    = "Border Color",
        default  = flatDefaults.borderColor,
        hasAlpha = true,
        disabledIf = "useClassColorBorder",
    },
})

local function build()
    return AddonTable.BuildPageOptions("border", "Border")
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("border", "Border", build)
end
