local T = _G.AT_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- `/at sim` (SG-AT-1): LibKa0s-Sim-1.0's session and step window over a made-up shield fight painted on
-- the bars, like MultiMeters' and KickCD's. The session holds the bars, stores nothing, honors each
-- step's wait, and leaves no hold or timer behind when it ends.

local function slash(line)
  local out = {}
  local cf = M.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(NS.Slash.OnSlash, NS.Slash, line)
  cf.AddMessage = old
  if not ok then error(err, 0) end
  return table.concat(out, "\n")
end

local function drain()
  for _ = 1, 60 do
    M.__now = M.__now + 3
    if M.__fireTimers() == 0 then return end
  end
end

-- The mock fires every queued timer whatever its delay, which would run the session's 6 h hold expiry on
-- the first drain; a start that drops that one timer lets the steps play out.
local function start(scenario)
  local addon = NS.addon
  local real = addon.ScheduleTimer
  addon.ScheduleTimer = function(self, fn, delay, ...)
    if delay and delay >= 3600 then return {} end
    return real(self, fn, delay, ...)
  end
  slash("sim start " .. scenario)
  addon.ScheduleTimer = real
end

local function reset()
  if NS.Sim:IsActive() then NS.Sim:Stop("stop") end
  NS.ClearPreview()
  drain()
end

test("sim: COMMANDS carries a sim row", function()
  local found
  for _, e in ipairs(NS.COMMANDS) do if e[1] == "sim" then found = e end end
  assertTrue(found ~= nil, "a sim verb")
end)

test("sim: the library session is bound and the seam wraps nothing", function()
  assertTrue(NS.Sim ~= nil and NS.Sim.RunVerb ~= nil, "a session")
  assertEqual(#NS.SimSeam:Unwrapped(), 0, "nothing escaped the seam")
end)

test("sim: three scenarios, each a list of shield steps with a wait", function()
  local sc = NS.SimHost.SCENARIOS
  assertEqual(#sc.names, 3)
  for _, name in ipairs(sc.names) do
    local steps = sc.defs[name].timeline(sc.defs[name], { scenario = name })
    assertTrue(#steps >= 5, name)
    for _, s in ipairs(steps) do
      assertEqual(s.kind, "shield")
      assertTrue(type(s.value) == "number" and type(s.wait) == "number", name)
    end
  end
end)

test("sim: a step's wait is the gap to the next, the last waits the default", function()
  local steps = NS.SimHost.SCENARIOS.defs.fight.timeline(nil, { scenario = "fight" })
  assertEqual(NS.SimHost.DelayAfter(steps[1]), 1.5)
  assertEqual(NS.SimHost.DelayAfter(steps[5]), 1)   -- 6 -> 7
  assertEqual(NS.SimHost.DelayAfter(steps[#steps]), NS.SimHost.DEFAULT_WAIT)
end)

test("sim: a bad word prints the usage and holds nothing", function()
  reset()
  slash("sim wibble")
  assertEqual(NS.testHoldUntil, nil, "no hold")
  assertFalse(NS.Sim:IsActive())
end)

test("sim: stop with nothing running says so", function()
  reset()
  assertTrue(slash("sim stop") ~= "", "it said something")
end)

test("sim: a start holds the bars, opens the stepper and plays the steps", function()
  reset()
  start("fight")
  assertTrue(NS.Sim:IsActive(), "active")
  assertTrue(NS.testHoldUntil ~= nil, "the bars are held")
  drain()
  local steps = NS.Sim:Steps()
  assertTrue(#steps > 0 and steps[#steps].ranAt ~= nil, "the run reached the last step")
  reset()
end)

test("sim: the held shield is what the last step painted", function()
  reset()
  local painted = {}
  local real = NS.PaintHold
  NS.PaintHold = function(n) painted[#painted + 1] = n return real(n) end
  start("drain")
  drain()
  NS.PaintHold = real
  assertEqual(painted[1], 120000)
  assertEqual(painted[#painted], 20000)
  reset()
end)

test("sim: a manual step paints one value and holds the run", function()
  reset()
  slash("sim start fight")
  slash("sim step")
  assertEqual(NS.Sim:Status().active, true)
  reset()
end)

test("sim: stop ends the session and clears the hold", function()
  reset()
  slash("sim start fight")
  slash("sim stop")
  assertFalse(NS.Sim:IsActive())
  assertEqual(NS.testHoldUntil, nil, "hold cleared")
  assertTrue(slash("sim stop") ~= "", "and nothing is left running")
end)

test("sim: clearing the preview mid-sim (a lock toggle, a stand-down) ends the session", function()
  reset()
  slash("sim start fight")
  NS.ClearPreview()
  assertFalse(NS.Sim:IsActive(), "the session ended with the hold")
  local painted = 0
  local real = NS.PaintHold
  NS.PaintHold = function(...) painted = painted + 1 return real(...) end
  drain()
  NS.PaintHold = real
  assertEqual(painted, 0, "no step paints after the hold was cleared")
end)

test("sim: a debug hold mid-sim replaces the sim", function()
  reset()
  slash("sim start fight")
  slash("debug hold 5000 3")
  assertFalse(NS.Sim:IsActive(), "the hold ended the session")
  NS.ClearPreview()
end)

test("sim: stop with the bars unlocked gives them their placeholder back", function()
  reset()
  slash("sim start fight")
  local placeholders = 0
  local real, inPreview = NS.PaintPlaceholder, NS.InPreview
  NS.PaintPlaceholder = function(...) placeholders = placeholders + 1 return real(...) end
  NS.InPreview = function() return true end
  slash("sim stop")
  NS.InPreview, NS.PaintPlaceholder = inPreview, real
  assertTrue(placeholders > 0, "the placeholder is painted before the repaint")
end)

test("sim: a disabled addon refuses and holds nothing", function()
  reset()
  NS.SetByPath("enabled", false)
  local ok, out = pcall(slash, "sim start fight")
  NS.SetByPath("enabled", true)
  drain()
  assertTrue(ok, tostring(out))
  assertFalse(NS.Sim:IsActive())
  assertEqual(NS.testHoldUntil, nil, "no hold")
end)

test("sim: the launcher's mode row follows the session", function()
  reset()
  assertFalse(NS.IsSimRunning())
  slash("sim start fight")
  assertTrue(NS.IsSimRunning())
  NS.ToggleSim()
  assertFalse(NS.IsSimRunning())
end)
