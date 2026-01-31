-- AbsorbTracker: Core module - AddonTable setup and defaults
local AddonName, AddonTable = ...

-- Cache frequently used functions
AddonTable.floor = math.floor
AddonTable.max = math.max
AddonTable.min = math.min
AddonTable.format = format

-- Default settings (AceDB format)
AddonTable.defaults = {
    profile = {
        barTexture = "Blizzard Raid Bar",
        bgTexture = "Blizzard Raid Bar",
        border = "Blizzard Tooltip",
        borderSize = 12,
        borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 },
        font = "Friz Quadrata TT",
        fontSize = 12,
        fontFlags = "OUTLINE",
        barWidth = 200,
        barHeight = 20,
        barColor = { r = 0.4, g = 0.7, b = 1.0, a = 0.8 },
        bgColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
        locked = false,
        hidden = false,
        updateInterval = 1.0,
        position = nil,
    },
}

-- Flat defaults for fallback when AceDB is not available
AddonTable.flatDefaults = AddonTable.defaults.profile
