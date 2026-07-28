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

-- ── Event wiring (core/AbsorbTracker.lua) — the two RegisterUnitEvent frames ────────

-- This is the ONLY coverage that events from non-tracked units never reach the handlers at all:
-- RegisterUnitEvent filters at the C level, tests/wow_mock.lua's stub can't simulate that
-- dispatch, so the guarantee has to be pinned as "these are the exact tokens registered, and no
-- others" instead. A widened filter (e.g. registering "player" alone, or adding a fourth unit)
-- would fail this test even though it can't fail via a direct OnAbsorbChanged/OnMaxHealthChanged
-- call.
test("EnsureUnitEventFrames registers exactly player+target on frame A and focus on frame B", function()
  -- Force a fresh pair so this test doesn't depend on whether OnEnable/EnsureUnitEventFrames ran
  -- earlier in the suite.
  NS.addon.__unitEventFrames = nil
  NS.addon:EnsureUnitEventFrames()
  local frameA, frameB = NS.addon.__unitEventFrames[1], NS.addon.__unitEventFrames[2]

  local function set(list)
    local seen = {}
    for _, u in ipairs(list or {}) do seen[u] = true end
    return seen
  end

  local aAbsorb, aHealth = frameA.__unitEvents.UNIT_ABSORB_AMOUNT_CHANGED,
                            frameA.__unitEvents.UNIT_MAXHEALTH
  local aAbsorbSet, aHealthSet = set(aAbsorb), set(aHealth)
  assertEqual(#aAbsorb, 2, "frame A registers exactly two units for UNIT_ABSORB_AMOUNT_CHANGED")
  assertEqual(#aHealth, 2, "frame A registers exactly two units for UNIT_MAXHEALTH")
  assertTrue(aAbsorbSet.player and aAbsorbSet.target and not aAbsorbSet.focus,
    "frame A is player+target only, never focus")
  assertTrue(aHealthSet.player and aHealthSet.target and not aHealthSet.focus,
    "frame A is player+target only, never focus")

  local bAbsorb, bHealth = frameB.__unitEvents.UNIT_ABSORB_AMOUNT_CHANGED,
                            frameB.__unitEvents.UNIT_MAXHEALTH
  local bAbsorbSet, bHealthSet = set(bAbsorb), set(bHealth)
  assertEqual(#bAbsorb, 1, "frame B registers exactly one unit for UNIT_ABSORB_AMOUNT_CHANGED")
  assertEqual(#bHealth, 1, "frame B registers exactly one unit for UNIT_MAXHEALTH")
  assertTrue(bAbsorbSet.focus and not bAbsorbSet.player and not bAbsorbSet.target,
    "frame B is focus only, never player or target")
  assertTrue(bHealthSet.focus and not bHealthSet.player and not bHealthSet.target,
    "frame B is focus only, never player or target")
end)

test("EnsureUnitEventFrames is idempotent — a second call leaves the same frame pair in place", function()
  NS.addon.__unitEventFrames = nil
  NS.addon:EnsureUnitEventFrames()
  local first = NS.addon.__unitEventFrames
  NS.addon:EnsureUnitEventFrames()
  assertTrue(NS.addon.__unitEventFrames == first, "a second call must not leak a second frame pair")
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

-- ── Debug coalescing (§9): [Combat] rollup + [Absorb] transitions ──────────────────
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
