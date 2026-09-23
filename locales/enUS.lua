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
-- The disabled-verb refusal that settings/Slash.lua used to route through here left the addon at
-- LibKa0s v1.42.0: slash-commands-§7 makes that line the COLLECTION's wording, built by
-- LibKa0s-Slash-1.0 out of one exported format string, precisely so a player running four Ka0s
-- addons does not read four different answers to the same question. `lib.L` does not reach it
-- either, so its key went with the call site.
--
-- What IS routed is the unlocked drag handle over each bar (modules/Bar.lua): its unit label and
-- both of its tooltips. Every key below is read there -- enUS.lua carries no key nothing reads
-- (localization-§3) -- and the English-only register row is otherwise unchanged: the rest of the
-- addon's strings are still hardcoded, and a future pass wraps them here without touching call
-- sites.

local L = NS.L

-- The strip's label: the unit's display name (core/Units.lua's LABEL, which stays the identity).
L["Player"] = "Player"
L["Target"] = "Target"
L["Focus"]  = "Focus"

-- The strip's tooltip.
L["Absorb Tracker"] = "Absorb Tracker"
L["Drag to move the %s bar."] = "Drag to move the %s bar."
L["Locked. Unlock the bars to move them \226\128\148 /at unlock."] =
    "Locked. Unlock the bars to move them \226\128\148 /at unlock."

-- The help mark's tooltip.
L["%s bar"] = "%s bar"
L["Drag this handle, or the bar itself, to move the bar."] =
    "Drag this handle, or the bar itself, to move the bar."
L["Each bar keeps its own position."] = "Each bar keeps its own position."
L["Locked. Unlock the bars to drag this handle \226\128\148 /at unlock."] =
    "Locked. Unlock the bars to drag this handle \226\128\148 /at unlock."
L["Lock the bars to hide this handle \226\128\148 /at lock."] =
    "Lock the bars to hide this handle \226\128\148 /at lock."
