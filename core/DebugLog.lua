local addonName, NS = ...
NS.DebugLog = NS.DebugLog or {}
local D = NS.DebugLog
local frame

-- On-screen debug console (Ka0s standard §12). Debug output (NS.Debug) renders here in a
-- monospace font instead of spamming the chat frame. Session-only: enabled state lives in
-- NS.State.debug and resets on every reload/login (§12.5).

-- Plain-text mirror of the log (no colour codes), for the Copy window. Capped like the log.
D.buffer = D.buffer or {}
local MAX_BUFFER = 500

-- Backdrop shared by the console + copy windows so they read like the addon's own frames.
local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
}
local function applySkin(f)
    if not f.SetBackdrop then return end
    f:SetBackdrop(BACKDROP)
    f:SetBackdropColor(0.06, 0.06, 0.07, 0.95)
    f:SetBackdropBorderColor(0, 0, 0, 1)
end

-- Small flat text button for the title bar (Copy / Clear).
local function makeTextButton(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 18)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("CENTER")
    fs:SetText(text)
    fs:SetTextColor(0.7, 0.7, 0.72)
    b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.82, 0) end)
    b:SetScript("OnLeave", function() fs:SetTextColor(0.7, 0.7, 0.72) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function makeCloseButton(parent, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("CENTER")
    fs:SetText("\195\151")  -- multiplication sign ×
    fs:SetTextColor(0.7, 0.7, 0.72)
    b:SetScript("OnEnter", function() fs:SetTextColor(1, 0.3, 0.3) end)
    b:SetScript("OnLeave", function() fs:SetTextColor(0.7, 0.7, 0.72) end)
    b:SetScript("OnClick", onClick)
    return b
end

local function EnsureFrame()
    if frame then return frame end

    frame = CreateFrame("Frame", "AbsorbTrackerDebugWindow", UIParent, "BackdropTemplate")
    frame:SetSize(700, 344)
    frame:SetPoint("CENTER", 220, -80)
    frame:SetFrameStrata("DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 1, -1)
    titleBar:SetPoint("TOPRIGHT", -1, -1)
    titleBar:SetHeight(26)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local title = titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("CENTER")
    title:SetText("Absorb Tracker \226\128\148 Debug")
    frame.title = title

    local divider = frame:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0)
    divider:SetPoint("TOPRIGHT", titleBar, "BOTTOMRIGHT", 0, 0)
    divider:SetHeight(1)
    divider:SetColorTexture(0, 0, 0, 1)
    frame.divider = divider

    local close = makeCloseButton(titleBar, function() D:Hide() end)
    close:SetPoint("RIGHT", titleBar, "RIGHT", -6, 0)

    local clear = makeTextButton(titleBar, "Clear", 42, function() D:Clear() end)
    clear:SetPoint("RIGHT", close, "LEFT", -6, 0)

    local copy = makeTextButton(titleBar, "Copy", 40, function() D:ShowCopy() end)
    copy:SetPoint("RIGHT", clear, "LEFT", -6, 0)

    -- Left-aligned debug on/off toggle: resting colour reflects state (green ON / red OFF);
    -- clicking flips state through the shared SetEnabled seam.
    local toggleBtn = CreateFrame("Button", nil, titleBar)
    toggleBtn:SetSize(80, 18)
    toggleBtn:SetPoint("LEFT", titleBar, "LEFT", 8, 0)
    local toggleFS = toggleBtn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    toggleFS:SetPoint("LEFT")
    toggleBtn:SetScript("OnEnter", function() toggleFS:SetTextColor(1, 0.82, 0) end)
    toggleBtn:SetScript("OnLeave", function() D:RefreshHeader() end)
    local function onToggleClick() D:SetEnabled(not (NS.State and NS.State.debug)) end
    toggleBtn:SetScript("OnClick", onToggleClick)
    frame.debugToggle = toggleFS
    frame.debugToggleBtn = toggleBtn
    D._toggleClickForTest = onToggleClick   -- test seam (mock stubs GetScript)

    local log = CreateFrame("ScrollingMessageFrame", nil, frame)
    log:SetPoint("TOPLEFT", 8, -(26 + 6))
    log:SetPoint("BOTTOMRIGHT", -8, 14)
    log:SetFont(NS.Constants.FONT_MONO, 10, "")
    log:SetJustifyH("LEFT")
    log:SetFading(false)
    log:SetMaxLines(500)
    log:EnableMouseWheel(true)
    log:SetScript("OnMouseWheel", function(self, delta)
        if delta > 0 then self:ScrollUp() else self:ScrollDown() end
    end)
    frame.log = log

    applySkin(frame)
    -- Keep the General page's session "Debug console" checkbox in sync with the window's actual
    -- visibility, however it changes — this checkbox, the /at debug bare toggle, the header Close
    -- button, or Esc (UISpecialFrames hides the frame directly). Guarded NS-bus call: the settings
    -- layer may not be loaded. AceGUI SetValue doesn't fire OnValueChanged, so no recursion.
    local function syncPanels()
        if NS.Helpers and NS.Helpers.RefreshAllPanels then NS.Helpers.RefreshAllPanels() end
    end
    frame:HookScript("OnShow", function() D:RefreshHeader(); syncPanels() end)
    frame:HookScript("OnHide", syncPanels)
    D:RefreshHeader()

    frame:Hide()
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "AbsorbTrackerDebugWindow")
    end
    return frame
end

-- Pure plain-text line formatter (no frames, no colour codes): "<ts> | [<tag>] <msg>". This is
-- what the Copy buffer mirrors — clean text with the tag rendered verbatim (§12.3).
function D.FormatPlain(ts, tag, msg)
    return ("%s | [%s] %s"):format(tostring(ts), tostring(tag or ""), tostring(msg))
end

-- Pure colour-coded line formatter for the console view: timestamp muted steel-blue (6f8faf),
-- [tag] muted tan/gold (c9a66b); the "|" separator and message stay default white. "||" renders
-- one literal pipe inside the colour-coded string (§12.3).
function D.FormatColored(ts, tag, msg)
    return ("|cff6f8faf%s|r || |cffc9a66b[%s]|r %s"):format(
        tostring(ts), tostring(tag or ""), tostring(msg))
end

function D:Add(tag, msg)
    local f = EnsureFrame()
    local ts = date("%H:%M:%S")
    f.log:AddMessage(D.FormatColored(ts, tag, msg))
    D.buffer[#D.buffer + 1] = D.FormatPlain(ts, tag, msg)
    if #D.buffer > MAX_BUFFER then table.remove(D.buffer, 1) end
end

function D:Clear()
    if frame and frame.log then frame.log:Clear() end
    wipe(D.buffer)
end

-- ── Copy window: read-through EditBox holding the whole log as plain text (§12.6) ──────────
local copyFrame
local function EnsureCopyFrame()
    if copyFrame then return copyFrame end

    copyFrame = CreateFrame("Frame", "AbsorbTrackerDebugCopyWindow", UIParent, "BackdropTemplate")
    copyFrame:SetSize(560, 360)
    copyFrame:SetPoint("CENTER")
    copyFrame:SetFrameStrata("FULLSCREEN")
    copyFrame:EnableMouse(true)
    copyFrame:SetMovable(true)
    copyFrame:SetClampedToScreen(true)

    local tbar = CreateFrame("Frame", nil, copyFrame)
    tbar:SetPoint("TOPLEFT", 1, -1)
    tbar:SetPoint("TOPRIGHT", -1, -1)
    tbar:SetHeight(26)
    tbar:EnableMouse(true)
    tbar:RegisterForDrag("LeftButton")
    tbar:SetScript("OnDragStart", function() copyFrame:StartMoving() end)
    tbar:SetScript("OnDragStop", function() copyFrame:StopMovingOrSizing() end)
    local t = tbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("CENTER")
    t:SetText("Copy log \226\128\148 Ctrl+C, then Esc")
    copyFrame.title = t

    local cclose = makeCloseButton(tbar, function() copyFrame:Hide() end)
    cclose:SetPoint("RIGHT", tbar, "RIGHT", -6, 0)

    local scroll = CreateFrame("ScrollFrame", "AbsorbTrackerDebugCopyScroll", copyFrame,
        "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 8, -30)
    scroll:SetPoint("BOTTOMRIGHT", -28, 10)
    copyFrame.scroll = scroll

    local edit = CreateFrame("EditBox", nil, scroll)
    edit:SetMultiLine(true)
    edit:SetFont(NS.Constants.FONT_MONO, 10, "")
    edit:SetAutoFocus(false)
    edit:SetWidth(510)
    edit:SetScript("OnEscapePressed", function(self) self:ClearFocus(); copyFrame:Hide() end)
    scroll:SetScrollChild(edit)
    copyFrame.edit = edit

    applySkin(copyFrame)
    copyFrame:Hide()
    if type(UISpecialFrames) == "table" then
        table.insert(UISpecialFrames, "AbsorbTrackerDebugCopyWindow")
    end
    return copyFrame
end

function D:ShowCopy()
    local f = EnsureCopyFrame()
    f.edit:SetWidth(f.scroll:GetWidth() > 0 and f.scroll:GetWidth() or 510)
    f.edit:SetText(table.concat(D.buffer, "\n"))
    f.edit:SetCursorPosition(0)
    f:Show()
    f.edit:SetFocus()
    f.edit:HighlightText()
end

function D:Show() EnsureFrame():Show() end
function D:Hide() if frame then frame:Hide() end end
function D:Toggle()
    local f = EnsureFrame()
    if f:IsShown() then f:Hide() else f:Show() end
end

-- Is the console window currently visible? Read-only, and never builds the frame — a nil frame
-- (never opened this session) reads as hidden. Backs the General page's Debug console checkbox.
function D:IsShown() return (frame and frame:IsShown()) and true or false end

-- Single seam for changing debug state. The slash command and the header toggle both call this
-- so the chat ack and the header label stay consistent. Session-only (§12.5).
function D:SetEnabled(on)
    on = not not on
    NS.State.debug = on
    D:RefreshHeader()
    -- Colour-coded chat ack (debug-logging §5): the state word is ON green (40ff40) / OFF red
    -- (ff4040), mirroring the title-bar toggle so the flag reads identically in chat and on the
    -- console header. Routes through the shared NS.PREFIX printer (never a raw print/tag).
    NS.Print("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))
    -- Bracket every session with a console line at both ends. Write through D:Add rather than
    -- NS.Debug so the "logging disabled" line still lands after NS.State.debug has flipped off
    -- (NS.Debug is gated on the flag, D:Add is not).
    D:Add("Debug", on and "logging enabled" or "logging disabled")
    -- On enable, follow the bracket with a one-line [Init] session summary (debug-logging §5;
    -- this also satisfies the §8 lifecycle boot-summary). Emitted HERE, not at login: the flag is
    -- session-only and off at login, so a load-time summary would always be gated off and never
    -- render — SetEnabled is the only point where it is both current and visible. Raw D:Add (not
    -- the gated sink); values are plain but routed through NS.SafeToString to honour secret-safety.
    if on then
        local schemaVer = NS.db and NS.db.global and NS.db.global.schemaVersion
        local profile = NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()
        D:Add("Init", ("%s v%s, schema v%s, profile '%s'"):format(
            NS.SafeToString(NS.name), NS.SafeToString(NS.version),
            NS.SafeToString(schemaVer or "?"), NS.SafeToString(profile or "?")))
    end
end

function D:RefreshHeader()
    if not (frame and frame.debugToggle) then return end
    local on = NS.State and NS.State.debug
    frame.debugToggle:SetText(on and "Debug: ON" or "Debug: OFF")
    if on then frame.debugToggle:SetTextColor(0.30, 0.85, 0.30)
    else frame.debugToggle:SetTextColor(0.90, 0.30, 0.30) end
end

-- "Debug console" checkbox spec for the General settings page. Toggles only the *visibility* of
-- the console window (same as the bare /at debug) — it deliberately does NOT touch the debug
-- logging flag (NS.State.debug), which stays on /at debug on|off and the window's own header
-- toggle. `get` reads live window visibility; `set` shows/hides the window. Window visibility is
-- transient UI state, never persisted (not a schema row). Consumed by Helpers.SessionCheckbox in
-- settings/General.lua; also the headless test seam for the wiring.
function D:ConsoleCheckbox()
    return {
        label   = "Debug console",
        tooltip = "Show or hide the on-screen debug console window. Same as /at debug. "
            .. "Whether logging is on is separate \226\128\148 use /at debug on|off "
            .. "or the window's own toggle.",
        get = function() return D:IsShown() end,
        set = function(v)
            if v then D:Show() else D:Hide() end
        end,
    }
end

-- Global debug sink (Ka0s debug-logging §4). Zero-alloc when off. Every vararg passes through
-- NS.SafeToString so a combat "secret" (absorb total) logs as <secret> instead of raising in
-- string.format — so call sites use %s for every placeholder.
function NS.Debug(tag, fmt, ...)
    if not (NS.State and NS.State.debug) then return end
    local n = select("#", ...)
    local msg = fmt
    if n > 0 then
        local parts = {}
        for i = 1, n do parts[i] = NS.SafeToString((select(i, ...))) end
        msg = fmt:format(unpack(parts))
    end
    D:Add(tag, msg)
end
