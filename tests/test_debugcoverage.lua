-- tests/test_debugcoverage.lua — the debug log's coverage (debug-logging-§8) and its quiet steady
-- state (debug-logging-§9).
--
-- The 060 audit (DL-AT-02) added the lines a support read of a pasted log needs beyond the flows:
-- the addon's own stand-down and stand-up edges, the loading-screen kind, the combat re-lock, the
-- readable/secret edge of the absorb read, each held and flushed `/at debug hold`, the refusals
-- that name their guard, the dependency and enable state in the [Init] summary, and a caught
-- error once per distinct message. Each case below pins one of those, with what goes red without it.
--
-- The other half is §9's quiet steady state: a repeating path must not log when nothing it reports
-- changed. Every repeating path this addon has is exercised N times with no change and must append
-- nothing (or, for the secret edge, exactly its one line).
--
-- Runs after test_diagnostics, on the shared environment, and puts back what it changes: the
-- enable flag, the lock, the debug flag, the kit's bad-event table and the rejected list.

local T = _G.AT_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

--- The debug lines `fn` appends, with logging on for its duration.
local function debugLines(fn)
  local before = #NS.DebugLog.buffer
  NS.State.debug = true
  local ok, err = pcall(fn)
  NS.State.debug = false
  if not ok then error(err, 0) end
  local out = {}
  for i = before + 1, #NS.DebugLog.buffer do out[#out + 1] = NS.DebugLog.buffer[i] end
  return out
end

local function joined(lines) return table.concat(lines, " | ") end

--- How many of `lines` contain `needle` (plain find).
local function count(lines, needle)
  local n = 0
  for _, l in ipairs(lines) do
    if l:find(needle, 1, true) then n = n + 1 end
  end
  return n
end

--- Run a slash line with chat swallowed.
local function slash(line)
  local cf = M.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function() end
  local ok, err = pcall(NS.Slash.OnSlash, NS.Slash, line)
  cf.AddMessage = old
  if not ok then error(err, 0) end
end

--- Run `fn` with the addon disabled, and bring it back up whatever happens.
local function whileDisabled(fn)
  NS.SetByPath("enabled", false)
  local ok, err = pcall(fn)
  NS.SetByPath("enabled", true)
  M.__fireTimers()
  if not ok then error(err, 0) end
end

-- ── state edges ────────────────────────────────────────────────────────────────────────────

test("coverage: a stand-down and a stand-up are the library's one [Lifecycle] line each, naming the holds", function()
  -- red under: dropping `debug` from the Lifecycle descriptor in core/Lifecycle.lua (Lifecycle
  -- minor 3 then writes nothing), or a host line of its own naming the edge again. Without the edge
  -- a log from a player who switched the addon off shows bars vanishing and no reason why.
  NS.SetByPath("enabled", true)
  local down = debugLines(function() NS.SetByPath("enabled", false) end)
  local up = debugLines(function() NS.SetByPath("enabled", true) end)
  M.__fireTimers()
  assertEqual(count(down, "[Lifecycle] stood down: added disabled (holds: disabled)"), 1, joined(down))
  assertEqual(count(up, "[Lifecycle] stood up: released disabled (holds: none)"), 1, joined(up))
  -- One line per edge: the host's [Life] lines say what the teardown and the rebuild found, and
  -- never the edge or the holds a second time.
  assertEqual(count(down, "[Life] stood down"), 0, "the edge once: " .. joined(down))
  assertEqual(count(down, "holds:"), 1, "the holds once: " .. joined(down))
  assertEqual(count(up, "[Life] stood up"), 0, "the edge once: " .. joined(up))
  assertEqual(count(up, "[Life] rebuild from current state:"), 1, joined(up))
end)

test("coverage: a hold that fires no edge writes no [Lifecycle] line", function()
  -- red under: a host line written from SyncEnabledHold on every call. Re-taking a held hold, or
  -- releasing one that is not held, moves nothing, so nothing is said (Lifecycle minor 3).
  NS.SetByPath("enabled", true)
  local lines = debugLines(function()
    NS.SyncEnabledHold()
    NS.SyncEnabledHold()
  end)
  assertEqual(count(lines, "[Lifecycle]"), 0, joined(lines))
  assertEqual(count(lines, "[Life]"), 0, joined(lines))
end)

