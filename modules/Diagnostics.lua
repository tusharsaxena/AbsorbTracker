local _, NS = ...

-- modules/Diagnostics.lua — this addon's sections of the diagnostics report (debug-logging-§14,
-- DX-AT). `/at diagnostics` and `/at debug diagnostics` run it (settings/Slash.lua).
--
-- WHAT IS NOT HERE. The markers, the identity header (the [Init] summary, the client build, the
-- locale, the debug flag, the combat reads and the running LibKa0s minors), the per-section pcall,
-- the cap and its truncated line, the escape strip, the ungated append and the one chat line are
-- all LibKa0s-DebugLog-1.0's helper (libs/LibKa0s/DebugLogDiagnostics.lua). Writing any of them
-- here is anti-pattern #90. This file supplies SECTIONS: each is `fn(out)`, and every line goes
-- through the `out` writer the library hands it, so the cap counts it and the strip cleans it.
--
-- WHAT A SECTION NEVER DOES, and each rule is a finding if broken (STD-05, STD-12):
--
--   * it WRITES nothing. No setter, no NS.SetByPath, no bus publish, no RequestRepaint, no
--     SyncUnitEventFrames, no lifecycle hold, no timer, no Show/Hide, no OpenOptionsPanel, no
--     Clear. It reads through the read-only seams DR-AT-02 published (NS.VisibilityReason,
--     NS.LastAppliedVisibility, NS.IsRepaintPending, NS.SessionCounters) and through getters.
--   * it never COMPARES, CONVERTS or DOES ARITHMETIC on an absorb or a max-health value. In
--     restricted content UnitGetTotalAbsorbs and UnitHealthMax answer secrets. The readout is
--     gated by NS.IsConcatSafe and a secret prints as `<secret>`. Nothing reads the bar's own
--     GetValue or GetText either: those hold the same secret, handed to the C side.
--   * it never trusts a number it has not proved readable (`out:readable`) before formatting it.
--
-- WHY IT LOADS ON A LIBRARY-LESS INSTALL. With LibKa0s absent the DebugLog stub answers
-- RunDiagnostics with the library-absent line and never asks for sections, but the module still
-- loads (the TOC lists it), so nothing here may touch the library at file load.
--
-- Body lines are English diagnostic text, like trace lines (STD-13); they do not go through NS.L.

NS.Diagnostics = NS.Diagnostics or {}
local D = NS.Diagnostics

-- DX-AT's always-print rows: the six addon-wide globals and the minimap row, printed whatever
-- their value. Everything else in the schema prints only when it differs from its default.
local ALWAYS = { "enabled", "visibility", "alpha", "scale", "locked", "throttleWindow",
    "global.minimap.shown" }

