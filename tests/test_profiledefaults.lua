local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue =
  T.test, T.assertEqual, T.assertTrue

-- What a NEW profile starts with, and what an EXISTING one keeps (ATF-02, owner 2026-11-23:
-- "Default setup for a new profile should be to enable all three bars, none of them linked.
-- Position should be stack on on top of another for initial positioning").
--
-- THE TRAP THESE CASES GUARD. AceDB stores only what differs from a default, and strips a value
-- equal to its default at logout, so an existing profile that never touched target or focus stores
-- no `enabled` and no `mirror` for them. Flipping the defaults alone would turn both bars on and
-- unlink them on every such profile at its next login. Ladder step v11 (core/Database.lua) writes
-- the old values into every profile that existed before the load, and only into those.
--
-- Each case seeds the SavedVariables global and drives the real NS:InitDB through the kit's AceDB
-- fake, which merges the defaults into the active profile the moment it is created: exactly the
-- state in which a stored value and a merged default can no longer be told apart.

local LEGACY = { target = true, focus = true }

--- Run `fn` against a fresh InitDB over `sv`, then put the suite's DB back.
local function withDB(sv, fn)
  local savedSV, savedDB = _G.AbsorbTrackerDB, NS.db
  _G.AbsorbTrackerDB = sv
  local ok, err = pcall(function()
    NS:InitDB()
    fn(NS.db)
  end)
  NS.db, _G.AbsorbTrackerDB = savedDB, savedSV
  NS.HideSkinPicker()
  T.mocks.__fireTimers()
  if not ok then error(err, 0) end
end

local function assertLegacy(units, unit, why)
  assertEqual(units[unit].enabled, false, why .. ": " .. unit .. " stays off")
  assertEqual(units[unit].mirror, true, why .. ": " .. unit .. " stays linked to the player")
end

local function assertFresh(units, why)
  for _, unit in ipairs(NS.Units.LIST) do
    assertEqual(units[unit].enabled, true, why .. ": " .. unit .. " is on")
    if unit ~= "player" then
      assertEqual(units[unit].mirror, false, why .. ": " .. unit .. " is not linked")
    end
  end
end

-- red under: the defaults flipped with no v11 step, or a step that reads the merged profile
-- (where the new default already sits) instead of what the SavedVariables file stored.
test("profile defaults: an existing profile keeps target and focus off and linked", function()
  withDB({
    profiles = { Default = { schemaVersion = 3, units = { player = { barWidth = 250 } } } },
    global = { schemaVersion = 10 },
  }, function(db)
    for unit in pairs(LEGACY) do assertLegacy(db.profile.units, unit, "the active profile") end
    assertEqual(db.profile.units.player.barWidth, 250, "the player's own look is untouched")
    assertEqual(db.global.schemaVersion, 11, "stamped at v11")
  end)
end)

-- red under: a v11 that walks only the active profile.
test("profile defaults: every stored profile keeps its look, inactive ones included", function()
  withDB({
    profiles = {
      Default = { schemaVersion = 3 },
      Raid    = { schemaVersion = 3, units = { focus = { barWidth = 300 } } },
    },
    global = { schemaVersion = 10 },
  }, function(db)
    local raid = db.sv.profiles.Raid
    for unit in pairs(LEGACY) do assertLegacy(raid.units, unit, "the inactive profile") end
    assertEqual(raid.units.focus.barWidth, 300, "its own values are kept")
  end)
end)

-- red under: a v11 that writes the old value over one the player stored.
test("profile defaults: a bar the player turned on or unlinked stays that way", function()
  withDB({
    profiles = { Default = { schemaVersion = 3, units = {
      target = { enabled = true },
      focus  = { mirror = false },
    } } },
    global = { schemaVersion = 10 },
  }, function(db)
    local u = db.profile.units
    assertEqual(u.target.enabled, true, "the target the player enabled stays on")
    assertEqual(u.target.mirror, true, "its link, never stored, keeps the old default")
    assertEqual(u.focus.enabled, false, "the focus enable, never stored, keeps the old default")
    assertEqual(u.focus.mirror, false, "the focus the player unlinked stays unlinked")
  end)
end)

-- red under: values the step wrote that AceDB strips again at the next logout or switch (a write
-- equal to the NEW default would be stripped, and the profile would read the new default).
test("profile defaults: the kept values survive AceDB's strip at the next switch", function()
  withDB({
    profiles = { Default = { schemaVersion = 3 } },
    global = { schemaVersion = 10 },
  }, function(db)
    db:SetProfile("ATFOther")                    -- removeDefaults runs over the outgoing profile
    local raw = db.sv.profiles.Default
    for unit in pairs(LEGACY) do assertLegacy(raw.units, unit, "the stripped SavedVariables") end
    db:SetProfile("Default")
    db.sv.profiles.ATFOther = nil
  end)
end)

test("profile defaults: a fresh install gets three enabled, unlinked bars", function()
  withDB(nil, function(db)
    assertFresh(db.profile.units, "a fresh install")
    assertEqual(db.global.schemaVersion, 11)
  end)
end)

-- red under: a step that runs again later, or one that catches a profile created after the load.
test("profile defaults: a profile made after the upgrade gets three enabled, unlinked bars", function()
  withDB({
    profiles = { Default = { schemaVersion = 3 } },
    global = { schemaVersion = 10 },
  }, function(db)
    db:SetProfile("ATFBrandNew")
    assertFresh(db.profile.units, "a new profile")
    NS.Slash:OnSlash("profile new ATFSlashNew")
    assertFresh(db.profile.units, "/at profile new")
    db:SetProfile("Default")
    for unit in pairs(LEGACY) do assertLegacy(db.profile.units, unit, "back on the old profile") end
    db.sv.profiles.ATFBrandNew, db.sv.profiles.ATFSlashNew = nil, nil
  end)
end)

test("profile defaults: a reset profile starts from the new defaults", function()
  withDB({
    profiles = { Default = { schemaVersion = 3 } },
    global = { schemaVersion = 10 },
  }, function(db)
    NS.ResetProfileCounted(db)
    assertFresh(db.profile.units, "a reset profile")
  end)
end)

-- red under: a v3 lift that seeds a pre-v3 profile's units from the new defaults. Such a profile
-- predates target and focus, so they start as they always did: off and linked.
test("profile defaults: a pre-v3 profile restored after the upgrade starts with target and focus off", function()
  withDB({ profiles = { Default = { schemaVersion = 3 } }, global = { schemaVersion = 11 } },
  function(db)
    db.sv.profiles.ATFRestored = { barWidth = 333 }
    db:SetProfile("ATFRestored")
    for unit in pairs(LEGACY) do assertLegacy(db.profile.units, unit, "the restored profile") end
    assertEqual(db.profile.units.player.barWidth, 333, "its flat width was lifted")
    db:SetProfile("Default")
    db.sv.profiles.ATFRestored = nil
  end)
end)

-- The stacked default (modules/Display.lua NS.DefaultPosition) on a new profile: player at the
-- screen's center, target above it, focus above that, at the default sizes and with no overlap.
test("profile defaults: a new profile's three bars stack one above another with no overlap", function()
  withDB(nil, function(db)
    local u = db.profile.units
    local prevTop
    for i, unit in ipairs(NS.Units.LIST) do
      assertEqual(u[unit].position, nil, unit .. " has no stored position")
      local point, relPoint, x, y = NS.DefaultPosition(unit)
      assertEqual(point, "CENTER", unit .. " anchors at its center")
      assertEqual(relPoint, "CENTER", unit .. " to the screen's center")
      assertEqual(x, 0, unit .. " is centered horizontally")
      local h = NS.Units.Get(unit, "barHeight")
      local bottom, top = y - h / 2, y + h / 2
      if i > 1 then
        assertTrue(bottom > prevTop, unit .. " sits wholly above the bar before it")
      end
      prevTop = top
    end
  end)
end)
