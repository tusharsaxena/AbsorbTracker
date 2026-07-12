local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- ── RunMigrations: the schema-migration seam (Ka0s standard §2.2/§5.1) ─────────────
test("RunMigrations stamps schemaVersion when absent", function()
  NS.db.global.schemaVersion = nil
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 1)
end)

test("RunMigrations leaves an already-current DB unchanged", function()
  NS.db.global.schemaVersion = 1
  NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 1)
end)

test("RunMigrations is idempotent across repeated runs", function()
  NS.db.global.schemaVersion = nil
  NS:RunMigrations(); NS:RunMigrations(); NS:RunMigrations()
  assertEqual(NS.db.global.schemaVersion, 1)
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
