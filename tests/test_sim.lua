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

-- What the tick does is what `/at sim` does, because it IS NS.ToggleSim: from off (no window, no
-- session) the bare verb, which opens the step window idle (SIM-1: nothing plays until a scenario
-- starts). R7-SIM (Ka0sAddonsCommonTasks docs/2026-11-04-SMOKE_ROUND7, call 2, the owner's "checked
-- while the sim window is open and/or a sim is running"): the box reads NS.IsSimMode, which is the
-- window shown OR a session running, so the tick stays ticked; the untick, from either, stops a
-- running sim and closes the window.
-- red under: a row with no hooks, a row that stores its value, a second implementation of the act,
-- or an isSimMode that asks the session alone.
test("sim box: ticking does what /at sim does and stays ticked, unticking stops and closes", function()
  reset()
  NS.Sim:HidePanel()
  assertEqual(NS.GetSetting("state.sim"), false, "unticked with no window and no sim")
  NS.SetByPath("state.sim", true)
  assertTrue(NS.Sim:IsPanelShown(), "the tick opened the step window, as the bare verb does")
  assertFalse(NS.Sim:IsActive(), "and, like the verb, started nothing by itself")
  assertEqual(NS.GetSetting("state.sim"), true, "so the box stays ticked while the window is open")
  slash("sim start fight")
  assertEqual(NS.GetSetting("state.sim"), true, "ticked while a sim runs")
  NS.SetByPath("state.sim", true)
  assertTrue(NS.Sim:IsActive(), "a tick while it runs does not toggle it off")
  NS.SetByPath("state.sim", false)
  assertFalse(NS.Sim:IsActive(), "the untick stopped it")
  assertFalse(NS.Sim:IsPanelShown(), "and closed the window")
  assertEqual(NS.testHoldUntil, nil, "and cleared the hold")
  assertEqual(NS.GetSetting("state.sim"), false)
  NS.SetByPath("state.sim", false)
  assertFalse(NS.Sim:IsActive(), "an untick while off starts nothing")
  assertFalse(NS.Sim:IsPanelShown(), "and opens nothing")
  assertEqual(NS.db.profile.state, nil, "never reaches db.profile")
  reset()
end)

-- R7-SIM: the four states of the owner's rule, read through the box's own row and the launcher's pair.
-- red under: NS.IsSimMode asking only whether a session runs.
test("sim box: the window open and idle reads ticked, closing it reads unticked", function()
  reset()
  NS.Sim:HidePanel()
  slash("sim")
  assertTrue(NS.Sim:IsPanelShown(), "bare /at sim opened the window")
  assertFalse(NS.Sim:IsActive(), "idle")
  assertEqual(NS.GetSetting("state.sim"), true, "the box is ticked with the window open")
  assertTrue(NS.IsSimMode(), "and so is the launcher's entry")
  NS.Sim:HidePanel()
  assertEqual(NS.GetSetting("state.sim"), false, "closing the window unticks it")
  assertFalse(NS.IsSimMode())
  reset()
end)

-- red under: NS.IsSimMode asking only whether the window is shown.
test("sim box: a sim running with its window hidden reads ticked", function()
  reset()
  slash("sim start fight")
  NS.Sim:HidePanel()
  assertTrue(NS.Sim:IsActive(), "the run outlives its window")
  assertEqual(NS.GetSetting("state.sim"), true, "the box stays ticked")
  assertTrue(NS.IsSimMode())
  NS.ToggleSimMode()
  assertFalse(NS.Sim:IsActive(), "one click stops it")
  assertFalse(NS.Sim:IsPanelShown(), "and leaves the window closed")
  assertFalse(NS.IsSimMode())
  reset()
end)

-- red under: unticking a window-open, idle box doing nothing (the verb's stop has no session to end).
test("sim box: the untick with the window open and idle closes it", function()
  reset()
  slash("sim")
  NS.SetByPath("state.sim", false)
  assertFalse(NS.Sim:IsPanelShown(), "the window closed")
  assertFalse(NS.Sim:IsActive(), "nothing started")
  assertEqual(NS.GetSetting("state.sim"), false)
  reset()
end)

-- The step window's own show and hide refresh an open page (its close button and Escape hide the frame
-- directly, never through HidePanel, and the session's listener does not fire for a window alone).
-- The mock's Show and Hide fire no scripts, so the case fires them as the client would.
-- red under: no OnShow / OnHide hook on the step window.
test("sim box: the step window's show and hide refresh the open page", function()
  reset()
  NS.Sim:HidePanel()
  local name = NS.SimHost.PANEL_NAME
  assertEqual(name, "AbsorbTrackerSimPanel", "the frame the library names")
  local calls = 0
  local real = NS.Helpers.RefreshScalars
  NS.Helpers.RefreshScalars = function(...) calls = calls + 1 return real(...) end
  slash("sim")
  local frame
  for _, f in ipairs(T.mocks.__shownFrames()) do if f.__name == name then frame = f end end
  assertTrue(frame ~= nil, "the step window is a shown frame")
  local hadGlobal = rawget(_G, name)
  rawset(_G, name, frame)
  slash("sim panel")
  slash("sim panel")
  local before = calls
  frame:__fire("OnShow")
  assertTrue(calls > before, "the window's OnShow refreshed the page")
  before = calls
  frame:Hide()
  frame:__fire("OnHide")
  assertTrue(calls > before, "the window's OnHide refreshed the page")
  assertEqual(NS.GetSetting("state.sim"), false, "and the box reads unticked")
  NS.Helpers.RefreshScalars = real
  rawset(_G, name, hadGlobal)
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
