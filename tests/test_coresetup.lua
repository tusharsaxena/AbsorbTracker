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
    "core/Compat.lua", "core/Constants.lua", "core/Namespace.lua", "core/CoreSetup.lua",
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
