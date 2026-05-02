-- AbsorbTracker: Options/General.lua
--
-- General sub-page — what `/at config` opens by default (flagged
-- `isDefault = true`). Holds master visibility, lock, the update
-- interval, and the Reset Position button. The top-level "Ka0s Absorb
-- Tracker" category itself is intentionally empty.

local AddonName, AddonTable = ...

local function getSetting(key)         return AddonTable.GetSetting(key) end
local function setSetting(key, value)  AddonTable.SetSetting(key, value) end

local function build()
    return {
        name = "General",
        type = "group",
        args = {
            visibility = {
                order = 10,
                type  = "group",
                name  = "Visibility",
                inline = true,
                args = {
                    show = {
                        order = 10,
                        type  = "toggle",
                        name  = "Show Bar",
                        desc  = "Toggle the absorb bar on or off.",
                        width = "full",
                        get   = function() return not getSetting("hidden") end,
                        set   = function(_, value)
                            setSetting("hidden", not value)
                            AddonTable.UpdateBarAppearance()
                            if not getSetting("hidden") then
                                AddonTable.lastAbsorb = -1
                                AddonTable.UpdateAbsorbBar()
                            end
                        end,
                    },
                    locked = {
                        order = 20,
                        type  = "toggle",
                        name  = "Lock Position",
                        desc  = "When locked, the bar can't be dragged.",
                        width = "full",
                        get   = function() return getSetting("locked") end,
                        set   = function(_, value)
                            setSetting("locked", value)
                            AddonTable.UpdateBarAppearance()
                        end,
                    },
                },
            },
            performance = {
                order = 20,
                type  = "group",
                name  = "Performance",
                inline = true,
                args = {
                    updateInterval = {
                        order = 10,
                        type  = "range",
                        name  = "Update Interval (sec)",
                        desc  = "How often the bar refreshes. Lower = smoother but more CPU.",
                        min   = 0.1,
                        max   = 10,
                        step  = 0.1,
                        bigStep = 0.1,
                        width = "full",
                        get   = function() return getSetting("updateInterval") end,
                        set   = function(_, value)
                            setSetting("updateInterval", value)
                            AddonTable.RestartUpdateTicker()
                        end,
                    },
                },
            },
            position = {
                order = 30,
                type  = "group",
                name  = "Position",
                inline = true,
                args = {
                    reset = {
                        order = 10,
                        type  = "execute",
                        name  = "Reset Position",
                        desc  = "Move the bar back to the screen center.",
                        func  = function()
                            local db = AddonTable.db
                            if db and db.profile then
                                db.profile.position = nil
                            end
                            AddonTable.RestoreBarPosition()
                        end,
                    },
                },
            },
        },
    }
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("general", "General", build, { isDefault = true })
end
