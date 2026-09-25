local _, NS = ...

local floor, max = NS.floor, NS.max

-- Perf probe (the LibKa0s-Perf instance built in core/PerfSetup.lua), taken as a load-time upvalue
-- so a bracket costs an upvalue read plus a field read when capture is off. PerfSetup loads before
-- this file (see the TOC), so it is never nil.
local Perf = NS.Perf

-- The bucket whose bracket is currently open in THIS module, or nil. Written only inside an open
-- bracket — so with capture off it is never touched at all — and read by the nested bracket, which
-- is how a Perf.Note here reports the containment the run OBSERVED instead of the one the
-- descriptor merely declares (performance-§3). A plain upvalue rather than a stack: this module
-- nests exactly one level (UpdateBarAppearance -> ApplyVisibility), and the previous value is
-- saved and restored at the one site that nests.
local openBucket

-- Gap between stacked default bar positions, in pixels.
local STACK_GAP = 8

-- The room the unlocked drag handle takes above each bar (modules/Bar.lua): the strip's height plus
-- the gap it keeps off the bar, both read off LibKa0s-Widgets-1.0's published values rather than
-- copied here. The default stack leaves it clear, or the player bar's strip would sit over the
-- bottom of the target bar -- and take its drags -- on the first unlock of a fresh profile. Zero on
-- a build with no widget, which draws no strip and so needs no room.
local Widgets = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
local DRAG = Widgets and Widgets.DRAG_HANDLE
local HANDLE_ROOM = DRAG and (DRAG.HEIGHT + DRAG.GAP) or 0

-- ── preview mode (preview-mode) ─────────────────────────────────────────────────────────────
--
-- Two things count as a preview here: the timed `/at debug hold <value>` fill, and the UNLOCKED state in
-- which the user is positioning the bars. There were three until the Test mode row was removed
-- (options-ui-§15); the lock is now the only switch, and entering combat re-locks so a fight always
-- starts on live data.
--
-- PLACEHOLDER_FRACTION is how full an unlocked bar reads when nothing live has painted over it.
-- Deliberately not 1.0: a full bar is indistinguishable from a real full-strength absorb, and the
-- placeholder must never be mistaken for data. The scale it paints against is 0..1 rather than the
-- unit's max health, so the fraction IS the fill and no health read is needed.
local PLACEHOLDER_FRACTION = 0.6
local PLACEHOLDER_TEXT     = "Absorb"

-- The armed `/at debug hold` expiry timer, or nil. The hold used to be a bare future timestamp that
-- nothing ever revisited: a five-second hold was announced, and the fake value then sat on the
-- bar until the next absorb event or an explicit `/at update`. preview-mode requires the announced
-- duration to be honored, so the hold now arms a one-shot that clears it and repaints.
local previewTimer

