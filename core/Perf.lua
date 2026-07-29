local addonName, NS = ...
NS.Perf = NS.Perf or {}
local P = NS.Perf

-- core/Perf.lua — the performance measurement probe (issue #17).
--
-- Two capabilities, both reached only through `/at debug perf` (settings/Slash.lua):
--
--   1. SELF-TIMING BUCKETS. debugprofilestop() brackets around the addon's own entry points,
--      accumulating call count / total ms / peak ms per bucket. Call sites use the idiom
--
--          local t0 = Perf.on and debugprofilestop()
--          -- ... work ...
--          if t0 then Perf.Note("paintBar", debugprofilestop() - t0) end
--
--      which costs one upvalue read, one field read and one boolean test when capture is off —
--      no call, no allocation. Same gating discipline as the §12.4 debug reads. tests/perf.lua's
--      `probeOverhead` scenario exists to keep that claim honest.
--
--   2. AN FPS SAMPLER BUCKETED BY SUSPEND STATE. While capture runs, an OnUpdate frame accumulates
--      elapsed seconds and frame counts into two arms — `active` and `suspended`. Because
--      Suspend() makes the addon inert WITHOUT a reload, one capture session yields both halves of
--      an A/B on the same fight, at the same target, with load order and shared-frame ownership
--      held fixed. That last point is the whole reason this exists: WoW's built-in Addon Profiler
--      bills a shared library's dispatch frame to whichever addon created it, so enabling and
--      disabling addons moves the blame around (see
--      docs/investigations/2026-07-14-addon-profiler-attribution/analysis.md). Suspend changes only
--      whether OUR code runs.
--
-- Records are emitted in the shared schema documented in docs/perf-runs/README.md, and persisted to
-- the AbsorbTrackerPerfDB SavedVariables global — deliberately OUTSIDE the AceDB tree, so perf data
-- never rides profile copy / reset / switch.

P.SCHEMA = 1

-- How many captures the SavedVariables ring keeps. Small on purpose: these are diagnostic
-- snapshots, not telemetry, and the file is read by hand (or by an agent) rather than aggregated.
P.RING_MAX = 10

-- Capture running? Read directly by every bracket call site, so it must stay a plain boolean field.
P.on = false

-- Addon inert? See Suspend/Resume at the bottom of this file.
P.suspended = false

-- Report order for the buckets. Membership here controls only PRESENTATION — Note() accepts any
-- key, so a new bracket that nobody added to this list still records, it just doesn't print.
--
-- These buckets NEST: repaintPass contains paintBar. Their totals must never be summed as if they
-- were disjoint, which is why FormatReport prints them in nesting order and labels the fact.
P.BUCKET_ORDER = {
    "absorbEvent",   -- addon:OnAbsorbChanged   (the event handler; publishes, paints nothing)
    "repaintPass",   -- doRepaint               (one coalesced pass over every unit)
    "paintBar",      -- NS.UpdateAbsorbBar      (per bar, inside repaintPass)
    "appearance",    -- NS.UpdateBarAppearance  (per bar)
    "visibility",    -- NS.ApplyVisibility      (per bar)
}

local buckets = {}

-- FPS accumulators, one arm per suspend state. `seconds` comes from the OnUpdate elapsed argument
-- rather than GetTime() deltas so a paused client doesn't inflate the denominator.
local fpsArms = {
    active    = { seconds = 0, frames = 0 },
    suspended = { seconds = 0, frames = 0 },
}

--- Record one bracketed measurement. `ms` is a delta of two debugprofilestop() reads.
function P.Note(key, ms)
    local b = buckets[key]
    if not b then
        b = { calls = 0, totalMs = 0, maxMs = 0 }
        buckets[key] = b
    end
    b.calls   = b.calls + 1
    b.totalMs = b.totalMs + ms
    if ms > b.maxMs then b.maxMs = ms end
end

--- Zero every counter. Called by `/at debug perf on` so each capture starts clean.
function P.Reset()
    buckets = {}
    fpsArms = {
        active    = { seconds = 0, frames = 0 },
        suspended = { seconds = 0, frames = 0 },
    }
end

-- Test seam: expose the live tables without letting callers swap them out.
function P.__buckets() return buckets end
function P.__fpsArms() return fpsArms end

-- ── JSON encoding ──────────────────────────────────────────────────────────────────────────
--
-- Hand-rolled because Lua has none built in and the addon vendors no JSON library for one
-- diagnostic path. The data is flat, finite and entirely ours, so the general-purpose hazards
-- (cycles, sparse arrays, NaN) cannot arise from BuildRecord's output.
--
-- Object keys are emitted SORTED. Lua's pairs() order is unspecified and varies between runs, so
-- unsorted output would make two otherwise-identical captures diff as different files.

local function encodeNumber(v)
    if v ~= v or v == math.huge or v == -math.huge then return "0" end   -- NaN / inf → 0
    if v == math.floor(v) and math.abs(v) < 1e15 then
        return ("%d"):format(v)
    end
    return ("%.4f"):format(v)
end

local ESCAPES = {
    ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
    ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
}

local function encodeString(v)
    local out = v:gsub('[%c"\\]', function(c)
        return ESCAPES[c] or ("\\u%04x"):format(c:byte())
    end)
    return '"' .. out .. '"'
end

local function sortedKeys(t)
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    return keys
end

--- Encode a Lua value as JSON. Tables with a non-empty array part encode as arrays; every other
--- table encodes as an object with sorted keys. Unsupported types encode as null.
function P.EncodeJSON(value)
    local t = type(value)
    if value == nil then return "null" end
    if t == "boolean" then return value and "true" or "false" end
    if t == "number" then return encodeNumber(value) end
    if t == "string" then return encodeString(value) end
    if t ~= "table" then return "null" end

    if #value > 0 then
        local parts = {}
        for i = 1, #value do parts[i] = P.EncodeJSON(value[i]) end
        return "[" .. table.concat(parts, ",") .. "]"
    end

    local parts = {}
    for _, k in ipairs(sortedKeys(value)) do
        parts[#parts + 1] = encodeString(k) .. ":" .. P.EncodeJSON(value[k])
    end
    return "{" .. table.concat(parts, ",") .. "}"
end

-- ── Record assembly ────────────────────────────────────────────────────────────────────────

-- Derive the reportable figures for one FPS arm. An arm that never ran (e.g. `suspended` in a
-- capture where the user never suspended) yields zeros rather than nil, so the record shape is
-- fixed and consumers never branch on presence.
local function arm(a)
    local seconds, frames = a.seconds, a.frames
    return {
        seconds    = seconds,
        frames     = frames,
        avgFps     = seconds > 0 and (frames / seconds) or 0,
        msPerFrame = frames > 0 and (seconds * 1000 / frames) or 0,
    }
end

-- Frame-rate limiter state at capture time.
--
-- This exists because of a real capture that silently measured nothing: both arms came back at
-- 119.4 fps / 8.37 ms per frame — 1/120 s to three decimals — because the client was capped at 120
-- and the addon's cost fit entirely inside the headroom. A capped capture can only ever report a
-- delta near zero, which is indistinguishable from a genuine null result. Record the limiter state
-- so FormatReport can say so instead of letting the number be believed.
--
-- CVar names are probed rather than asserted: the vsync CVar has been renamed across expansions, so
-- ask for several and keep whichever the client actually answers to.
local FPS_CVARS = { maxFPS = "maxFPS", maxFPSBk = "maxFPSBk", targetFPS = "targetFPS" }
local VSYNC_CVARS = { "vsync", "gxVSync", "VerticalSync" }

local function getCVar(name)
    if C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    if GetCVar then return GetCVar(name) end
    return nil
end

local function readLimits()
    local out = {}
    for key, cvar in pairs(FPS_CVARS) do
        out[key] = tonumber(getCVar(cvar)) or 0
    end
    for _, cvar in ipairs(VSYNC_CVARS) do
        local v = getCVar(cvar)
        if v ~= nil then
            out.vsync = (v == "1" or v == 1) and 1 or 0
            break
        end
    end
    out.vsync = out.vsync or 0
    return out
end

--- Did a frame-rate limit actually BIND during this capture, invalidating the FPS delta?
--- Returns false, or true plus a human reason.
---
--- Deliberately evidence-based rather than config-based. WoW keeps `maxFPS` at its last slider
--- value even when the limiter checkbox is off, so "the CVar is non-zero" is not the same as "the
--- frame rate was capped" — treating them as equivalent produced a false alarm on a client whose
--- limiters were all disabled. What actually invalidates the delta is the frame rate being PINNED
--- at a ceiling, because then the addon's cost disappears into headroom instead of into frame time.
--- So the test is: a cap is configured AND the capture ran at it.
---
--- `maxFPSBk` is recorded but never warned on: it only applies while the window is unfocused, which
--- is not a state anyone captures in.
local CAP_TOLERANCE = 0.97   -- within 3% of the configured cap counts as running at it

function P.IsFrameRateCapped(limits, fps)
    if not limits then return false end

    -- Vsync pins the frame rate to the display's refresh whenever the client can keep up, and we
    -- cannot see the refresh rate from here to test whether it bound. Flag it on configuration.
    if (limits.vsync or 0) ~= 0 then
        return true, "vsync is on"
    end

    local cap = limits.maxFPS or 0
    if cap <= 0 then return false end

    local observed = 0
    if fps then
        local a = (fps.active and fps.active.avgFps) or 0
        local s = (fps.suspended and fps.suspended.avgFps) or 0
        observed = a > s and a or s
    end
    -- Nothing sampled yet (e.g. a bare `report` before any frames): no evidence either way, so say
    -- nothing rather than cry wolf on a merely-configured value.
    if observed <= 0 then return false end

    if observed >= cap * CAP_TOLERANCE then
        return true, ("maxFPS is %d and the capture averaged %.1f fps \226\128\148 pinned at the cap")
            :format(cap, observed)
    end
    return false
end

local function interfaceVersion()
    -- Compat wraps the metadata accessor; the TOC value is a string, and the record wants a number.
    local raw = NS.Compat and NS.Compat.GetAddOnMetadata
        and NS.Compat.GetAddOnMetadata(NS.name or addonName, "Interface")
    return tonumber(raw) or 0
end

--- Assemble the capture into the shared record schema (docs/perf-runs/README.md).
function P.BuildRecord(label)
    local active, suspended = arm(fpsArms.active), arm(fpsArms.suspended)

    -- Positive delta = the addon costs this much per frame. Only meaningful when BOTH arms ran;
    -- with one arm empty its msPerFrame is 0 and the delta would read as the whole frame time, so
    -- report zero instead of a number that invites a wrong conclusion.
    local delta = 0
    if active.frames > 0 and suspended.frames > 0 then
        delta = active.msPerFrame - suspended.msPerFrame
    end

    local out = {}
    for key, b in pairs(buckets) do
        out[key] = { calls = b.calls, totalMs = b.totalMs, maxMs = b.maxMs }
    end

    return {
        schema    = P.SCHEMA,
        source    = "ingame",
        version   = NS.version or "?",
        interface = interfaceVersion(),
        timestamp = time and time() or 0,
        label     = label or "",
        buckets   = out,
        fps       = { active = active, suspended = suspended, deltaMsPerFrame = delta },
        limits    = P.limits or readLimits(),
    }
end

-- ── Persistence ────────────────────────────────────────────────────────────────────────────

--- Append a record to the AbsorbTrackerPerfDB ring, trimming the oldest past RING_MAX.
---
--- Writes the global directly rather than going through AceDB. AceDB would put this inside the
--- profile tree, where it would be copied by "copy profile", wiped by "reset profile", and would
--- swap out from under a capture on a profile switch — none of which is wanted for diagnostics.
function P.Save(record)
    -- Bare global, not _G.<name>: AbsorbTrackerPerfDB is declared in the TOC's SavedVariables list
    -- and in .luacheckrc's `globals`, so this is the same write the addon already makes for
    -- AbsorbTrackerDB. Going through _G would additionally trip luacheck's read-only-_G rule.
    local db = AbsorbTrackerPerfDB
    if type(db) ~= "table" then
        db = {}
        AbsorbTrackerPerfDB = db
    end
    db.schema = P.SCHEMA
    db.runs = db.runs or {}
    db.runs[#db.runs + 1] = record
    while #db.runs > P.RING_MAX do table.remove(db.runs, 1) end
    return db
end

-- ── Reporting ──────────────────────────────────────────────────────────────────────────────

--- One line describing the frame-limiter CVars as they were at capture start.
---
--- Printed on EVERY report, not only when a cap is detected, so a capture is self-documenting:
--- reading a saved run months later, the conditions travel with the numbers instead of having to be
--- remembered. It also makes the disagreement visible when the graphics UI and the CVars disagree —
--- a checkbox can read "off" while the CVar still holds a limiting value, and the engine obeys the
--- CVar.
local function limitsLine(limits)
    if not limits then return "limits:    (not recorded)" end
    return ("limits:    maxFPS=%s  maxFPSBk=%s  targetFPS=%s  vsync=%s")
        :format(limits.maxFPS or "?", limits.maxFPSBk or "?",
            limits.targetFPS or "?", limits.vsync or "?")
end

--- Render a record as a list of plain strings. Returns a table (not a printed side effect) so the
--- headless suite can assert on the exact lines without frames or a chat sink.
function P.FormatReport(record)
    local lines = {}
    local function add(fmt, ...)
        lines[#lines + 1] = select("#", ...) > 0 and fmt:format(...) or fmt
    end

    local f = record.fps
    add("capture: %s  (schema %d, v%s)", record.label ~= "" and record.label or "unlabelled",
        record.schema, record.version)
    add(limitsLine(record.limits))

    -- FPS arms first: this is the headline the whole harness exists to produce.
    for _, name in ipairs({ "active", "suspended" }) do
        local a = f[name]
        if a.frames > 0 then
            add("%-10s %7.1fs  %6d frames  %6.1f fps  %6.2f ms/frame",
                name .. ":", a.seconds, a.frames, a.avgFps, a.msPerFrame)
        else
            add("%-10s (not sampled)", name .. ":")
        end
    end
    local capped, why = P.IsFrameRateCapped(record.limits, f)
    if f.active.frames > 0 and f.suspended.frames > 0 then
        add("%-10s %45s%+6.2f ms/frame", "delta:", "", f.deltaMsPerFrame)
        -- A capped client absorbs the addon's cost in headroom, so the delta reads ~0 whether or
        -- not the addon is free. Say so loudly rather than let a meaningless zero be believed.
        if capped then
            add("!! DELTA IS INVALID \226\128\148 %s.", why)
            add("!! Run `/console maxFPS 0` (unticking the slider does NOT zero the CVar);")
            add("!! verify with `/dump GetCVar(\"maxFPS\")`, then capture again.")
            add("!! The bucket figures below are unaffected \226\128\148 they time our code directly.")
        end
    else
        add("delta:     (needs both arms \226\128\148 run `/at debug perf suspend` mid-capture)")
    end

    -- Buckets, in nesting order. ms/s divides by the ACTIVE seconds only: no bucket can accrue
    -- while suspended, so including the suspended arm would understate every rate.
    local secs = f.active.seconds
    add("")
    add("%-14s %8s %10s %10s %9s", "bucket", "calls", "total ms", "ms/s", "max ms")
    for _, key in ipairs(P.BUCKET_ORDER) do
        local b = record.buckets[key]
        if b then
            add("%-14s %8d %10.2f %10.3f %9.3f",
                key, b.calls, b.totalMs, secs > 0 and (b.totalMs / secs) or 0, b.maxMs)
        end
    end
    add("(buckets nest: repaintPass contains paintBar \226\128\148 do not sum)")

    return lines
end

-- ── The FPS sampler ────────────────────────────────────────────────────────────────────────

local sampler

-- Created on first capture and reused. The frame's OnUpdate script is set only while capturing —
-- an idle addon must not pay for a per-frame callback that exists purely to measure.
local function ensureSampler()
    if sampler then return sampler end
    if type(CreateFrame) ~= "function" then return nil end
    sampler = CreateFrame("Frame")
    sampler:Hide()
    return sampler
end

local function onUpdate(_, elapsed)
    local a = fpsArms[P.suspended and "suspended" or "active"]
    a.seconds = a.seconds + elapsed
    a.frames  = a.frames + 1
end

--- Begin a capture: zero the counters, arm the sampler, flip the brackets on.
function P.Start(label)
    P.Reset()
    P.label = label
    -- Snapshot the limiter state at capture START, not at report time: changing maxFPS mid-capture
    -- is exactly the kind of thing that would make a report describe conditions that no longer
    -- match the frames it counted.
    P.limits = readLimits()
    local s = ensureSampler()
    if s then
        s:SetScript("OnUpdate", onUpdate)
        s:Show()
    end
    P.on = true
end

--- End a capture and hand back the assembled record. Stops the sampler so the OnUpdate cost goes
--- away entirely rather than idling.
function P.Stop()
    P.on = false
    if sampler then
        sampler:SetScript("OnUpdate", nil)
        sampler:Hide()
    end
    return P.BuildRecord(P.label)
end

-- ── Suspend / resume ───────────────────────────────────────────────────────────────────────

--- Make the addon inert without a /reload.
---
--- Visibility is NOT enforced by hiding frames here. NS.ShouldShowBar checks P.suspended as step 0
--- of its ladder, so publishing VISIBILITY is enough and nothing — a combat transition, a target
--- swap, a settings change — can re-show a bar behind suspend's back.
function P.Suspend()
    if P.suspended then return false end
    P.suspended = true

    local addon = NS.addon
    if addon then
        local frames = addon.__unitEventFrames
        if frames then
            for _, f in pairs(frames) do f:UnregisterAllEvents() end
        end
        if addon.UnregisterEvent then
            for _, event in ipairs({
                "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
            }) do
                addon:UnregisterEvent(event)
            end
        end
    end

    if NS.CancelPendingRepaint then NS.CancelPendingRepaint() end
    if NS.bus then NS.bus:SendMessage(NS.MSG.VISIBILITY) end
    return true
end

--- Restore everything Suspend took away. SyncUnitEventFrames rebuilds the per-unit registrations
--- from the CURRENT enabled set, so a unit toggled while suspended comes back correctly.
function P.Resume()
    if not P.suspended then return false end
    P.suspended = false

    local addon = NS.addon
    if addon then
        if addon.RegisterLifecycleEvents then addon:RegisterLifecycleEvents() end
        if addon.SyncUnitEventFrames then addon:SyncUnitEventFrames() end
    end

    if NS.bus then
        NS.bus:SendMessage(NS.MSG.VISIBILITY)
        NS.bus:SendMessage(NS.MSG.APPEARANCE)
        NS.bus:SendMessage(NS.MSG.REPAINT)
    end
    return true
end
