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
-- THE THREE LIBRARY-BACKED SEAMS CALL THE KIT'S BY-NAME FORM — assertSurfaceParity(stub, major,
-- ignore), new at kit 15 and vendored by M4-01. What it changes is which keys of the live half get
-- walked: the by-name form compares only Kit.publicMembers, which drops LibStub's own MAJOR, MINOR
-- and MODULES and every `__`-prefixed key. Those are the library talking to itself across its own
-- file boundary — __bannerBand, __layoutTabs, __tabPlacement, __print — and a stub is obliged to
-- carry none of them. Under the four-argument form this file exempted twelve of them BY HAND, and
-- the list grew on every re-vendor that added an internal; libs/LibKa0s/Options.lua's own comment
-- at O.__print states the rule the kit now enforces for us.
--
-- WHERE THE LIVE HALF COMES FROM, and why it is not the obvious place. tests/run.lua registers it
-- with Kit.setSurfaceSource. It has to: all three stubs mirror an INSTANCE — what
-- `lib:New(descriptor)` returned — and not the library table LibStub answers for the same name.
-- Left to Kit.expose's auto-wiring, which reaches for the mock's LibStub, "LibKa0s-Options-1.0"
-- would resolve a four-member table (LAYOUT, New, PatchAlwaysShowScrollbar, STRINGS) and this case
-- would go red for three reasons that have nothing to do with the stub.
--
-- Core stays on the four-argument form, because it is not a major's surface at all: its two halves
-- are two blocks of one file of ours, and what they have in common is a set of NS names.
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
  -- The live half is the LibKa0s-DebugLog-1.0 instance core/DebugLogSetup.lua:72 builds, which
  -- tests/run.lua registers under that name. Read off the built instance rather than the file,
  -- which is the same list as
  --   grep -nE "^function D[:.]|^  [A-Za-z_]+ *= *function" libs/LibKa0s/DebugLog.lua
  -- without a parser.
  local NS2 = loadDegraded()
  T.assertSurfaceParity(NS2.DebugLog, "LibKa0s-DebugLog-1.0", {
    -- The four formatters and the text accessors are live-only ON PURPOSE, and core/DebugLogSetup.lua
    -- says so where the stub is written: nothing in the addon calls them (they are reached only
    -- inside the library's own Add), and hand-copying the exact line format whose seven-way drift
    -- this extraction exists to end is the duplicate testing-§8 most specifically forbids.
    --   grep -nE "DebugLog[.:](FormatPlain|FormatColored|CopyText|Text)" core modules settings
    -- returns nothing.
    "FormatPlain", "FormatColored", "CopyText", "Text",
    -- Test seams the library stamps on the instance when it BUILDS the console window (its
    -- `EnsureFrame`, in libs/LibKa0s/DebugLog.lua). They are on the live instance by the time this case
    -- runs because tests/test_debuglog.lua showed the window; a library-less build has no window to
    -- build, so their absence from the stub is the condition under test, not a gap in it. Single
    -- underscore, so Kit.publicMembers does not filter them — that exclusion is the `__` prefix.
    "_frameForTest", "_toggleClickForTest",
  })
end)

-- ── Options ────────────────────────────────────────────────────────────────────────────────────