--- True while the bars show the placeholder instead of live data — which is exactly while they are
--- UNLOCKED. The one question all three preview sites ask (the appearance pass, the live repaint's
--- stand-down and the `/at debug hold` expiry), so a way into preview that reached two of them could not
--- strand the third.
---
--- There used to be a second way in, `NS.State.testMode`, and `options-ui-§15` now forbids it: an
--- addon whose unlocked view already IS its preview omits the Test mode row, because two switches
--- for one state is the finding (anti-pattern #80). What test mode did that unlocking did not —
--- skip the visibility and unit-exists rungs of ShouldShowBar — unlocking now does, so nothing was
--- lost with it.
function NS.InPreview()
    return not NS.GetSetting("locked")
end

--- Paint the unlocked placeholder fill on one bar. Returns true when it painted.
---
--- Not folded into UpdateAbsorbBar on purpose: choosing between "live value" and "placeholder"
--- there would mean asking whether the absorb is zero, and UnitGetTotalAbsorbs returns a secret in
--- restricted content — comparing it raises. See ShouldShowBar's note and docs/scope.md. The
--- placeholder is therefore painted by the appearance pass, and while the bars are unlocked
--- UpdateAbsorbBar stands down entirely rather than repainting over it — so the placeholder is
--- what the user sees for as long as they are positioning the bars, whatever else publishes a
--- repaint meanwhile.
function NS.PaintPlaceholder(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return false end
    -- The unit's configured opacity, not the literal 1 this used to pass. Both paint sites and the
    -- appearance pass now ask NS.GetBarAlpha, so the placeholder, a live repaint and a restyle
    -- cannot disagree about how solid the bar is.
    bar:SetAlpha(NS.GetBarAlpha(unit))
    bar.statusBar:SetMinMaxValues(0, 1)
    bar.statusBar:SetValue(PLACEHOLDER_FRACTION)
    bar.valueText:SetText(PLACEHOLDER_TEXT)
    return true
end

--- End any `/at debug hold` immediately, canceling its expiry timer. Returns true when a hold was
--- actually live, so a caller can tell "cleared something" from "nothing to clear".
---
--- The single seam: the expiry timer, a second `/at debug hold`, and the `locked` toggle's onChange all
--- come through here, so re-locking can never leave a stale preview on screen. Publishing the
--- repaint is the CALLER's job — the lock path already sends one, and a double repaint would be
--- one wasted pass.
function NS.ClearPreview()
    local held = (NS.testHoldUntil or 0) > GetTime()
    NS.testHoldUntil = nil
    if previewTimer then
        if NS.addon and NS.addon.CancelTimer then NS.addon:CancelTimer(previewTimer) end
        previewTimer = nil
    end
    return held
end

--- Hold the currently-painted fake value for `seconds`, then clear it and repaint. Returns the
--- absolute expiry time, which is what the tests and `/at debug hold` read back.
function NS.HoldPreview(seconds)
    NS.ClearPreview()                       -- a second /at debug hold replaces the first hold, never stacks
    NS.testHoldUntil = GetTime() + seconds
    if NS.addon and NS.addon.ScheduleTimer then
        previewTimer = NS.addon:ScheduleTimer(function()
            previewTimer = nil
            NS.ClearPreview()
            -- The previews overlap: `/at debug hold <value>` can be run with the bars unlocked, and a
            -- repaint stands down there too (see NS.UpdateAbsorbBar). Publishing REPAINT alone
            -- would therefore leave the fake value on the bar for good -- past the window this
            -- timer exists to enforce. Hand the bars back to the placeholder first; out of preview,
            -- this arm does not run and the repaint below restores live data as before.
            if NS.InPreview() then NS.ForEachUnit(NS.PaintPlaceholder) end
            if NS.bus then NS.bus:SendMessage(NS.MSG.REPAINT) end
        end, seconds)
    end
    return NS.testHoldUntil
end

--- Run `fn(unit)` for every tracked unit, in NS.Units.LIST order. The bus handlers drive all
--- three bars through this, which is what keeps the bus messages payload-free.
function NS.ForEachUnit(fn)
    for _, unit in ipairs(NS.Units.LIST) do fn(unit) end
end

--- Where a bar sits before the user has ever dragged it. Player is dead center; target and focus
--- stack upward from it, one player-bar-height plus the drag handle's room plus a gap apart, so a
--- newly-enabled bar lands somewhere visible and non-overlapping instead of on top of the player's
--- -- and, unlocked, clear of the strip over the bar below it.
function NS.DefaultPosition(unit)
    local index = 0
    for i, u in ipairs(NS.Units.LIST) do
        if u == unit then index = i - 1 break end
    end
    local step = NS.Units.Get("player", "barHeight") + HANDLE_ROOM + STACK_GAP
    return "CENTER", "CENTER", 0, index * step
end

-- Restore a bar's position from the saved profile (or its stacked default if unset).
function NS.RestoreBarPosition(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return end
    local pos = NS.Units.Position(unit)
    bar:ClearAllPoints()
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        -- NS.DefaultPosition returns (point, relPoint, x, y) with no relative FRAME — UIParent is
        -- supplied here, same as the saved-position branch above, since every default anchor is
        -- relative to the screen.
        local point, relPoint, x, y = NS.DefaultPosition(unit)
        bar:SetPoint(point, UIParent, relPoint, x, y)
    end
end

-- Apply appearance: size, texture, colors, border/background, font, lock, visibility.
function NS.UpdateBarAppearance(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return end
    local t0 = Perf.on and debugprofilestop()
    -- Publish this bracket as the open one, so ApplyVisibility's note below records the containment
    -- rather than asserting it. Saved and restored rather than cleared, so a future outer bracket
    -- is not lost.
    local prevBucket
    if t0 then prevBucket, openBucket = openBucket, "appearance" end
    local statusBar = bar.statusBar
    local valueText = bar.valueText
    local backdropInfo = bar.backdropInfo

    bar:SetSize(NS.Units.Get(unit, "barWidth"), NS.Units.Get(unit, "barHeight"))
    statusBar:SetStatusBarTexture(NS.GetBarTexture(unit))
    statusBar:SetStatusBarColor(NS.GetBarColor(unit))

    local borderSize = NS.Units.Get(unit, "borderSize")
    local inset = max(1, floor(borderSize / 4))
    backdropInfo.bgFile = NS.GetBgTexture(unit)
    backdropInfo.edgeFile = NS.GetBorder(unit)
    backdropInfo.edgeSize = borderSize
    backdropInfo.insets.left = inset
    backdropInfo.insets.right = inset
    backdropInfo.insets.top = inset
    backdropInfo.insets.bottom = inset
    -- Clear first to force refresh: WoW's SetBackdrop is a no-op when the table identity is
    -- unchanged, even if its fields changed. Do not optimize this away.
    bar:SetBackdrop(nil)
    bar:SetBackdrop(backdropInfo)
    bar:SetBackdropColor(NS.GetBgColor(unit))
    bar:SetBackdropBorderColor(NS.GetBorderColor(unit))

    valueText:SetFont(NS.GetFont(unit), NS.Units.Get(unit, "fontSize"),
        NS.Units.Get(unit, "fontFlags") or "")
    -- The absorb amount had no color of its own until the Text tab gained one; it drew at a bare
    -- FontString's default, opaque white, which is exactly what NS.GetFontColor answers for an
    -- untouched profile. Set on every appearance pass, like every other styled property here, so a
    -- profile switch and a `/at set` land the same way.
    valueText:SetTextColor(NS.GetFontColor(unit))

    -- Font shadow, the sixth row of the canonical font block (options-ui-§16). BOTH arms are
    -- written: a setting that is declared and not honored is worse than one that is absent, and an
    -- OFF arm that merely skipped the call would leave whatever the last pass set, so turning the
    -- shadow back off would do nothing until a /reload.
    if NS.Units.Get(unit, "fontShadow") then
        valueText:SetShadowColor(0, 0, 0, 1)
        valueText:SetShadowOffset(1, -1)
    else
        valueText:SetShadowColor(0, 0, 0, 0)
        valueText:SetShadowOffset(0, 0)
    end

    -- The frame's overall opacity -- the unit's own value times the addon-wide Master alpha
    -- (options-ui-§15), both resolved by NS.GetBarAlpha. Applied in the appearance pass as well as
    -- at the two paint sites, because a restyle that did not touch it would leave the bar at
    -- whatever alpha the last paint chose until the next absorb event.
    bar:SetAlpha(NS.GetBarAlpha(unit))

    -- The addon-wide Master scale (options-ui-§15). Applied here rather than once at CreateBar
    -- because it IS a setting: a restyle has to re-apply it, or a change would not land until the
    -- next /reload. It scales the whole frame, so the drag handle and the value text ride with it.
    bar:SetScale(NS.GetMasterScale())

    -- `locked` is global: all three bars lock together.
    local locked = NS.GetSetting("locked")
    bar:SetMovable(not locked)
    bar:EnableMouse(not locked)

    -- The drag handle rides the same flag: it exists to tell the stacked bars apart and give them
    -- a grab point while they can be dragged, so a locked (i.e. finished) layout shows nothing.
    -- Parented to the bar, so it is only ever on screen while the bar is. Nil on a build without
    -- LibKa0s-Widgets-1.0 (modules/Bar.lua), and then there is simply no strip.
    --
    -- Sized HERE, not by the widget, on every pass: the bar's width is a setting. Floored at the
    -- bar's width, so over a bar at least as wide as its label the strip is exactly as wide as the
    -- bar it moves; only a bar narrower than the strip's own label and help mark gets a wider one.
    local handle = bar.handle
    if handle then
        if locked then
            handle:Hide()
        else
            handle:ApplyWidth(NS.Units.Get(unit, "barWidth"))
            handle:Show()
        end
    end

    -- Unlocked means "being positioned", and out of combat the bar the user is trying to grab is
    -- usually empty — a transparent strip with no text. Paint the placeholder fill so there is
    -- something to see and drag (preview-mode). Leaving preview — re-locking, whether by the player
    -- or by combat starting — runs this same pass and
    -- does not repaint the placeholder; the REPAINT published beside it is what restores live
    -- data, and it can only paint because the bars are out of preview again (see UpdateAbsorbBar).
    if NS.InPreview() then NS.PaintPlaceholder(unit) end

    NS.ApplyVisibility(unit)
    -- Closed AFTER ApplyVisibility on purpose: the appearance bucket is meant to answer "what does
    -- one full restyle of a bar cost", and in production a restyle always ends by re-evaluating
    -- visibility. Excluding it would understate the real call. `visibility` still records its own
    -- nested figure, so the two are separable in the report.
    if t0 then
        openBucket = prevBucket
        -- Third argument: the bucket THIS bracket ran inside, which is whatever was open when it
        -- started — nil today, since UpdateBarAppearance is an entry point.
        Perf.Note("appearance", debugprofilestop() - t0, openBucket)
    end
end

-- The `visibility` dropdown's own gate (options-ui-§15). Four states, where there used to be a
-- `showOnlyInCombat` boolean that could only ever answer two of them; the v5 migration
-- (core/Database.lua) carries an existing install across.
--
-- The combat test keys off UnitAffectingCombat("player"), NOT InCombatLockdown(). At
-- PLAYER_REGEN_DISABLED the client fires the event while InCombatLockdown() is still false —
-- secure-frame lockdown lags actual combat by a fraction of a second — so gating on lockdown hid
-- the bar exactly when it should appear. See docs/midnight-quirks.md.
--
-- An unrecognized value reads as "always", which is the honest answer for a hand-edited
-- SavedVariable: the alternative is a hidden addon with no visible cause.
local function visibilityAllows()
    local mode = NS.GetSetting("visibility")
    if mode == "never" then return false end
    if mode == "inCombat" then return not not UnitAffectingCombat("player") end
    if mode == "outOfCombat" then return not UnitAffectingCombat("player") end
    return true
end

-- Effective bar visibility, composed in order — the first false wins:
--   0. the lifecycle latch: is the addon stood down, for ANY reason (`disabled` or `perf`)
--   1. the per-unit `enabled` flag
--      (UNLOCKED answers true here, skipping 2 and 3)
--   2. the `visibility` dropdown
--   3. for target/focus only, whether the unit exists
--
-- UNLOCKING skips exactly the two rungs that hide a bar the player has asked for: you unlock to see
-- and place the bars, and out of combat with no target those are the two that hide them. The rungs
-- above it still win, because a stood-down addon or a disabled bar is not something to preview.
--
-- This rung used to read `NS.State.testMode`, and moving it onto the lock is what let the Test mode
-- row go (options-ui-§15). Unlocking previously made the bars draggable and painted the placeholder
-- on whatever was already visible, which left the player unable to place a target bar with no
-- target — the gap test mode existed to fill. One switch now does both halves.
--
-- STEP 0 IS WHAT `Perf.suspended` AND THE ADDON-WIDE `enabled` RUNG USED TO BE, and asking the
-- latch rather than the setting is what keeps this from being a draw gate. Reading the stored
-- `enabled` here was the shape slash-commands-§7 is named for: a boolean one rung of a show ladder
-- consults, with every registration still live behind it. Both reasons are now holds on ONE latch
-- (core/Lifecycle.lua), and by the time this rung answers false the registrations are already
-- gone. What the rung still buys is §7's other half — hiding enforced AT THE SOURCE — because a
-- combat transition, a target swap or a settings change would otherwise re-show a bar behind the
-- stand-down's back.
--
-- The addon-wide `enabled` and the three per-unit flags are still DIFFERENT settings, and
-- options-ui-§15 forbids conflating them: the first reaches this ladder only through the latch, the
-- second is which bars exist. This is not the pre-v4 `hidden` global coming back — that key was
-- dropped because nothing in the UI could clear it, which is exactly what a Master controls row is
-- not.
--
-- Step 3 uses UnitExists and nothing else. "Hide when the unit has no absorb" is NOT
-- implementable: UnitGetTotalAbsorbs returns a secret in restricted content and comparing it to
-- zero raises — the same constraint recorded in docs/scope.md for the audio-alert feature.
function NS.ShouldShowBar(unit)
    unit = unit or "player"
    if NS.IsStoodDown() then return false end
    if not NS.Units.IsEnabled(unit) then return false end
    if not NS.GetSetting("locked") then return true end
    if not visibilityAllows() then return false end
    if unit ~= "player" and not UnitExists(unit) then return false end
    return true
end

-- Which rung of the ShouldShowBar ladder decided the outcome, as a debug string. Extracted from
-- ApplyVisibility rather than left inline: the and/or chain is one branch per rung, and inlining it
-- put ApplyVisibility over `lizard`'s complexity threshold for what is only ever debug narration.
-- Mirrors the ladder's order exactly — if a rung is added there, add it here.
local function visibilityReason(unit)
    if NS.IsStoodDown() then
        return "stood down (" .. table.concat(NS.lifecycle:Holds(), ", ") .. ")"
    end
    if not NS.Units.IsEnabled(unit) then return "unit disabled" end
    if not NS.GetSetting("locked") then return "unlocked" end
    if not visibilityAllows() then
        return "visibility=" .. NS.SafeToString(NS.GetSetting("visibility"))
    end
    if unit ~= "player" and not UnitExists(unit) then return "no unit" end
    return "always"
end

local dbgLastShown = {}   -- module-local: last applied visibility per unit, for transition logging
function NS.ApplyVisibility(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return end
    local t0 = Perf.on and debugprofilestop()
    local show = NS.ShouldShowBar(unit)
    if NS.State and NS.State.debug and show ~= dbgLastShown[unit] then
        NS.Debug("Bar", "%s: %s (%s)", unit, show and "shown" or "hidden", visibilityReason(unit))
    end
    dbgLastShown[unit] = show
    if show then bar:Show() else bar:Hide() end
    -- `openBucket` is "appearance" when UpdateBarAppearance called us and nil when the VISIBILITY
    -- message did, so the record reports containment where it happened and claims none where it did
    -- not. A hard-coded "appearance" here would be the same unverified declaration in a new place.
    if t0 then Perf.Note("visibility", debugprofilestop() - t0, openBucket) end
end

-- Repaint one bar's absorb value. Reads the raw (possibly "secret") UnitGetTotalAbsorbs value and
-- hands it straight to the C-side UI functions / AbbreviateNumbers — never through tonumber first.
--
-- Returns true when it actually painted, false on either early-out. modules/Timer.lua uses that to
-- count ONE repaint per coalesced pass rather than one per bar: the `[Combat] left: N events, M
-- repaints` rollup exists to show that the throttle coalesced, and N counts player events only, so
-- an M that scaled with the number of visible bars could exceed N and read as if the throttle were
-- amplifying work. A pass that painted nothing still counts nothing, same as before.
--
-- `parentBucket` is the perf bucket this paint is running inside, SUPPLIED BY THE CALLER rather
-- than named here. doRepaint (modules/Timer.lua) is the only caller that has one, and it hands
-- down "repaintPass" only while its own bracket is open; every other reach -- a test, a future
-- direct call -- passes nothing and the note then claims no containment. Hard-coding
-- "repaintPass" at the Note below would be the same unverified declaration core/PerfSetup.lua
-- already makes, moved one file over, and performance-§3 asks the third argument to CHECK
-- that declaration, not to repeat it.
function NS.UpdateAbsorbBar(unit, parentBucket)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return false end

    if not NS.ShouldShowBar(unit) then
        return false
    end

    -- /at debug hold paints a fake value and sets testHoldUntil so this doesn't immediately overwrite it.
    if (NS.testHoldUntil or 0) > GetTime() then
        return false
    end

    -- The other half of preview mode (preview-mode). Unlocked means the user is positioning the
    -- bars, so the appearance pass has painted
    -- the placeholder onto every one of them (NS.InPreview), and a live
    -- paint landing afterwards would replace it with an empty strip reading 0, which is the exact
    -- "nothing to grab" the placeholder exists to prevent.
    --
    -- Every REPAINT fans out over all three bars (modules/Timer.lua), and the panel publishes one
    -- whenever a bar is enabled, the addon-wide switch flips or the visibility mode changes -- so
    -- letting the live paint win made the placeholder depend on which row the user last touched:
    -- unchecking a bar left the other two reading "Absorb", rechecking it turned all three back
    -- into empty strips. Skipping here is the single seam, and it holds for absorb events and
    -- throttle ticks as well as for the panel.
    --
    -- Returns false, like the hold above: a bar that did not paint is not a repaint, so the
    -- [Combat] rollup's count is unaffected.
    if NS.InPreview() then
        return false
    end

    local t0 = Perf.on and debugprofilestop()

    local totalAbsorb = UnitGetTotalAbsorbs(unit) or 0
    local maxHealth = UnitHealthMax(unit) or 1

    bar:SetAlpha(NS.GetBarAlpha(unit))
    bar.statusBar:SetMinMaxValues(0, maxHealth)
    bar.statusBar:SetValue(totalAbsorb)
    bar.valueText:SetText(AbbreviateNumbers(totalAbsorb))

    -- Bracket opened AFTER the early-outs, so `paintBar` counts only passes that actually painted.
    -- A bucket whose call count included skipped bars would make ms/call meaningless.
    --
    -- Third argument: the bucket THIS paint ran inside, as the `appearance` and `visibility`
    -- brackets above already report theirs. It is the caller's `parentBucket` and not this
    -- module's `openBucket` upvalue because the containment being recorded crosses a module
    -- boundary -- doRepaint's bracket is opened in modules/Timer.lua, which this file's upvalue
    -- cannot see.
    if t0 then Perf.Note("paintBar", debugprofilestop() - t0, parentBucket) end
    return true
end

-- Bus subscriptions (architecture-§4). This module owns the SOLE subscription to each of the
-- appearance / visibility / position notifications; the settings, event, and lifecycle layers
-- publish them instead of calling these functions across the module boundary. All three register
-- on Display's own bus target, so no two receivers ever share a table (anti-pattern #32).
-- Handlers look the functions up on NS at dispatch time so a test can stub e.g. NS.ApplyVisibility,
-- and fan out over every unit so the messages stay payload-free.
NS.Display = NS.Display or {}
if NS.NewBusTarget then
    local ev = NS.NewBusTarget()
    NS.Display.__ev = ev
    -- `ev` is a TRACKED target (core/Bus.lua, LibKa0s-Bus-1.0): it is a file-local, so the bus
    -- record is the only thing that can reach these subscriptions to unregister them when the
    -- addon stands down (slash-commands-§7).
    ev:RegisterMessage(NS.MSG.APPEARANCE, function()
        NS.ForEachUnit(function(unit) NS.UpdateBarAppearance(unit) end)
    end)
    ev:RegisterMessage(NS.MSG.VISIBILITY, function()
        NS.ForEachUnit(function(unit) NS.ApplyVisibility(unit) end)
    end)
    ev:RegisterMessage(NS.MSG.POSITION, function()
        NS.ForEachUnit(function(unit) NS.RestoreBarPosition(unit) end)
    end)
end
