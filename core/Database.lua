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

-- Schema-migration runner (Ka0s standard §2.2/§5.1). Reads/writes db.global.schemaVersion and
-- ships with an effectively no-op body — the *seam* is the requirement: future schema changes
-- get a single, idempotent upgrade path invoked once at init. Safe no-op when the DB isn't ready.
--
-- v1 also backfills any missing profile key from flatDefaults. This absorbs the legacy pre-AceDB
-- flat-SavedVariables shape (the old inline migration) and the no-AceDB fallback into one
-- versioned, idempotent step: keys already present are left untouched, so running it twice is a
-- no-op. Table defaults are deep-copied so an in-place mutation of a saved variable can't reach
-- back and corrupt flatDefaults.
function NS:RunMigrations()
    local g = NS.db and NS.db.global
    if not g then return end
    g.schemaVersion = g.schemaVersion or 1

    local profile = NS.db.profile
    if profile then
        for key, defaultVal in pairs(NS.flatDefaults) do
            if profile[key] == nil then
                if type(defaultVal) == "table" then
                    local copy = {}
                    for k, v in pairs(defaultVal) do copy[k] = v end
                    profile[key] = copy
                else
                    profile[key] = defaultVal
                end
            end
        end
    end
    -- v2 (§2.2/§5.1): the poll ticker became event-driven; the old poll-interval key is dead.
    -- throttleWindow is seeded by the flatDefaults backfill above, so this step only deletes the
    -- orphan. Operates on the active profile, matching the backfill's scope.
    if g.schemaVersion < 2 then
        if profile then profile.updateInterval = nil end
        g.schemaVersion = 2
    end
end
