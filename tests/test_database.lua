local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- ── RunMigrations: the schema-migration seam (Ka0s standard §2.2/§5.1) ─────────────
-- The current schema version is 4, so a full migration run leaves the DB stamped at 4.
test("RunMigrations migrates a fresh DB to the current version (4)", function()
  NS.db.global.schemaVersion = nil
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 4)
end)

test("RunMigrations leaves an already-current (v4) DB unchanged", function()
  NS.db.global.schemaVersion = 4
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 4)
end)

test("RunMigrations is idempotent across repeated runs", function()
  NS.db.global.schemaVersion = nil
  NS:RunMigrations(); NS:RunMigrations(); NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 4)
end)

test("RunMigrations v2 retires the legacy updateInterval profile key", function()
  NS.db.global.schemaVersion = 1
  NS.db.profile.updateInterval = 1.0
  NS:RunMigrations()
  assertEqual(NS.db.profile.updateInterval, nil)
  assertEqual(NS.db.global.schemaVersion, 4)
end)

test("RunMigrations backfills throttleWindow from flatDefaults", function()
  NS.db.profile.throttleWindow = nil
  NS:RunMigrations()
  assertEqual(NS.db.profile.throttleWindow, NS.flatDefaults.throttleWindow)
end)

-- barWidth moved under profile.units.player in the v3 migration, so the scalar backfill is
-- exercised on that per-unit key rather than on the (now appearance-less) flat root.
test("RunMigrations backfills a missing scalar per-unit key from the defaults", function()
  NS.db.profile.units.player.barWidth = nil
  NS:RunMigrations()
  assertEqual(NS.db.profile.units.player.barWidth, NS.defaults.profile.units.player.barWidth)
end)

-- barColor moved under profile.units.player in the v3 migration (defaults/Profile.lua), so the
-- backfill deep-copy for a per-unit table is exercised here rather than on the flat root.
test("RunMigrations deep-copies per-unit table defaults (no shared reference to defaults)", function()
  NS.db.profile.units.player.barColor = nil
  NS:RunMigrations()
  local d = NS.defaults.profile.units.player
  assertTrue(NS.db.profile.units.player.barColor ~= d.barColor,
    "backfilled color table must be a copy, not the defaults reference")
  assertEqual(NS.db.profile.units.player.barColor.r, d.barColor.r)
end)

test("RunMigrations does not overwrite an existing user value", function()
  NS.db.profile.units.player.barWidth = 321
  NS:RunMigrations()
  assertEqual(NS.db.profile.units.player.barWidth, 321)
  NS.db.profile.units.player.barWidth = NS.defaults.profile.units.player.barWidth  -- restore
end)

test("RunMigrations is a safe no-op when the DB is absent", function()
  local saved = NS.db
  NS.db = nil
  NS:RunMigrations()   -- must not error with no db.global to touch
  NS.db = saved
end)

