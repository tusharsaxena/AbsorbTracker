-- tests/test_diagnostics.lua — this addon's half of the diagnostics dump (debug-logging-§14).
--
-- What the report IS is shared: the markers, the identity header, the per-section pcall, the cap
-- and the truncated line are LibKa0s-DebugLog-1.0's helper (libs/LibKa0s/DebugLogDiagnostics.lua)
-- and are tested in that library's own suite. The dispatcher contract (both forms, while disabled,
-- append, ungated, the markers carrying our brand, `diag` not running it) is the kit's shared case,
-- tests/_kit/test_diagnostics_contract.lua, wired to this addon's dispatcher in tests/run.lua.
--
-- What is OURS, and what this file covers: the `diagnostics` row and the `debug diagnostics` word
-- as settings/Slash.lua spells them; the sections modules/Diagnostics.lua writes (DX-AT), and that
-- each of them reads state without changing it; the secret-value discipline on the absorb readout;
-- the stood-down wording; and the library-absent arm.

local T = _G.AT_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- ── helpers ────────────────────────────────────────────────────────────────────────────────

--- The report as `[tag] msg` lines, built as data (nothing reaches the console), plus the raw
--- result for the cap fields.
local function report(spec)
  local r = NS.DebugLog:BuildDiagnostics(spec)
  local lines = {}
  for i, l in ipairs(r.lines) do lines[i] = "[" .. l[1] .. "] " .. l[2] end
  return lines, r
end

local function joined(lines) return table.concat(lines, "\n  ") end

--- The first line holding `needle`, or nil.
local function find(lines, needle)
  for _, l in ipairs(lines) do
    if l:find(needle, 1, true) then return l end
  end
  return nil
end

