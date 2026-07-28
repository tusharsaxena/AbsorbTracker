local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- ── RunMigrations: the schema-migration seam (Ka0s standard §2.2/§5.1) ─────────────
-- The current schema version is 3, so a full migration run leaves the DB stamped at 3.
test("RunMigrations migrates a fresh DB to the current version (3)", function()
  NS.db.global.schemaVersion = nil
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 3)
end)

test("RunMigrations leaves an already-current (v3) DB unchanged", function()
  NS.db.global.schemaVersion = 3
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 3)
end)

test("RunMigrations is idempotent across repeated runs", function()
  NS.db.global.schemaVersion = nil
  NS:RunMigrations(); NS:RunMigrations(); NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 3)
end)

test("RunMigrations v2 retires the legacy updateInterval profile key", function()
  NS.db.global.schemaVersion = 1
  NS.db.profile.updateInterval = 1.0
  NS:RunMigrations()
  assertEqual(NS.db.profile.updateInterval, nil)
  assertEqual(NS.db.global.schemaVersion, 3)
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

test("v3 migration leaves the four global keys flat", function()
  local profile = { hidden = true, locked = true, showOnlyInCombat = true, throttleWindow = 0.25 }
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  NS.db = savedDB
  assertEqual(profile.hidden, true)
  assertEqual(profile.throttleWindow, 0.25)
  assertEqual(profile.units.player.hidden, nil, "globals must not be duplicated per unit")
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

test("the schema version lands on 3", function()
  local savedDB = NS.db
  NS.db = { profile = {}, global = { schemaVersion = 1 } }
  NS:RunMigrations()
  local v = NS.db.global.schemaVersion
  NS.db = savedDB
  assertEqual(v, 3)
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
  assertEqual(NS.db.global.schemaVersion, 3)
  NS.db, _G.AbsorbTrackerDB = savedDB, savedSV
end)

test("real AceDB init: a fresh install (no saved data) converges on factory defaults at v3", function()
  local savedSV, savedDB = _G.AbsorbTrackerDB, NS.db
  _G.AbsorbTrackerDB = nil
  NS:InitDB()
  local profile = NS.db.profile
  assertEqual(profile.units.player.barWidth, NS.defaults.profile.units.player.barWidth)
  assertEqual(profile.units.player.enabled, true)
  assertEqual(profile.units.target.enabled, false)
  assertEqual(profile.units.target.mirror, true)
  assertEqual(profile.barWidth, nil, "a fresh install has no flat key to lift in the first place")
  assertEqual(NS.db.global.schemaVersion, 3)
  NS.db, _G.AbsorbTrackerDB = savedDB, savedSV
end)
