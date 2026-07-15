local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

test("FONT_MONO constant is a JetBrains Mono TTF path", function()
  assertTrue(type(NS.Constants.FONT_MONO) == "string", "FONT_MONO must be a string")
  assertTrue(NS.Constants.FONT_MONO:match("JetBrainsMono.-%.ttf$") ~= nil,
    "FONT_MONO must point at the vendored JetBrainsMono TTF")
end)

test("FormatPlain wraps the tag in brackets with single-space separators", function()
  assertEqual(NS.DebugLog.FormatPlain("15:04:43", "Absorb", "player=1234"),
    "15:04:43 | [Absorb] player=1234")
end)

test("FormatPlain tolerates a nil tag", function()
  assertEqual(NS.DebugLog.FormatPlain("15:04:43", nil, "hi"), "15:04:43 | [] hi")
end)

test("FormatColored colours the timestamp and tag; pipe and content default", function()
  assertEqual(NS.DebugLog.FormatColored("15:04:43", "Absorb", "player=1234"),
    "|cff6f8faf15:04:43|r || |cffc9a66b[Absorb]|r player=1234")
end)

local function debugCmd(rest)
  for _, c in ipairs(NS.COMMANDS) do
    if c[1] == "debug" then return c[3](rest) end
  end
  error("no debug command")
end

-- NS.Print writes to DEFAULT_CHAT_FRAME:AddMessage; override it on the mock frame to record the
-- chat ack lines (same pattern as tests/test_slash.lua).
local function captureChat(fn)
  local cf = T.mocks.DEFAULT_CHAT_FRAME
  local out = {}
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  cf.AddMessage = old
  if not ok then error(err) end
  return table.concat(out, "\n")
end

test("/at debug on enables session state", function()
  NS.State.debug = false
  debugCmd("on")
  assertTrue(NS.State.debug == true, "state should be on")
end)

test("/at debug off disables session state", function()
  NS.State.debug = true
  debugCmd("off")
  assertTrue(NS.State.debug == false, "state should be off")
end)

test("/at debug (no arg) toggles the window, not the state", function()
  NS.State.debug = true
  debugCmd("")
  assertTrue(NS.State.debug == true, "bare toggle must not change state")
  NS.State.debug = false
  debugCmd("")
  assertTrue(NS.State.debug == false, "bare toggle must not change state")
end)

test("header toggle click flips debug state", function()
  NS.State.debug = false
  NS.DebugLog:Show()
  local click = NS.DebugLog._toggleClickForTest
  assertTrue(type(click) == "function", "toggle click closure must be exposed")
  click(); assertTrue(NS.State.debug == true, "click should turn state on")
  click(); assertTrue(NS.State.debug == false, "second click should turn state off")
end)

test("/at debug on: green-ON ack, then '[Debug] logging enabled' bracket + [Init] summary (§5)", function()
  NS.State.debug = false
  local ack = captureChat(function() debugCmd("on") end)
  -- §5: the chat ack colour-codes the state word — ON in green (40ff40).
  assertTrue(ack:find("|cff40ff40ON|r", 1, true) ~= nil, "enable ack colours ON green: " .. ack)
  -- On enable the [Init] session summary follows the bracket, so the bracket is second-to-last.
  local n = #NS.DebugLog.buffer
  local bracket, initLine = NS.DebugLog.buffer[n - 1], NS.DebugLog.buffer[n]
  assertTrue(bracket and bracket:find("[Debug] logging enabled", 1, true) ~= nil,
    "the bracket line is written on enable")
  assertTrue(initLine and initLine:find("[Init]", 1, true) ~= nil,
    "an [Init] session summary follows the bracket on enable")
  assertTrue(initLine:find("schema v", 1, true) ~= nil and initLine:find("profile", 1, true) ~= nil,
    "the [Init] summary names the schema version and active profile: " .. tostring(initLine))
  NS.State.debug = false
end)

test("/at debug off: red-OFF ack, and '[Debug] logging disabled' is the last console line (§5)", function()
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  local ack = captureChat(function() debugCmd("off") end)
  -- §5: OFF in red (ff4040). No [Init] summary on disable, so the bracket stays last.
  assertTrue(ack:find("|cffff4040OFF|r", 1, true) ~= nil, "disable ack colours OFF red: " .. ack)
  assertTrue(#NS.DebugLog.buffer > before, "disabling should still append a console line")
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(last and last:find("[Debug] logging disabled", 1, true) ~= nil,
    "disabling should log '[Debug] logging disabled' as the last line")
end)

test("NS.Debug is a no-op (no console write) when debug is off", function()
  NS.State.debug = false
  local before = #NS.DebugLog.buffer
  NS.Debug("Absorb", "should not append")
  assertEqual(#NS.DebugLog.buffer, before)
end)
