-- AbsorbTracker: Options/Border.lua
--
-- Border sub-page: style, thickness, color (with class-color toggle).

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
        name = "Border",
        type = "group",
        args = {
            style = {
                order = 10,
                type  = "group",
                name  = "Border Style",
                inline = true,
                args = {
                    border = {
                        order = 10,
                        type  = "select",
                        name  = "Border Style",
                        dialogControl = "LSM30_Border",
                        values = function()
                            local LSM = AddonTable.GetLSM()
                            local list, out = LSM and LSM:HashTable("border") or {}, {}
                            for k in pairs(list) do out[k] = k end
                            return out
                        end,
                        width = "full",
                        get   = function() return getSetting("border") end,
                        set   = function(_, v) setSetting("border", v); AddonTable.UpdateBarAppearance() end,
                    },
                    borderSize = {
                        order = 20,
                        type  = "range",
                        name  = "Border Size",
                        min   = 1, max = 32, step = 1,
                        width = "full",
                        get   = function() return getSetting("borderSize") end,
                        set   = function(_, v) setSetting("borderSize", v); AddonTable.UpdateBarAppearance() end,
                    },
                },
            },
            color = {
                order = 20,
                type  = "group",
                name  = "Border Color",
                inline = true,
                args = {
                    useClassColorBorder = {
                        order = 10,
                        type  = "toggle",
                        name  = "Use Class Color",
                        desc  = "Use your class color for the border.",
                        get   = function() return getSetting("useClassColorBorder") end,
                        set   = function(_, v) setSetting("useClassColorBorder", v); AddonTable.UpdateBarAppearance() end,
                    },
                    borderColor = {
                        order = 20,
                        type  = "color",
                        name  = "Border Color",
                        hasAlpha = true,
                        disabled = function() return getSetting("useClassColorBorder") end,
                        get   = function() return getColor("borderColor") end,
                        set   = function(_, r, g, b, a) setColor("borderColor", r, g, b, a) end,
                    },
                },
            },
        },
    }
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("border", "Border", build)
end
