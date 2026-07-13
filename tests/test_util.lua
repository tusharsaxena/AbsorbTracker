local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- A stand-in for a WoW combat "secret" value. Crucially it models BOTH halves of the real
-- behaviour: the `..` operator SUCCEEDS on a secret (silently propagating secretness) while
-- `table.concat` RAISES on it. A table with a string-returning __concat concatenates fine via
-- `..`, yet `table.concat({mock})` still rejects it (table.concat ignores __concat and refuses a
-- non-string/number element) — so this catches a detector that (wrongly) probes with `..` and
-- passes one that probes with `table.concat`. (Earlier a __concat that *errored* was used, which
-- modelled the opposite of a real secret and gave false confidence.)
local secretMock = setmetatable({}, {
  __concat = function() return "secret-propagated" end,
})

test("IsConcatSafe: true for plain number/string, false for an un-concatenable value", function()
  assertTrue(NS.IsConcatSafe(1234) == true, "numbers concat fine")
  assertTrue(NS.IsConcatSafe("hi") == true, "strings concat fine")
  assertTrue(NS.IsConcatSafe(secretMock) == false, "secret-like value must be flagged unsafe")
end)

test("SafeToString: passes normal values through tostring", function()
  assertEqual(NS.SafeToString(1234), "1234")
  assertEqual(NS.SafeToString("hi"), "hi")
  assertEqual(NS.SafeToString(nil), "nil")
  assertEqual(NS.SafeToString(true), "true")
end)

test("SafeToString: renders a secret value as <secret> instead of raising", function()
  assertEqual(NS.SafeToString(secretMock), "<secret>")
end)

test("DebugPrint tolerates a secret arg (no concat crash, renders <secret>)", function()
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  local ok = pcall(NS.DebugPrint, "UNIT_ABSORB_AMOUNT_CHANGED -", secretMock)
  NS.State.debug = false
  assertTrue(ok, "DebugPrint must not raise on a secret arg")
  assertTrue(#NS.DebugLog.buffer > before, "a console line should still be appended")
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(last:find("<secret>", 1, true) ~= nil, "the secret arg should render as <secret>")
end)

test("Print tolerates a secret arg (no concat crash)", function()
  local ok = pcall(NS.Print, "value:", secretMock)
  assertTrue(ok, "Print must not raise on a secret arg")
end)
