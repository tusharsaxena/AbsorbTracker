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

-- Which experiments have run to completion this session. Tracked explicitly rather than inferred
-- from frame counts, so a window that opened and closed without accumulating a frame still counts
-- as done — the step happened, whatever it caught.
local completed = { active = false, suspended = false }

-- Review actions that have been used at least once. Unlike the measurement steps these stay
-- available after use — reprinting a summary or re-dumping the JSON is free and often wanted twice —
-- so they get their own state rather than being marked `done` and disabled.
local reviewed = { report = false, dump = false }

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

--- Zero every counter. Called by `/at debug perf start` so each run begins clean.
function P.Reset()
    buckets = {}
    completed = { active = false, suspended = false }
    reviewed = { report = false, dump = false }
    fpsArms = {
        active    = { seconds = 0, frames = 0 },
        suspended = { seconds = 0, frames = 0 },
    }
end

-- Test seam: expose the live tables without letting callers swap them out.
function P.__buckets() return buckets end
function P.__fpsArms() return fpsArms end
function P.__completed() return completed end
function P.__reviewed() return reviewed end


-- Tell the step panel (core/PerfPanel.lua) that something moved. Payload-free like every other bus
-- message (architecture-§4): the panel re-reads P.Progress() when it fires.
local function publishState()
    if NS.bus and NS.MSG and NS.MSG.PERF then NS.bus:SendMessage(NS.MSG.PERF) end
end

--- Note that a review action has been run, so the panel can mark it without disabling it. Called by
--- the slash handlers, so a typed command and a click mark it identically.
function P.MarkReviewed(key)
    if reviewed[key] == nil or reviewed[key] then return false end
    reviewed[key] = true
    publishState()
    return true
end

--- The run as a list of step states, for the panel to render. Lives here rather than in the panel
--- so the progression is testable without frames, and so the panel stays a dumb renderer.
---
--- Strictly linear: exactly one step is `ready` at a time. `locked` steps are not yet reachable,
--- `busy` is armed-or-recording, `done` is finished. The slash verbs are NOT gated this way — a run
--- that cannot complete Experiment B can still be closed with `/at perf finish` from chat.
function P.Progress()
    local aBusy = (P.armed == "active") or (P.recording == "active")
    local bBusy = (P.armed == "suspended") or (P.recording == "suspended")
    local finished = (not P.run) and (completed.active or completed.suspended)

    local a = aBusy and "busy"
        or (completed.active and "done")
        or ((P.run and not bBusy) and "ready")
        or "locked"
    local b = bBusy and "busy"
        or (completed.suspended and "done")
        or ((P.run and completed.active and not aBusy) and "ready")
        or "locked"
    local fin = (finished and "done")
        or ((P.run and completed.suspended and not bBusy) and "ready")
        or "locked"
    -- `used` is green like `done` but stays clickable: these are read-only actions worth repeating.
    local function review(key)
        if not finished then return "locked" end
        return reviewed[key] and "used" or "ready"
    end

    return {
        -- Clickable whenever there is no run in flight, so the panel is the entry point rather than
        -- something you can only reach once you already knew the command. `done` while a run is
        -- active; ready again afterwards, since starting another is the obvious next thing.
        start = P.run and "done" or "ready",
        measureA = a, measureB = b, finish = fin,
        report = review("report"), dump = review("dump"),
        -- Its own state, not "ready": it sits outside the linear progression and the panel colours
        -- it separately, so it never reads as the next step to take. Only offered while there is
        -- actually a run to abandon — after `finish` the run is saved and there is nothing left to
        -- cancel, and an live-looking button that discards nothing is just a way to worry someone.
        cancel = (P.run or P.armed or P.recording) and "cancel" or "locked",
    }
end


-- ── Output ─────────────────────────────────────────────────────────────────────────────────
--
-- Perf output is deliberately NOT gated on NS.State.debug, unlike NS.Debug. That gate exists to
-- keep the addon free when idle, and a perf run is explicit user action — none of this executes
-- unless someone typed `/at perf start`. Gating it meant a user who started a run without first
-- enabling debug logging watched a console that stayed empty while a capture was plainly running.
--
-- The console form is stripped of colour escapes: the Copy window mirrors the buffer verbatim, and
-- colour codes in a log destined for analysis are noise.

