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
ignore = {
  "212/self",       -- unused argument self
  "212/event",      -- unused argument event
  "211/addonName",  -- mandated `local addonName, NS = ...` header; not every file uses addonName
  "431",            -- shadowing `print` with the prefixed `local print = NS.Print` is intentional
}
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
