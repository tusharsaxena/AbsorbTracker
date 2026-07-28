local addonName, NS = ...

-- AceDB defaults. Bar appearance is PER UNIT (player / target / focus) under `profile.units`;
-- the four master toggles stay flat at the profile root because they govern all three bars.
-- The persisted-DB schema-version stamp lives under `global` (account-wide) so NS:RunMigrations
-- has a single version to walk regardless of the active profile (Ka0s standard §5.1).
NS.defaults = NS.defaults or {}

-- The per-unit appearance block. Built by a factory so each unit gets its OWN tables — sharing
-- one literal across three units would make a color picker on the target bar repaint the player's.
local function appearance()
    return {
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
        useClassColorBar = false,
        useClassColorBg = false,
        useClassColorBorder = false,
        position = nil,
    }
end

local function unit(enabled, mirror)
    local t = appearance()
    t.enabled = enabled
    t.mirror = mirror
    return t
end

NS.defaults.profile = {
    -- Globals: one value shared by all three bars.
    locked = false,
    hidden = false,
    throttleWindow = 0.1,
    showOnlyInCombat = false,

    -- Per-unit. Player has no `mirror` key — it is the mirror SOURCE, so a player mirror row
    -- would be circular. Target and Focus ship disabled (an upgrade changes nothing on screen)
    -- but mirrored (a first enable looks like the player bar, not raw factory defaults).
    units = {
        player = unit(true, nil),
        target = unit(false, true),
        focus  = unit(false, true),
    },
}

NS.defaults.global = {
    -- Persisted-DB schema version. NS:RunMigrations (core/Database.lua) reads/writes this once
    -- at init — the idempotent seam future schema changes hook into. v3 introduced profile.units.
    schemaVersion = 3,
}

-- Flat alias for the no-AceDB fallback path: GetSetting reads this when NS.db is absent. It now
-- carries the four globals plus the `units` table.
NS.flatDefaults = NS.defaults.profile

-- Per-unit default alias. settings/{Bar,Border,Font}.lua read each row's `default =` from here,
-- so every unit's rows share one canonical default regardless of which unit generated them.
NS.unitDefaults = NS.defaults.profile.units.player
