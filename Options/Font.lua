-- AbsorbTracker: Options/Font.lua
--
-- Font sub-page: face, size, outline.

local AddonName, AddonTable = ...

local function getSetting(key)         return AddonTable.GetSetting(key) end
local function setSetting(key, value)  AddonTable.SetSetting(key, value) end

local fontFlagOptions = {
    [""]                          = "None",
    ["OUTLINE"]                   = "Outline",
    ["THICKOUTLINE"]              = "Thick Outline",
    ["MONOCHROME"]                = "Monochrome",
    ["MONOCHROME, OUTLINE"]       = "Monochrome, Outline",
    ["MONOCHROME, THICKOUTLINE"]  = "Monochrome, Thick Outline",
}

local fontFlagOrder = {
    "", "OUTLINE", "THICKOUTLINE",
    "MONOCHROME", "MONOCHROME, OUTLINE", "MONOCHROME, THICKOUTLINE",
}

local function build()
    return {
        name = "Font",
        type = "group",
        args = {
            font = {
                order = 10,
                type  = "select",
                name  = "Font Face",
                dialogControl = "LSM30_Font",
                values = function()
                    local LSM = AddonTable.GetLSM()
                    local list, out = LSM and LSM:HashTable("font") or {}, {}
                    for k in pairs(list) do out[k] = k end
                    return out
                end,
                width = "full",
                get   = function() return getSetting("font") end,
                set   = function(_, v) setSetting("font", v); AddonTable.UpdateBarAppearance() end,
            },
            fontSize = {
                order = 20,
                type  = "range",
                name  = "Font Size",
                min   = 6, max = 32, step = 1,
                width = "full",
                get   = function() return getSetting("fontSize") end,
                set   = function(_, v) setSetting("fontSize", v); AddonTable.UpdateBarAppearance() end,
            },
            fontFlags = {
                order = 30,
                type  = "select",
                name  = "Font Outline",
                values = fontFlagOptions,
                sorting = fontFlagOrder,
                width = "full",
                get   = function() return getSetting("fontFlags") end,
                set   = function(_, v) setSetting("fontFlags", v); AddonTable.UpdateBarAppearance() end,
            },
        },
    }
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("font", "Font", build)
end
