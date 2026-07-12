local addonName, NS = ...

-- The absorb bar frame. Built at file-load time from flat defaults (no DB needed yet — the
-- appearance is re-applied from the active profile on enable). Exports NS.bar / NS.statusBar /
-- NS.valueText / NS.backdropInfo for the paint path (modules/Display.lua).

local C = NS.Constants
local flatDefaults = NS.flatDefaults

-- Reusable backdrop table to avoid garbage.
NS.backdropInfo = {
    bgFile = C.FALLBACK_TEXTURE,
    edgeFile = nil,
    tile = false,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

local bar = CreateFrame("Frame", "AbsorbTrackerFrame", UIParent, "BackdropTemplate")
bar:SetSize(flatDefaults.barWidth, flatDefaults.barHeight)
bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
NS.backdropInfo.edgeFile = NS.GetBorder()
bar:SetBackdrop(NS.backdropInfo)
bar:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
bar:SetBackdropBorderColor(flatDefaults.borderColor.r, flatDefaults.borderColor.g,
    flatDefaults.borderColor.b, flatDefaults.borderColor.a)
bar:SetMovable(true)
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", bar.StartMoving)
bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    NS.SetSetting("position", { point = point, relPoint = relPoint, x = x, y = y })
end)
bar:SetClampedToScreen(true)

local statusBar = CreateFrame("StatusBar", nil, bar)
statusBar:SetPoint("TOPLEFT", bar, "TOPLEFT", 3, -3)
statusBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -3, 3)
statusBar:SetStatusBarTexture(NS.GetBarTexture())
statusBar:SetMinMaxValues(0, 100)
statusBar:SetValue(100)
statusBar:SetStatusBarColor(0.4, 0.7, 1, 0.8)
bar.statusBar = statusBar

-- Absorb value text (on statusBar so it's above the bar texture).
local valueText = statusBar:CreateFontString(nil, "OVERLAY", nil)
valueText:SetFont(NS.GetFont(), NS.GetSetting("fontSize"), NS.GetSetting("fontFlags") or "")
valueText:SetPoint("CENTER", bar, "CENTER", 0, 0)
bar.valueText = valueText

NS.bar = bar
NS.statusBar = statusBar
NS.valueText = valueText
