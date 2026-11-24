local T = _G.AT_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- FB2-AT-01 (Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH, decision D2): every start of an
-- `/at sim` session shows the step window. The owner's words: "sim mode whether started from a
-- command like /xx sim start <scenario> or from just plain /xx sim should always show the sim stepper
-- window". The rule is LibKa0s-Sim-1.0's (minor 5: the session's own Start shows the panel), so the
-- addon's prepare no longer opens it; each case below is one start path, run with the window closed.

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
  NS.Sim:HidePanel()
  assertFalse(NS.Sim:IsPanelShown(), "every case starts with the window closed")
end

--- The step window's frame, once a show has built it.
local function panelFrame()
  for _, f in ipairs(M.__shownFrames()) do
    if f.__name == NS.SimHost.PANEL_NAME then return f end
  end
  return nil
end

test("sim start panel: the window comes from the library's start, not the addon's prepare", function()
  -- red under: Host.Prepare calling NS.Sim:ShowPanel itself (an addon-owned show the library now owns).
  reset()
  local shows = 0
  local real = NS.Sim.ShowPanel
  NS.Sim.ShowPanel = function(...) shows = shows + 1 return real(...) end
  local realHold = NS.HoldPreview
  NS.HoldPreview = function() end
  local ready = false
  local ok, err = pcall(NS.SimHost.Prepare, nil, nil, nil, function() ready = true end)
  NS.HoldPreview = realHold
  NS.ShowSimStrips(false)
  NS.Sim.ShowPanel = real
  if not ok then error(err, 0) end
  assertTrue(ready, "prepare handed the session ready")
  assertEqual(shows, 0, "prepare opened no window of its own")
  reset()
end)

test("sim start panel: bare /at sim shows the window and starts nothing", function()
  reset()
  slash("sim")
  assertTrue(NS.Sim:IsPanelShown())
  assertFalse(NS.Sim:IsActive())
  reset()
end)

test("sim start panel: /at sim start <scenario> shows the window", function()
  -- red under: LibKa0s before v1.113.0 with no prepare-time show (the owner's /lh sim start loot).
  for _, name in ipairs(NS.SimHost.SCENARIOS.names) do
    reset()
    slash("sim start " .. name)
    assertTrue(NS.Sim:IsActive(), name .. " started")
    assertTrue(NS.Sim:IsPanelShown(), name .. ": the step window opened")
  end
  reset()
end)

test("sim start panel: the window's picker Start and its Restart show the window", function()
  reset()
  slash("sim")
  local f = panelFrame()
  assertTrue(f ~= nil and f.picker ~= nil and f.picker.start ~= nil, "the picker's Start button")
  NS.Sim:HidePanel()
  f.picker.start:__fire("OnClick")
  assertTrue(NS.Sim:IsActive(), "the picker's Start started a session")
  assertTrue(NS.Sim:IsPanelShown(), "and the window shows")
  NS.Sim:HidePanel()
  assertTrue(f.controls ~= nil and f.controls.restart ~= nil, "the Restart control")
  f.controls.restart:__fire("OnClick")
  assertTrue(NS.Sim:IsActive(), "Restart started the session again")
  assertTrue(NS.Sim:IsPanelShown(), "and showed the window")
  reset()
end)

test("sim start panel: the Master controls box and the launcher row show the window", function()
  reset()
  NS.SetByPath("state.sim", true)
  assertTrue(NS.Sim:IsPanelShown(), "the box's tick opened it")
  reset()
  NS.ToggleSimMode()
  assertTrue(NS.Sim:IsPanelShown(), "the launcher's Sim mode row opened it")
  reset()
end)

test("sim start panel: a host start through the session shows the window", function()
  reset()
  assertTrue(NS.Sim:Start({ scenario = "drain" }))
  assertTrue(NS.Sim:IsPanelShown(), "sim:Start, the choke point every path goes through")
  reset()
end)