local function stripColors(s)
    return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function render(fmt, ...)
    if select("#", ...) == 0 then return fmt end
    local parts = {}
    for i = 1, select("#", ...) do parts[i] = NS.SafeToString((select(i, ...))) end
    return fmt:format(unpack(parts))
end

--- Console only. Phase transitions and anything else worth having in the copied log.
function P.Log(fmt, ...)
    local msg = stripColors(render(fmt, ...))
    if NS.DebugLog and NS.DebugLog.Add then
        NS.DebugLog:Add("Perf", msg)
    else
        NS.Print(msg)
    end
end

--- Chat AND console. For the things the user must see while looking at the game rather than at the
--- console — recording starting and ending mid-combat, above all.
function P.Announce(fmt, ...)
    local msg = render(fmt, ...)
    NS.Print(msg)
    if NS.DebugLog and NS.DebugLog.Add then
        NS.DebugLog:Add("Perf", stripColors(msg))
    end
end

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
        context   = P.context,
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
    for _, line in ipairs(P.ContextLines(record.context)) do add(line) end

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
    if f.active.frames > 0 and f.suspended.frames > 0 then
        add("%-10s %45s%+6.2f ms/frame", "delta:", "", f.deltaMsPerFrame)
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

-- ── Measurement windows + the FPS sampler ──────────────────────────────────────────────────
--
-- An experiment is a sequence of explicitly-armed, COMBAT-GATED windows:
--
--     /at debug perf on          begin the experiment (samples nothing yet)
--     /at debug perf measure a   arm window A - starts the moment combat does, ends when it does
--     /at debug perf measure b   arm window B - same, with the addon suspended
--     /at debug perf off         report both windows and resume
--
-- Why windows rather than sampling continuously and splitting by suspend state (the original
-- design): continuous sampling silently folds every difference between the arms into the result.
-- Two real captures were lost to exactly that - one where the active arm was ~78% combat against a
-- suspended arm at ~100%, and one where the arms ran 72.3s and 59.2s. Both produced a delta that
-- described the environment rather than the addon. A window that opens on PLAYER combat and closes
-- when it ends measures a comparable slice by construction, and lets the user walk to the pull,
-- reset a dungeon, or wait out a respawn between arms without contaminating anything.
--
-- Combat is read from UnitAffectingCombat("player") on the sampler's own OnUpdate rather than from
-- the combat EVENTS, deliberately: P.Suspend() unregisters the addon's event frames, so window B -
-- the suspended arm - would never see PLAYER_REGEN_DISABLED fire. Polling a cheap C call on a frame
-- that only exists during an experiment sidesteps that entirely.
--
-- Window A maps to the `active` arm and window B to `suspended`, so the record schema and the delta
-- computation are unchanged. `measure b` suspends the addon and `measure a` resumes it, so the two
-- windows differ by the addon and nothing else - there is no way to forget the suspend.

-- Window token -> FPS arm.
P.EXPERIMENTS = { a = "active", b = "suspended" }

-- Reverse map, so every message names the experiment the way the user typed it.
P.LABELS = { active = "A", suspended = "B" }

P.run        = false   -- between `start` and `finish`
P.armed      = nil     -- experiment armed, waiting for combat to begin
P.recording  = nil     -- experiment currently recording

local sampler

-- Created on first experiment and reused. The OnUpdate script is attached only while an experiment
-- is running - an idle addon must not pay for a per-frame callback that exists purely to measure.
local function ensureSampler()
    if sampler then return sampler end
    if type(CreateFrame) ~= "function" then return nil end
    sampler = CreateFrame("Frame")
    sampler:Hide()
    return sampler
end

function P.__sampler() return sampler end

