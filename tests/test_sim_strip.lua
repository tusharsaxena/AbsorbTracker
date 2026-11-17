local T = _G.AT_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local loadDegraded = dofile("tests/degraded_env.lua")

-- AD-88-AT: the simulation's strip on each bar (WowAddonStandards v2.113.0, preview-mode, *Where the
-- strip sits*: "On a HUD display, on its top edge and outside it"; LibKa0s Widgets minor 27's
-- `dock = "hud"`). Each bar is a HUD display the player positions on its own, so each carries its
-- own cyan strip while `/at sim` runs. The library docks it: on the bar's top edge, stacked beyond
-- the drag handle while that shows, flipped under the bar near the screen's top. The host only
-- builds it, shows it, hides it and calls strip:Place() after it moves a bar. The step panel stays.
-- The library's docking itself is tested in LibKa0s; these cases pin what this addon hands it.

local function slash(line)
  local cf = M.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function() end
  local ok, err = pcall(NS.Slash.OnSlash, NS.Slash, line)
  cf.AddMessage = old
  if not ok then error(err, 0) end
end

local function reset()
  if NS.Sim:IsActive() then NS.Sim:Stop("stop") end
  NS.ClearPreview()
  for _ = 1, 60 do
    M.__now = M.__now + 3
    if M.__fireTimers() == 0 then break end
  end
end

-- Rawset `fields` on `frame` while `body` runs, then put back whatever was there.
local function with(frame, fields, body)
  local saved = {}
  for k, v in pairs(fields) do saved[k] = rawget(frame, k); rawset(frame, k, v) end
  local ok, err = pcall(body)
  for k in pairs(fields) do rawset(frame, k, saved[k]) end
  if not ok then error(err, 0) end
end

