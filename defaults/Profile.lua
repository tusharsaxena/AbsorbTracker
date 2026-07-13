local addonName, NS = ...

-- AceDB defaults. Per-profile bar appearance/position lives under `profile`; the persisted-DB
-- schema-version stamp lives under `global` (account-wide) so NS:RunMigrations has a single
-- version to walk regardless of the active profile (Ka0s standard §5.1).
NS.defaults = NS.defaults or {}

NS.defaults.profile = {
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
    locked = false,
    hidden = false,
    throttleWindow = 0.1,
    showOnlyInCombat = false,
    position = nil,
}

NS.defaults.global = {
    -- Persisted-DB schema version. NS:RunMigrations (core/Database.lua) reads/writes this once
    -- at init — the idempotent seam future schema changes hook into. v1 is the initial shape.
    schemaVersion = 1,
}

-- Flat alias for the no-AceDB fallback path: GetSetting reads this when NS.db is absent, and
-- Options pages read per-key defaults from it.
NS.flatDefaults = NS.defaults.profile
