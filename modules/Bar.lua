local addonName, NS = ...

-- The absorb bar frames — one per unit (player / target / focus). Built at file-load time from
-- the per-unit defaults (no DB yet — appearance is re-applied from the active profile on enable).
-- Exports NS.bars keyed by unit; every caller, tests included, indexes NS.bars[unit].
--
-- LAYERING: every strata and level written here reads NS.Constants.LAYERS (core/Constants.lua),
-- whose header comment is the addon's whole stack. Inside one bar, from its own level: the
-- backdrop background on the root, the fill, the border frame, the text overlay frame, and the
-- drag strip on top (frame-layering-§2, §3). NS.ApplyBarLayers is the one place a level is set.

local C = NS.Constants
local LAYERS = C.LAYERS
local unitDefaults = NS.unitDefaults
local L = NS.L

-- LibKa0s-Widgets-1.0, for its unlocked drag handle, through the core/WidgetsSetup.lua seam: the
-- live major, or on a build with no LibKa0s a stub whose DragHandle answers nil, and then no strip
-- is drawn -- see NS.CreateBar. Captured at load; the TOC loads the seam before this file.
local Widgets = NS.Widgets

--- Save where a bar was dropped. THE one save for both grab points -- the bar body's own
--- OnDragStop and its handle's onDragStop -- so the two cannot disagree about what a drop writes.
--- Position is per-unit and never mirrored, so the write always targets this frame's own unit.
---
--- THROUGH THE SCHEMA SEAM since ATF-03 (architecture-§5, "a row wins"): the Appearance page's
--- Position rows address the offsets, so a drop writes them with NS.SetByPath, bracketed as one
--- act. The anchor point, which no row addresses, is the drag's own geometry and is set first,
--- in place (Units.SetAnchor). Without the rows (no LibKa0s: the composer is hollow) the whole
--- position is stored as before.
local function savePosition(bar)
    local point, _, relPoint, x, y = bar:GetPoint()
    local base = "units." .. bar.unit .. ".position."
    if NS.FindSchemaRow and NS.FindSchemaRow(base .. "x") and NS.FindSchemaRow(base .. "y") then
        NS.Units.SetAnchor(bar.unit, point, relPoint)
        NS.Bulk.Run("drag", bar.unit, function()
            NS.SetByPath(base .. "x", x)
            NS.SetByPath(base .. "y", y)
        end)
    else
        NS.Units.SetPosition(bar.unit, { point = point, relPoint = relPoint, x = x, y = y })
    end
    -- A drop is a move, which fires no script: the sim strip decides its side again (AD-88-AT).
    NS.PlaceSimStrip(bar)
    -- The Appearance page's Position sliders read this position (ATF-03): an open page follows.
    if NS.RefreshOptionsValues then NS.RefreshOptionsValues() end
end

--- The close mark's click: turn off this ONE bar. It writes the existing per-unit enable row --
--- `units.<unit>.enabled`, the row the Appearance band draws as "Enable this unit" and `/at toggle
--- <unit>` flips -- through
--- NS.SetByPath, the one schema write seam, so the [Set] trace, the row's onChange (which re-syncs
--- the unit's event registrations and repaints), the refresh bus and an open panel all fire exactly
--- as they do from the checkbox. Never the addon-wide `enabled` and never the shared `locked`: the
--- other bars stay where they are. Position is untouched, so turning the bar back on puts it back
--- where it was. One chat line names the way back; the X's tooltip carries the same sentence.
---
--- No combat rule of its own: the strip is only shown unlocked, and the lock closes in combat.
local function closeBar(unit, label)
    NS.SetByPath("units." .. unit .. ".enabled", false)
    NS.Print(format(L["%s bar hidden. Re-enable it on the Appearance page or with /at toggle %s."],
        label, unit))
end