test("parity: the Options stub carries every helper the degraded build can reach", function()
  -- The live half is the LibKa0s-Options-1.0 instance the live arm of settings/OptionsSetup.lua
  -- assigns to NS.Helpers, decorated by settings/UnitPanel.lua and settings/About.lua, and
  -- registered under that name by tests/run.lua.
  --   grep -n "Helpers\.[A-Za-z_]" core modules settings   names the addon's call sites.
  local NS2 = loadDegraded()
  T.assertSurfaceParity(NS2.Helpers, "LibKa0s-Options-1.0", {
    -- Layout scalars. A host copy of a library constant is the copy that goes stale, and every
    -- degraded reader of these sits behind an AceGUI a library-less build never gets.
    -- tests/test_optionssetup.lua pins their absence directly, as a measured fact.
    "ROW_VSPACER", "SECTION_HEADING_H", "BUTTON_PAIR_REL", "PADDING_X",
    -- The chrome band's three scalars, new at LibKa0s v1.23.0 (options-ui-§13/§14) and exactly the
    -- same class as the four above: they are lib.LAYOUT's numbers, published so a host that draws
    -- its OWN chrome can measure where the library's band ends. This addon draws one --
    --   grep -rn "CHROME_GAP\|TAB_H\|BANNER_H" core modules settings
    -- names settings/UnitPanel.lua's BANNER_H alone, which sizes the block it hands PageHeader --
    -- and it reads it from inside a render the degraded build never reaches. So a stub copy of
    -- 8 / 37 / 44 would still be three numbers with no reader and one re-vendor to go stale.
    -- tests/test_optionssetup.lua pins their absence beside the other three.
    "CHROME_GAP", "TAB_H", "BANNER_H",
    -- The panel machinery itself. settings/OptionsSetup.lua's stub answers these on NS (a single
    -- honest "the settings panel is unavailable" line) rather than on Helpers, because there is no
    -- panel for them to act on: NS.CreateOptionsPanel / NS.OpenOptionsPanel / NS.RegisterOptionsPage
    -- are the degraded seam and tests/test_optionssetup.lua exercises them there.
    "CreateOptionsPanel", "OpenOptionsPanel", "RegisterOptionsPage",
    "BuildLandingPage", "RefreshScalars", "TextRow",
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
    -- New at LibKa0s v1.24.0 (OptionsWidgets 13 / OptionsCompose 1), and exempt under the rule the
    -- RefreshPanel entry above states. The five COMPOSERS this addon does call are in the stub,
    -- because they must be for the page files to finish loading; these are the members it does not
    -- call.
    --
    --   * The published CONSTANTS. `grep -rn "FONT_FLAGS\|VISIBILITY_\|CLASS_COLOR_NOTE" core
    --     modules settings` returns nothing: the composers stamp those values onto the rows they
    --     emit, so nothing outside the library ever reads the tables themselves. A stub copy would
    --     be the same class of thing as a stub copy of lib.LAYOUT's numbers, one layer up.
    "CLASS_COLOR_NOTE", "FONT_FLAGS", "FONT_FLAGS_SORT", "VISIBILITY_SORT", "VISIBILITY_VALUES",
    --   * The banner and the secondary strip. The Appearance page's one chrome block is a
    --     PageHeader (settings/UnitPanel.lua) -- options-ui-§14 allows a page ONE block, and this
    --     one carries the Unit picker AND the two page-wide mirror controls, so the picker is built
    --     inside it and PageBanner is never called. No tab of the five holds a list of like
    --     subjects that would earn a sub-strip.
    "PageBanner", "SubTabStrip",
    -- WHAT IS NO LONGER ON THIS LIST, and why the file got shorter rather than laxer. Twelve
    -- `__`-prefixed live members used to be exempted here one at a time -- the six chrome
    -- primitives, __pages, __lastUnitCtx, __releaseSubTabs, __resetTabArtHeight, __tabArtHeight and
    -- __print. Kit.publicMembers drops the whole prefix, so the exemptions are the kit's rule now
    -- instead of this file's typing, and the next internal the library publishes needs no edit
    -- here. The library said as much where it published the last of them: O.__print's own comment
    -- calls it "internal rather than surface" and cites this filter by name.
  })
end)

-- ── Slash ──────────────────────────────────────────────────────────────────────────────────────

test("parity: the Slash stub carries every dispatcher member the addon calls", function()
  -- Both arms are the object settings/Slash.lua builds with SlashLib:New(...) — the library's
  -- instance live, the file's own stub degraded — reached through Sl.__cli, because both are
  -- otherwise file-scope locals. tests/run.lua registers the live one under the major's name.
  --   grep -nE "cli[:.][A-Za-z_]+" settings/Slash.lua   names what the addon actually calls.
  local NS2 = loadDegraded()
  assertTrue(type(NS.Slash.__cli) == "table", "the live dispatcher is published for introspection")
  assertTrue(type(NS2.Slash.__cli) == "table", "and so is the degraded one")
  T.assertSurfaceParity(NS2.Slash.__cli, "LibKa0s-Slash-1.0", {
    -- Live-only, with no call site in this addon: the grep above returns nothing for any of them.
    -- The stub deliberately renders a plain help row instead of re-implementing the library's
    -- header, its coloring or its list builder — LootHistory calls HelpHeader and its stub carries
    -- one; this addon does not, and a stub member with no caller is a copy waiting to go stale.
    "HelpHeader", "HelpRows", "BuildListLines", "CliVersion", "Text",
  })
end)