--- The lines the helper wrote for a section that raised.
local function failures(lines)
  local out = {}
  for _, l in ipairs(lines) do
    if l:find("^%[Diag%] section .- failed:") then out[#out + 1] = l end
  end
  return out
end

--- A combat secret, as far as a headless run can make one: it survives `..` (as the client's do)
--- and RAISES on every comparison and every piece of arithmetic, so a report that so much as asks
--- whether it is zero fails here the way it would fail in a Mythic+ key.
local function secret()
  local function refuse() error("attempted arithmetic or comparison on a secret value", 2) end
  return setmetatable({}, {
    __concat = function() return "secret-propagated" end,
    __lt = refuse, __le = refuse, __add = refuse, __sub = refuse, __mul = refuse,
    __div = refuse, __unm = refuse,
  })
end

-- ── the command surface ─────────────────────────────────────────────────────────────────────

test("diagnostics: the row sits straight after debug and its text is routed through NS.L", function()
  -- debug-logging-§14 / slash-commands-§2: `diagnostics` is a reserved verb with its own COMMANDS
  -- row, and the help index reads it next to the console it writes into.
  -- red under: a missing row (the report reachable only as a debug word), a row somewhere else in
  -- the index, or a hardcoded description that bypasses the locale table.
  local debugAt, diagAt
  for i, entry in ipairs(NS.COMMANDS) do
    if entry[1] == "debug" then debugAt = i end
    if entry[1] == "diagnostics" then diagAt = i end
  end
  assertTrue(diagAt ~= nil, "NS.COMMANDS has a `diagnostics` row")
  assertEqual(diagAt, debugAt + 1, "straight after `debug`")
  local desc = NS.COMMANDS[diagAt][2]
  assertEqual(rawget(NS.L, desc), desc, "the description is a key locales/enUS.lua sets")
  assertTrue(NS.COMMANDS[debugAt][2]:find("`diagnostics`", 1, true) ~= nil,
    "the debug row names its diagnostics word: " .. NS.COMMANDS[debugAt][2])
end)

-- ── the sections (DX-AT) ────────────────────────────────────────────────────────────────────

-- One needle per fact DX-AT asks the report for. Per-unit needles are checked for all three bars.
local ONCE = {
  "[Diag] schema: stored=",
  "[Diag] profile: ",
  "[Diag] enabled (stored)=",
  "[Diag] test mode: none",
  "[Life] holds:",
  "[Life] perf: capturing=",
  "[Life] bus: ",
  "[Set] state.debugConsole = ",
  "[Events] AceEvent registered:",
  "[Repaint] pending=",
  "[Repaint] hold remaining=",
  "[Counters] since last combat start",
  "[UI] settings panel open=",
  "[UI] launcher: registered=",
  "[UI] libraries missing:",
  "[Events] rejected events:",
}

local PER_UNIT = {
  "[Unit] %s: enabled=",
  "[Frame] %s: shown=",
  "[Frame] %s: live point=",
  "[Frame] %s: handle=",
  "[Media] %s: barTexture=",
  "[Media] %s: bgTexture=",
  "[Media] %s: border=",
  "[Media] %s: font=",
  "[Color] %s: class=",
  "[Color] %s: bar=",
  "[Absorb] %s: absorb=",
  "[Events] %s frame:",
}

test("diagnostics: the report carries every DX-AT section, and none of them fails", function()
  -- red under: a section dropped from NS.Diagnostics.Sections, a section that raises in the
  -- headless client (it would cost its one line and every fact below it), or a report that grew
  -- past the < 150-line budget DX-AT sets.
  NS.SetByPath("enabled", true)
  local lines = report()
  assertEqual(#failures(lines), 0, "no section failed: " .. joined(failures(lines)))
  for _, needle in ipairs(ONCE) do
    assertTrue(find(lines, needle) ~= nil, "missing `" .. needle .. "` in:\n  " .. joined(lines))
  end
  for _, unit in ipairs(NS.Units.LIST) do
    for _, pattern in ipairs(PER_UNIT) do
      local needle = pattern:format(unit)
      assertTrue(find(lines, needle) ~= nil, "missing `" .. needle .. "` in:\n  " .. joined(lines))
    end
  end
  assertTrue(#lines < 150, "DX-AT's budget is under 150 lines, got " .. #lines)
end)

test("diagnostics: a changed setting prints as path = value (default), and the always rows print", function()
  -- DX-AT's always-print rows are the six flat globals and the minimap row; everything else prints
  -- only when it differs from its default. state.debugConsole is session-only, which the library's
  -- walk skips, so the section prints it on its own line.
  -- red under: a walk that prints every row (the report drowns), one that prints none, or an
  -- always list that lost a global.
  NS.SetByPath("scale", 1.5)
  local lines = report()
  NS.SetByPath("scale", 1)
  assertTrue(find(lines, "[Set] scale = 1.5 (1)") ~= nil, "the changed row: " .. joined(lines))
  for _, path in ipairs({ "enabled", "visibility", "alpha", "locked", "throttleWindow",
      "global.minimap.shown" }) do
    assertTrue(find(lines, "[Set] " .. path .. " = ") ~= nil, "always printed: " .. path)
  end
  assertTrue(find(lines, "[Set] units.player.barWidth = ") == nil,
    "an untouched row stays out of the report")
end)

test("diagnostics: a secret absorb prints as <secret> and costs no section", function()
  -- events-frames-taint-§8 / debug-logging-§14: in restricted content UnitGetTotalAbsorbs and
  -- UnitHealthMax answer secrets. The readout is gated by NS.IsConcatSafe and never compared,
  -- converted or abbreviated.
  -- red under: a `tonumber`, `<`, `==0` or arithmetic on the value; an AbbreviateNumbers call; a
  -- readout that prints the value without the gate.
  local absorbs, health = M.__absorbs.player, M.__maxHealth.player
  M.__absorbs.player, M.__maxHealth.player = secret(), secret()
  local ok, lines = pcall(report)
  M.__absorbs.player, M.__maxHealth.player = absorbs, health
  assertTrue(ok, "the report raised on a secret: " .. tostring(lines))
  assertEqual(#failures(lines), 0, "no section failed: " .. joined(failures(lines)))
  assertTrue(find(lines, "[Absorb] player: absorb=<secret> max health=<secret>") ~= nil,
    joined(lines))
end)

test("diagnostics: stood down, the released runtime state says so rather than printing empty", function()
  -- debug-logging-§14 (STD-05): the report runs while disabled, and a section whose state the
  -- stand-down released says it is stood down. The configuration still prints in full.
  -- red under: a report that refuses while disabled, or one that prints an empty registration set
  -- as if that were the live state of an enabled addon.
  NS.SetByPath("enabled", false)
  local lines = report()
  NS.SetByPath("enabled", true)
  assertEqual(#failures(lines), 0, "no section failed: " .. joined(failures(lines)))
  assertTrue(find(lines, "[Diag] enabled (stored)=false stood down=true") ~= nil, joined(lines))
  assertTrue(find(lines, "[Life] holds: disabled") ~= nil, joined(lines))
  assertTrue(find(lines, "[Events] stood down:") ~= nil, joined(lines))
  assertTrue(find(lines, "[Repaint] pending=stood down") ~= nil, joined(lines))
  assertTrue(find(lines, "[Unit] player: enabled=true") ~= nil, "configuration still prints")
end)

test("diagnostics: the report reads state and changes none of it", function()
  -- debug-logging-§14 (STD-05): no hold, no event, no timer, no stand-up, no settings panel, no
  -- Clear. Snapshotted around the REAL run, which writes into the console and prints its chat line.
  -- red under: a section that calls NS.RequestRepaint, OpenOptionsPanel, SyncUnitEventFrames or a
  -- setter; a report that clears the console first.
  NS.SetByPath("enabled", true)
  NS.DebugLog:Show()       -- shown first, so the reveal the report performs is not in the diff
  local registrations = #M.__registrations()
  local timers = #M.__timers
  local holds = table.concat(NS.lifecycle:Holds(), ",")
  local pending, debug = NS.IsRepaintPending(), NS.State.debug
  local opened, cleared = 0, 0
  local open, clear = NS.OpenOptionsPanel, NS.DebugLog.Clear
  NS.OpenOptionsPanel = function() opened = opened + 1 end
  NS.DebugLog.Clear = function(...) cleared = cleared + 1 return clear(...) end
  local ok, err = pcall(NS.DebugLog.RunDiagnostics, NS.DebugLog)
  NS.OpenOptionsPanel, NS.DebugLog.Clear = open, clear
  NS.DebugLog:Hide()
  assertTrue(ok, tostring(err))
  assertEqual(#M.__registrations(), registrations, "no registration made or dropped")
  assertEqual(#M.__timers, timers, "no timer armed")
  assertEqual(table.concat(NS.lifecycle:Holds(), ","), holds, "no hold taken or released")
  assertEqual(NS.IsRepaintPending(), pending, "the throttle is as it was")
  assertEqual(NS.State.debug, debug, "the debug flag is as it was")
  assertEqual(opened, 0, "the settings panel was not opened")
  assertEqual(cleared, 0, "the console was not cleared")
end)

test("diagnostics: the session's rejected events are folded into the report", function()
  -- `/at debug events` stays as a topic (debug-logging-§4's MAY); the report carries the same list,
  -- so a pasted report does not need a second command.
  -- red under: a report that leaves NS.State.rejectedEvents out.
  local list = NS.State.rejectedEvents
  list[#list + 1] = "AT_DIAGNOSTICS_PROBE_EVENT"
  local lines = report()
  list[#list] = nil
  assertTrue(find(lines, "AT_DIAGNOSTICS_PROBE_EVENT") ~= nil, joined(lines))
end)

test("diagnostics: a raising section costs exactly one line and the rest still print", function()
  -- debug-logging-§14 (STD-12): every section runs under its own pcall.
  -- red under: sections run in one pcall (a raise takes the rest of the report with it), or a
  -- host-side wrapper that swallows the raise without saying so.
  local real = NS.VisibilityReason
  NS.VisibilityReason = function() error("diagnostics probe raise") end
  local ok, lines = pcall(report)
  NS.VisibilityReason = real
  assertTrue(ok, tostring(lines))
  local failed = failures(lines)
  assertEqual(#failed, 1, "one line: " .. joined(failed))
  assertTrue(failed[1]:find("diagnostics probe raise", 1, true) ~= nil, failed[1])
  assertTrue(find(lines, "[Frame] focus: shown=") ~= nil, "the sections after it still ran")
end)

test("diagnostics: an over-cap report ends in the truncated line, then the end marker", function()
  -- red under: sections that write around the helper's writer (hand-rolled Add calls would not be
  -- counted or dropped), which is anti-pattern #90.
  local lines, r = report({ maxLines = 12 })
  assertTrue(r.capped, "the cap bit")
  assertTrue(lines[#lines - 1]:find("^%[Diag%] truncated: %d+ line%(s%) omitted") ~= nil,
    lines[#lines - 1])
  assertTrue(lines[#lines]:find(NS.Constants.BRAND .. " diagnostics end: 12 line(s)", 1, true)
    ~= nil, lines[#lines])
end)

test("diagnostics: the chat line is ours to localize and names the line count", function()
  -- debug-logging-§14 (STD-09 / STD-13): the one chat line is localized; the report body is not.
  -- The descriptor hands the library's DIAG_WRITTEN key a string from NS.L, never NS.L itself
  -- (tests/test_ltrap.lua).
  -- red under: dropping the descriptor's `L` entry (the line would still read, but no longer from
  -- this addon's locale table), or a second chat line.
  local key = "Diagnostic report written to the debug console: %d lines. Use Copy to share it."
  assertEqual(rawget(NS.L, key), key, "locales/enUS.lua sets the key")
  assertEqual(NS.DebugLog:Text("DIAG_WRITTEN"), key, "the descriptor routes it to the library")
  M.__resetPrinted()
  local n = NS.DebugLog:RunDiagnostics()
  NS.DebugLog:Hide()
  local out = {}
  for _, line in ipairs(M.__printed()) do
    if line:find("Diagnostic report", 1, true) then out[#out + 1] = line end
  end
  assertEqual(#out, 1, "one chat line: " .. table.concat(M.__printed(), " / "))
  assertTrue(out[1]:find(key:format(n), 1, true) ~= nil, out[1])
end)

test("diagnostics: with the library absent both forms print the one absent line", function()
  -- debug-logging-§14 (STD-14). The sections module loads without the library, and the degraded
  -- dispatcher routes both forms to the DebugLog stub, which says what is missing.
  -- red under: a degraded load that raises in modules/Diagnostics.lua, or a form that goes silent.
  local NS2, M2 = dofile("tests/degraded_env.lua")()
  assertEqual(type(NS2.Diagnostics and NS2.Diagnostics.Sections), "function",
    "modules/Diagnostics.lua loaded without the library")
  assertEqual(type(NS2.Diagnostics.Sections()), "table")
  local want = "/at diagnostics is unavailable: the LibKa0s library did not load."
  for _, form in ipairs({ "diagnostics", "debug diagnostics" }) do
    M2.__resetPrinted()
    NS2.Slash:OnSlash(form)
    local hits = 0
    for _, line in ipairs(M2.__printed()) do
      if line:find(want, 1, true) then hits = hits + 1 end
    end
    assertEqual(hits, 1, "/at " .. form .. ": " .. table.concat(M2.__printed(), " / "))
  end
  assertFalse(NS2.DebugLog:DebugVerb("events"), "the stub leaves the topic words to the host")
end)
