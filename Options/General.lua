-- AbsorbTracker: Options/General.lua
--
-- General sub-page — what `/at config` opens by default. Visibility,
-- lock, update interval, plus a Reset Position execute button. The
-- schema rows below double as the source for `/at list/get/set` on
-- these paths.

local AddonName, AddonTable = ...

local flatDefaults = AddonTable.flatDefaults

AddonTable.RegisterSchemaRows({
    {
        path    = "hidden",
        page    = "general",
        group   = "Visibility",
        order   = 10,
        type    = "bool",
        label   = "Show Bar",
        desc    = "Toggle the absorb bar on or off.",
        default = flatDefaults.hidden,
        inverse = true,
        onChange = function()
            AddonTable.UpdateBarAppearance()
            if not AddonTable.GetSetting("hidden") then
                AddonTable.lastAbsorb = -1
                AddonTable.UpdateAbsorbBar()
            end
        end,
    },
    {
        path    = "locked",
        page    = "general",
        group   = "Visibility",
        order   = 20,
        type    = "bool",
        label   = "Lock Position",
        desc    = "When locked, the bar can't be dragged.",
        default = flatDefaults.locked,
    },
    {
        path    = "updateInterval",
        page    = "general",
        group   = "Performance",
        order   = 10,
        type    = "number",
        label   = "Update Interval (sec)",
        desc    = "How often the bar refreshes. Lower = smoother but more CPU.",
        default = flatDefaults.updateInterval,
        min = 0.1, max = 10, step = 0.1, fmt = "%.1f sec",
        onChange = function() AddonTable.RestartUpdateTicker() end,
    },
})

local function build()
    local opts = AddonTable.BuildPageOptions("general", "General")
    -- Reset Position is an action, not a setting — inject it as an
    -- inline group AFTER the schema-built table so it appears below
    -- the Performance group.
    opts.args.position = {
        type   = "group",
        inline = true,
        name   = "Position",
        order  = 100,
        args   = {
            reset = {
                order = 10,
                type  = "execute",
                name  = "Reset Position",
                desc  = "Move the bar back to the screen center.",
                func  = function()
                    if AddonTable.db and AddonTable.db.profile then
                        AddonTable.db.profile.position = nil
                    end
                    if AddonTable.RestoreBarPosition then
                        AddonTable.RestoreBarPosition()
                    end
                end,
            },
        },
    }
    return opts
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("general", "General", build, { isDefault = true })
end
