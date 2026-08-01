-- tests/test_debuglog.lua — this addon's side of the debug console.
--
-- The console itself is LibKa0s-DebugLog and is tested in that repo: the two formatters, the buffer
-- and its cap, the enable seam's write path and ordering, the window, and the checkbox contract all
-- have cases there. Duplicating them here would mean two places to fix one bug.
--
-- What is ours, and what this file covers: the descriptor is wired to the right places, `/at debug`
-- reaches the right member, and the [Init] summary says what only this addon can know.

local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

test("FONT_MONO constant is a JetBrains Mono TTF path", function()
  assertTrue(type(NS.Constants.FONT_MONO) == "string", "FONT_MONO must be a string")
  assertTrue(NS.Constants.FONT_MONO:match("JetBrainsMono.-%.ttf$") ~= nil,
    "FONT_MONO must point at the vendored JetBrainsMono TTF")
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

-- ── the descriptor's seams ─────────────────────────────────────────────────────────────────

test("the debug flag the library reads and writes is NS.State.debug", function()
  -- The library keeps no copy: NS.ShouldShowBar's ladder and the settings panel both read this one.
  NS.State.debug = false
  NS.DebugLog:SetEnabled(true)
  assertTrue(NS.State.debug == true, "setEnabled writes our flag")
  assertTrue(NS.DebugLog:IsEnabled() == true, "and isEnabled reads it back")
  NS.State.debug = false
  assertFalse(NS.DebugLog:IsEnabled(), "a change made behind the library is seen immediately")
end)

test("NS.Debug is published and reaches the console buffer", function()
  NS.State.debug = true
  NS.DebugLog:Clear()
  NS.Debug("Absorb", "value=%s", 1234)
  NS.State.debug = false
  assertEqual(NS.DebugLog:BufferSize(), 1)
  assertTrue(NS.DebugLog:LastLine():find("[Absorb] value=1234", 1, true) ~= nil,
    "the sixteen NS.Debug call sites reach the shared console unchanged")
end)

test("our title and our font reach the descriptor", function()
  -- The title is ours; the " — Debug" suffix is the library's. Asserted on the recorded string
  -- rather than the font string, which cannot be read back through the frame API.
  NS.DebugLog:Show()
  local f = NS.DebugLog._frameForTest
  assertTrue(f ~= nil, "the window was built")
  assertEqual(f.titleText, "Absorb Tracker \226\128\148 Debug")
  NS.DebugLog:Hide()
end)

test("the console checkbox the General page renders is wired to this addon", function()
  -- settings/General.lua guards with `if NS.DebugLog and NS.DebugLog.ConsoleCheckbox`, so a broken
  -- wiring drops the checkbox silently. What the spec table DOES is the library's and is tested
  -- there; that it exists at all, and carries OUR slash verb, is ours.
  local spec = NS.DebugLog:ConsoleCheckbox()
  assertEqual(type(spec.label), "string")
  assertEqual(type(spec.get), "function")
  assertEqual(type(spec.set), "function")
  assertTrue(spec.tooltip:find("/at debug", 1, true) ~= nil,
    "slash = \"/at\" reached the descriptor: " .. spec.tooltip)
  NS.DebugLog:Hide()
  assertFalse(spec.get(), "get tracks the window this addon owns")
  NS.DebugLog:Show()
  assertTrue(spec.get())
  NS.DebugLog:Hide()
end)

-- ── the slash verb ─────────────────────────────────────────────────────────────────────────

test("/at debug on enables session state", function()
  NS.State.debug = false
  debugCmd("on")
  assertTrue(NS.State.debug == true, "state should be on")
  NS.State.debug = false
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

-- ── the [Init] summary ─────────────────────────────────────────────────────────────────────

test("/at debug on writes an [Init] summary naming our version, schema and profile", function()
  -- The library decides WHEN this lands (on enable, because the flag is off at login); only this
  -- addon can know what it says.
  NS.State.debug = false
  NS.DebugLog:Clear()
  local ack = captureChat(function() debugCmd("on") end)
  -- That an ack was printed proves the descriptor's `print` seam reaches NS.Print. What it SAYS,
  -- color codes included, is the library's and is pinned in the LibKa0s suite — asserting it here
  -- too would make one hex change fail two suites in two repos.
  assertTrue(#ack > 0, "the print seam reaches NS.Print and so the chat frame")
  local initLine = NS.DebugLog:FindLine("[Init]")
  assertTrue(initLine ~= nil, "an [Init] summary follows the bracket on enable")
  assertTrue(initLine:find(NS.name, 1, true) ~= nil, "it names the addon")
  assertTrue(initLine:find("v" .. NS.version, 1, true) ~= nil, "and its version")
  assertTrue(initLine:find("schema v", 1, true) ~= nil and initLine:find("profile", 1, true) ~= nil,
    "and the schema version and active profile: " .. tostring(initLine))
  NS.State.debug = false
end)

-- -- the `L` trap -----------------------------------------------------------------------------

test("the console checkbox label the library renders is prose, not its own STRINGS key", function()
  -- core/DebugLogSetup.lua:72's descriptor omits `L` — correct, because this addon translates
  -- nothing (locales/enUS.lua). This asserts the CONSEQUENCE rather than the omission: the string
  -- the library actually produced, read back through the live instance's own accessor. A resolved
  -- string is prose; an unresolved one is the STRINGS key itself, and no English label is
  -- SCREAMING_SNAKE_CASE. Deliberately not guarded with `if label then` — a nil accessor must fail
  -- here, not pass vacuously.
  -- red under: giving the descriptor an `L` that answers CHECKBOX_LABEL with "CHECKBOX_LABEL".
  local label = NS.DebugLog:ConsoleCheckbox().label
  assertTrue(type(label) == "string" and label ~= "", "ConsoleCheckbox must render a label")
  assertNil(label:match("^[A-Z][A-Z0-9_]+$"),
    "the label resolved to prose, not to its own key (got '" .. label .. "')")

  -- The window title is the second user-visible string this descriptor composes, and it is the one
  -- KickCD shipped broken (`Ka0s KickCDPANEL_TITLE_SUFFIX`). Ours is `title .. Text("TITLE_SUFFIX")`.
  local suffix = NS.DebugLog:Text("TITLE_SUFFIX")
  assertNil(suffix:match("^[A-Z][A-Z0-9_]+$"),
    "the title suffix resolved to prose, not to its own key (got '" .. suffix .. "')")
end)
