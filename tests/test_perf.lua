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
  P.experiment = false
  P.armed, P.window = nil, nil
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

local function captureDebugLines(fn)
  local before = #NS.DebugLog.buffer
  local wasOn = NS.State.debug
  NS.State.debug = true
  local ok, err = pcall(fn)
  NS.State.debug = wasOn
  if not ok then error(err) end
  local out = {}
  for i = before + 1, #NS.DebugLog.buffer do out[#out + 1] = NS.DebugLog.buffer[i] end
  return table.concat(out, "\n")
end

test("perf: starting an experiment logs it", function()
  reset()
  local lines = captureDebugLines(function() P.Start("solo") end)
  P.on = false
  assertTrue(lines:find("[Perf]", 1, true) ~= nil, "tagged [Perf]: " .. lines)
  assertTrue(lines:find("experiment started", 1, true) ~= nil, "says what happened")
  assertTrue(lines:find("solo", 1, true) ~= nil, "and which capture: " .. lines)
end)

test("perf: stopping an experiment logs both arm durations", function()
  reset()
  local arms = P.__fpsArms()
  arms.active.seconds, arms.active.frames = 60, 7000
  arms.suspended.seconds, arms.suspended.frames = 30, 3500
  local lines = captureDebugLines(function() P.Stop() end)
  assertTrue(lines:find("experiment stopped", 1, true) ~= nil, "logged: " .. lines)
  assertTrue(lines:find("60.0s", 1, true) ~= nil, "active arm duration")
  assertTrue(lines:find("30.0s", 1, true) ~= nil, "suspended arm duration")
end)

test("perf: suspend and resume are logged", function()
  reset()
  local lines = captureDebugLines(function() P.Suspend() end)
  assertTrue(lines:find("suspended", 1, true) ~= nil, "suspend logged: " .. lines)
  lines = captureDebugLines(function() P.Resume() end)
  settle()
  assertTrue(lines:find("resumed", 1, true) ~= nil, "resume logged: " .. lines)
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

test("perf: lifecycle lines cost nothing when debug logging is off", function()
  reset()
  local before = #NS.DebugLog.buffer
  NS.State.debug = false
  P.Start("quiet")
  P.Suspend()
  P.Resume()
  settle()
  P.Stop()
  assertEqual(#NS.DebugLog.buffer, before, "NS.Debug is gated, so nothing was written")
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
  assertEqual(P.window, "active", "window open")
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
  assertEqual(P.window, nil, "window closed")
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
  assertEqual(P.window, nil, "A was closed, B not yet open")
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
  assertEqual(P.window, nil, "closed")
  assertEqual(record.fps.active.seconds, 1.5, "and its data survived into the record")
end)

test("perf: Stop detaches the sampler so an idle client pays nothing", function()
  startExperiment()
  P.Stop()
  assertEqual(P.__sampler():GetScript("OnUpdate"), nil, "OnUpdate removed")
  assertFalse(P.experiment, "experiment over")
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
