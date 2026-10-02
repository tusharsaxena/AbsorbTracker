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

--- The close mark's click: turn off this ONE bar. It writes the existing per-unit enable row --
--- `units.<unit>.enabled`, the row General > Bars draws and `/at toggle <unit>` flips -- through
--- NS.SetByPath, the one schema write seam, so the [Set] trace, the row's onChange (which re-syncs
--- the unit's event registrations and repaints), the refresh bus and an open panel all fire exactly
--- as they do from the checkbox. Never the addon-wide `enabled` and never the shared `locked`: the
--- other bars stay where they are. Position is untouched, so turning the bar back on puts it back
--- where it was. One chat line names the way back; the X's tooltip carries the same sentence.
---
--- No combat rule of its own: the strip is only shown unlocked, and the lock closes in combat.
local function closeBar(unit, label)
    NS.SetByPath("units." .. unit .. ".enabled", false)
    NS.Print(format(L["%s bar hidden. Re-enable it on General > Bars or with /at toggle %s."],
        label, unit))
end

-- ---------------------------------------------------------------------------
-- Drag strip tooltip placement
-- ---------------------------------------------------------------------------
--
-- Every strip passes this as LibKa0s-Widgets' `tooltipPlace` (WidgetsDragHandle minor 4), the
-- placement every Ka0s strip uses (KickCD's NS.Util.PlaceTooltipBeside, TP-KC-01). The widget owns
-- GameTooltip by UIParent at ANCHOR_NONE, draws and shows it, then calls this under pcall; only a
-- literal `true` means placed, and anything else falls back to the cursor tooltip with the same
-- lines.

-- The gap between the strip's edge and the tooltip, in the tooltip's own units (SetPoint's).
local TIP_GAP = 4

--- A frame geometry read as a plain number, or nil when the method is missing or the answer is
--- nil, secret (NS.IsConcatSafe, the one question this addon asks of a value that may be secret)
--- or not a number. Asked before any arithmetic, because arithmetic on a secret raises. Read off
--- NS at call time, so the library's probe or the degraded stub's is the one asked.
local function plainRead(frame, method)
    local fn = frame and frame[method]
    if not fn then return nil end
    local v = fn(frame)
    if v == nil or not NS.IsConcatSafe(v) or type(v) ~= "number" then return nil end
    return v
end

--- `method`'s answer in SCREEN px (times the frame's effective scale), or nil. A bar carries its
--- own scale times the master scale and the strip inherits it, so a raw edge and a raw screen width
--- are in different units and comparing them would flip on the wrong side.
local function screenRead(frame, method)
    local v, s = plainRead(frame, method), plainRead(frame, "GetEffectiveScale")
    return v and s and v * s or nil
end

--- Place a drag strip's tooltip beside the strip: to its right, or to its left when the strip's
--- right edge plus the tooltip's width would pass the screen's right edge. `frame` is the frame
--- hovered: the strip itself (it carries the widget's `help` field) or its `?` or X mark, whose
--- parent is the strip, so all three show their tooltips in one place.
--- @return true|nil  true only once the tooltip is anchored; nil (the widget's cursor fallback)
---                   when any read is missing, nil or secret, with nothing anchored.
function NS.Util.PlaceTooltipBeside(tip, frame)
    if not (tip and frame) then return nil end
    local strip = frame
    if not frame.help and frame.GetParent then strip = frame:GetParent() end
    local right    = screenRead(strip, "GetRight")
    local width    = screenRead(tip, "GetWidth")
    local screen   = screenRead(UIParent, "GetRight")
    local tipScale = plainRead(tip, "GetEffectiveScale")
    if not (right and width and screen and tipScale) then return nil end
    tip:ClearAllPoints()
    if right + TIP_GAP * tipScale + width <= screen then
        tip:SetPoint("TOPLEFT", strip, "TOPRIGHT", TIP_GAP, 0)
    else
        tip:SetPoint("TOPRIGHT", strip, "TOPLEFT", -TIP_GAP, 0)
    end
    return true
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
---
--- EVERY STRIP CARRIES A CLOSE MARK, the player bar's included (the owner's ruling, DR-OW-03): an
--- X left of the help mark that turns off THIS bar and nothing wider. See closeBar.
---
--- ITS TOOLTIPS SIT BESIDE THE STRIP (TP-AT-02, LibKa0s v1.68.0): `tooltipPlace` is
--- NS.Util.PlaceTooltipBeside, which anchors the strip's, the `?`'s and the X's tooltips to the
--- strip's right, or its left when that would leave the screen -- the owner's rule for every Ka0s
--- strip. Until then each was owned by the hovered frame (ANCHOR_TOP off the strip, ANCHOR_TOPRIGHT
--- off a mark), which opened the strip's over the bar stacked above it and gave the marks a second
--- position. A read the placement cannot trust falls back to the cursor, the widget's own fallback.
local function buildHandle(bar, unit, globalName)
    if not (Widgets and Widgets.DragHandle) then return nil end
    local label = L[NS.Units.LABEL[unit] or unit]
    local wayBack = format(L["Re-enable it on General > Bars or with /at toggle %s."], unit)
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
        -- All three tooltips, the strip's and both marks', beside the strip. While a hook is in
        -- force the widget reads no owner or anchor, so the descriptors below carry neither.
        tooltipPlace = NS.Util.PlaceTooltipBeside,
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
        -- The close mark. Its art is the Media seam's; nil falls back to the widget's own texture.
        onClose      = function() closeBar(unit, label) end,
        closeIcon    = NS.Icon and NS.Icon("close") or nil,
        closeTooltip = {
            title  = format(L["Hide the %s bar"], label),
            body   = { L["Click to hide this bar."], wayBack },
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
