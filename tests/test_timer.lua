local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual = T.test, T.assertEqual

-- ── Coalescing repaint scheduler (modules/Timer.lua) ──────────────────────────────
test("RequestRepaint coalesces multiple requests into one scheduled repaint", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local calls = 0
  local orig = NS.UpdateAbsorbBar
  NS.UpdateAbsorbBar = function() calls = calls + 1 end

  NS.RequestRepaint(); NS.RequestRepaint(); NS.RequestRepaint()
  assertEqual(#mocks.__timers, 1)          -- three requests, one timer
  mocks.__fireTimers()
  assertEqual(calls, 1)                     -- fires exactly one repaint
  NS.RequestRepaint()
  assertEqual(#mocks.__timers, 1)           -- re-arms after firing
  mocks.__fireTimers()                      -- drain so `pending` resets for later tests

  NS.UpdateAbsorbBar = orig
end)

test("RequestRepaint schedules the timer at the throttleWindow delay", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.RequestRepaint()
  assertEqual(mocks.__timers[1].delay, NS.GetSetting("throttleWindow"))
  mocks.__fireTimers()
end)

-- ── Event wiring (core/AbsorbTracker.lua) ─────────────────────────────────────────
test("OnAbsorbChanged requests a repaint for the player", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnAbsorbChanged(nil, "player")
  assertEqual(#mocks.__timers, 1)
  mocks.__fireTimers()
end)

test("OnAbsorbChanged ignores non-player units", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnAbsorbChanged(nil, "target")
  assertEqual(#mocks.__timers, 0)
end)

test("OnMaxHealthChanged requests a repaint for the player", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnMaxHealthChanged(nil, "player")
  assertEqual(#mocks.__timers, 1)
  mocks.__fireTimers()
end)

test("OnMaxHealthChanged ignores non-player units", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnMaxHealthChanged(nil, "party1")
  assertEqual(#mocks.__timers, 0)
end)
