local addonName, NS = ...

-- Canonical locale. Metatable fallback returns the key itself, so English strings work
-- untranslated and a missing key never errors (Ka0s standard §8). Non-enUS files gate with
-- GetLocale() and only list overrides.
NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })

-- v1.8.0 ships English-only: user-facing strings (labels, tooltips, slash output, the
-- reset-confirm popup) are still hardcoded English. The NS.L seam is in place so a future
-- localization pass can wrap them (`NS.L["Bar Width (in px)"]`) and drop enUS overrides here
-- without touching call sites. Keys are the English source strings (localization-§2). No `local L` alias
-- until the first string is wrapped, so this file stays luacheck-clean.
