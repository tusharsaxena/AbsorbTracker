local T = _G.AT_TEST
local NS = T.NS
local test, assertTrue, assertFalse = T.test, T.assertTrue, T.assertFalse

-- Run `body` with specific hidden / showOnlyInCombat / in-combat state, then restore everything.
-- The loader binds WoW globals live through the mock table, so swapping mocks.InCombatLockdown is
-- seen by addon code (same pattern as tests/test_slash.lua).
local function withState(hidden, combatOnly, inCombat, body)
  local savedHidden     = NS.GetSetting("hidden")
  local savedCombatOnly = NS.GetSetting("showOnlyInCombat")
  local savedICL        = T.mocks.InCombatLockdown
  NS.SetSetting("hidden", hidden)
  NS.SetSetting("showOnlyInCombat", combatOnly)
  T.mocks.InCombatLockdown = function() return inCombat end
  local ok, err = pcall(body)
  NS.SetSetting("hidden", savedHidden)
  NS.SetSetting("showOnlyInCombat", savedCombatOnly)
  T.mocks.InCombatLockdown = savedICL
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
