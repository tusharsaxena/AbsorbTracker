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

test("core: the close button is the library's, told which addon is asking", function()
  -- The one member of this seam that is WRAPPED rather than handed over by reference. LibKa0s draws
  -- this collection's own close mark when it can build a texture path, and it cannot work that out
  -- itself: it is vendored, so there is no one path to it and a copy cannot know which folder it was
  -- copied into. The wrapper supplies the answer once, for every close control the addon builds.
  --
  -- THE ARGUMENT IS WHAT IS TESTED, not the appearance. lib.MakeCloseButton takes three arguments;
  -- a two-argument passthrough onto it is green in every suite and visible only in a screenshot,
  -- because a texture path that is never built draws nothing and raises nothing.
  -- red under: NS.MakeCloseButton = lib.MakeCloseButton, or a wrapper that drops the third argument.
  local lib = T.mocks.LibStub("LibKa0s-Core-1.0")
  local real = lib.MakeCloseButton
  local seen, sawParent, sawClick
  lib.MakeCloseButton = function(parent, onClick, name)
    sawParent, sawClick, seen = parent, onClick, name
    return nil
  end
  local parent, click = {}, function() end
  NS.MakeCloseButton(parent, click)
  lib.MakeCloseButton = real

  assertEqual(seen, "AbsorbTracker",
    "the library was not told which addon folder to build the mark's path from")
  assertTrue(sawParent == parent, "the wrapper must carry the parent through")
  assertTrue(sawClick == click, "the wrapper must carry the click handler through")
end)

test("core: the perf panel builds its close control through that one wrapper", function()
  -- ANTI-PATTERN #64, THE ONE THIS SUITE EXISTS FOR: a wrapper that does not carry every argument
  -- its target takes. core/PerfSetup.lua's `decorate` used to call
  -- NS.DebugLog.MakeCloseButton(frame, api.Hide) -- two arguments onto a three-argument function --
  -- so the panel drew a multiplication sign while every suite stayed green, because a texture path
  -- that is never built draws nothing and raises nothing.
  --
  -- THIS USED TO BE A SOURCE GREP, and a source grep is not an argument test: it stays green under
  -- any refactor that keeps the text and breaks the call, and it says nothing at all about whether
  -- the descriptor still CARRIES `decorate`. That second half matters here more than it looks.
  -- libs/LibKa0s/PerfPanel.lua branches on it: with `decorate` supplied the panel's close control
  -- comes from this addon's wrapper and gets the mark; with it absent the library falls to its own
  -- `core.MakeCloseButton(frame, P.HidePanel)` -- still a TWO-argument call onto the three-argument
  -- function at the time of writing -- and the panel silently goes back to the multiplication sign.
  -- So the descriptor is captured for real and its `decorate` is RUN, against a spy on the library
  -- function, and the value the library is actually handed is what is asserted.
  --
  -- red under: dropping `decorate` from the descriptor; calling the library's MakeCloseButton
  -- directly instead of through NS.MakeCloseButton; any wrapper that stops carrying the third
  -- argument, the parent or the click handler.
  local perfLib = T.mocks.LibStub("LibKa0s-Perf-1.0")
  local realNew = perfLib.New
  local descriptor
  perfLib.New = function(_, d)
    descriptor = d
    return { on = false, suspended = false, Note = function() end }
  end

  -- A scratch namespace that reads through to the live one, so the reloaded chunk sees the real
  -- NS.MakeCloseButton wrapper (and the real NS.Print sinks) while its NS.Perf assignment lands
  -- here rather than replacing the instance the rest of the suite shares.
  local Loader = dofile("tests/_kit/loader.lua")
  Loader.addonName = "AbsorbTracker"
  local NS2 = setmetatable({}, { __index = NS })
  local ok, err = pcall(Loader.load, "core/PerfSetup.lua", NS2, T.mocks)
  perfLib.New = realNew
  assertTrue(ok, "reloading core/PerfSetup.lua raised: " .. tostring(err))

  assertTrue(type(descriptor) == "table",
    "core/PerfSetup.lua did not hand LibKa0s-Perf a descriptor at all")
  assertTrue(type(descriptor.decorate) == "function",
    "the descriptor must carry `decorate` -- without it libs/LibKa0s/PerfPanel.lua builds the "
      .. "panel's close control itself, two-argument, and the mark is never drawn")

  local core = T.mocks.LibStub("LibKa0s-Core-1.0")
  local realMake = core.MakeCloseButton
  local calls, sawParent, sawClick, sawName = 0, nil, nil, nil
  core.MakeCloseButton = function(parent, onClick, name)
    calls = calls + 1
    sawParent, sawClick, sawName = parent, onClick, name
    return nil   -- the factory answers nil where CreateFrame is unavailable; decorate must survive it
  end
  local frame, hide = {}, function() end
  local ranOK, ranErr = pcall(descriptor.decorate, frame, {
    Show = function() end, Hide = hide, Toggle = function() end,
    TITLE_H = 22, PAD = 6, ROW_W = 200,
  })
  core.MakeCloseButton = realMake
  assertTrue(ranOK, "the descriptor's decorate raised: " .. tostring(ranErr))

  assertEqual(calls, 1, "decorate must build exactly one close control, through the library")
  assertTrue(sawParent == frame, "the panel's own frame must be carried through as the parent")
  assertTrue(sawClick == hide, "the panel's Hide must be carried through as the click handler")
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
