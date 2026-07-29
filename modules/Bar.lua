local addonName, NS = ...

-- The absorb bar frames — one per unit (player / target / focus). Built at file-load time from
-- the per-unit defaults (no DB yet — appearance is re-applied from the active profile on enable).
-- Exports NS.bars keyed by unit, plus NS.bar / NS.statusBar / NS.valueText as player aliases for
-- the call sites that predate multi-unit (core/DebugLog.lua, settings/Slash.lua, the tests).

local C = NS.Constants
local unitDefaults = NS.unitDefaults

-- Gap between the top of a bar and its unit label, in pixels.
local LABEL_GAP = 2

--- Build one bar. Each frame owns its OWN backdropInfo table: one shared table cannot hold three
--- different border sizes, and WoW's SetBackdrop keys off table identity.
function NS.CreateBar(unit, globalName)
    local bar = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
    bar.unit = unit

    bar.backdropInfo = {
        bgFile = C.FALLBACK_TEXTURE,
        edgeFile = NS.GetBorder(unit),
        tile = false,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    }

    bar:SetSize(unitDefaults.barWidth, unitDefaults.barHeight)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    bar:SetBackdrop(bar.backdropInfo)
    bar:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
    bar:SetBackdropBorderColor(unitDefaults.borderColor.r, unitDefaults.borderColor.g,
        unitDefaults.borderColor.b, unitDefaults.borderColor.a)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", bar.StartMoving)
    -- Position is per-unit and never mirrored, so the write always targets this frame's own unit.
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        NS.Units.SetPosition(self.unit, { point = point, relPoint = relPoint, x = x, y = y })
    end)
    bar:SetClampedToScreen(true)

    local statusBar = CreateFrame("StatusBar", nil, bar)
    statusBar:SetPoint("TOPLEFT", bar, "TOPLEFT", 3, -3)
    statusBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -3, 3)
    statusBar:SetStatusBarTexture(NS.GetBarTexture(unit))
    statusBar:SetMinMaxValues(0, 100)
    statusBar:SetValue(100)
    statusBar:SetStatusBarColor(0.4, 0.7, 1, 0.8)
    bar.statusBar = statusBar

    -- Absorb value text (on statusBar so it's above the bar texture).
    local valueText = statusBar:CreateFontString(nil, "OVERLAY", nil)
    valueText:SetFont(NS.GetFont(unit), unitDefaults.fontSize, unitDefaults.fontFlags or "")
    valueText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.valueText = valueText

    -- Unit name, shown above the bar only while the bars are unlocked. The three bars stack and
    -- look alike, so this is what tells the user which one they are about to drag; it is an
    -- affordance rather than a styled element, so it has no schema row. Parented to `bar` (not
    -- statusBar) so it sits outside the fill and moves with the frame. Starts hidden so a locked
    -- login never flashes it.
    --
    -- Deliberately NOT given text here: a FontString raises "SetText(): Font not set" if text is
    -- assigned before a font, and this label's font (the unit's own face at a fixed label size) is
    -- owned by NS.UpdateBarAppearance, which runs from the APPEARANCE message on enable. That
    -- error would abort CreateBar mid-frame and leave NS.bars nil for the whole session, so keep
    -- the SetFont → SetText order there and create this bare.
    local unitLabel = bar:CreateFontString(nil, "OVERLAY", nil)
    unitLabel:SetPoint("BOTTOM", bar, "TOP", 0, LABEL_GAP)
    unitLabel:Hide()
    bar.unitLabel = unitLabel

    return bar
end

NS.bars = {
    player = NS.CreateBar("player", "AbsorbTrackerFrame"),
    target = NS.CreateBar("target", "AbsorbTrackerTargetFrame"),
    focus  = NS.CreateBar("focus",  "AbsorbTrackerFocusFrame"),
}

-- Player aliases. core/DebugLog.lua, settings/Slash.lua (`/at test`) and the test harness reach
-- for these; keeping them avoids a rename sweep across files this feature does not otherwise touch.
NS.bar          = NS.bars.player
NS.statusBar    = NS.bars.player.statusBar
NS.valueText    = NS.bars.player.valueText
NS.backdropInfo = NS.bars.player.backdropInfo
