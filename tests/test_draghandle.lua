local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local loadDegraded = dofile("tests/degraded_env.lua")

-- The unlocked drag affordance on each bar: how a bar is moved, and where the move is saved.
--
-- Two grab points. The bar body's own drag is the one that must survive everything -- a build with
-- no LibKa0s draws no strip over it, and the body is then the only grab point left. The other is
-- the drag handle modules/Bar.lua builds over each bar from LibKa0s-Widgets-1.0's DragHandle: a
-- labeled strip above the bar, shown only while the bars are unlocked. The widget itself -- its
-- chrome, its drag scripts, its tooltip drawing, its width arithmetic -- is tested in LibKa0s;
-- these cases pin what this addon hands it and when this addon shows it.

-- The stub frame answers GetPoint from its metatable with the frame itself; hand the bar a real
-- anchor for the duration of one call, and put back whatever was there.
local function withPoint(bar, point, relPoint, x, y, body)
  local previous = rawget(bar, "GetPoint")
  rawset(bar, "GetPoint", function() return point, UIParent, relPoint, x, y end)
  local ok, err = pcall(body)
  rawset(bar, "GetPoint", previous)
  if not ok then error(err) end
end

local function withLocked(value, body)
  local saved = NS.GetSetting("locked")
  T.rawSet("locked", value)
  local ok, err = pcall(body)
  T.rawSet("locked", saved)
  if not ok then error(err) end
end

