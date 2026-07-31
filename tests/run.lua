-- Headless test runner for Ka0s Absorb Tracker.
-- Run from the repo root:  lua tests/run.lua
--
-- The registry, the assertions, the source loader and the universal WoW-API mock all live in the
-- shared kit under tests/_kit/ (vendored from LibKa0s/testkit — see its README). What stays here is
-- what is genuinely this addon's: the load list, the lifecycle kick, and the suite list.

local Kit        = dofile("tests/_kit/framework.lua")
local Loader     = dofile("tests/_kit/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

-- --- build the shared addon environment once (mirrors in-game load + OnInitialize) ---
local mocks = buildMocks()
local NS = {}

Loader.addonName = "AbsorbTracker"

-- The vendored library files, which the TOC pulls in through libs\LibKa0s\LibKa0s.xml and so are
-- invisible to Loader.tocFiles. Listed here explicitly, in the same dependency order the XML uses.
local LIB_FILES = {
  "libs/LibKa0s/Core.lua",
  "libs/LibKa0s/DebugLog.lua",
  "libs/LibKa0s/Slash.lua",
  "libs/LibKa0s/Options.lua",
  "libs/LibKa0s/OptionsWidgets.lua",
  "libs/LibKa0s/OptionsScroll.lua",
  "libs/LibKa0s/Perf.lua",
  "libs/LibKa0s/PerfPanel.lua",
}

-- The addon's own files come from the TOC rather than a copy of it, so this runner cannot drift
-- from what the client actually loads. tests/test_loadorder.lua pins the derivation.
local ADDON_FILES = Loader.tocFiles("AbsorbTracker.toc")

Loader.loadAll(LIB_FILES, NS, mocks)
Loader.loadAll(ADDON_FILES, NS, mocks)

NS:InitDB()

-- Mirror the in-game lifecycle: OnInitialize inits the DB (above), OnEnable builds the settings
-- panel. Building it here is what stashes NS.AceGUI and runs every settings/<page>.lua builder for
-- real, so the schema → AceGUI widget layer is exercised as the client exercises it rather than
-- through hand-called fictions. The Profiles page self-skips: its builder returns nil without
-- AceDBOptions / AceConfigDialog, which are not mocked.
NS.CreateOptionsPanel()

-- Kit.expose merges `test` and the assertions in, so the key set every existing suite file reads is
-- unchanged by the move to the shared harness.
_G.AT_TEST = Kit.expose{
  NS = NS, mocks = mocks,
  -- What this runner actually fed the loader, so tests/test_loadorder.lua can compare it against a
  -- fresh reading of the TOC instead of trusting that they still match.
  loadedAddonFiles = ADDON_FILES,
}

-- --- load test suites (order is load-order-sensitive; keep it) ---
Kit.run{
  dir = "tests/",
  suites = {
    "test_loadorder",
    "test_schema",
    "test_database",
    "test_units",
    "test_compat",
    "test_coresetup",
    "test_debuglog",
    "test_slash",
    "test_timer",
    "test_perf",
    "test_visibility",
    "test_bus",
    "test_data",
    "test_display",
    "test_helpers",
    "test_slashcmds",
    "test_widgets",
  },
}
