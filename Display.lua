-- AbsorbTracker: Display module - Update functions
local AddonName, AddonTable = ...

local floor, max = AddonTable.floor, AddonTable.max
local GetSetting = AddonTable.GetSetting
local GetBarTexture = AddonTable.GetBarTexture
local GetBgTexture = AddonTable.GetBgTexture
local GetBorder = AddonTable.GetBorder
local GetFont = AddonTable.GetFont
local GetBarColor = AddonTable.GetBarColor
local GetBgColor = AddonTable.GetBgColor
local GetBorderColor = AddonTable.GetBorderColor
local DebugPrint = AddonTable.DebugPrint

-- Track last absorb value to avoid redundant updates
AddonTable.lastAbsorb = -1  -- Start at -1 to force first update

-- Function to restore bar position from saved variables
function AddonTable.RestoreBarPosition()
    local bar = AddonTable.bar
    local pos = GetSetting("position")
    bar:ClearAllPoints()
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        -- Default to center of screen
        bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

-- Function to update appearance (texture, border, font, size, colors, lock)
function AddonTable.UpdateBarAppearance()
    local bar = AddonTable.bar
    local statusBar = AddonTable.statusBar
    local valueText = AddonTable.valueText
    local backdropInfo = AddonTable.backdropInfo

    -- Update size
    bar:SetSize(GetSetting("barWidth"), GetSetting("barHeight"))

    -- Update texture
    statusBar:SetStatusBarTexture(GetBarTexture())

    -- Update bar color
    statusBar:SetStatusBarColor(GetBarColor())

    -- Update border and background texture (reuse backdrop table)
    local borderSize = GetSetting("borderSize")
    local inset = max(1, floor(borderSize / 4))
    backdropInfo.bgFile = GetBgTexture()
    backdropInfo.edgeFile = GetBorder()
    backdropInfo.edgeSize = borderSize
    backdropInfo.insets.left = inset
    backdropInfo.insets.right = inset
    backdropInfo.insets.top = inset
    backdropInfo.insets.bottom = inset
    bar:SetBackdrop(nil)  -- Clear first to force refresh
    bar:SetBackdrop(backdropInfo)
    bar:SetBackdropColor(GetBgColor())
    bar:SetBackdropBorderColor(GetBorderColor())

    -- Update font
    valueText:SetFont(GetFont(), GetSetting("fontSize"), GetSetting("fontFlags") or "")

    -- Update lock state
    local locked = GetSetting("locked")
    bar:SetMovable(not locked)
    bar:EnableMouse(not locked)

    -- Update visibility
    if GetSetting("hidden") then
        bar:Hide()
    else
        bar:Show()
    end
end

-- Function to update the absorb bar
function AddonTable.UpdateAbsorbBar()
    local bar = AddonTable.bar
    local statusBar = AddonTable.statusBar
    local valueText = AddonTable.valueText
    local GetSetting = AddonTable.GetSetting
    local DebugPrint = AddonTable.DebugPrint

    -- Skip if hidden
    if GetSetting("hidden") then
        DebugPrint("UpdateAbsorbBar skipped - bar is hidden")
        return
    end

    local totalAbsorb = UnitGetTotalAbsorbs("player") or 0
    local maxHealth = UnitHealthMax("player") or 1

    DebugPrint("UpdateAbsorbBar - Absorb:", AbbreviateNumbers(totalAbsorb), "MaxHP:", AbbreviateNumbers(maxHealth)," Timestamp:", AddonTable.format("%.3f", GetTime()))

    -- Always keep bar visible
    bar:SetAlpha(1)

    -- Use raw secret value directly in UI functions for bar display
    statusBar:SetMinMaxValues(0, maxHealth)
    statusBar:SetValue(totalAbsorb)

    -- Use Blizzard's AbbreviateNumbers for text display
    local displayText = AbbreviateNumbers(totalAbsorb)
    valueText:SetText(displayText)
end