-- Every SetPoint the strip takes while `body` runs.
local function points(strip, body)
  local got = {}
  with(strip, { SetPoint = function(_, p, rel, relP, x, y)
    got[#got + 1] = { p = p, rel = rel, relP = relP, x = x, y = y }
  end }, body)
  return got
end

local function edges(top, bottom)
  return {
    GetTop = function() return top end,
    GetBottom = function() return bottom end,
    GetEffectiveScale = function() return 1 end,
  }
end

-- red under: no strip built, an amber one, or one the library did not dock (no Place, no IsFlipped).
test("sim strip: every bar carries its own cyan strip, docked by the library, born hidden", function()
  for _, unit in ipairs(NS.Units.LIST) do
    local strip = NS.bars[unit].simStrip
    assertTrue(strip ~= nil, unit .. " has a sim strip")
    assertEqual(strip.kind, "sim", unit .. ": the simulation's cyan")
    assertEqual(type(strip.Place), "function", unit .. ": docked (the library's Place)")
    assertEqual(type(strip.IsFlipped), "function", unit .. ": docked (the library's IsFlipped)")
    assertEqual(strip:BodyOffset(), 0, unit .. ": a HUD strip moves no body")
    assertTrue(strip.text ~= nil and strip.text:GetText() ~= "", unit .. ": it says what it marks")
  end
  reset()
  for _, unit in ipairs(NS.Units.LIST) do
    assertFalse(NS.bars[unit].simStrip:IsShown(), unit .. ": hidden while no sim runs")
  end
end)

-- red under: a hand anchor, or a dock on something other than the bar's top edge.
test("sim strip: it sits on the bar's top edge, outside it, spanning its width", function()
  local bar = NS.bars.player
  local scr = dofile("tests/_kit/mock_screen.lua")(M, { width = 1920, height = 1080 })
  local got
  local handleShown = bar.handle:IsShown()
  bar.handle:Hide()
  local ok, err = pcall(with, bar, edges(520, 500), function()
    got = points(bar.simStrip, function() bar.simStrip:Place() end)
  end)
  if handleShown then bar.handle:Show() end
  scr.restore()
  if not ok then error(err, 0) end
  assertEqual(#got, 2, "two points")
  assertEqual(got[1].p, "BOTTOMLEFT"); assertEqual(got[1].relP, "TOPLEFT")
  assertEqual(got[2].p, "BOTTOMRIGHT"); assertEqual(got[2].relP, "TOPRIGHT")
  assertTrue(got[1].rel == bar and got[2].rel == bar, "anchored to the bar itself")
  assertEqual(got[1].y, 0, "on the edge while no handle shows")
  assertFalse(bar.simStrip:IsFlipped())
end)

-- red under: no `clear`, so an unlocked bar's strip overlaps its drag handle.
test("sim strip: while the drag handle shows, the strip stacks beyond it", function()
  local bar = NS.bars.player
  local scr = dofile("tests/_kit/mock_screen.lua")(M, { width = 1920, height = 1080 })
  local got
  local handleShown = bar.handle:IsShown()
  bar.handle:Show()
  local ok, err = pcall(with, bar, edges(520, 500), function()
    with(bar.handle, edges(542, 522), function()
      got = points(bar.simStrip, function() bar.simStrip:Place() end)
    end)
  end)
  if not handleShown then bar.handle:Hide() end
  scr.restore()
  if not ok then error(err, 0) end
  assertEqual(got[1].p, "BOTTOMLEFT")
  assertEqual(got[1].y, 22, "lifted past the handle's top")
end)

-- red under: no flip (the library's), i.e. a strip not docked with dock = "hud".
test("sim strip: near the screen's top it flips under the bar", function()
  local bar = NS.bars.player
  local scr = dofile("tests/_kit/mock_screen.lua")(M, { width = 1920, height = 1080 })
  local got
  local handleShown = bar.handle:IsShown()
  bar.handle:Hide()
  local ok, err = pcall(with, bar, edges(1078, 1058), function()
    with(bar.simStrip, { GetHeight = function() return 18 end }, function()
      got = points(bar.simStrip, function() bar.simStrip:Place() end)
    end)
  end)
  if handleShown then bar.handle:Show() end
  local flipped = bar.simStrip:IsFlipped()
  bar.simStrip:Place()
  scr.restore()
  if not ok then error(err, 0) end
  assertEqual(got[1].p, "TOPLEFT"); assertEqual(got[1].relP, "BOTTOMLEFT")
  assertTrue(flipped, "IsFlipped answers true")
end)

-- red under: the strip never shown, shown only on one bar, or left up after the stop.
test("sim strip: a sim shows it on every bar and every stop hides it", function()
  reset()
  slash("sim start fight")
  for _, unit in ipairs(NS.Units.LIST) do
    assertTrue(NS.bars[unit].simStrip:IsShown(), unit .. ": shown while the sim runs")
  end
  assertTrue(NS.Sim:IsPanelShown(), "the step panel stays")
  slash("sim stop")
  for _, unit in ipairs(NS.Units.LIST) do
    assertFalse(NS.bars[unit].simStrip:IsShown(), unit .. ": hidden by the stop")
  end
  slash("sim start drain")
  NS.ClearPreview()                       -- a lock toggle or a stand-down ends the session
  for _, unit in ipairs(NS.Units.LIST) do
    assertFalse(NS.bars[unit].simStrip:IsShown(), unit .. ": hidden when the preview clears")
  end
  reset()
end)

-- red under: no strip:Place() after the host moves a bar (a move fires no script).
test("sim strip: moving a bar places its strip again", function()
  reset()
  slash("sim start fight")
  local bar = NS.bars.player
  local calls = 0
  with(bar.simStrip, { Place = function() calls = calls + 1 end }, function()
    NS.RestoreBarPosition("player")
    assertEqual(calls, 1, "a restored position re-places it")
    with(bar, { GetPoint = function() return "CENTER", UIParent, "CENTER", 0, 0 end }, function()
      bar:__fire("OnDragStop")
    end)
    assertEqual(calls, 2, "a drop re-places it")
    NS.UpdateBarAppearance("player")
    assertEqual(calls, 3, "an appearance pass (the Master scale) re-places it")
  end)
  reset()
  calls = 0
  with(bar.simStrip, { Place = function() calls = calls + 1 end }, function()
    NS.RestoreBarPosition("player")
  end)
  assertEqual(calls, 0, "a hidden strip is not placed (it places itself on show)")
end)

-- red under: a degraded build that raises, or one that fakes a strip.
test("sim strip: a build with no LibKa0s draws no strip and the sim still answers", function()
  local NS2 = loadDegraded()
  for _, unit in ipairs(NS2.Units.LIST) do
    assertNil(NS2.bars[unit].simStrip, unit .. ": no strip without the library")
  end
  NS2.ShowSimStrips(true)
  NS2.ShowSimStrips(false)
end)
