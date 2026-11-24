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

-- FB2-AT-01 (decision D3): the one menu here that marks a selected entry is the step window's
-- scenario picker, LibKa0s-Widgets-1.0's Dropdown (SimPanel builds it with the addon as owner). The
-- addon's own settings dropdowns are AceGUI's (the schema rows' and the Unit picker), which mark
-- their pick with a check and whose colors the library's AceGUI skinning paints; Absorb Tracker
-- builds and paints no menu row of its own. Since WidgetsDropdown minor 4 a selected row stands off
-- a plain row. FB2-AT-02 (the owner's ruling, 2026-11-24): a selected row is Ka0s Default's gold in
-- every skin, the skin's own menu.textSel standing in only where the gold sits too near that skin's
-- menu text. This pins the picker to it under Ka0s Default, Azeroth and WoW Forever (the default
-- skin on Forever, whose tan accent a selected row wore before the ruling).
local function rgb(r, g, b) return ("%.3f,%.3f,%.3f"):format(r, g, b) end

--- Open `dd`'s menu and answer each row's painted label color, by row index.
local function rowColors(dd)
  local seen = {}
  local menu
  dd:__fire("OnClick")
  for _, f in ipairs(M.__shownFrames()) do
    if rawget(f, "__dd") == dd and type(rawget(f, "buttons")) == "table" then menu = f end
  end
  assertTrue(menu ~= nil, "the picker's menu opened")
  for i, row in ipairs(menu.buttons) do
    local fs = row.fs
    local real = fs.SetTextColor
    fs.SetTextColor = function(self, r, g, b, ...)
      seen[i] = rgb(r, g, b)
      if real then return real(self, r, g, b, ...) end
    end
  end
  menu:Populate(dd)
  for _, row in ipairs(menu.buttons) do row.fs.SetTextColor = nil end
  local W = M.LibStub("LibKa0s-Widgets-1.0")
  W.CloseMenu()
  -- The mock's Hide fires no script; the client's OnHide is what drops the outside-press watch.
  menu:__fire("OnHide")
  return seen
end

test("sim start panel: the scenario picker's selected row stands off the plain rows", function()
  -- red under: WidgetsDropdown minor 3, where Azeroth's selected row wore its accent, 16.3 dE00 off
  -- its plain rows; and under the first cut of v1.113.0, where WoW Forever's wore its tan accent.
  reset()
  local W = M.LibStub("LibKa0s-Widgets-1.0")
  assertTrue(type(W.SelectedColor) == "function", "WidgetsDropdown minor 4's SelectedColor")
  slash("sim")
  local f = panelFrame()
  local dd = f and f.picker and f.picker.scenario
  assertTrue(dd ~= nil, "the step window's scenario picker")
  local before = NS.GetSetting("skin.skin")
  local gold = rgb(1, 0.82, 0)
  for _, key in ipairs({ "ka0s", "azeroth", "forever" }) do
    assertTrue(NS.SetByPath("skin.skin", key), "skin " .. key)
    dd:SelectValue("drain")
    local colors = rowColors(dd)
    local selIndex
    for i, name in ipairs(NS.SimHost.SCENARIOS.names) do if name == "drain" then selIndex = i end end
    assertTrue(colors[selIndex] ~= nil, key .. ": the selected row painted")
    assertEqual(colors[selIndex], rgb(W.SelectedColor("AbsorbTracker")), key .. ": the selected row wears SelectedColor")
    assertEqual(colors[selIndex], gold, key .. ": the selected row is Ka0s Default's gold")
    for i, c in pairs(colors) do
      if i ~= selIndex then
        assertTrue(c ~= colors[selIndex], key .. ": plain row " .. i .. " differs from the selected one")
      end
    end
  end
  NS.SetByPath("skin.skin", before)
  reset()
end)