test("RunMigrations logs [Migrate] only when a version bump happens", function()
  NS.State.debug = true
  NS.db.global.schemaVersion = 1               -- force a v1->v2 migration
  local before = #NS.DebugLog.buffer
  NS:RunMigrations()
  local afterMigrate = #NS.DebugLog.buffer
  assertTrue(afterMigrate > before, "a [Migrate] line is logged when migrating")
  assertTrue(NS.DebugLog.buffer[afterMigrate]:find("[Migrate]", 1, true) ~= nil, "tag is Migrate")
  -- Idempotent: running again at v2 logs nothing new.
  NS:RunMigrations()
  assertEqual(#NS.DebugLog.buffer, afterMigrate)
  NS.State.debug = false
end)

test("InitDB produced a profile carrying every default key", function()
  for k in pairs(NS.flatDefaults) do
    -- `position` defaults to nil, so it is legitimately absent.
    if k ~= "position" then
      assertTrue(NS.db.profile[k] ~= nil, "profile missing default key: " .. k)
    end
  end
end)

test("v3 migration lifts flat appearance keys onto the player unit", function()
  local profile = { barWidth = 275, fontSize = 17, position = { point = "TOP", relPoint = "TOP", x = 1, y = 2 } }
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  NS.db = savedDB
  assertEqual(profile.units.player.barWidth, 275)
  assertEqual(profile.units.player.fontSize, 17)
  assertEqual(profile.units.player.position.x, 1)
  assertEqual(profile.barWidth, nil, "the flat original must be cleared, not duplicated")
  assertEqual(profile.position, nil)
end)

test("v3 migration seeds target and focus disabled and mirrored", function()
  local profile = { barWidth = 275 }
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  NS.db = savedDB
  assertEqual(profile.units.target.enabled, false)
  assertEqual(profile.units.target.mirror, true)
  assertEqual(profile.units.focus.enabled, false)
  assertEqual(profile.units.focus.mirror, true)
end)

test("v3 migration leaves the remaining global keys flat", function()
  local profile = { locked = true, showOnlyInCombat = true, throttleWindow = 0.25 }
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  NS.db = savedDB
  assertEqual(profile.locked, true)
  assertEqual(profile.throttleWindow, 0.25)
  assertEqual(profile.units.player.locked, nil, "globals must not be duplicated per unit")
end)

-- v4 drops the `hidden` master toggle: the per-unit `enabled` flags are the only visibility
-- switch now, so a surviving `hidden = true` would suppress every bar with no UI left to clear it.
test("v4 drops the dead `hidden` key from every profile, not just the active one", function()
  local active = { hidden = true, schemaVersion = 3 }
  local raid   = { hidden = true, schemaVersion = 3 }
  local savedDB = NS.db
  NS.db = {
    profile = active,
    global  = { schemaVersion = 3 },
    sv      = { profiles = { Default = active, Raid = raid } },
  }
  NS:RunMigrations()
  local version = NS.db.global.schemaVersion
  NS.db = savedDB

  assertEqual(active.hidden, nil, "the active profile's dead key is dropped")
  assertEqual(raid.hidden, nil, "and so is an inactive profile's -- it would return on a switch")
  assertEqual(version, 4)
end)

test("v4 does not resurrect `hidden` via the defaults backfill", function()
  local profile = {}
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 1 } }
  NS:RunMigrations()
  NS.db = savedDB
  assertEqual(profile.hidden, nil, "`hidden` is gone from defaults, so nothing can backfill it")
end)

test("v3 migration is idempotent", function()
  local profile = { barWidth = 275 }
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  profile.units.player.barWidth = 400
  NS:RunMigrations()
  NS.db = savedDB
  assertEqual(profile.units.player.barWidth, 400, "a second run must not re-lift or reset")
  assertEqual(profile.barWidth, nil, "a second run must not resurrect the flat key")
end)

test("v3 migration does not share nested tables between units", function()
  local profile = {}
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  NS.db = savedDB
  profile.units.target.barColor.r = 0.11
  assertTrue(profile.units.player.barColor.r ~= 0.11)
  assertTrue(profile.units.focus.barColor.r ~= 0.11)
end)

test("the schema version lands on 4", function()
  local savedDB = NS.db
  NS.db = { profile = {}, global = { schemaVersion = 1 } }
  NS:RunMigrations()
  local v = NS.db.global.schemaVersion
  NS.db = savedDB
  assertEqual(v, 4)
end)

