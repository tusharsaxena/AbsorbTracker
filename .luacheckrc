std = "lua51"
max_line_length = false
codes = true
-- libs/ holds vendored code, including libs/LibKa0s/ whose upstream is the LibKa0s repo, so it is
-- linted there and not here. tests/_kit/ is the same fact one level down: it is a byte copy of the
-- library's testkit/, linted in LibKa0s as source, and linting the copy too would report every
-- finding twice while letting the copy drift green as the original went red -- the one state the
-- re-vendor diff gate exists to make impossible. Everything else under tests/ is ours and is
-- linted (lint-§1).
-- Under docs/ only the FROZEN evidence bundles are excluded — `lint` names exactly
-- docs/audits/ and docs/reviews/. A blanket docs/ exclude would silently drop any Lua a future
-- doc directory carries (a plan's worked example, a repro snippet) out of the gate.
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }
-- NO TOP-LEVEL `ignore`, and none is coming back (lint-§1, `M4-11`). This file carried
-- `ignore = { "212/self", "212/event", "211/addonName", "431" }` until `M4c-06`. Three of those
-- four entries were narrowed to the variable already, which reads like the careful thing and is
-- not: an entry at the TOP LEVEL reaches all 54 files whatever it names, so `211/addonName`
-- silenced the header defect in every file at once, and a genuinely dead `self` written into
-- modules/Bar.lua tomorrow would have landed green under a 0/0 badge. That is the state the rule
-- calls "reads as coverage and provides none".
--
-- Removing the four lines reported THIRTY-TWO findings -- nineteen `211/addonName`, thirteen
-- `212/self` -- and nineteen of the thirty-two were not conventions at all: nineteen files opened
-- `local addonName, NS = ...` over a folder name they never read. Those are fixed at source and
-- now open `local _, NS = ...`. Seven files do read it -- Namespace, EnvSetup, CoreSetup,
-- MediaSetup, DebugLogSetup, PerfSetup and AbsorbTracker, each handing it to a vendored library
-- that cannot infer which folder it was copied into -- and those keep the name.
--
-- Two of the four entries were silencing NOTHING, which is the same fault at its purest: with all
-- four removed, this tree reported zero `212/event` and zero `431`. There is no unused `event`
-- argument in the repo (the one handler that takes the slot spells it `_`), and `431` is
-- shadowing-an-UPVALUE -- the four `local print = NS.Print` captures shadow a GLOBAL, which
-- luacheck does not warn about at all, so the entry never matched the pattern its own comment
-- described. A bare code class silencing nothing still silences the next real one.
--
-- What replaced all of it: the three `files[...]` stanzas at the foot of this file, each naming one
-- file and the variable that earns the code, plus one `-- luacheck: ignore 542` beside the single
-- line in tests/test_schema.lua that needs it. tests/test_lintconfig.lua is what keeps the blanket
-- from re-entering.
read_globals = {
  "_G", "LibStub", "CreateFrame", "UIParent", "GetTime", "format", "time",
  "UnitClass", "UnitHealthMax", "UnitGetTotalAbsorbs", "UnitExists", "AbbreviateNumbers",
  -- The class-color table, read by core/CoreSetup.lua's library-absent fallback resolver. It is
  -- RAID_CLASS_COLORS rather than C_ClassColor because that is what LibKa0s-Core-1.0 reads, and it
  -- is what every other unit frame on the player's screen is already reading (options-ui-§17).
  "RAID_CLASS_COLORS",
  "InCombatLockdown", "UnitAffectingCombat", "Settings", "C_Timer", "C_AddOns",
  "GetAddOnMetadata",
  -- ms CPU clock backing the perf brackets in core/AbsorbTracker.lua, modules/Display.lua and
  -- modules/Timer.lua. The probe they feed lives in libs/LibKa0s/Perf.lua, which this lint excludes.
  "debugprofilestop",
  "hooksecurefunc", "DEFAULT_CHAT_FRAME",
  "StaticPopup_Show", "CreateColor", "PlaySound",
  "strsplit", "strtrim", "tinsert", "tremove", "select",
}
globals = {
  "AbsorbTrackerDB",     -- the SavedVariables write target
  "AbsorbTrackerPerfDB", -- second SavedVariables global: the perf capture ring (core/PerfSetup.lua)
  "StaticPopupDialogs",  -- the Reset-All confirm dialog registers here
}

