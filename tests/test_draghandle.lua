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

-- A screen `g.sw` x `g.sh` (UIParent, scale 1: the kit's fake screen, tests/_kit/mock_screen.lua,
-- kit revision 57), `strip` at `g.left`, `g.bottom`, `g.width` x
-- `g.height` in its own units at an effective scale of `g.scale` (1 by default), GameTooltip
-- `g.tipW` x `g.tipH` at scale 1, and the strip's marks parented to it (the kit's GetParent answers
-- the frame itself). Every figure LibKa0s-Tooltip-1.0's PlaceAttached reads is answered, so the
-- library placer the widget calls actually places. `g.top`, when given, overrides the strip's
-- GetTop (a secret or nil read). SetOwner and SetPoint on GameTooltip are recorded into `g.owners`
-- and `g.points` rather than no-opped. The strip and GameTooltip are the addon's real frame and
-- the kit's global tooltip, not frames the screen built, so their figures are rawset here; the
-- screen supplies UIParent's whole geometry and puts it back afterwards.
local function withScreen(strip, g, body)
  local tip = T.mocks.GameTooltip
  g.sw, g.sh = g.sw or 1000, g.sh or 800
  g.tipW, g.tipH = g.tipW or 200, g.tipH or 80
  g.owners, g.points = {}, {}
  local top = g.top
  if top == nil and g.bottom ~= nil then top = g.bottom + g.height end
  local function edge(v) return function() return v end end
  local scr = dofile("tests/_kit/mock_screen.lua")(T.mocks, { width = g.sw, height = g.sh })
  local list = {
    { strip, "GetLeft", edge(g.left) }, { strip, "GetBottom", edge(g.bottom) },
    { strip, "GetRight", edge(g.left and g.left + g.width) }, { strip, "GetTop", edge(top) },
    { strip, "GetEffectiveScale", answer(g.scale or 1) },
    { tip, "GetWidth", answer(g.tipW) }, { tip, "GetHeight", answer(g.tipH) },
    { tip, "GetEffectiveScale", answer(1) },
    { tip, "SetOwner", function(_, owner, anchor) g.owners[#g.owners + 1] = { owner, anchor } end },
    { tip, "SetPoint", function(_, ...) g.points[#g.points + 1] = { ... } end },
    { tip, "ClearAllPoints", function() g.points = {} end },
  }
  for _, mark in ipairs({ strip.help, strip.close, strip.settings }) do
    list[#list + 1] = { mark, "GetParent", answer(strip) }
  end
  local ok, err = pcall(withRaw, list, body)
  scr.restore()
  if not ok then error(err, 0) end
end

-- A strip mid-screen: 400..600 x 500..516 on a 1000 x 800 screen, with room above it.
local function midScreen() return { left = 400, bottom = 500, width = 200, height = 16 } end

-- The lines one hover of `frame` put on GameTooltip: the title (SetText) then every AddLine.
-- `strip` is the strip `frame` belongs to (itself when omitted); it sits mid-screen, so the
-- library's placement succeeds and the tooltip is drawn once.
local function hover(frame, strip)
  local tip = T.mocks.GameTooltip
  local lines, texts = {}, nil
  withScreen(strip or frame, midScreen(), function()
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

test("a strip with a close mark and a settings mark reserves room for both on both sides", function()
  -- Re-pinned by AD-86-AT (LibKa0s#86, WidgetsDragHandle minor 14): the settings mark is the X's
  -- twin, so each side of the label keeps one more mark frame and gap clear. Until then the reserve
  -- was RESERVE + one mark (the X's).
  local D = Widgets.DRAG_HANDLE
  for _, unit in ipairs(NS.Units.LIST) do
    assertEqual(NS.bars[unit].handle:Reserve(), D.RESERVE + 2 * (D.HELP_HIT + D.CLOSE_GAP),
      unit .. " strip does not reserve the close and settings marks' room")
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
  assertEqual(lines[1], "Target bar hidden. Re-enable it on the Appearance page or with /at toggle target.")
  local _, playerLines = clickClose("player")
  assertEqual(playerLines[1], "Player bar hidden. Re-enable it on the Appearance page or with /at toggle player.")
end)

test("the close mark's tooltip says what X does and names the same way back", function()
  local title, lines = hover(NS.bars.focus.handle.close, NS.bars.focus.handle)
  assertEqual(title, "Hide the Focus bar")
  assertEqual(lines[1], "Click to hide this bar.")
  assertEqual(lines[#lines], "Re-enable it on the Appearance page or with /at toggle focus.")
end)

-- ── the settings mark (AD-86-AT, LibKa0s#86; AF-STRIP-AT): every bar, between the ? and the X ──────────────────

-- Opening a bar's settings: the call NS.OpenOptionsPanel is handed, and the unit the Appearance
-- page holds afterwards. The page's ctx is the one tests/run.lua's CreateOptionsPanel built.
local function clickSettings(unit, openAnswer)
  local ctx = NS.Helpers.__panelFor("appearance")
  local savedUnit = ctx and ctx.unit
  local realOpen, opened = NS.OpenOptionsPanel, {}
  NS.OpenOptionsPanel = function(page) opened[#opened + 1] = page or "landing" return openAnswer end
  local ok, err = pcall(function()
    withLocked(false, function() NS.bars[unit].handle.settings:__fire("OnClick", "LeftButton") end)
  end)
  NS.OpenOptionsPanel = realOpen
  local held = ctx and ctx.unit
  if ctx then ctx.unit = savedUnit end
  if not ok then error(err) end
  return opened, held
end

test("every bar's strip carries all three marks: ?, settings and close", function()
  -- red under: `settings = false` (the gear is the default from WidgetsDragHandle minor 15), a spec
  -- with no onClose (no X), or no help mark.
  for _, unit in ipairs(NS.Units.LIST) do
    local handle = NS.bars[unit].handle
    assertTrue(handle.help ~= nil, unit .. " strip has no help mark")
    assertTrue(handle.settings ~= nil, unit .. " strip has no settings mark")
    assertTrue(handle.settings.icon ~= nil, unit .. " settings mark has no art")
    assertTrue(handle.close ~= nil, unit .. " strip has no close mark")
  end
end)

test("the settings mark opens this bar's own settings, with its art from the Media seam", function()
  -- red under: AD-86-AT's `settings = true`, which sent every gear to the landing page.
  local spec = specFor("focus")
  assertTrue(spec.settings ~= false, "never opted out of the standard settings mark")
  assertTrue(type(spec.onSettings) == "function", "the gear opens this bar's page, not the landing page")
  assertEqual(spec.settingsIcon, NS.Icon("settings"))
  assertTrue(spec.settingsIcon ~= nil, "the vendored catalog ships a settings mark")
end)

test("clicking a strip's settings mark opens the Appearance page on that strip's unit", function()
  for _, unit in ipairs(NS.Units.LIST) do
    local opened, held = clickSettings(unit, true)
    assertEqual(#opened, 1, unit .. ": one click, one open")
    assertEqual(opened[1], "appearance", unit .. ": the gear opens the Appearance page")
    assertEqual(held, unit, unit .. ": the Appearance page shows the clicked bar's unit")
  end
end)

test("a refused open (combat) leaves the Appearance page's unit alone", function()
  local ctx = NS.Helpers.__panelFor("appearance")
  local before = ctx.unit
  local opened, held = clickSettings(before == "focus" and "target" or "focus", false)
  assertEqual(#opened, 1)
  assertEqual(held, before, "a refused open must not move the page to another unit")
end)

test("NS.OpenUnitSettings hands the page key through to the library's opener", function()
  local real, seen = NS.Helpers.OpenOptionsPanel, {}
  NS.Helpers.OpenOptionsPanel = function(page) seen[#seen + 1] = page return false end
  local ok, err = pcall(NS.OpenUnitSettings, "target")
  NS.Helpers.OpenOptionsPanel = real
  if not ok then error(err) end
  assertEqual(seen[1], "appearance", "NS.OpenOptionsPanel must not drop its page key")
end)

test("the settings mark's click touches no bar setting", function()
  local c = NS.db.profile.units.target
  local enabled, writes = c.enabled, 0
  local realSet = NS.SetByPath
  NS.SetByPath = function(...) writes = writes + 1 return realSet(...) end
  local ok, err = pcall(clickSettings, "target", true)
  NS.SetByPath = realSet
  if not ok then error(err) end
  assertEqual(writes, 0, "opening the settings writes nothing")
  assertEqual(c.enabled, enabled)
end)

test("the settings mark's tooltip names its bar and its page, not how to drag the strip", function()
  local title, lines = hover(NS.bars.player.handle.settings, NS.bars.player.handle)
  assertEqual(title, "Player bar settings")
  assertEqual(lines[1], "Click to open this bar's settings on the Appearance page.")
  local focusTitle = hover(NS.bars.focus.handle.settings, NS.bars.focus.handle)
  assertEqual(focusTitle, "Focus bar settings")
end)

test("the close mark's tooltip says the bar can be turned back on, and where", function()
  -- The owner's ruling (AF-STRIP): close is restorable, and the X's tooltip says how.
  for _, unit in ipairs(NS.Units.LIST) do
    local _, lines = hover(NS.bars[unit].handle.close, NS.bars[unit].handle)
    assertEqual(lines[#lines], "Re-enable it on the Appearance page or with /at toggle " .. unit .. ".")
  end
end)

-- ── where the tooltips sit: attached above the strip (AD-92-AT, LibKa0s#92) ─────────────────
--
-- A HUD display's drag strip is its title bar, so its tooltip, and its marks', is a CHROME tooltip
-- (WowAddonStandards standalone-windows, *Tooltip placement*, the chrome rule, v2.113.0): attached
-- to the strip, centered on it, 2 px (TIP_GAP) ABOVE it, flipped below only when the screen has no
-- room above, slid sideways only as far as it must, never at the cursor and never at a corner
-- offset. The library places it: no strip hands the widget a `tooltipPlace` hook, so the widget's
-- own placement runs, LibKa0s-Tooltip-1.0's PlaceAttached on the strip (WidgetsDragHandleTip
-- minor 1), one absolute point on UIParent's BOTTOMLEFT in screen units.
--
-- RE-PINNED by AD-92-AT. Until then every strip handed the widget NS.Util.PlaceTooltipBeside
-- (TP-AT-02, LibKa0s v1.68.0), which opened the tooltip BESIDE the single strip, right or left;
-- the rule now reads that as a body placement on a chrome element. The six PlaceTooltipBeside cases
-- (right when it fits, left near the right edge, a mark resolving to its strip, screen pixels, a
-- secret read, a nil read) and the two hover cases became the cases below, one for one: above
-- mid-screen, below at the top, clamped at the right edge, every mark placed by its strip, screen
-- units on a scaled strip, a secret read and a nil read falling back to the widget's attached point.

-- One hover of `frame` (the strip or one of its marks) on the screen `g` describes.
local function hoverAt(strip, frame, g)
  withScreen(strip, g, function() frame:__fire("OnEnter") end)
  frame:__fire("OnLeave")
  return g
end

-- Assert `g` landed one point: `point` on UIParent's BOTTOMLEFT at x, y (screen units, scale 1).
local function assertPinned(g, point, x, y, what)
  assertEqual(#g.points, 1, what .. ": one point")
  local p, rel, relPoint, px, py = unpack(g.points[1])
  assertEqual(p, point, what)
  assertTrue(rawequal(rel, T.mocks.UIParent), what .. ": an absolute point on UIParent")
  assertEqual(relPoint, "BOTTOMLEFT", what)
  assertEqual(px, x, what .. ": x")
  assertEqual(py, y, what .. ": y")
end

test("no strip hands the widget a tooltipPlace hook: the library places every strip tooltip", function()
  -- red under: the retired spec, whose tooltipPlace was NS.Util.PlaceTooltipBeside (TP-AT-02).
  for _, unit in ipairs(NS.Units.LIST) do
    assertNil(specFor(unit).tooltipPlace, unit .. " strip still places its own tooltips")
  end
end)

test("the addon's own beside-the-strip placer is retired", function()
  -- red under: NS.Util.PlaceTooltipBeside still defined in modules/Bar.lua.
  assertNil(NS.Util.PlaceTooltipBeside, "a second placer beside LibKa0s-Tooltip-1.0's")
end)

test("hovering a strip, its ?, its X or its settings mark attaches the tooltip centered above the strip", function()
  -- red under: the retired hook, which anchored TOPLEFT on the strip's TOPRIGHT (beside it).
  -- The strip spans 400..600 and tops out at 516: centered at 500, its BOTTOM 2 px over the top.
  for _, unit in ipairs(NS.Units.LIST) do
    local strip = NS.bars[unit].handle
    for _, frame in ipairs({ strip, strip.help, strip.close, strip.settings }) do
      local g = hoverAt(strip, frame, midScreen())
      assertEqual(#g.owners, 1, unit .. ": owned once")
      assertTrue(rawequal(g.owners[1][1], T.mocks.UIParent), "owned by UIParent (a restricted tree)")
      assertEqual(g.owners[1][2], "ANCHOR_NONE", "never ANCHOR_CURSOR or a corner anchor")
      assertPinned(g, "BOTTOM", 500, 518, unit .. ": above the strip, whichever part was hovered")
    end
  end
end)

test("a mark's tooltip is centered on its STRIP, not on the mark", function()
  -- Re-pins "PlaceTooltipBeside anchors to the STRIP when the hovered frame is its ? mark or its
  -- X": one position for the strip and every mark, not four. Each mark gets its own geometry at
  -- the strip's right end (580..596); a placement by the mark would center at 588.
  local strip = NS.bars.target.handle
  for _, key in ipairs({ "help", "close", "settings" }) do
    local mark = strip[key]
    local g
    withRaw({
      { mark, "GetLeft", answer(580) }, { mark, "GetRight", answer(596) },
      { mark, "GetBottom", answer(500) }, { mark, "GetTop", answer(516) },
      { mark, "GetEffectiveScale", answer(1) },
    }, function() g = hoverAt(strip, mark, midScreen()) end)
    assertPinned(g, "BOTTOM", 500, 518, "the " .. key .. " mark places by its strip")
  end
end)

test("a strip at the screen's top opens its tooltip below it", function()
  -- No room above (796 + 2 + 80 passes 800), room below: TOP 2 px under the strip's bottom.
  local strip = NS.bars.player.handle
  local g = hoverAt(strip, strip, { left = 400, bottom = 780, width = 200, height = 16 })
  assertPinned(g, "TOP", 500, 778, "flipped below")
end)

test("a strip near the screen's right edge keeps its tooltip on screen, slid only as far as it must", function()
  -- The strip spans 900..1000; centered at 950 a 200 wide tooltip would run to 1050, so it slides
  -- left until its right edge is the screen's: center 900. Still above, never beside.
  local strip = NS.bars.target.handle
  local g = hoverAt(strip, strip, { left = 900, bottom = 500, width = 100, height = 16 })
  assertPinned(g, "BOTTOM", 900, 518, "clamped sideways")
end)

test("a scaled strip is measured in screen units", function()
  -- red under: a placement on raw edges. At an effective scale of 2 (a bar scale times the master
  -- scale) a strip at 200..300 x 250..258 in its own units is 400..600 x 500..516 on screen.
  local strip = NS.bars.focus.handle
  local g = hoverAt(strip, strip, { left = 200, bottom = 250, width = 100, height = 8, scale = 2 })
  assertPinned(g, "BOTTOM", 500, 518, "the same place as the unscaled mid-screen strip")
end)

test("a strip whose top is a secret value falls back to the widget's attached point, never the cursor", function()
  -- LibKa0s-Tooltip-1.0 asks issecretvalue (read bare at call time) before any arithmetic, and
  -- places nothing on a secret read; the widget then writes its relative point above the strip.
  local SECRET_TOP = 516.25
  local saved = rawget(_G, "issecretvalue")
  rawset(_G, "issecretvalue", function(v) return v == SECRET_TOP end)
  local strip = NS.bars.player.handle
  local g = midScreen()
  g.top = SECRET_TOP
  local ok, err = pcall(hoverAt, strip, strip, g)
  rawset(_G, "issecretvalue", saved)
  if not ok then error(err) end
  assertEqual(#g.owners, 1, "owned once: no second owner at the cursor")
  assertEqual(g.owners[1][2], "ANCHOR_NONE")
  assertEqual(#g.points, 1, "one point, the widget's attached fallback")
  local point, rel, relPoint, x, y = unpack(g.points[1])
  assertEqual(point, "BOTTOM")
  assertTrue(rawequal(rel, strip), "attached to the strip")
  assertEqual(relPoint, "TOP")
  assertEqual(x, 0)
  assertEqual(y, 2)
end)

test("a strip whose geometry cannot be read falls back to the widget's attached tooltip, never the cursor", function()
  -- The widget's own fallback since LibKa0s v1.105.0 (WidgetsDragHandleTip minor 1, LibKa0s#92,
  -- anti-pattern #119): owned once by UIParent at ANCHOR_NONE, then attached above the strip
  -- (smoke round 1's SR-L1: above, since the pointer hangs down and never covers that side).
  -- With the strip's edges unreadable (nil: not yet laid out) the Tooltip major places nothing,
  -- so the widget writes its relative point, BOTTOM on the strip's TOP 2 px up. Until v1.104.0 it
  -- re-owned at the cursor.
  local strip = NS.bars.target.handle
  local g = { width = 200, height = 16 }
  withScreen(strip, g, function() strip:__fire("OnEnter") end)
  strip:__fire("OnLeave")
  assertEqual(#g.owners, 1, "owned once: no second owner at the cursor")
  assertTrue(rawequal(g.owners[1][1], T.mocks.UIParent), "owned by UIParent")
  assertEqual(g.owners[1][2], "ANCHOR_NONE")
  assertEqual(#g.points, 1, "one point, the widget's attached fallback")
  local point, rel, relPoint, x, y = unpack(g.points[1])
  assertEqual(point, "BOTTOM")
  assertTrue(rawequal(rel, strip), "attached to the strip, not beside it")
  assertEqual(relPoint, "TOP")
  assertEqual(x, 0)
  assertEqual(y, 2)
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

test("degraded: NS.Widgets is the stub, whose DragHandle draws nothing and whose strip takes no room", function()
  -- The setup seam's contract, read off a real partial load: core/WidgetsSetup.lua publishes a
  -- stub when the major is absent, its DragHandle answers nil (so NS.CreateBar draws no strip) and
  -- its DRAG_HANDLE sizes add to zero (so modules/Display.lua's HANDLE_ROOM is 0).
  -- red under: NS.Widgets unpublished on the degraded path, or a stub whose sizes leave room.
  local NS2 = loadDegraded()
  assertTrue(type(NS2.Widgets) == "table", "core/WidgetsSetup.lua publishes NS.Widgets degraded")
  assertNil(NS2.Widgets.DragHandle(NS2.bars.player, {}), "the stub's DragHandle builds nothing")
  local D = NS2.Widgets.DRAG_HANDLE
  assertEqual(D.HEIGHT + D.GAP, 0, "the stub reserves no strip room")
  for _, unit in ipairs(NS2.Units.LIST) do
    assertNil(NS2.bars[unit].handle, unit .. " drew a strip through the stub")
  end
  local _, _, _, ty = NS2.DefaultPosition("target")
  assertEqual(ty, NS2.Units.Get("player", "barHeight") + 8, "HANDLE_ROOM is 0: bar height + 8px gap")
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