-- ── Regression coverage: the v3 lift must fire under REAL AceDB, not just a bespoke table ──
-- The tests above build `NS.db` as a bare `{ profile = plainTable, global = {...} }`, which
-- never triggers AceDB's own copyDefaults and so could not have caught the bug where reading
-- `NS.db.profile` under the real library silently pre-populates `profile.units` from the NEW
-- defaults before the migration's guard ever ran. These two drive the actual production path —
-- NS:InitDB() -> AceDB:New() (tests/wow_mock.lua's mock, which now merges defaults into
-- pre-existing saved data the way real copyDefaults does) -> NS:RunMigrations() — against a
-- seeded SavedVariables global.
test("real AceDB init: a legacy flat profile is lifted onto the player unit, not overwritten by fresh defaults", function()
  local savedSV, savedDB = _G.AbsorbTrackerDB, NS.db
  _G.AbsorbTrackerDB = {
    profiles = {
      Default = {
        barWidth = 275,
        fontSize = 17,
        borderColor = { r = 0.9, g = 0.1, b = 0.1, a = 1.0 },
        position = { point = "TOP", relPoint = "TOP", x = 1, y = 2 },
      },
    },
    global = { schemaVersion = 2 },
  }
  NS:InitDB()
  local profile = NS.db.profile
  assertEqual(profile.units.player.barWidth, 275,
    "the user's saved barWidth must survive the upgrade, not revert to the factory default")
  assertEqual(profile.units.player.fontSize, 17)
  assertEqual(profile.units.player.borderColor.r, 0.9)
  assertEqual(profile.units.player.position.x, 1)
  assertEqual(profile.barWidth, nil, "the flat original must be cleared, not duplicated")
  assertEqual(profile.position, nil)
  assertEqual(NS.db.global.schemaVersion, 4)
  NS.db, _G.AbsorbTrackerDB = savedDB, savedSV
end)

test("real AceDB init: a fresh install (no saved data) converges on factory defaults at v4", function()
  local savedSV, savedDB = _G.AbsorbTrackerDB, NS.db
  _G.AbsorbTrackerDB = nil
  NS:InitDB()
  local profile = NS.db.profile
  assertEqual(profile.units.player.barWidth, NS.defaults.profile.units.player.barWidth)
  assertEqual(profile.units.player.enabled, true)
  assertEqual(profile.units.target.enabled, false)
  assertEqual(profile.units.target.mirror, true)
  assertEqual(profile.barWidth, nil, "a fresh install has no flat key to lift in the first place")
  assertEqual(NS.db.global.schemaVersion, 4)
  NS.db, _G.AbsorbTrackerDB = savedDB, savedSV
end)

-- ── Per-profile v3 lift: every profile, not just the active one ───────────────────
-- The account-wide `db.global.schemaVersion` cannot gate a PER-PROFILE mutation. A user on
-- "Default" with a second pre-v3 "Raid" profile used to migrate Default, flip the account-wide
-- stamp to 3, and strand Raid's flat barWidth / barColor / position forever — no later login
-- re-ran the lift, so their raid layout silently reverted to factory defaults.

test("InitDB lifts EVERY saved profile, not only the active one", function()
  local savedSV, savedDB = _G.AbsorbTrackerDB, NS.db
  _G.AbsorbTrackerDB = {
    profiles = {
      Default = { barWidth = 275 },
      Raid    = { barWidth = 411, position = { point = "TOP", relPoint = "TOP", x = 3, y = 4 } },
    },
    global = { schemaVersion = 2 },
  }
  NS:InitDB()
  local raid = _G.AbsorbTrackerDB.profiles.Raid
  assertEqual(NS.db.profile.units.player.barWidth, 275, "the active profile is lifted")
  assertEqual(raid.units.player.barWidth, 411,
    "an inactive pre-v3 profile must be lifted too, or its layout is unreachable forever")
  assertEqual(raid.units.player.position.x, 3, "including its saved position")
  assertEqual(raid.barWidth, nil, "the inactive profile's flat original must be cleared")
  assertEqual(raid.schemaVersion, 3, "and it carries its own stamp afterwards")
  NS.db, _G.AbsorbTrackerDB = savedDB, savedSV
end)

test("a profile that appears AFTER the upgrade is lifted when it becomes active", function()
  -- Copied in from another character, or restored from a backup SavedVariables file: it never
  -- passed through InitDB's sweep, and the account-wide stamp already reads 3.
  local savedSV, savedDB = _G.AbsorbTrackerDB, NS.db
  _G.AbsorbTrackerDB = { profiles = { Default = {} }, global = { schemaVersion = 3 } }
  NS:InitDB()
  NS.db.sv.profiles.Restored = { barWidth = 333, fontSize = 19 }
  NS.db:SetProfile("Restored")   -- fires OnProfileChanged, which re-runs the per-profile lift
  local p = NS.db.profile
  assertEqual(p.units.player.barWidth, 333,
    "a restored pre-v3 profile must still be lifted on activation")
  assertEqual(p.units.player.fontSize, 19)
  assertEqual(p.barWidth, nil, "and its flat originals cleared")
  assertEqual(p.schemaVersion, 3, "and stamped so it is never lifted twice")
  NS.db, _G.AbsorbTrackerDB = savedDB, savedSV
  T.mocks.__fireTimers()   -- OnProfileChanged published REPAINT; drain so `pending` resets
end)

