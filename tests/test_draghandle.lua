local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The unlocked drag affordance on each bar: how a bar is moved, and where the move is saved.
--
-- The bar body's own drag is the one way to move a bar that must survive everything -- a build
-- with no LibKa0s draws no strip over it, and the body is then the only grab point left. These
-- cases pin it per unit, so a change to the strip above the bar cannot quietly take the body's
-- drag, or its save, with it.

-- The stub frame answers GetPoint from its metatable with the frame itself; hand the bar a real
-- anchor for the duration of one call, and put back whatever was there.
local function withPoint(bar, point, relPoint, x, y, body)
  local previous = rawget(bar, "GetPoint")
  rawset(bar, "GetPoint", function() return point, UIParent, relPoint, x, y end)
  local ok, err = pcall(body)
  rawset(bar, "GetPoint", previous)
  if not ok then error(err) end
end

local function withSavedPosition(unit, body)
  local c = NS.db.profile.units[unit]
  local saved = c.position
  local ok, err = pcall(body)
  c.position = saved
  if not ok then error(err) end
end

-- ── the bar body's own drag ──────────────────────────────────────────────────────────────────

test("every bar body is registered for a left-button drag", function()
  for _, unit in ipairs(NS.Units.LIST) do
    local bar = NS.bars[unit]
    assertTrue(bar:GetScript("OnDragStart") ~= nil, unit .. " bar has no OnDragStart")
    assertTrue(bar:GetScript("OnDragStop") ~= nil, unit .. " bar has no OnDragStop")
  end
end)

test("dropping a bar body saves the position to that bar's own unit", function()
  for _, unit in ipairs(NS.Units.LIST) do
    withSavedPosition(unit, function()
      withPoint(NS.bars[unit], "TOPLEFT", "BOTTOMLEFT", 12, 34, function()
        NS.bars[unit]:__fire("OnDragStop")
      end)
      local pos = NS.Units.Position(unit)
      assertTrue(pos ~= nil, unit .. " drag-stop saved nothing")
      assertEqual(pos.point, "TOPLEFT")
      assertEqual(pos.relPoint, "BOTTOMLEFT")
      assertEqual(pos.x, 12)
      assertEqual(pos.y, 34)
    end)
  end
end)

test("dropping one bar leaves the other bars' positions alone", function()
  withSavedPosition("player", function()
    withSavedPosition("focus", function()
      NS.db.profile.units.player.position = nil
      withPoint(NS.bars.focus, "CENTER", "CENTER", 5, 6, function()
        NS.bars.focus:__fire("OnDragStop")
      end)
      assertEqual(NS.Units.Position("player"), nil, "a focus drop must not write the player's position")
      assertFalse(NS.Units.Position("focus") == nil)
    end)
  end)
end)