-- Capture every call to `method` on `frame` while `body` runs, then put back whatever was there
-- (a kit frame's Show/Hide are real raw fields, so restoring nil would break them for good).
local function record(frame, method, body)
  local calls = {}
  local previous = rawget(frame, method)
  rawset(frame, method, function(_, ...) calls[#calls + 1] = { ... } return frame end)
  local ok, err = pcall(body)
  rawset(frame, method, previous)
  if not ok then error(err) end
  return calls
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

-- ── the handle: built once per bar, from the library ─────────────────────────────────────────

local Widgets = T.mocks.LibStub("LibKa0s-Widgets-1.0", true)

-- The spec one CreateBar hands the widget, captured by wrapping DragHandle for one build of a
-- throwaway bar. The widget's own frame hides what it was told (the label is set at construction),
-- so the spec is the honest place to read the strings from.
local function specFor(unit)
  local seen
  local real = Widgets.DragHandle
  Widgets.DragHandle = function(parent, spec) seen = spec return real(parent, spec) end
  local ok, bar = pcall(NS.CreateBar, unit, "ATDragHandleTest_" .. unit)
  Widgets.DragHandle = real
  if not ok then error(bar) end
  return seen, bar
end

test("the widget major is present, so the handle is not the degraded path", function()
  assertTrue(Widgets ~= nil and Widgets.DragHandle ~= nil,
    "libs/LibKa0s/WidgetsDragHandle.lua must have loaded and attached DragHandle")
end)

test("every bar owns a drag handle: a named Button parented to the bar", function()
  local names = { player = "AbsorbTrackerFrame", target = "AbsorbTrackerTargetFrame",
                  focus = "AbsorbTrackerFocusFrame" }
  for _, unit in ipairs(NS.Units.LIST) do
    local handle = NS.bars[unit].handle
    assertTrue(handle ~= nil, unit .. " bar has no handle")
    assertEqual(handle.__frameType, "Button")
    assertEqual(handle.__name, names[unit] .. "Handle", "the handle's global name follows the bar's")
    assertEqual(handle.__parent, NS.bars[unit], "the handle rides its own bar")
  end
end)

test("the handle is labeled with its own unit's name", function()
  for _, unit in ipairs(NS.Units.LIST) do
    local spec = specFor(unit)
    assertEqual(spec.label, NS.Units.LABEL[unit], unit .. " strip names the wrong unit")
  end
end)

test("the handle moves its own bar, with the help icon from the Media seam", function()
  local spec, bar = specFor("target")
  assertEqual(spec.moveFrame, bar)
  assertEqual(spec.name, "ATDragHandleTest_targetHandle")
  assertEqual(spec.helpIcon, NS.Icon("help"))
  assertTrue(spec.helpIcon ~= nil, "the vendored catalog ships a help mark")
  assertEqual(bar.handle.__parent, bar)
end)

-- ── shown exactly while unlocked ─────────────────────────────────────────────────────────────

test("unlocking shows every bar's handle; locking hides it", function()
  for _, unit in ipairs(NS.Units.LIST) do
    local handle = NS.bars[unit].handle
    withLocked(false, function() NS.UpdateBarAppearance(unit) end)
    assertTrue(handle:IsShown(), unit .. " handle hidden while unlocked")
    withLocked(true, function() NS.UpdateBarAppearance(unit) end)
    assertFalse(handle:IsShown(), unit .. " handle shown while locked")
  end
  NS.ForEachUnit(NS.UpdateBarAppearance)
end)

test("an unlocked handle is exactly as wide as its bar", function()
  -- Unmirrored for the case, so the width read is the focus bar's own and not the player's.
  local c = NS.db.profile.units.focus
  local saved, savedMirror = c.barWidth, c.mirror
  c.barWidth, c.mirror = 240, false
  local widths
  withLocked(false, function()
    widths = record(NS.bars.focus.handle, "SetWidth", function() NS.UpdateBarAppearance("focus") end)
  end)
  c.barWidth, c.mirror = saved, savedMirror
  NS.UpdateBarAppearance("focus")
  assertEqual(#widths, 1, "sized once per appearance pass")
  assertEqual(widths[1][1], 240, "floored at the bar's own width")
end)

test("a handle over a narrow bar takes its own natural width instead", function()
  local c = NS.db.profile.units.player
  local saved = c.barWidth
  c.barWidth = 10
  local widths
  withLocked(false, function()
    widths = record(NS.bars.player.handle, "SetWidth", function() NS.UpdateBarAppearance("player") end)
  end)
  c.barWidth = saved
  NS.UpdateBarAppearance("player")
  assertEqual(widths[1][1], NS.bars.player.handle:Measure(),
    "narrower than its label and help mark, the strip keeps room for both")
end)

test("a locked pass does not resize the hidden handle", function()
  local widths
  withLocked(true, function()
    widths = record(NS.bars.target.handle, "SetWidth", function() NS.UpdateBarAppearance("target") end)
  end)
  NS.UpdateBarAppearance("target")
  assertEqual(#widths, 0)
end)

test("the combat re-lock hides every handle", function()
  local savedUAC = T.mocks.UnitAffectingCombat
  local saved = NS.GetSetting("locked")
  T.rawSet("locked", false)
  NS.ForEachUnit(NS.UpdateBarAppearance)
  T.mocks.UnitAffectingCombat = function() return true end
  local ok, err = pcall(function() NS.addon:OnEnterCombat() end)
  T.mocks.UnitAffectingCombat = savedUAC
  T.mocks.__fireTimers()
  local shown = {}
  for _, unit in ipairs(NS.Units.LIST) do shown[unit] = NS.bars[unit].handle:IsShown() end
  T.rawSet("locked", saved)
  NS.ForEachUnit(NS.UpdateBarAppearance)
  if not ok then error(err) end
  for _, unit in ipairs(NS.Units.LIST) do
    assertFalse(shown[unit], unit .. " handle still shown after combat re-locked the bars")
  end
end)

-- ── dragging the handle ──────────────────────────────────────────────────────────────────────

test("a locked handle refuses the drag and does not move the bar", function()
  local bar = NS.bars.target
  local moves
  withLocked(true, function()
    moves = record(bar, "StartMoving", function() bar.handle:__fire("OnDragStart") end)
    assertFalse(specFor("target").canDrag(), "canDrag answers the lock")
  end)
  assertEqual(#moves, 0, "StartMoving on a locked (unmovable) bar raises in the client")
end)

test("an unlocked handle drags its bar", function()
  local bar = NS.bars.player
  local moves
  withLocked(false, function()
    assertTrue(specFor("player").canDrag())
    moves = record(bar, "StartMoving", function() bar.handle:__fire("OnDragStart") end)
    bar.handle:__fire("OnDragStop")
  end)
  assertEqual(#moves, 1)
end)

test("dropping a handle saves the position to its own bar's unit", function()
  for _, unit in ipairs(NS.Units.LIST) do
    local bar = NS.bars[unit]
    withSavedPosition(unit, function()
      withLocked(false, function()
        withPoint(bar, "BOTTOM", "TOP", -7, 8, function()
          bar.handle:__fire("OnDragStart")
          bar.handle:__fire("OnDragStop")
        end)
      end)
      local pos = NS.Units.Position(unit)
      assertTrue(pos ~= nil, unit .. " handle drop saved nothing")
      assertEqual(pos.point, "BOTTOM")
      assertEqual(pos.relPoint, "TOP")
      assertEqual(pos.x, -7)
      assertEqual(pos.y, 8)
    end)
  end
end)

test("the handle and the bar body save through the same writer", function()
  -- One save, two grab points: a drop on either must write the identical table shape.
  local fromBody, fromHandle
  local bar = NS.bars.focus
  withSavedPosition("focus", function()
    withLocked(false, function()
      withPoint(bar, "LEFT", "RIGHT", 1, 2, function()
        bar:__fire("OnDragStop")
        fromBody = NS.Units.Position("focus")
        NS.db.profile.units.focus.position = nil
        bar.handle:__fire("OnDragStart")
        bar.handle:__fire("OnDragStop")
        fromHandle = NS.Units.Position("focus")
      end)
    end)
  end)
  for _, k in ipairs({ "point", "relPoint", "x", "y" }) do
    assertEqual(fromHandle[k], fromBody[k], k)
  end
end)

-- ── tooltips ─────────────────────────────────────────────────────────────────────────────────

-- The lines one hover of `frame` put on GameTooltip: the title (SetText) then every AddLine.
local function hover(frame)
  local tip = T.mocks.GameTooltip
  local lines = {}
  local texts = record(tip, "SetText", function()
    local added = record(tip, "AddLine", function() frame:__fire("OnEnter") end)
    for _, a in ipairs(added) do lines[#lines + 1] = a[1] end
  end)
  frame:__fire("OnLeave")
  return texts[1] and texts[1][1], lines
end

test("the strip's tooltip names the addon and says how to move this bar", function()
  local title, lines
  withLocked(false, function() title, lines = hover(NS.bars.target.handle) end)
  assertEqual(title, "Absorb Tracker")
  assertEqual(#lines, 1)
  assertEqual(lines[1], "Drag to move the Target bar.")
end)

test("the strip's tooltip reads the lock on every hover", function()
  local _, lines
  withLocked(true, function() _, lines = hover(NS.bars.player.handle) end)
  assertEqual(lines[1], "Locked. Unlock the bars to move them \226\128\148 /at unlock.")
end)

test("the help mark has its own tooltip, with a footer saying how to put the strip away", function()
  local help = NS.bars.focus.handle.help
  assertTrue(help ~= nil, "the widget built its help mark")
  local title, lines
  withLocked(false, function() title, lines = hover(help) end)
  assertEqual(title, "Focus bar")
  assertEqual(lines[1], "Drag this handle, or the bar itself, to move the bar.")
  assertEqual(lines[#lines], "Lock the bars to hide this handle \226\128\148 /at lock.")
end)

-- ── degraded: no widget, no strip, nothing raises ────────────────────────────────────────────

test("degraded: with LibKa0s absent the bars load with no handle and keep their own drag", function()
  local NS2 = loadDegraded()
  for _, unit in ipairs(NS2.Units.LIST) do
    local bar = NS2.bars[unit]
    assertTrue(bar ~= nil, unit .. " bar failed to build without the library")
    assertNil(bar.handle, unit .. " drew a strip with no widget to draw it")
    assertTrue(bar:GetScript("OnDragStart") ~= nil and bar:GetScript("OnDragStop") ~= nil,
      unit .. " bar body lost its drag")
  end
end)

test("degraded: with no widget the default stack reserves no strip room", function()
  local NS2 = loadDegraded()
  local _, _, _, ty = NS2.DefaultPosition("target")
  assertEqual(ty, NS2.Units.Get("player", "barHeight") + 8, "the pre-strip bar height + 8px gap")
end)

test("an appearance pass over a bar with no handle raises nothing", function()
  local bar = NS.bars.target
  local handle = bar.handle
  bar.handle = nil
  local ok, err = pcall(function()
    withLocked(false, function() NS.UpdateBarAppearance("target") end)
    withLocked(true, function() NS.UpdateBarAppearance("target") end)
  end)
  bar.handle = handle
  NS.UpdateBarAppearance("target")
  if not ok then error(err) end
end)