-- The harness publishes its exposed table under a per-repo global, written at tests/run.lua:59 and
-- read by every suite file. It is declared HERE rather than in the top-level `read_globals` on
-- purpose: a name granted at the top level is granted to core/ and modules/ as much as to a suite,
-- and no shipped file may ever reach for the test harness. `globals` rather than `read_globals`
-- because tests/run.lua is the writer.
files["tests/"] = {
  globals = {
    "_G.AT_TEST",
    -- The two SavedVariables tables, named as fields rather than bare because a suite that
    -- clears one is asserting on the ABSENT-saved-variable path and writes `_G.X = nil` to say
    -- so. The bare names are already writable above, for the shipped files that own them.
    "_G.AbsorbTrackerDB", "_G.AbsorbTrackerPerfDB",
  },
}

-- ---------------------------------------------------------------------------
-- The narrowed 212s (lint-§1, `M4c-06`)
-- ---------------------------------------------------------------------------
--
-- Every stanza below names ONE file, and every entry inside it names the code AND the variable, in
-- luacheck's `<code>/<variable>` form. That is the whole difference from the blanket this replaced:
-- an unused `self` in any of the other fifty-one files still reports, where under the old top-level
-- entry it did not. Measured, not assumed, and measured in BOTH directions so the claim is the one
-- the tree actually supports. Three probes report under this config and reported nothing under the
-- blanket: an unused `self` on a throwaway method in modules/Bar.lua; a fresh
-- `local addonName, NS = ...` header in the same file; a genuine shadowed upvalue.
--
-- And one probe that does NOT distinguish them, recorded because a measurement only means anything
-- if the negative is reported too: a dead argument under a DIFFERENT name in a stanza'd file --
-- `addon:OnUnitSwap(deadArg)` -- reports under both, because the old entries were already written
-- `212/self` rather than bare `212`. The old config's fault was never the name it carried, it was
-- the scope it carried it at.
--
-- Each one is a receiver a CALLING CONVENTION forces on a body that has no use for it, which is the
-- only shape that earns a stanza here. An argument this addon chose to accept and then never read
-- is dead code, and the answer to that is the delete key.

-- Seven handlers, and every one of them is entered through a receiver someone else supplies.
-- AceAddon calls `safecall(addon.OnInitialize, addon)`. AceEvent-3.0 invokes a handler registered
-- by name as `self[method](self, event, ...)`, which is OnEnterWorld, OnEnterCombat, OnLeaveCombat
-- and OnUnitSwap (registered at :92-:94 and :148/:153). OnAbsorbChanged and OnMaxHealthChanged are
-- reached with a colon from this file's own RegisterUnitEvent script at :116/:118, from
-- tests/perf.lua and from four suites. The bodies read `NS` and this file's upvalues rather than
-- the receiver, because `addon` IS `NS` -- AceAddon promoted it at :13 -- so nothing is lost by not
-- naming it, and the method form is what the registration seam requires.
files["core/AbsorbTracker.lua"] = {
  ignore = { "212/self" },
}

-- `NS:InitDB` and `NS:RunMigrations`, both published on the namespace and both reached with a colon
-- -- InitDB from core/AbsorbTracker.lua:42, tests/run.lua:32, tests/perf.lua:63 and
-- tests/test_database.lua; RunMigrations from InitDB's own tail at :22. The bodies address `NS`
-- directly because the receiver and the namespace are the same table, and a dot-declared function
-- under a colon call site is a trap left for whoever adds the first real parameter.
files["core/Database.lua"] = {
  ignore = { "212/self" },
}

-- Four receivers, and the parity gate is why they stay methods. `SlashLib:New(d)` at :410 is the
-- degraded-arm stub for LibKa0s-Slash-1.0, whose real entry point is `function lib:New(d)`
-- (libs/LibKa0s/Slash.lua:375) and which is called as `SlashLib:New({...})` at :448 either way -- a
-- stub that quietly narrows a signature is a stub that lets a caller pass here and fail in the
-- client. `Sl:LandingRows`, `Sl:OnSlash` and `Sl:Register` mirror the library instance member for
-- member, which is exactly what tests/test_surface_parity.lua asserts through `Sl.__cli`, and they
-- are reached with a colon from settings/About.lua:29, core/AbsorbTracker.lua:44 and some sixty
-- call sites across the slash suites.
files["settings/Slash.lua"] = {
  ignore = { "212/self" },
}
