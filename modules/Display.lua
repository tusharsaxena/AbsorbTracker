local addonName, NS = ...

local floor, max = NS.floor, NS.max

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
end

-- Effective bar visibility, composed in order — the first false wins:
--   1. the per-unit `enabled` flag
--   2. the global `showOnlyInCombat` gate
--   3. for target/focus only, whether the unit exists
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
    if not NS.Units.IsEnabled(unit) then return false end
    if NS.GetSetting("showOnlyInCombat") and not UnitAffectingCombat("player") then return false end
    if unit ~= "player" and not UnitExists(unit) then return false end
    return true
end

local dbgLastShown = {}   -- module-local: last applied visibility per unit, for transition logging
function NS.ApplyVisibility(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return end
    local show = NS.ShouldShowBar(unit)
    if NS.State and NS.State.debug and show ~= dbgLastShown[unit] then
        local reason = (not NS.Units.IsEnabled(unit)) and "unit disabled"
            or (NS.GetSetting("showOnlyInCombat") and not UnitAffectingCombat("player")
                and "showOnlyInCombat")
            or (unit ~= "player" and not UnitExists(unit) and "no unit")
            or "always"
        NS.Debug("Bar", "%s: %s (%s)", unit, show and "shown" or "hidden", reason)
    end
    dbgLastShown[unit] = show
    if show then bar:Show() else bar:Hide() end
end

-- Repaint one bar's absorb value. Reads the raw (possibly "secret") UnitGetTotalAbsorbs value and
-- hands it straight to the C-side UI functions / AbbreviateNumbers — never through tonumber first.
function NS.UpdateAbsorbBar(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return end

    if not NS.ShouldShowBar(unit) then
        return
    end

    -- /at test paints a fake value and sets testHoldUntil so this doesn't immediately overwrite it.
    if (NS.testHoldUntil or 0) > GetTime() then
        return
    end

    local totalAbsorb = UnitGetTotalAbsorbs(unit) or 0
    local maxHealth = UnitHealthMax(unit) or 1

    bar:SetAlpha(1)
    bar.statusBar:SetMinMaxValues(0, maxHealth)
    bar.statusBar:SetValue(totalAbsorb)
    bar.valueText:SetText(AbbreviateNumbers(totalAbsorb))

    if NS.NoteRepaint then NS.NoteRepaint() end
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
