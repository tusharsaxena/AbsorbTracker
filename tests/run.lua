-- Headless test runner for Ka0s Absorb Tracker.
-- Run from the repo root:  lua tests/run.lua

local Loader     = dofile("tests/loader.lua")
local buildMocks = dofile("tests/wow_mock.lua")

-- --- tiny test framework (exposed to test files via _G.AT_TEST) ---
local tests = {}
local currentSuite  -- basename (no extension) of the suite file currently being dofile'd
local function test(name, fn) tests[#tests + 1] = { name = name, fn = fn, suite = currentSuite } end

local function fail(msg, level) error(msg, (level or 1) + 1) end
local function assertEqual(got, want, msg)
  if got ~= want then
    fail((msg or "assertEqual") ..
      string.format(" (expected %s, got %s)", tostring(want), tostring(got)), 1)
  end
end
local function assertTrue(c, msg) if not c then fail(msg or "assertTrue failed", 1) end end
local function assertFalse(c, msg) if c then fail(msg or "assertFalse failed", 1) end end

-- --- build the shared addon environment once (mirrors in-game load + OnInitialize) ---
local mocks = buildMocks()
local NS = {}

Loader.loadAll({
  "core/Compat.lua",
  "core/Constants.lua",
  "core/Namespace.lua",
  "core/State.lua",
  "core/Util.lua",
  "core/Data.lua",
  "core/Database.lua",
  "core/LSMPatch.lua",
  "core/DebugLog.lua",
  "core/AbsorbTracker.lua",
  "defaults/Profile.lua",
  "locales/enUS.lua",
  "modules/Bar.lua",
  "modules/Display.lua",
  "modules/Timer.lua",
  "settings/Schema.lua",
  "settings/Slash.lua",
  "settings/Panel.lua",
  "settings/Helpers.lua",
  "settings/ScrollPatch.lua",
  "settings/Widgets.lua",
  "settings/About.lua",
  "settings/General.lua",
  "settings/Bar.lua",
  "settings/Border.lua",
  "settings/Font.lua",
  "settings/Profiles.lua",
}, NS, mocks)

NS:InitDB()

_G.AT_TEST = {
  NS = NS, mocks = mocks, test = test,
  assertEqual = assertEqual, assertTrue = assertTrue, assertFalse = assertFalse,
}

-- --- load test suites (order is load-order-sensitive; keep it) ---
local SUITES = {
  "test_schema",
  "test_database",
  "test_compat",
  "test_util",
  "test_debuglog",
  "test_slash",
  "test_timer",
  "test_visibility",
}
for _, suite in ipairs(SUITES) do
  currentSuite = suite
  dofile("tests/" .. suite .. ".lua")
end
currentSuite = nil

-- --- `--list`: emit the generated docs/test-cases.md body and exit WITHOUT running ---
local function wantsList()
  for _, a in ipairs(arg or {}) do
    if a == "--list" then return true end
  end
  return false
end

if wantsList() then
  print("# Test Cases")
  print()
  print("_Generated — do not hand-edit. Regenerate with " ..
    "`lua tests/run.lua --list > docs/test-cases.md`._")
  for _, suite in ipairs(SUITES) do
    local names = {}
    for _, t in ipairs(tests) do
      if t.suite == suite then names[#names + 1] = t.name end
    end
    print()
    print(string.format("### %s.lua (%d)", suite, #names))
    print()
    for _, name in ipairs(names) do
      print("- " .. name)
    end
  end
  print()
  print("## Totals")
  print()
  print("| Suite | Count |")
  print("|-------|-------|")
  for _, suite in ipairs(SUITES) do
    local n = 0
    for _, t in ipairs(tests) do
      if t.suite == suite then n = n + 1 end
    end
    print(string.format("| %s.lua | %d |", suite, n))
  end
  print(string.format("| **Total** | **%d** |", #tests))
  os.exit(0)
end

-- --- run ---
local passed, failed = 0, 0
for _, t in ipairs(tests) do
  local ok, err = pcall(t.fn)
  if ok then
    passed = passed + 1
    print("  PASS  " .. t.name)
  else
    failed = failed + 1
    print("  FAIL  " .. t.name .. "\n          " .. tostring(err))
  end
end
print(string.format("\n%d passed, %d failed, %d total", passed, failed, passed + failed))
os.exit(failed == 0 and 0 or 1)
