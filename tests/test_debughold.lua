local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- `/at debug hold <value> [secs]`: the one-shot value hold, moved out of tests/test_slashcmds.lua
-- together with the verb it drives. It used to be `/at test <value> [secs]`. That verb is gone
-- because this addon's unlocked view is its preview, and options-ui-§15 and preview-mode bar a
-- `test` verb in that shape (anti-pattern #80). The hold answers a question unlocking does not
-- (what a real NUMBER looks like on the bar), so it survives under `debug`, which is where
-- WS-06 (2) puts a kept value hold. Moving the cases here also keeps test_slashcmds.lua clear of
-- layout-§1's 1500-line cap.
--
-- `debug` is a live verb (slash-commands-§2), but painting the bars is a feature, so `hold` carries
-- its own disabled gate. The duration is validated (0.5 to 60 s) and announced as given, not
-- truncated: `%d` used to turn 2.5 into "2 s" and announce -3 as "-3 s".

-- Same capture seam as test_slashcmds.lua: Slash.lua bound `local print = NS.Print` at load, so the
-- only interceptable point is the chat frame's AddMessage sink.
local function capture(fn)
  local out = {}
  local cf = T.mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  cf.AddMessage = old
  if not ok then error(err) end
  return out
end

local function stripColor(s)
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function slash(line)
  local out = capture(function() NS.Slash:OnSlash(line) end)
  local plain = {}
  for i, l in ipairs(out) do plain[i] = stripColor(l) end
  return plain
end

local function joined(lines) return table.concat(lines, "\n") end

local function contains(lines, needle)
  return joined(lines):find(needle, 1, true) ~= nil
end

local USAGE = "Usage: /at debug hold <value> [secs]"

--- Run `fn` with NS.HoldPreview spied. Returns the seconds each call received.
local function withHoldSpy(fn)
  local real, calls = NS.HoldPreview, {}
  NS.HoldPreview = function(secs, ...)
    calls[#calls + 1] = secs
    return real(secs, ...)
  end
  local ok, err = pcall(fn)
  NS.HoldPreview = real
  if not ok then error(err) end
  return calls
end

-- ── the verb moved ─────────────────────────────────────────────────────────────────────────────

test("the `test` verb is gone: it prints unknown command", function()
  local calls
  local out
  calls = withHoldSpy(function() out = slash("test 1000") end)
  assertTrue(contains(out, "unknown command 'test'"), joined(out))
  assertEqual(#calls, 0, "no hold from a verb that does not exist")
end)

test("COMMANDS carries no `test` row, and the debug row names `hold <value> [secs]`", function()
  local debugDesc
  for _, entry in ipairs(NS.COMMANDS) do
    assertFalse(entry[1] == "test",
      "the lock-is-preview shape ships no test verb (options-ui-§15, preview-mode)")
    if entry[1] == "debug" then debugDesc = entry[2] end
  end
  assertTrue(debugDesc and debugDesc:find("hold <value> [secs]", 1, true) ~= nil,
    "the debug help row documents the hold: " .. tostring(debugDesc))
  assertFalse(debugDesc:find("on|off", 1, true) ~= nil,
    "and it does not advertise a test mode toggle: " .. debugDesc)
end)

-- ── the usage line ─────────────────────────────────────────────────────────────────────────────

test("/at debug hold with a word it does not know prints the usage and changes nothing", function()
  local savedHold = NS.testHoldUntil
  local out
  local calls = withHoldSpy(function() out = slash("debug hold wibble") end)
  assertEqual(NS.testHoldUntil, savedHold, "no hold")
  assertEqual(#calls, 0)
  assertTrue(contains(out, USAGE), joined(out))
end)

test("bare /at debug hold prints the usage and holds nothing", function()
  local savedLocked = NS.GetSetting("locked")
  local savedHold = NS.testHoldUntil
  local out
  local calls = withHoldSpy(function() out = slash("debug hold") end)
  assertEqual(NS.GetSetting("locked"), savedLocked, "the lock is the switch, and this is not it")
  assertEqual(NS.testHoldUntil, savedHold, "no hold either")
  assertEqual(#calls, 0)
  assertTrue(contains(out, USAGE), joined(out))
end)

-- red under: `tonumber(args[2]) or 5` with no range check -- -3 was announced as "-3 s" and handed
-- to AceTimer, which clamps it to 0.01 s, so the hold vanished while chat promised three seconds.
test("/at debug hold with a negative duration prints the usage and holds nothing", function()
  NS.db.profile.units.player.enabled = true
  local out
  local calls = withHoldSpy(function() out = slash("debug hold 1000 -3") end)
  assertTrue(contains(out, USAGE), joined(out))
  assertEqual(#calls, 0, "a refused duration must not reach NS.HoldPreview")
end)

test("/at debug hold refuses a duration above 60 s and below 0.5 s", function()
  NS.db.profile.units.player.enabled = true
  for _, secs in ipairs({ "61", "0.4", "0", "soon" }) do
    local out
    local calls = withHoldSpy(function() out = slash("debug hold 1000 " .. secs) end)
    assertTrue(contains(out, USAGE), secs .. ": " .. joined(out))
    assertEqual(#calls, 0, secs .. " must not reach NS.HoldPreview")
  end
end)

test("/at debug hold accepts both ends of the range", function()
  NS.db.profile.units.player.enabled = true
  for _, secs in ipairs({ 0.5, 60 }) do
    local calls = withHoldSpy(function() slash("debug hold 1000 " .. secs) end)
    assertEqual(calls[1], secs, "the edge is inside the range")
    NS.ClearPreview()
  end
end)

-- red under: '%d s', which truncates 2.5 to "2 s" while the timer runs for 2.5.
test("/at debug hold announces a fractional duration as given, and holds for it", function()
  NS.db.profile.units.player.enabled = true
  local out
  local calls = withHoldSpy(function() out = slash("debug hold 1000 2.5") end)
  assertTrue(contains(out, "for 2.5 s"), joined(out))
  assertEqual(calls[1], 2.5)
  NS.ClearPreview()
end)

-- ── the hold itself ────────────────────────────────────────────────────────────────────────────

test("/at debug hold refuses while every bar is disabled and says how to fix it", function()
  local savedHold = NS.testHoldUntil
  local saved = {}
  for _, unit in ipairs(NS.Units.LIST) do
    saved[unit] = NS.db.profile.units[unit].enabled
    NS.db.profile.units[unit].enabled = false
  end
  local out = slash("debug hold 50000")
  for _, unit in ipairs(NS.Units.LIST) do
    NS.db.profile.units[unit].enabled = saved[unit]
  end
  assertTrue(contains(out, "Every bar is disabled"), joined(out))
  assertTrue(contains(out, "/at toggle"), joined(out))
  assertEqual(NS.testHoldUntil, savedHold, "no hold window is armed on the refusal path")
end)

test("/at debug hold paints the given value and arms the hold window", function()
  NS.db.profile.units.player.enabled = true
  local painted
  local sb = NS.statusBar
  rawset(sb, "SetValue", function(_, v) painted = v end)
  local out = slash("debug hold 12345 7")
  rawset(sb, "SetValue", nil)
  assertEqual(painted, 12345)
  assertEqual(NS.testHoldUntil, T.mocks.GetTime() + 7)
  assertTrue(contains(out, "Holding"), joined(out))
  NS.ClearPreview()
end)

test("/at debug hold with a value and no duration holds it for 5 seconds", function()
  NS.db.profile.units.player.enabled = true
  local painted
  local sb = NS.statusBar
  rawset(sb, "SetValue", function(_, v) painted = v end)
  local out = slash("debug hold 50000")
  rawset(sb, "SetValue", nil)
  assertEqual(painted, 50000)
  assertEqual(NS.testHoldUntil, T.mocks.GetTime() + 5)
  assertTrue(contains(out, "for 5 s"), joined(out))
  assertEqual(NS.State.testMode, nil, "the hold is a hold, and there is no mode to enter")
  NS.ClearPreview()
end)

test("/at debug hold keeps the bar scale usable for a value below the 100k floor", function()
  -- A small value must not shrink the scale below 100000, or the fake fill reads as full.
  NS.db.profile.units.player.enabled = true
  local mn, mx
  local sb = NS.statusBar
  rawset(sb, "SetMinMaxValues", function(_, a, b) mn, mx = a, b end)
  slash("debug hold 500")
  rawset(sb, "SetMinMaxValues", nil)
  assertEqual(mn, 0)
  assertEqual(mx, 100000)
  NS.ClearPreview()
end)

-- The announced duration is a promise: "for 7 s" has to be a scheduled expiry, not a timestamp
-- nobody revisits (preview-mode).
test("/at debug hold schedules the expiry it just announced", function()
  NS.db.profile.units.player.enabled = true
  local before = #T.mocks.__timers
  local out = slash("debug hold 12345 7")
  local armed = T.mocks.__timers[#T.mocks.__timers]
  assertTrue(contains(out, "for 7 s"), joined(out))
  assertEqual(#T.mocks.__timers, before + 1, "the announced window must be armed")
  assertEqual(armed.delay, 7, "the timer fires at the end of the window the user was told about")
  NS.ClearPreview()
end)

test("re-locking the bars clears a live /at debug hold preview", function()
  NS.db.profile.units.player.enabled = true
  local wasLocked = NS.GetSetting("locked")
  slash("unlock")
  slash("debug hold 12345 30")
  assertTrue((NS.testHoldUntil or 0) > T.mocks.GetTime(), "the hold is live before the re-lock")
  slash("lock")
  assertEqual(NS.testHoldUntil, nil, "re-locking returns the bars to live data (preview-mode)")
  NS.SetByPath("locked", wasLocked)
  NS.ClearPreview()
end)

-- ── the hold's own disabled gate ───────────────────────────────────────────────────────────────

-- `debug` answers while disabled (slash-commands-§2), so the library's gate never sees `hold`.
-- The hold paints the bars, which is a feature, so it refuses on the collection's one line.
-- red under: a `hold` sub-verb with no gate of its own -- it would leave a fake value on a bar for
-- five seconds on an addon the player turned off.
test("/at debug hold refuses while the addon is disabled: one line, no paint, no hold", function()
  NS.SetByPath("enabled", false)
  local painted = NS.bars.player and NS.bars.player.valueText:GetText()
  local out
  local calls = withHoldSpy(function() out = slash("debug hold 123456") end)
  local refusal = stripColor(NS.Slash:DisabledLine())
  NS.SetByPath("enabled", true)

  assertEqual(#out, 1, "one refusal line: " .. joined(out))
  assertTrue(contains(out, refusal), joined(out))
  assertEqual(#calls, 0, "a refused hold armed the preview")
  assertEqual(NS.bars.player and NS.bars.player.valueText:GetText(), painted,
    "and it must not have painted the fake value either")
end)
