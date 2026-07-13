local addonName, NS = ...

local floor, max = NS.floor, NS.max

-- Restore the bar's position from the saved profile (or centre if unset).
function NS.RestoreBarPosition()
    local bar = NS.bar
    local pos = NS.GetSetting("position")
    bar:ClearAllPoints()
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- Apply appearance: size, texture, colors, border/background, font, lock, visibility.
function NS.UpdateBarAppearance()
    local bar = NS.bar
    local statusBar = NS.statusBar
    local valueText = NS.valueText
    local backdropInfo = NS.backdropInfo

    bar:SetSize(NS.GetSetting("barWidth"), NS.GetSetting("barHeight"))
    statusBar:SetStatusBarTexture(NS.GetBarTexture())
    statusBar:SetStatusBarColor(NS.GetBarColor())

    local borderSize = NS.GetSetting("borderSize")
    local inset = max(1, floor(borderSize / 4))
    backdropInfo.bgFile = NS.GetBgTexture()
    backdropInfo.edgeFile = NS.GetBorder()
    backdropInfo.edgeSize = borderSize
    backdropInfo.insets.left = inset
    backdropInfo.insets.right = inset
    backdropInfo.insets.top = inset
    backdropInfo.insets.bottom = inset
    -- Clear first to force refresh: WoW's SetBackdrop is a no-op when the table identity is
    -- unchanged, even if its fields changed. Do not optimize this away.
    bar:SetBackdrop(nil)
    bar:SetBackdrop(backdropInfo)
    bar:SetBackdropColor(NS.GetBgColor())
    bar:SetBackdropBorderColor(NS.GetBorderColor())

    valueText:SetFont(NS.GetFont(), NS.GetSetting("fontSize"), NS.GetSetting("fontFlags") or "")

    local locked = NS.GetSetting("locked")
    bar:SetMovable(not locked)
    bar:EnableMouse(not locked)

    if NS.GetSetting("hidden") then
        bar:Hide()
    else
        bar:Show()
    end
end

-- Repaint the absorb value. Reads the raw (possibly "secret") UnitGetTotalAbsorbs value and hands
-- it straight to the C-side UI functions / AbbreviateNumbers — never through tonumber first.
function NS.UpdateAbsorbBar()
    local bar = NS.bar
    local statusBar = NS.statusBar
    local valueText = NS.valueText

    if NS.GetSetting("hidden") then
        NS.DebugPrint("UpdateAbsorbBar", "Skipped: bar is hidden")
        return
    end

    -- /at test paints a fake value and sets testHoldUntil so this ticker doesn't immediately
    -- overwrite it on the next tick.
    if (NS.testHoldUntil or 0) > GetTime() then
        return
    end

    local totalAbsorb = UnitGetTotalAbsorbs("player") or 0
    local maxHealth = UnitHealthMax("player") or 1

    -- Hot-path debug: gate the AbbreviateNumbers + format allocations so they don't fire every
    -- tick when debug is off.
    if NS.State and NS.State.debug then
        NS.DebugPrint("UpdateAbsorbBar", "Absorb:", AbbreviateNumbers(totalAbsorb),
            "| MaxHP:", AbbreviateNumbers(maxHealth), "| Timestamp:", NS.format("%.3f", GetTime()))
    end

    bar:SetAlpha(1)
    statusBar:SetMinMaxValues(0, maxHealth)
    statusBar:SetValue(totalAbsorb)
    valueText:SetText(AbbreviateNumbers(totalAbsorb))
end