-- Blizzard's stopwatch, driven so the user has an on-screen timer for the window actually being
-- measured. Called as Lua functions rather than by running "/sw play" as a macro: RunMacroText is
-- protected and would taint or fail outright in combat, whereas these FrameXML helpers are plain
-- and safe to call mid-fight. Every one is existence-checked, so a client that has renamed or
-- removed them degrades to no stopwatch rather than an error mid-capture.
local function stopwatch(action)
    if action == "reset" then
        if type(Stopwatch_Clear) == "function" then Stopwatch_Clear() end
        if StopwatchFrame and StopwatchFrame.Show then StopwatchFrame:Show() end
    elseif action == "play" then
        if type(Stopwatch_Play) == "function" then Stopwatch_Play() end
    elseif action == "pause" then
        if type(Stopwatch_Pause) == "function" then Stopwatch_Pause() end
    end
end

-- Who / where / what, captured once at the start of a run. A saved capture is read weeks later, and
-- "119 fps" means nothing without knowing it was a Blood DK soloing a dummy rather than a healer in
-- a 20-man. Every lookup is existence-checked so the headless harness (and any client that renames
-- one of these) degrades to "?" rather than erroring at the start of a capture.
local function groupContext()
    local inInstance, instanceType
    if IsInInstance then inInstance, instanceType = IsInInstance() end
    local n = (GetNumGroupMembers and GetNumGroupMembers()) or 0
    local base = "solo"
    if IsInRaid and IsInRaid() then
        base = ("raid (%d)"):format(n)
    elseif IsInGroup and IsInGroup() then
        base = ("party (%d)"):format(n)
    end
    if inInstance and instanceType and instanceType ~= "none" then
        return base .. " / " .. instanceType
    end
    return base
end

function P.Context()
    local ctx = {
        character = "?", realm = "?", class = "?", spec = "?",
        level = 0, zone = "?", subZone = "", group = "solo",
    }
    if UnitName then ctx.character = UnitName("player") or "?" end
    if GetRealmName then ctx.realm = GetRealmName() or "?" end
    if UnitClass then ctx.class = (UnitClass("player")) or "?" end
    if UnitLevel then ctx.level = UnitLevel("player") or 0 end
    if GetSpecialization and GetSpecializationInfo then
        local index = GetSpecialization()
        if index then
            local _, name = GetSpecializationInfo(index)
            ctx.spec = name or "?"
        end
    end
    if GetZoneText then ctx.zone = GetZoneText() or "?" end
    if GetSubZoneText then ctx.subZone = GetSubZoneText() or "" end
    ctx.group = groupContext()
    return ctx
end

--- The context as display lines, shared by the chat ack and the report so they cannot drift.
function P.ContextLines(ctx)
    if not ctx then return {} end
    local where = ctx.zone or "?"
    if ctx.subZone and ctx.subZone ~= "" then where = where .. " \226\128\148 " .. ctx.subZone end
    return {
        ("who:       %s-%s, level %s %s %s"):format(ctx.character, ctx.realm,
            tostring(ctx.level), ctx.spec, ctx.class),
        ("where:     %s"):format(where),
        ("group:     %s"):format(ctx.group),
    }
end

local function inCombat()
    return UnitAffectingCombat and UnitAffectingCombat("player") and true or false
end

-- Both a chat line and a debug line, deliberately. These fire mid-combat, when the debug console is
-- usually not what the user is looking at — the chat line is what tells them the recording actually
-- started — while the console line is what survives into the copied log for later analysis.
local function openWindow()
    P.recording = P.armed
    P.armed = nil
    P.on = true              -- the brackets record only inside an experiment
    stopwatch("play")
    publishState()
    P.Announce("Experiment |cFFFFFF00%s|r |cff40ff40RECORDING|r \226\128\148 combat started",
        P.LABELS[P.recording] or P.recording)
end

local function closeWindow()
    local w = P.recording
    P.recording = nil
    P.on = false
    stopwatch("pause")
    if not w then return end
    completed[w] = true
    publishState()
    local a = fpsArms[w]
    P.Announce("Experiment |cFFFFFF00%s|r |cffff4040ENDED|r \226\128\148 %s, %s frames, %s fps",
        P.LABELS[w] or w, ("%.1fs"):format(a.seconds), a.frames,
        ("%.1f"):format(a.seconds > 0 and (a.frames / a.seconds) or 0))
end