test("the InitDB sweep and the profile-change lift compose without double-applying", function()
  local savedSV, savedDB = _G.AbsorbTrackerDB, NS.db
  _G.AbsorbTrackerDB = {
    profiles = { Default = { barWidth = 275 } },
    global   = { schemaVersion = 2 },
  }
  NS:InitDB()                                  -- mechanism (a): the sweep lifts Default
  assertEqual(NS.db.profile.units.player.barWidth, 275)
  NS.db.profile.units.player.barWidth = 500    -- the user then edits the migrated value
  NS.db.profile.barWidth = 999                 -- and a stale flat key is planted at the root
  NS.OnProfileChanged()                        -- mechanism (b) fires on the same profile
  assertEqual(NS.db.profile.units.player.barWidth, 500,
    "a second lift must not re-run and clobber the already-migrated value")
  assertEqual(NS.db.profile.barWidth, 999,
    "nor touch the profile root at all once the profile carries its own stamp")
  assertFalse(NS.MigrateProfileToV3(NS.db.profile),
    "the per-profile stamp \226\128\148 not the account-wide one \226\128\148 is the authority")
  NS.db, _G.AbsorbTrackerDB = savedDB, savedSV
  T.mocks.__fireTimers()   -- ditto
end)

test("the per-profile stamp defaults to 1 so copyDefaults cannot mark a pre-v3 profile migrated",
  function()
  -- Load-bearing: AceDB fills every absent key from the defaults BEFORE RunMigrations reads the
  -- profile. A default of 3 here would stamp every upgrading profile as already-migrated on first
  -- touch and make the whole gate dead code.
  assertEqual(NS.defaults.profile.schemaVersion, 1)
end)

test("a fresh install logs no [Migrate] lift line -- nothing was actually lifted", function()
  -- The per-profile stamp defaults to 1, so a factory-fresh profile passes the gate and gets
  -- stamped -- but it has no flat keys to move. Reporting that as a migration made a brand-new
  -- install log "lifted 1 profile(s) to v3" for work that never happened, contradicting
  -- docs/profiles.md's claim that the line appears only when the bump actually happens.
  local savedSV, savedDB, savedDebug = _G.AbsorbTrackerDB, NS.db, NS.State.debug
  _G.AbsorbTrackerDB = nil
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  NS:InitDB()
  local logged = table.concat(NS.DebugLog.buffer, "\n", before + 1, #NS.DebugLog.buffer)
  NS.db, _G.AbsorbTrackerDB, NS.State.debug = savedDB, savedSV, savedDebug
  assertTrue(logged:find("lifted", 1, true) == nil,
    "a fresh install lifted nothing and must say nothing: " .. logged)
end)

test("a real upgrade still logs the lift, with an accurate count", function()
  local savedSV, savedDB, savedDebug = _G.AbsorbTrackerDB, NS.db, NS.State.debug
  _G.AbsorbTrackerDB = {
    profiles = { Default = { barWidth = 275 }, Raid = { fontSize = 19 }, Fresh = {} },
    global   = { schemaVersion = 2 },
  }
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  NS:InitDB()
  local logged = table.concat(NS.DebugLog.buffer, "\n", before + 1, #NS.DebugLog.buffer)
  NS.db, _G.AbsorbTrackerDB, NS.State.debug = savedDB, savedSV, savedDebug
  assertTrue(logged:find("lifted 2 profile(s) to v3", 1, true) ~= nil,
    "two profiles carried flat keys; the third was empty and must not be counted: " .. logged)
end)
