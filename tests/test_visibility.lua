local T = _G.AT_TEST
local NS = T.NS
local test, assertTrue, assertFalse = T.test, T.assertTrue, T.assertFalse

-- Run `body` with specific enabled / showOnlyInCombat / in-combat state, then restore everything.
-- The loader binds WoW globals live through the mock table, so swapping the combat mocks is seen by
-- addon code (same pattern as tests/test_slash.lua). `inCombat` drives both combat predicates so
-- steady-state combat is modeled faithfully; the transition-timing gap between them is exercised
-- by the dedicated regression test below.
--
-- The first argument used to be the global `hidden` master toggle; schema v4 dropped it, so it is
-- now the PLAYER's own `enabled` flag — the first step of the ladder in either case.
local function withState(enabled, combatOnly, inCombat, body)
  local savedEnabled    = NS.db.profile.units.player.enabled
  local savedCombatOnly = NS.GetSetting("showOnlyInCombat")
  local savedICL        = T.mocks.InCombatLockdown
  local savedUAC        = T.mocks.UnitAffectingCombat
  NS.db.profile.units.player.enabled = enabled
  NS.SetSetting("showOnlyInCombat", combatOnly)
  T.mocks.InCombatLockdown    = function() return inCombat end
  T.mocks.UnitAffectingCombat = function() return inCombat end
  local ok, err = pcall(body)
  NS.db.profile.units.player.enabled = savedEnabled
  NS.SetSetting("showOnlyInCombat", savedCombatOnly)
  T.mocks.InCombatLockdown    = savedICL
  T.mocks.UnitAffectingCombat = savedUAC
  if not ok then error(err) end
end

test("ShouldShowBar: a disabled unit wins even in combat", function()
  withState(false, false, true, function()
    assertFalse(NS.ShouldShowBar(), "enabled=false is never shown")
  end)
end)

test("ShouldShowBar: default (enabled, not combat-only) is shown", function()
  withState(true, false, false, function()
    assertTrue(NS.ShouldShowBar(), "default visibility is shown")
  end)
end)

test("ShouldShowBar: combat-only + in combat is shown", function()
  withState(true, true, true, function()
    assertTrue(NS.ShouldShowBar(), "showOnlyInCombat + in combat -> shown")
  end)
end)

test("ShouldShowBar: combat-only + out of combat is hidden", function()
  withState(true, true, false, function()
    assertFalse(NS.ShouldShowBar(), "showOnlyInCombat + out of combat -> hidden")
  end)
end)

-- Regression: at PLAYER_REGEN_DISABLED the client fires OnEnterCombat while InCombatLockdown() is
-- still false (secure lockdown lags actual combat by a fraction of a second), yet the player IS in
-- combat. The gate must key off UnitAffectingCombat("player"), not the secure-lockdown flag — else
-- the transition-time ApplyVisibility hides the bar and no later repaint ever re-shows it.
test("ShouldShowBar: combat-only shows when lockdown lags actual combat", function()
  local savedCombatOnly = NS.GetSetting("showOnlyInCombat")
  local savedICL        = T.mocks.InCombatLockdown
  local savedUAC        = T.mocks.UnitAffectingCombat
  NS.SetSetting("showOnlyInCombat", true)
  T.mocks.InCombatLockdown    = function() return false end          -- lockdown not yet flipped
  T.mocks.UnitAffectingCombat = function(unit) return unit == "player" end  -- but in combat
  local ok, err = pcall(function()
    assertTrue(NS.ShouldShowBar(), "in combat with lockdown still false -> shown")
  end)
  NS.SetSetting("showOnlyInCombat", savedCombatOnly)
  T.mocks.InCombatLockdown    = savedICL
  T.mocks.UnitAffectingCombat = savedUAC
  if not ok then error(err) end
end)

local assertEqual = T.assertEqual

-- ── Event wiring (core/AbsorbTracker.lua) — the per-unit RegisterUnitEvent frames ──

-- This is the ONLY coverage that events for units we do not track — or do not currently have a
-- bar for — never reach the handlers at all: RegisterUnitEvent filters at the C level and
-- tests/wow_mock.lua's stub cannot simulate that dispatch, so the guarantee is pinned as "these
-- are the exact tokens registered, and no others" instead. A widened filter, a dropped one, or a
-- disabled unit left registered all fail here even though none can fail via a direct
-- OnAbsorbChanged / OnMaxHealthChanged call.

-- Run `body` with an exact enabled-set applied and the registrations re-synced, then restore.
local function withEnabled(enabledByUnit, body)
  local saved = {}
  for _, unit in ipairs(NS.Units.LIST) do
    saved[unit] = NS.db.profile.units[unit].enabled
    NS.db.profile.units[unit].enabled = enabledByUnit[unit] and true or false
  end
  NS.addon:SyncUnitEventFrames()
  local ok, err = pcall(body)
  for _, unit in ipairs(NS.Units.LIST) do
    NS.db.profile.units[unit].enabled = saved[unit]
  end
  NS.addon:SyncUnitEventFrames()
  if not ok then error(err) end
