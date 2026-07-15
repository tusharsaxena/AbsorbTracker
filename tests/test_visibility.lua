local T = _G.AT_TEST
local NS = T.NS
local test, assertTrue, assertFalse = T.test, T.assertTrue, T.assertFalse

-- Run `body` with specific hidden / showOnlyInCombat / in-combat state, then restore everything.
-- The loader binds WoW globals live through the mock table, so swapping the combat mocks is seen by
-- addon code (same pattern as tests/test_slash.lua). `inCombat` drives both combat predicates so
-- steady-state combat is modelled faithfully; the transition-timing gap between them is exercised
-- by the dedicated regression test below.
local function withState(hidden, combatOnly, inCombat, body)
  local savedHidden     = NS.GetSetting("hidden")
  local savedCombatOnly = NS.GetSetting("showOnlyInCombat")
  local savedICL        = T.mocks.InCombatLockdown
  local savedUAC        = T.mocks.UnitAffectingCombat
  NS.SetSetting("hidden", hidden)
  NS.SetSetting("showOnlyInCombat", combatOnly)
  T.mocks.InCombatLockdown    = function() return inCombat end
  T.mocks.UnitAffectingCombat = function() return inCombat end
  local ok, err = pcall(body)
  NS.SetSetting("hidden", savedHidden)
  NS.SetSetting("showOnlyInCombat", savedCombatOnly)
  T.mocks.InCombatLockdown    = savedICL
  T.mocks.UnitAffectingCombat = savedUAC
  if not ok then error(err) end
end

test("ShouldShowBar: hidden master toggle wins even in combat", function()
  withState(true, false, true, function()
    assertFalse(NS.ShouldShowBar(), "hidden=true is never shown")
  end)
end)

test("ShouldShowBar: default (not hidden, not combat-only) is shown", function()
  withState(false, false, false, function()
    assertTrue(NS.ShouldShowBar(), "default visibility is shown")
  end)
end)

test("ShouldShowBar: combat-only + in combat is shown", function()
  withState(false, true, true, function()
    assertTrue(NS.ShouldShowBar(), "showOnlyInCombat + in combat -> shown")
  end)
end)

test("ShouldShowBar: combat-only + out of combat is hidden", function()
  withState(false, true, false, function()
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

-- ── Combat wiring (core/AbsorbTracker.lua) ──────────────────────────────────────────
test("OnEnterCombat applies visibility and requests a repaint", function()
  local mocks = T.mocks
  mocks.__timers = {}
  local applied = 0
  local origApply = NS.ApplyVisibility
  NS.ApplyVisibility = function() applied = applied + 1 end
  NS.addon:OnEnterCombat()
  assertEqual(applied, 1)
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
  assertEqual(applied, 1)
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
