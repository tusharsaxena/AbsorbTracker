local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The closed message bus (core/Bus.lua, architecture-§4). Producers publish on
-- NS.bus; each consumer subscribes on its own NS.NewBusTarget(). These tests run
-- against the harness's (message, target)-keyed AceEvent mock (tests/wow_mock.lua),
-- which fans a SendMessage out to every registered target exactly like the live lib.

test("bus, NewBusTarget, and the message catalog are published", function()
  assertTrue(NS.bus ~= nil, "NS.bus published")
  assertTrue(type(NS.bus.SendMessage) == "function", "NS.bus can SendMessage")
  assertTrue(type(NS.NewBusTarget) == "function", "NS.NewBusTarget published")
  assertTrue(NS.MSG ~= nil, "NS.MSG catalog published")
  assertEqual(NS.MSG.REPAINT,    "Ka0s_AbsorbTracker_RepaintRequested")
  assertEqual(NS.MSG.APPEARANCE, "Ka0s_AbsorbTracker_AppearanceChanged")
  assertEqual(NS.MSG.VISIBILITY, "Ka0s_AbsorbTracker_VisibilityChanged")
  assertEqual(NS.MSG.POSITION,   "Ka0s_AbsorbTracker_PositionChanged")
end)

test("a receiver on its own target hears a message, then is silent after unregister", function()
  local got = 0
  local target = NS.NewBusTarget()
  target:RegisterMessage("AT_TEST_Ping", function() got = got + 1 end)

  NS.bus:SendMessage("AT_TEST_Ping")
  assertEqual(got, 1, "receiver heard the message")

  target:UnregisterMessage("AT_TEST_Ping")
  NS.bus:SendMessage("AT_TEST_Ping")
  assertEqual(got, 1, "unregistered receiver goes silent")
end)

-- anti-pattern #33: two receivers of ONE message, each on its OWN target, must BOTH
-- fire. A no-op or single-slot mock (or two receivers sharing one target) would let
-- the second registration silently clobber the first — the exact bug the rule guards.
test("two receivers of one message both fire (no (message,target) clobber)", function()
  local a, b = 0, 0
  local ta, tb = NS.NewBusTarget(), NS.NewBusTarget()
  ta:RegisterMessage("AT_TEST_Fanout", function() a = a + 1 end)
  tb:RegisterMessage("AT_TEST_Fanout", function() b = b + 1 end)

  NS.bus:SendMessage("AT_TEST_Fanout")
  assertEqual(a, 1, "first receiver fired")
  assertEqual(b, 1, "second receiver fired (not clobbered by the first)")

  ta:UnregisterMessage("AT_TEST_Fanout")
  tb:UnregisterMessage("AT_TEST_Fanout")
end)

test("a message payload reaches the receiver after the message name", function()
  local seen
  local target = NS.NewBusTarget()
  -- CallbackHandler fires a function-ref callback as fn(message, ...payload).
  target:RegisterMessage("AT_TEST_Payload", function(_, value) seen = value end)
  NS.bus:SendMessage("AT_TEST_Payload", "hello")
  assertEqual(seen, "hello", "payload arrives after the message name")
  target:UnregisterMessage("AT_TEST_Payload")
end)

-- Integration: the production catalog routes to the right consumer.
test("REPAINT routes through Timer to one coalesced repaint", function()
  local mocks = T.mocks
  mocks.__timers = {}
  NS.bus:SendMessage(NS.MSG.REPAINT)
  NS.bus:SendMessage(NS.MSG.REPAINT)          -- coalesced by NS.RequestRepaint
  assertEqual(#mocks.__timers, 1, "two REPAINTs coalesce into one scheduled repaint")
  mocks.__fireTimers()                        -- drain so `pending` resets for later suites
end)

test("APPEARANCE / VISIBILITY / POSITION route to their Display consumers", function()
  local appearance, visibility, position = 0, 0, 0
  local origA, origV, origP =
    NS.UpdateBarAppearance, NS.ApplyVisibility, NS.RestoreBarPosition
  NS.UpdateBarAppearance = function() appearance = appearance + 1 end
  NS.ApplyVisibility     = function() visibility = visibility + 1 end
  NS.RestoreBarPosition  = function() position   = position   + 1 end

  NS.bus:SendMessage(NS.MSG.APPEARANCE)
  NS.bus:SendMessage(NS.MSG.VISIBILITY)
  NS.bus:SendMessage(NS.MSG.POSITION)

  NS.UpdateBarAppearance, NS.ApplyVisibility, NS.RestoreBarPosition =
    origA, origV, origP

  -- Task 4: Display's bus handlers fan each message out over all three tracked units
  -- (NS.ForEachUnit), so each consumer now fires once per bar rather than once total.
  assertEqual(appearance, 3, "APPEARANCE -> UpdateBarAppearance, once per unit")
  assertEqual(visibility, 3, "VISIBILITY -> ApplyVisibility, once per unit")
  assertEqual(position,   3, "POSITION -> RestoreBarPosition, once per unit")
end)

test("sending a message with no subscribers is a harmless no-op", function()
  local ok = pcall(function() NS.bus:SendMessage("AT_TEST_Nobody_Listening") end)
  assertTrue(ok, "SendMessage with no registrant does not error")
  assertFalse(false, "sanity")
end)
