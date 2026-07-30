-- tests/test_loadorder.lua — the load lists cannot drift from the TOC.
--
-- This repo has FOUR places that name the addon's files in load order: AbsorbTracker.toc (what the
-- client reads), tests/run.lua (the gated suite), tests/perf.lua (the allocation runner) and
-- test_perf.lua's loadDegraded() (a deliberately partial list). Only the first two are exercised by
-- `lua tests/run.lua`, so a file added to the TOC but forgotten in tests/perf.lua goes unnoticed
-- while the parity figure that runner produces is still trusted — and the LibKa0s extraction turns
-- one file addition into five.
--
-- The fix is derivation: Loader.tocFiles() reads the TOC, and both runners build their list from
-- it. These cases pin the derivation itself, and pin that nothing has quietly gone back to a
-- hand-copied list.

local T = _G.AT_TEST
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse
local mocks = T.mocks

local Loader = dofile("tests/_kit/loader.lua")

local function readFile(path)
  local f = io.open(path, "r")
  assertTrue(f ~= nil, "cannot open " .. path .. " (tests run from the repo root)")
  local body = f:read("*a")
  f:close()
  return body
end

test("loadorder: tocFiles returns every addon lua file, in TOC order", function()
  local files = Loader.tocFiles("AbsorbTracker.toc")
  assertTrue(#files > 20, "the TOC lists more than twenty lua files, got " .. #files)
  -- Anchored on the two ends rather than the whole list, so adding a file in the middle does not
  -- fail this case — the TOC-vs-runner case below is what catches a real desync.
  assertEqual(files[1], "locales/enUS.lua", "the locale table loads first")
  assertEqual(files[#files], "settings/Profiles.lua", "the settings pages load last")
end)

test("loadorder: tocFiles skips libs, directives and comments", function()
  local files = Loader.tocFiles("AbsorbTracker.toc")
  for _, p in ipairs(files) do
    assertFalse(p:lower():match("^libs/"), "a libs/ path leaked into the derived list: " .. p)
    assertFalse(p:match("^#"), "a comment leaked into the derived list: " .. p)
    assertTrue(p:match("%.lua$") ~= nil, "a non-lua entry leaked into the derived list: " .. p)
  end
end)

test("loadorder: tocFiles converts backslashes to forward slashes", function()
  local raw = readFile("AbsorbTracker.toc")
  assertTrue(raw:find("core\\Compat.lua", 1, true) ~= nil, "the TOC really does use backslashes")
  local files = Loader.tocFiles("AbsorbTracker.toc")
  for _, p in ipairs(files) do
    assertFalse(p:find("\\", 1, true), "a backslash survived into " .. p)
  end
end)

test("loadorder: every derived path exists on disk", function()
  for _, p in ipairs(Loader.tocFiles("AbsorbTracker.toc")) do
    local f = io.open(p, "r")
    assertTrue(f ~= nil, "the TOC names a file that does not exist: " .. p)
    if f then f:close() end
  end
end)

test("loadorder: the runner loaded exactly the TOC's files, in the TOC's order", function()
  -- tests/run.lua records what it actually fed the loader. Comparing against a fresh derivation
  -- catches a runner that has gone back to a literal list, or a lib entry that crept in.
  local loaded = T.loadedAddonFiles
  assertTrue(type(loaded) == "table", "tests/run.lua publishes the addon files it loaded")
  local want = Loader.tocFiles("AbsorbTracker.toc")
  assertEqual(table.concat(loaded, "\n"), table.concat(want, "\n"),
    "tests/run.lua's load list has drifted from the TOC")
end)

test("loadorder: tests/perf.lua derives its list from the TOC too", function()
  -- Asserted by reading the source, because tests/perf.lua is a separate process that this suite
  -- deliberately does not run. It is the ungated list, and therefore the one that rots.
  local src = readFile("tests/perf.lua")
  assertTrue(src:find("Loader.tocFiles", 1, true) ~= nil,
    "tests/perf.lua must derive its load list from the TOC, not carry a copy")
end)

test("loadorder: LibStub raises for a missing major without the silent flag", function()
  local ok = pcall(function() return mocks.LibStub("LibKa0s-NoSuchModule-1.0") end)
  assertFalse(ok, "a bare LibStub() on a missing major must raise, as the real LibStub does")
end)

test("loadorder: LibStub returns nil for a missing major with the silent flag", function()
  local ok, lib = pcall(function() return mocks.LibStub("LibKa0s-NoSuchModule-1.0", true) end)
  assertTrue(ok, "the silent form must not raise")
  assertEqual(lib, nil, "the silent form returns nil")
end)

test("loadorder: LibStub keeps the higher minor when a major registers twice", function()
  local a = mocks.LibStub:NewLibrary("LibKa0s-VersionProbe-1.0", 2)
  assertTrue(a ~= nil, "the first registration wins")
  local b = mocks.LibStub:NewLibrary("LibKa0s-VersionProbe-1.0", 1)
  assertEqual(b, nil, "a lower minor is refused, exactly as LibStub does")
  local c = mocks.LibStub:NewLibrary("LibKa0s-VersionProbe-1.0", 3)
  assertTrue(c ~= nil, "a higher minor is accepted")
end)