local function onUpdate(_, elapsed)
    if not P.run then return end
    local combat = inCombat()

    -- Open first, then fall THROUGH to accumulate: the frame that opens a window is itself an
    -- in-combat frame and belongs in the sample. Returning after openWindow() silently dropped it,
    -- which is invisible over a 60s pull but wrong, and wrong in a way that biases both arms.
    if not P.recording then
        if not (P.armed and combat) then return end
        openWindow()
    end

    if combat then
        local a = fpsArms[P.recording]
        a.seconds = a.seconds + elapsed
        a.frames  = a.frames + 1
    else
        closeWindow()
    end
end

--- Begin an experiment. Samples nothing until a window is armed with Measure().
function P.Start(label)
    P.Reset()
    P.label = label
    P.run = true
    P.armed, P.recording = nil, nil
    P.on = false
    -- Lifecycle lines go through NS.Debug (gated on the debug flag, §12.4) so an experiment's phase
    -- boundaries land in the console timeline alongside [Combat] entered/left. Matching a window
    -- against the combat it happened in is exactly how the first capture's confound was spotted,
    -- and reconstructing that from memory afterwards is guesswork.
    P.context = P.Context()
    P.Log("run started \226\128\148 %s", P.label or "unlabelled")
    for _, line in ipairs(P.ContextLines(P.context)) do P.Log(line) end
    local s = ensureSampler()
    if s then
        s:SetScript("OnUpdate", onUpdate)
        s:Show()
    end
    publishState()
end

--- Arm a measurement window. Returns the arm name, or nil plus the offending token.
---
--- Re-arming a window that already has data ZEROES it first, so a botched pull can simply be redone
--- with the same command instead of silently averaging into the previous attempt.
function P.Measure(token)
    if not P.run then return nil, "no experiment" end
    local arm = P.EXPERIMENTS[tostring(token or ""):lower()]
    if not arm then return nil, "unknown window" end

    if P.recording then closeWindow() end

    -- The suspend state IS the independent variable, so it is set here rather than left to the
    -- user: window B with the addon still running would look like a null result.
    if arm == "suspended" then P.Suspend() else P.Resume() end

    fpsArms[arm].seconds, fpsArms[arm].frames = 0, 0
    completed[arm] = false          -- re-arming redoes the step, so it is no longer done
    P.armed = arm
    stopwatch("reset")
    P.Log("experiment %s armed (addon %s) \226\128\148 waiting for combat",
        P.LABELS[arm] or arm, arm == "suspended" and "SUSPENDED" or "active")
    publishState()
    return arm
end

--- End the experiment and hand back the assembled record. Detaches the sampler so the OnUpdate cost
--- goes away entirely rather than idling.
function P.Stop()
    if P.recording then closeWindow() end
    P.run = false
    P.armed = nil
    P.on = false
    stopwatch("pause")
    P.Log("run finished \226\128\148 A %s / %s frames, B %s / %s frames",
        ("%.1fs"):format(fpsArms.active.seconds), fpsArms.active.frames,
        ("%.1fs"):format(fpsArms.suspended.seconds), fpsArms.suspended.frames)
    if sampler then
        sampler:SetScript("OnUpdate", nil)
        sampler:Hide()
    end
    publishState()
    return P.BuildRecord(P.label)
end

--- Abandon a run. Everything measured is discarded — nothing is saved to the ring — the addon is
--- restored, and the counters are zeroed so the next `start` begins clean.
---
--- Deliberately does NOT go through closeWindow(): that marks the experiment completed and announces
--- it ENDED, which would be a lie about a run being thrown away.
function P.Cancel()
    if not (P.run or P.armed or P.recording) then return false end

    P.run, P.armed, P.recording = false, nil, nil
    P.on = false
    stopwatch("pause")
    if sampler then
        sampler:SetScript("OnUpdate", nil)
        sampler:Hide()
    end
    -- Restore before zeroing: Resume() republishes VISIBILITY/APPEARANCE/REPAINT, and the bars need
    -- to come back whatever else happens.
    if P.suspended then P.Resume() end
    P.Reset()
    P.label = nil
    P.Log("run CANCELLED \226\128\148 measurements discarded, nothing saved")
    publishState()
    return true
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
    P.Log("addon SUSPENDED \226\128\148 inert, bars hidden, events unregistered")

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
    P.Log("addon RESUMED \226\128\148 events and bars restored")

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
