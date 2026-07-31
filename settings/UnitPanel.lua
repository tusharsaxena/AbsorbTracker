-- AbsorbTracker: settings/UnitPanel.lua
--
-- The two pieces of the old settings/Helpers.lua that are genuinely this addon's and did not go
-- upstream: the per-unit appearance page (the Unit dropdown, the mirror header, and the two-tier
-- refresher that keeps them honest) and the single reset-position implementation.
--
-- Neither generalizes. RenderUnitPanel reads NS.Units and the mirror partition, which no other Ka0s
-- addon has; ResetAllPositions clears a per-unit saved frame position, which is this addon's data
-- model. Everything they stand on — ClearScroll, EnsureScroll, RenderRows, AttachTooltip — is
-- LibKa0s-Options-1.0's, reached through the same NS.Helpers table, which IS the library instance
-- (settings/OptionsSetup.lua). Decorating it rather than sitting beside it is what lets a page file
-- call H.RenderUnitPanel and H.RenderSchema without knowing or caring which is which.

local addonName, NS = ...

local Helpers = NS.Helpers

-- ---------------------------------------------------------------------
-- Reset position
-- ---------------------------------------------------------------------

-- Clear EVERY unit's saved position and republish POSITION so all three bars re-anchor to their
-- stacked defaults. This is the single "reset position" implementation: `/at resetposition`
-- (settings/Slash.lua), the General page's "Reset Position" button (settings/General.lua) and the
-- descriptor's afterRestoreAll hook (settings/OptionsSetup.lua) all call it, so the CLI, the panel
-- and Reset All can never diverge.
--
-- They diverged here once already: the panel button nil'd `db.profile.position`, the pre-v3 FLAT
-- key that the v3 migration DELETES, so the assignment cleared an already-nil key and the POSITION
-- publish re-anchored every bar from its untouched NS.Units.Position. The button was a silent
-- no-op. Do not re-inline the loop at any call site.
function Helpers.ResetAllPositions()
    for _, unit in ipairs(NS.Units.LIST) do
        NS.Units.SetPosition(unit, nil)
    end
    NS.bus:SendMessage(NS.MSG.POSITION)
end

-- ---------------------------------------------------------------------
-- Per-unit panel rendering — Unit dropdown + mirror header
-- ---------------------------------------------------------------------

