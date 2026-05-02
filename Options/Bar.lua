-- AbsorbTracker: Options/Bar.lua
--
-- Bar sub-page: dimensions, fill texture/color, background texture/color.
-- Class-color toggles grey out the matching color picker via `disabled`.

local AddonName, AddonTable = ...

local function getSetting(key)         return AddonTable.GetSetting(key) end
local function setSetting(key, value)  AddonTable.SetSetting(key, value) end

local function getColor(key)
    local c = getSetting(key) or {}
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

local function setColor(key, r, g, b, a)
    setSetting(key, { r = r, g = g, b = b, a = a })
    AddonTable.UpdateBarAppearance()
end

local function build()
    return {
        name = "Bar",
        type = "group",
        args = {
            size = {
                order = 10,
                type  = "group",
                name  = "Size",
                inline = true,
                args = {
                    barWidth = {
                        order = 10,
                        type  = "range",
                        name  = "Bar Width",
                        min   = 50, max = 500, step = 1,
                        width = "full",
                        get   = function() return getSetting("barWidth") end,
                        set   = function(_, v) setSetting("barWidth", v); AddonTable.UpdateBarAppearance() end,
                    },
                    barHeight = {
                        order = 20,
                        type  = "range",
                        name  = "Bar Height",
                        min   = 10, max = 100, step = 1,
                        width = "full",
                        get   = function() return getSetting("barHeight") end,
                        set   = function(_, v) setSetting("barHeight", v); AddonTable.UpdateBarAppearance() end,
                    },
                },
            },
            fill = {
                order = 20,
                type  = "group",
                name  = "Bar Fill",
                inline = true,
                args = {
                    barTexture = {
                        order = 10,
                        type  = "select",
                        name  = "Bar Texture",
                        dialogControl = "LSM30_Statusbar",
                        values = function()
                            local LSM = AddonTable.GetLSM()
                            local list, out = LSM and LSM:HashTable("statusbar") or {}, {}
                            for k in pairs(list) do out[k] = k end
                            return out
                        end,
                        width = "full",
                        get   = function() return getSetting("barTexture") end,
                        set   = function(_, v) setSetting("barTexture", v); AddonTable.UpdateBarAppearance() end,
                    },
                    useClassColorBar = {
                        order = 20,
                        type  = "toggle",
                        name  = "Use Class Color",
                        desc  = "Use your class color for the bar fill.",
                        get   = function() return getSetting("useClassColorBar") end,
                        set   = function(_, v) setSetting("useClassColorBar", v); AddonTable.UpdateBarAppearance() end,
                    },
                    barColor = {
                        order = 30,
                        type  = "color",
                        name  = "Bar Color",
                        hasAlpha = true,
                        disabled = function() return getSetting("useClassColorBar") end,
                        get   = function() return getColor("barColor") end,
                        set   = function(_, r, g, b, a) setColor("barColor", r, g, b, a) end,
                    },
                },
            },
            background = {
                order = 30,
                type  = "group",
                name  = "Background",
                inline = true,
                args = {
                    bgTexture = {
                        order = 10,
                        type  = "select",
                        name  = "Background Texture",
                        dialogControl = "LSM30_Statusbar",
                        values = function()
                            local LSM = AddonTable.GetLSM()
                            local list, out = LSM and LSM:HashTable("statusbar") or {}, {}
                            for k in pairs(list) do out[k] = k end
                            return out
                        end,
                        width = "full",
                        get   = function() return getSetting("bgTexture") end,
                        set   = function(_, v) setSetting("bgTexture", v); AddonTable.UpdateBarAppearance() end,
                    },
                    useClassColorBg = {
                        order = 20,
                        type  = "toggle",
                        name  = "Use Class Color",
                        desc  = "Use a darkened class color for the background.",
                        get   = function() return getSetting("useClassColorBg") end,
                        set   = function(_, v) setSetting("useClassColorBg", v); AddonTable.UpdateBarAppearance() end,
                    },
                    bgColor = {
                        order = 30,
                        type  = "color",
                        name  = "Background Color",
                        hasAlpha = true,
                        disabled = function() return getSetting("useClassColorBg") end,
                        get   = function() return getColor("bgColor") end,
                        set   = function(_, r, g, b, a) setColor("bgColor", r, g, b, a) end,
                    },
                },
            },
        },
    }
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("bar", "Bar", build)
end
