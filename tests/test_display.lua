local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- modules/Display.lua — the paint path: position restore, the appearance apply (size / textures /
-- backdrop insets / lock), and the absorb repaint with its two early-outs.
--
-- The mock frames answer every PascalCase method from a metatable no-op, so nothing is recorded by
-- default. `spy` rawsets a recorder over one method for the duration of a call and rawsets it back
-- to nil afterwards, which restores the metatable fallthrough.

local function spy(frame, method)
  local calls = {}
  rawset(frame, method, function(_, ...) calls[#calls + 1] = { ... } return frame end)
  return calls, function() rawset(frame, method, nil) end
end

-- Capture every call to `method` made while `body` runs.
local function record(frame, method, body)
  local calls, restore = spy(frame, method)
  local ok, err = pcall(body)
  restore()
  if not ok then error(err) end
  return calls
end

local function withSetting(key, value, body)
  local saved = NS.GetSetting(key)
  NS.SetSetting(key, value)
  local ok, err = pcall(body)
  NS.SetSetting(key, saved)
  if not ok then error(err) end
end

-- Same shape as withSetting, but targets a per-unit config table directly (units.<unit>.<key>)
-- rather than a flat/dotted NS.GetSetting path.
local function withUnitSetting(unit, key, value, body)
  local c = NS.db.profile.units[unit]
  local saved = c[key]
  c[key] = value
  local ok, err = pcall(body)
  c[key] = saved
  if not ok then error(err) end
end

-- ── RestoreBarPosition ─────────────────────────────────────────────────────────────

test("RestoreBarPosition centers the bar when no position is saved", function()
  local saved = NS.db.profile.units.player.position
  NS.db.profile.units.player.position = nil
  local calls = record(NS.bar, "SetPoint", NS.RestoreBarPosition)
  NS.db.profile.units.player.position = saved
  assertEqual(#calls, 1)
  assertEqual(calls[1][1], "CENTER")
  assertEqual(calls[1][2], T.mocks.UIParent, "the default anchor is relative to UIParent")
  assertEqual(calls[1][3], "CENTER")
  assertEqual(calls[1][4], 0)
  assertEqual(calls[1][5], 0)
end)

test("RestoreBarPosition restores the saved anchor verbatim", function()
  local saved = NS.db.profile.units.player.position
  NS.db.profile.units.player.position = { point = "TOPLEFT", relPoint = "BOTTOMRIGHT", x = 12, y = -34 }
  local calls = record(NS.bar, "SetPoint", NS.RestoreBarPosition)
  NS.db.profile.units.player.position = saved
  assertEqual(#calls, 1)
  assertEqual(calls[1][1], "TOPLEFT")
  assertEqual(calls[1][2], T.mocks.UIParent, "a saved anchor is still relative to UIParent")
  assertEqual(calls[1][3], "BOTTOMRIGHT")
  assertEqual(calls[1][4], 12)
  assertEqual(calls[1][5], -34)
end)

test("RestoreBarPosition clears the old anchors before re-anchoring", function()
  -- Without the ClearAllPoints the new SetPoint stacks on top of the old one and the bar ends up
  -- stretched between two anchors instead of moved.
  local calls = record(NS.bar, "ClearAllPoints", NS.RestoreBarPosition)
  assertEqual(#calls, 1)
end)

-- ── UpdateBarAppearance ────────────────────────────────────────────────────────────

test("UpdateBarAppearance sizes the bar from the profile", function()
  local calls
  withUnitSetting("player", "barWidth", 260, function()
    withUnitSetting("player", "barHeight", 24, function()
      calls = record(NS.bar, "SetSize", NS.UpdateBarAppearance)
    end)
  end)
  assertEqual(#calls, 1)
  assertEqual(calls[1][1], 260)
  assertEqual(calls[1][2], 24)
end)

test("UpdateBarAppearance derives the backdrop inset from borderSize (floor of a quarter)", function()
  withUnitSetting("player", "borderSize", 12, function()
    NS.UpdateBarAppearance()
    assertEqual(NS.backdropInfo.edgeSize, 12)
    assertEqual(NS.backdropInfo.insets.left, 3)
    assertEqual(NS.backdropInfo.insets.right, 3)
    assertEqual(NS.backdropInfo.insets.top, 3)
    assertEqual(NS.backdropInfo.insets.bottom, 3)
  end)
end)

test("UpdateBarAppearance floors the inset to 1 for a hairline border", function()
  -- borderSize 2 would give an inset of 0 on a bare floor(), which collapses the statusbar onto
  -- the backdrop edge; the max(1, ...) guard is what keeps a visible gutter.
  withUnitSetting("player", "borderSize", 2, function()
    NS.UpdateBarAppearance()
    assertEqual(NS.backdropInfo.insets.left, 1)
    assertEqual(NS.backdropInfo.insets.bottom, 1)
  end)
end)

test("UpdateBarAppearance scales the inset up with a thick border", function()
  withUnitSetting("player", "borderSize", 32, function()
    NS.UpdateBarAppearance()
    assertEqual(NS.backdropInfo.edgeSize, 32)
    assertEqual(NS.backdropInfo.insets.left, 8)
  end)
end)

test("UpdateBarAppearance clears the backdrop before re-applying it", function()
  -- WoW's SetBackdrop no-ops when handed the same table identity, even after its fields changed —
  -- and NS.backdropInfo is deliberately reused to avoid garbage. The nil-then-set is the only
  -- thing that makes a border/inset change visible; this pins that ordering.
  local calls = record(NS.bar, "SetBackdrop", NS.UpdateBarAppearance)
  assertEqual(#calls, 2, "SetBackdrop is called exactly twice")
  assertEqual(calls[1][1], nil, "first call clears")
  assertEqual(calls[2][1], NS.backdropInfo, "second re-applies the shared table")
end)

test("UpdateBarAppearance pushes the resolved media into the backdrop", function()
  NS.UpdateBarAppearance()
  assertEqual(NS.backdropInfo.bgFile, NS.GetBgTexture())
  assertEqual(NS.backdropInfo.edgeFile, NS.GetBorder())
end)

test("UpdateBarAppearance makes the bar immovable and mouse-inert when locked", function()
  local movable, mouse
  withSetting("locked", true, function()
    movable = record(NS.bar, "SetMovable", function()
      mouse = record(NS.bar, "EnableMouse", NS.UpdateBarAppearance)
    end)
  end)
  assertEqual(movable[1][1], false)
  assertEqual(mouse[1][1], false)
end)

test("UpdateBarAppearance restores drag + mouse when unlocked", function()
  local movable, mouse
  withSetting("locked", false, function()
    movable = record(NS.bar, "SetMovable", function()
      mouse = record(NS.bar, "EnableMouse", NS.UpdateBarAppearance)
    end)
  end)
  assertEqual(movable[1][1], true)
  assertEqual(mouse[1][1], true)
end)

-- ── unit labels (unlocked drag affordance) ─────────────────────────────────────────
-- The three bars stack and look identical, so while they can be dragged each one names the unit
-- it tracks. Purely an affordance: it follows the global `locked` flag and has no schema row.
--
-- Harness note: the stub frame answers every PascalCase call from its metatable by returning
-- ITSELF, so `bar:CreateFontString(...)` hands back the bar. `bar.unitLabel` and `bar` are one
-- object here, which means a raw Show/Hide count also catches the bar's own visibility call at the
-- end of UpdateBarAppearance. Suppress ApplyVisibility so these assert the label alone.
local function withoutVisibility(body)
  local saved = NS.ApplyVisibility
  NS.ApplyVisibility = function() end
  local ok, err = pcall(body)
  NS.ApplyVisibility = saved
  if not ok then error(err) end
end

test("every bar owns a unit label", function()
  for _, unit in ipairs(NS.Units.LIST) do
    assertTrue(NS.bars[unit].unitLabel ~= nil, unit .. " has no unitLabel")
  end
end)

test("unlocking shows a label naming the unit", function()
  local shows, texts
  withSetting("locked", false, function()
    withoutVisibility(function()
      texts = record(NS.bars.focus.unitLabel, "SetText", function()
        shows = record(NS.bars.focus.unitLabel, "Show", function()
          NS.UpdateBarAppearance("focus")
        end)
      end)
    end)
  end)
  assertEqual(#shows, 1, "the label is shown while the bars are draggable")
  assertEqual(texts[1][1], NS.Units.LABEL.focus, "the label names its own unit, not the player")
end)

test("locking hides the unit label", function()
  local hides
  withSetting("locked", true, function()
    withoutVisibility(function()
      hides = record(NS.bars.target.unitLabel, "Hide", function()
        NS.UpdateBarAppearance("target")
      end)
    end)
  end)
  assertEqual(#hides, 1, "a locked bar shows no label")
end)

-- ── preview mode ───────────────────────────────────────────────────────────────────
-- Two previews: the unlocked placeholder fill, and the timed `/at test` hold. Both must END —
-- the placeholder when the bars are re-locked, the hold when its announced duration expires.

test("an unlocked bar paints a placeholder fill against a 0..1 scale", function()
  local minmax, value
  withSetting("locked", false, function()
    withoutVisibility(function()
      minmax = record(NS.statusBar, "SetMinMaxValues", function()
        value = record(NS.statusBar, "SetValue", function()
          NS.UpdateBarAppearance("player")
        end)
      end)
    end)
  end)
  assertEqual(#value, 1, "an unlocked bar the user is dragging must not be an empty strip")
  assertEqual(minmax[#minmax][1], 0)
  assertEqual(minmax[#minmax][2], 1, "the placeholder scale is a fraction, not the unit's health")
  assertTrue(value[1][1] > 0 and value[1][1] < 1,
    "a full placeholder would be indistinguishable from a real absorb")
end)

test("a locked bar paints no placeholder", function()
  local value
  withSetting("locked", true, function()
    withoutVisibility(function()
      value = record(NS.statusBar, "SetValue", function()
        NS.UpdateBarAppearance("player")
      end)
    end)
  end)
  assertEqual(#value, 0, "a locked bar shows live data only")
end)

test("HoldPreview arms an expiry timer for exactly the announced duration", function()
  local savedHold = NS.testHoldUntil
  local before = #T.mocks.__timers
  local expiry = NS.HoldPreview(7)
  local armed = T.mocks.__timers[#T.mocks.__timers]
  assertEqual(#T.mocks.__timers, before + 1, "the announced duration must be scheduled, not assumed")
  assertEqual(armed.delay, 7, "the timer fires when the announced window ends")
  assertEqual(expiry, T.mocks.GetTime() + 7)
  NS.ClearPreview()
  NS.testHoldUntil = savedHold
end)

test("the expiry timer clears the hold and republishes REPAINT", function()
  local savedHold = NS.testHoldUntil
  local repaints = 0
  local ev = NS.NewBusTarget()
  ev:RegisterMessage(NS.MSG.REPAINT, function() repaints = repaints + 1 end)
  NS.HoldPreview(5)
  local armed = T.mocks.__timers[#T.mocks.__timers]
  armed.fn()
  ev:UnregisterMessage(NS.MSG.REPAINT)
  assertEqual(NS.testHoldUntil, nil, "the fake value must not outlive the window it announced")
  assertEqual(repaints, 1, "live data has to be repainted, or the bar keeps the fake number")
  NS.testHoldUntil = savedHold
end)

test("ClearPreview reports whether a hold was actually live", function()
  local savedHold = NS.testHoldUntil
  NS.testHoldUntil = nil
  assertFalse(NS.ClearPreview(), "nothing to clear")
  NS.HoldPreview(5)
  assertTrue(NS.ClearPreview(), "a live hold is reported as cleared")
  assertEqual(NS.testHoldUntil, nil)
  NS.testHoldUntil = savedHold
end)

test("the unit label follows the unit's own font face", function()
  local calls
  withSetting("locked", false, function()
    calls = record(NS.bars.player.unitLabel, "SetFont", NS.UpdateBarAppearance)
  end)
  assertEqual(calls[1][1], NS.GetFont("player"), "label uses the resolved font face")
  assertTrue(calls[1][2] < NS.Units.Get("player", "fontSize"),
    "the label is smaller than the bar's own value text")
end)

test("UpdateBarAppearance re-applies the font from the profile", function()
  local calls
  withUnitSetting("player", "fontSize", 17, function()
    withUnitSetting("player", "fontFlags", "THICKOUTLINE", function()
      calls = record(NS.valueText, "SetFont", NS.UpdateBarAppearance)
    end)
  end)
  assertEqual(#calls, 1)
  assertEqual(calls[1][1], NS.GetFont())
  assertEqual(calls[1][2], 17)
  assertEqual(calls[1][3], "THICKOUTLINE")
end)

test("UpdateBarAppearance tolerates a nil fontFlags by passing an empty flag string", function()
  local savedDB = NS.db.profile.units.player.fontFlags
  local savedDefault = NS.unitDefaults.fontFlags
  NS.db.profile.units.player.fontFlags = nil
  NS.unitDefaults.fontFlags = nil
  local calls = record(NS.valueText, "SetFont", NS.UpdateBarAppearance)
  NS.db.profile.units.player.fontFlags = savedDB
  NS.unitDefaults.fontFlags = savedDefault
  assertEqual(calls[1][3], "", "SetFont rejects a nil flags argument")
end)

test("UpdateBarAppearance ends by applying visibility", function()
  local applied = 0
  local orig = NS.ApplyVisibility
  NS.ApplyVisibility = function() applied = applied + 1 end
  local ok, err = pcall(NS.UpdateBarAppearance)
  NS.ApplyVisibility = orig
  if not ok then error(err) end
  assertEqual(applied, 1, "an appearance change must re-evaluate the show/hide gate")
end)

-- ── ApplyVisibility ────────────────────────────────────────────────────────────────

test("ApplyVisibility shows the bar when the gate passes and hides it when it does not", function()
  withUnitSetting("player", "enabled", true, function()
    NS.ApplyVisibility()
    assertTrue(NS.bar:IsShown(), "not hidden -> shown")
  end)
  withUnitSetting("player", "enabled", false, function()
    NS.ApplyVisibility()
    assertTrue(NS.bar:IsShown() == false, "hidden -> hidden")
  end)
  withUnitSetting("player", "enabled", true, function() NS.ApplyVisibility() end)
end)

-- ── UpdateAbsorbBar ────────────────────────────────────────────────────────────────

test("UpdateAbsorbBar is a no-op while the bar is hidden", function()
  local calls
  withUnitSetting("player", "enabled", false, function()
    calls = record(NS.statusBar, "SetValue", NS.UpdateAbsorbBar)
  end)
  assertEqual(#calls, 0, "no paint work is done for an invisible bar")
end)

test("UpdateAbsorbBar is a no-op inside a /at test hold window", function()
  -- /at test paints a fake value and parks testHoldUntil in the future; the ticker must leave that
  -- value alone until the hold expires, or the test display flickers back to the live value.
  local savedHold = NS.testHoldUntil
  local calls
  withUnitSetting("player", "enabled", true, function()
    NS.testHoldUntil = T.mocks.GetTime() + 5
    calls = record(NS.statusBar, "SetValue", NS.UpdateAbsorbBar)
  end)
  NS.testHoldUntil = savedHold
  assertEqual(#calls, 0, "the held fake value must not be overwritten")
end)

test("UpdateAbsorbBar paints again once the hold window has expired", function()
  local savedHold = NS.testHoldUntil
  local calls
  withUnitSetting("player", "enabled", true, function()
    NS.testHoldUntil = T.mocks.GetTime() - 1
    calls = record(NS.statusBar, "SetValue", NS.UpdateAbsorbBar)
  end)
  NS.testHoldUntil = savedHold
  assertEqual(#calls, 1)
end)

test("UpdateAbsorbBar scales the bar to max health and sets the absorb value", function()
  local savedAbs, savedHP = T.mocks.UnitGetTotalAbsorbs, T.mocks.UnitHealthMax
  local savedHold = NS.testHoldUntil
  T.mocks.UnitGetTotalAbsorbs = function() return 7500 end
  T.mocks.UnitHealthMax = function() return 250000 end
  NS.testHoldUntil = nil
  local minmax, value
  withUnitSetting("player", "enabled", true, function()
    minmax = record(NS.statusBar, "SetMinMaxValues", function()
      value = record(NS.statusBar, "SetValue", NS.UpdateAbsorbBar)
    end)
  end)
  T.mocks.UnitGetTotalAbsorbs, T.mocks.UnitHealthMax = savedAbs, savedHP
  NS.testHoldUntil = savedHold
  assertEqual(minmax[1][1], 0)
  assertEqual(minmax[1][2], 250000, "the scale is the player's max health, not a fixed 100")
  assertEqual(value[1][1], 7500)
end)

test("UpdateAbsorbBar substitutes 0 / 1 when the absorb and health reads come back nil", function()
  local savedAbs, savedHP = T.mocks.UnitGetTotalAbsorbs, T.mocks.UnitHealthMax
  local savedHold = NS.testHoldUntil
  T.mocks.UnitGetTotalAbsorbs = function() return nil end
  T.mocks.UnitHealthMax = function() return nil end
  NS.testHoldUntil = nil
  local minmax, value
  withUnitSetting("player", "enabled", true, function()
    minmax = record(NS.statusBar, "SetMinMaxValues", function()
      value = record(NS.statusBar, "SetValue", NS.UpdateAbsorbBar)
    end)
  end)
  T.mocks.UnitGetTotalAbsorbs, T.mocks.UnitHealthMax = savedAbs, savedHP
  NS.testHoldUntil = savedHold
  assertEqual(value[1][1], 0, "a nil absorb paints as zero, never nil")
  assertEqual(minmax[1][2], 1, "a nil max health must not produce a 0-width scale")
end)

test("UpdateAbsorbBar writes the abbreviated value into the bar text", function()
  local savedAbs = T.mocks.UnitGetTotalAbsorbs
  local savedHold = NS.testHoldUntil
  T.mocks.UnitGetTotalAbsorbs = function() return 4200 end
  NS.testHoldUntil = nil
  local calls
  withUnitSetting("player", "enabled", true, function()
    calls = record(NS.valueText, "SetText", NS.UpdateAbsorbBar)
  end)
  T.mocks.UnitGetTotalAbsorbs = savedAbs
  NS.testHoldUntil = savedHold
  assertEqual(calls[1][1], T.mocks.AbbreviateNumbers(4200))
end)

-- UpdateAbsorbBar reports whether it painted; modules/Timer.lua turns that into the [Combat]
-- rollup's repaint count (one per coalesced pass, not one per bar -- see tests/test_timer.lua).
test("UpdateAbsorbBar reports true when it paints", function()
  local savedHold = NS.testHoldUntil
  NS.testHoldUntil = nil
  local painted
  local ok, err = pcall(function()
    withUnitSetting("player", "enabled", true, function()
      painted = NS.UpdateAbsorbBar("player")
    end)
  end)
  NS.testHoldUntil = savedHold
  if not ok then error(err) end
  assertEqual(painted, true)
end)

test("UpdateAbsorbBar reports false for a bar it skipped", function()
  local painted
  local ok, err = pcall(function()
    withUnitSetting("player", "enabled", false, function()
      painted = NS.UpdateAbsorbBar("player")
    end)
  end)
  if not ok then error(err) end
  assertEqual(painted, false, "the [Combat] rollup would over-report otherwise")
end)

test("UpdateAbsorbBar reports false while a /at test hold is active", function()
  local savedHold = NS.testHoldUntil
  local painted
  local ok, err = pcall(function()
    withUnitSetting("player", "enabled", true, function()
      NS.testHoldUntil = T.mocks.GetTime() + 5
      painted = NS.UpdateAbsorbBar("player")
    end)
  end)
  NS.testHoldUntil = savedHold
  if not ok then error(err) end
  assertEqual(painted, false)
end)

-- ── per-unit visibility ladder ─────────────────────────────────────────────────────

local function withUnitFlag(unit, key, value, body)
  local c = NS.db.profile.units[unit]
  local saved = c[key]
  c[key] = value
  local ok, err = pcall(body)
  c[key] = saved
  if not ok then error(err) end
end

-- There is no master `hidden` toggle above the ladder any more (dropped in schema v4): each
-- unit's own `enabled` flag is the visibility switch, so disabling one bar must not touch another.
test("each unit's enable flag governs only its own bar", function()
  withUnitFlag("player", "enabled", false, function()
    withUnitFlag("target", "enabled", true, function()
      T.mocks.__unitExists.target = true
      assertEqual(NS.ShouldShowBar("player"), false, "the player bar follows its own flag")
      assertEqual(NS.ShouldShowBar("target"), true, "and does not drag the target bar down with it")
      T.mocks.__unitExists.target = false
    end)
  end)
end)

test("a disabled unit stays hidden even when the others are on", function()
  withUnitFlag("player", "enabled", true, function()
    withUnitFlag("target", "enabled", false, function()
      T.mocks.__unitExists.target = true
      assertEqual(NS.ShouldShowBar("target"), false)
      T.mocks.__unitExists.target = false
    end)
  end)
end)

test("an enabled target bar hides when there is no target", function()
  withUnitSetting("player", "enabled", true, function()
    withUnitFlag("target", "enabled", true, function()
      T.mocks.__unitExists.target = false
      assertEqual(NS.ShouldShowBar("target"), false)
      T.mocks.__unitExists.target = true
      assertEqual(NS.ShouldShowBar("target"), true)
      T.mocks.__unitExists.target = false
    end)
  end)
end)

test("the player bar never consults UnitExists", function()
  -- The player always exists; gating on it would add a pointless call and a failure mode.
  withUnitSetting("player", "enabled", true, function()
    T.mocks.__unitExists.player = false
    assertEqual(NS.ShouldShowBar("player"), true)
    T.mocks.__unitExists.player = true
  end)
end)

test("showOnlyInCombat gates every bar on PLAYER combat", function()
  withUnitSetting("player", "enabled", true, function()
    withSetting("showOnlyInCombat", true, function()
      withUnitFlag("target", "enabled", true, function()
        T.mocks.__unitExists.target = true
        local savedCombat = T.mocks.UnitAffectingCombat
        T.mocks.UnitAffectingCombat = function() return false end
        assertEqual(NS.ShouldShowBar("target"), false)
        T.mocks.UnitAffectingCombat = function() return true end
        assertEqual(NS.ShouldShowBar("target"), true)
        T.mocks.UnitAffectingCombat = savedCombat
        T.mocks.__unitExists.target = false
      end)
    end)
  end)
end)

-- ── per-unit paint ─────────────────────────────────────────────────────────────────

test("UpdateAbsorbBar reads the absorb of the unit it is painting", function()
  local savedHold = NS.testHoldUntil
  NS.testHoldUntil = nil
  T.mocks.__absorbs.target = 9100
  T.mocks.__maxHealth.target = 300000
  T.mocks.__unitExists.target = true
  local value
  withUnitSetting("player", "enabled", true, function()
    withUnitFlag("target", "enabled", true, function()
      value = record(NS.bars.target.statusBar, "SetValue", function()
        NS.UpdateAbsorbBar("target")
      end)
    end)
  end)
  T.mocks.__absorbs.target, T.mocks.__maxHealth.target = nil, nil
  T.mocks.__unitExists.target = false
  NS.testHoldUntil = savedHold
  assertEqual(value[1][1], 9100, "the target bar must not paint the player's absorb")
end)

test("UpdateBarAppearance sizes the bar it is given, not always the player's", function()
  local calls
  local c = NS.db.profile.units.target
  local savedMirror, savedW = c.mirror, c.barWidth
  c.mirror, c.barWidth = false, 333
  calls = record(NS.bars.target, "SetSize", function() NS.UpdateBarAppearance("target") end)
  c.mirror, c.barWidth = savedMirror, savedW
  assertEqual(calls[1][1], 333)
end)

test("a mirrored unit paints with the player's size", function()
  local c = NS.db.profile.units.focus
  local savedMirror = c.mirror
  local savedPlayerW = NS.db.profile.units.player.barWidth
  c.mirror = true
  c.barWidth = 999
  NS.db.profile.units.player.barWidth = 210
  local calls = record(NS.bars.focus, "SetSize", function() NS.UpdateBarAppearance("focus") end)
  c.mirror = savedMirror
  NS.db.profile.units.player.barWidth = savedPlayerW
  assertEqual(calls[1][1], 210)
end)

-- ── default positions ──────────────────────────────────────────────────────────────

test("the player bar defaults to dead center", function()
  local point, relPoint, x, y = NS.DefaultPosition("player")
  assertEqual(point, "CENTER"); assertEqual(relPoint, "CENTER")
  assertEqual(x, 0); assertEqual(y, 0)
end)

test("target and focus default stacked above the player bar", function()
  local savedH = NS.db.profile.units.player.barHeight
  NS.db.profile.units.player.barHeight = 20
  local _, _, _, ty = NS.DefaultPosition("target")
  local _, _, _, fy = NS.DefaultPosition("focus")
  NS.db.profile.units.player.barHeight = savedH
  assertEqual(ty, 28, "one bar height + an 8px gap")
  assertEqual(fy, 56, "two bar heights + two gaps")
end)

test("ForEachUnit walks all three units in order", function()
  local seen = {}
  NS.ForEachUnit(function(unit) seen[#seen + 1] = unit end)
  assertEqual(#seen, 3)
  assertEqual(seen[1], "player"); assertEqual(seen[2], "target"); assertEqual(seen[3], "focus")
end)
