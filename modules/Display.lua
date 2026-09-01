local addonName, NS = ...

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

-- Point size of the unlocked-only unit label. Deliberately fixed rather than derived from the
-- unit's `fontSize`: the label identifies a drag target and should stay small and uniform across
-- the three bars even when one of them is styled with 24pt value text.
local LABEL_FONT_SIZE = 10

-- ── preview mode (preview-mode) ─────────────────────────────────────────────────────────────
--
-- Two things count as a preview here: the timed `/at test` fill, and the unlocked state in which
-- the user is dragging the bars into place.
--
-- PLACEHOLDER_FRACTION is how full an unlocked bar reads when nothing live has painted over it.
-- Deliberately not 1.0: a full bar is indistinguishable from a real full-strength absorb, and the
-- placeholder must never be mistaken for data. The scale it paints against is 0..1 rather than the
-- unit's max health, so the fraction IS the fill and no health read is needed.
local PLACEHOLDER_FRACTION = 0.6
local PLACEHOLDER_TEXT     = "Absorb"

-- The armed `/at test` expiry timer, or nil. The hold used to be a bare future timestamp that
-- nothing ever revisited: `/at test 5` announced five seconds, and the fake value then sat on the
-- bar until the next absorb event or an explicit `/at update`. preview-mode requires the announced
-- duration to be honored, so the hold now arms a one-shot that clears it and repaints.
local previewTimer

--- Paint the unlocked placeholder fill on one bar. Returns true when it painted.
---
--- Not folded into UpdateAbsorbBar on purpose: choosing between "live value" and "placeholder"
--- there would mean asking whether the absorb is zero, and UnitGetTotalAbsorbs returns a secret in
--- restricted content — comparing it raises. See ShouldShowBar's note and docs/scope.md. The
--- placeholder is therefore painted by the appearance pass, and any live repaint wins over it,
--- which is the honest ordering.
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

--- End any `/at test` hold immediately, canceling its expiry timer. Returns true when a hold was
--- actually live, so a caller can tell "cleared something" from "nothing to clear".
---
--- The single seam: the expiry timer, a second `/at test`, and the `locked` toggle's onChange all
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
--- absolute expiry time, which is what the tests and `/at test` read back.
function NS.HoldPreview(seconds)
    NS.ClearPreview()                       -- a second /at test replaces the first hold, never stacks
    NS.testHoldUntil = GetTime() + seconds
    if NS.addon and NS.addon.ScheduleTimer then
        previewTimer = NS.addon:ScheduleTimer(function()
            previewTimer = nil
            NS.ClearPreview()
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
--- stack upward from it, one player-bar-height plus a gap apart, so a newly-enabled bar lands
--- somewhere visible and non-overlapping instead of on top of the player's.
function NS.DefaultPosition(unit)
    local index = 0
    for i, u in ipairs(NS.Units.LIST) do
        if u == unit then index = i - 1 break end
    end
    local step = NS.Units.Get("player", "barHeight") + STACK_GAP
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

    -- The frame's overall opacity. Applied in the appearance pass as well as at the two paint
    -- sites, because a restyle that did not touch it would leave the bar at whatever alpha the last
    -- paint chose until the next absorb event.
    bar:SetAlpha(NS.GetBarAlpha(unit))

    -- `locked` is global: all three bars lock together.
    local locked = NS.GetSetting("locked")
    bar:SetMovable(not locked)
    bar:EnableMouse(not locked)

    -- The unit label rides the same flag: it exists to tell the stacked bars apart while they can
    -- be dragged, so a locked (i.e. finished) layout shows nothing. Font face follows the unit's
    -- own setting — mirror-resolved like every other read here — at a fixed small size.
    local unitLabel = bar.unitLabel
    unitLabel:SetFont(NS.GetFont(unit), LABEL_FONT_SIZE, "OUTLINE")
    unitLabel:SetText(NS.Units.LABEL[unit] or unit)
    if locked then unitLabel:Hide() else unitLabel:Show() end

    -- Unlocked means "being positioned", and out of combat the bar the user is trying to grab is
    -- usually empty — a transparent strip with no text. Paint the placeholder fill so there is
    -- something to see and drag (preview-mode). Re-locking runs this same pass with `locked` true
    -- and does not repaint the placeholder, and the REPAINT the lock publishes restores live data.
    if not locked then NS.PaintPlaceholder(unit) end

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

-- Effective bar visibility, composed in order — the first false wins:
--   0. the perf probe's suspend switch
--   1. the per-unit `enabled` flag
--   2. the global `showOnlyInCombat` gate
--   3. for target/focus only, whether the unit exists
--
-- Step 0 is what makes `/at debug perf suspend` airtight. Suspend could have hidden the bars
-- imperatively, but then any later VISIBILITY publish — a combat transition, a target swap, a
-- settings edit — would quietly re-show them mid-measurement and corrupt the capture. Gating at
-- the source means suspend only has to publish VISIBILITY once and nothing can undo it.
--
-- There is no master `hidden` toggle above these any more (dropped in schema v4): `enabled` is the
-- visibility switch, and `/at toggle` flips all three at once rather than a separate global.
--
-- The combat gate keys off UnitAffectingCombat("player"), NOT InCombatLockdown(). At
-- PLAYER_REGEN_DISABLED the client fires the event while InCombatLockdown() is still false —
-- secure-frame lockdown lags actual combat by a fraction of a second — so gating on lockdown hid
-- the bar exactly when it should appear. See docs/midnight-quirks.md.
--
-- Step 4 uses UnitExists and nothing else. "Hide when the unit has no absorb" is NOT
-- implementable: UnitGetTotalAbsorbs returns a secret in restricted content and comparing it to
-- zero raises — the same constraint recorded in docs/scope.md for the audio-alert feature.
function NS.ShouldShowBar(unit)
    unit = unit or "player"
    if Perf.suspended then return false end
    if not NS.Units.IsEnabled(unit) then return false end
    if NS.GetSetting("showOnlyInCombat") and not UnitAffectingCombat("player") then return false end
    if unit ~= "player" and not UnitExists(unit) then return false end
    return true
end

-- Which rung of the ShouldShowBar ladder decided the outcome, as a debug string. Extracted from
-- ApplyVisibility rather than left inline: the and/or chain is one branch per rung, and inlining it
-- put ApplyVisibility over `lizard`'s complexity threshold for what is only ever debug narration.
-- Mirrors the ladder's order exactly — if a rung is added there, add it here.
local function visibilityReason(unit)
    if Perf.suspended then return "perf suspended" end
    if not NS.Units.IsEnabled(unit) then return "unit disabled" end
    if NS.GetSetting("showOnlyInCombat") and not UnitAffectingCombat("player") then
        return "showOnlyInCombat"
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
function NS.UpdateAbsorbBar(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return false end

    if not NS.ShouldShowBar(unit) then
        return false
    end

    -- /at test paints a fake value and sets testHoldUntil so this doesn't immediately overwrite it.
    if (NS.testHoldUntil or 0) > GetTime() then
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
    if t0 then Perf.Note("paintBar", debugprofilestop() - t0) end
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