--- Render a per-unit appearance page (Bar / Border / Font): the Unit dropdown, the mirror header
--- for target/focus, then the schema rows filtered to the selected unit.
---
--- Full rebuild on every call rather than a persistent header widget: the library's ScrollFrame
--- anchors flush to ctx.body, so there is no free real estate above it to park a persistent
--- dropdown without surgery on that anchor. AceGUI's widget pool exists exactly to make
--- release-and-recreate cheap, so each call clears ctx.scroll and rebuilds from scratch.
---
--- The body is a private local so the public entry point below can pcall it — see the re-entrancy
--- guard there. Call Helpers.RenderUnitPanel, never this.
local function renderUnitPanelBody(ctx, pageKey)
    local AceGUI = NS.AceGUI

    ctx.unit = ctx.unit or "player"
    Helpers.ClearScroll(ctx)
    local scroll = Helpers.EnsureScroll(ctx)
    Helpers.__lastUnitCtx = ctx   -- test seam: the harness has no other handle on a live ctx

    -- Unit selector ---------------------------------------------------
    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel("Unit")
    dd:SetFullWidth(true)
    local items, order = {}, {}
    for i, u in ipairs(NS.Units.LIST) do
        items[u] = NS.Units.LABEL[u]
        order[i] = u
    end
    dd:SetList(items, order)
    dd:SetValue(ctx.unit)
    dd:SetCallback("OnValueChanged", function(_, _, value)
        ctx.unit = value
        Helpers.RenderUnitPanel(ctx, pageKey)
    end)
    scroll:AddChild(dd)
    Helpers.AddSpacer(scroll, Helpers.ROW_VSPACER)

    local rows = NS.SchemaForPage(pageKey, ctx.unit)
    local perUnitRows, styledRows = NS.PartitionUnitRows(rows)

    -- Mirror header (target / focus only) ------------------------------
    local mirrored = NS.Units.IsMirrored(ctx.unit)
    local cb                                   -- hoisted: the refresher at the bottom re-syncs it
    if ctx.unit ~= "player" then
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)

        cb = AceGUI:Create("CheckBox")
        cb:SetLabel("Use same styling as Player")
        cb:SetValue(mirrored)
        cb:SetRelativeWidth(0.5)
        cb:SetCallback("OnValueChanged", function(_, _, value)
            NS.SetByPath("units." .. ctx.unit .. ".mirror", value and true or false)
            Helpers.RenderUnitPanel(ctx, pageKey)
        end)
        Helpers.AttachTooltip(cb, "Use same styling as Player",
            "Mirror every Player bar appearance setting. Position and enable stay independent.")
        row:AddChild(cb)

        local btn = AceGUI:Create("Button")
        btn:SetText("Copy styling from Player")
        btn:SetRelativeWidth(0.5)
        btn:SetCallback("OnClick", function()
            NS.Units.CopyFromPlayer(ctx.unit)
            NS.bus:SendMessage(NS.MSG.APPEARANCE)
            Helpers.RenderUnitPanel(ctx, pageKey)
        end)
        Helpers.AttachTooltip(btn, "Copy styling from Player",
            "Take a one-time snapshot of the Player bar's appearance. Unlinks this unit so you can then edit it freely.")
        row:AddChild(btn)

        scroll:AddChild(row)
        Helpers.AddSpacer(scroll, Helpers.ROW_VSPACER)

        if mirrored then
            local hint = AceGUI:Create("Label")
            hint:SetText("Linked to Player \226\128\147 uncheck to customize.")
            hint:SetFullWidth(true)
            scroll:AddChild(hint)
            Helpers.AddSpacer(scroll, Helpers.ROW_VSPACER)
        end
    end

    -- Body: the per-unit rows always render; the appearance rows only when unlinked. The mirror
    -- row itself carries skipRender, so RenderRows leaves it to the header above.
    Helpers.RenderRows(ctx, perUnitRows)
    if not mirrored then
        Helpers.RenderRows(ctx, styledRows)
    end
    if scroll.DoLayout then scroll:DoLayout() end

    -- Register the HEADER's refresher. The mirror checkbox and the "Copy styling from Player"
    -- button above are built inline here, not through RenderField, so neither appends a refresher
    -- of its own — RefreshAllPanels structurally could not update them, and nothing re-ran the
    -- mirrored/unmirrored row partition. Concretely: RestoreDefaults("bar", ctx) resets
    -- units.focus.mirror to its default `true`, then runs only the refreshers, so the checkbox
    -- still read unchecked and the appearance rows stayed on screen over a now-mirrored unit
    -- (same stale state after `/at set units.focus.mirror true` and after a profile switch).
    --
    -- TWO-TIER, and the split matters. Every schema widget's write calls RefreshAllPanels, so this
    -- closure runs on EVERY checkbox click, slider drag and LSM pick on this page:
    --
    --   * Always — re-sync the checkbox in place. Cheap, tears nothing down.
    --   * Only when the mirror state actually CHANGED since this render — re-render, because that
    --     is the only thing that can invalidate the mirrored/unmirrored partition.
    --
    -- An unconditional re-render here would rebuild the whole page on every ordinary appearance
    -- write, and the mechanism (not the waste) is the problem: ClearScroll releases the very
    -- widget whose OnValueChanged is still on the stack — an LSM30_* dropdown with an open pullout,
    -- a slider mid-drag — and destroys scroll position and tooltips with it. The library's color
    -- picker already declines to call RefreshAllPanels for exactly this class of reason.
    --
    -- Registered LAST so the row refreshers above have already run; RefreshAllPanels iterates the
    -- pre-render table, so a closure registered by a re-render is not re-invoked in the same pass.
    local renderedUnit, renderedMirrored = ctx.unit, mirrored
    ctx.refreshers[#ctx.refreshers + 1] = function()
        local nowMirrored = NS.Units.IsMirrored(renderedUnit)
        if cb then cb:SetValue(nowMirrored) end
        if nowMirrored ~= renderedMirrored then
            Helpers.RenderUnitPanel(ctx, pageKey)
        end
    end
end

--- The public entry point. Every caller — the page files' OnShow, the Unit dropdown, the mirror
--- checkbox, the header refresher — goes through here.
---
--- Re-entrancy guard. The last thing a render does is register a refresher that re-renders the
--- whole panel, and a render registers a fresh refresher of its own. Without this flag, any
--- refresher pass fired from INSIDE a render — a widget's onChange reaching RefreshAllPanels while
--- the page is being built — would recurse. The flag makes the inner call a no-op; the outer render
--- finishes and leaves the panel correct.
---
--- The flag is cleared on BOTH paths, which is why the body is pcall'd. Cleared only on the normal
--- exit, a single raise anywhere inside the render — an AceGUI widget error, a malformed schema
--- row, a nil NS.Units.LABEL entry — latches it, and every later render returns silently at the
--- guard: the page looks frozen for the rest of the session and only /reload recovers it. The
--- library pcalls each refresher for the same reason. The failure is reported rather than
--- swallowed, because a page that silently declines to draw is the same bug wearing a hat.
function Helpers.RenderUnitPanel(ctx, pageKey)
    if not NS.AceGUI then return end
    if ctx.__rendering then return end

    ctx.__rendering = true
    local ok, err = pcall(renderUnitPanelBody, ctx, pageKey)
    ctx.__rendering = false

    if not ok then
        NS.Print(("Unit panel render failed: %s"):format(NS.SafeToString(err)))
    end
end
