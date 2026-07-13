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

test("/at debug on writes a '[Debug] logging enabled' line to the console", function()
  NS.State.debug = false
  debugCmd("on")
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(last and last:find("[Debug] logging enabled", 1, true) ~= nil,
    "enabling should log '[Debug] logging enabled'")
  NS.State.debug = false
end)

test("/at debug off writes a '[Debug] logging disabled' line to the console", function()
  NS.State.debug = true
  local before = #NS.DebugLog.buffer
  debugCmd("off")
  assertTrue(#NS.DebugLog.buffer > before, "disabling should still append a console line")
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(last and last:find("[Debug] logging disabled", 1, true) ~= nil,
    "disabling should log '[Debug] logging disabled'")
end)

test("NS.Debug is a no-op (no console write) when debug is off", function()
  NS.State.debug = false
  local before = #NS.DebugLog.buffer
  NS.Debug("Absorb", "should not append")
  assertEqual(#NS.DebugLog.buffer, before)
end)
