local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The `/at perf` verb, peeled out of tests/test_slashcmds.lua when that file crossed layout-§1's
-- 1500-line cap. The seam is the one that file already carried: every other case in it drives a
-- verb settings/Slash.lua owns outright, while these drive a surface that belongs to a different
-- module — the perf probe (LibKa0s-Perf, wired up in core/PerfSetup.lua, issue #17) — which only
-- reaches the player through the same dispatcher. Nothing was renamed on the way across and no
-- case was dropped: the names below are the names that were in test_slashcmds.lua, so a red reads
-- exactly as it did before.
--
-- Three files now cover NS.COMMANDS between them, and the split is the thing that makes a red
-- legible: tests/test_slash.lua (NS.Print, the dispatcher itself and the first verbs),
-- tests/test_slashcmds.lua (the rest of settings/Slash.lua's own verbs), and this file (`/at perf`).
-- Read the failing case name, and you know which file to open.
--
-- As in test_slashcmds.lua, these assert the DISPATCH — that each sub-verb reaches the right probe
-- call and says so — rather than re-testing the probe's accounting, which tests/test_perf.lua owns.

-- Same capture seam as test_slashcmds.lua: Slash.lua bound `local print = NS.Print` at load, so the
-- only interceptable point is the chat frame's AddMessage sink. Restated here rather than shared:
-- these four helpers are file-local in every suite in this collection, and a suite that reached
-- into another one for them would tie the two together for no gain.
local function capture(fn)
  local out = {}
  local cf = T.mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  cf.AddMessage = old
  if not ok then error(err) end
  return out
end

local function stripColor(s)
  return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

-- Run a slash line and return its plain-text output lines.
local function slash(line)
  local out = capture(function() NS.Slash:OnSlash(line) end)
  local plain = {}
  for i, l in ipairs(out) do plain[i] = stripColor(l) end
  return plain
end

local function joined(lines) return table.concat(lines, "\n") end

local function contains(lines, needle)
  return joined(lines):find(needle, 1, true) ~= nil
end

-- ── /at perf ──────────────────────────────────────────────────────────────────────────
--
-- The perf probe's slash surface (LibKa0s-Perf, wired up in core/PerfSetup.lua, issue #17). These
-- assert the DISPATCH — that each sub-verb reaches the right probe call and says so — rather than
-- re-testing the probe's accounting, which tests/test_perf.lua owns.

local P = NS.Perf

-- Every perf sub-verb that resumes republishes REPAINT and arms a coalescing timer; left armed it
-- poisons later suites (see the same note in tests/test_perf.lua).
local function perfReset()
  P.on = false
  P.run = false
  P.armed, P.recording = nil, nil
  if P.suspended then P.Resume() end
  P.Reset()
  NS.CancelPendingRepaint()
  for i = #T.mocks.__timers, 1, -1 do T.mocks.__timers[i] = nil end
end

test("/at perf (bare) reports status and prints usage", function()
  perfReset()
  local out = slash("perf")
  assertTrue(contains(out, "perf "), "leads with the phase")
  assertTrue(contains(out, "usage: /at perf"), "then the usage block")
  assertTrue(contains(out, "suspend"), "documents the suspend arm")
end)

test("/at perf start starts a capture", function()
  perfReset()
  local out = slash("perf start")
  assertTrue(P.run, "experiment running")
  assertFalse(P.on, "but sampling nothing until a window is armed")
  assertTrue(contains(out, "STARTED"), "acknowledges: " .. joined(out))
  perfReset()
end)

test("/at perf start resets the counters from the previous capture", function()
  perfReset()
  P.Note("paintBar", 99)
  slash("perf start")
  assertEqual(P.__buckets().paintBar, nil, "a new capture starts clean")
  perfReset()
end)

test("/at perf finish refuses when no run is active", function()
  perfReset()
  local out = slash("perf finish")
  assertTrue(contains(out, "no perf run is active"), "says so rather than saving an empty record")
end)

test("/at perf finish does not print the summary", function()
  -- It fires the moment a fight ends, when the console is buried in combat output and a dozen
  -- unasked-for lines would scroll straight past. Report and Dump are one click away in the panel.
  perfReset()
  _G.AbsorbTrackerPerfDB = nil
  slash("perf start")
  NS.DebugLog:Clear()
  local out = slash("perf finish")
  assertEqual(joined(out):find("bucket", 1, true), nil, "no summary table: " .. joined(out))
  assertTrue(contains(out, "FINISHED"), "just the acknowledgment")
  assertTrue(contains(out, "Report"), "which points at how to read it")
  local logged = table.concat(NS.DebugLog.buffer, "\n")
  assertEqual(logged:find("bucket", 1, true), nil, "and none in the console either: " .. logged)
  _G.AbsorbTrackerPerfDB = nil
  perfReset()
end)

test("/at perf report still prints the summary on demand", function()
  perfReset()
  slash("perf start")
  slash("perf finish")
  NS.DebugLog:Clear()
  slash("perf report")
  local logged = table.concat(NS.DebugLog.buffer, "\n")
  assertTrue(logged:find("bucket", 1, true) ~= nil, "the table is there when asked for: " .. logged)
  perfReset()
end)

test("/at perf finish saves the record to the perf ring", function()
  perfReset()
  _G.AbsorbTrackerPerfDB = nil
  slash("perf start")
  slash("perf finish")
  assertEqual(type(_G.AbsorbTrackerPerfDB), "table", "the ring exists")
  assertEqual(#_G.AbsorbTrackerPerfDB.runs, 1, "one capture stored")
  assertFalse(P.on, "capture stopped")
  _G.AbsorbTrackerPerfDB = nil
end)

test("/at perf finish lifts a suspend left over from the capture", function()
  -- Otherwise stopping a capture would silently leave the addon disabled for the whole session.
  perfReset()
  slash("perf start")
  slash("perf measure b")
  assertTrue(P.suspended, "measure b suspended the addon")
  local out = slash("perf finish")
  assertFalse(P.suspended, "finish lifted it")
  assertTrue(contains(out, "RESUMED"), "and says so: " .. joined(out))
  perfReset()
  _G.AbsorbTrackerPerfDB = nil
end)

test("/at perf report prints without stopping the capture", function()
  perfReset()
  slash("perf start")
  slash("perf report")
  assertTrue(P.run, "still running")
  perfReset()
end)

test("/at perf routes output to the debug console, not chat", function()
  -- The console is ungated (D:Add ignores NS.State.debug), which is what makes perf usable with
  -- logging off. If these lines went to chat instead they would be lost in combat spam.
  perfReset()
  NS.DebugLog:Clear()
  slash("perf report")
  assertTrue(#NS.DebugLog.buffer > 0, "report lines landed in the console buffer")
end)

test("/at perf report writes the JSON to the console, not to a copy window", function()
  -- `perf dump` was its own verb until LibKa0s v1.29.0 folded it into `report`. What it proved is
  -- unchanged and still worth proving here rather than only upstream: this addon's slash handler
  -- reaches the library's report, and the JSON lands in the console -- the log already open and
  -- scrollable, its Copy button one click away when the text needs lifting out. A modal for
  -- something you may only want to glance at is the wrong default.
  perfReset()
  NS.DebugLog:Clear()
  slash("perf report")
  local logged = table.concat(NS.DebugLog.buffer, "\n")
  assertTrue(logged:find('"buckets"', 1, true) ~= nil, "JSON is in the console: " .. logged)
  perfReset()
end)

test("/at perf report emits parseable JSON carrying the schema stamp, as its LAST line", function()
  -- Last, not merely present: the summary is what a person reads and the JSON is what they copy,
  -- so a copy-paste starts at the bottom of the window. A report that printed the JSON first and
  -- the summary after would satisfy "contains JSON" and be worse to use.
  perfReset()
  NS.DebugLog:Clear()
  slash("perf report")
  local line = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(#NS.DebugLog.buffer > 1, "the summary went missing with the fold")
  assertTrue(line:find('"schema":2', 1, true) ~= nil, "carries the schema: " .. line)
  assertTrue(line:find('"source":"ingame"', 1, true) ~= nil, "and the source")
end)

test("/at perf with an unknown sub falls back to the usage block", function()
  perfReset()
  local out = slash("perf wibble")
  assertTrue(contains(out, "usage: /at perf"), joined(out))
end)

test("/at debug on|off still toggles logging with perf present", function()
  -- Guards the sub-verb split: `perf` must not have swallowed the existing on/off contract.
  perfReset()
  slash("debug on")
  assertTrue(NS.State.debug, "logging on")
  slash("debug off")
  assertFalse(NS.State.debug, "logging off")
end)

test("perf is a top-level verb in the help index", function()
  local out = slash("help")
  assertTrue(contains(out, "/at perf"), "listed in its own right: " .. joined(out))
  assertTrue(contains(out, "/at debug"), "and debug is still there")
end)

test("perf is registered in NS.COMMANDS, so the About page lists it too", function()
  -- PrintHelp and the About page both iterate NS.COMMANDS; a verb wired only into the dispatcher
  -- would work but stay invisible in both.
  local found
  for _, entry in ipairs(NS.COMMANDS) do
    if entry[1] == "perf" then found = entry end
  end
  assertTrue(found ~= nil, "perf has a COMMANDS row")
  assertTrue(found[2] ~= nil and found[2] ~= "", "with a description")
end)

test("/at debug no longer swallows a perf argument", function()
  -- `perf` used to be a sub-verb of debug. `/at debug perf` must now fall through to debug's own
  -- handling rather than silently doing perf work.
  perfReset()
  local before = P.run
  slash("debug perf")
  assertEqual(P.run, before, "debug did not start a perf run")
end)

test("/at perf start accepts an optional label, appended to the timestamp", function()
  -- Captures accumulate in a ring across sessions; without a label two runs from the same
  -- afternoon are near-impossible to tell apart when reading SavedVariables later.
  perfReset()
  slash("perf start solo run")
  assertTrue(P.label:find("solo run", 1, true) ~= nil, "label kept: " .. tostring(P.label))
  assertTrue(#P.label > #"solo run", "timestamp still present: " .. tostring(P.label))
  P.on = false
end)

test("/at perf start without a label still stamps the capture", function()
  perfReset()
  slash("perf start")
  assertTrue(P.label ~= nil and P.label ~= "", "auto-stamped: " .. tostring(P.label))
  P.on = false
end)

test("/at perf start label reaches the saved record", function()
  perfReset()
  _G.AbsorbTrackerPerfDB = nil
  slash("perf start full addon set")
  slash("perf finish")
  local rec = _G.AbsorbTrackerPerfDB.runs[1]
  assertTrue(rec.label:find("full addon set", 1, true) ~= nil, "label persisted: " .. rec.label)
  _G.AbsorbTrackerPerfDB = nil
end)

test("/at perf start records who and where the capture happened", function()
  -- A ring of archived runs is unreadable if a record cannot say which character, spec and zone
  -- produced it. The snapshot is taken by `start`, so it has to survive all the way into the saved
  -- record — the lib pins BuildRecord, this pins the addon's whole start → finish → SavedVariables
  -- path.
  perfReset()
  _G.AbsorbTrackerPerfDB = nil
  slash("perf start")
  slash("perf finish")
  local ctx = _G.AbsorbTrackerPerfDB.runs[1].context
  assertTrue(ctx ~= nil, "the saved run carries a context")
  assertEqual(ctx.character, "Testchar", "the character, not a placeholder")
  assertEqual(ctx.zone, "Silvermoon City", "and where it was captured")
  _G.AbsorbTrackerPerfDB = nil
  perfReset()
end)

test("/at perf report prints the capture's context, not just the numbers", function()
  -- Someone reading a pasted report has to be able to tell whose it is. FormatReport folding the
  -- context in is the seam that makes that true.
  perfReset()
  slash("perf start")
  slash("perf finish")
  NS.DebugLog:Clear()
  slash("perf report")
  local logged = table.concat(NS.DebugLog.buffer, "\n")
  assertTrue(logged:find("Testchar", 1, true) ~= nil, "the character is in the report: " .. logged)
  assertTrue(logged:find("Silvermoon City", 1, true) ~= nil, "and the zone")
  _G.AbsorbTrackerPerfDB = nil
  perfReset()
end)

test("/at perf measure a arms Experiment A", function()
  perfReset()
  slash("perf start")
  local out = slash("perf measure a")
  assertEqual(P.armed, "active", "armed")
  assertFalse(P.suspended, "addon left running for the A arm")
  assertTrue(contains(out, "ARMED"), "acknowledges: " .. joined(out))
  assertTrue(contains(out, "combat"), "and says it waits for combat")
  perfReset()
end)

test("/at perf measure b arms Experiment B and suspends", function()
  perfReset()
  slash("perf start")
  slash("perf measure b")
  assertEqual(P.armed, "suspended", "armed")
  assertTrue(P.suspended, "and the addon is inert without a separate command")
  perfReset()
end)

test("/at perf measure refuses outside an experiment", function()
  perfReset()
  local out = slash("perf measure a")
  assertTrue(contains(out, "/at perf start"), "points at the fix: " .. joined(out))
end)

test("/at perf measure rejects an unknown window", function()
  perfReset()
  slash("perf start")
  local out = slash("perf measure z")
  assertTrue(contains(out, "unknown window"), joined(out))
  assertTrue(contains(out, "measure a"), "and names the valid ones")
  perfReset()
end)

test("/at perf bare reports the armed window", function()
  perfReset()
  slash("perf start")
  slash("perf measure a")
  local out = slash("perf")
  assertTrue(contains(out, "armed"), "shows the phase: " .. joined(out))
  perfReset()
end)

test("the perf usage block documents the measure workflow", function()
  -- This block is LibKa0s-Perf's text, printed through this addon's slash handler, so what is
  -- pinned here has to be the CONCEPT rather than the sentence. It asserted the exact phrase
  -- "suspends the addon first" until v1.28.0 reworded the block, and went red on a re-vendor that
  -- had changed nothing about this addon -- a case that fails when an upstream sentence is edited
  -- is reporting on the wrong thing.
  --
  -- What matters is that the block names the two experiments, says what B changes (the addon is
  -- suspended) and says what report does. Any wording that does those things should pass.
  perfReset()
  local out = slash("perf")
  assertTrue(contains(out, "measure a"), "lists measure a")
  assertTrue(contains(out, "measure b"), "lists measure b")
  assertTrue(contains(out, "suspend"), "explains what measure b changes")
  assertTrue(contains(out, "opens the log window"), "and what report does")
end)

test("/at perf start opens the panel instead of listing the steps in chat", function()
  -- The steps used to be printed to chat and the console on every start. The panel carries them
  -- now, in a form that does not scroll away the moment combat begins.
  perfReset()
  NS.DebugLog:Clear()
  local out = slash("perf start")
  assertEqual(joined(out):find("next steps", 1, true), nil, "no step list: " .. joined(out))
  assertTrue(contains(out, "STARTED"), "still acknowledges the run")
  assertTrue(P.IsPanelShown(), "and the panel is up")
  assertTrue(#NS.DebugLog.buffer > 0, "with the run start in the console")
  perfReset()
  P.HidePanel()
end)

test("/at perf cancel abandons the run and closes the panel", function()
  perfReset()
  _G.AbsorbTrackerPerfDB = nil
  slash("perf start")
  slash("perf measure b")
  local out = slash("perf cancel")
  assertTrue(contains(out, "CANCELED"), "acknowledges: " .. joined(out))
  assertFalse(P.run, "run abandoned")
  assertFalse(P.suspended, "addon restored")
  assertEqual(_G.AbsorbTrackerPerfDB, nil, "and nothing was saved")
  perfReset()
end)

test("/at perf show, hide and toggle drive the panel without touching the run", function()
  perfReset()
  slash("perf start")
  slash("perf hide")
  assertFalse(P.IsPanelShown(), "hidden")
  assertTrue(P.run, "run untouched")
  slash("perf show")
  assertTrue(P.IsPanelShown(), "shown")
  slash("perf toggle")
  assertFalse(P.IsPanelShown(), "toggled off")
  slash("perf toggle")
  assertTrue(P.IsPanelShown(), "toggled back on")
  perfReset()
  P.HidePanel()
end)

test("/at perf (bare) opens the panel — it is the entry point to a run", function()
  -- Reverses an earlier call that a status query should not move windows. With Start clickable in
  -- the panel, `/at perf` is how someone who remembers one command reaches all of them.
  perfReset()
  P.HidePanel()
  slash("perf")
  assertTrue(P.IsPanelShown(), "panel opened")
  assertEqual(P.PanelStateOf("start"), "ready", "with Start ready to click")
  P.HidePanel()
end)

test("/at perf then clicking Start runs a whole run without another typed command", function()
  perfReset()
  P.HidePanel()
  slash("perf")
  local f = P.__panel()
  f.buttons.start:__fire("OnClick")
  assertTrue(P.run, "started from the panel")
  assertEqual(P.PanelStateOf("measureA"), "ready", "and Measure A is next")
  slash("perf cancel")
  perfReset()
  P.HidePanel()
end)

test("a panel click reaches chat through this addon's print sink, like typing does", function()
  -- The panel has no slash layer behind it, so the lib prints OnCommand's lines itself — through
  -- the `print` hook core/PerfSetup.lua hands it. Wired to the wrong sink (or to none) a click
  -- would silently produce less chat than the identical typed command; here Start's whole
  -- acknowledgment went missing.
  perfReset()
  P.HidePanel()
  local typed = slash("perf start")
  perfReset()
  P.HidePanel()
  slash("perf")
  local clicked = capture(function() P.__panel().buttons.start:__fire("OnClick") end)
  for i, line in ipairs(clicked) do clicked[i] = stripColor(line) end
  assertEqual(joined(clicked), joined(typed), "click and type must say the same thing")
  slash("perf cancel")
  perfReset()
  P.HidePanel()
end)

test("the perf usage block documents show/hide/toggle", function()
  perfReset()
  local out = slash("perf")
  assertTrue(contains(out, "toggle"), "listed: " .. joined(out))
  assertTrue(contains(out, "never touches the run"), "and says hiding is non-destructive")
end)

test("/at perf cancel says so when there is nothing to cancel", function()
  perfReset()
  local out = slash("perf cancel")
  assertTrue(contains(out, "no perf run to cancel"), joined(out))
end)

test("the perf usage block documents cancel", function()
  perfReset()
  local out = slash("perf")
  assertTrue(contains(out, "cancel"), "listed: " .. joined(out))
  assertTrue(contains(out, "discards it unsaved"), "and says it does not save")
end)

test("/at perf start announces to the console with debug logging OFF", function()
  perfReset()
  local wasOn = NS.State.debug
  NS.State.debug = false
  NS.DebugLog:Clear()
  slash("perf start")
  NS.State.debug = wasOn
  assertTrue(#NS.DebugLog.buffer > 0, "perf output is ungated")
  perfReset()
end)

test("/at perf no longer offers suspend or resume", function()
  -- Vestigial once `measure b` handles the suspend itself. `finish` resumes before it saves or
  -- formats anything, so no failure downstream can strand the addon inert, and /reload remains the
  -- universal escape.
  perfReset()
  local usage = slash("perf")
  assertEqual(joined(usage):find("suspend|resume", 1, true), nil, "gone from the usage line")
  local out = slash("perf suspend")
  assertTrue(contains(out, "usage: "), "unknown sub falls back to usage: " .. joined(out))
  assertFalse(P.suspended, "and did not suspend anything")
end)

test("/at perf finish resumes before it saves, so a later error cannot strand the addon", function()
  perfReset()
  _G.AbsorbTrackerPerfDB = nil
  slash("perf start")
  slash("perf measure b")
  slash("perf finish")
  assertFalse(P.suspended, "addon restored")
  assertEqual(#_G.AbsorbTrackerPerfDB.runs, 1, "and the run still saved")
  _G.AbsorbTrackerPerfDB = nil
  perfReset()
end)

test("/at perf report opens the debug console when it is hidden", function()
  -- Output lands in the console. With it hidden the user clicks Report, sees nothing, and has no
  -- reason to suspect a window they never opened.
  perfReset()
  slash("perf start")
  NS.DebugLog:Hide()
  assertFalse(NS.DebugLog:IsShown(), "console hidden")
  slash("perf report")
  assertTrue(NS.DebugLog:IsShown(), "report opened it")
  perfReset()
end)

test("/at perf report marks itself reviewed exactly once", function()
  -- One review step since v1.29.0: `dump` had its own mark and its own panel row, and both folded
  -- into this one. The console-opening half is covered by the report case above, which is where it
  -- belonged all along -- it was never about which verb was typed.
  perfReset()
  slash("perf start")
  slash("perf finish")
  slash("perf report")
  assertTrue(P.__reviewed().report, "marked")
  assertFalse(P.MarkReviewed("report"), "and only once")
  assertTrue(P.__reviewed().dump == nil, "the dump mark is back")
  perfReset()
end)
