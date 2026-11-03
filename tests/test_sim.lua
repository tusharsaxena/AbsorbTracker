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

test("sim: the step delay setting paces every step (SG-AT-1)", function()
  -- red under: DelayAfter answered the scripted wait whatever the slider said.
  local steps = NS.SimHost.SCENARIOS.defs.fight.timeline(nil, { scenario = "fight" })
  assertEqual(NS.GetSetting("sim.stepDelay"), 1, "the default")
  assertEqual(NS.SimHost.DelayAfter(steps[1]), 1)
  assertTrue(NS.SetByPath("sim.stepDelay", 4))
  assertEqual(NS.SimHost.DelayAfter(steps[1]), 4)
  assertEqual(NS.SimHost.DelayAfter(steps[#steps]), 4)
  assertFalse(NS.SetByPath("sim.stepDelay", 0.3), "a pace the slider cannot make is refused")
  NS.SetByPath("sim.stepDelay", 1)
end)

test("sim: with no valid setting a step's wait is the gap to the next, the last waits the default", function()
  local steps = NS.SimHost.SCENARIOS.defs.fight.timeline(nil, { scenario = "fight" })
  local was = NS.db.profile.sim.stepDelay
  NS.db.profile.sim.stepDelay = 0.3
  assertEqual(NS.SimHost.DelayAfter(steps[1]), 1.5)
  assertEqual(NS.SimHost.DelayAfter(steps[5]), 1)   -- 6 -> 7
  assertEqual(NS.SimHost.DelayAfter(steps[#steps]), NS.SimHost.DEFAULT_WAIT)
  NS.db.profile.sim.stepDelay = was
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

-- R6-SIM (Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND6, the owner's "a sim checkbox in settings
-- (next to test)"): Master controls carries the library's Sim mode box (OptionsCompose minor 19), fed
-- the SAME isSimMode / toggleSim pair the launcher descriptor carries, so the box, the launcher's Sim
-- mode entry and `/at sim` are one act. This addon has no Test mode row (the lock is its preview), so
-- the box sits beside Lock frame.

local function slashSource(path)
  local f = assert(io.open(path, "r"))
  local src = f:read("*a")
  f:close()
  return src
end

-- red under: no sim hooks on the MasterControls spec (the library then draws no row).
test("sim box: Master controls draws a session-only Sim mode row beside Lock frame", function()
  local row = NS.FindSchemaRow("state.sim")
  assertTrue(row ~= nil, "a state.sim row")
  assertEqual(row.label, "Sim mode")
  assertEqual(row.group, "Master controls")
  assertEqual(row.sessionOnly, true, "nothing is stored")
  assertEqual(row.default, false)
  local master = {}
  for _, r in ipairs(NS.SchemaForPage("general")) do
    if r.group == "Master controls" then master[#master + 1] = r.path end
  end
  local lockAt
  for i, path in ipairs(master) do if path == "locked" then lockAt = i end end
  assertEqual(master[lockAt + 1], "state.sim", "straight after Lock frame, in its second column")
end)

-- red under: the launcher and the box built their own pairs (launcher-§1's one act).
test("sim box: the box and the launcher take the one NS pair", function()
  for _, path in ipairs({ "core/LauncherSetup.lua", "settings/General.lua" }) do
    local src = slashSource(path)
    assertTrue(src:find("isSimMode%s*=%s*NS%.IsSimMode[%s,]") ~= nil, path .. " passes NS.IsSimMode")
    assertTrue(src:find("toggleSim%s*=%s*NS%.ToggleSimMode[%s,]") ~= nil, path .. " passes NS.ToggleSimMode")
  end
  assertEqual(type(NS.IsSimMode), "function")
  assertEqual(type(NS.ToggleSimMode), "function")
end)

-- What the tick does is what `/at sim` does, because it IS NS.ToggleSim: from idle the bare verb
-- (status, usage, and the step window opened idle, SIM-1: nothing plays until a scenario starts), and
-- while a sim runs `/at sim stop`. So a tick from idle opens the window and the box re-reads unticked
-- until the player starts a scenario there; it then reads ticked, and the untick stops the session.
-- red under: a row with no hooks, a row that stores its value, or a second implementation of the act.
test("sim box: ticking does what /at sim does, unticking stops the sim", function()
  reset()
  NS.Sim:HidePanel()
  assertEqual(NS.GetSetting("state.sim"), false, "unticked while idle")
  NS.SetByPath("state.sim", true)
  assertTrue(NS.Sim:IsPanelShown(), "the tick opened the step window, as the bare verb does")
  assertFalse(NS.Sim:IsActive(), "and, like the verb, started nothing by itself")
  assertEqual(NS.GetSetting("state.sim"), false, "so the box re-reads unticked")
  slash("sim start fight")
  assertEqual(NS.GetSetting("state.sim"), true, "ticked while a sim runs")
  NS.SetByPath("state.sim", true)
  assertTrue(NS.Sim:IsActive(), "a tick while it runs does not toggle it off")
  NS.SetByPath("state.sim", false)
  assertFalse(NS.Sim:IsActive(), "the untick stopped it")
  assertEqual(NS.testHoldUntil, nil, "and cleared the hold")
  assertEqual(NS.GetSetting("state.sim"), false)
  NS.SetByPath("state.sim", false)
  assertFalse(NS.Sim:IsActive(), "an untick while idle starts nothing")
  assertEqual(NS.db.profile.state, nil, "never reaches db.profile")
  NS.Sim:HidePanel()
  reset()
end)

-- red under: the row's write falling through to the schema's announce (a three-bar restyle).
test("sim box: the row's write publishes no appearance pass", function()
  assertEqual(type(NS.MasterReactions["state.sim"]), "function", "a declared reaction")
  reset()
  local sent = {}
  local real = NS.bus.SendMessage
  NS.bus.SendMessage = function(self, msg, ...) sent[msg] = true return real(self, msg, ...) end
  NS.MasterReactions["state.sim"](true)
  NS.bus.SendMessage = real
  assertEqual(sent[NS.MSG.APPEARANCE], nil)
end)

-- red under: no listener on the session, so a sim started elsewhere leaves an open box stale.
test("sim box: a sim started or stopped elsewhere refreshes the open page", function()
  reset()
  local calls = 0
  local real = NS.Helpers.RefreshScalars
  NS.Helpers.RefreshScalars = function(...) calls = calls + 1 return real(...) end
  slash("sim start fight")
  local onStart = calls
  slash("sim stop")
  NS.Helpers.RefreshScalars = real
  assertTrue(onStart > 0, "the start refreshed the page")
  assertTrue(calls > onStart, "the stop refreshed it again")
  reset()
end)

-- red under: Reset all settings leaving the row out of its session walk.
test("sim box: Reset all settings stops a running sim and never starts one", function()
  reset()
  NS.Helpers.RestoreAllDefaults()
  T.mocks.__fireTimers()
  assertFalse(NS.Sim:IsActive(), "a reset from idle starts nothing")
  slash("sim start fight")
  NS.Helpers.RestoreAllDefaults()
  assertFalse(NS.Sim:IsActive(), "the reset stopped the sim")
  reset()
end)
