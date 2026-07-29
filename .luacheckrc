std = "lua51"
max_line_length = false
codes = true
exclude_files = { "libs/", "docs/", "_dev/", "tests/" }
ignore = {
  "212/self",       -- unused argument self
  "212/event",      -- unused argument event
  "211/addonName",  -- mandated `local addonName, NS = ...` header; not every file uses addonName
  "431",            -- shadowing `print` with the prefixed `local print = NS.Print` is intentional
}
read_globals = {
  "_G", "LibStub", "CreateFrame", "UIParent", "GetTime", "format", "time", "date",
  "UnitClass", "UnitHealthMax", "UnitGetTotalAbsorbs", "UnitExists", "AbbreviateNumbers", "C_ClassColor",
  "InCombatLockdown", "UnitAffectingCombat", "Settings", "SettingsPanel", "C_Timer", "C_AddOns",
  "GetAddOnMetadata",
  "debugprofilestop",    -- ms CPU clock backing the perf probe's brackets (core/Perf.lua)
  -- Blizzard stopwatch, driven by the perf probe's measurement windows. Called as Lua functions
  -- rather than via "/sw play": RunMacroText is protected and would fail in combat.
  "Stopwatch_Clear", "Stopwatch_Play", "Stopwatch_Pause", "StopwatchFrame",
  -- Capture context recorded at the start of a perf run, so a saved record says who/where/what.
  "UnitName", "UnitLevel", "GetRealmName", "GetZoneText", "GetSubZoneText",
  "GetSpecialization", "GetSpecializationInfo", "IsInInstance", "IsInRaid", "IsInGroup",
  "GetNumGroupMembers",
  "hooksecurefunc", "GameTooltip", "DEFAULT_CHAT_FRAME", "UISpecialFrames",
  "StaticPopup_Show", "CreateColor", "PlaySound",
  "wipe", "strsplit", "strtrim", "tinsert", "tremove", "select",
}
globals = {
  "AbsorbTrackerDB",     -- the SavedVariables write target
  "AbsorbTrackerPerfDB", -- second SavedVariables global: the perf capture ring (core/Perf.lua)
  "StaticPopupDialogs",  -- the Reset-All confirm dialog registers here
}