test("coverage: the stand-down line says whether it dropped a queued repaint", function()
  -- red under: StandDown discarding CancelPendingRepaint's answer (the line would always say no).
  NS.SetByPath("enabled", true)
  M.__fireTimers()
  NS.RequestRepaint()
  assertTrue(NS.IsRepaintPending(), "a repaint is queued before the stand-down")
  local down = debugLines(function() NS.SetByPath("enabled", false) end)
  NS.SetByPath("enabled", true)
  M.__fireTimers()
  assertEqual(count(down, "[Life] teardown: pending repaint dropped=yes"), 1, joined(down))
end)

test("coverage: [World] names the loading screen's kind: login, reload or zone change", function()
  -- red under: the old bare `entering world` line, which reads the same for all three.
  local lines = debugLines(function()
    NS.addon:OnEnterWorld("PLAYER_ENTERING_WORLD", true, false)
    NS.addon:OnEnterWorld("PLAYER_ENTERING_WORLD", false, true)
    NS.addon:OnEnterWorld("PLAYER_ENTERING_WORLD", false, false)
  end)
  M.__fireTimers()
  assertEqual(count(lines, "[World] entering world (login)"), 1, joined(lines))
  assertEqual(count(lines, "[World] entering world (reload)"), 1, joined(lines))
  assertEqual(count(lines, "[World] entering world (zone change)"), 1, joined(lines))
end)

test("coverage: entering combat unlocked says the bars were re-locked", function()
  -- red under: logging a bare `entered` on both branches of OnEnterCombat.
  T.rawSet("locked", false)
  local lines = debugLines(function() NS.addon:OnEnterCombat() end)
  local plain = debugLines(function() NS.addon:OnEnterCombat() end)
  M.__fireTimers()
  assertEqual(count(lines, "[Combat] entered: bars re-locked"), 1, joined(lines))
  assertEqual(count(plain, "re-locked"), 0, "already locked: " .. joined(plain))
  assertEqual(count(plain, "[Combat] entered"), 1, joined(plain))
end)

--- A combat secret as far as a headless run can make one: it survives `..`, and raises on every
--- comparison, so a trace that compared it would fail here.
local function secret()
  local function refuse() error("attempted arithmetic or comparison on a secret value", 2) end
  return setmetatable({}, {
    __concat = function() return "secret-propagated" end,
    __lt = refuse, __le = refuse, __add = refuse, __sub = refuse, __mul = refuse,
    __div = refuse, __unm = refuse,
  })
end

