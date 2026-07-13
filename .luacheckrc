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
  "UnitClass", "UnitHealthMax", "UnitGetTotalAbsorbs", "AbbreviateNumbers", "C_ClassColor",
  "InCombatLockdown", "Settings", "SettingsPanel", "C_Timer", "C_AddOns", "GetAddOnMetadata",
  "hooksecurefunc", "GameTooltip", "DEFAULT_CHAT_FRAME", "UISpecialFrames",
  "StaticPopup_Show", "CreateColor", "PlaySound",
  "wipe", "strsplit", "strtrim", "tinsert", "tremove", "select",
}
globals = {
  "AbsorbTrackerDB",     -- the SavedVariables write target
  "StaticPopupDialogs",  -- the Reset-All confirm dialog registers here
}
