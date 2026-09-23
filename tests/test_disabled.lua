-- tests/test_disabled.lua — the conformance suite for the disabled state (slash-commands-§7).
--
-- WHAT THIS SUITE IS FOR, AND WHAT IT REFUSES TO BE. `Disabled` used to mean, here and in ten
-- sibling addons, a DRAW GATE: a stored boolean read as one rung of the show ladder, so the bars
-- went away and nothing else changed. Every registration stayed live, the client went on walking
-- them on every UNIT_ABSORB_AMOUNT_CHANGED in a twenty-five-man raid, building the argument frame
-- and entering Lua to run the comparison that decided to leave. The addon had not stopped watching;
-- it had stopped reacting, and it still paid the dispatch a player switching it off was trying to
-- stop paying.
--
-- That shape survived eleven audits because from the outside it is INDISTINGUISHABLE from standing
-- down. So the assertions here are on the REGISTRATION SET, through the kit's recording mocks
-- (`M.__registrations`, `M.__timers`, `M.__shownFrames`, `M.__svWrites`, `M.__printed`), and never
-- on a handler's return value. A suite that asserts "the handler returned early" CERTIFIES the draw
-- gate it exists to catch: an early return is exactly what a draw gate does.
--
-- `M.__fire` dispatches at the LIVE set only, which is the honest half; `M.__fireUnconditional`
-- reaches a handler whose registration is gone, which is the falsification half — without it,
-- "nothing happened" is equally true of a correctly inert addon and of a harness that has lost the
-- ability to dispatch at all.
--
-- The ten steps below are slash-commands-§7's own list, in its order.

local T = _G.AT_TEST
local NS, M = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- ── the surveys ────────────────────────────────────────────────────────────────────────────────

--- One registration as a comparable string. Target identity is part of the key and not decoration:
--- the per-unit frames are three DIFFERENT frames, and a stand-up that rebuilt the player's
--- registrations onto the target's frame would have an identical count and the wrong set.
local function regKey(r)
  return ("%s|%s|%s|%s"):format(r.kind, tostring(r.event), tostring(r.unit), tostring(r.target))
end

local function regSet()
  local out = {}
  for i, r in ipairs(M.__registrations()) do out[i] = regKey(r) end
  return out
end

local function joined(list) return table.concat(list, "\n  ") end

