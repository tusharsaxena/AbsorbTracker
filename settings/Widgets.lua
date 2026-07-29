-- AbsorbTracker: settings/Widgets.lua
--
-- Schema-row → AceGUI widget translation. Each widget maker reads via
-- NS.GetSetting, writes via NS.SetByPath (the
-- documented single-write seam), registers a refresher closure for
-- /at set + profile-change re-sync, and adds itself to the panel's
-- AceGUI scroll. Helpers.RenderField dispatches by row.type;
-- Helpers.RenderRows lays an explicit row list into 50/50 flow rows with
-- section headings and inter-row spacers; Helpers.RenderSchema is the
-- thin per-page wrapper around it.
--
-- Decorates NS.Helpers (created by OptionsPanel.lua, decorated
-- by Panel/Helpers.lua before this file loads).

local addonName, NS = ...

local Helpers = NS.Helpers

local function applyWidth(widget, relativeWidth)
    if relativeWidth then
        widget:SetRelativeWidth(relativeWidth)
    else
        widget:SetFullWidth(true)
    end
end

local function get(path) return NS.GetSetting(path) end

-- Write a row's value via the documented SetByPath seam (SetSetting +
-- fireOnChange in one call), then refresh every widget on every panel.
-- The refresh is what makes paired controls Just Work — a "Use Class
-- Color" toggle flips and the matching color picker greys out (or
-- un-greys) on the same frame. AceGUI SetValue doesn't fire
-- OnValueChanged, so this can't recurse.
local function set(row, value)
    NS.SetByPath(row.path, value)
    Helpers.RefreshAllPanels()
end

local function makeCheckbox(ctx, row, parent, relativeWidth)
    local AceGUI = NS.AceGUI
    parent = parent or Helpers.EnsureScroll(ctx)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(row.label or row.path)
    applyWidth(cb, relativeWidth)

    local function readValue()
        return get(row.path) and true or false
    end

    cb:SetValue(readValue())

    local function refresh() cb:SetValue(readValue()) end

    cb:SetCallback("OnValueChanged", function(_, _, value)
        set(row, value and true or false)
    end)

    Helpers.AttachTooltip(cb, row.label, row.desc)
    parent:AddChild(cb)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return cb
end

-- Non-schema session checkbox: a bare AceGUI CheckBox wired to caller-supplied get/set instead of
-- a schema path. For runtime-only, never-persisted toggles (the General page's "Debug console"
-- window show/hide) that must NOT become a saved setting — so they can't go through makeCheckbox
-- (which reads/writes a persisted path). Registers a refresher so RefreshAllPanels re-reads live
-- state (e.g. when the console window is opened/closed elsewhere). spec = { label, tooltip, get, set }.
function Helpers.SessionCheckbox(ctx, parent, relativeWidth, spec)
    local AceGUI = NS.AceGUI
    parent = parent or Helpers.EnsureScroll(ctx)
    local cb = AceGUI:Create("CheckBox")
    cb:SetLabel(spec.label)
    applyWidth(cb, relativeWidth)

    cb:SetValue(spec.get() and true or false)

    local function refresh() cb:SetValue(spec.get() and true or false) end

    cb:SetCallback("OnValueChanged", function(_, _, value)
        spec.set(value and true or false)
    end)

    Helpers.AttachTooltip(cb, spec.label, spec.tooltip)
    parent:AddChild(cb)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return cb
end

local function snapToStep(value, mn, step)
    if not (step and step > 0) then return value end
    return math.floor((value - mn) / step + 0.5) * step + mn
end

local function makeSlider(ctx, row, parent, relativeWidth)
    local AceGUI = NS.AceGUI
    parent = parent or Helpers.EnsureScroll(ctx)
    local s = AceGUI:Create("Slider")
    s:SetLabel(row.label or row.path)
    s:SetSliderValues(row.min or 0, row.max or 1, row.step or 1)
    s:SetIsPercent(false)
    applyWidth(s, relativeWidth)

    local function refresh()
        local v = get(row.path)
        if type(v) ~= "number" then v = row.default or row.min or 0 end
        s:SetValue(v)
    end

    s:SetCallback("OnMouseUp", function(_, _, value)
        local snapped = snapToStep(value, row.min or 0, row.step or 0)
        set(row, snapped)
    end)

    Helpers.AttachTooltip(s, row.label, row.desc)
    parent:AddChild(s)
    refresh()
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return s
end

