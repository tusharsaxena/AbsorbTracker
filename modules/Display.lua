local addonName, NS = ...

local floor, max = NS.floor, NS.max

-- Perf probe (core/Perf.lua), taken as a load-time upvalue so a bracket costs an upvalue read plus
-- a field read when capture is off. Perf loads before this file (see the TOC), so it is never nil.
local Perf = NS.Perf

-- Gap between stacked default bar positions, in pixels.
local STACK_GAP = 8

-- Point size of the unlocked-only unit label. Deliberately fixed rather than derived from the
-- unit's `fontSize`: the label identifies a drag target and should stay small and uniform across
-- the three bars even when one of them is styled with 24pt value text.
local LABEL_FONT_SIZE = 10

--- Run `fn(unit)` for every tracked unit, in NS.Units.LIST order. The bus handlers drive all
--- three bars through this, which is what keeps the bus messages payload-free.
function NS.ForEachUnit(fn)
    for _, unit in ipairs(NS.Units.LIST) do fn(unit) end
end

--- Where a bar sits before the user has ever dragged it. Player is dead centre; target and focus
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

    NS.ApplyVisibility(unit)
    -- Closed AFTER ApplyVisibility on purpose: the appearance bucket is meant to answer "what does
    -- one full restyle of a bar cost", and in production a restyle always ends by re-evaluating
    -- visibility. Excluding it would understate the real call. `visibility` still records its own
    -- nested figure, so the two are separable in the report.
    if t0 then Perf.Note("appearance", debugprofilestop() - t0) end
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
    if t0 then Perf.Note("visibility", debugprofilestop() - t0) end
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

    bar:SetAlpha(1)
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
