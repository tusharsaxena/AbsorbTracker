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

test("the console's font resolves through the Media seam to the LibKa0s payload", function()
  -- This used to pin a literal path into this addon's own media/fonts/. That folder is gone: the
  -- face ships inside the vendored LibKa0s payload now and core/Constants.lua resolves it through
  -- NS.MediaFont at load, so the truth worth pinning here is that the descriptor hands the console
  -- the resolved path rather than a second spelling of it.
  -- The seam itself — extensionless icons, nil for an unknown name, the degraded fallback — is
  -- covered in tests/test_mediasetup.lua.
  assertTrue(type(NS.Constants.FONT_MONO) == "string", "FONT_MONO must be a string")
  assertEqual(NS.Constants.FONT_MONO, NS.MediaFont(NS.Constants.FONT_MONO_NAME),
    "FONT_MONO must be what the seam answers for FONT_MONO_NAME")
  assertTrue(NS.Constants.FONT_MONO:match("libs\\LibKa0s\\media\\fonts\\JetBrainsMono.-%.ttf$") ~= nil,
    "FONT_MONO must point into the vendored payload, got " .. tostring(NS.Constants.FONT_MONO))
end)

-- The descriptor core/DebugLogSetup.lua actually hands `lib:New`, captured by a spy rather than
-- read out of the source.
--
-- WHY A WHOLE SECOND LOAD. `lib:New` is called once, at file load, and by the time any suite runs
-- the shared environment in tests/run.lua has long since made that call. So this builds a second
-- full environment — libraries first, exactly as the runner does — wraps `New` on the registered
-- LibKa0s-DebugLog-1.0 major, and then loads the addon, which is the only moment the real argument
-- exists. tests/degraded_env.lua does the same trick for the library-less case.
local function captureDescriptor()
  local Loader     = dofile("tests/_kit/loader.lua")
  local buildMocks = dofile("tests/wow_mock.lua")
  Loader.addonName = "AbsorbTracker"
  local mocks2, NS2 = buildMocks(), {}
  Loader.loadAll(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), NS2, mocks2)

  local lib = mocks2.LibStub("LibKa0s-DebugLog-1.0")
  local realNew, seen = lib.New, nil
  lib.New = function(self, d) seen = d; return realNew(self, d) end
  local ok, err = pcall(Loader.loadAll, Loader.tocFiles("AbsorbTracker.toc"), NS2, mocks2)
  lib.New = realNew
  if not ok then error(err, 0) end
  return seen
end

test("the descriptor tells the library the FOLDER name, not just the frame name", function()
  -- Two fields, two questions, one string in this addon: `name` seeds AbsorbTrackerDebugWindow and
  -- its Copy window's globals; `addonName` is what the library builds a texture path from, so its
  -- own close, copy and clear draw this collection's marks instead of a multiplication sign and two
  -- words. A host where the two strings diverge would hand the library a path into nowhere — which
  -- draws nothing and raises nothing — so it is passed explicitly rather than inferred from `name`.
  --
  -- ASSERTED ON THE TABLE THE LIBRARY RECEIVED, NOT ON THE SOURCE TEXT. A grep for
  -- `addonName%s*=%s*addonName` matches just as happily inside `local d = {}; d.addonName =
  -- addonName` — a table `lib:New` never sees — and that decoy is anti-pattern #64 exactly: the
  -- library gets nil, makeIconButton returns nil for all three marks, both windows go back to the
  -- multiplication sign and two words, and every suite stays green because a texture path that is
  -- never built draws nothing and raises nothing.
  -- red under: dropping the `addonName` line, AND under moving it onto a table that never reaches
  -- the call.
  local d = captureDescriptor()
  assertTrue(type(d) == "table", "core/DebugLogSetup.lua never called lib:New")
  assertEqual(d.addonName, "AbsorbTracker",
    "the descriptor the library received carries no folder name, so both console windows draw the "
      .. "untold title bar")
  assertEqual(d.name, "AbsorbTracker",
    "and it must still seed its frame names from the same folder name")
end)

test("and it takes that folder name from the vararg, not from a hand-typed literal", function()
  -- The one thing a spy cannot see: both fields would read "AbsorbTracker" whether they came from
  -- the first vararg or from a quoted string, because this addon's folder and its frame prefix are
  -- the same word. A literal is still wrong — it is a second place to edit when a folder is
  -- renamed, and a wrong texture path draws nothing and raises nothing — so this half stays a
  -- source check, deliberately secondary to the spy above.
  local f = io.open("core/DebugLogSetup.lua", "r")
  assertTrue(f ~= nil, "cannot open core/DebugLogSetup.lua (tests run from the repo root)")
  local src = f:read("*a")
  f:close()
  local body = src:gsub("%-%-[^\r\n]*", "")
  assertNil(body:find("\"AbsorbTracker\"", 1, true),
    "the descriptor must name this addon through `addonName`, the first vararg, never as a literal")
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
