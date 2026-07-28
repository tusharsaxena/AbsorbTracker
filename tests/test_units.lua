local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- core/Units.lua — unit identity and the mirror seam. Every appearance read in the addon goes
-- through Units.Get, so these tests pin the mirror resolution that the rest of the addon trusts.

local function withUnits(body)
  -- Snapshot and restore the whole units table so one test's mutation can't leak into the next.
  local saved = {}
  for _, u in ipairs(NS.Units.LIST) do
    local c, copy = NS.db.profile.units[u], {}
    for k, v in pairs(c) do
      if type(v) == "table" then
        local t = {}
        for kk, vv in pairs(v) do t[kk] = vv end
        copy[k] = t
      else
        copy[k] = v
      end
    end
    saved[u] = copy
  end
  local ok, err = pcall(body)
  for _, u in ipairs(NS.Units.LIST) do NS.db.profile.units[u] = saved[u] end
  if not ok then error(err) end
end

test("LIST is player, target, focus in render order", function()
  assertEqual(NS.Units.LIST[1], "player")
  assertEqual(NS.Units.LIST[2], "target")
  assertEqual(NS.Units.LIST[3], "focus")
  assertEqual(#NS.Units.LIST, 3)
end)

test("Get reads the unit's own value when it is not mirrored", function()
  withUnits(function()
    NS.db.profile.units.target.mirror = false
    NS.db.profile.units.target.barWidth = 321
    NS.db.profile.units.player.barWidth = 200
    assertEqual(NS.Units.Get("target", "barWidth"), 321)
  end)
end)

test("Get resolves to the player's value when the unit is mirrored", function()
  withUnits(function()
    NS.db.profile.units.focus.mirror = true
    NS.db.profile.units.focus.barWidth = 321
    NS.db.profile.units.player.barWidth = 200
    assertEqual(NS.Units.Get("focus", "barWidth"), 200,
      "a mirrored unit must ignore its own stored value")
  end)
end)

test("player is never mirrored even if a mirror key is force-written", function()
  withUnits(function()
    NS.db.profile.units.player.mirror = true
    assertEqual(NS.Units.IsMirrored("player"), false)
    assertEqual(NS.Units.SourceUnit("player"), "player")
  end)
end)

test("Position is never mirror-resolved", function()
  withUnits(function()
    NS.db.profile.units.focus.mirror = true
    NS.db.profile.units.player.position = { point = "TOP", relPoint = "TOP", x = 1, y = 2 }
    NS.db.profile.units.focus.position  = { point = "LEFT", relPoint = "LEFT", x = 3, y = 4 }
    assertEqual(NS.Units.Position("focus").point, "LEFT",
      "mirroring styling must not drag the position along")
  end)
end)

test("SetPosition writes the unit's own position while mirrored", function()
  withUnits(function()
    NS.db.profile.units.target.mirror = true
    NS.Units.SetPosition("target", { point = "BOTTOM", relPoint = "BOTTOM", x = 5, y = 6 })
    assertEqual(NS.db.profile.units.target.position.y, 6)
    assertEqual(NS.db.profile.units.player.position, nil)
  end)
end)

test("CopyFromPlayer snapshots every appearance key and clears the mirror", function()
  withUnits(function()
    NS.db.profile.units.player.barWidth = 275
    NS.db.profile.units.player.fontSize = 19
    NS.db.profile.units.focus.mirror = true
    NS.Units.CopyFromPlayer("focus")
    assertEqual(NS.db.profile.units.focus.mirror, false)
    assertEqual(NS.db.profile.units.focus.barWidth, 275)
    assertEqual(NS.db.profile.units.focus.fontSize, 19)
  end)
end)

test("a copied unit does not track later player changes", function()
  withUnits(function()
    NS.db.profile.units.player.barWidth = 275
    NS.db.profile.units.focus.mirror = true
    NS.Units.CopyFromPlayer("focus")
    NS.db.profile.units.player.barWidth = 400
    assertEqual(NS.Units.Get("focus", "barWidth"), 275, "copy is a snapshot, not a link")
  end)
end)

test("CopyFromPlayer deep-copies color tables rather than sharing them", function()
  withUnits(function()
    NS.Units.CopyFromPlayer("target")
    NS.db.profile.units.target.barColor.r = 0.11
    assertTrue(NS.db.profile.units.player.barColor.r ~= 0.11,
      "a shared table would let one unit's color picker repaint another bar")
  end)
end)

test("CopyFromPlayer leaves position and enabled alone", function()
  withUnits(function()
    NS.db.profile.units.target.enabled = true
    NS.db.profile.units.target.position = { point = "TOP", relPoint = "TOP", x = 7, y = 8 }
    NS.db.profile.units.player.position = { point = "LEFT", relPoint = "LEFT", x = 0, y = 0 }
    NS.Units.CopyFromPlayer("target")
    assertEqual(NS.db.profile.units.target.enabled, true)
    assertEqual(NS.db.profile.units.target.position.x, 7)
  end)
end)

test("CopyFromPlayer is a no-op for the player itself", function()
  withUnits(function()
    NS.db.profile.units.player.barWidth = 275
    NS.Units.CopyFromPlayer("player")
    assertEqual(NS.db.profile.units.player.barWidth, 275)
  end)
end)

test("IsEnabled reads the per-unit flag and ignores the global hidden toggle", function()
  withUnits(function()
    local savedHidden = NS.db.profile.hidden
    NS.db.profile.hidden = true
    NS.db.profile.units.target.enabled = true
    assertEqual(NS.Units.IsEnabled("target"), true,
      "the global master toggle is composed in ShouldShowBar, not here")
    NS.db.profile.units.target.enabled = false
    assertEqual(NS.Units.IsEnabled("target"), false)
    NS.db.profile.hidden = savedHidden
  end)
end)

test("target and focus ship disabled so an upgrade changes nothing on screen", function()
  assertEqual(NS.defaults.profile.units.player.enabled, true)
  assertEqual(NS.defaults.profile.units.target.enabled, false)
  assertEqual(NS.defaults.profile.units.focus.enabled, false)
end)

test("target and focus ship mirrored so a first enable looks like the player bar", function()
  assertEqual(NS.defaults.profile.units.target.mirror, true)
  assertEqual(NS.defaults.profile.units.focus.mirror, true)
  assertEqual(NS.defaults.profile.units.player.mirror, nil, "player is the mirror source")
end)
