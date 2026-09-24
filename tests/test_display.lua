local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- modules/Display.lua — the paint path: position restore, the appearance apply (size / textures /
-- backdrop insets / lock), and the absorb repaint with its two early-outs.
--
-- The mock frames answer every PascalCase method from a metatable no-op, so nothing is recorded by
-- default. `spy` rawsets a recorder over one method for the duration of a call and PUTS BACK
-- WHATEVER WAS THERE afterwards.
--
-- It used to restore `nil` unconditionally, on the reasoning that nil restores the metatable
-- fallthrough — true for a method the stub does not define, and quietly destructive for one it
-- does. `Show`, `Hide`, `SetShown` and `IsShown` are REAL raw fields on a kit frame (they maintain
-- `__shown`, which is what `M.__shownFrames()` reads), so a spy on `Hide` that restored nil left
-- that frame permanently unhideable for every suite that ran afterwards -- and a stand-down suite
-- reading the shown set would then be measuring this helper rather than the addon.
local function spy(frame, method)
  local calls = {}
  local previous = rawget(frame, method)
  rawset(frame, method, function(_, ...) calls[#calls + 1] = { ... } return frame end)
  return calls, function() rawset(frame, method, previous) end
end

-- Capture every call to `method` made while `body` runs.
local function record(frame, method, body)
  local calls, restore = spy(frame, method)
  local ok, err = pcall(body)
  restore()
  if not ok then error(err) end
  return calls
end

-- Live paint is a locked-mode act: while the bars are unlocked they are in preview mode and
-- UpdateAbsorbBar stands down so the placeholder survives (modules/Display.lua). Every test below
-- that asserts what a repaint PAINTS therefore has to say which mode it is in, rather than riding
-- the profile default -- which is `locked = false`, i.e. preview mode.
local withLocked   -- forward declaration; assigned under withSetting, which it needs

local function withSetting(key, value, body)
  local saved = NS.GetSetting(key)
  T.rawSet(key, value)
  local ok, err = pcall(body)
  T.rawSet(key, saved)
  if not ok then error(err) end
end

--- The same, but through the WRITE SEAM so the row's onChange runs. `enabled` needs it: that
--- onChange is what takes the `disabled` hold on the lifecycle latch (slash-commands-§7), and the
--- raw store write above would move the stored value while leaving the addon standing.
local function withSeamSetting(key, value, body)
  local saved = NS.GetSetting(key)
  NS.SetByPath(key, value)
  local ok, err = pcall(body)
  NS.SetByPath(key, saved)
  -- The stand-up the restore just triggered ends by publishing REPAINT, which arms the coalescing
  -- one-shot. Drain it, or the next case to count scheduled timers counts this one.
  NS.CancelPendingRepaint()
  for i = #T.mocks.__timers, 1, -1 do T.mocks.__timers[i] = nil end
  if not ok then error(err) end
end

function withLocked(body) return withSetting("locked", true, body) end

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
  local calls = record(NS.bars.player, "SetPoint", NS.RestoreBarPosition)
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
  local calls = record(NS.bars.player, "SetPoint", NS.RestoreBarPosition)
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
  local calls = record(NS.bars.player, "ClearAllPoints", NS.RestoreBarPosition)
  assertEqual(#calls, 1)
end)

-- ── UpdateBarAppearance ────────────────────────────────────────────────────────────

test("UpdateBarAppearance sizes the bar from the profile", function()
  local calls
  withUnitSetting("player", "barWidth", 260, function()
    withUnitSetting("player", "barHeight", 24, function()
      calls = record(NS.bars.player, "SetSize", NS.UpdateBarAppearance)
    end)
  end)
  assertEqual(#calls, 1)
  assertEqual(calls[1][1], 260)
  assertEqual(calls[1][2], 24)
end)

test("UpdateBarAppearance derives the backdrop inset from borderSize (floor of a quarter)", function()
  withUnitSetting("player", "borderSize", 12, function()
    NS.UpdateBarAppearance()
    assertEqual(NS.bars.player.backdropInfo.edgeSize, 12)
    assertEqual(NS.bars.player.backdropInfo.insets.left, 3)
    assertEqual(NS.bars.player.backdropInfo.insets.right, 3)
    assertEqual(NS.bars.player.backdropInfo.insets.top, 3)
    assertEqual(NS.bars.player.backdropInfo.insets.bottom, 3)
  end)
end)

test("UpdateBarAppearance floors the inset to 1 for a hairline border", function()
  -- borderSize 2 would give an inset of 0 on a bare floor(), which collapses the statusbar onto
  -- the backdrop edge; the max(1, ...) guard is what keeps a visible gutter.
  withUnitSetting("player", "borderSize", 2, function()
    NS.UpdateBarAppearance()
    assertEqual(NS.bars.player.backdropInfo.insets.left, 1)
    assertEqual(NS.bars.player.backdropInfo.insets.bottom, 1)
  end)
end)

test("UpdateBarAppearance scales the inset up with a thick border", function()
  withUnitSetting("player", "borderSize", 32, function()
    NS.UpdateBarAppearance()
    assertEqual(NS.bars.player.backdropInfo.edgeSize, 32)
    assertEqual(NS.bars.player.backdropInfo.insets.left, 8)
  end)
end)

test("UpdateBarAppearance clears the backdrop before re-applying it", function()
  -- WoW's SetBackdrop no-ops when handed the same table identity, even after its fields changed —
  -- and each bar's backdropInfo table is deliberately reused to avoid garbage. The nil-then-set is the only
  -- thing that makes a border/inset change visible; this pins that ordering.
  local calls = record(NS.bars.player, "SetBackdrop", NS.UpdateBarAppearance)
  assertEqual(#calls, 2, "SetBackdrop is called exactly twice")
  assertEqual(calls[1][1], nil, "first call clears")
  assertEqual(calls[2][1], NS.bars.player.backdropInfo, "second re-applies the shared table")
end)

test("UpdateBarAppearance pushes the resolved media into the backdrop", function()
  NS.UpdateBarAppearance()
  assertEqual(NS.bars.player.backdropInfo.bgFile, NS.GetBgTexture())
  assertEqual(NS.bars.player.backdropInfo.edgeFile, NS.GetBorder())
end)

test("UpdateBarAppearance makes the bar immovable and mouse-inert when locked", function()
  local movable, mouse
  withSetting("locked", true, function()
    movable = record(NS.bars.player, "SetMovable", function()
      mouse = record(NS.bars.player, "EnableMouse", NS.UpdateBarAppearance)
    end)
  end)
  assertEqual(movable[1][1], false)
  assertEqual(mouse[1][1], false)
end)

test("UpdateBarAppearance restores drag + mouse when unlocked", function()
  local movable, mouse
  withSetting("locked", false, function()
    movable = record(NS.bars.player, "SetMovable", function()
      mouse = record(NS.bars.player, "EnableMouse", NS.UpdateBarAppearance)
    end)
  end)
  assertEqual(movable[1][1], true)
  assertEqual(mouse[1][1], true)
end)

-- ── ApplyVisibility, suppressed ────────────────────────────────────────────────────
-- A raw Show/Hide count on a bar also catches the bar's own visibility call at the end of
-- UpdateBarAppearance; suppress ApplyVisibility so a case can assert the one call it is about. (The
-- unlocked drag handle that replaced the unit label has its own suite, tests/test_draghandle.lua.)
local function withoutVisibility(body)
  local saved = NS.ApplyVisibility
  NS.ApplyVisibility = function() end
  local ok, err = pcall(body)
  NS.ApplyVisibility = saved
  if not ok then error(err) end
end

-- ── the two promoted chrome literals ───────────────────────────────────────────────
--
-- The absorb amount had NO color of its own (a bare FontString, drawing at its own default white)
-- and the frame's alpha was the literal 1 written at two paint sites. Both are settings now, and
-- both default to exactly the value they replaced -- which is what these first two cases pin: an
-- untouched profile must paint identically to the build before the rows existed.

test("an untouched profile paints the same white text and full alpha it always did", function()
  local colors, alphas
  withoutVisibility(function()
    colors = record(NS.bars.player.valueText, "SetTextColor", function()
      alphas = record(NS.bars.player, "SetAlpha", function()
        NS.UpdateBarAppearance("player")
      end)
    end)
  end)
  assertTrue(#colors > 0, "the appearance pass must set a text color")
  local c = colors[#colors]
  assertEqual(c[1], 1); assertEqual(c[2], 1); assertEqual(c[3], 1); assertEqual(c[4], 1)
  assertTrue(#alphas > 0, "the appearance pass must set the frame alpha")
  assertEqual(alphas[#alphas][1], 1)
end)

test("the Text tab's color reaches the absorb amount, alpha included", function()
  local colors
  withUnitSetting("player", "fontColor", { r = 0.2, g = 0.4, b = 0.6, a = 0.5 }, function()
    withoutVisibility(function()
      colors = record(NS.bars.player.valueText, "SetTextColor", function()
        NS.UpdateBarAppearance("player")
      end)
    end)
  end)
  local c = colors[#colors]
  assertTrue(math.abs(c[1] - 0.2) < 1e-6)
  assertTrue(math.abs(c[4] - 0.5) < 1e-6, "the swatch's alpha is the text's alpha")
end)

test("barAlpha reaches all three paint sites, not just the appearance pass", function()
  -- The appearance pass, the unlocked placeholder and a live repaint each set the frame's alpha.
  -- Before the row existed all three passed a literal 1; if any one of them still did, a bar would
  -- snap back to full opacity the next time an absorb event landed.
  withUnitSetting("player", "barAlpha", 0.4, function()
    withSetting("locked", false, function()
      withoutVisibility(function()
        local a = record(NS.bars.player, "SetAlpha", function() NS.UpdateBarAppearance("player") end)
        assertTrue(#a >= 2, "the appearance pass and its placeholder both set alpha")
        for i, call in ipairs(a) do
          assertTrue(math.abs(call[1] - 0.4) < 1e-6, "alpha call " .. i .. " ignored the setting")
        end
      end)
    end)
    withLocked(function()
      local a = record(NS.bars.player, "SetAlpha", function() NS.UpdateAbsorbBar("player") end)
      assertTrue(#a == 1 and math.abs(a[1][1] - 0.4) < 1e-6, "a live repaint honors it too")
    end)
  end)
end)

-- ── the rows the composers added, and the drawing code that honors them ────────────
--
-- A setting that is declared and not honored is worse than one that is absent: the panel promises
-- something the addon never does, and nothing in a schema test can tell the two apart. These are
-- the three rows this adoption ADDED, each pinned against the call that applies it.

test("fontShadow reaches the absorb amount, and turning it off CLEARS the shadow", function()
  -- The sixth row of the canonical font block (options-ui-§16), new to this addon. Both arms
  -- matter: an OFF arm that merely skipped the call would leave whatever the last pass set, so
  -- turning the shadow back off would do nothing until a /reload.
  -- red under: dropping either arm, or writing only SetShadowColor and not the offset.
  withUnitSetting("player", "fontShadow", true, function()
    local color = record(NS.bars.player.valueText, "SetShadowColor", NS.UpdateBarAppearance)
    assertEqual(#color, 1, "the shadow color is set on every appearance pass")
    assertTrue(color[1][4] > 0, "shadow on means a visible shadow alpha")
    local offset = record(NS.bars.player.valueText, "SetShadowOffset", NS.UpdateBarAppearance)
    assertEqual(#offset, 1)
    assertTrue(offset[1][1] ~= 0 or offset[1][2] ~= 0, "shadow on means a non-zero offset")
  end)
  withUnitSetting("player", "fontShadow", false, function()
    local color = record(NS.bars.player.valueText, "SetShadowColor", NS.UpdateBarAppearance)
    assertEqual(#color, 1, "the OFF arm still writes, rather than leaving the last pass's shadow")
    assertEqual(color[1][4], 0, "shadow off means a transparent shadow")
    local offset = record(NS.bars.player.valueText, "SetShadowOffset", NS.UpdateBarAppearance)
    assertEqual(offset[1][1], 0)
    assertEqual(offset[1][2], 0)
  end)
end)

test("Master scale is applied to the frame on every appearance pass", function()
  -- options-ui-§15's addon-wide scale. Applied in the appearance pass rather than once at
  -- CreateBar, because it IS a setting: a restyle has to re-apply it or a change would not land
  -- until the next /reload.
  -- red under: a SetScale moved into modules/Bar.lua's constructor, or dropped entirely.
  withSetting("scale", 1.35, function()
    local calls = record(NS.bars.player, "SetScale", function() NS.UpdateBarAppearance("player") end)
    assertEqual(#calls, 1, "exactly one scale write per pass")
    assertTrue(math.abs(calls[1][1] - 1.35) < 1e-6, "the frame took the addon-wide scale")
  end)
end)

test("Master alpha MULTIPLIES the per-unit barAlpha rather than replacing it", function()
  -- The two are different settings and options-ui-§15 forbids conflating them: one dims all three
  -- bars, the other dims one. NS.GetBarAlpha composes them, so every paint site gets the product
  -- without any of them knowing there are two numbers.
  -- red under: a master alpha that overwrites the per-unit value, or one read at only one of the
  -- three paint sites.
  withUnitSetting("player", "barAlpha", 0.5, function()
    withSetting("alpha", 0.5, function()
      assertTrue(math.abs(NS.GetBarAlpha("player") - 0.25) < 1e-6,
        "0.5 of the bar's own 0.5 is 0.25, not 0.5")
      local calls = record(NS.bars.player, "SetAlpha",
        function() withLocked(function() NS.UpdateAbsorbBar("player") end) end)
      assertEqual(#calls, 1)
      assertTrue(math.abs(calls[1][1] - 0.25) < 1e-6, "the repaint site takes the product too")
    end)
    withSetting("alpha", 1, function()
      assertTrue(math.abs(NS.GetBarAlpha("player") - 0.5) < 1e-6,
        "a master alpha of 1 leaves the per-unit value exactly where it was")
    end)
  end)
end)

-- ── preview mode ───────────────────────────────────────────────────────────────────
-- Two previews: the unlocked placeholder fill, and the timed `/at debug hold`. Both must END —
-- the placeholder when the bars are re-locked, the hold when its announced duration expires.

test("an unlocked bar paints a placeholder fill against a 0..1 scale", function()
  local minmax, value
  withSetting("locked", false, function()
    withoutVisibility(function()
      minmax = record(NS.bars.player.statusBar, "SetMinMaxValues", function()
        value = record(NS.bars.player.statusBar, "SetValue", function()
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
      value = record(NS.bars.player.statusBar, "SetValue", function()
        NS.UpdateBarAppearance("player")
      end)
    end)
  end)
  assertEqual(#value, 0, "a locked bar shows live data only")
end)

-- The placeholder must SURVIVE a repaint, not merely be painted once. Every REPAINT publish fans
-- out over all three bars (modules/Timer.lua), and the panel publishes one whenever a bar is
-- enabled, the addon-wide switch flips or the visibility mode changes -- so a live paint that won
-- over the placeholder made unlocked mode depend on which settings row the user last touched:
-- unchecking a bar left the others reading "Absorb", rechecking it turned all three back into
-- empty strips reading 0.
test("a live repaint leaves the unlocked placeholder alone", function()
  local savedHold = NS.testHoldUntil
  NS.testHoldUntil = nil
  local calls
  withSetting("locked", false, function()
    withUnitSetting("player", "enabled", true, function()
      calls = record(NS.bars.player.statusBar, "SetValue", function() NS.UpdateAbsorbBar("player") end)
    end)
  end)
  NS.testHoldUntil = savedHold
  assertEqual(#calls, 0, "the bar the user is dragging must keep its placeholder fill")
end)

test("UpdateAbsorbBar reports false while the bars are unlocked", function()
  local savedHold = NS.testHoldUntil
  NS.testHoldUntil = nil
  local painted
  local ok, err = pcall(function()
    withSetting("locked", false, function()
      withUnitSetting("player", "enabled", true, function()
        painted = NS.UpdateAbsorbBar("player")
      end)
    end)
  end)
  NS.testHoldUntil = savedHold
  if not ok then error(err) end
  assertEqual(painted, false, "a skipped bar is not a repaint, same as the /at debug hold")
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

-- The two previews overlap: `/at debug hold` can be run while the bars are unlocked. The expiry timer
-- publishes REPAINT, and a repaint stands down in preview mode -- so without this the fake value
-- would sit on an unlocked bar forever, past the window `/at debug hold` announced.
test("a hold that expires while unlocked falls back to the placeholder", function()
  local savedHold = NS.testHoldUntil
  local value
  withSetting("locked", false, function()
    NS.HoldPreview(5)
    local armed = T.mocks.__timers[#T.mocks.__timers]
    value = record(NS.bars.player.statusBar, "SetValue", armed.fn)
  end)
  NS.testHoldUntil = savedHold
  assertTrue(#value >= 1, "the announced window must end in something the user can see")
  assertTrue(value[#value][1] > 0 and value[#value][1] < 1,
    "unlocked, the fake value gives way to the placeholder fraction, not to live data")
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

-- ── preview is the lock, and nothing else (preview-mode, options-ui-§15) ───────────
-- This addon ships NO Test mode row. options-ui-§15 exempts an addon whose unlocked view already is
-- its preview, and anti-pattern #80 makes the duplicate switch the finding. What test mode used to
-- do that unlocking did not -- skip the visibility and unit-exists rungs of ShouldShowBar -- the
-- lock now does, so the capability survived the row.

-- Straight to the store, so no onChange fires: these cases pin what the paint path does while
-- unlocked, not what switching publishes (the cases after them do that through NS.SetByPath).
local function withUnlocked(body) return withSetting("locked", false, body) end

-- Chat output, through the sink every NS.Print ends in (same seam as tests/test_slashcmds.lua).
local function capture(fn)
  local out = {}
  local cf = T.mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(fn)
  cf.AddMessage = old
  if not ok then error(err) end
  return table.concat(out, "\n")
end

test("there is no test-mode flag left behind the lock", function()
  -- GetSetting answers `false` for any unregistered session path, so it cannot tell "removed" from
  -- "off". NS.State is where the flag actually lived, and it is the honest thing to assert on.
  assertEqual(NS.State.testMode, nil,
    "the row is gone (options-ui-§15); a lingering flag would mean a half-removed switch")
  assertEqual(NS.InPreview(), not NS.GetSetting("locked"),
    "preview is the lock and nothing else")
end)

test("a LOCKED bar does not preview", function()
  local value
  withLocked(function()
    withoutVisibility(function()
      value = record(NS.bars.player.statusBar, "SetValue", function() NS.UpdateBarAppearance("player") end)
    end)
  end)
  assertEqual(#value, 0,
    "locked is live data; the placeholder belonged to test mode here and test mode is gone")
end)

test("a live repaint stands down while unlocked", function()
  local savedHold = NS.testHoldUntil
  NS.testHoldUntil = nil
  local calls, painted
  withUnlocked(function()
    withUnitSetting("player", "enabled", true, function()
      calls = record(NS.bars.player.statusBar, "SetValue", function() painted = NS.UpdateAbsorbBar("player") end)
    end)
  end)
  NS.testHoldUntil = savedHold
  assertEqual(#calls, 0, "an absorb event must not paint over the placeholder being dragged")
  assertEqual(painted, false, "and a skipped bar is not a repaint")
end)

test("re-locking ends any /at debug hold and restores live data", function()
  local appearance, repaint = 0, 0
  local ev = NS.NewBusTarget()
  ev:RegisterMessage(NS.MSG.APPEARANCE, function() appearance = appearance + 1 end)
  ev:RegisterMessage(NS.MSG.REPAINT, function() repaint = repaint + 1 end)
  local painted
  withUnitSetting("player", "enabled", true, function()
    NS.SetByPath("locked", false)
    NS.HoldPreview(30)
    appearance, repaint = 0, 0
    NS.SetByPath("locked", true)
    painted = NS.UpdateAbsorbBar("player")
  end)
  ev:UnregisterMessage(NS.MSG.APPEARANCE)
  ev:UnregisterMessage(NS.MSG.REPAINT)
  T.mocks.__fireTimers()
  assertEqual(NS.testHoldUntil, nil, "the fake value must not outlive the preview")
  assertTrue(appearance >= 1, "the appearance pass is what stops painting the placeholder")
  assertTrue(repaint >= 1, "and the repaint is what puts live data back")
  assertEqual(painted, true, "locked again, a repaint paints again")
end)

-- THE CASE THE MERGE EXISTS FOR. You unlock to SEE the bars, so unlocking has to reach the two a
-- player cannot otherwise see out of combat: a target or focus bar with nothing targeted, and every
-- bar under a `visibility` that hides it right now. This rung used to be test mode's; without it,
-- removing the row would have cost the only way to place a target bar with no target.
test("unlocking shows a bar the visibility dropdown or a missing unit would hide", function()
  local savedExists = T.mocks.__unitExists.target
  T.mocks.__unitExists.target = nil
  local before, during
  withUnitSetting("target", "enabled", true, function()
    withSetting("visibility", "never", function()
      withLocked(function()
        before = { NS.ShouldShowBar("target"), NS.ShouldShowBar("player") }
      end)
      withUnlocked(function()
        during = { NS.ShouldShowBar("target"), NS.ShouldShowBar("player") }
      end)
    end)
  end)
  T.mocks.__unitExists.target = savedExists
  assertEqual(before[1], false, "locked, a target bar with no target is hidden")
  assertEqual(before[2], false, "locked, visibility=never hides the player bar")
  assertEqual(during[1], true, "no target, but the target bar is what the player came to place")
  assertEqual(during[2], true, "visibility=never, but unlocking is how the bar is seen at all")
end)

test("unlocking does not override the addon-wide or per-unit switch", function()
  local addonOff, unitOff
  withUnlocked(function()
    withSeamSetting("enabled", false, function() addonOff = NS.ShouldShowBar("player") end)
    withUnitSetting("focus", "enabled", false, function() unitOff = NS.ShouldShowBar("focus") end)
  end)
  assertEqual(addonOff, false, "Enable Absorb Tracker off means nothing draws")
  assertEqual(unitOff, false, "a bar that is turned off does not exist to preview")
end)

test("a hold that expires while unlocked falls back to the placeholder", function()
  local savedHold = NS.testHoldUntil
  local value
  withUnlocked(function()
    NS.HoldPreview(5)
    local armed = T.mocks.__timers[#T.mocks.__timers]
    value = record(NS.bars.player.statusBar, "SetValue", armed.fn)
  end)
  NS.testHoldUntil = savedHold
  T.mocks.__fireTimers()
  assertTrue(#value >= 1, "the announced window must end in something the user can see")
  assertTrue(value[#value][1] > 0 and value[#value][1] < 1,
    "still unlocked, the fake value gives way to the placeholder, not to live data")
end)

-- PLAYER_REGEN_DISABLED RE-LOCKS, says so in one line, and redraws an open panel so the box ticks.
-- This is where "combat ends test mode" went: ending preview and locking are now the same act, so
-- the guarantee the old line carried -- a fight starts on live data -- is unchanged.
test("combat re-locks the bars, says so, and refreshes the panel", function()
  local savedRefresh = NS.RefreshOptionsPanel
  local refreshed = 0
  NS.RefreshOptionsPanel = function() refreshed = refreshed + 1 end
  T.rawSet("locked", false)
  local ok, out = pcall(capture, function() NS.addon:OnEnterCombat() end)
  NS.RefreshOptionsPanel = savedRefresh
  T.mocks.__fireTimers()
  if not ok then error(out) end
  assertEqual(NS.GetSetting("locked"), true, "combat must re-lock, so the fight starts on live data")
  assertTrue(out:find("locked", 1, true) ~= nil, "one line saying why: " .. out)
  assertTrue(out:find("combat", 1, true) ~= nil, out)
  assertEqual(refreshed, 1, "the Lock frame box must tick in an open panel")
end)

test("combat with the bars already locked says nothing and leaves the panel alone", function()
  local savedRefresh = NS.RefreshOptionsPanel
  local refreshed = 0
  NS.RefreshOptionsPanel = function() refreshed = refreshed + 1 end
  T.rawSet("locked", true)
  local ok, out = pcall(capture, function() NS.addon:OnEnterCombat() end)
  NS.RefreshOptionsPanel = savedRefresh
  T.mocks.__fireTimers()
  if not ok then error(out) end
  assertEqual(out, "")
  assertEqual(refreshed, 0)
end)

-- The refusal the removed Test mode row used to carry, now on the lock. Re-LOCKING stays allowed in
-- combat, or the refusal could strand a player unlocked for the whole fight.
test("unlocking will not happen in combat, and says why", function()
  local savedUAC = T.mocks.UnitAffectingCombat
  T.mocks.UnitAffectingCombat = function() return true end
  T.rawSet("locked", true)
  local ok, out = pcall(capture, function() NS.SetByPath("locked", false) end)
  T.mocks.UnitAffectingCombat = savedUAC
  local locked = NS.GetSetting("locked")
  T.mocks.__fireTimers()
  if not ok then error(out) end
  assertEqual(locked, true, "a refused unlock leaves the bars locked and the box ticked")
  assertTrue(out:find("combat", 1, true) ~= nil, "the refusal says why: " .. out)
end)

test("re-locking in combat is always allowed", function()
  local savedUAC = T.mocks.UnitAffectingCombat
  T.mocks.UnitAffectingCombat = function() return true end
  T.rawSet("locked", false)
  local ok, err = pcall(function() NS.SetByPath("locked", true) end)
  T.mocks.UnitAffectingCombat = savedUAC
  T.mocks.__fireTimers()
  if not ok then error(err) end
  assertEqual(NS.GetSetting("locked"), true,
    "the combat refusal is one-directional; locking mid-fight must never be blocked")
end)

test("UpdateBarAppearance re-applies the font from the profile", function()
  local calls
  withUnitSetting("player", "fontSize", 17, function()
    withUnitSetting("player", "fontFlags", "THICKOUTLINE", function()
      calls = record(NS.bars.player.valueText, "SetFont", NS.UpdateBarAppearance)
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
  local calls = record(NS.bars.player.valueText, "SetFont", NS.UpdateBarAppearance)
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
    assertTrue(NS.bars.player:IsShown(), "not hidden -> shown")
  end)
  withUnitSetting("player", "enabled", false, function()
    NS.ApplyVisibility()
    assertTrue(NS.bars.player:IsShown() == false, "hidden -> hidden")
  end)
  withUnitSetting("player", "enabled", true, function() NS.ApplyVisibility() end)
end)

-- ── UpdateAbsorbBar ────────────────────────────────────────────────────────────────

test("UpdateAbsorbBar is a no-op while the bar is hidden", function()
  local calls
  withUnitSetting("player", "enabled", false, function()
    calls = record(NS.bars.player.statusBar, "SetValue", NS.UpdateAbsorbBar)
  end)
  assertEqual(#calls, 0, "no paint work is done for an invisible bar")
end)

test("UpdateAbsorbBar is a no-op inside a /at debug hold window", function()
  -- /at debug hold paints a fake value and parks testHoldUntil in the future; the ticker must leave that
  -- value alone until the hold expires, or the test display flickers back to the live value.
  local savedHold = NS.testHoldUntil
  local calls
  withUnitSetting("player", "enabled", true, function()
    NS.testHoldUntil = T.mocks.GetTime() + 5
    calls = record(NS.bars.player.statusBar, "SetValue", NS.UpdateAbsorbBar)
  end)
  NS.testHoldUntil = savedHold
  assertEqual(#calls, 0, "the held fake value must not be overwritten")
end)

test("UpdateAbsorbBar paints again once the hold window has expired", function()
  local savedHold = NS.testHoldUntil
  local calls
  withUnitSetting("player", "enabled", true, function()
    NS.testHoldUntil = T.mocks.GetTime() - 1
    calls = record(NS.bars.player.statusBar, "SetValue", function()
      withLocked(NS.UpdateAbsorbBar)
    end)
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
    minmax = record(NS.bars.player.statusBar, "SetMinMaxValues", function()
      value = record(NS.bars.player.statusBar, "SetValue", function() withLocked(NS.UpdateAbsorbBar) end)
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
    minmax = record(NS.bars.player.statusBar, "SetMinMaxValues", function()
      value = record(NS.bars.player.statusBar, "SetValue", function() withLocked(NS.UpdateAbsorbBar) end)
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
    calls = record(NS.bars.player.valueText, "SetText", function() withLocked(NS.UpdateAbsorbBar) end)
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
      withLocked(function() painted = NS.UpdateAbsorbBar("player") end)
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

test("UpdateAbsorbBar reports false while a /at debug hold is active", function()
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

test("visibility=inCombat gates every bar on PLAYER combat", function()
  -- The gate is the addon-wide `visibility` dropdown (schema v5, options-ui-§15), and it keys off
  -- the PLAYER's combat state for every bar -- a target bar hidden because the TARGET is out of
  -- combat would flicker on every pull.
  withUnitSetting("player", "enabled", true, function()
    withSetting("visibility", "inCombat", function()
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
        withLocked(function() NS.UpdateAbsorbBar("target") end)
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
  -- 20 of bar, 20 of drag-handle room (the widget's HEIGHT 18 + GAP 2) and the 8px gap: the
  -- player bar's strip must clear the target bar, not sit over its bottom edge.
  local D = T.mocks.LibStub("LibKa0s-Widgets-1.0", true).DRAG_HANDLE
  assertEqual(D.HEIGHT + D.GAP, 20, "the widget's published strip room this case was written against")
  assertEqual(ty, 48, "one bar height + the handle's room + an 8px gap")
  assertEqual(fy, 96, "two of each")
end)

test("ForEachUnit walks all three units in order", function()
  local seen = {}
  NS.ForEachUnit(function(unit) seen[#seen + 1] = unit end)
  assertEqual(#seen, 3)
  assertEqual(seen[1], "player"); assertEqual(seen[2], "target"); assertEqual(seen[3], "focus")
end)