local function makeDropdown(ctx, row, parent, relativeWidth)
    local AceGUI = NS.AceGUI
    parent = parent or Helpers.EnsureScroll(ctx)
    -- LSM dropdowns get the in-tree LSM30_* widget so each row renders
    -- with a swatch / font preview. Everything else uses the stock
    -- AceGUI Dropdown — both share enough of an interface
    -- (SetLabel/SetList/SetValue/OnValueChanged) that the rest of this
    -- function is unchanged either way. Fall back to plain Dropdown if
    -- AceGUI-3.0-SharedMediaWidgets failed to load (no swatch, but the
    -- option still renders).
    local widgetType = row.dialogControl or "Dropdown"
    if widgetType ~= "Dropdown" and not AceGUI:GetWidgetVersion(widgetType) then
        widgetType = "Dropdown"
    end
    local dd = AceGUI:Create(widgetType)
    dd:SetLabel(row.label or row.path)
    applyWidth(dd, relativeWidth)

    local function valuesHash()
        if type(row.values) == "function" then return row.values() or {} end
        return row.values or {}
    end

    local function applyList()
        local items = valuesHash()
        local order
        if row.sorting then
            order = {}
            for i, k in ipairs(row.sorting) do order[i] = k end
        else
            order = {}
            for k in pairs(items) do order[#order + 1] = k end
            table.sort(order)
        end
        dd:SetList(items, order)
    end
    applyList()
    dd:SetValue(get(row.path))

    local function refresh()
        applyList()                            -- LSM lists may grow over time
        dd:SetValue(get(row.path))
    end

    dd:SetCallback("OnValueChanged", function(_, _, value)
        set(row, value)
    end)

    Helpers.AttachTooltip(dd, row.label, row.desc)
    parent:AddChild(dd)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return dd
end

-- AT colors are stored as {r=, g=, b=, a=} named keys (see Settings.lua's
-- GetBarColor / GetBgColor / GetBorderColor). Read/write that shape here
-- so the rest of the addon doesn't have to translate.
local function makeColorPicker(ctx, row, parent, relativeWidth)
    local AceGUI = NS.AceGUI
    parent = parent or Helpers.EnsureScroll(ctx)
    local cp = AceGUI:Create("ColorPicker")
    cp:SetLabel(row.label or row.path)
    cp:SetHasAlpha(row.hasAlpha and true or false)
    applyWidth(cp, relativeWidth)

    local function readColor()
        local c = get(row.path)
        if type(c) ~= "table" then c = {} end
        return c.r or 1, c.g or 1, c.b or 1, c.a or 1
    end

    cp:SetColor(readColor())

    local function applyDisabled()
        if row.disabledIf then
            cp:SetDisabled(get(row.disabledIf) and true or false)
        end
    end
    applyDisabled()

    local function refresh()
        cp:SetColor(readColor())
        applyDisabled()
    end

    -- AceGUI's ColorPicker fires OnValueChanged during drag (live
    -- preview) and OnValueConfirmed on cancel (with the original color).
    -- Throttle the live-preview commits at 50 ms so a sustained drag
    -- doesn't repaint the bar 60×/s; cancel commits immediately so the
    -- bar snaps back to the pre-drag color without waiting on the
    -- throttle window. Intentionally does NOT call RefreshAllPanels — a
    -- sustained drag would re-traverse every panel widget every 50 ms.
    local function commit(r, g, b, a)
        NS.SetByPath(row.path, { r = r, g = g, b = b, a = a or 1 })
    end

    -- Single re-armed AceTimer + reused pendingArgs table — a sustained drag at 60 Hz produces
    -- O(1) garbage instead of 60 closures + 60 pendingArgs allocations per second. AceTimer
    -- (Ka0s standard §3.1) rather than a raw C_Timer; the one-shot self-clears so no CancelTimer.
    local pendingArgs
    local timer
    local function throttledCommit(r, g, b, a)
        pendingArgs = pendingArgs or {}
        pendingArgs[1], pendingArgs[2], pendingArgs[3], pendingArgs[4] = r, g, b, a
        if timer then return end
        timer = NS.addon:ScheduleTimer(function()
            timer = nil
            local p = pendingArgs
            pendingArgs = nil
            if p then commit(p[1], p[2], p[3], p[4]) end
        end, 0.05)
    end

    cp:SetCallback("OnValueChanged",   function(_, _, r, g, b, a) throttledCommit(r, g, b, a) end)
    cp:SetCallback("OnValueConfirmed", function(_, _, r, g, b, a) commit(r, g, b, a) end)

    Helpers.AttachTooltip(cp, row.label, row.desc)
    parent:AddChild(cp)
    ctx.refreshers[#ctx.refreshers + 1] = refresh
    return cp
end

-- Generic field renderer — dispatches by row.type.
function Helpers.RenderField(ctx, row, parent, relativeWidth)
    if row.type == "bool"   then return makeCheckbox(ctx, row, parent, relativeWidth)    end
    if row.type == "number" then return makeSlider(ctx, row, parent, relativeWidth)      end
    if row.type == "string" then return makeDropdown(ctx, row, parent, relativeWidth)    end
    if row.type == "color"  then return makeColorPicker(ctx, row, parent, relativeWidth) end
end

-- ---------------------------------------------------------------------
-- Schema-driven render
-- ---------------------------------------------------------------------
--
-- Schema widgets are paired into 50%/50% Flow rows, each row wrapped in
-- a full-width SimpleGroup so AceGUI's layout pass gives both children
-- exactly half the panel width and breaks them onto the same line.
-- Section headings span the full width (one per row), and every row is
-- followed by a small vertical spacer for breathing room. afterGroup
-- callbacks (e.g. inline action buttons) fire after the in-progress row
-- is flushed, so they always start on a fresh line.
--
-- pairWith (optional) = { [path] = maker(ctx, rowGroup) }: attach a non-schema widget as the
-- right partner of a named path's row (e.g. the General page's session "Debug console" checkbox
-- beside "Lock Position"). One-shot, and only when that path is the lone widget on its row, so the
-- pair stays 50/50 and never overflows to three-wide.

