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
-- both of its tooltips; and the library-absent line (slash-commands-§1), one sentence with one
-- placeholder, the full verb, which settings/Slash.lua's library-absent stub prints for each schema
-- verb it cannot run. (The minimap tooltip's left-click hint left with LibKa0s-Launcher minor 4,
-- whose hints and menu are the library's own strings.) Every key below is read by one of those
-- two -- enUS.lua carries no key nothing reads (localization-§3)
-- -- and the English-only register row is otherwise unchanged: the rest of the addon's strings are
-- still hardcoded, and a future pass wraps them here without touching call sites.

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

-- The diagnostics report (debug-logging-§14): the `diagnostics` row in `/at help` and on the About
-- page (settings/Slash.lua), and the one chat line the report prints, handed to LibKa0s-DebugLog
-- as its DIAG_WRITTEN string (core/DebugLogSetup.lua). The report body itself is English
-- diagnostic text and is not routed here.
L["Write a diagnostics report to the debug console"] =
    "Write a diagnostics report to the debug console"
L["Diagnostic report written to the debug console: %d lines. Use Copy to share it."] =
    "Diagnostic report written to the debug console: %d lines. Use Copy to share it."

-- The library-absent line: `%s` is the full verb, e.g. `/at list` (settings/Slash.lua's stub).
L["%s is unavailable: the LibKa0s library did not load."] =
    "%s is unavailable: the LibKa0s library did not load."
