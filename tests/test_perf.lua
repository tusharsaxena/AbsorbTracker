-- tests/test_perf.lua — the performance probe (core/Perf.lua, issue #17).
--
-- Covers the pure logic: bucket accounting, JSON encoding, record assembly, report formatting,
-- the SavedVariables ring, and the suspend/resume state machine. The timing values themselves are
-- driven off the mock's settable debugprofilestop counter, so every assertion here is exact — a
-- wall-clock reading would make these flaky for no benefit.

local T = _G.AT_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local P = NS.Perf

-- Drain the repaint queue. Resume() republishes REPAINT, which arms a coalescing timer; left
-- armed, `pending` in modules/Timer.lua stays set for the rest of the PROCESS and every later
-- suite's RequestRepaint quietly coalesces into a pass that never fires. That is invisible here
-- and shows up as unrelated failures three suites away, so every path that resumes drains first.
local function settle()
  NS.CancelPendingRepaint()
  for i = #mocks.__timers, 1, -1 do mocks.__timers[i] = nil end
end

-- Resume and drain, for the tests that don't care about the return value.
local function resume()
  P.Resume()
  settle()
end

-- Every test starts from a known probe state. Suspend in particular leaks across tests if left
-- set, and would silently make every later visibility assertion in the whole suite return false.
local function reset()
  P.on = false
  P.run = false
  P.armed, P.recording = nil, nil
  P.suspended = false
  P.label = nil
  P.Reset()
  settle()
  mocks.__profileMs = 0
  _G.AbsorbTrackerPerfDB = nil
end

-- ── bucket accounting ───────────────────────────────────────────────────────────────────────

test("perf: Note accumulates calls, total and max", function()
  reset()
  P.Note("paintBar", 2)
  P.Note("paintBar", 5)
  P.Note("paintBar", 1)
  local b = P.__buckets().paintBar
  assertEqual(b.calls, 3, "calls")
  assertEqual(b.totalMs, 8, "totalMs")
  assertEqual(b.maxMs, 5, "maxMs is the peak, not the last")
end)

test("perf: Note tracks unrelated buckets independently", function()
  reset()
  P.Note("paintBar", 2)
  P.Note("repaintPass", 7)
  assertEqual(P.__buckets().paintBar.calls, 1, "paintBar")
  assertEqual(P.__buckets().repaintPass.totalMs, 7, "repaintPass")
end)

test("perf: Reset clears every bucket and both fps arms", function()
  reset()
  P.Note("paintBar", 2)
  P.__fpsArms().active.frames = 99
  P.Reset()
  assertEqual(next(P.__buckets()), nil, "buckets emptied")
  assertEqual(P.__fpsArms().active.frames, 0, "active arm zeroed")
  assertEqual(P.__fpsArms().suspended.frames, 0, "suspended arm zeroed")
end)

-- ── JSON encoding ───────────────────────────────────────────────────────────────────────────

test("perf: EncodeJSON emits object keys in sorted order", function()
  -- Sorted output is what makes two captures diffable; pairs() order is unspecified.
  assertEqual(P.EncodeJSON({ b = 1, a = 2, c = 3 }), '{"a":2,"b":1,"c":3}')
end)

test("perf: EncodeJSON renders integral numbers without a decimal point", function()
  assertEqual(P.EncodeJSON({ n = 42 }), '{"n":42}')
end)

test("perf: EncodeJSON renders fractional numbers to four places", function()
  assertEqual(P.EncodeJSON({ n = 1.5 }), '{"n":1.5000}')
end)

test("perf: EncodeJSON escapes quotes, backslashes and control characters", function()
  assertEqual(P.EncodeJSON('a"b\\c\nd'), '"a\\"b\\\\c\\nd"')
end)

test("perf: EncodeJSON emits arrays for sequence tables", function()
  assertEqual(P.EncodeJSON({ 1, 2, 3 }), "[1,2,3]")
end)

test("perf: EncodeJSON emits an empty table as an object", function()
  assertEqual(P.EncodeJSON({}), "{}")
end)

test("perf: EncodeJSON coerces non-finite numbers rather than emitting invalid JSON", function()
  -- inf/NaN have no JSON representation; emitting them raw would produce a file no parser reads.
  assertEqual(P.EncodeJSON({ n = math.huge }), '{"n":0}')
end)

test("perf: EncodeJSON round-trips a full record without error", function()
  reset()
  P.Note("paintBar", 1.25)
  local json = P.EncodeJSON(P.BuildRecord("x"))
  assertTrue(json:find('"schema":1', 1, true) ~= nil, "carries the schema stamp")
  assertTrue(json:find('"source":"ingame"', 1, true) ~= nil, "carries the source")
  assertTrue(json:find('"paintBar"', 1, true) ~= nil, "carries the bucket")
end)

-- ── record assembly ─────────────────────────────────────────────────────────────────────────

test("perf: BuildRecord carries schema, source and label", function()
  reset()
  local r = P.BuildRecord("dummy run")
  assertEqual(r.schema, P.SCHEMA, "schema")
  assertEqual(r.source, "ingame", "source")
  assertEqual(r.label, "dummy run", "label")
end)

test("perf: BuildRecord derives avgFps and msPerFrame from the arms", function()
  reset()
  local a = P.__fpsArms().active
  a.seconds, a.frames = 10, 800
  local r = P.BuildRecord()
  assertEqual(r.fps.active.avgFps, 80, "800 frames over 10s is 80 fps")
  assertEqual(r.fps.active.msPerFrame, 12.5, "and 12.5 ms per frame")
end)

test("perf: BuildRecord reports zero delta when only one arm was sampled", function()
  -- With no B arm, suspended.msPerFrame is 0 and a naive subtraction would report the ENTIRE
  -- frame time as the addon's cost — a number that reads as a catastrophic finding.
  reset()
  local a = P.__fpsArms().active
  a.seconds, a.frames = 10, 800
  assertEqual(P.BuildRecord().fps.deltaMsPerFrame, 0, "no delta without both arms")
end)

test("perf: BuildRecord computes the delta when both arms were sampled", function()
  reset()
  local arms = P.__fpsArms()
  arms.active.seconds, arms.active.frames = 10, 800        -- 12.5 ms/frame
  arms.suspended.seconds, arms.suspended.frames = 10, 1000 -- 10.0 ms/frame
  assertEqual(P.BuildRecord().fps.deltaMsPerFrame, 2.5, "active costs 2.5 ms/frame more")
end)

test("perf: BuildRecord snapshots buckets rather than aliasing them", function()
  reset()
  P.Note("paintBar", 3)
  local r = P.BuildRecord()
  P.Note("paintBar", 3)
  assertEqual(r.buckets.paintBar.calls, 1, "the record is a snapshot, not a live view")
end)

-- ── the SavedVariables ring ─────────────────────────────────────────────────────────────────

test("perf: Save creates the perf global and appends the run", function()
  reset()
  P.Save(P.BuildRecord("first"))
  local db = _G.AbsorbTrackerPerfDB
  assertEqual(type(db), "table", "global created")
  assertEqual(#db.runs, 1, "one run stored")
  assertEqual(db.runs[1].label, "first", "the run we saved")
end)

test("perf: Save stamps the schema on the store", function()
  reset()
  P.Save(P.BuildRecord())
  assertEqual(_G.AbsorbTrackerPerfDB.schema, P.SCHEMA, "store is self-describing")
end)

test("perf: Save trims the ring to RING_MAX, dropping the oldest", function()
  reset()
  for i = 1, P.RING_MAX + 3 do P.Save(P.BuildRecord("run" .. i)) end
  local runs = _G.AbsorbTrackerPerfDB.runs
  assertEqual(#runs, P.RING_MAX, "capped at RING_MAX")
  assertEqual(runs[1].label, "run4", "oldest three dropped")
  assertEqual(runs[#runs].label, "run" .. (P.RING_MAX + 3), "newest kept")
end)

test("perf: Save is outside the AceDB tree", function()
  -- The whole point of the separate global: a profile reset must not touch captures.
  reset()
  P.Save(P.BuildRecord())
  assertEqual(NS.db.profile.runs, nil, "nothing landed in the profile")
  assertEqual(NS.db.global.runs, nil, "nothing landed in AceDB global either")
end)

-- ── report formatting ───────────────────────────────────────────────────────────────────────

test("perf: FormatReport marks an unsampled arm rather than printing zeros", function()
  reset()
  local lines = table.concat(P.FormatReport(P.BuildRecord()), "\n")
  assertTrue(lines:find("(not sampled)", 1, true) ~= nil, "says so explicitly")
end)

test("perf: FormatReport prints both arms and the delta when both ran", function()
  reset()
  local arms = P.__fpsArms()
  arms.active.seconds, arms.active.frames = 10, 800
  arms.suspended.seconds, arms.suspended.frames = 10, 1000
  local lines = table.concat(P.FormatReport(P.BuildRecord()), "\n")
  assertTrue(lines:find("active:", 1, true) ~= nil, "active arm")
  assertTrue(lines:find("suspended:", 1, true) ~= nil, "suspended arm")
  assertTrue(lines:find("+2.50 ms/frame", 1, true) ~= nil, "signed delta")
end)

test("perf: FormatReport derives ms/s from the active seconds only", function()
  reset()
  local arms = P.__fpsArms()
  arms.active.seconds, arms.active.frames = 10, 800
  arms.suspended.seconds, arms.suspended.frames = 90, 9000  -- must not dilute the rate
  P.Note("paintBar", 20)
  local lines = table.concat(P.FormatReport(P.BuildRecord()), "\n")
  assertTrue(lines:find("2.000", 1, true) ~= nil, "20ms over 10 active seconds is 2 ms/s")
end)

test("perf: FormatReport warns that buckets nest", function()
  reset()
  local lines = table.concat(P.FormatReport(P.BuildRecord()), "\n")
  assertTrue(lines:find("do not sum", 1, true) ~= nil, "totals must not be added naively")
end)

test("perf: FormatReport omits buckets that never fired", function()
  reset()
  P.Note("paintBar", 1)
  local lines = table.concat(P.FormatReport(P.BuildRecord()), "\n")
  assertTrue(lines:find("paintBar", 1, true) ~= nil, "fired bucket present")
  assertEqual(lines:find("appearance", 1, true), nil, "unfired bucket absent")
end)

-- ── the brackets ────────────────────────────────────────────────────────────────────────────

test("perf: brackets record nothing while capture is off", function()
  reset()
  mocks.__profileMs = 100
  NS.UpdateAbsorbBar("player")
  assertEqual(next(P.__buckets()), nil, "no bucket created when off")
end)

test("perf: paintBar records when capture is on", function()
  reset()
  NS.SetByPath("units.player.enabled", true)
  P.on = true
  NS.UpdateAbsorbBar("player")
  P.on = false
  assertTrue(P.__buckets().paintBar ~= nil, "bucket created")
  assertEqual(P.__buckets().paintBar.calls, 1, "one paint")
end)

test("perf: paintBar does not count a bar that early-outed", function()
  -- ms/call is only meaningful if the call count excludes skipped bars.
  reset()
  NS.SetByPath("units.player.enabled", false)
  P.on = true
  NS.UpdateAbsorbBar("player")
  P.on = false
  NS.SetByPath("units.player.enabled", true)
  assertEqual(P.__buckets().paintBar, nil, "hidden bar is not a paint")
end)

test("perf: repaintPass records one note per coalesced pass", function()
  reset()
  NS.SetByPath("units.player.enabled", true)
  P.on = true
  NS.RequestRepaint()
  NS.RequestRepaint()
  NS.RequestRepaint()
  mocks.__fireTimers()
  P.on = false
  assertEqual(P.__buckets().repaintPass.calls, 1, "three requests coalesce into one pass")
end)

-- ── suspend / resume ────────────────────────────────────────────────────────────────────────

test("perf: suspend hides bars through the visibility ladder", function()
  reset()
  NS.SetByPath("units.player.enabled", true)
  assertTrue(NS.ShouldShowBar("player"), "shown before suspend")
  P.Suspend()
  assertFalse(NS.ShouldShowBar("player"), "hidden while suspended")
  resume()
  assertTrue(NS.ShouldShowBar("player"), "shown again after resume")
end)

test("perf: suspend returns false when already suspended", function()
  reset()
  assertTrue(P.Suspend(), "first call suspends")
  assertFalse(P.Suspend(), "second is a no-op")
  resume()
end)

test("perf: resume returns false when not suspended", function()
  reset()
  assertFalse(P.Resume(), "nothing to resume")
end)

test("perf: suspend unregisters every unit event frame", function()
  reset()
  NS.SetByPath("units.player.enabled", true)
  NS.addon:SyncUnitEventFrames()
  local f = NS.addon.__unitEventFrames.player
  assertTrue(f.__unitEvents["UNIT_ABSORB_AMOUNT_CHANGED"] ~= nil, "registered before")
  P.Suspend()
  assertEqual(f.__unitEvents["UNIT_ABSORB_AMOUNT_CHANGED"], nil, "gone while suspended")
  resume()
  assertTrue(f.__unitEvents["UNIT_ABSORB_AMOUNT_CHANGED"] ~= nil, "restored on resume")
end)

test("perf: suspend unregisters the lifecycle events", function()
  reset()
  NS.addon:RegisterLifecycleEvents()
  P.Suspend()
  assertEqual(NS.addon.__events["PLAYER_REGEN_DISABLED"], nil, "combat event dropped")
  resume()
  assertTrue(NS.addon.__events["PLAYER_REGEN_DISABLED"] ~= nil, "restored on resume")
end)

test("perf: resume restores the lifecycle set from one definition", function()
  -- Guards against Resume growing a hand-copied event list that drifts from OnEnable's.
  reset()
  P.Suspend()
  resume()
  for _, event in ipairs({
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
  }) do
    assertTrue(NS.addon.__events[event] ~= nil, event .. " restored")
  end
end)

test("perf: RequestRepaint no-ops while suspended", function()
  reset()
  NS.SetByPath("units.player.enabled", true)
  P.Suspend()
  local before = #mocks.__timers
  NS.RequestRepaint()
  assertEqual(#mocks.__timers, before, "no timer armed while inert")
  resume()
end)

test("perf: CancelPendingRepaint drops a queued pass", function()
  reset()
  NS.RequestRepaint()
  assertTrue(NS.CancelPendingRepaint(), "there was one to cancel")
  assertFalse(NS.CancelPendingRepaint(), "and now there is not")
  mocks.__fireTimers()
end)

test("perf: suspend leaves no repaint queued behind it", function()
  -- A pass armed just before suspending would otherwise land inside the suspended measurement arm
  -- and put work into a window that is supposed to contain none.
  reset()
  NS.SetByPath("units.player.enabled", true)
  NS.RequestRepaint()
  P.Suspend()
  assertFalse(NS.CancelPendingRepaint(), "suspend already cleared it")
  resume()
end)

test("perf: the suspended state is session-only, never persisted", function()
  reset()
  P.Suspend()
  assertEqual(NS.db.profile.suspended, nil, "not in the profile")
  assertEqual(NS.db.global.suspended, nil, "not in AceDB global")
  resume()
end)


-- ── lifecycle logging ───────────────────────────────────────────────────────────────────────
--
-- The capture's phase boundaries belong in the console timeline next to [Combat] entered/left.
-- Matching a suspend against the combat it happened in is exactly how the first capture's
-- unequal-combat confound was spotted; reconstructing it from memory afterwards is guesswork.

-- Clear the console, run `fn`, and return everything it logged.
--
-- Clearing rather than remembering an offset is deliberate: D.buffer is capped at MAX_BUFFER (500)
-- and drops from the front once full, so any assertion phrased as "#buffer grew" silently stops
-- working the moment the suite has produced 500 lines — and fails in a completely unrelated test.
local function captureDebugLines(fn)
  NS.DebugLog:Clear()
  local wasOn = NS.State.debug
  NS.State.debug = true
  local ok, err = pcall(fn)
  NS.State.debug = wasOn
  if not ok then error(err) end
  return table.concat(NS.DebugLog.buffer, "\n")
end

test("perf: starting an experiment logs it", function()
  reset()
  local lines = captureDebugLines(function() P.Start("solo") end)
  P.on = false
  assertTrue(lines:find("[Perf]", 1, true) ~= nil, "tagged [Perf]: " .. lines)
  assertTrue(lines:find("run started", 1, true) ~= nil, "says what happened")
  assertTrue(lines:find("solo", 1, true) ~= nil, "and which capture: " .. lines)
end)

test("perf: stopping an experiment logs both arm durations", function()
  reset()
  local arms = P.__fpsArms()
  arms.active.seconds, arms.active.frames = 60, 7000
  arms.suspended.seconds, arms.suspended.frames = 30, 3500
  local lines = captureDebugLines(function() P.Stop() end)
  assertTrue(lines:find("run finished", 1, true) ~= nil, "logged: " .. lines)
  assertTrue(lines:find("60.0s", 1, true) ~= nil, "active arm duration")
  assertTrue(lines:find("30.0s", 1, true) ~= nil, "suspended arm duration")
end)

test("perf: suspend and resume are logged", function()
  reset()
  local lines = captureDebugLines(function() P.Suspend() end)
  assertTrue(lines:find("SUSPENDED", 1, true) ~= nil, "suspend logged: " .. lines)
  lines = captureDebugLines(function() P.Resume() end)
  settle()
  assertTrue(lines:find("RESUMED", 1, true) ~= nil, "resume logged: " .. lines)
end)

test("perf: a no-op suspend or resume logs nothing", function()
  -- The line marks a real state transition; logging a rejected call would put phantom boundaries
  -- in the timeline that never happened.
  reset()
  P.Suspend()
  local lines = captureDebugLines(function() P.Suspend() end)
  assertEqual(lines, "", "second suspend is silent")
  lines = captureDebugLines(function() P.Resume() end)
  settle()
  assertTrue(lines ~= "", "the real resume still logs")
  lines = captureDebugLines(function() P.Resume() end)
  assertEqual(lines, "", "second resume is silent")
end)

test("perf: lifecycle lines appear even with debug logging OFF", function()
  -- Perf output is deliberately ungated. The debug gate exists to keep the addon free when idle,
  -- and a run only happens because someone typed `/at perf start` — gating it meant watching an
  -- empty console while a capture was plainly running.
  reset()
  local wasOn = NS.State.debug
  NS.State.debug = false
  NS.DebugLog:Clear()
  P.Start("quiet")
  P.Suspend()
  P.Resume()
  settle()
  P.Stop()
  NS.State.debug = wasOn
  assertTrue(#NS.DebugLog.buffer > 0, "the run was logged regardless of the debug flag")
end)

test("perf: nothing is logged when no run is happening", function()
  -- Ungated does not mean chatty: the lines only exist inside a run.
  reset()
  NS.DebugLog:Clear()
  NS.UpdateAbsorbBar("player")
  NS.RequestRepaint()
  settle()
  assertEqual(#NS.DebugLog.buffer, 0, "an idle addon writes nothing")
end)

-- ── combat-gated measurement windows ────────────────────────────────────────────────────────
--
-- The A/B is a pair of explicitly-armed windows that open when PLAYER combat starts and close when
-- it ends, rather than continuous sampling split by suspend state. Continuous sampling folded every
-- environmental difference into the result: two real captures were lost that way, one with the
-- active arm at ~78% combat against a suspended arm at ~100%, one with arms of 72.3s and 59.2s.

-- Drive the sampler's OnUpdate the way the client would.
local function tick(seconds, combat)
  local saved = mocks.UnitAffectingCombat
  mocks.UnitAffectingCombat = function() return combat and true or false end
  local s = P.__sampler()
  s:__fire("OnUpdate", seconds)
  mocks.UnitAffectingCombat = saved
end

local function startExperiment()
  reset()
  P.Start("test")
end

-- End an experiment AND put the probe fully back. P.Stop() deliberately leaves the suspend state
-- alone (the slash `off` verb owns resuming), so a test that armed window B would otherwise leak
-- P.suspended = true into every later suite and silently fail their visibility assertions.
local function finish()
  P.Stop()
  if P.suspended then P.Resume() end
  settle()
end

test("perf: an armed window samples nothing until combat begins", function()
  startExperiment()
  P.Measure("a")
  tick(1.0, false)
  tick(1.0, false)
  assertEqual(P.__fpsArms().active.frames, 0, "out of combat is not measured")
  assertTrue(P.armed ~= nil, "still waiting")
  assertFalse(P.on, "and the brackets stay closed")
  finish()
end)

test("perf: a window opens on combat and accumulates", function()
  startExperiment()
  P.Measure("a")
  tick(0.5, true)
  tick(0.5, true)
  assertEqual(P.recording, "active", "window open")
  assertEqual(P.__fpsArms().active.frames, 2, "two frames")
  assertEqual(P.__fpsArms().active.seconds, 1, "one second")
  assertTrue(P.on, "brackets record inside a window")
  finish()
end)

test("perf: a window closes when combat ends and stops accumulating", function()
  startExperiment()
  P.Measure("a")
  tick(0.5, true)
  tick(0.5, false)             -- combat ended: closes the window
  tick(9.0, false)             -- and nothing lands afterwards
  tick(9.0, true)              -- not even a later, unrelated fight
  assertEqual(P.recording, nil, "window closed")
  assertEqual(P.__fpsArms().active.frames, 1, "only the in-combat frame counted")
  assertFalse(P.on, "brackets closed with the window")
  finish()
end)

test("perf: the walk between windows is never measured", function()
  -- The whole point: reset a dungeon, run back, wait for respawns - none of it contaminates a run.
  startExperiment()
  P.Measure("a")
  tick(1.0, true)
  tick(1.0, false)
  for _ = 1, 20 do tick(5.0, false) end   -- a long walk back
  P.Measure("b")
  tick(1.0, true)
  local arms = P.__fpsArms()
  assertEqual(arms.active.seconds, 1, "arm A holds only its own combat")
  assertEqual(arms.suspended.seconds, 1, "arm B likewise")
  finish()
end)

test("perf: measure b suspends the addon and measure a resumes it", function()
  -- The suspend state is the independent variable, so arming sets it - it cannot be forgotten.
  startExperiment()
  P.Measure("b")
  assertTrue(P.suspended, "B suspends")
  P.Measure("a")
  assertFalse(P.suspended, "A resumes")
  finish()
end)

test("perf: window B still samples while the addon is suspended", function()
  -- Suspend unregisters the addon's event frames, so a combat-EVENT-driven window would never open
  -- for arm B. The sampler polls UnitAffectingCombat on its own frame precisely to avoid that.
  startExperiment()
  P.Measure("b")
  assertTrue(P.suspended, "suspended")
  tick(0.5, true)
  tick(0.5, true)
  assertEqual(P.__fpsArms().suspended.frames, 2, "arm B sampled anyway")
  finish()
end)

test("perf: re-arming a window zeroes it rather than averaging in", function()
  -- A botched pull should be redoable with the same command.
  startExperiment()
  P.Measure("a")
  tick(1.0, true)
  tick(1.0, false)
  assertEqual(P.__fpsArms().active.seconds, 1, "first attempt recorded")
  P.Measure("a")
  tick(2.0, true)
  assertEqual(P.__fpsArms().active.seconds, 2, "second attempt replaced it")
  finish()
end)

test("perf: arming a window mid-combat closes the one already open", function()
  startExperiment()
  P.Measure("a")
  tick(1.0, true)
  P.Measure("b")
  assertEqual(P.recording, nil, "A was closed, B not yet open")
  assertEqual(P.__fpsArms().active.seconds, 1, "A kept what it had")
  finish()
end)

test("perf: Measure is rejected outside an experiment", function()
  reset()
  local arm, err = P.Measure("a")
  assertEqual(arm, nil, "refused")
  assertEqual(err, "no experiment", "with a reason the caller can branch on")
end)

test("perf: Measure rejects an unknown window token", function()
  startExperiment()
  local arm, err = P.Measure("c")
  assertEqual(arm, nil, "refused")
  assertEqual(err, "unknown window", "and says why")
  finish()
end)

test("perf: Measure accepts either case", function()
  startExperiment()
  assertEqual(P.Measure("A"), "active", "uppercase A")
  assertEqual(P.Measure("B"), "suspended", "uppercase B")
  finish()
end)

test("perf: Stop closes an open window rather than discarding it", function()
  startExperiment()
  P.Measure("a")
  tick(1.5, true)
  local record = P.Stop()
  assertEqual(P.recording, nil, "closed")
  assertEqual(record.fps.active.seconds, 1.5, "and its data survived into the record")
end)

test("perf: Stop detaches the sampler so an idle client pays nothing", function()
  startExperiment()
  P.Stop()
  assertEqual(P.__sampler():GetScript("OnUpdate"), nil, "OnUpdate removed")
  assertFalse(P.run, "experiment over")
end)

test("perf: the sampler ignores ticks once the experiment is over", function()
  startExperiment()
  P.Measure("a")
  P.Stop()
  tick(5.0, true)
  assertEqual(P.__fpsArms().active.frames, 0, "nothing accumulated after Stop")
end)

test("perf: two completed windows produce a delta", function()
  startExperiment()
  P.Measure("a")
  for _ = 1, 8 do tick(0.0125, true) end     -- 0.1s, 8 frames -> 80 fps, 12.5 ms/frame
  tick(0.1, false)
  P.Measure("b")
  for _ = 1, 10 do tick(0.01, true) end      -- 0.1s, 10 frames -> 100 fps, 10 ms/frame
  local record = P.Stop()
  if P.suspended then P.Resume() end
  settle()
  assertEqual(record.fps.deltaMsPerFrame, 2.5, "A costs 2.5 ms/frame more than B")
end)

-- ── capture context ─────────────────────────────────────────────────────────────────────────
--
-- A saved record is read weeks later, and "119 fps" means nothing without knowing it was a Blood DK
-- soloing a dummy rather than a healer in a 20-man.

test("perf: Context captures character, spec, zone and group", function()
  local ctx = P.Context()
  assertEqual(ctx.character, "Testchar", "character")
  assertEqual(ctx.realm, "Testrealm", "realm")
  assertEqual(ctx.level, 80, "level")
  assertEqual(ctx.spec, "Blood", "spec")
  assertEqual(ctx.zone, "Silvermoon City", "zone")
  assertEqual(ctx.subZone, "Falconwing Square", "sub-zone")
end)

test("perf: Context reports solo when ungrouped", function()
  assertEqual(P.Context().group, "solo")
end)

test("perf: Context reports party size and instance type", function()
  local saved = mocks.__context
  mocks.__context = {
    name = "X", realm = "Y", level = 80, spec = "Blood", zone = "Nexus-Point Xenas", subZone = "",
    inInstance = true, instanceType = "party", inGroup = true, inRaid = false, groupSize = 5,
  }
  local g = P.Context().group
  mocks.__context = saved
  assertEqual(g, "party (5) / party", "names both the group and where it is")
end)

test("perf: Context reports raid size", function()
  local saved = mocks.__context
  mocks.__context = {
    name = "X", realm = "Y", level = 80, spec = "Blood", zone = "Z", subZone = "",
    inInstance = true, instanceType = "raid", inGroup = true, inRaid = true, groupSize = 20,
  }
  local g = P.Context().group
  mocks.__context = saved
  assertEqual(g, "raid (20) / raid")
end)

test("perf: a run records its context", function()
  reset()
  P.Start("ctx")
  local record = P.Stop()
  assertEqual(record.context.character, "Testchar", "context reached the record")
  assertEqual(record.context.zone, "Silvermoon City", "including where it happened")
end)

test("perf: ContextLines folds the sub-zone into the location", function()
  local lines = table.concat(P.ContextLines(P.Context()), "\n")
  assertTrue(lines:find("Silvermoon City", 1, true) ~= nil, "zone: " .. lines)
  assertTrue(lines:find("Falconwing Square", 1, true) ~= nil, "and sub-zone")
end)

test("perf: ContextLines omits an empty sub-zone cleanly", function()
  local lines = table.concat(P.ContextLines({
    character = "X", realm = "Y", level = 80, spec = "Blood", class = "Death Knight",
    zone = "Orgrimmar", subZone = "", group = "solo",
  }), "\n")
  assertTrue(lines:find("Orgrimmar", 1, true) ~= nil, "zone present")
  assertEqual(lines:find("\226\128\148 \n", 1, true), nil, "no dangling separator")
end)

test("perf: ContextLines tolerates a record with no context", function()
  assertEqual(#P.ContextLines(nil), 0, "returns nothing rather than erroring")
end)

test("perf: FormatReport includes the context", function()
  reset()
  P.Start("ctx")
  local lines = table.concat(P.FormatReport(P.Stop()), "\n")
  assertTrue(lines:find("Testchar", 1, true) ~= nil, "who: " .. lines)
  assertTrue(lines:find("Silvermoon City", 1, true) ~= nil, "where")
  assertTrue(lines:find("solo", 1, true) ~= nil, "group")
end)

-- ── experiment announcements ────────────────────────────────────────────────────────────────

test("perf: recording start and end are announced to chat AND the debug log", function()
  -- These fire mid-combat: chat is what the user actually sees, the console line is what survives
  -- into the copied log for later analysis. Both, deliberately.
  reset()
  local chat = {}
  local cf = mocks.DEFAULT_CHAT_FRAME
  local oldAdd = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) chat[#chat + 1] = msg end
  local wasOn = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()

  P.Start("announce")
  P.Measure("a")
  tick(0.5, true)          -- opens
  tick(0.5, false)         -- closes
  P.Stop()

  NS.State.debug = wasOn
  cf.AddMessage = oldAdd
  local chatText = table.concat(chat, "\n")
  local logText = table.concat(NS.DebugLog.buffer, "\n")

  assertTrue(chatText:find("RECORDING", 1, true) ~= nil, "chat announced the start: " .. chatText)
  assertTrue(chatText:find("ENDED", 1, true) ~= nil, "and the end")
  assertTrue(logText:find("RECORDING", 1, true) ~= nil, "console too: " .. logText)
  assertTrue(logText:find("ENDED", 1, true) ~= nil, "and the end")
end)

test("perf: the end announcement carries the duration and frame rate", function()
  reset()
  local wasOn = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  P.Start("dur")
  P.Measure("a")
  for _ = 1, 60 do tick(0.05, true) end   -- 3.0s, 60 frames -> 20 fps
  tick(0.1, false)
  P.Stop()
  NS.State.debug = wasOn
  local logText = table.concat(NS.DebugLog.buffer, "\n")
  assertTrue(logText:find("3.0s", 1, true) ~= nil, "duration: " .. logText)
  assertTrue(logText:find("60 frames", 1, true) ~= nil, "frames")
  assertTrue(logText:find("20.0 fps", 1, true) ~= nil, "and the rate")
end)

test("perf: the console log is plain text, free of colour escapes", function()
  -- The Copy window mirrors this buffer verbatim; colour codes in a log you are about to paste
  -- somewhere for analysis are noise.
  reset()
  local wasOn = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  P.Start("plain")
  P.Measure("a")
  tick(0.5, true)
  P.Stop()
  NS.State.debug = wasOn
  local logText = table.concat(NS.DebugLog.buffer, "\n")
  assertEqual(logText:find("|c", 1, true), nil, "no colour escapes: " .. logText)
  assertTrue(logText:find("Experiment A", 1, true) ~= nil, "and it reads cleanly")
end)

test("perf: experiments are named A and B, never active/suspended", function()
  reset()
  local wasOn = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  P.Start("naming")
  P.Measure("b")
  tick(0.5, true)
  P.Stop()
  if P.suspended then P.Resume() end
  settle()
  NS.State.debug = wasOn
  local logText = table.concat(NS.DebugLog.buffer, "\n")
  assertTrue(logText:find("Experiment B", 1, true) ~= nil, "user-facing name: " .. logText)
end)

test("perf: the run start is logged with its context", function()
  reset()
  local wasOn = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  P.Start("logged run")
  P.Stop()
  NS.State.debug = wasOn
  local logText = table.concat(NS.DebugLog.buffer, "\n")
  assertTrue(logText:find("run started", 1, true) ~= nil, "start line: " .. logText)
  assertTrue(logText:find("logged run", 1, true) ~= nil, "with the label")
  assertTrue(logText:find("Testchar", 1, true) ~= nil, "and the context")
  assertTrue(logText:find("run finished", 1, true) ~= nil, "and the finish line")
end)

test("perf: arming logs which experiment and whether the addon is suspended", function()
  reset()
  local wasOn = NS.State.debug
  NS.State.debug = true
  NS.DebugLog:Clear()
  P.Start("arm log")
  P.Measure("b")
  P.Stop()
  if P.suspended then P.Resume() end
  settle()
  NS.State.debug = wasOn
  local logText = table.concat(NS.DebugLog.buffer, "\n")
  assertTrue(logText:find("armed", 1, true) ~= nil, "armed line: " .. logText)
  assertTrue(logText:find("SUSPENDED", 1, true) ~= nil, "and the addon state that defines the arm")
end)

-- ── the step panel ──────────────────────────────────────────────────────────────────────────
--
-- Progress() is the whole state model; core/PerfPanel.lua only renders it. Asserting here keeps the
-- progression testable without frames.

local function states() return P.Progress() end

test("perf: before a run only Start reads done, everything else is locked", function()
  reset()
  local s = states()
  assertEqual(s.start, "done", "start")
  assertEqual(s.measureA, "locked", "A")
  assertEqual(s.measureB, "locked", "B")
  assertEqual(s.finish, "locked", "finish")
  assertEqual(s.report, "locked", "report")
end)

test("perf: starting a run makes exactly Measure A ready", function()
  reset()
  P.Start("panel")
  local s = states()
  assertEqual(s.measureA, "ready", "A is next")
  assertEqual(s.measureB, "locked", "B waits its turn")
  assertEqual(s.finish, "locked", "finish waits")
  P.Stop()
end)

test("perf: an armed or recording experiment reads busy, not ready", function()
  reset()
  P.Start("panel")
  P.Measure("a")
  assertEqual(states().measureA, "busy", "armed is busy")
  tick(0.5, true)
  assertEqual(states().measureA, "busy", "recording is busy too")
  assertEqual(states().measureB, "locked", "and B stays locked meanwhile")
  P.Stop()
end)

test("perf: completing A unlocks B and nothing else", function()
  reset()
  P.Start("panel")
  P.Measure("a")
  tick(0.5, true)
  tick(0.5, false)
  local s = states()
  assertEqual(s.measureA, "done", "A done")
  assertEqual(s.measureB, "ready", "B is next")
  assertEqual(s.finish, "locked", "finish still locked")
  P.Stop()
end)

test("perf: completing B unlocks Finish", function()
  reset()
  P.Start("panel")
  P.Measure("a"); tick(0.5, true); tick(0.5, false)
  P.Measure("b"); tick(0.5, true); tick(0.5, false)
  local s = states()
  assertEqual(s.measureB, "done", "B done")
  assertEqual(s.finish, "ready", "finish is next")
  assertEqual(s.report, "locked", "review waits for the run to end")
  finish()
end)

test("perf: finishing unlocks Report and Dump", function()
  reset()
  P.Start("panel")
  P.Measure("a"); tick(0.5, true); tick(0.5, false)
  P.Measure("b"); tick(0.5, true); tick(0.5, false)
  P.Stop()
  if P.suspended then P.Resume() end
  settle()
  local s = states()
  assertEqual(s.finish, "done", "finish done")
  assertEqual(s.report, "ready", "report available")
  assertEqual(s.dump, "ready", "dump available")
end)

test("perf: exactly one step is ready at any point in a run", function()
  -- The panel's entire purpose: a run cannot be done out of order.
  reset()
  local function readyCount()
    local n = 0
    for _, state in pairs(states()) do if state == "ready" then n = n + 1 end end
    return n
  end
  P.Start("panel")
  assertEqual(readyCount(), 1, "after start")
  P.Measure("a")
  assertEqual(readyCount(), 0, "while A is armed, nothing else is offered")
  tick(0.5, true); tick(0.5, false)
  assertEqual(readyCount(), 1, "after A")
  P.Measure("b")
  assertEqual(readyCount(), 0, "while B is armed")
  tick(0.5, true); tick(0.5, false)
  assertEqual(readyCount(), 1, "after B")
  finish()
end)

test("perf: re-arming a completed experiment sends it back to busy", function()
  reset()
  P.Start("panel")
  P.Measure("a"); tick(0.5, true); tick(0.5, false)
  assertEqual(states().measureA, "done", "done after the first attempt")
  P.Measure("a")
  assertEqual(states().measureA, "busy", "redoing it is in progress again")
  assertEqual(states().measureB, "locked", "and B relocks until A completes")
  P.Stop()
end)

test("perf: a window that caught no frames still counts as completed", function()
  -- Completion is tracked explicitly rather than inferred from frame counts: the step happened,
  -- whatever it caught.
  reset()
  P.Start("panel")
  P.Measure("a")
  tick(0.0, true)     -- opens, accumulates a zero-length frame
  tick(0.0, false)    -- closes immediately
  assertEqual(states().measureA, "done", "still done")
  P.Stop()
end)

test("perf: Reset clears completion, so a fresh run starts from step one", function()
  reset()
  P.Start("panel")
  P.Measure("a"); tick(0.5, true); tick(0.5, false)
  P.Stop()
  P.Start("second")
  assertEqual(states().measureA, "ready", "A is offered again")
  assertEqual(states().measureB, "locked", "and B is not")
  P.Stop()
end)

test("perf: the panel renders every step and tracks their states", function()
  reset()
  P.Start("panel")
  P.Measure("a"); tick(0.5, true); tick(0.5, false)
  NS.PerfPanel:Show()
  local f = NS.PerfPanel.__frame()
  assertTrue(f ~= nil, "panel built")
  assertTrue(f:IsShown(), "and shown")
  for _, step in ipairs(NS.PerfPanel.STEPS) do
    assertTrue(f.buttons[step.key] ~= nil, "button for " .. step.key)
  end
  assertEqual(f.buttons.measureA.__label, "Measure A (with the addon)", "label is plain text")
  assertEqual(f.buttons.measureA.__state, "done", "a completed step carries its state")
  assertEqual(f.buttons.measureB.__state, "ready", "as does the next one")
  assertEqual(f.buttons.finish.__state, "locked", "and the ones beyond it")
  P.Stop()
  NS.PerfPanel:Hide()
end)

test("perf: a locked panel button refuses to act when clicked", function()
  -- Belt and braces over Disable(): a step that runs out of order corrupts the run the panel exists
  -- to protect, and a script can be fired directly.
  reset()
  P.Start("panel")
  NS.PerfPanel:Show()
  local f = NS.PerfPanel.__frame()
  assertEqual(NS.PerfPanel.StateOf("finish"), "locked", "finish is locked")
  f.buttons.finish:__fire("OnClick")
  assertTrue(P.run, "the run is still going — the click did nothing")
  P.Stop()
  NS.PerfPanel:Hide()
end)

test("perf: a ready panel button runs its slash command", function()
  reset()
  P.Start("panel")
  NS.PerfPanel:Show()
  local f = NS.PerfPanel.__frame()
  assertEqual(NS.PerfPanel.StateOf("measureA"), "ready", "A is offered")
  f.buttons.measureA:__fire("OnClick")
  assertEqual(P.armed, "active", "clicking armed Experiment A")
  P.Stop()
  NS.PerfPanel:Hide()
end)

test("perf: the panel refreshes off the bus, not by polling", function()
  reset()
  P.Start("panel")
  NS.PerfPanel:Show()
  local f = NS.PerfPanel.__frame()
  assertEqual(f.buttons.measureB.__state, "locked", "B not yet reachable")
  P.Measure("a"); tick(0.5, true); tick(0.5, false)
  P.Measure("b"); tick(0.5, true); tick(0.5, false)
  -- No explicit Refresh() call here: closing the window published PERF, which drove it.
  assertEqual(f.buttons.measureB.__state, "done", "the panel caught up on its own")
  finish()
  NS.PerfPanel:Hide()
end)

test("perf: every step row carries a status dot, drawn not glyphed", function()
  -- A text tick rendered as tofu in the default font, and any Interface\\... path is an unverifiable
  -- guess. The dot is a SetColorTexture, which has no font or art dependency.
  reset()
  P.Start("dots")
  NS.PerfPanel:Show()
  local f = NS.PerfPanel.__frame()
  for _, step in ipairs(NS.PerfPanel.STEPS) do
    assertTrue(f.buttons[step.key].dot ~= nil, "dot for " .. step.key)
  end
  P.Stop()
  NS.PerfPanel:Hide()
end)

test("perf: labels are plain text with no decoration baked in", function()
  reset()
  P.Start("labels")
  NS.PerfPanel:Show()
  local f = NS.PerfPanel.__frame()
  for _, step in ipairs(NS.PerfPanel.STEPS) do
    assertEqual(f.buttons[step.key].__label, step.label,
      step.key .. " renders its label verbatim")
  end
  P.Stop()
  NS.PerfPanel:Hide()
end)

-- ── the cancel step ─────────────────────────────────────────────────────────────────────────

test("perf: cancel is offered at every point, including before a run", function()
  reset()
  assertEqual(P.Progress().cancel, "cancel", "before a run")
  P.Start("c")
  assertEqual(P.Progress().cancel, "cancel", "during one")
  P.Measure("a")
  assertEqual(P.Progress().cancel, "cancel", "mid-experiment")
  P.Stop()
  assertEqual(P.Progress().cancel, "cancel", "and after")
end)

test("perf: cancel has its own state, so it never reads as the next step", function()
  reset()
  P.Start("c")
  local ready = 0
  for _, state in pairs(P.Progress()) do if state == "ready" then ready = ready + 1 end end
  assertEqual(ready, 1, "cancel does not inflate the ready count")
end)

test("perf: cancelling discards the run without saving it", function()
  reset()
  _G.AbsorbTrackerPerfDB = nil
  P.Start("thrown away")
  P.Measure("a"); tick(0.5, true); tick(0.5, false)
  assertTrue(P.Cancel(), "cancelled")
  assertEqual(_G.AbsorbTrackerPerfDB, nil, "nothing was written to the ring")
  assertFalse(P.run, "run over")
  assertEqual(P.__fpsArms().active.frames, 0, "counters zeroed")
  assertEqual(P.Progress().measureA, "locked", "and the progression is back to the start")
end)

test("perf: cancelling restores a suspended addon", function()
  reset()
  P.Start("c")
  P.Measure("b")
  assertTrue(P.suspended, "B suspended it")
  P.Cancel()
  settle()
  assertFalse(P.suspended, "cancel brought it back")
  assertTrue(NS.ShouldShowBar("player"), "and the bars with it")
end)

test("perf: cancelling mid-recording does not announce the experiment as ended", function()
  -- It goes through neither closeWindow nor Stop: marking a thrown-away window "ENDED" would be a
  -- lie about a measurement that never counted.
  reset()
  local lines = captureDebugLines(function()
    P.Start("c")
    P.Measure("a")
    tick(0.5, true)
    P.Cancel()
  end)
  settle()
  assertEqual(lines:find("ENDED", 1, true), nil, "no end-of-experiment line: " .. lines)
  assertTrue(lines:find("CANCELLED", 1, true) ~= nil, "but it says it was cancelled")
end)

test("perf: cancelling detaches the sampler", function()
  reset()
  P.Start("c")
  P.Cancel()
  assertEqual(P.__sampler():GetScript("OnUpdate"), nil, "no per-frame cost left behind")
end)

test("perf: cancel returns false when there is nothing to cancel", function()
  reset()
  assertFalse(P.Cancel(), "no run in flight")
end)

test("perf: a cancelled run leaves the next one clean", function()
  reset()
  P.Start("first")
  P.Measure("a"); tick(0.5, true); tick(0.5, false)
  P.Cancel()
  settle()
  P.Start("second")
  assertEqual(P.Progress().measureA, "ready", "A is offered again")
  assertEqual(P.__fpsArms().active.frames, 0, "with nothing carried over")
  P.Stop()
end)

-- ── the three-column layout ─────────────────────────────────────────────────────────────────

test("perf: every row shows its slash command", function()
  reset()
  P.Start("cols")
  NS.PerfPanel:Show()
  local f = NS.PerfPanel.__frame()
  assertEqual(f.buttons.measureA.__command, "/at perf measure a", "A")
  assertEqual(f.buttons.finish.__command, "/at perf finish", "finish")
  assertEqual(f.buttons.cancel.__command, "/at perf cancel", "cancel")
  P.Stop()
  NS.PerfPanel:Hide()
end)

test("perf: the cancel row is clickable when every other row is locked", function()
  reset()
  NS.PerfPanel:Show()
  local f = NS.PerfPanel.__frame()
  assertFalse(NS.PerfPanel.IsActionable("measureA"), "A locked outside a run")
  assertFalse(NS.PerfPanel.IsActionable("finish"), "finish locked")
  assertTrue(NS.PerfPanel.IsActionable("cancel"), "cancel still live")
  NS.PerfPanel:Hide()
end)

test("perf: clicking the cancel row abandons the run", function()
  reset()
  P.Start("clicked")
  P.Measure("a"); tick(0.5, true)
  NS.PerfPanel:Show()
  NS.PerfPanel.__frame().buttons.cancel:__fire("OnClick")
  settle()
  assertFalse(P.run, "the run was abandoned from the panel")
  NS.PerfPanel:Hide()
end)
