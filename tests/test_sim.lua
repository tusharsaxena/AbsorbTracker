local T = _G.AT_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- `/at sim [stop]` (SF-AT-2): a scripted, made-up absorb fight played on the bars, modeled on
-- DpsRace's `/dr sim`. It holds the bars for the whole fight, stores nothing, stops on `stop` and
-- leaves no hold or timer behind when it ends.

local function slash(line)
  local out = {}
  local cf = M.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(NS.Slash.OnSlash, NS.Slash, line)
  cf.AddMessage = old
  if not ok then error(err, 0) end
  return table.concat(out, "\n")
end

-- Fire the chained one-shot timers until none is left to run.
local function drain()
  for _ = 1, 40 do
    if M.__fireTimers() == 0 then return end
  end
end



test("sim: COMMANDS carries a sim row", function()
  local found
  for _, e in ipairs(NS.COMMANDS) do if e[1] == "sim" then found = e end end
  assertTrue(found ~= nil, "a sim verb")
  assertTrue(found[2]:find("/at sim [stop]", 1, true) ~= nil, found[2])
end)

test("sim: a bad word prints the usage and holds nothing", function()
  NS.ClearPreview()
  local out = slash("sim wibble")
  assertTrue(out:find("Usage: /at sim [stop]", 1, true) ~= nil, out)
  assertEqual(NS.testHoldUntil, nil, "no hold")
end)

test("sim: stop with nothing running says so", function()
  assertTrue(slash("sim stop"):find("No sim is running", 1, true) ~= nil)
end)

test("sim: a run holds the bars, plays the script, then lets go", function()
  NS.ClearPreview()
  local out = slash("sim")
  assertTrue(out:find("made-up absorb fight", 1, true) ~= nil, out)
  assertTrue(NS.testHoldUntil ~= nil, "the bars are held for the fight")
  drain()
  M.__now = M.__now + 30
  drain()
  assertEqual(NS.testHoldUntil, nil, "the hold ended with the fight")
end)

test("sim: stop cancels the fight and clears the hold", function()
  slash("sim")
  assertTrue(NS.testHoldUntil ~= nil)
  local out = slash("sim stop")
  assertTrue(out:find("Sim stopped", 1, true) ~= nil, out)
  assertEqual(NS.testHoldUntil, nil, "hold cleared")
  assertTrue(slash("sim stop"):find("No sim is running", 1, true) ~= nil, "and nothing is left running")
end)

test("sim: a disabled addon refuses on the collection's line", function()
  NS.SetByPath("enabled", false)
  local ok, out = pcall(slash, "sim")
  NS.SetByPath("enabled", true)
  M.__fireTimers()
  assertTrue(ok, tostring(out))
  assertEqual(NS.testHoldUntil, nil, "no hold")
  assertFalse(out == "", "it said something")
end)
