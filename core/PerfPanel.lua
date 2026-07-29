local addonName, NS = ...
NS.PerfPanel = NS.PerfPanel or {}
local Panel = NS.PerfPanel

-- core/PerfPanel.lua — the clickable step panel for a perf run (issue #17).
--
-- Appears on `/at perf start` and walks the user through the run one step at a time. The ordering
-- is the whole point: arming Experiment B before pulling, or forgetting `/reload`, silently ruins a
-- capture, and a numbered list in chat scrolls away the moment combat starts. A panel that only
-- offers the next legal step cannot be done out of order.
--
-- This file is a DUMB RENDERER. Every question about what is clickable lives in NS.Perf.Progress(),
-- which is pure state and headlessly testable; the panel asks it and draws the answer. Buttons
-- dispatch through the slash layer (`NS.Slash:OnSlash("perf measure a")`) rather than calling the
-- probe directly, so a click and a typed command can never take different code paths.

-- Three columns: status dot, step, slash command. The command column is the point — it teaches the
-- typed form while you click, so the panel is a crutch you can stop needing.
local ROW_W, ROW_H, GAP = 360, 22, 4
local DOT_X, DOT = 8, 8        -- column 1: status dot
local LABEL_X   = 26           -- column 2: step name
local CMD_PAD   = 10           -- column 3: slash command, right-aligned
local TITLE_H = 24
local PAD = 8

-- Same shape as the debug console's skin so the two windows read as one addon.
local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}

-- Per-state colour, used for both the row's text and its status dot. `busy` deliberately shares the
-- gold of an interactive control: the step IS happening, and greying it out would read as "nothing
-- is going on" during the one phase where the user most needs to know the addon is recording.
local COLORS = {
    done   = { 0.30, 0.85, 0.30 },
    -- Same green as `done`: it has been run. Still clickable, because re-reading a report costs
    -- nothing and is regularly wanted twice.
    used   = { 0.30, 0.85, 0.30 },
    ready  = { 0.90, 0.90, 0.92 },
    busy   = { 1.00, 0.82, 0.00 },
    locked = { 0.40, 0.40, 0.42 },
    -- Muted red rather than a warning red: cancel is always available, so a shade that shouts would
    -- shout on every frame of every run.
    cancel = { 0.80, 0.32, 0.32 },
}

-- Command column, dimmer than its row so it reads as reference rather than as another control.
local CMD_COLOR = { 0.45, 0.45, 0.48 }

-- Ordered, and the order IS the workflow. `key` matches a field of NS.Perf.Progress(); `command` is
-- the slash line the button runs.
local STEPS = {
    { key = "start",    label = "Start",                         command = "perf start"     },
    { key = "measureA", label = "Measure A (with the addon)",    command = "perf measure a" },
    { key = "measureB", label = "Measure B (without the addon)", command = "perf measure b" },
    { key = "finish",   label = "Finish",                        command = "perf finish"    },
    { key = "report",   label = "Report",                        command = "perf report"    },
    { key = "dump",     label = "Dump",                           command = "perf dump"      },
    -- Outside the linear progression: always clickable, at every point including none. Abandons an
    -- in-flight run unsaved, and doubles as "dismiss this panel" once a run has finished.
    { key = "cancel",   label = "Cancel run",                    command = "perf cancel"    },
}
Panel.STEPS = STEPS

local frame

local function setColor(fs, state)
    local c = COLORS[state] or COLORS.locked
    fs:SetTextColor(c[1], c[2], c[3])
end

