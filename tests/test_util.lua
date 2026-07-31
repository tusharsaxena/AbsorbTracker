local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- The secret guard, the stringifier and the printer moved to LibKa0s-Core-1.0, and their algorithm
-- is tested there (LibKa0s tests/test_core.lua carries this mock verbatim). What remains here is
-- NS.Debug, which is the debug console's seam rather than Core's — it moves in its own milestone.

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

test("NS.Debug routes the first arg as the [tag] and tolerates a secret arg", function()
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  local ok = pcall(NS.Debug, "Absorb", "value=%s", secretMock)
  NS.State.debug = false
  assertTrue(ok, "NS.Debug must not raise on a secret arg")
  assertTrue(#NS.DebugLog.buffer > before, "a console line should still be appended")
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(last:find("[Absorb]", 1, true) ~= nil, "the first arg is the console [tag]")
  assertTrue(last:find("value=<secret>", 1, true) ~= nil, "a secret arg renders as <secret>")
end)

test("NS.Debug is a no-op when debug is off", function()
  NS.State.debug = false
  local before = #NS.DebugLog.buffer
  NS.Debug("Absorb", "value=%s", 123)
  assertEqual(#NS.DebugLog.buffer, before)
end)
