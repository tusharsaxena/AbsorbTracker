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

-- Task 4 (multi-unit bars): the per-unit filter that used to live in this handler is gone. The
-- RegisterUnitEvent frames in core/AbsorbTracker.lua already restrict dispatch to player/target/
-- focus at the C level, so once an event reaches this handler every tracked unit drives the same
-- single coalesced all-bars repaint — the handler no longer re-filters by unit.
test("OnAbsorbChanged requests a repaint for any tracked unit, not just the player", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnAbsorbChanged(nil, "target")
  assertEqual(#mocks.__timers, 1)
  mocks.__fireTimers()
end)

test("OnMaxHealthChanged requests a repaint for the player", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnMaxHealthChanged(nil, "player")
  assertEqual(#mocks.__timers, 1)
  mocks.__fireTimers()
end)

test("OnMaxHealthChanged requests a repaint for any tracked unit, not just the player", function()
  -- Same Task 4 change as OnAbsorbChanged above: filtering happens upstream at the
  -- RegisterUnitEvent registration, not in this handler.
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnMaxHealthChanged(nil, "focus")
  assertEqual(#mocks.__timers, 1)
  mocks.__fireTimers()
end)

test("OnEnterWorld requests a repaint", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.addon:OnEnterWorld()
  assertEqual(#mocks.__timers, 1)
  mocks.__fireTimers()
end)
