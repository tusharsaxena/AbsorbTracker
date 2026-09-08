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

-- The [Combat] rollup prints "N events, M repaints" to show the throttle coalescing, and its N
-- counts PLAYER absorb events only (core/AbsorbTracker.lua). So M has to be passes, not bar-paints:
-- counting per bar made M scale with how many bars happened to be visible, which could push it
-- above N and read as if the throttle were amplifying work rather than collapsing it.
test("one coalesced pass counts one repaint, however many bars it painted", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local noted = 0
  local origNote, origPaint = NS.NoteRepaint, NS.UpdateAbsorbBar
  NS.NoteRepaint = function() noted = noted + 1 end
  NS.UpdateAbsorbBar = function() return true end   -- every unit paints

  NS.RequestRepaint()
  mocks.__fireTimers()

  NS.NoteRepaint, NS.UpdateAbsorbBar = origNote, origPaint
  assertEqual(noted, 1, "three bars painted, but it is still one repaint")
end)

test("a pass in which no bar painted counts no repaint", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local noted = 0
  local origNote, origPaint = NS.NoteRepaint, NS.UpdateAbsorbBar
  NS.NoteRepaint = function() noted = noted + 1 end
  NS.UpdateAbsorbBar = function() return false end  -- all hidden, or a /at test hold

  NS.RequestRepaint()
  mocks.__fireTimers()

  NS.NoteRepaint, NS.UpdateAbsorbBar = origNote, origPaint
  assertEqual(noted, 0, "the rollup would over-report otherwise")
end)

test("a pass counts one repaint when only some of the bars painted", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local noted = 0
  local origNote, origPaint = NS.NoteRepaint, NS.UpdateAbsorbBar
  NS.NoteRepaint = function() noted = noted + 1 end
  NS.UpdateAbsorbBar = function(unit) return unit == "player" end

  NS.RequestRepaint()
  mocks.__fireTimers()

  NS.NoteRepaint, NS.UpdateAbsorbBar = origNote, origPaint
  assertEqual(noted, 1, "one bar painting is still a repaint")
end)

test("RequestRepaint schedules the timer at the throttleWindow delay", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.RequestRepaint()
  assertEqual(mocks.__timers[1].delay, NS.GetSetting("throttleWindow"))
  mocks.__fireTimers()
end)

test("RequestRepaint hands AceTimer a clamped number, never the raw stored value", function()
  -- ABSORBTRACKER-R-05: the seam, not the getter (tests/test_data.lua pins the clamp itself). The
  -- case above asserts the delay equals the STORED value, which is true and stays true for every
  -- value the slider can produce — so it could never see the line pass a hand-edited SavedVariables
  -- string straight into AceTimer's `delay < 0.01`.
  -- red under: putting NS.GetSetting("throttleWindow") back at modules/Timer.lua:50.
  -- Arm every case FIRST, restore, and only then assert, for the reason tests/test_data.lua's
  -- twin gives: a raise inside the loop would skip the restore and leave a bad throttle behind for
  -- every later case in this file.
  local mocks = T.mocks
  local saved = NS.db.profile.throttleWindow
  local cases = { { 0, 0.05 }, { -1, 0.05 }, { 9, 1 }, { "0.4", 0.4 },
                  { "wibble", NS.flatDefaults.throttleWindow } }
  for _, c in ipairs(cases) do
    NS.db.profile.throttleWindow = c[1]
    mocks.__timers = {}
    NS.RequestRepaint()
    c[3] = mocks.__timers[1] and mocks.__timers[1].delay
    mocks.__fireTimers()
  end
  NS.db.profile.throttleWindow = saved
  for _, c in ipairs(cases) do
    assertEqual(c[3], c[2], "stored " .. tostring(c[1]))
  end
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
