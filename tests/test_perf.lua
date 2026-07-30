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

-- Identity search: is `needle` reachable anywhere under `root`? Cycle-safe, and keys count as much
-- as values — a ring parked as `db.profile[someTable]` would hide from a value-only walk.
local function reaches(root, needle, seen)
  if root == needle then return true end
  if type(root) ~= "table" then return false end
  seen = seen or {}
  if seen[root] then return false end
  seen[root] = true
  for k, v in pairs(root) do
    if reaches(k, needle, seen) or reaches(v, needle, seen) then return true end
  end
  return false
end

test("perf: the ring is reachable through its own global and nowhere in AceDB", function()
  -- Naming one field AceDB might hold (`profile.perf`) tests almost nothing — nothing writes that
  -- name. What actually matters is that no path at all leads from the AceDB tree to the ring or to
  -- a saved run, because anything inside a profile rides copy, reset and profile switch.
  reset()
  P.Save(P.BuildRecord("cap"))
  local ring = _G.AbsorbTrackerPerfDB
  local record = ring.runs[1]
  assertTrue(reaches(ring, record), "sanity: the walk can find a record it is pointed at")
  for _, where in ipairs({ "profile", "global" }) do
    local tree = NS.db and NS.db[where]
    assertFalse(reaches(tree, ring), "the ring is reachable from db." .. where)
    assertFalse(reaches(tree, record), "a saved run is reachable from db." .. where)
  end
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

-- ── the degraded install (no LibKa0s) ───────────────────────────────────────────────────────
--
-- LibKa0s is vendored, so it can go missing: a partial unzip, a user pruning libs/, a packager that
-- dropped the folder. core/PerfSetup.lua substitutes a stub for the probe in that case, and the stub
-- has to answer for every member the addon calls — including OnCommand, because `/at perf` is
-- registered unconditionally in settings/Slash.lua.
--
-- Built as a SECOND, self-contained environment rather than by poking at the shared one: the whole
-- point is a load with the library absent, which cannot be simulated after the fact. Nothing here
-- calls InitDB or CreateOptionsPanel, so the shared suite's SavedVariables globals are untouched.
local function loadDegraded()
  local Loader     = dofile("tests/_kit/loader.lua")
  local buildMocks = dofile("tests/wow_mock.lua")
  -- A fresh loader table per dofile, so this environment sets its own addonName.
  Loader.addonName = "AbsorbTracker"
  local mocks2, NS2 = buildMocks(), {}
  -- libs/LibKa0s/*.lua deliberately not in this list: unloaded, nothing registers the perf major,
  -- and the mock's LibStub returns nil for it exactly as the real client would.
  Loader.loadAll({
    "locales/enUS.lua", "core/Compat.lua", "core/Constants.lua", "core/Namespace.lua",
    "core/State.lua", "core/Bus.lua", "core/Util.lua", "core/PerfSetup.lua", "core/Data.lua",
    "core/Units.lua", "core/Database.lua", "core/LSMPatch.lua", "core/DebugLog.lua",
    "core/AbsorbTracker.lua", "defaults/Profile.lua", "modules/Bar.lua", "modules/Display.lua",
    "modules/Timer.lua", "settings/Schema.lua", "settings/Slash.lua",
  }, NS2, mocks2)
  return NS2, mocks2
end

local function chatOf(mocks2, fn)
  local out = {}
  mocks2.DEFAULT_CHAT_FRAME.AddMessage = function(_, msg) out[#out + 1] = msg end
  fn()
  return out
end

test("perf: the addon loads with LibKa0s absent", function()
  local NS2 = loadDegraded()
  assertEqual(NS2.Perf.on, false, "the bracket gate is off and stays off")
  assertEqual(NS2.Perf.suspended, false, "and the show ladder sees a running addon")
  assertEqual(type(NS2.Perf.Note), "function", "Note")
end)

test("perf: /at perf explains itself instead of erroring with LibKa0s absent", function()
  local NS2, mocks2 = loadDegraded()
  for _, line in ipairs({ "perf", "perf start", "perf finish", "perf dump" }) do
    local out = chatOf(mocks2, function() NS2.Slash:OnSlash(line) end)
    assertTrue(#out > 0, "/at " .. line .. " said nothing")
    assertTrue(table.concat(out, "\n"):find("LibKa0s", 1, true) ~= nil,
      "/at " .. line .. " should name the missing library: " .. table.concat(out, "\n"))
  end
end)

test("perf: the brackets and the show ladder survive LibKa0s being absent", function()
  -- The degraded env needs its own database to paint anything, and AceDB resolves the SavedVariables
  -- global by name — so the shared suite's is swapped out and put back rather than merged into.
  local NS2 = loadDegraded()
  local saved = _G.AbsorbTrackerDB
  _G.AbsorbTrackerDB = nil
  local ok, err = pcall(function()
    NS2:InitDB()
    NS2.SetByPath("units.player.enabled", true)
    assertTrue(NS2.ShouldShowBar("player"), "the ladder still reaches a decision")
    NS2.UpdateAbsorbBar("player")
    NS2.bus:SendMessage(NS2.MSG.APPEARANCE)
  end)
  _G.AbsorbTrackerDB = saved
  assertTrue(ok, "a bracket site errored without the probe: " .. tostring(err))
end)
