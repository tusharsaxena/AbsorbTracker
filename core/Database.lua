local addonName, NS = ...

-- AceDB init + schema migration. Called from the AceAddon OnInitialize (core/AbsorbTracker.lua)
-- and available headlessly for the test harness.
function NS:InitDB()
    local AceDB = LibStub and LibStub("AceDB-3.0", true)
    if AceDB then
        NS.db = AceDB:New("AbsorbTrackerDB", NS.defaults, true)
        -- Profile changes repaint the bar and refresh an open panel. Guard RegisterCallback so
        -- the headless AceDB mock (no CallbackHandler) doesn't error.
        if NS.db.RegisterCallback then
            NS.db.RegisterCallback(NS, "OnProfileChanged", NS.OnProfileChanged)
            NS.db.RegisterCallback(NS, "OnProfileCopied", NS.OnProfileChanged)
            NS.db.RegisterCallback(NS, "OnProfileReset", NS.OnProfileChanged)
        end
    end
    -- Fallback when AceDB is unavailable: a minimal db-like table backed by the raw SV global.
    if not NS.db then
        AbsorbTrackerDB = AbsorbTrackerDB or {}
        NS.db = { profile = AbsorbTrackerDB, global = {} }
    end
    NS:RunMigrations()
end

-- Deep-copy so an in-place mutation of a saved variable can never reach back into the defaults.
local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, vv in pairs(v) do out[k] = deepcopy(vv) end
    return out
end

