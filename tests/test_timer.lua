local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual = T.test, T.assertEqual

-- ── Coalescing repaint scheduler (modules/Timer.lua) ──────────────────────────────
test("RequestRepaint coalesces multiple requests into one scheduled repaint", function()
  local mocks = T.mocks
  mocks.__timers = {}
  -- Count PASSES, not paints: one fired timer now paints every unit in NS.Units.LIST, so counting
  -- raw calls would make this assert the unit count rather than the coalescing it exists to test.
  local calls = 0
  local orig = NS.UpdateAbsorbBar
  NS.UpdateAbsorbBar = function(unit) if unit == "player" then calls = calls + 1 end end

  NS.RequestRepaint(); NS.RequestRepaint(); NS.RequestRepaint()
  assertEqual(#mocks.__timers, 1)          -- three requests, one timer
  mocks.__fireTimers()
  assertEqual(calls, 1)                     -- fires exactly one repaint
  NS.RequestRepaint()
  assertEqual(#mocks.__timers, 1)           -- re-arms after firing
  mocks.__fireTimers()                      -- drain so `pending` resets for later tests

  NS.UpdateAbsorbBar = orig
end)

-- The Timer -> Display seam. Every other repaint test stubs UpdateAbsorbBar and only counts the
-- calls, so a fan-out that painted the player alone still passed them all: the target and focus
-- StatusBars were created, styled and shown but never had SetMinMaxValues/SetValue/SetText run,
-- leaving them at the untouched frame default (full fill, empty text). Assert the units by name.
test("the coalesced repaint paints every tracked unit, not just the player", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local painted = {}
  local orig = NS.UpdateAbsorbBar
  NS.UpdateAbsorbBar = function(unit) painted[#painted + 1] = unit end

  NS.RequestRepaint()
  mocks.__fireTimers()

  NS.UpdateAbsorbBar = orig
  assertEqual(#painted, #NS.Units.LIST, "one paint per tracked unit")
  for i, unit in ipairs(NS.Units.LIST) do
    assertEqual(painted[i], unit, "paints units in NS.Units.LIST order")
  end
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
