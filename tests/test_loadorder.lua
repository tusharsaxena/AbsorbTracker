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
local NS = T.NS

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

test("loadorder: core/MediaSetup.lua loads before core/Constants.lua", function()
  -- The one TOC position in this addon that is LOAD-BEARING rather than conventional.
  -- core/Constants.lua resolves C.FONT_MONO from the NS.MediaFont seam core/MediaSetup.lua
  -- publishes, at load. A Constants that loaded first would resolve it to C.FALLBACK_FONT on a
  -- perfectly healthy install and say nothing about it — the debug console would simply stop being
  -- monospace, which is the kind of regression only a screenshot catches.
  -- red under: moving MediaSetup below Constants, or dropping it out of the TOC entirely.
  local index = {}
  for i, p in ipairs(Loader.tocFiles("AbsorbTracker.toc")) do index[p:lower()] = i end

  local media = index["core/mediasetup.lua"]
  assertTrue(media ~= nil, "core/MediaSetup.lua is not in the TOC")
  local constants = index["core/constants.lua"]
  assertTrue(constants ~= nil, "core/Constants.lua is not in the TOC")
  assertTrue(media < constants,
    "core/MediaSetup.lua must load before core/Constants.lua, which reads NS.MediaFont")

  -- And the reason is written down where the next person editing the TOC will see it, not only
  -- here. A silent reorder is the failure; a comment is what makes it a deliberate one.
  local raw = readFile("AbsorbTracker.toc")
  assertTrue(raw:find("Constants.FONT_MONO is resolved from", 1, true) ~= nil,
    "the TOC line must carry the note saying its position is load-bearing")
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
  assertTrue(raw:find("core\\EnvSetup.lua", 1, true) ~= nil, "the TOC really does use backslashes")
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

test("loadorder: xmlFiles returns every LibKa0s script the vendored XML lists, in its order", function()
  -- The library half of each runner's list CANNOT be derived from the TOC: the TOC reaches it
  -- through libs\LibKa0s\LibKa0s.xml, which Loader.tocFiles deliberately skips. It used to be hand
  -- maintained in both runners, and it had already rotted once — omitting Core.lua raises nothing at
  -- all, because Perf simply refuses to register, NS.Perf falls back to its degradation stub, and
  -- tests/perf.lua goes on reporting a probeOverhead figure measured on a stub with no probe in it.
  local raw = readFile("libs/LibKa0s/LibKa0s.xml")
  local want = {}
  for f in raw:gmatch('<Script%s+file="([^"]+)"%s*/>') do
    want[#want + 1] = "libs/LibKa0s/" .. f
  end
  assertTrue(#want > 0, "the vendored LibKa0s.xml lists at least one script")

  local got = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")
  assertEqual(table.concat(got, "\n"), table.concat(want, "\n"),
    "Loader.xmlFiles must return the XML's scripts, directory-prefixed, in the XML's order")
end)

test("loadorder: the runner loaded exactly the vendored XML's library files, in its order", function()
  -- What this observes is the LIST THE LOADER WAS FED, published by tests/run.lua, against a fresh
  -- reading of the XML — not the spelling of the call that produced it. A runner that hoists the
  -- path to a local, or reaches xmlFiles through a helper, loads exactly the right files and stays
  -- green; a runner that drops or reorders a file goes red however it is written.
  local loaded = T.loadedLibFiles
  assertTrue(type(loaded) == "table", "tests/run.lua publishes the library files it loaded")
  local want = Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml")
  assertEqual(table.concat(loaded, "\n"), table.concat(want, "\n"),
    "tests/run.lua's library load list has drifted from libs/LibKa0s/LibKa0s.xml")
end)

test("loadorder: the loaded library registered — NS.Perf is the lib, not the degradation stub", function()
  -- The consequence a short list has, and the reason it goes unnoticed: a missing Perf.lua raises
  -- nothing at all. LibStub never sees the major, core/PerfSetup.lua takes its `if not lib` arm,
  -- NS.Perf becomes the four-member stub (on/suspended/Note/OnCommand), and tests/perf.lua goes on
  -- reporting a probeOverhead figure measured on a stub with no probe in it. So assert the majors
  -- the XML declares are registered, and that NS.Perf carries members only the real instance has.
  local perf = mocks.LibStub("LibKa0s-Perf-1.0", true)
  assertTrue(perf ~= nil, "libs/LibKa0s/Perf.lua must have loaded and registered its major")
  -- PerfPanel.lua does not take a major of its own — it attaches to the probe and records itself in
  -- lib.MODULES, so that table is what says the second file was in the list the loader was fed.
  assertTrue((perf.MODULES or {}).PerfPanel ~= nil,
    "libs/LibKa0s/PerfPanel.lua must have loaded and attached to the probe")
  assertTrue(type(NS.Perf.Start) == "function",
    "NS.Perf is the LibKa0s-Perf instance; the degradation stub has no Start")
  assertTrue(type(NS.Perf.BUCKET_ORDER) == "table",
    "and it built this addon's descriptor, which only the real lib:New does")
end)

test("loadorder: tests/perf.lua derives its library half from the vendored XML too", function()
  -- Source-only, and deliberately so: tests/perf.lua is a separate process this suite does not run,
  -- so there is no loaded list to observe. Kept as a lint for the ungated runner, matching the
  -- FUNCTION rather than a whole literal call, so a correct refactor that hoists the path is
  -- allowed through.
  local src = readFile("tests/perf.lua")
  assertTrue(src:find("Loader.xmlFiles", 1, true) ~= nil,
    "tests/perf.lua must derive its library load list with Loader.xmlFiles, not carry a copy of it")
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