end

local function tokensFor(unit, event)
  local frame = NS.addon.__unitEventFrames[unit]
  return frame and frame.__unitEvents[event]
end

test("SyncUnitEventFrames registers each enabled unit on its own frame, one token each", function()
  withEnabled({ player = true, target = true, focus = true }, function()
    for _, unit in ipairs(NS.Units.LIST) do
      for _, event in ipairs({ "UNIT_ABSORB_AMOUNT_CHANGED", "UNIT_MAXHEALTH" }) do
        local tokens = tokensFor(unit, event)
        assertTrue(tokens ~= nil, unit .. " is enabled but not registered for " .. event)
        assertEqual(#tokens, 1, unit .. "'s frame registers exactly one unit token for " .. event)
        assertEqual(tokens[1], unit, unit .. "'s frame must filter on " .. unit .. " alone")
      end
    end
  end)
end)

-- The point of the whole exercise: a bar you have turned off costs no event dispatch whatsoever.
test("a disabled unit is registered for nothing at all", function()
  withEnabled({ player = true, target = false, focus = false }, function()
    assertTrue(tokensFor("player", "UNIT_ABSORB_AMOUNT_CHANGED") ~= nil, "player stays registered")
    for _, unit in ipairs({ "target", "focus" }) do
      assertEqual(tokensFor(unit, "UNIT_ABSORB_AMOUNT_CHANGED"), nil,
        "a disabled " .. unit .. " must not be registered for absorb events")
      assertEqual(tokensFor(unit, "UNIT_MAXHEALTH"), nil,
        "a disabled " .. unit .. " must not be registered for max-health events")
    end
  end)
end)

test("enabling a unit registers it and disabling it again unregisters", function()
  withEnabled({ player = true, target = false, focus = false }, function()
    assertEqual(tokensFor("target", "UNIT_MAXHEALTH"), nil, "starts unregistered")
  end)
  withEnabled({ player = true, target = true, focus = false }, function()
    assertTrue(tokensFor("target", "UNIT_MAXHEALTH") ~= nil, "enabling registers it")
  end)
  withEnabled({ player = true, target = false, focus = false }, function()
    assertEqual(tokensFor("target", "UNIT_MAXHEALTH"), nil, "and disabling clears it again")
  end)
end)

-- PLAYER_TARGET_CHANGED fires constantly in ordinary play, so this is the registration whose
-- gating actually saves work — the absorb events were already C-filtered to units we asked for.
test("the target/focus swap events are registered only while that bar is enabled", function()
  withEnabled({ player = true, target = false, focus = false }, function()
    assertEqual(NS.addon.__events.PLAYER_TARGET_CHANGED, nil,
      "no target bar means no reason to watch target swaps")
    assertEqual(NS.addon.__events.PLAYER_FOCUS_CHANGED, nil)
  end)
  withEnabled({ player = true, target = true, focus = false }, function()
    assertTrue(NS.addon.__events.PLAYER_TARGET_CHANGED ~= nil, "enabling the target bar registers")
    assertEqual(NS.addon.__events.PLAYER_FOCUS_CHANGED, nil, "focus is still off, still unwatched")
  end)
  withEnabled({ player = true, target = true, focus = true }, function()
    assertTrue(NS.addon.__events.PLAYER_FOCUS_CHANGED ~= nil)
  end)
end)

test("SyncUnitEventFrames reuses its frames — a re-sync must not leak a new set", function()
  NS.addon:SyncUnitEventFrames()
  local first = NS.addon.__unitEventFrames
  local firstPlayer = first.player
  NS.addon:SyncUnitEventFrames()
  assertTrue(NS.addon.__unitEventFrames == first, "the frame table is reused")
  assertTrue(NS.addon.__unitEventFrames.player == firstPlayer, "and so is each unit's frame")
end)

-- The bus seam: the enable toggles and `/at toggle` publish UNITS rather than calling across the
-- module boundary, so the registrations follow the enabled set however it was changed.
test("the UNITS message re-syncs the registrations", function()
  local saved = NS.db.profile.units.focus.enabled
  NS.db.profile.units.focus.enabled = false
  NS.bus:SendMessage(NS.MSG.UNITS)
  assertEqual(tokensFor("focus", "UNIT_MAXHEALTH"), nil, "disabled focus is unregistered")

  NS.db.profile.units.focus.enabled = true
  NS.bus:SendMessage(NS.MSG.UNITS)
  assertTrue(tokensFor("focus", "UNIT_MAXHEALTH") ~= nil, "and re-registered when enabled")

  NS.db.profile.units.focus.enabled = saved
  NS.bus:SendMessage(NS.MSG.UNITS)
end)

-- ── Combat wiring (core/AbsorbTracker.lua) ──────────────────────────────────────────
test("OnEnterCombat applies visibility and requests a repaint", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local applied = 0
  local origApply = NS.ApplyVisibility
  NS.ApplyVisibility = function() applied = applied + 1 end
  NS.addon:OnEnterCombat()
  -- Task 4: the VISIBILITY message fans out over all three tracked units (NS.ForEachUnit), so
  -- one combat transition now re-evaluates the gate once per bar, not once total.
  assertEqual(applied, 3, "visibility is re-evaluated for player, target, and focus")
  assertEqual(#mocks.__timers, 1)   -- a repaint was requested
  NS.ApplyVisibility = origApply
  mocks.__fireTimers()
end)

test("OnLeaveCombat applies visibility and requests a repaint", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local applied = 0
  local origApply = NS.ApplyVisibility
  NS.ApplyVisibility = function() applied = applied + 1 end
  NS.addon:OnLeaveCombat()
  -- Task 4: same three-bar fan-out as OnEnterCombat above.
  assertEqual(applied, 3, "visibility is re-evaluated for player, target, and focus")
  assertEqual(#mocks.__timers, 1)   -- a repaint was requested
  NS.ApplyVisibility = origApply
  mocks.__fireTimers()
end)

-- options-ui-§2: the panel REFUSES to open in combat instead of deferring, so OnLeaveCombat must
-- never auto-open the config — even if a stale panelOpenPending flag is somehow present.
test("OnLeaveCombat never opens config, even with a stale panelOpenPending (options-ui-§2)", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local opened = 0
  local origOpen, origApply = NS.OpenOptionsPanel, NS.ApplyVisibility
  NS.OpenOptionsPanel = function() opened = opened + 1 end
  NS.ApplyVisibility = function() end
  NS.State.panelOpenPending = true
  NS.addon:OnLeaveCombat()
  assertEqual(opened, 0)
  NS.OpenOptionsPanel, NS.ApplyVisibility = origOpen, origApply
  mocks.__fireTimers()
  NS.State.panelOpenPending = nil
end)

-- ── Debug coalescing (debug-logging-§9): [Combat] rollup + [Absorb] transitions ────
test("combat rollup: OnLeaveCombat logs one [Combat] left summary with counts", function()
  local mocks = T.mocks
  NS.State.debug = true
  NS.addon:OnEnterCombat()                 -- resets counters
  NS.addon:OnAbsorbChanged(nil, "player")  -- +1 event
  NS.addon:OnAbsorbChanged(nil, "player")  -- +1 event
  NS.NoteRepaint()                         -- +1 repaint
  local before = #NS.DebugLog.buffer
  NS.addon:OnLeaveCombat()
  NS.State.debug = false
  local line
  for i = #NS.DebugLog.buffer, before, -1 do
    local l = NS.DebugLog.buffer[i]
    if l and l:find("[Combat]", 1, true) and l:find("left", 1, true) then line = l break end
  end
  assertTrue(line ~= nil, "a [Combat] left summary is logged")
  assertTrue(line:find("2 events", 1, true) ~= nil, "counts absorb events")
  assertTrue(line:find("1 repaints", 1, true) ~= nil, "counts repaints")
  mocks.__fireTimers()
end)

test("OnAbsorbChanged is silent on an unchanged value (no per-event spam)", function()
  local mocks = T.mocks
  local savedAbs = mocks.UnitGetTotalAbsorbs
  NS.State.debug = true
  mocks.UnitGetTotalAbsorbs = function() return 5000 end
  NS.addon:OnEnterCombat()
  NS.addon:OnAbsorbChanged(nil, "player")   -- establishes last=5000 (may log one transition)
  local before = #NS.DebugLog.buffer
  NS.addon:OnAbsorbChanged(nil, "player")   -- 5000 -> 5000: no transition, no line
  assertEqual(#NS.DebugLog.buffer, before)  -- silent when the value is unchanged
  mocks.UnitGetTotalAbsorbs = savedAbs
  NS.State.debug = false
  mocks.__fireTimers()
end)

test("[Absorb] transition logs on a non-secret 0->nonzero change", function()
  local mocks = T.mocks
  local savedAbs = mocks.UnitGetTotalAbsorbs
  NS.State.debug = true
  NS.addon:OnEnterCombat()
  mocks.UnitGetTotalAbsorbs = function() return 0 end
  NS.addon:OnAbsorbChanged(nil, "player")   -- establishes last = 0
  mocks.UnitGetTotalAbsorbs = function() return 5000 end
  local before = #NS.DebugLog.buffer
  NS.addon:OnAbsorbChanged(nil, "player")   -- 0 -> 5000 transition
  local last = NS.DebugLog.buffer[#NS.DebugLog.buffer]
  assertTrue(#NS.DebugLog.buffer > before and last:find("[Absorb]", 1, true) ~= nil
    and last:find("shield up", 1, true) ~= nil, "logs shield-up transition")
  mocks.UnitGetTotalAbsorbs = savedAbs
  NS.State.debug = false
  mocks.__fireTimers()
end)