--- Bring the addon up the way the client does. OnEnable is where the five AceEvent registrations
--- and the three per-unit frames are made, and tests/run.lua deliberately stops short of it — so
--- a suite about what a stand-down removes has to put them there first.
local function bringUp()
  -- CLOSE every settings page an earlier suite left on screen, before the baseline is taken. From
  -- LibKa0s v1.46.1 (options-ui-§2's combat lock) the library registers PLAYER_REGEN_DISABLED /
  -- _ENABLED for as long as one of its pages is shown, so a page left open would put the library's
  -- own registrations into the baseline, and a stand-down would (correctly) not remove them -- they
  -- are the library's, not this addon's. Hidden the way the client hides one: the kit mock's Hide
  -- fires no script, so OnHide is fired by hand, which is what lets go of lib.__shownPages.
  for ctx in pairs(M.LibStub("LibKa0s-Options-1.0").__shownPages) do
    ctx.panel:Hide()
    ctx.panel:__fire("OnHide")
  end
  NS.SetByPath("enabled", true)
  NS.addon:OnEnable()
  -- DRAIN the pending queue without firing it. `__fireTimers` would run every entry left behind by
  -- the suites ahead of this one — a settings panel's deferred body render among them — and this
  -- suite would then be asserting about somebody else's frames.
  NS.CancelPendingRepaint()
  for i = #M.__timers, 1, -1 do M.__timers[i] = nil end
  NS.SetByPath("enabled", true)
  return regSet()
end

--- The frames THIS ADDON has on screen. A bare `M.__shownFrames()` answers for the whole build,
--- including the settings panels earlier suites opened and never closed, so the survey is narrowed
--- to the bars — which are the frames a stand-down is answerable for.
local function shownBars()
  local out = {}
  for _, unit in ipairs(NS.Units.LIST) do
    local bar = NS.bars[unit]
    if bar and bar.__shown then out[#out + 1] = unit end
  end
  return out
end

--- Disable THROUGH THE SINGLE WRITE SEAM, never by calling StandDown directly. The point of the
--- suite is the route the checkbox and the verb take: a test that called the teardown by hand would
--- stay green over a checkbox wired to nothing.
local function disable() NS.SetByPath("enabled", false) end
local function enable()  NS.SetByPath("enabled", true)  end

-- ── 1. baseline ────────────────────────────────────────────────────────────────────────────────

test("disabled 1: the enabled addon registers something to stand down from", function()
  -- Without this the entire suite is trivially green: an addon that registered nothing when enabled
  -- passes every later assertion by registering nothing when disabled.
  local R_on = bringUp()
  assertTrue(#R_on > 0, "the baseline registration set is empty; nothing below would mean anything")

  -- The shape of it, named rather than counted, so a stand-up that rebuilds a DIFFERENT set is
  -- caught by more than an integer.
  local kinds = {}
  for _, r in ipairs(M.__registrations()) do kinds[r.kind] = (kinds[r.kind] or 0) + 1 end
  assertTrue((kinds.event or 0) >= 3, "the three lifecycle events: " .. joined(R_on))
  assertTrue((kinds.unit or 0) >= 2, "the player bar's two per-unit registrations: " .. joined(R_on))
  assertTrue((kinds.message or 0) >= 5, "the five bus subscriptions: " .. joined(R_on))
end)

-- ── 2 & 3. the registration set is EMPTY ───────────────────────────────────────────────────────

test("disabled 3: writing the enable path leaves NOTHING registered", function()
  -- THE ASSERTION THE WHOLE SUITE EXISTS FOR, and the one that reddened this addon before the
  -- adoption: the draw gate left all ten registrations in place and simply declined to draw.
  --
  -- red under: dropping the UnregisterAllEvents loop in core/Lifecycle.lua's StandDown; dropping its
  -- NS.BusStandDown; an `enabled` onChange that publishes VISIBILITY instead of moving the
  -- latch's `disabled` hold; a handler gated with `if not NS.GetSetting("enabled") then return end`
  -- in place of any of it, which is the draw gate wearing the new rule's clothes.
  bringUp()
  disable()
  local after = regSet()
  assertEqual(#after, 0, "survivors of the stand-down:\n  " .. joined(after))
  enable()
end)

-- ── 4. nothing is still going to wake up ───────────────────────────────────────────────────────

test("disabled 4: no timer, ticker or OnUpdate is left armed", function()
  -- The coalescing repaint is the expensive shape §7 names: an AceTimer that re-arms up to ten
  -- times a second in combat and then discovers it has nothing to paint. `M.__timers()` answers the
  -- LIVE set — armed handles and frames carrying an OnUpdate — not the pending queue, because a
  -- repeating ticker that has just fired is absent from the queue for a moment and very much alive.
  bringUp()
  NS.bus:SendMessage(NS.MSG.REPAINT)
  assertTrue(#M.__timers() > 0, "precondition: a repaint is queued to be canceled")

  disable()
  local live = M.__timers()
  assertEqual(#live, 0, "timers left armed on a stood-down addon: " .. #live)

  -- And none is armed for the rest of the run: the bus is unsubscribed, so a publish that would
  -- normally arm one reaches nobody.
  NS.bus:SendMessage(NS.MSG.REPAINT)
  assertEqual(#M.__timers(), 0, "a publish re-armed the repaint on a disabled addon")
  enable()
end)

-- ── 5. every frame that was shown is hidden ────────────────────────────────────────────────────

test("disabled 5: every frame that was on screen is hidden, and stays hidden", function()
  -- Hidden AT THE SOURCE, through NS.ShouldShowBar, never by an imperative Hide: a hidden frame
  -- comes back on a combat transition, a target swap or a settings change, and the addon is then
  -- visibly running while it claims to be off. The second half of this case is that property — an
  -- APPEARANCE pass over a stood-down addon must not put a bar back.
  bringUp()
  local F_on = shownBars()
  assertTrue(#F_on > 0, "precondition: at least one bar is on screen")

  disable()
  assertEqual(#shownBars(), 0, "bars still shown: " .. joined(shownBars()))

  NS.ForEachUnit(function(unit) NS.ApplyVisibility(unit) end)
  assertEqual(#shownBars(), 0, "the show ladder let a bar back while disabled")
  enable()
end)

-- ── 6. no write, no line, no frame, from any game event ────────────────────────────────────────

test("disabled 6: firing every baseline event writes nothing, says nothing, shows nothing", function()
  -- The finding this step exists for, verbatim from the audit: entering combat while DISABLED wrote
  -- `locked = true` and printed a line to chat. The player's evidence that the addon is off is the
  -- absence of exactly that line.
  --
  -- The cure is not a guard inside OnEnterCombat — that is the draw gate again — it is that
  -- PLAYER_REGEN_DISABLED is no longer registered, so the client never calls it.
  --
  -- red under: a StandDown that leaves PLAYER_REGEN_DISABLED registered; an OnEnterCombat reached
  -- by any other route; any handler that writes SavedVariables off a game event while down.
  local R_on = bringUp()
  local events = {}
  for _, r in ipairs(M.__registrations()) do
    if r.kind ~= "message" then events[r.event] = true end
  end
  assertTrue(events.PLAYER_REGEN_DISABLED, "the combat-entry event is in the baseline set by name")

  disable()
  NS.SetByPath("locked", false)          -- the value the combat handler used to overwrite
  M.__resetSvWrites()
  M.__resetPrinted()

  local ran = 0
  for event in pairs(events) do ran = ran + M.__fire(event, "player") end
  ran = ran + M.__fire("UNIT_ABSORB_AMOUNT_CHANGED", "player")

  assertEqual(ran, 0, "a handler ran off a game event while the addon was disabled")
  local writes = M.__svWrites()
  assertEqual(#writes, 0, "SavedVariables writes from a game event: " .. #writes
    .. (writes[1] and (" (" .. writes[1].path .. ")") or ""))
  assertEqual(#M.__printed(), 0, "lines printed: " .. table.concat(M.__printed(), " / "))
  assertEqual(#shownBars(), 0, "a frame was shown: " .. joined(shownBars()))
  assertFalse(NS.GetSetting("locked"), "`locked` was rewritten by a game event")

  -- THE FALSIFICATION HALF. Everything above is equally true of an addon that is inert and of a
  -- harness that can no longer dispatch, so reach the handler the client can no longer reach and
  -- prove it is still there and still acts. That is what a SURVIVOR would have been: the code did
  -- not change, its reachability did.
  local frame = NS.addon.__unitEventFrames and NS.addon.__unitEventFrames.player
  local reached = M.__fireUnconditional(frame, "UNIT_ABSORB_AMOUNT_CHANGED", "player")
  assertEqual(reached, 1, "the harness could not dispatch to an unregistered frame at all, so the "
    .. "silence above was the harness's and not the addon's")

  -- And the sharpest one: the combat handler is UNTOUCHED. Called by hand — which is the only way
  -- left to reach it — it still writes `locked = true`, exactly as it did on every pull before this
  -- adoption. Nothing about the handler was gated or softened; what changed is that
  -- PLAYER_REGEN_DISABLED is no longer registered, so the client never calls it. That is the
  -- difference between standing down and a draw gate, stated as two lines of a test.
  NS.addon:OnEnterCombat()
  assertTrue(NS.GetSetting("locked"),
    "reached by hand, the combat handler still writes — which is why unregistering is the fix")

  enable()
  assertEqual(#R_on, #regSet(), "and the set comes back")
end)

-- ── 7. the slash surface — UNCHANGED, and that is the ruling ───────────────────────────────────

test("disabled 7: every reserved verb answers, and only a feature verb refuses", function()
  -- THIS STEP IS NOT THE STAND-DOWN. Steps 1-6 are; a green step 7 says nothing about whether the
  -- addon is inert. It pins the OTHER half: the dispatcher and the settings registration are SETUP,
  -- not features, so they come up in either state and keeping them live costs nothing the
  -- stand-down was trying to reclaim.
  --
  -- THE SET HERE IS THE RESTORED ONE. The standard narrowed it to `enable` and `help` at v2.56.0
  -- and reversed it the same day at v2.57.0: `/at` on a disabled addon answered with a refusal
  -- instead of opening the settings panel, which is the one surface a player uses to switch it back
  -- on by hand. This suite asserts the RESTORED behavior, and would go red against a host still
  -- passing minor 12's narrowed `liveVerbs`.
  local LIVE = {
    help = true, config = true, version = true, enable = true, disable = true,
    debug = true, perf = true,
    get = true, set = true, list = true, reset = true, resetall = true,
    -- This addon's own two, argued at the `liveVerbs` entry in settings/Slash.lua.
    resetposition = true, profile = true,
  }
  local refusal = NS.Slash:DisabledLine()

  local realOpen, opened = NS.OpenOptionsPanel, 0
  NS.OpenOptionsPanel = function() opened = opened + 1 end

  bringUp()
  for _, entry in ipairs(NS.COMMANDS) do
    local verb = entry[1]
    disable()
    M.__resetPrinted()
    NS.Slash:OnSlash(verb)
    local out = M.__printed()
    if verb == "help" then
      -- Not a refusal OF help: the index prints in full, because the player has to be able to see
      -- `enable` in it, and the line sits under the header as a statement about the rows below.
      assertTrue(#out > 2, "`/at help` prints the whole index while disabled: " .. joined(out))
    elseif LIVE[verb] then
      for _, line in ipairs(out) do
        assertFalse(line:find(refusal, 1, true) ~= nil,
          "`/at " .. verb .. "` must answer normally while disabled: " .. line)
      end
    else
      assertEqual(#out, 1, "`/at " .. verb .. "` refuses on ONE line: " .. joined(out))
      assertTrue(out[1]:find(refusal, 1, true) ~= nil, "`/at " .. verb .. "`: " .. out[1])
    end
  end

  -- The bare verb, which is the case that settled the reversal.
  disable()
  opened = 0
  NS.Slash:OnSlash("")
  assertEqual(opened, 1, "a bare `/at` must open the settings panel while disabled")

  NS.OpenOptionsPanel = realOpen
  enable()
end)

test("disabled 7: a refused feature verb reaches no write seam", function()
  -- One line is the WHOLE courtesy: no partial work, no side effect, no second line. A gate that
  -- printed and then fell through would satisfy the line count above and nothing else.
  bringUp()
  NS.SetByPath("locked", true)
  disable()

  local real, seen = NS.SetByPath, 0
  NS.SetByPath = function(path, value)
    if path == "locked" then seen = seen + 1 end
    return real(path, value)
  end
  NS.Slash:OnSlash("unlock")
  NS.SetByPath = real

  assertEqual(seen, 0, "a refused verb reached the write seam")
  assertTrue(NS.GetSetting("locked"), "and the bars are still locked")
  enable()
end)

-- ── 8. the launcher ────────────────────────────────────────────────────────────────────────────

local function launcherObject()
  if not T.mocks.LibStub("LibDataBroker-1.1", true) then
    local ldb = T.mocks.LibStub:NewLibrary("LibDataBroker-1.1", 4)
    ldb.objects = {}
    function ldb:NewDataObject(name, tbl)
      if self.objects[name] then return nil end
      self.objects[name] = tbl
      return tbl
    end
    function ldb:GetDataObjectByName(name) return self.objects[name] end
    local icons = T.mocks.LibStub:NewLibrary("LibDBIcon-1.0", 45)
    icons.Register = function() end
    icons.Show     = function() end
    icons.Hide     = function() end
  end
  NS.Launcher:Register()
  return NS.Launcher:Object()
end

test("disabled 8: the left click is refused and writes nothing; the right click still opens the panel", function()
  -- launcher-§2's rung (b): this addon's left click drives the LOCK, which is its preview switch
  -- (options-ui-§15's exemption), and a preview switch is a feature. The audit's finding was that
  -- the button stayed clickable with NO gate at all, so a click wrote the stored tree of an addon
  -- the player had switched off — a game event in every sense that matters.
  --
  -- The BUTTON stays on the minimap either way: `minimap.hide` is a per-installation display
  -- preference and says nothing about whether the addon is running.
  local object = launcherObject()
  assertTrue(object ~= nil, "precondition: the launcher object is registered")

  bringUp()
  NS.SetByPath("locked", true)
  disable()
  M.__resetSvWrites()
  M.__resetPrinted()

  object.OnClick(object, "LeftButton")
  local writes = M.__svWrites()
  assertEqual(#writes, 0, "a disabled addon's launcher click wrote SavedVariables: "
    .. (writes[1] and writes[1].path or ""))
  assertEqual(#shownBars(), 0, "the click showed a frame: " .. joined(shownBars()))
  assertEqual(#M.__printed(), 1, "one refusal line: " .. joined(M.__printed()))
  assertTrue(M.__printed()[1]:find(NS.Slash:DisabledLine(), 1, true) ~= nil,
    "and it is the dispatcher's own line, not a second spelling: " .. M.__printed()[1])
  assertTrue(NS.GetSetting("locked"), "the lock did not move")

  -- RIGHT-click is unchanged, in either state: the panel is setup, not a feature (§7), so the right
  -- button opens it for the same reason `config` and the bare `/at` still do.
  local realOpen, opened = NS.OpenOptionsPanel, 0
  NS.OpenOptionsPanel = function() opened = opened + 1 end
  object.OnClick(object, "RightButton")
  NS.OpenOptionsPanel = realOpen
  assertEqual(opened, 1, "right-click must still open the settings panel while disabled")

  enable()
end)

-- ── 9. re-enable, and the rebuild is from CURRENT state ────────────────────────────────────────

test("disabled 9: re-enabling restores the registration set, from the settings as they are NOW", function()
  -- performance-§6's restore rule, which the latch inherits in full: standing up rebuilds from the
  -- enabled set AS IT IS, never from a snapshot taken on the way down. A snapshot would be correct
  -- on the first cycle and wrong on every cycle in which the player changed something while the
  -- addon was off — which is a thing players do precisely because the addon is off.
  local R_on = bringUp()
  disable()
  enable()
  assertEqual(table.concat(regSet(), "\n"), table.concat(R_on, "\n"),
    "the set did not come back as it went down")

  -- Now the same cycle with ONE setting changed while down.
  local target = NS.Units.IsEnabled("target")
  disable()
  NS.SetByPath("units.target.enabled", not target)
  enable()

  local sawTarget = false
  for _, r in ipairs(M.__registrations()) do
    if r.unit == "target" then sawTarget = true end
  end
  assertEqual(sawTarget, not target,
    "the rebuilt set must reflect the setting as it is now, not the snapshot")

  NS.SetByPath("units.target.enabled", target)
  assertEqual(table.concat(regSet(), "\n"), table.concat(R_on, "\n"), "and back again")
end)

test("disabled 9: the bus subscriptions come back as the same five pairs, and each still reaches its consumer once", function()
  -- The bus half of step 9, pinned by NAME rather than by count. The five production receivers
  -- are three private targets (core/AbsorbTracker.lua's, modules/Display.lua's and
  -- modules/Timer.lua's), and a stand-up that put a message back on the wrong target, or dropped
  -- one and doubled another, would keep the count and lose a consumer.
  bringUp()
  local who = {
    [NS.Events.__ev] = "Events", [NS.Display.__ev] = "Display", [NS.Timer.__ev] = "Timer",
  }
  local function busSet()
    local out = {}
    for _, r in ipairs(M.__registrations()) do
      if r.kind == "message" and who[r.target] then
        out[#out + 1] = who[r.target] .. ":" .. tostring(r.event)
      end
    end
    table.sort(out)
    return table.concat(out, ", ")
  end
  local EXPECTED = table.concat({
    "Display:Ka0s_AbsorbTracker_AppearanceChanged",
    "Display:Ka0s_AbsorbTracker_PositionChanged",
    "Display:Ka0s_AbsorbTracker_VisibilityChanged",
    "Events:Ka0s_AbsorbTracker_UnitsChanged",
    "Timer:Ka0s_AbsorbTracker_RepaintRequested",
  }, ", ")
  assertEqual(busSet(), EXPECTED, "the five production subscriptions, before")
  disable()
  assertEqual(busSet(), "", "every production subscription is down")
  enable()
  assertEqual(busSet(), EXPECTED, "the same five pairs, after")

  -- And each one still ACTS, once. Counted through stubs of the consumer each handler looks up at
  -- dispatch time, so a replay that registered a handler twice, or registered a stale one, shows.
  local calls = {}
  local function count(name) return function() calls[name] = (calls[name] or 0) + 1 end end
  local saved = {
    NS.UpdateBarAppearance, NS.ApplyVisibility, NS.RestoreBarPosition, NS.RequestRepaint,
    NS.addon.SyncUnitEventFrames,
  }
  NS.UpdateBarAppearance, NS.ApplyVisibility = count("appearance"), count("visibility")
  NS.RestoreBarPosition, NS.RequestRepaint = count("position"), count("repaint")
  NS.addon.SyncUnitEventFrames = count("units")
  NS.bus:SendMessage(NS.MSG.APPEARANCE)
  NS.bus:SendMessage(NS.MSG.VISIBILITY)
  NS.bus:SendMessage(NS.MSG.POSITION)
  NS.bus:SendMessage(NS.MSG.REPAINT)
  NS.bus:SendMessage(NS.MSG.UNITS)
  NS.UpdateBarAppearance, NS.ApplyVisibility, NS.RestoreBarPosition, NS.RequestRepaint,
    NS.addon.SyncUnitEventFrames = saved[1], saved[2], saved[3], saved[4], saved[5]
  local n = #NS.Units.LIST
  assertEqual(calls.appearance, n, "APPEARANCE fans out once per unit")
  assertEqual(calls.visibility, n, "VISIBILITY fans out once per unit")
  assertEqual(calls.position, n, "POSITION fans out once per unit")
  assertEqual(calls.repaint, 1, "REPAINT reaches the scheduler once")
  assertEqual(calls.units, 1, "UNITS re-syncs the unit frames once")
end)

-- ── 10. the latch ──────────────────────────────────────────────────────────────────────────────

test("disabled 10: releasing one hold does not stand up an addon the other still holds down", function()
  -- THE WHOLE REASON THE LATCH EXISTS. `/at disable` is a live verb, so a player can disable the
  -- addon during a suspended perf arm; `/at enable` is live too. A resume that called a bare
  -- StandUp would bring the addon back mid-capture and silently ruin the run; a disable that called
  -- one on its way out would do the same. Both go through release-and-re-evaluate.
  --
  -- red under: a `P.suspended` boolean kept beside the latch; a Resume that calls StandUp directly;
  -- an `enabled` onChange that calls StandUp instead of releasing the `disabled` hold; a second
  -- teardown path for disable beside the perf one.
  local R_on = bringUp()
  local lc = NS.lifecycle

  -- perf first, then disabled.
  NS.Perf.Suspend()
  assertTrue(lc:IsHeld("perf"), "the perf hold is taken")
  disable()
  assertEqual(#regSet(), 0, "down under both holds")
  NS.Perf.Resume()
  assertFalse(lc:IsHeld("perf"), "the perf hold is released")
  assertTrue(lc:IsDown(), "and the addon is STILL down: the player disabled it")
  assertEqual(#regSet(), 0, "a released perf hold resurrected a disabled addon:\n  "
    .. joined(regSet()))
  enable()
  assertEqual(#regSet(), #R_on, "and the last hold released stands it up")

  -- disabled first, then perf — order is irrelevant to a hold set, and this is the case that says
  -- so from the outside.
  disable()
  NS.Perf.Suspend()
  assertEqual(#regSet(), 0, "down under both holds, the other way round")
  enable()
  assertTrue(lc:IsDown(), "still down: the perf arm is still running")
  assertEqual(#regSet(), 0, "re-enabling mid-capture stood the addon up:\n  " .. joined(regSet()))
  NS.Perf.Resume()
  assertFalse(lc:IsDown(), "and releasing the last hold brings it back")
  assertEqual(#regSet(), #R_on, "with the set it went down with")
end)

test("disabled 10: the perf hold is session-only and the disabled hold is the stored path", function()
  -- Two holds, two lifetimes, and neither inherits the other's rule. `perf` must never be persisted
  -- — a hold re-taken across a reload leaves a player's addon dead with no visible cause — and
  -- `disabled` IS the stored `enabled` path, because surviving a /reload is the entire point of it.
  bringUp()
  M.__resetSvWrites()
  NS.Perf.Suspend()
  local writes = M.__svWrites()
  assertEqual(#writes, 0, "the perf hold was persisted: " .. (writes[1] and writes[1].path or ""))
  NS.Perf.Resume()

  disable()
  assertFalse(NS.GetSetting("enabled"), "the disabled hold is read back out of the store")
  assertTrue(NS.lifecycle:IsHeld("disabled"), "and the hold follows it")
  enable()
  assertFalse(NS.lifecycle:IsHeld("disabled"), "both ways")
  assertFalse(NS.lifecycle:IsDown(), "with no hold left, the addon is up")
end)

-- ── the bus record (LibKa0s-Bus-1.0) ───────────────────────────────────────────────────────────
--
-- Two properties the hand-written register this replaced did not have, pinned where the latch is
-- driven for real. Both use a throwaway receiver and empty it at the end, because a target made by
-- the tracked factory is part of the record (the Bus API document, Known limitations 3).

test("bus: a registration made while stood down is recorded, and not live until the stand-up", function()
  bringUp()
  disable()
  local heard = 0
  local probe = NS.NewBusTarget()
  probe:RegisterMessage("AT_TEST_WhileDown", function() heard = heard + 1 end)
  NS.bus:SendMessage("AT_TEST_WhileDown")
  assertEqual(heard, 0, "a stood-down addon registered nothing, even for a new receiver")
  enable()
  NS.bus:SendMessage("AT_TEST_WhileDown")
  assertEqual(heard, 1, "and the stand-up made it live")
  probe:UnregisterAllMessages()
end)

test("bus: a subscription its owner dropped is not brought back by a stand-up", function()
  -- The defect the sweep's spec names in the old register: append-only triples with no forget,
  -- so an unregister while up was undone by the next disable/enable cycle.
  bringUp()
  local heard = 0
  local probe = NS.NewBusTarget()
  probe:RegisterMessage("AT_TEST_Dropped", function() heard = heard + 1 end)
  probe:UnregisterMessage("AT_TEST_Dropped")
  disable()
  enable()
  NS.bus:SendMessage("AT_TEST_Dropped")
  assertEqual(heard, 0, "the dropped subscription came back on the stand-up")
end)

test("bus: the stand-down and stand-up counts are the record's, and the latch drives both", function()
  bringUp()
  local down = NS.BusStandDown()
  assertTrue(down >= 5, "the five production entries are in the record: " .. down)
  assertEqual(NS.BusStandDown(), 0, "a second stand-down is idempotent and answers 0")
  -- The latch is still UP, so isDown() answers false and this bare replay is allowed; it restores
  -- what the direct stand-down above took away.
  assertEqual(NS.BusStandUp(), down, "the replay puts back every entry it took down")
  disable()
  assertEqual(NS.BusStandUp(), 0, "while a hold is taken a bare stand-up of the bus is refused")
  enable()
end)
