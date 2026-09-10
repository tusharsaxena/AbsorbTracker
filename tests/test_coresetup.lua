-- What core/CoreSetup.lua is responsible for: that the addon's seam actually reaches
-- LibKa0s-Core-1.0 rather than a leftover private copy, that the tag is ours, and that a missing
-- library leaves a working addon rather than a silent or a broken one. The algorithms themselves
-- are the library's and are tested in the LibKa0s repo.

local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local secretMock = setmetatable({}, {
  __concat = function() return "secret-propagated" end,
})

local function chatOf(mocks, fn)
  local out = {}
  local frame = mocks.DEFAULT_CHAT_FRAME
  rawset(frame, "AddMessage", function(_, msg) out[#out + 1] = msg end)
  fn()
  rawset(frame, "AddMessage", nil)
  return out
end

test("core: the secret seam is the library's, not a private copy", function()
  local lib = T.mocks.LibStub("LibKa0s-Core-1.0")
  assertTrue(NS.IsConcatSafe == lib.IsConcatSafe, "NS.IsConcatSafe is Core's own function")
  assertTrue(NS.SafeToString == lib.SafeToString, "NS.SafeToString is Core's own function")
  assertEqual(NS.SafeToString(secretMock), lib.SECRET)
end)

test("core: the perf descriptor names the folder and leaves the close control to the library", function()
  -- ANTI-PATTERN #64, THE ONE THIS SUITE EXISTS FOR: a wrapper that does not carry every argument
  -- its target takes. core/PerfSetup.lua's `decorate` used to call
  -- NS.DebugLog.MakeCloseButton(frame, api.Hide) -- two arguments onto a three-argument function --
  -- so the panel drew a multiplication sign while every suite stayed green, because a texture path
  -- that is never built draws nothing and raises nothing.
  --
  -- THE HOOK IS GONE, AND THAT IS THE POINT. `decorate` was repaired into a copy of what
  -- libs/LibKa0s/PerfPanel.lua:185-196 does in its else arm -- same factory, same TOPRIGHT anchor,
  -- same -(TITLE_H - 18) / 2 offset -- and PerfPanel minor 4 passes `d.addonName or d.name`, so the
  -- library reaches the same texture the wrapper did. A duplicate that agrees today is a duplicate
  -- that can disagree tomorrow, and the branch is EXCLUSIVE: a host supplying `decorate` never runs
  -- the library's arm, so the collection's own close mark would silently become this addon's
  -- private business again.
  --
  -- SO THE DESCRIPTOR IS ASSERTED IN BOTH DIRECTIONS -- `addonName` present, `decorate` absent --
  -- and then the REAL panel is shown against a spy on the library's factory, because the descriptor
  -- shape alone says nothing about what reaches the screen. Testing the ARGUMENT, not the
  -- appearance: a source grep stays green under any refactor that keeps the text and breaks the call.
  --
  -- red under: re-adding `decorate` to the descriptor; dropping `addonName`; a vendored PerfPanel
  -- whose else arm stops passing the folder name on to MakeCloseButton.
  local perfLib = T.mocks.LibStub("LibKa0s-Perf-1.0")
  local realNew = perfLib.New
  local descriptor
  perfLib.New = function(_, d)
    descriptor = d
    return { on = false, suspended = false, Note = function() end }
  end

  -- A scratch namespace that reads through to the live one, so the reloaded chunk sees the real
  -- NS.Print sinks while its NS.Perf assignment lands here rather than replacing the instance the
  -- rest of the suite shares.
  local Loader = dofile("tests/_kit/loader.lua")
  Loader.addonName = "AbsorbTracker"
  local NS2 = setmetatable({}, { __index = NS })
  local ok, err = pcall(Loader.load, "core/PerfSetup.lua", NS2, T.mocks)
  perfLib.New = realNew
  assertTrue(ok, "reloading core/PerfSetup.lua raised: " .. tostring(err))

  assertTrue(type(descriptor) == "table",
    "core/PerfSetup.lua did not hand LibKa0s-Perf a descriptor at all")
  assertEqual(descriptor.addonName, "AbsorbTracker",
    "the descriptor must name the addon FOLDER explicitly -- `name` reaching the same string is "
      .. "luck, and libs/LibKa0s/PerfPanel.lua reads `d.addonName or d.name`")
  assertTrue(descriptor.decorate == nil,
    "the descriptor must NOT carry `decorate` -- the hook was a copy of PerfPanel's own else arm, "
      .. "and supplying it takes the library's close control off the panel entirely")

  -- The live instance, built at load with the real descriptor, drawing its real panel.
  local core = T.mocks.LibStub("LibKa0s-Core-1.0")
  local realMake = core.MakeCloseButton
  local calls, sawClick, sawName = 0, nil, nil
  core.MakeCloseButton = function(_, onClick, name)
    calls = calls + 1
    sawClick, sawName = onClick, name
    return nil   -- the factory answers nil where CreateFrame is unavailable; the arm must survive it
  end
  local shown, showErr = pcall(NS.Perf.ShowPanel)
  NS.Perf.HidePanel()
  core.MakeCloseButton = realMake
  assertTrue(shown, "showing the perf panel raised: " .. tostring(showErr))

  assertEqual(calls, 1, "the library's else arm must build exactly one close control")
  assertTrue(sawClick == NS.Perf.HidePanel, "the panel's own Hide must be the click handler")
  assertEqual(sawName, "AbsorbTracker",
    "the library was not told which addon folder to build the panel's close mark from")
end)

test("core: NS.Print carries the [AT] tag and survives a secret arg", function()
  local out = chatOf(T.mocks, function() NS.Print("value:", secretMock) end)
  assertEqual(#out, 1)
  assertEqual(out[1], NS.PREFIX .. " value: <secret>")
end)

test("core: NS.Print and NS.Util.print are the same object after the AceConsole reclaim", function()
  -- The reclaim in core/AbsorbTracker.lua repoints NS.Print at NS.Util.print, so a printer built as
  -- two separate closures would leave every `local print = NS.Print` capture pointing at the wrong
  -- one. tests/test_slash.lua asserts the same identity from the other side.
  assertTrue(NS.Print == NS.Util.print, "one function object, reachable under two names")
end)

test("core: the addon still prints, tagged, with LibKa0s absent", function()
  local Loader = dofile("tests/_kit/loader.lua")
  local buildMocks = dofile("tests/wow_mock.lua")
  Loader.addonName = "AbsorbTracker"
  local mocks2, NS2 = buildMocks(), {}
  Loader.loadAll({
    "core/EnvSetup.lua", "core/Constants.lua", "core/Namespace.lua", "core/CoreSetup.lua",
  }, NS2, mocks2)

  assertTrue(NS2.Print == NS2.Util.print, "the identity holds in the degraded build too")
  assertEqual(NS2.SafeToString(secretMock), "<secret>", "the fallback still guards secrets")

  local out = chatOf(mocks2, function()
    NS2.Print("first line")
    NS2.Print("second line")
  end)
  -- Said once, on the first line printed, not stapled to every line.
  assertEqual(#out, 3)
  assertTrue(out[1]:find("LibKa0s", 1, true) ~= nil, "the first print explains what is missing")
  assertEqual(out[2], NS2.PREFIX .. " first line")
  assertEqual(out[3], NS2.PREFIX .. " second line")
end)
