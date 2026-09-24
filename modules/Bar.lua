local _, NS = ...

-- The absorb bar frames — one per unit (player / target / focus). Built at file-load time from
-- the per-unit defaults (no DB yet — appearance is re-applied from the active profile on enable).
-- Exports NS.bars keyed by unit; every caller, tests included, indexes NS.bars[unit].

local C = NS.Constants
local unitDefaults = NS.unitDefaults
local L = NS.L

-- LibKa0s-Widgets-1.0, for its unlocked drag handle. Already vendored and loaded (libs\LibKa0s's
-- XML carries Widgets.lua and WidgetsDragHandle.lua), so there is no core/<Name>Setup.lua seam:
-- the major is read here, at the one module that draws a strip. Nil on a build with no LibKa0s,
-- and then no strip is drawn -- see NS.CreateBar.
local Widgets = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

--- Save where a bar was dropped. THE one save for both grab points -- the bar body's own
--- OnDragStop and its handle's onDragStop -- so the two cannot disagree about what a drop writes.
--- Position is per-unit and never mirrored, so the write always targets this frame's own unit.
local function savePosition(bar)
    local point, _, relPoint, x, y = bar:GetPoint()
    NS.Units.SetPosition(bar.unit, { point = point, relPoint = relPoint, x = x, y = y })
end

--- The unlocked drag handle over one bar: LibKa0s-Widgets-1.0's DragHandle, a dark strip with a
--- gold edge, the unit's name centered in gold and a help mark at its right end. The three bars
--- stack and look alike, so the strip is what tells the user which one they are about to drag,
--- and it gives them a grab point that is not the bar's own fill.
---
--- EVERYTHING ABOUT WHAT IT SAYS AND WHERE IT SITS IS OURS; the chrome, the label layout, the drag
--- scripts, the tooltips' drawing and the width arithmetic are the widget's. Anchored here, once:
--- BOTTOM to the bar's TOP at the widget's own published gap. Born hidden with no width;
--- NS.UpdateBarAppearance (modules/Display.lua) sizes it and shows it while the bars are unlocked.
---
--- A BUILD WITHOUT THE WIDGET DRAWS NO STRIP, and that is the documented degradation rather than
--- an oversight (LibKa0s Widgets docs, "Degraded"): a hand-built fallback here would be the second
--- copy the widget exists to delete. Nothing raises -- `bar.handle` stays nil and the appearance
--- pass guards on it -- and the bar body's own drag, below, still moves the bar.
---
--- Nothing here is protected: the bars are plain frames, and the lock refuses to open in combat
--- (settings/General.lua's `locked` row) and re-locks when combat starts (core/AbsorbTracker.lua),
--- so a strip is never shown, and never dragged, mid-fight.
local function buildHandle(bar, unit, globalName)
    if not (Widgets and Widgets.DragHandle) then return nil end
    local label = L[NS.Units.LABEL[unit] or unit]
    local handle = Widgets.DragHandle(bar, {
        name      = globalName .. "Handle",
        label     = label,
        moveFrame = bar,
        -- nil falls back to the widget's own last rung, a Blizzard texture, not to nothing.
        helpIcon  = NS.Icon and NS.Icon("help") or nil,
        -- Dragging is the LOCK's business. A locked bar is not movable (UpdateBarAppearance), and
        -- StartMoving on a frame that is not movable raises, so the strip asks before it starts.
        canDrag    = function() return not NS.GetSetting("locked") end,
        onDragStop = function() savePosition(bar) end,
        -- The strip's own tooltip. The body line is a FUNCTION because it is read on every hover
        -- and the lock can change between two hovers of the same strip.
        tooltip = {
            title = L["Absorb Tracker"],
            body  = {
                function()
                    if NS.GetSetting("locked") then
                        return L["Locked. Unlock the bars to move them \226\128\148 /at unlock."]
                    end
                    return format(L["Drag to move the %s bar."], label)
                end,
            },
        },
        -- The help mark's own: what the strip is for, and how to put it away.
        helpTooltip = {
            title  = format(L["%s bar"], label),
            anchor = "ANCHOR_TOPRIGHT",
            body   = {
                L["Drag this handle, or the bar itself, to move the bar."],
                L["Each bar keeps its own position."],
            },
            footer = {
                function()
                    if NS.GetSetting("locked") then
                        return L["Locked. Unlock the bars to drag this handle \226\128\148 /at unlock."]
                    end
                    return L["Lock the bars to hide this handle \226\128\148 /at lock."]
                end,
            },
        },
    })
    if handle then
        handle:SetPoint("BOTTOM", bar, "TOP", 0, Widgets.DRAG_HANDLE.GAP)
    end
    return handle
end

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
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        savePosition(self)
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

    -- The unlocked drag handle above the bar, naming its unit. Nil on a build without
    -- LibKa0s-Widgets-1.0; see buildHandle.
    bar.handle = buildHandle(bar, unit, globalName)

    -- CREATED HIDDEN, for the same reason the handle above it is. CreateFrame returns a SHOWN
    -- frame, and these three are built at file scope -- before a profile is read, before
    -- RestoreBarPosition has run and before the show ladder has decided anything. So every login
    -- and every /reload flashed three full blue bars stacked dead center on UIParent, at the
    -- default CENTER anchor, until the first VISIBILITY message reached modules/Display.lua.
    -- Owner-reported, and visible long enough to be screenshotted.
    -- NS.ApplyVisibility is the ONLY thing that shows a bar (modules/Display.lua): starting hidden
    -- makes that true at load as well as afterwards, rather than only afterwards.
    bar:Hide()

    return bar
end

NS.bars = {
    player = NS.CreateBar("player", "AbsorbTrackerFrame"),
    target = NS.CreateBar("target", "AbsorbTrackerTargetFrame"),
    focus  = NS.CreateBar("focus",  "AbsorbTrackerFocusFrame"),
}