-- v3 (toc-file-§2/savedvariables-§1): bar appearance moved from flat profile keys to profile.units.<unit>.
--
-- Gated on a schemaVersion stamp, NOT on `profile.units == nil`. Under REAL AceDB-3.0, the very
-- act of reading `NS.db.profile` already triggers the library's own copyDefaults: AceDB's
-- dbmt.__index lazily initializes a section on first access and fills every missing key —
-- including the whole new `units` table — straight from NS.defaults before any migration code
-- runs. So on a real upgrading install `profile.units` is NEVER nil by the time we get here, and
-- a `units == nil` guard makes this entire block permanently dead: the user's pre-v3 flat values
-- (barWidth, barColor, position, ...) would be silently orphaned and the bar would render with
-- brand-new factory defaults instead of their saved configuration.
--
-- The gate is the PER-PROFILE stamp (`profile.schemaVersion`, defaults/Profile.lua), not the
-- account-wide `db.global.schemaVersion`. The lift is a per-profile mutation, so an account-wide
-- flag cannot gate it correctly: a user on "Default" with a second pre-v3 "Raid" profile would
-- migrate Default, flip the account-wide stamp to 3, and strand Raid's flat keys forever. The
-- per-profile default is deliberately 1, so an unstamped (= pre-v3) profile reads as pre-v3 even
-- after copyDefaults has been over it — see the comment in defaults/Profile.lua.
--
-- Idempotent by construction: it clears each flat original as it lifts, and stamps the profile at
-- the end, so a second call (from InitDB's sweep AND from OnProfileChanged) is a no-op.
--
-- Returns true only when a flat key was ACTUALLY moved — not merely when the stamp was written.
-- A factory-fresh profile is unstamped (the per-profile default is 1) and so passes the gate and
-- gets stamped, but has no flat keys to lift; reporting that as a migration made a fresh install
-- log "[Migrate] lifted 1 profile(s) to v3" for work that never happened.
function NS.MigrateProfileToV3(profile)
    if type(profile) ~= "table" then return false end
    if (profile.schemaVersion or 1) >= 3 then return false end

    local lifted = false
    local defaults = NS.defaults.profile
    -- profile.units usually already exists here (AceDB / the backfill on a prior run seeded it) —
    -- the no-AceDB fallback and a raw, never-activated profile out of db.sv.profiles can reach
    -- this with no `units` table at all, so create it (and any missing unit row) rather than
    -- assuming it is absent.
    profile.units = profile.units or {}
    for _, unit in ipairs(NS.Units.LIST) do
        profile.units[unit] = profile.units[unit] or deepcopy(defaults.units[unit])
    end
    -- Lift the pre-v3 flat appearance keys (and the saved position) onto the player unit —
    -- OVERWRITING whatever copyDefaults may already have seeded there from the NEW defaults —
    -- then clear the flat originals. A user upgrading sees an identical bar in an identical spot.
    for _, key in ipairs(NS.Units.APPEARANCE_KEYS) do
        if profile[key] ~= nil then
            profile.units.player[key] = profile[key]
            profile[key] = nil
            lifted = true
        end
    end
    if profile.position ~= nil then
        profile.units.player.position = profile.position
        profile.position = nil
        lifted = true
    end

    profile.schemaVersion = 3
    return lifted
end

-- Lift EVERY profile in the saved store, not just whichever one happens to be active at InitDB.
-- Without this, a user with "Default" and "Raid" who upgrades while on Default migrates Default,
-- flips the account-wide stamp, and Raid's flat barWidth / barColor / position become unreachable
-- forever — their raid layout silently reverts to factory defaults.
local function migrateAllProfiles()
    local n = 0
    if NS.MigrateProfileToV3(NS.db.profile) then n = n + 1 end

    -- AceDB-3.0 keeps the raw name -> profile-table map at db.sv.profiles. Guarded rather than
    -- assumed: the no-AceDB fallback (NS.db = { profile = AbsorbTrackerDB, global = {} }) has no
    -- `sv` at all, and there the single profile handled above IS the whole store.
    local sv = NS.db.sv
    local store = (type(sv) == "table") and sv.profiles or nil
    if type(store) == "table" then
        for _, p in pairs(store) do
            -- Skip the active profile: already done above, and MigrateProfileToV3's own stamp
            -- would make a second pass a no-op anyway.
            if p ~= NS.db.profile and NS.MigrateProfileToV3(p) then n = n + 1 end
        end
    end
    return n
end

-- Delete one dead profile key from EVERY profile in the store, not just the active one. Same
-- reasoning as migrateAllProfiles: a key left behind on an inactive profile comes back the moment
-- the user switches to it. Returns how many profiles actually carried the key.
local function dropKeyEverywhere(key)
    local n = 0
    local function drop(p)
        if type(p) == "table" and p[key] ~= nil then
            p[key] = nil
            n = n + 1
        end
    end

    drop(NS.db.profile)
    local sv = NS.db.sv
    local store = (type(sv) == "table") and sv.profiles or nil
    if type(store) == "table" then
        for _, p in pairs(store) do
            if p ~= NS.db.profile then drop(p) end
        end
    end
    return n
end

-- Backfill any missing FLAT profile key from the defaults. `units` is skipped: it is the per-unit
-- section, handled by backfillUnitKeys below. Keys already present are left untouched, so running
-- it twice is a no-op.
local function backfillFlatKeys(profile, defaults)
    for key, defaultVal in pairs(defaults) do
        if key ~= "units" and profile[key] == nil then
            profile[key] = deepcopy(defaultVal)
        end
    end
end

-- Backfill any missing key on each per-unit row. Seeds the `units` table and each unit's row when
-- absent, so the no-AceDB fallback and a raw profile out of db.sv.profiles both land on the full
-- shape. Same idempotence: present keys are left alone.
local function backfillUnitKeys(profile, defaults)
    profile.units = profile.units or {}
    for _, unit in ipairs(NS.Units.LIST) do
        profile.units[unit] = profile.units[unit] or {}
        for key, defaultVal in pairs(defaults.units[unit]) do
            if profile.units[unit][key] == nil then
                profile.units[unit][key] = deepcopy(defaultVal)
            end
        end
    end
end

-- The account-wide schema ladder, in order. `apply` runs BEFORE the version line is logged, so a
-- step's own [Migrate] output still precedes its "vX -> vY" stamp. Built once at file load — the
-- ladder has grown three times now, and a new version should be one row here, not another arm.
local SCHEMA_STEPS = {
    { to = 2, apply = function(profile)
        -- v2: the poll ticker became event-driven; the old poll-interval key is dead.
        if profile then profile.updateInterval = nil end
    end },
    -- v3 is stamp-only: the per-unit lift is gated on the PER-PROFILE stamp and already ran
    -- unconditionally above, so there is nothing account-wide left to do here.
    { to = 3, apply = function() end },
    { to = 4, apply = function()
        -- v4: the global `hidden` master toggle is gone. The three per-unit `enabled` flags are
        -- now the only visibility switch, so a stale `hidden = true` would be an unreachable
        -- setting that silently suppressed every bar with no UI left to clear it. Swept from
        -- every profile.
        local dropped = dropKeyEverywhere("hidden")
        if dropped > 0 then
            NS.Debug("Migrate", "dropped `hidden` from %s profile(s)", dropped)
        end
    end },
}

function NS:RunMigrations()
    local g = NS.db and NS.db.global
    if not g then return end
    g.schemaVersion = g.schemaVersion or 1

    local profile = NS.db.profile
    local defaults = NS.defaults.profile

    local lifted = migrateAllProfiles()
    if lifted > 0 then
        NS.Debug("Migrate", "lifted %s profile(s) to v3", lifted)
    end

    -- Backfill absorbs the legacy pre-AceDB flat SavedVariables shape and the no-AceDB fallback
    -- into one versioned, idempotent step. It runs AFTER the v3 lift (or a pre-v3 profile's flat
    -- appearance keys get shadowed by freshly copied defaults) and BEFORE the ladder (so v2 still
    -- clears `updateInterval` after any backfill pass).
    if profile then
        backfillFlatKeys(profile, defaults)
        backfillUnitKeys(profile, defaults)
    end

    for _, step in ipairs(SCHEMA_STEPS) do
        if g.schemaVersion < step.to then
            step.apply(profile)
            NS.Debug("Migrate", "v%s \226\134\146 v%s", g.schemaVersion, step.to)
            g.schemaVersion = step.to
        end
    end
end
