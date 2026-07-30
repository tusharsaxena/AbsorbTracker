-- tests/test_perf.lua — this addon's side of the perf harness (issue #17).
--
-- The probe itself is LibKa0s-Perf and is tested in that repo: buckets, JSON, the record schema, the
-- report, the ring, the measurement windows and the panel all have suites there. Duplicating them
-- here would mean two places to fix one bug.
--
-- What is ours, and what this file covers: the descriptor is well-formed, every bucket we declare is
-- actually reached by a bracket, and Suspend genuinely makes THIS addon inert.

local T = _G.AT_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

local P = NS.Perf

-- Drain the repaint queue. Resume() republishes REPAINT, which arms a coalescing timer; left armed,
-- `pending` in modules/Timer.lua stays set for the rest of the PROCESS and every later suite's
-- RequestRepaint quietly coalesces into a pass that never fires. That is invisible here and shows up
-- as unrelated failures three suites away, so every path that resumes drains first.
local function settle()
  NS.CancelPendingRepaint()
  for i = #mocks.__timers, 1, -1 do mocks.__timers[i] = nil end
end

local function resume()
  P.Resume()
  settle()
end

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

-- ── the descriptor ──────────────────────────────────────────────────────────────────────────

test("perf: the addon holds a real LibKa0s-Perf instance", function()
  reset()
  assertTrue(type(P.Note) == "function", "Note")
  assertTrue(type(P.Start) == "function", "Start")
  assertTrue(type(P.OnCommand) == "function", "OnCommand")
  assertEqual(P.on, false, "the capture gate is a plain boolean field")
end)

test("perf: the descriptor declares this addon's buckets, with their nesting", function()
  reset()
  assertEqual(table.concat(P.BUCKET_ORDER, ","),
    "absorbEvent,repaintPass,paintBar,appearance,visibility", "order")
  assertEqual(P.BUCKET_WITHIN.paintBar, "repaintPass", "paintBar nests")
  assertEqual(P.BUCKET_WITHIN.appearance, "repaintPass", "appearance nests")
  assertEqual(P.BUCKET_WITHIN.visibility, "repaintPass", "visibility nests")
  assertEqual(P.BUCKET_WITHIN.repaintPass, nil, "the pass itself is top level")
end)

test("perf: records identify this addon and land in its own global", function()
  reset()
  P.Save(P.BuildRecord("cap"))
  assertEqual(_G.AbsorbTrackerPerfDB.runs[1].addon, "AbsorbTracker", "self-identifying")
  assertEqual(_G.AbsorbTrackerPerfDB.schema, 2, "schema 2")
end)

test("perf: the ring is outside the AceDB tree", function()
  reset()
  P.Save(P.BuildRecord("cap"))
  local profile = NS.db and NS.db.profile
  assertTrue(profile == nil or profile.perf == nil,
    "a perf ring inside a profile would ride copy, reset and switch")
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

test("perf: every declared bucket is reached by a real bracket", function()
  -- Each bucket is driven through its OWN entry point rather than off one repaint: the pass covers
  -- repaintPass and paintBar only, while appearance and visibility are reached by their own bus
  -- messages and absorbEvent by the event handler. Weakening the assertion to whatever a repaint
  -- happens to touch would be the wrong trade — a declared bucket no bracket reaches is a lie in
  -- every report the addon prints.
  reset()
  NS.SetByPath("units.player.enabled", true)
  P.on = true
  mocks.__absorbs.player = 1000
  mocks.__profileMs = 1
  NS.bus:SendMessage(NS.MSG.REPAINT)
  mocks.__fireTimers()
  NS.bus:SendMessage(NS.MSG.APPEARANCE)
  NS.bus:SendMessage(NS.MSG.VISIBILITY)
  NS.addon:OnAbsorbChanged("UNIT_ABSORB_AMOUNT_CHANGED", "player")
  P.on = false
  local recorded = P.__buckets()
  for _, key in ipairs(P.BUCKET_ORDER) do
    assertTrue(recorded[key] ~= nil,
      "declared bucket '" .. key .. "' never fired — a bucket nobody reaches is a lie in the report")
  end
  mocks.__absorbs.player = nil
  settle()
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
  -- Guards against the descriptor's resume growing a hand-copied event list that drifts from
  -- OnEnable's.
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

-- ── output routing ──────────────────────────────────────────────────────────────────────────

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

test("perf: the slash verb dispatches into the lib", function()
  reset()
  NS.Slash:OnSlash("perf start")
  assertTrue(P.run, "typed command reached the lib")
  P.Cancel()
  settle()
end)
