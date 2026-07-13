local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- ── RunMigrations: the schema-migration seam (Ka0s standard §2.2/§5.1) ─────────────
-- The current schema version is 2, so a full migration run leaves the DB stamped at 2.
test("RunMigrations migrates a fresh DB to the current version (2)", function()
  NS.db.global.schemaVersion = nil
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
end)

test("RunMigrations leaves an already-current (v2) DB unchanged", function()
  NS.db.global.schemaVersion = 2
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
end)

test("RunMigrations is idempotent across repeated runs", function()
  NS.db.global.schemaVersion = nil
  NS:RunMigrations(); NS:RunMigrations(); NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 2)
end)

test("RunMigrations v2 retires the legacy updateInterval profile key", function()
  NS.db.global.schemaVersion = 1
  NS.db.profile.updateInterval = 1.0
  NS:RunMigrations()
  assertEqual(NS.db.profile.updateInterval, nil)
  assertEqual(NS.db.global.schemaVersion, 2)
end)

test("RunMigrations backfills throttleWindow from flatDefaults", function()
  NS.db.profile.throttleWindow = nil
  NS:RunMigrations()
  assertEqual(NS.db.profile.throttleWindow, NS.flatDefaults.throttleWindow)
end)

test("RunMigrations backfills a missing scalar profile key from flatDefaults", function()
  NS.db.profile.barWidth = nil
  NS:RunMigrations()
  assertEqual(NS.db.profile.barWidth, NS.flatDefaults.barWidth)
end)

test("RunMigrations deep-copies table defaults (no shared reference to flatDefaults)", function()
  NS.db.profile.barColor = nil
  NS:RunMigrations()
  assertTrue(NS.db.profile.barColor ~= NS.flatDefaults.barColor,
    "backfilled color table must be a copy, not the defaults reference")
  assertEqual(NS.db.profile.barColor.r, NS.flatDefaults.barColor.r)
end)

test("RunMigrations does not overwrite an existing user value", function()
  NS.db.profile.barWidth = 321
  NS:RunMigrations()
  assertEqual(NS.db.profile.barWidth, 321)
  NS.db.profile.barWidth = NS.flatDefaults.barWidth  -- restore
end)

test("RunMigrations is a safe no-op when the DB is absent", function()
  local saved = NS.db
  NS.db = nil
  NS:RunMigrations()   -- must not error with no db.global to touch
  NS.db = saved
end)

test("InitDB produced a profile carrying every default key", function()
  for k in pairs(NS.flatDefaults) do
    -- `position` defaults to nil, so it is legitimately absent.
    if k ~= "position" then
      assertTrue(NS.db.profile[k] ~= nil, "profile missing default key: " .. k)
    end
  end
end)
