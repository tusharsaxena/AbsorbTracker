-- AbsorbTracker: UI module - Bar frame creation
local AddonName, AddonTable = ...

local flatDefaults = AddonTable.flatDefaults
local GetBorder = AddonTable.GetBorder
local GetFont = AddonTable.GetFont
local GetSetting = AddonTable.GetSetting
local SetSetting = AddonTable.SetSetting
local GetBarTexture = AddonTable.GetBarTexture
local FALLBACK_TEXTURE = AddonTable.FALLBACK_TEXTURE

-- Reusable backdrop table to avoid garbage
AddonTable.backdropInfo = {
    bgFile = FALLBACK_TEXTURE,
    edgeFile = nil,
    tile = false,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

-- Create the absorb bar directly (no container frame)
local bar = CreateFrame("Frame", "AbsorbTrackerFrame", UIParent, "BackdropTemplate")
bar:SetSize(flatDefaults.barWidth, flatDefaults.barHeight)
bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
AddonTable.backdropInfo.edgeFile = GetBorder()
bar:SetBackdrop(AddonTable.backdropInfo)
bar:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
bar:SetBackdropBorderColor(flatDefaults.borderColor.r, flatDefaults.borderColor.g, flatDefaults.borderColor.b, flatDefaults.borderColor.a)
bar:SetMovable(true)
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", bar.StartMoving)
bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save position
    local point, _, relPoint, x, y = self:GetPoint()
    SetSetting("position", { point = point, relPoint = relPoint, x = x, y = y })
end)
bar:SetClampedToScreen(true)

-- Status bar for absorb amount
local statusBar = CreateFrame("StatusBar", nil, bar)
statusBar:SetPoint("TOPLEFT", bar, "TOPLEFT", 3, -3)
statusBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -3, 3)
statusBar:SetStatusBarTexture(GetBarTexture())
statusBar:SetMinMaxValues(0, 100)
statusBar:SetValue(100)
statusBar:SetStatusBarColor(0.4, 0.7, 1, 0.8)
bar.statusBar = statusBar

-- Absorb value text (on statusBar so it's above the bar texture)
local valueText = statusBar:CreateFontString(nil, "OVERLAY", nil)
valueText:SetFont(GetFont(), GetSetting("fontSize"), GetSetting("fontFlags") or "")
valueText:SetPoint("CENTER", bar, "CENTER", 0, 0)
bar.valueText = valueText

-- Export to AddonTable
AddonTable.bar = bar
AddonTable.statusBar = statusBar
AddonTable.valueText = valueText
