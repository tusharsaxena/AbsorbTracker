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
-- ONE STRING IS ROUTED, and the register is not weakened by it: a recorded English-only decision is
-- not a license to leave the seam unused, and a string the addon DOES route stays routed
-- (localization-§3). Keys are the English source strings (localization-§2).
local L = NS.L

-- settings/Slash.lua's disabled-verb refusal (slash-commands-§2). It is the single line a disabled
-- addon says, and the one verb-surface string a player is guaranteed to meet at the moment they are
-- least sure what is happening -- which is the worst line in the addon to leave unreachable to a
-- translator. Listed here rather than left to the metatable fallback so a `deDE.lua` has something
-- to override; enUS.lua carries no key nothing reads (localization-§3), and this one is read on
-- every refusal.
L["Absorb Tracker is disabled \226\128\148 /at enable turns it back on"] =
    "Absorb Tracker is disabled \226\128\148 /at enable turns it back on"
