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

-- Rawset every { frame, key, value } in `list` while `body` runs, then put back whatever was there.
-- The kit's frames answer an unknown capitalized method with the frame itself, which is not a
-- number, so a case that wants a geometry read to succeed has to hand the frame its answer.
local function withRaw(list, body)
  local saved = {}
  for i, p in ipairs(list) do
    saved[i] = rawget(p[1], p[2])
    rawset(p[1], p[2], p[3])
  end
  local ok, err = pcall(body)
  for i, p in ipairs(list) do rawset(p[1], p[2], saved[i]) end
  if not ok then error(err) end
end

local function answer(v) return function() return v end end

-- A screen `g.screen` px wide (UIParent's right edge), `strip` with its right edge at `g.right` and
-- an effective scale of `g.scale` (1 by default), GameTooltip `g.width` px wide, and the strip's two
-- marks parented to it (the kit's GetParent answers the frame itself). SetOwner and SetPoint on
-- GameTooltip are recorded into `g.owners` and `g.points` rather than no-opped.
local function withScreen(strip, g, body)
  local tip, ui = T.mocks.GameTooltip, T.mocks.UIParent
  g.owners, g.points = {}, {}
  local list = {
    { ui, "GetRight", answer(g.screen) }, { ui, "GetEffectiveScale", answer(1) },
    { strip, "GetRight", answer(g.right) }, { strip, "GetEffectiveScale", answer(g.scale or 1) },
    { tip, "GetWidth", answer(g.width) }, { tip, "GetEffectiveScale", answer(1) },
    { tip, "SetOwner", function(_, owner, anchor) g.owners[#g.owners + 1] = { owner, anchor } end },
    { tip, "SetPoint", function(_, ...) g.points[#g.points + 1] = { ... } end },
    { tip, "ClearAllPoints", function() g.points = {} end },
  }
  for _, mark in ipairs({ strip.help, strip.close }) do list[#list + 1] = { mark, "GetParent", answer(strip) } end
  withRaw(list, body)
end

-- The lines one hover of `frame` put on GameTooltip: the title (SetText) then every AddLine.
-- `strip` is the strip `frame` belongs to (itself when omitted); it is given room on a 1000 px
-- screen, so the strip's placement succeeds and the tooltip is drawn once.
local function hover(frame, strip)
  local tip = T.mocks.GameTooltip
  local lines, texts = {}, nil
  withScreen(strip or frame, { screen = 1000, right = 500, width = 200 }, function()
    texts = record(tip, "SetText", function()
      local added = record(tip, "AddLine", function() frame:__fire("OnEnter") end)
      for _, a in ipairs(added) do lines[#lines + 1] = a[1] end
    end)
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
  withLocked(false, function() title, lines = hover(help, NS.bars.focus.handle) end)
  assertEqual(title, "Focus bar")
  assertEqual(lines[1], "Drag this handle, or the bar itself, to move the bar.")
  assertEqual(lines[#lines], "Lock the bars to hide this handle \226\128\148 /at lock.")
end)

-- ── the close mark (X-04, X-05): every bar, the player bar included ─────────────────────────

-- Click one strip's X with that unit's bar enabled, spying on the schema write seam and on chat.
-- Everything the click touches is put back afterwards, through the same seam.
local function clickClose(unit)
  local c = NS.db.profile.units[unit]
  local savedEnabled, savedPos = c.enabled, c.position
  c.enabled = true
  c.position = { point = "TOP", relPoint = "TOP", x = 3, y = -4 }
  local writes, lines = {}, {}
  local realSet, realPrint = NS.SetByPath, NS.Print
  NS.SetByPath = function(path, v, ...)
    writes[#writes + 1] = { path, v }
    return realSet(path, v, ...)
  end
  NS.Print = function(...) lines[#lines + 1] = table.concat({ ... }, " ") end
  local ok, err = pcall(function()
    withLocked(false, function() NS.bars[unit].handle.close:__fire("OnClick", "LeftButton") end)
  end)
  NS.SetByPath, NS.Print = realSet, realPrint
  local after = { enabled = c.enabled, position = c.position }
  c.position = savedPos
  NS.SetByPath("units." .. unit .. ".enabled", savedEnabled)
  if not ok then error(err) end
  return writes, lines, after
end

test("every bar's strip carries a close mark, the player bar included", function()
  for _, unit in ipairs(NS.Units.LIST) do
    local handle = NS.bars[unit].handle
    assertTrue(handle.close ~= nil, unit .. " strip has no close mark")
    assertTrue(handle.close.icon ~= nil, unit .. " close mark has no art")
  end
end)

test("the close mark's art comes from the Media seam", function()
  local spec = specFor("player")
  assertTrue(type(spec.onClose) == "function", "the player strip is handed an onClose")
  assertEqual(spec.closeIcon, NS.Icon("close"))
  assertTrue(spec.closeIcon ~= nil, "the vendored catalog ships a close mark")
end)

test("a strip with a close mark reserves room for it on both sides", function()
  local D = Widgets.DRAG_HANDLE
  for _, unit in ipairs(NS.Units.LIST) do
    assertEqual(NS.bars[unit].handle:Reserve(), D.RESERVE + D.HELP_HIT + D.CLOSE_GAP,
      unit .. " strip does not reserve the close mark's room")
  end
end)

test("clicking X turns off exactly that unit's bar, through the schema seam", function()
  for _, unit in ipairs(NS.Units.LIST) do
    local writes, _, after = clickClose(unit)
    assertEqual(#writes, 1, unit .. ": one write, and only one")
    assertEqual(writes[1][1], "units." .. unit .. ".enabled")
    assertEqual(writes[1][2], false)
    assertEqual(after.enabled, false, unit .. " bar still enabled after X")
  end
end)

test("clicking X leaves the bar's position, the other bars and the addon-wide enable alone", function()
  local addonOn, playerOn = NS.GetSetting("enabled"), NS.Units.IsEnabled("player")
  local _, _, after = clickClose("target")
  assertEqual(after.position.point, "TOP")
  assertEqual(after.position.x, 3)
  assertEqual(after.position.y, -4)
  assertEqual(NS.GetSetting("enabled"), addonOn, "X must never touch the addon-wide enable")
  assertEqual(NS.Units.IsEnabled("player"), playerOn, "X on one bar leaves the others alone")
end)

test("clicking X prints one line naming the way back", function()
  local _, lines = clickClose("target")
  assertEqual(#lines, 1)
  assertEqual(lines[1], "Target bar hidden. Re-enable it on General > Bars or with /at toggle target.")
  local _, playerLines = clickClose("player")
  assertEqual(playerLines[1], "Player bar hidden. Re-enable it on General > Bars or with /at toggle player.")
end)

test("the close mark's tooltip says what X does and names the same way back", function()
  local title, lines = hover(NS.bars.focus.handle.close, NS.bars.focus.handle)
  assertEqual(title, "Hide the Focus bar")
  assertEqual(lines[1], "Click to hide this bar.")
  assertEqual(lines[#lines], "Re-enable it on General > Bars or with /at toggle focus.")
end)

-- ── where the tooltips sit: beside the strip (TP-AT-02) ─────────────────────────────────────
--
-- Every strip hands the widget NS.Util.PlaceTooltipBeside as `tooltipPlace` (LibKa0s
-- WidgetsDragHandle minor 4), the same placement every Ka0s strip uses (KickCD's TP-KC-01). The
-- owner's rule: the tooltip sits to the strip's RIGHT, or to its LEFT when the strip's right edge
-- plus the tooltip's width would leave the screen. Only a literal `true` means placed; anything
-- else makes the widget fall back to the cursor, so a read that cannot be trusted must answer
-- non-true and leave the tooltip unanchored rather than guess.

-- A bare strip with its two marks and a bare tooltip, for the placement on its own. The marks'
-- parent is the strip, as the widget builds them; `strip.help` is what marks a frame as the strip.
local function placeBench()
  local M = T.mocks
  local strip, tip = M.__stubFrame(), M.__stubFrame()
  strip.help, strip.close = M.__stubFrame(), M.__stubFrame()
  rawset(strip.help, "GetParent", answer(strip))
  rawset(strip.close, "GetParent", answer(strip))
  local points = {}
  rawset(tip, "SetPoint", function(_, ...) points[#points + 1] = { ... } end)
  rawset(tip, "ClearAllPoints", function() for i = #points, 1, -1 do points[i] = nil end end)
  rawset(tip, "GetEffectiveScale", answer(1))
  return strip, tip, points
end

-- Run the placement for `frame` (the strip or one of its marks) on a `screen` px screen with the
-- strip's right edge at `right` (or the result of `read`) and a tooltip `width` px wide.
local function place(strip, tip, frame, g)
  local placed
  withRaw({
    { T.mocks.UIParent, "GetRight", answer(g.screen) },
    { T.mocks.UIParent, "GetEffectiveScale", answer(1) },
    { strip, "GetRight", g.read or answer(g.right) },
    { strip, "GetEffectiveScale", answer(g.scale or 1) },
    { tip, "GetWidth", answer(g.width) },
  }, function() placed = NS.Util.PlaceTooltipBeside(tip, frame) end)
  return placed
end

test("PlaceTooltipBeside puts the tooltip to the strip's right when it fits", function()
  local strip, tip, points = placeBench()
  assertEqual(place(strip, tip, strip, { screen = 1000, right = 500, width = 200 }), true,
    "a placement it made answers true")
  assertEqual(#points, 1)
  local point, rel, relPoint, x, y = unpack(points[1])
  assertEqual(point, "TOPLEFT")
  assertTrue(rawequal(rel, strip), "anchored to the strip itself")
  assertEqual(relPoint, "TOPRIGHT")
  assertEqual(x, 4, "a 4 px gap clear of the strip's right edge")
  assertEqual(y, 0)
end)

test("PlaceTooltipBeside flips to the strip's left when the right side would leave the screen", function()
  -- red under: a placement that always anchors right (900 + 200 runs 100 px off a 1000 px screen)
  local strip, tip, points = placeBench()
  assertEqual(place(strip, tip, strip, { screen = 1000, right = 900, width = 200 }), true)
  assertEqual(#points, 1)
  local point, rel, relPoint, x, y = unpack(points[1])
  assertEqual(point, "TOPRIGHT")
  assertTrue(rawequal(rel, strip))
  assertEqual(relPoint, "TOPLEFT")
  assertEqual(x, -4, "a 4 px gap clear of the strip's left edge")
  assertEqual(y, 0)
end)

test("PlaceTooltipBeside anchors to the STRIP when the hovered frame is its ? mark or its X", function()
  -- The widget hands the hook the frame hovered; for a mark that is the mark, whose parent is the
  -- strip. One position for the strip and both its marks, not three.
  for _, key in ipairs({ "help", "close" }) do
    local strip, tip, points = placeBench()
    assertEqual(place(strip, tip, strip[key], { screen = 1000, right = 500, width = 200 }), true, key)
    local _, rel, relPoint = unpack(points[1])
    assertTrue(rawequal(rel, strip), "the " .. key .. " mark resolves to its strip")
    assertEqual(relPoint, "TOPRIGHT")
  end
end)

test("PlaceTooltipBeside compares in screen pixels, so a scaled strip flips when it should", function()
  -- red under: comparing the strip's raw GetRight (450, in its own scaled units) with the screen.
  -- At an effective scale of 2 (a bar scale times the master scale) its right edge is 900 screen
  -- px, and 900 + 200 does not fit in 1000.
  local strip, tip, points = placeBench()
  assertEqual(place(strip, tip, strip, { screen = 1000, right = 450, width = 200, scale = 2 }), true)
  assertEqual(points[1][1], "TOPRIGHT")
end)

test("PlaceTooltipBeside answers non-true and anchors nothing when a read is secret", function()
  -- red under: a placement that does arithmetic on whatever GetRight answered. The secret here is
  -- a plain number the concat probe refuses, so only the secret guard can catch it.
  local SECRET_EDGE = 123.5
  local realSafe = NS.IsConcatSafe
  NS.IsConcatSafe = function(v) return v ~= SECRET_EDGE and realSafe(v) end
  local strip, tip, points = placeBench()
  local ok, placed = pcall(place, strip, tip, strip, { screen = 1000, right = SECRET_EDGE, width = 200 })
  NS.IsConcatSafe = realSafe
  if not ok then error(placed) end
  assertTrue(placed ~= true, "the widget must fall back to the cursor")
  assertEqual(#points, 0, "nothing anchored on a guess")
end)

test("PlaceTooltipBeside answers non-true and anchors nothing when a read is nil", function()
  -- A strip not yet laid out answers nil for its edges in the client.
  local strip, tip, points = placeBench()
  assertTrue(place(strip, tip, strip, { screen = 1000, read = answer(nil), width = 200 }) ~= true)
  assertEqual(#points, 0)
end)

test("hovering a strip, its ? or its X puts the tooltip beside the strip, owned once", function()
  -- red under: a spec without the hook, which owns the tooltip by the hovered frame (ANCHOR_TOP
  -- off the strip, ANCHOR_TOPRIGHT off a mark) and anchors nothing beside the strip.
  for _, unit in ipairs(NS.Units.LIST) do
    local strip = NS.bars[unit].handle
    for _, frame in ipairs({ strip, strip.help, strip.close }) do
      local g = { screen = 1000, right = 500, width = 200 }
      withScreen(strip, g, function() frame:__fire("OnEnter") end)
      frame:__fire("OnLeave")
      assertEqual(#g.owners, 1, unit .. ": placed on the first try, so owned once")
      assertTrue(rawequal(g.owners[1][1], T.mocks.UIParent), "owned by UIParent, as the hook requires")
      assertEqual(g.owners[1][2], "ANCHOR_NONE")
      assertEqual(#g.points, 1)
      local point, rel, relPoint = unpack(g.points[1])
      assertEqual(point, "TOPLEFT")
      assertTrue(rawequal(rel, strip), unit .. ": beside the strip, whichever part was hovered")
      assertEqual(relPoint, "TOPRIGHT")
    end
  end
end)

test("a strip near the screen's right edge opens its tooltip on its left", function()
  local strip = NS.bars.player.handle
  local g = { screen = 1000, right = 900, width = 200 }
  withScreen(strip, g, function() strip:__fire("OnEnter") end)
  strip:__fire("OnLeave")
  local point, rel, relPoint = unpack(g.points[1])
  assertEqual(point, "TOPRIGHT")
  assertTrue(rawequal(rel, strip))
  assertEqual(relPoint, "TOPLEFT", "900 + 200 leaves a 1000 px screen, so the left side")
end)

test("a strip whose geometry cannot be read falls back to the cursor tooltip", function()
  -- The widget's own fallback: re-owned at the cursor, with the same lines redrawn.
  local strip = NS.bars.target.handle
  local g = { screen = 1000, right = nil, width = 200 }
  withScreen(strip, g, function() strip:__fire("OnEnter") end)
  strip:__fire("OnLeave")
  assertEqual(#g.owners, 2)
  assertEqual(g.owners[2][2], "ANCHOR_CURSOR")
  assertEqual(#g.points, 0, "nothing anchored beside the strip")
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
