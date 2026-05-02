-- AbsorbTracker: Options/Font.lua
--
-- Font sub-page: face, size, outline.

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

AddonTable.RegisterSchemaRows({
    {
        path    = "font",
        page    = "font",
        order   = 10,
        type    = "string",
        label   = "Font Face",
        default = flatDefaults.font,
        dialogControl = "LSM30_Font",
        values = lsmValues("font"),
    },
    {
        path    = "fontSize",
        page    = "font",
        order   = 20,
        type    = "number",
        label   = "Font Size",
        default = flatDefaults.fontSize,
        min = 6, max = 32, step = 1,
    },
    {
        path    = "fontFlags",
        page    = "font",
        order   = 30,
        type    = "string",
        label   = "Font Outline",
        default = flatDefaults.fontFlags,
        values  = fontFlagOptions,
        sorting = fontFlagSorting,
    },
})

local function build()
    return AddonTable.BuildPageOptions("font", "Font")
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("font", "Font", build)
end
