local addonName, NS = ...

-- AceDB defaults. Bar appearance is PER UNIT (player / target / focus) under `profile.units`;
-- the three master toggles stay flat at the profile root because they govern all three bars.
-- There are TWO schema-version stamps. The account-wide one under `global` (Ka0s standard savedvariables-§1) is
-- the DB-wide marker NS:RunMigrations walks regardless of the active profile. The second lives
-- per-profile, below, and gates the v3 lift — which is a per-profile mutation an account-wide flag
-- structurally cannot gate. That second stamp is a deliberate, recorded savedvariables-§1 deviation: see the
-- "Documented deviations" register in docs/ARCHITECTURE.md and docs/profiles.md.
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
        -- The sixth row of the canonical font block (options-ui-§16), new with the composer.
        -- Default OFF, so an install that never opens the Text tab is drawn exactly as it was;
        -- modules/Display.lua applies it beside SetFont on every appearance pass.
        fontShadow = false,
        -- Opaque white: what a FontString draws at when nothing sets a color, which is what the
        -- absorb amount did before it had a row. Stated here so an install that never opens the
        -- Text tab is drawn exactly as it was.
        fontColor = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },
        barWidth = 200,
        barHeight = 20,
        -- The literal `1` modules/Display.lua used to pass to bar:SetAlpha at both paint sites.
        -- Same reason as fontColor above: the promoted default has to BE the number it replaced.
        barAlpha = 1.0,
        barColor = { r = 0.4, g = 0.7, b = 1.0, a = 0.8 },
        bgColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
        useClassColorBar = false,
        useClassColorBg = false,
        useClassColorBorder = false,
        useClassColorText = false,
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
    -- PER-PROFILE schema stamp — a deliberate, documented deviation from Ka0s standard savedvariables-§1, which
    -- puts the version stamp account-wide under `global` (see docs/ARCHITECTURE.md "Standards
    -- Deviations" and docs/profiles.md). The account-wide stamp still exists below and remains the
    -- DB-wide marker; this one answers the narrower question "has THIS profile been lifted?", which
    -- an account-wide stamp structurally cannot: the v3 lift is a PER-PROFILE mutation, so one
    -- global flag flipping after the active profile migrates strands every other profile.
    --
    -- The default is 1 ("legacy — not yet lifted"), NOT the current 3, and that is load-bearing.
    -- AceDB-3.0's copyDefaults fills every ABSENT key the first time a profile section is
    -- instantiated, which happens BEFORE NS:RunMigrations ever reads it. A default of 3 would stamp
    -- every pre-v3 profile as already-migrated on first touch and make the gate permanently dead —
    -- the exact failure mode the old `units == nil` guard had. Defaulting to 1 makes an unstamped
    -- profile read as what it is: pre-v3.
    schemaVersion = 1,

    -- Globals: one value shared by all three bars.
    --
    -- The Master controls block (options-ui-§15) is five of them — `enabled`, `visibility`,
    -- `scale`, `alpha` and `locked`; its sixth row, the debug console, is session state and stores
    -- nothing here. `enabled` is the addon-wide
    -- switch the three per-unit `enabled` flags are NOT — §15 forbids conflating an addon-wide row
    -- with a per-instance one, so both exist and the addon-wide one gates the per-unit ones
    -- (NS.ShouldShowBar). `visibility` REPLACES the old `showOnlyInCombat` boolean, which could
    -- only ever answer two of the four states; the v5 migration in core/Database.lua carries every
    -- existing install across. `scale` and `alpha` are the addon-wide multipliers, and are a
    -- different question from the per-unit `barAlpha` on the Appearance page.
    --
    -- There is deliberately no `hidden` master toggle — that key was dropped in v4, and `enabled`
    -- above is not a re-introduction of it: `hidden` had no UI left to clear it, which is exactly
    -- what made it a defect.
    enabled = true,
    visibility = "always",
    scale = 1.0,
    alpha = 1.0,
    locked = false,
    throttleWindow = 0.1,

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
    -- at init — the idempotent seam future schema changes hook into. v3 introduced profile.units;
    -- v4 dropped the dead `hidden` global; v5 mapped `showOnlyInCombat` onto `visibility`.
    --
    -- The default is 1 ("pre-ladder"), NOT the current 5, for exactly the reason the per-profile
    -- stamp above is 1: AceDB-3.0's copyDefaults fills every ABSENT key the moment the section is
    -- instantiated, which happens BEFORE NS:RunMigrations reads it. A default of 5 would stamp
    -- every freshly-materialized global as already-migrated, so `g.schemaVersion < step.to` is
    -- false for every step and the ladder is structurally dead — including for a DB whose global
    -- was wiped while its profiles still carried pre-v5 data. Every step is idempotent, so running
    -- the ladder on a genuinely new install costs four no-ops and stamps 5.
    schemaVersion = 1,
}

-- Flat alias for the no-AceDB fallback path: GetSetting reads this when NS.db is absent. It now
-- carries the six globals (enabled, visibility, scale, alpha, locked, throttleWindow), the
-- per-profile schema stamp and the `units` table.
NS.flatDefaults = NS.defaults.profile

-- Per-unit default alias. settings/{Bar,Border,Font}.lua read each row's `default =` from here,
-- so every unit's rows share one canonical default regardless of which unit generated them.
NS.unitDefaults = NS.defaults.profile.units.player