--- Render an EXPLICIT list of schema rows into ctx's scroll. This is the former RenderSchema
--- body, lifted so Helpers.RenderUnitPanel can render a filtered subset (the mirror partition).
--- Rows carrying `skipRender` stay in the schema (so /at get|set and the Defaults buttons still
--- see them) but are not drawn here — the panel renders them bespoke, e.g. the mirror checkbox
--- in the per-unit page header.
function Helpers.RenderRows(ctx, rows, afterGroup, pairWith)
    local AceGUI = NS.AceGUI
    local scroll = Helpers.EnsureScroll(ctx)
    local pendingRow, pendingCount = nil, 0

    local function flushRow()
        if pendingRow then
            scroll:AddChild(pendingRow)
            Helpers.AddSpacer(scroll, Helpers.ROW_VSPACER)
            pendingRow, pendingCount = nil, 0
        end
    end

    local function startRow()
        local r = AceGUI:Create("SimpleGroup")
        r:SetLayout("Flow")
        r:SetFullWidth(true)
        return r
    end

    for i, row in ipairs(rows) do
        if row.group and row.group ~= ctx.lastGroup then
            flushRow()                 -- previous group's tail row
            Helpers.Section(ctx, row.group)
            ctx.lastGroup = row.group
        end

        -- row.solo = true means "render this widget alone in the left
        -- half of its own row, leaving the right half empty." Used for
        -- visually-grouping pivots.
        if not row.skipRender then
            if row.solo and pendingCount > 0 then
                flushRow()
            end

            if not pendingRow then pendingRow = startRow() end
            Helpers.RenderField(ctx, row, pendingRow, 0.5)
            pendingCount = pendingCount + 1
            if pairWith and row.path and pairWith[row.path] and pendingCount == 1 then
                pairWith[row.path](ctx, pendingRow)
                pairWith[row.path] = nil       -- one-shot
                pendingCount = pendingCount + 1
            end
            if row.solo or pendingCount >= 2 then flushRow() end
        end

        local nextRow = rows[i + 1]
        if afterGroup and row.group
           and (not nextRow or nextRow.group ~= row.group)
           and afterGroup[row.group] then
            flushRow()                 -- afterGroup buttons start fresh
            afterGroup[row.group](ctx)
            afterGroup[row.group] = nil  -- one-shot
        end
    end
    flushRow()
    if scroll.DoLayout then scroll:DoLayout() end
end

function Helpers.RenderSchema(ctx, pageKey, afterGroup, pairWith)
    Helpers.RenderRows(ctx, NS.SchemaForPage(pageKey, ctx.unit), afterGroup, pairWith)
end
