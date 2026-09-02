std = "lua51"
max_line_length = false
codes = true
-- libs/ holds vendored code, including libs/LibKa0s/ whose upstream is the LibKa0s repo; the
-- blanket tests/ exclude likewise covers the vendored tests/_kit/. Neither is ours to lint here.
-- Under docs/ only the FROZEN evidence bundles are excluded — `lint` names exactly
-- docs/audits/ and docs/reviews/. A blanket docs/ exclude would silently drop any Lua a future
-- doc directory carries (a plan's worked example, a repro snippet) out of the gate.
exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }
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
