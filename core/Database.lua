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

function NS:RunMigrations()
    local g = NS.db and NS.db.global
    if not g then return end
    g.schemaVersion = g.schemaVersion or 1

    local profile = NS.db.profile
    local defaults = NS.defaults.profile

    -- v3 (§2.2/§5.1): bar appearance moved from flat profile keys to profile.units.<unit>.
    --
    -- Gated on schemaVersion, NOT on `profile.units == nil`. Under REAL AceDB-3.0, the very act
    -- of reading `NS.db.profile` two lines above already triggered the library's own
    -- copyDefaults: AceDB's dbmt.__index lazily initializes a section on first access and fills
    -- every missing key — including the whole new `units` table — straight from NS.defaults
    -- before this line ever runs. So on a real upgrading install `profile.units` is NEVER nil by
    -- the time we get here, and a `units == nil` guard makes this entire block permanently dead:
    -- the user's pre-v3 flat values (barWidth, barColor, position, ...) would be silently
    -- orphaned and the bar would render with brand-new factory defaults instead of their saved
    -- configuration. schemaVersion is the only reliable "does this profile predate v3" signal —
    -- copyDefaults only ever fills an ABSENT key, so it never touches an existing
    -- schemaVersion, meaning an upgrading user's global keeps its pre-v3 stamp (1 or 2) right up
    -- until the version bump below runs.
    if profile and g.schemaVersion < 3 then
        -- profile.units usually already exists here (AceDB / the backfill on a prior run seeded
        -- it) — only the no-AceDB fallback (NS.db = { profile = AbsorbTrackerDB, global = {} })
        -- can reach this with no `units` table at all, so create it (and any missing unit row)
        -- rather than assuming it is absent.
        profile.units = profile.units or {}
        for _, unit in ipairs(NS.Units.LIST) do
            profile.units[unit] = profile.units[unit] or deepcopy(defaults.units[unit])
        end
        -- Lift the pre-v3 flat appearance keys (and the saved position) onto the player unit —
        -- OVERWRITING whatever copyDefaults may already have seeded there from the NEW
        -- defaults — then clear the flat originals. A user upgrading sees an identical bar in
        -- an identical spot.
        for _, key in ipairs(NS.Units.APPEARANCE_KEYS) do
            if profile[key] ~= nil then
                profile.units.player[key] = profile[key]
                profile[key] = nil
            end
        end
        if profile.position ~= nil then
            profile.units.player.position = profile.position
            profile.position = nil
        end
    end

    -- Backfill any missing key from the defaults. Absorbs the legacy pre-AceDB flat
    -- SavedVariables shape and the no-AceDB fallback into one versioned, idempotent step: keys
    -- already present are left untouched, so running it twice is a no-op.
    if profile then
        for key, defaultVal in pairs(defaults) do
            if key ~= "units" and profile[key] == nil then
                profile[key] = deepcopy(defaultVal)
            end
        end
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

    -- v2: the poll ticker became event-driven; the old poll-interval key is dead.
    if g.schemaVersion < 2 then
        if profile then profile.updateInterval = nil end
        NS.Debug("Migrate", "v%s \226\134\146 v2", g.schemaVersion)
        g.schemaVersion = 2
    end
    if g.schemaVersion < 3 then
        NS.Debug("Migrate", "v%s \226\134\146 v3", g.schemaVersion)
        g.schemaVersion = 3
    end
end