test("quiet: the absorb read's secret edge is one line each way, however many events", function()
  -- red under: logging the secret state per event (twenty lines here) or not at all (a Mythic+ log
  -- with no [Absorb] line and nothing saying why). The one-line-per-edge is debug-logging-§9's
  -- quiet steady state on the addon's highest-frequency path.
  local saved = M.UnitGetTotalAbsorbs
  local s = secret()
  -- Settle on a readable value first: the edge is the console's DebugChanged gate now, so the first
  -- readable observation after a Clear or an enable states itself once (AT-08), and that one line
  -- is not what this case counts.
  debugLines(function()
    M.UnitGetTotalAbsorbs = function() return 5000 end
    NS.addon:OnAbsorbChanged(nil, "player")
  end)
  local lines = debugLines(function()
    M.UnitGetTotalAbsorbs = function() return s end
    for _ = 1, 20 do NS.addon:OnAbsorbChanged(nil, "player") end
    M.UnitGetTotalAbsorbs = function() return 5000 end
    for _ = 1, 20 do NS.addon:OnAbsorbChanged(nil, "player") end
  end)
  M.UnitGetTotalAbsorbs = saved
  M.__fireTimers()
  assertEqual(count(lines, "[Absorb] reads secret"), 1, joined(lines))
  assertEqual(count(lines, "[Absorb] reads readable"), 1, joined(lines))
  assertEqual(#lines, 2, "nothing else on an unchanged value: " .. joined(lines))
end)

test("coverage: the console's Clear re-arms the absorb read's secret edge", function()
  -- red under: a hand-rolled memo in core/AbsorbTracker.lua's traceAbsorb in place of the console's
  -- DebugChanged (debug-logging-§9, AT-A-09). A reader who cleared the console mid-key and
  -- reproduced saw no [Absorb] line at all and nothing saying why.
  local saved = M.UnitGetTotalAbsorbs
  local s = secret()
  M.UnitGetTotalAbsorbs = function() return s end
  local ok, err = pcall(function()
    debugLines(function() NS.addon:OnAbsorbChanged(nil, "player") end)   -- spend the edge
    local spent = debugLines(function() NS.addon:OnAbsorbChanged(nil, "player") end)
    assertEqual(count(spent, "[Absorb] reads secret"), 0, "still gated: " .. joined(spent))
    NS.DebugLog:Clear()
    local rearmed = debugLines(function() NS.addon:OnAbsorbChanged(nil, "player") end)
    assertEqual(count(rearmed, "[Absorb] reads secret"), 1, joined(rearmed))
  end)
  M.UnitGetTotalAbsorbs = function() return 5000 end
  debugLines(function() NS.addon:OnAbsorbChanged(nil, "player") end)     -- leave it readable
  M.UnitGetTotalAbsorbs = saved
  M.__fireTimers()
  if not ok then error(err, 0) end
end)

test("coverage: the console's Clear re-arms the bar visibility line", function()
  -- red under: the hand-rolled `show ~= dbgLastShown[unit]` memo in modules/Display.lua's
  -- NS.ApplyVisibility (debug-logging-§9, AT-A-09): the bar's state was never restated after a
  -- Clear, so a fresh log began with no [Bar] line for a bar that was plainly on screen.
  NS.SetByPath("enabled", true)
  M.__fireTimers()
  debugLines(function() NS.ApplyVisibility("player") end)                 -- spend the key
  local spent = debugLines(function() NS.ApplyVisibility("player") end)
  assertEqual(count(spent, "[Bar] player:"), 0, "still gated: " .. joined(spent))
  NS.DebugLog:Clear()
  local rearmed = debugLines(function() NS.ApplyVisibility("player") end)
  assertEqual(count(rearmed, "[Bar] player:"), 1, joined(rearmed))
end)

test("quiet: the repaint throttle, the swap and max-health events and the ladder log nothing unchanged", function()
  -- red under: any per-pass line on these paths. Each fires many times a second in combat, and a
  -- line per pass (even one the console folds into `(xN)`) evicts the lines that matter from the
  -- 3000-line buffer before the reporter reaches Copy (debug-logging-§9, anti-patterns #91).
  NS.SetByPath("enabled", true)
  M.__fireTimers()
  -- Settle the [Bar] gates first, with logging ON: the line is the console's DebugChanged gate,
  -- which remembers only what it wrote, so the first logged pass states each bar once (AT-08).
  debugLines(function() NS.ForEachUnit(NS.ApplyVisibility) end)
  local lines = debugLines(function()
    for _ = 1, 10 do
      NS.RequestRepaint()
      M.__fireTimers()
      NS.addon:OnMaxHealthChanged("UNIT_MAXHEALTH", "player")
      NS.ForEachUnit(NS.ApplyVisibility)
      M.__fireTimers()
    end
  end)
  assertEqual(#lines, 0, "steady state appended: " .. joined(lines))
end)

-- ── deferred work ──────────────────────────────────────────────────────────────────────────

test("coverage: a /at debug hold logs when it holds live repaints and when it lets them go", function()
  -- red under: dropping either line in modules/Display.lua. A held-then-never-flushed hold is what
  -- a "the bar froze on a number" report looks like, and the pair is the evidence (§8).
  local expired = debugLines(function()
    NS.HoldPreview(5)
    M.__now = M.__now + 6
    M.__fireTimers()
  end)
  assertEqual(count(expired, "[Bar] hold: live repaints held for 5 s"), 1, joined(expired))
  assertEqual(count(expired, "[Bar] hold expired"), 1, joined(expired))
  assertEqual(count(expired, "cleared early"), 0, "an expiry is not an early clear: " .. joined(expired))

  local early = debugLines(function()
    NS.HoldPreview(5)
    NS.ClearPreview()
  end)
  M.__fireTimers()
  assertEqual(count(early, "[Bar] hold cleared early"), 1, joined(early))
end)

-- ── refusals name their guard ──────────────────────────────────────────────────────────────

test("coverage: an in-combat unlock refusal names the guard", function()
  -- red under: dropping the [Set] refusal line in settings/General.lua; the log then shows an
  -- unlock and a re-lock back to back with nothing saying why.
  T.rawSet("locked", true)
  local saved = M.InCombatLockdown
  M.InCombatLockdown = function() return true end
  local ok, lines = pcall(debugLines, function() NS.SetByPath("locked", false) end)
  M.InCombatLockdown = saved
  M.__fireTimers()
  assertTrue(ok, tostring(lines))
  assertEqual(count(lines, "[Set] locked: unlock refused (in combat)"), 1, joined(lines))
end)

test("coverage: a verb the disabled gate refuses is the library's one [Cmd] line; help is not a refusal", function()
  -- red under: dropping `debug` from the Slash descriptor (settings/Slash.lua; Slash minor 18 then
  -- writes nothing), or a host line of its own for the same refusal, such as the old match of the
  -- gate's chat line against DisabledLine, which would make the refusal two lines.
  local refused, help, alias
  whileDisabled(function()
    refused = debugLines(function() slash("toggle") end)
    help = debugLines(function() slash("help") end)
    alias = debugLines(function() slash("TOGGLE") end)
  end)
  assertEqual(count(refused, "[Cmd] refused toggle: disabled"), 1, joined(refused))
  assertEqual(count(refused, "refused"), 1, "one refusal line, not two: " .. joined(refused))
  assertEqual(count(alias, "[Cmd] refused toggle: disabled"), 1, "the verb as dispatched: " .. joined(alias))
  assertEqual(count(help, "refused"), 0, joined(help))
end)

test("coverage: the dispatcher's other refusals land as the library's [Cmd] lines", function()
  -- red under: dropping `debug` from the Slash descriptor. An unknown verb and a set the parser
  -- refuses reached chat only before Slash minor 18.
  local unknown = debugLines(function() slash("nosuchverb") end)
  assertEqual(count(unknown, "[Cmd] refused nosuchverb: unknown verb"), 1, joined(unknown))
  local usage = debugLines(function() slash("get") end)
  assertEqual(count(usage, "[Cmd] refused get: usage"), 1, joined(usage))
  local missing = debugLines(function() slash("get no.such.path") end)
  assertEqual(count(missing, "[Cmd] refused get no.such.path: not found"), 1, joined(missing))
end)

test("coverage: with logging off, a refusal writes nothing to the console", function()
  -- red under: a Slash sink that bypassed the gate (a bare D:Add rather than NS.Debug).
  NS.State.debug = false
  local before = #NS.DebugLog.buffer
  whileDisabled(function() slash("toggle") end)
  slash("nosuchverb")
  assertEqual(#NS.DebugLog.buffer, before, "nothing appended with logging off")
end)

test("coverage: /at debug hold names which guard refused it, once", function()
  -- red under: dropping any of the three [Cmd] lines in runHold.
  local disabled
  whileDisabled(function()
    disabled = debugLines(function() slash("debug hold 5000") end)
  end)
  assertEqual(count(disabled, "[Cmd] debug hold refused: addon disabled"), 1, joined(disabled))
  assertEqual(count(disabled, "refused"), 1, "one refusal line, not two: " .. joined(disabled))
  local bad = debugLines(function() slash("debug hold 5000 99") end)
  assertEqual(count(bad, "[Cmd] debug hold refused: bad arguments"), 1, joined(bad))
  local unknown = debugLines(function() slash("toggle nosuchunit") end)
  assertEqual(count(unknown, "[Cmd] toggle refused: unknown unit 'nosuchunit'"), 1, joined(unknown))
end)

-- ── dependencies and enable state, once, in [Init] ────────────────────────────────────────

--- The [Init] line `/at debug on` writes, with MissingLibraries answering `missing`.
local function initLine(missing)
  local D = NS.Diagnostics
  local real = D.MissingLibraries
  D.MissingLibraries = function() return missing end
  local before = #NS.DebugLog.buffer
  local ok, err = pcall(NS.DebugLog.SetEnabled, NS.DebugLog, true)
  NS.DebugLog:SetEnabled(false)
  D.MissingLibraries = real
  if not ok then error(err, 0) end
  for i = before + 1, #NS.DebugLog.buffer do
    local l = NS.DebugLog.buffer[i]
    if l:find("[Init]", 1, true) then return l end
  end
  return nil
end

local function quietly(fn)
  local cf = M.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function() end
  local ok, res = pcall(fn)
  cf.AddMessage = old
  if not ok then error(res, 0) end
  return res
end

test("coverage: [Init] names missing libraries and a stood-down addon, and nothing on a clean one", function()
  -- red under: dropping initSuffix's two new parts (core/DebugLogSetup.lua). The flag is off at
  -- login, so the moment logging is switched on is the one place a dependency or the addon's own
  -- enable state can be said once (debug-logging-§8).
  NS.SetByPath("enabled", true)
  local clean = quietly(function() return initLine({}) end)
  assertTrue(clean ~= nil, "an [Init] line was written")
  assertEqual(clean:find("missing libraries", 1, true), nil, clean)
  assertEqual(clean:find("stood down", 1, true), nil, clean)

  local missing = quietly(function() return initLine({ "LibDBIcon-1.0" }) end)
  assertTrue(missing:find("missing libraries: LibDBIcon-1.0", 1, true) ~= nil, missing)

  local down
  whileDisabled(function() down = quietly(function() return initLine({}) end) end)
  assertTrue(down:find("stood down (holds: disabled)", 1, true) ~= nil, down)
end)

test("coverage: the real MissingLibraries answers an array the ui section and [Init] share", function()
  local list = NS.Diagnostics.MissingLibraries()
  assertEqual(type(list), "table")
  assertTrue(list ~= NS.Diagnostics.MissingLibraries(), "a fresh array each call")
end)

-- ── caught errors, once per distinct error ─────────────────────────────────────────────────

test("coverage: a refused event name is one [Events] line, however many syncs refuse it", function()
  -- red under: noteRejected logging on every refusal (core/AbsorbTracker.lua). SyncUnitEventFrames
  -- runs on every UNITS message, so a retired name would otherwise log on every toggle.
  local lines = debugLines(function()
    M.__badEvents = { UNIT_MAXHEALTH = true }
    for _ = 1, 5 do
      for _, f in pairs(NS.addon.__unitEventFrames or {}) do f:UnregisterAllEvents() end
      NS.addon:SyncUnitEventFrames()
    end
  end)
  M.__badEvents = {}
  local list = NS.State.rejectedEvents
  for i = #list, 1, -1 do list[i] = nil end
  NS.addon:SyncUnitEventFrames()
  assertEqual(count(lines, "[Events] rejected UNIT_MAXHEALTH"), 1, joined(lines))
end)

--- One refusal pass of UNIT_MAXHEALTH, through the real SyncUnitEventFrames, then the kit's bad
--- table and the rejected list put back.
local function refuseMaxHealth(times)
  M.__badEvents = { UNIT_MAXHEALTH = true }
  for _ = 1, times do
    for _, f in pairs(NS.addon.__unitEventFrames or {}) do f:UnregisterAllEvents() end
    NS.addon:SyncUnitEventFrames()
  end
  M.__badEvents = {}
  local list = NS.State.rejectedEvents
  for i = #list, 1, -1 do list[i] = nil end
  NS.addon:SyncUnitEventFrames()
end

test("coverage: the console's Clear re-arms the refused-event gate", function()
  -- red under: a hand-rolled once-table in core/AbsorbTracker.lua in place of the console's
  -- DebugOnce (DebugLogGates 1). A reader who cleared the console and reproduced saw nothing and
  -- took it for nothing happening; the console's gate is re-armed by Clear.
  debugLines(function() refuseMaxHealth(2) end)          -- spend the key, whatever state it was in
  local spent = debugLines(function() refuseMaxHealth(2) end)
  assertEqual(count(spent, "[Events] rejected UNIT_MAXHEALTH"), 0, "still once: " .. joined(spent))
  NS.DebugLog:Clear()
  local rearmed = debugLines(function() refuseMaxHealth(3) end)
  assertEqual(count(rearmed, "[Events] rejected UNIT_MAXHEALTH"), 1, joined(rearmed))
end)

test("coverage: with logging off, a refused event spends nothing", function()
  -- red under: a gate that remembered the key with logging off, so the line never landed once the
  -- player turned logging on.
  NS.DebugLog:Clear()
  NS.State.debug = false
  refuseMaxHealth(2)
  local lines = debugLines(function() refuseMaxHealth(1) end)
  assertEqual(count(lines, "[Events] rejected UNIT_MAXHEALTH"), 1, joined(lines))
end)

test("coverage: a unit panel that raises on every render is one [Cfg] line per distinct error", function()
  -- red under: a bare NS.Debug in place of NS.DebugLog.DebugChanged (keyed by RENDER_ERROR_KEY) in
  -- settings/UnitPanel.lua (a panel that raises on every refresh would log once per refresh), or
  -- dropping the [Cfg] line (the error is chat-only).
  local H = NS.Helpers
  assertTrue(type(H.RenderUnitPanel) == "function", "the entry point is published")
  assertTrue(NS.AceGUI ~= nil, "AceGUI is loaded, so the render runs")
  local realClear = H.ClearScroll
  H.ClearScroll = function() error("planted render failure", 0) end
  local ok, lines = pcall(debugLines, function()
    quietly(function()
      for _ = 1, 3 do H.RenderUnitPanel({}, "appearance") end
    end)
  end)
  H.ClearScroll = realClear
  assertTrue(ok, tostring(lines))
  assertEqual(count(lines, "[Cfg] unit panel render failed (appearance): planted render failure"), 1,
    joined(lines))
end)

test("coverage: the console's Clear re-arms the unit panel's render-error gate", function()
  -- red under: the old lastRenderError upvalue in settings/UnitPanel.lua in place of the console's
  -- DebugChanged: after a Clear the same error stayed silent until a different one came along.
  local H = NS.Helpers
  local realClear = H.ClearScroll
  H.ClearScroll = function() error("planted render failure", 0) end
  local ok, res = pcall(function()
    debugLines(function() quietly(function() H.RenderUnitPanel({}, "appearance") end) end)
    local spent = debugLines(function() quietly(function() H.RenderUnitPanel({}, "appearance") end) end)
    NS.DebugLog:Clear()
    local rearmed = debugLines(function()
      quietly(function()
        for _ = 1, 3 do H.RenderUnitPanel({}, "appearance") end
      end)
    end)
    return { spent = spent, rearmed = rearmed }
  end)
  H.ClearScroll = realClear
  assertTrue(ok, tostring(res))
  assertEqual(count(res.spent, "[Cfg] unit panel render failed"), 0, "still once: " .. joined(res.spent))
  assertEqual(count(res.rearmed, "[Cfg] unit panel render failed (appearance): planted render failure"), 1,
    joined(res.rearmed))
end)

-- ── the Options major's combat lock (G3) ───────────────────────────────────────────────────

--- Run the Options library's combat hooks with `locked`: the edge that re-arms its refusal lines.
local function combatEdge(locked)
  local lib = M.LibStub("LibKa0s-Options-1.0")
  for hook in pairs(lib.__combatHooks) do hook(locked) end
end

test("coverage: a Defaults click refused in combat is the library's one [Cfg] line per combat", function()
  -- red under: dropping `debug` from the Options descriptor in settings/OptionsSetup.lua (Options
  -- minor 27 then writes nothing), a host line of its own for the same refusal, or a library that
  -- wrote the line once per click rather than once per combat.
  local H = NS.Helpers
  local saved = M.InCombatLockdown
  M.InCombatLockdown = function() return true end
  local ok, res = pcall(function()
    return quietly(function()
      combatEdge(true)   -- combat begins: whatever an earlier case spent is re-armed
      local first = debugLines(function() H.RestoreDefaults("appearance") end)
      local repeated = debugLines(function()
        H.RestoreDefaults("appearance")
        H.RestoreDefaults("appearance")
      end)
      return { first = first, repeated = repeated }
    end)
  end)
  M.InCombatLockdown = saved
  quietly(function() combatEdge(false) end)
  assertTrue(ok, tostring(res))
  assertEqual(count(res.first, "[Cfg] defaults appearance refused (in combat)"), 1, joined(res.first))
  assertEqual(count(res.first, "refused"), 1, "the library's line only, no host copy: " .. joined(res.first))
  assertEqual(#res.repeated, 0, "once per combat: " .. joined(res.repeated))
end)