--- Build one step row. The click handler re-checks Progress() rather than trusting the button's
--- enabled state: the mock (and a sufficiently determined user) can fire a script directly, and a
--- step that runs out of order corrupts the run it was meant to protect.
local function makeStepButton(parent, step, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(ROW_W, ROW_H)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", PAD, -(TITLE_H + PAD + (index - 1) * (ROW_H + GAP)))

    -- Status dot drawn with SetColorTexture rather than a glyph or an art file. A text tick (U+2713)
    -- rendered as tofu in the default font, and any Interface\\... path is a guess that fails
    -- silently as a green box. A solid colour texture has no dependency and cannot not render.
    local dot = b:CreateTexture(nil, "ARTWORK")
    dot:SetSize(DOT, DOT)
    dot:SetPoint("LEFT", b, "LEFT", DOT_X, 0)
    b.dot = dot

    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", b, "LEFT", LABEL_X, 0)
    fs:SetJustifyH("LEFT")
    b.text = fs

    local cmd = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cmd:SetPoint("RIGHT", b, "RIGHT", -CMD_PAD, 0)
    cmd:SetJustifyH("RIGHT")
    cmd:SetText("/at " .. step.command)
    cmd:SetTextColor(CMD_COLOR[1], CMD_COLOR[2], CMD_COLOR[3])
    b.cmd = cmd

    b.step = step

    b:SetScript("OnEnter", function()
        local state = Panel.StateOf(step.key)
        if state == "cancel" then fs:SetTextColor(1.00, 0.45, 0.45)
        elseif state == "ready" or state == "used" then fs:SetTextColor(1, 0.82, 0) end
    end)
    b:SetScript("OnLeave", function() setColor(fs, Panel.StateOf(step.key)) end)
    b:SetScript("OnClick", function()
        if not Panel.IsActionable(step.key) then return end
        if NS.Slash and NS.Slash.OnSlash then NS.Slash:OnSlash(step.command) end
        Panel:Refresh()
    end)
    return b
end

--- Current state of one step, straight from the probe. Nil-safe so the panel can exist before a run.
function Panel.StateOf(key)
    if not (NS.Perf and NS.Perf.Progress) then return "locked" end
    return NS.Perf.Progress()[key] or "locked"
end

--- Can this row be clicked? `ready` is the one legal next step, `cancel` is available for as long
--- as there is a run to abandon, and `used` is a review action that stays repeatable.
function Panel.IsActionable(key)
    local state = Panel.StateOf(key)
    return state == "ready" or state == "cancel" or state == "used"
end

local function EnsureFrame()
    if frame then return frame end
    if type(CreateFrame) ~= "function" then return nil end

    local height = TITLE_H + PAD * 2 + #STEPS * (ROW_H + GAP)
    frame = CreateFrame("Frame", "AbsorbTrackerPerfPanel", UIParent, "BackdropTemplate")
    frame:SetSize(ROW_W + PAD * 2, height)
    frame:SetPoint("CENTER", -320, 0)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", frame, "TOP", 0, -6)
    title:SetText("Absorb Tracker \226\128\148 Perf Run")
    frame.title = title

    -- Close hides the window WITHOUT touching the run — a hidden panel is not an abandoned capture.
    -- Cancelling is the Cancel row's job, and conflating the two would make dismissing a window a
    -- destructive act. `/at perf show` (or `toggle`) brings it back.
    --
    -- Built by the debug console's own factory rather than a lookalike, so the two windows cannot
    -- drift apart. Guarded only because a close button is worth degrading over, not erroring over.
    if NS.DebugLog and NS.DebugLog.MakeCloseButton then
        local close = NS.DebugLog.MakeCloseButton(frame, function() Panel:Hide() end)
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(TITLE_H - 18) / 2)
        frame.closeButton = close
    end

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -TITLE_H)
    divider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -TITLE_H)
    divider:SetHeight(1)
    divider:SetColorTexture(0.24, 0.24, 0.27, 0.85)

    frame.buttons = {}
    for i, step in ipairs(STEPS) do
        frame.buttons[step.key] = makeStepButton(frame, step, i)
    end

    if frame.SetBackdrop then
        frame:SetBackdrop(BACKDROP)
        frame:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
        frame:SetBackdropBorderColor(0, 0, 0, 1)
    end

    frame:Hide()
    -- Esc closes it, like the debug console. Hiding is non-destructive, so this is safe to wire.
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "AbsorbTrackerPerfPanel")
    end
    return frame
end

--- Repaint every row from the probe's current state. Cheap and idempotent, so it is safe to call
--- from the bus on every transition rather than trying to work out which row changed.
function Panel:Refresh()
    if not frame then return end
    for _, step in ipairs(STEPS) do
        local b = frame.buttons[step.key]
        if b then
            local state = Panel.StateOf(step.key)
            b.text:SetText(step.label)
            setColor(b.text, state)
            -- The dot carries the state at a glance: green behind you, gold on the step that is
            -- actually happening, grey ahead. Dimmed while locked so the eye skips it.
            local c = COLORS[state] or COLORS.locked
            if b.dot.SetColorTexture then
                b.dot:SetColorTexture(c[1], c[2], c[3], state == "locked" and 0.35 or 1)
            end
            if Panel.IsActionable(step.key) then b:Enable() else b:Disable() end
            -- What was actually rendered, for the headless suite. The mock's FontString stub cannot
            -- be asked (it returns the parent frame, and defining SetText on it would break the
            -- other suites' SetText spies — see the note in tests/wow_mock.lua).
            b.__label, b.__state, b.__command = step.label, state, "/at " .. step.command
        end
    end
end

function Panel:Show()
    local f = EnsureFrame()
    if not f then return end
    Panel:Refresh()
    f:Show()
end

function Panel:Hide() if frame then frame:Hide() end end
function Panel:IsShown() return (frame and frame:IsShown()) and true or false end

function Panel:Toggle()
    if Panel:IsShown() then Panel:Hide() else Panel:Show() end
end

-- Test seam: reach the buttons without a live client.
function Panel.__frame() return frame end

-- Bus subscription (architecture-§4). This module owns the SOLE subscription to PERF, on its own
-- target so no two receivers share a table (anti-pattern #32). core/Perf.lua publishes on every
-- phase transition; the panel re-reads Progress() rather than being handed state.
if NS.NewBusTarget then
    Panel.__ev = NS.NewBusTarget()
    Panel.__ev:RegisterMessage(NS.MSG.PERF, function()
        if NS.PerfPanel then NS.PerfPanel:Refresh() end
    end)
end
