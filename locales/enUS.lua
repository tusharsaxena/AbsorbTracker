local _, NS = ...

-- Canonical locale. Metatable fallback returns the key itself, so English strings work
-- untranslated and a missing key never errors (localization-§1). Non-enUS files gate with
-- GetLocale() and only list overrides.
NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })

-- This addon ships English-only, and that decision is a ratified row in docs/ARCHITECTURE.md's
-- Documented deviations register (localization-§1), with the re-check trigger the standard asks for:
-- the first non-English locale file added to this folder. Almost every user-facing string -- labels,
-- tooltips, slash output, the reset-confirm popup -- is therefore still hardcoded English, and the
-- seam is here so a future pass can wrap them (`NS.L["Bar Width (in px)"]`) without touching call
-- sites.
--
-- NO KEY IS LISTED HERE, and that is the register holding rather than weakening. The one string
-- this addon used to route was settings/Slash.lua's disabled-verb refusal, and it left the addon
-- entirely at LibKa0s v1.42.0: slash-commands-§7 makes that line the COLLECTION's wording, built by
-- LibKa0s-Slash-1.0 out of one exported format string, precisely so a player running four Ka0s
-- addons does not read four different answers to the same question. `lib.L` does not reach it
-- either. enUS.lua carries no key nothing reads (localization-§3), so the key went with the call
-- site.
--
-- The seam above is untouched and still the place a future pass wraps `NS.L["Bar Width (in px)"]`
-- without editing call sites; what is gone is a dead entry, not the mechanism.
