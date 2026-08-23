-- tests/test_surface_parity.lua — every degradation stub carries the whole live surface.
--
-- The addon adopts four LibKa0s seams — Core, DebugLog, Options and Slash — and each of the four
-- setup files carries a degradation stub for the install where libs/LibKa0s is missing. A stub is a
-- second implementation of somebody else's surface, so it drifts the moment the library grows a
-- member the host starts calling: the live path stays green, and the degraded path raises in
-- exactly the install the stub exists for.
--
-- These cases assert the surface as a SET, in one message per seam, using the kit's
-- T.assertSurfaceParity. Two rules they follow, both from testing-§8:
--
--   * The degraded arm comes from a real load with a partial file list (tests/degraded_env.lua
--     loads the TOC and nothing from libs/), never from a hand-written stub. A hand-stub asserts
--     the test author's typing, not the shipped file.
--   * Where a member is live-only on purpose, it is named in the `ignore` set with the reason,
--     because otherwise a deliberate omission and a bug read identically.
--
-- The member lists below are not typed from memory; each case names the grep that produces it.

local T = _G.AT_TEST
local test, assertTrue = T.test, T.assertTrue
local NS = T.NS

local loadDegraded = dofile("tests/degraded_env.lua")

-- ── Core ───────────────────────────────────────────────────────────────────────────────────────

test("parity: the Core stub publishes everything core/CoreSetup.lua publishes live", function()
  -- The live and degraded halves of this seam are two blocks of ONE file, and what they have in
  -- common is the set of names they hang on NS. Derived from the source rather than typed here, so
  -- a publication added to the live half joins this case on the commit that adds it:
  --   grep -nE "^NS\.[A-Za-z_]+ *=" core/CoreSetup.lua
  local f = io.open("core/CoreSetup.lua", "r")
  assertTrue(f ~= nil, "cannot open core/CoreSetup.lua (tests run from the repo root)")
  local src = f:read("*a")
  f:close()

  local live = {}
  local n = 0
  for name in src:gmatch("\nNS%.([A-Za-z_]+)%s*=") do
    if NS[name] ~= nil then live[name] = NS[name]; n = n + 1 end
  end
  assertTrue(n >= 3, "the derivation found only " .. n .. " NS publications in core/CoreSetup.lua " ..
    "— a pattern that matches nothing passes this case without looking at anything")

  local NS2 = loadDegraded()
  T.assertSurfaceParity(live, NS2, "Core stub")
end)

-- ── DebugLog ───────────────────────────────────────────────────────────────────────────────────

test("parity: the DebugLog stub carries the whole live surface", function()
  -- Live members from: grep -nE "^function D[:.]|^  [A-Za-z_]+ *= *function" libs/LibKa0s/DebugLog.lua
  -- — but read off the built instance rather than the file, which is the same list without a parser.
  local NS2 = loadDegraded()
  T.assertSurfaceParity(NS.DebugLog, NS2.DebugLog, "DebugLog stub", {
    -- The four formatters and the text accessors are live-only ON PURPOSE, and core/DebugLogSetup.lua
    -- says so where the stub is written: nothing in the addon calls them (they are reached only
    -- inside the library's own Add), and hand-copying the exact line format whose seven-way drift
    -- this extraction exists to end is the duplicate testing-§8 most specifically forbids.
    --   grep -nE "DebugLog[.:](FormatPlain|FormatColored|CopyText|Text)" core modules settings
    -- returns nothing.
    "FormatPlain", "FormatColored", "CopyText", "Text",
    -- Test seams the library stamps on the instance when it BUILDS the console window
    -- (libs/LibKa0s/DebugLog.lua:357, :362). A library-less build has no window to build, so their
    -- absence is the condition under test, not a gap in the stub.
    "_frameForTest", "_toggleClickForTest",
  })
end)

-- ── Options ────────────────────────────────────────────────────────────────────────────────────

test("parity: the Options stub carries every helper the degraded build can reach", function()
  -- Live surface = the LibKa0s-Options instance the live path assigns to NS.Helpers, decorated by
  -- settings/UnitPanel.lua and settings/About.lua.
  --   grep -n "Helpers\.[A-Za-z_]" core modules settings   names the addon's call sites.
  local NS2 = loadDegraded()
  T.assertSurfaceParity(NS.Helpers, NS2.Helpers, "Options stub", {
    -- Layout scalars. A host copy of a library constant is the copy that goes stale, and every
    -- degraded reader of these sits behind an AceGUI a library-less build never gets.
    -- tests/test_optionssetup.lua pins their absence directly, as a measured fact.
    "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL", "PADDING_X",
    -- The panel machinery itself. settings/OptionsSetup.lua's stub answers these on NS (a single
    -- honest "the settings panel is unavailable" line) rather than on Helpers, because there is no
    -- panel for them to act on: NS.CreateOptionsPanel / NS.OpenOptionsPanel / NS.RegisterOptionsPage
    -- are the degraded seam and tests/test_optionssetup.lua exercises them there.
    "CreateOptionsPanel", "OpenOptionsPanel", "RegisterOptionsPage",
    "BuildLandingPage", "RefreshScalars", "SetRenderer", "TextRow", "__pages",
    -- The AceGUI handle the live panel stashes. There is no AceGUI on the degraded path — that is
    -- the condition, not a divergence.
    "AceGUI",
    -- New at Options minor 8 (libs/LibKa0s/Options.lua's O.RefreshPanel): the library's way for a
    -- host to say "this one page's contents changed" without touching the private dirty flag. This
    -- addon has no call site for it —
    --   grep -rn "RefreshPanel" core modules settings   returns nothing —
    -- and the Slash case below states the rule this follows: a stub member with no caller is a copy
    -- waiting to go stale. It joins the stub on the commit that gives it a caller.
    "RefreshPanel",
    -- A test seam settings/UnitPanel.lua:60 stamps on the table as it RENDERS a unit panel. The
    -- degraded build renders none, so the key is absent for the same reason AceGUI is.
    "__lastUnitCtx",
  })
end)

-- ── Slash ──────────────────────────────────────────────────────────────────────────────────────

test("parity: the Slash stub carries every dispatcher member the addon calls", function()
  -- Both arms are the object settings/Slash.lua builds with SlashLib:New(...) — the library's
  -- instance live, the file's own stub degraded — reached through Sl.__cli, because both are
  -- otherwise file-scope locals.
  --   grep -nE "cli[:.][A-Za-z_]+" settings/Slash.lua   names what the addon actually calls.
  local NS2 = loadDegraded()
  assertTrue(type(NS.Slash.__cli) == "table", "the live dispatcher is published for introspection")
  assertTrue(type(NS2.Slash.__cli) == "table", "and so is the degraded one")
  T.assertSurfaceParity(NS.Slash.__cli, NS2.Slash.__cli, "Slash stub", {
    -- Live-only, with no call site in this addon: the grep above returns nothing for any of them.
    -- The stub deliberately renders a plain help row instead of re-implementing the library's
    -- header, its coloring or its list builder — LootHistory calls HelpHeader and its stub carries
    -- one; this addon does not, and a stub member with no caller is a copy waiting to go stale.
    "HelpHeader", "HelpRows", "BuildListLines", "CliVersion", "Text",
  })
end)