-- The two events each per-unit frame registers (core/AbsorbTracker.lua's SyncUnitEventFrames).
local UNIT_EVENTS = { "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_MAXHEALTH" }

-- The libraries this addon reads through LibStub, whose absence degrades a feature rather than
-- raising. Listed so the report can say which one a broken install is missing.
local LIBRARIES = {
    "AceAddon-3.0", "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0", "AceDB-3.0", "AceGUI-3.0",
    "AceConfig-3.0", "AceDBOptions-3.0", "LibDataBroker-1.1", "LibDBIcon-1.0",
    "LibSharedMedia-3.0",
    "LibKa0s-Core-1.0", "LibKa0s-Env-1.0", "LibKa0s-Lifecycle-1.0", "LibKa0s-Bus-1.0",
    "LibKa0s-Schema-1.0", "LibKa0s-Media-1.0", "LibKa0s-Widgets-1.0", "LibKa0s-DebugLog-1.0",
    "LibKa0s-Slash-1.0", "LibKa0s-Launcher-1.0", "LibKa0s-Options-1.0", "LibKa0s-Perf-1.0",
}

-- ── helpers ────────────────────────────────────────────────────────────────────────────────

local function yesno(v) return v and "yes" or "no" end

--- A number as `%.2f`, or `?` when it cannot be read (a secret, a nil, a string).
local function num(out, v)
    if out:readable(v) then return ("%.2f"):format(v) end
    return "?"
end

--- r/g/b/a as one token, each channel through `num`.
local function rgba(out, r, g, b, a)
    return num(out, r) .. "/" .. num(out, g) .. "/" .. num(out, b) .. "/" .. num(out, a)
end

--- A value that may be a combat secret: itself when a concat can survive it, else the sentinel.
--- Never compared, never converted: IsConcatSafe is the only question asked of it.
local function secretSafe(v)
    if v == nil then return "nil" end
    if NS.IsConcatSafe and NS.IsConcatSafe(v) then return v end
    return "<secret>"
end

local function stoodDown() return NS.IsStoodDown and NS.IsStoodDown() or false end

local function holdsText()
    local holds = NS.lifecycle and NS.lifecycle:Holds() or {}
    if #holds == 0 then return "none" end
    return table.concat(holds, ", ")
end

-- ── the sections ───────────────────────────────────────────────────────────────────────────

--- The addon's own identity rows, on top of the library's header: schema (stored and code),
--- profile, the stored switch against the latch, and test mode (this addon has none: its unlocked
--- view is its preview, options-ui-§15). The nil tag is the library's own identity tag, so these
--- rows read as part of the header they extend.
local function stateSection(out)
    local db = NS.db
    local global = db and db.global
    local profileStamp = db and db.profile and db.profile.schemaVersion
    out:add(nil, "schema: stored=%s code=%s profile stamp=%s",
        global and global.schemaVersion, NS.SCHEMA_VERSION, profileStamp)
    local ok, profile = pcall(function() return db:GetCurrentProfile() end)
    out:add(nil, "profile: %s", ok and profile or "unreadable")
    out:add(nil, "enabled (stored)=%s stood down=%s", NS.GetSetting("enabled") ~= false,
        stoodDown())
    out:add(nil, "test mode: none (the unlocked view is the preview; unlocked=%s)",
        NS.GetSetting("locked") == false)
end

--- The latch's holds, the perf probe and the internal bus.
local function lifecycleSection(out)
    out:add("Life", "holds: %s", holdsText())
    local P = NS.Perf
    out:add("Life", "perf: capturing=%s run=%s armed=%s", P and P.on, P and P.run, P and P.armed)
    out:add("Life", "bus: %s", stoodDown() and "stood down (every tracked subscription released)"
        or "live")
end

--- Every schema row off its default as `path = value (default)`, the always rows whatever their
--- value, and the console toggle, a session-only row the library's walk skips.
local function settingsSection(out)
    out:nonDefaults(NS.Schema,
        function(row) return NS.GetSetting(row.path) end,
        nil,
        function(row, v) return NS.FormatSchemaValue(row, v) end,
        { always = ALWAYS })
    local console = NS.DebugLog and NS.DebugLog.IsShown and NS.DebugLog:IsShown()
    out:add("Set", "state.debugConsole = %s (session only)", console and true or false)
end

--- Per unit: its switch, the mirror, whether the unit exists, and the show ladder's answer with
--- the rung that decided it, against what ApplyVisibility last applied.
local function unitsSection(out)
    local Units = NS.Units
    for _, unit in ipairs(Units.LIST) do
        local ok, exists = pcall(UnitExists, unit)
        local existsText = "unreadable"
        if ok then existsText = exists and "true" or "false" end
        out:add("Unit", "%s: enabled=%s mirror=%s source=%s exists=%s", unit,
            Units.IsEnabled(unit), Units.IsMirrored(unit), Units.SourceUnit(unit), existsText)
        out:add("Unit", "%s: should show=%s reason=%s last applied=%s", unit,
            NS.ShouldShowBar(unit), NS.VisibilityReason(unit), NS.LastAppliedVisibility(unit))
    end
end

--- One bar frame's geometry: shown and visible, alpha against GetBarAlpha, scale and size.
local function frameShape(out, unit, bar)
    out:add("Frame", "%s: shown=%s visible=%s alpha=%s (want %s) scale=%s size=%sx%s", unit,
        bar:IsShown(), bar:IsVisible(), num(out, bar:GetAlpha()), num(out, NS.GetBarAlpha(unit)),
        num(out, bar:GetScale()), num(out, bar:GetWidth()), num(out, bar:GetHeight()))
end

--- One bar frame's anchor: the live point against the stored one, and the default-position flag.
local function framePoint(out, unit, bar)
    local point, _, relPoint, x, y = bar:GetPoint()
    local pos = NS.Units.Position(unit)
    local stored = pos and ("%s/%s %s,%s"):format(tostring(pos.point), tostring(pos.relPoint),
        num(out, pos.x), num(out, pos.y)) or "none"
    out:add("Frame", "%s: live point=%s/%s %s,%s stored=%s default position=%s", unit, point,
        relPoint, num(out, x), num(out, y), stored, yesno(pos == nil))
end

--- Per bar frame: shape, anchor, and the unlocked drag handle.
local function framesSection(out)
    for _, unit in ipairs(NS.Units.LIST) do
        local bar = NS.bars and NS.bars[unit]
        if not bar then
            out:add("Frame", "%s: shown=not built", unit)
        else
            frameShape(out, unit, bar)
            framePoint(out, unit, bar)
            local handle = bar.handle
            out:add("Frame", "%s: handle=%s", unit,
                handle and ("built shown=" .. tostring(handle:IsShown())) or "none")
        end
    end
end

--- Which rung of core/Data.lua's media getters drew `name`: `lsm` when LSM knows the name,
--- `lsm default` when LSM answered its own default for a name nobody registered (a SharedMedia pack
--- uninstalled), `fallback` when there is no LSM, or no answer, and the getter's literal drew. Asked
--- of LSM rather than read off the resolved path: the shipped border and font names resolve to the
--- very paths C.FALLBACK_BORDER and C.FALLBACK_FONT hold, so comparing paths calls every default
--- install a fallback.
local function mediaRung(kind, name)
    local lsm = NS.GetLSM and NS.GetLSM()
    if not lsm then return "fallback" end
    local ok, own = pcall(lsm.Fetch, lsm, kind, name, true)
    if ok and own then return "lsm" end
    local okDefault, default = pcall(lsm.Fetch, lsm, kind, name)
    if okDefault and default then return "lsm default" end
    return "fallback"
end

--- One media row: the stored LSM name, what it resolved to, and the rung that resolved it.
local function mediaRow(out, unit, key, kind, resolved)
    local name = NS.Units.Get(unit, key)
    out:add("Media", "%s: %s=%s -> %s rung=%s", unit, key, name, resolved, mediaRung(kind, name))
end

--- Per unit: the four media paths the bar draws with, through the mirror.
local function mediaSection(out)
    for _, unit in ipairs(NS.Units.LIST) do
        mediaRow(out, unit, "barTexture", "statusbar", NS.GetBarTexture(unit))
        mediaRow(out, unit, "bgTexture", "statusbar", NS.GetBgTexture(unit))
        mediaRow(out, unit, "border", "border", NS.GetBorder(unit))
        mediaRow(out, unit, "font", "font", NS.GetFont(unit))
    end
end

--- Per unit: the four class-color flags and the unit's class token, then the resolved RGBA of
--- each surface (options-ui-§17: the class is the RENDERING unit's, not the mirror source's).
local function colorsSection(out)
    local get = NS.Units.Get
    for _, unit in ipairs(NS.Units.LIST) do
        local ok, _, token = pcall(UnitClass, unit)
        out:add("Color", "%s: class=%s useClassColor bar=%s bg=%s border=%s text=%s", unit,
            ok and token or "unreadable", get(unit, "useClassColorBar"),
            get(unit, "useClassColorBg"), get(unit, "useClassColorBorder"),
            get(unit, "useClassColorText"))
        out:add("Color", "%s: bar=%s bg=%s border=%s text=%s", unit,
            rgba(out, NS.GetBarColor(unit)), rgba(out, NS.GetBgColor(unit)),
            rgba(out, NS.GetBorderColor(unit)), rgba(out, NS.GetFontColor(unit)))
    end
end

--- Per unit: the absorb and max-health readout, gated by IsConcatSafe. No `or 0`, no compare, no
--- AbbreviateNumbers: a secret is passed nowhere but IsConcatSafe.
local function absorbSection(out)
    for _, unit in ipairs(NS.Units.LIST) do
        out:add("Absorb", "%s: absorb=%s max health=%s", unit,
            secretSafe(UnitGetTotalAbsorbs(unit)), secretSafe(UnitHealthMax(unit)))
    end
end

--- The AceEvent events this addon holds right now, read off AceEvent's own callback registry.
--- `pairs` over the registry, never an index: CallbackHandler's events table builds an empty
--- entry for any name it is indexed with, and the report writes nothing.
local function aceEventNames()
    local AceEvent = LibStub and LibStub("AceEvent-3.0", true)
    local registry = AceEvent and AceEvent.events and AceEvent.events.events
    local names = {}
    if type(registry) ~= "table" then return names end
    for name, owners in pairs(registry) do
        if type(owners) == "table" and owners[NS.addon] ~= nil then names[#names + 1] = name end
    end
    table.sort(names)
    return names
end

--- One unit's private RegisterUnitEvent frame and what it is registered for.
local function unitFrameEvents(out, unit, frames)
    local f = frames and frames[unit]
    if not f then return out:add("Events", "%s frame: not built", unit) end
    local parts = {}
    for i, event in ipairs(UNIT_EVENTS) do
        parts[i] = event .. "=" .. yesno(f:IsEventRegistered(event))
    end
    out:add("Events", "%s frame: %s", unit, table.concat(parts, " "))
end

--- The registration set: stood down, it was released and the section says so; otherwise the
--- AceEvent set and each unit frame's events.
local function eventsSection(out)
    if stoodDown() then
        return out:add("Events", "stood down: every registration released (holds: %s)",
            holdsText())
    end
    out:joined("Events", "AceEvent registered:", aceEventNames())
    local frames = NS.addon and NS.addon.__unitEventFrames
    for _, unit in ipairs(NS.Units.LIST) do unitFrameEvents(out, unit, frames) end
end

--- `/at debug events`, folded in: every event name the client refused this session.
local function rejectedSection(out)
    out:list("Events", "rejected events:", NS.State and NS.State.rejectedEvents or {})
end

--- The coalescing throttle and the `/at debug hold` value hold.
local function repaintSection(out)
    local pending = stoodDown() and "stood down" or tostring(NS.IsRepaintPending())
    out:add("Repaint", "pending=%s throttle window=%s", pending, num(out, NS.GetThrottleWindow()))
    local untilAt, now = NS.testHoldUntil, GetTime()
    local left = "none"
    if out:readable(untilAt) and out:readable(now) and untilAt > now then
        left = ("%.1f s"):format(untilAt - now)
    end
    out:add("Repaint", "hold remaining=%s", left)
end

--- The [Combat] rollup's counters, which count only while debug is on.
local function countersSection(out)
    local c = NS.SessionCounters()
    out:add("Counters", "since last combat start (debug on only): absorb events=%s repaints=%s "
        .. "last absorb=%s", c.absorbEvents, c.repaints, secretSafe(c.lastAbsorb))
end

--- The settings panel, the launcher, and any library missing from this install.
local function uiSection(out)
    local panel = _G.SettingsPanel
    local open = type(panel) == "table" and type(panel.IsShown) == "function" and panel:IsShown()
    out:add("UI", "settings panel open=%s", open and true or false)
    local L = NS.Launcher
    out:add("UI", "launcher: registered=%s shown=%s", L and L:IsRegistered(), L and L:IsShown())
    local missing = {}
    for _, major in ipairs(LIBRARIES) do
        if not (LibStub and LibStub(major, true)) then missing[#missing + 1] = major end
    end
    out:joined("UI", "libraries missing:", missing)
end

local SECTIONS = {
    { "state",     stateSection },
    { "lifecycle", lifecycleSection },
    { "settings",  settingsSection },
    { "units",     unitsSection },
    { "frames",    framesSection },
    { "media",     mediaSection },
    { "colors",    colorsSection },
    { "absorb",    absorbSection },
    { "events",    eventsSection },
    { "rejected",  rejectedSection },
    { "repaint",   repaintSection },
    { "counters",  countersSection },
    { "ui",        uiSection },
}

--- The section list the DebugLog descriptor hands the library (core/DebugLogSetup.lua), in report
--- order. A fresh array each call, so nothing the library does to it reaches the next report.
function D.Sections()
    local out = {}
    for i, entry in ipairs(SECTIONS) do out[i] = { entry[1], entry[2] } end
    return out
end