--- The unlocked drag handle over one bar: LibKa0s-Widgets-1.0's DragHandle, a dark strip with a
--- gold edge, the unit's name centered in gold and three marks at its right end
--- (`?`, settings gear, X, the X in the corner). The three bars
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
--- copy the widget exists to delete. The core/WidgetsSetup.lua stub's DragHandle answers nil, so
--- nothing raises -- `bar.handle` stays nil and the appearance pass guards on it -- and the bar
--- body's own drag, below, still moves the bar.
---
--- Nothing here is protected: the bars are plain frames, and the lock refuses to open in combat
--- (settings/General.lua's `locked` row) and re-locks when combat starts (core/AbsorbTracker.lua),
--- so a strip is never shown, and never dragged, mid-fight.
---
--- EVERY STRIP CARRIES ALL THREE MARKS, read left to right `?` · settings · X (the owner's ruling
--- of 2026-11-19, AF-STRIP-AT; WidgetsDragHandle minor 15 owns the order, the spacing and the
--- header tints). The player bar's strip is no exception.
---
--- THE X turns off THIS bar and nothing wider, keeping every setting (DR-OW-03). See closeBar. The
--- way back is the Appearance page's "Enable this unit" box or `/at toggle <unit>`, and the X's
--- tooltip and its chat line both say so.
---
--- THE SETTINGS MARK opens THIS bar's settings: NS.OpenUnitSettings (settings/Appearance.lua) opens
--- the Appearance page with its Unit picker on this bar's unit. It replaced AD-86-AT's
--- `settings = true`, which went through the launcher's opener to the landing page. The mark is
--- the library's default from minor 15, so the spec only hands it the opener, the art and words.
---
--- ITS TOOLTIPS ARE ATTACHED ABOVE THE STRIP (AD-92-AT, LibKa0s#92): the strip is the bar's title
--- bar, a chrome element (WowAddonStandards standalone-windows, *Tooltip placement*), so the
--- strip's, the `?`'s, the X's and the settings mark's tooltips are centered on the strip, 2 px
--- above it, flipped below only without room above, never at the cursor. The widget places them
--- (WidgetsDragHandleTip minor 2 places every strip tooltip itself and ignores `tooltipPlace`), so
--- this spec hands it no hook. From TP-AT-02 (LibKa0s v1.68.0) until AD-92-AT the hook was this
--- file's NS.Util.PlaceTooltipBeside, which opened them beside the strip; it is retired. Each mark
--- carries its own descriptor, so none falls back to the strip's "Drag to move".
local function buildHandle(bar, unit, globalName)
    local label = L[NS.Units.LABEL[unit] or unit]
    local wayBack = format(L["Re-enable it on the Appearance page or with /at toggle %s."], unit)
    local handle = Widgets.DragHandle(bar, {
        name      = globalName .. "Handle",
        label     = label,
        moveFrame = bar,
        -- The skin owner (core/SkinSetup.lua registered it at file load, above this file): the
        -- strip's fill, edge, label and mark tints come from this addon's skin (WidgetsDragHandle
        -- minor 6), and a skin switch repaints them. Ka0s Default draws the strip as before.
        owner     = addonName,
        -- nil falls back to the widget's own last rung, a Blizzard texture, not to nothing.
        helpIcon  = NS.Icon and NS.Icon("ph:question") or nil,
        -- Dragging is the LOCK's business. A locked bar is not movable (UpdateBarAppearance), and
        -- StartMoving on a frame that is not movable raises, so the strip asks before it starts.
        canDrag    = function() return not NS.GetSetting("locked") end,
        onDragStop = function() savePosition(bar) end,
        -- No `tooltipPlace`: all four tooltips, the strip's and its three marks', are the library's
        -- to place, attached above the strip (AD-92-AT). The descriptors carry no owner or anchor.
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
        -- The settings mark (standard from minor 15): this bar's own settings, the Appearance page
        -- on this unit. Read at click time, so settings/Appearance.lua, which loads after this
        -- file, publishes the opener before any strip can be clicked. Its own tooltip, because
        -- without one it would repeat the strip's "Drag to move".
        onSettings      = function()
            if NS.OpenUnitSettings then NS.OpenUnitSettings(unit) else NS.OpenOptionsPanel() end
        end,
        settingsIcon    = NS.Icon and NS.Icon("settings") or nil,
        settingsTooltip = {
            title = format(L["%s bar settings"], label),
            body  = { L["Click to open this bar's settings on the Appearance page."] },
        },
        -- Edit chrome sits at the top of its display (frame-layering-§2): an offset over the bar,
        -- applied by the widget before it builds the marks, so the `?` and X are born at
        -- handle + 1. HANDLE clears every content level of a neighboring bar at the same base, so
        -- an overlapping bar's fill or text cannot cover this strip. NS.ApplyBarLayers re-applies
        -- it (handle:ApplyLevel) whenever the bar's own level moves.
        level = LAYERS.LEVEL.HANDLE,
        -- The move affordance must stay visible when the bar is faded to 0% (Bar opacity times
        -- Master alpha): an invisible strip that still takes the click is anti-pattern #101.
        ignoreParentAlpha = true,
    })
    if handle then
        handle:SetPoint("BOTTOM", bar, "TOP", 0, Widgets.DRAG_HANDLE.GAP)
    end
    return handle
end

-- ---------------------------------------------------------------------------
-- The simulation's strip (AD-88-AT)
-- ---------------------------------------------------------------------------
--
-- Each bar is a HUD display the player positions on its own, so each carries its own cyan strip
-- while `/at sim` paints its made-up shield (WowAddonStandards preview-mode, *Where the strip sits*:
-- on a HUD display's top edge, outside it). LibKa0s-Widgets-1.0's TestStrip with `dock = "hud"`
-- (Widgets minor 27) places it, never this file: on the bar's top edge spanning its width, stacked
-- beyond the drag handle while an unlocked bar shows one (`clear`), and flipped under the bar while
-- the top would leave the screen. The library turns its mouse off and lifts it into the bar's chrome
-- band (bar level + 5), so it never takes a click and never covers the handle, which stays.
--
-- The host's whole share: build it hidden here, show and hide it with the session (NS.ShowSimStrips,
-- from modules/Sim.lua's prepare and stop) and call strip:Place() after it moves a bar
-- (NS.PlaceSimStrip), because a move fires no script. The step panel stays on screen as well. This
-- addon has no test mode (the unlocked view is its preview), so there is no amber strip; the bars
-- carry no header, so there is no mode word to drop. Nil on a build without the Widgets major.
local function buildSimStrip(bar)
    if not bar.handle then return nil end
    return Widgets.TestStrip(bar, {
        text   = L["SIM: a simulated shield, not live data."],
        icon   = NS.Icon and NS.Icon("info") or nil,
        kind   = "sim",
        owner  = addonName,
        dock   = "hud",
        target = bar,
        clear  = bar.handle,
    })
end

--- Show (`on`) or hide every bar's sim strip. A strip shows only while its bar does: it is the
--- bar's child, so a bar the ladder hides takes its strip with it.
function NS.ShowSimStrips(on)
    for _, unit in ipairs(NS.Units.LIST) do
        local bar = NS.bars and NS.bars[unit]
        local strip = bar and bar.simStrip
        if strip then
            strip:SetShown(on == true)
            if on then strip:Place() end
        end
    end
end

--- After the host moves `bar`: place its strip again while it shows (a hidden one places itself on
--- its next show).
function NS.PlaceSimStrip(bar)
    local strip = bar and bar.simStrip
    if strip and strip:IsShown() and strip.Place then strip:Place() end
end

--- A frame level read as a plain number. The bars are our own plain frames and a real client
--- always answers a number here; anything else (a headless stand-in) reads 0 rather than being
--- computed on, so a layering pass can never raise inside the appearance pass.
local function levelOf(frame)
    local v = frame:GetFrameLevel()
    if type(v) ~= "number" then return 0 end
    return v
end

--- Put every child of one bar at its LAYERS offset over the bar's CURRENT level: the fill, the
--- border frame, the text overlay frame and the drag strip (whose marks follow at handle + 1).
--- Called once at creation and again by every appearance pass (modules/Display.lua), because the
--- bar is toplevel and a raise moves its level; an explicit level is re-asserted wherever its base
--- can move, never set once and trusted (frame-layering-§3). Plain frames, so safe in combat.
function NS.ApplyBarLayers(bar)
    local base = levelOf(bar)
    bar.statusBar:SetFrameLevel(base + LAYERS.LEVEL.FILL)
    bar.border:SetFrameLevel(base + LAYERS.LEVEL.BORDER)
    bar.overlay:SetFrameLevel(base + LAYERS.LEVEL.OVERLAY)
    if bar.handle and bar.handle.ApplyLevel then bar.handle:ApplyLevel() end
end

--- Build one bar. Each frame owns its OWN backdropInfo and borderInfo tables: one shared table
--- cannot hold three different border sizes, and WoW's SetBackdrop keys off table identity.
function NS.CreateBar(unit, globalName)
    local bar = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
    bar.unit = unit
    -- The HUD tier, stated on the root even though UIParent's is the same (frame-layering-§1):
    -- a decision with a name, not a side effect of the parent. Children inherit it.
    bar:SetFrameStrata(LAYERS.STRATA.HUD)
    -- The three bars are peers that can overlap. Toplevel, so the one the player grabs comes to
    -- the front WHOLE instead of the two interleaving level by level (frame-layering-§3, peers
    -- stack whole). A locked bar takes no mouse (UpdateBarAppearance), so locked bars never move.
    bar:SetToplevel(true)

    -- The root's backdrop is the BACKGROUND only. Its edge lives on bar.border, a frame above the
    -- fill: drawn here on the root, a border thicker than the fill's 3 px inset was painted over
    -- by the fill along the filled fraction only, so its inner edge changed width where the fill
    -- ended (frame-layering-§3: a border is a frame above the fill).
    bar.backdropInfo = {
        bgFile = C.FALLBACK_TEXTURE,
        tile = false,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    }

    bar:SetSize(unitDefaults.barWidth, unitDefaults.barHeight)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    bar:SetBackdrop(bar.backdropInfo)
    -- Every build-time look is the profile's own getter, never a literal (anti-pattern #107): at
    -- file load there is no profile yet and each answers the defaults; the first appearance pass
    -- (modules/Display.lua) paints the real values before the bar is shown.
    bar:SetBackdropColor(NS.GetBgColor(unit))
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
    statusBar:SetStatusBarColor(NS.GetBarColor(unit))
    bar.statusBar = statusBar

    -- The border: the backdrop EDGE alone, on its own frame over the whole bar, above the fill.
    -- Mouse-off, so a drag on the bar's body still reaches the bar.
    local border = CreateFrame("Frame", nil, bar, "BackdropTemplate")
    border:SetAllPoints(bar)
    border:EnableMouse(false)
    bar.borderInfo = {
        edgeFile = NS.GetBorder(unit),
        tile = false,
        edgeSize = NS.GetBorderSize(unit),
    }
    border:SetBackdrop(bar.borderInfo)
    border:SetBackdropBorderColor(NS.GetBorderColor(unit))
    bar.border = border

    -- The text overlay: a mouse-off frame over the whole bar, above the border, that hosts the
    -- absorb value text, so neither the fill nor a thick border can draw over the number.
    local overlay = CreateFrame("Frame", nil, bar)
    overlay:SetAllPoints(bar)
    overlay:EnableMouse(false)
    bar.overlay = overlay

    -- Absorb value text, on the overlay (the top of the bar's content).
    local valueText = overlay:CreateFontString(nil, "OVERLAY", nil)
    -- The defaults through the skin's two sizers (LibKa0s v1.82.0): "@skin" is never handed to
    -- SetFont. The appearance pass right after creation draws the unit's own (modules/Display.lua).
    local S = NS.Skin
    valueText:SetFont(NS.GetFont(unit), S.HudFontSize(unitDefaults.fontSize, unitDefaults.fontFromSkin),
        S.FontFlags(unitDefaults.fontFlags))
    -- Spans the bar rather than keeping the width of its own text: an unsized FontString holds the
    -- width it measured under the previous face, so a wider skin face (High Contrast) clipped
    -- "Absorb" to "Absor" (SF-AT-1). Centered inside the span, never wrapped.
    valueText:SetPoint("LEFT", bar, "LEFT", 0, 0)
    valueText:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
    valueText:SetJustifyH("CENTER")
    valueText:SetWordWrap(false)
    bar.valueText = valueText

    -- The unlocked drag handle above the bar, naming its unit. Nil on a build without
    -- LibKa0s-Widgets-1.0; see buildHandle.
    bar.handle = buildHandle(bar, unit, globalName)
    -- The sim's cyan strip on the bar's top edge, beyond the handle. Nil without the widget.
    bar.simStrip = buildSimStrip(bar)

    -- Every child at its LAYERS offset; the appearance pass re-asserts it.
    NS.ApplyBarLayers(bar)

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
