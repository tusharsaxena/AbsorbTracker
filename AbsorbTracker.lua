-- AbsorbTracker: Shows total absorb on your character
local AddonName, AddonTable = ...

-- Cache frequently used functions
local floor, max, min = math.floor, math.max, math.min
local format = format
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitHealthMax = UnitHealthMax

-- Default settings
local defaults = {
    barTexture = "Blizzard Raid Bar",
    border = "Blizzard Tooltip",
    borderSize = 12,
    font = "Friz Quadrata TT",
    fontSize = 12,
    barWidth = 200,
    barHeight = 20,
    barColor = { r = 0.4, g = 0.7, b = 1.0, a = 0.8 },
    bgColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
    locked = false,
    hidden = false,
    updateInterval = 1.0,
}

-- Saved variables (loaded on PLAYER_LOGIN)
AbsorbTrackerDB = AbsorbTrackerDB or {}

-- Cached LibSharedMedia reference
local LSM

-- LibSharedMedia support (fetched once, then cached)
local function GetLSM()
    if LSM then return LSM end
    if LibStub then
        LSM = LibStub("LibSharedMedia-3.0", true)
    end
    return LSM
end

-- Generic setting getter with fallback
local function GetSetting(key)
    local val = AbsorbTrackerDB[key]
    if val == nil then
        return defaults[key]
    end
    return val
end

-- Fallback paths
local FALLBACK_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
local FALLBACK_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
local FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

local function GetBarTexture()
    local lsm = GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", GetSetting("barTexture"))
        if texture then return texture end
    end
    return FALLBACK_TEXTURE
end

local function GetBorder()
    local lsm = GetLSM()
    if lsm then
        local border = lsm:Fetch("border", GetSetting("border"))
        if border then return border end
    end
    return FALLBACK_BORDER
end

local function GetFont()
    local lsm = GetLSM()
    if lsm then
        local font = lsm:Fetch("font", GetSetting("font"))
        if font then return font end
    end
    return FALLBACK_FONT
end

local function GetBarColor()
    local c = GetSetting("barColor")
    return c.r, c.g, c.b, c.a
end

local function GetBgColor()
    local c = GetSetting("bgColor")
    return c.r, c.g, c.b, c.a
end

-- Reusable backdrop table to avoid garbage
local backdropInfo = {
    bgFile = FALLBACK_TEXTURE,
    edgeFile = nil,
    tile = false,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}

-- Create the absorb bar directly (no container frame)
local bar = CreateFrame("Frame", "AbsorbTrackerFrame", UIParent, "BackdropTemplate")
bar:SetSize(defaults.barWidth, defaults.barHeight)
bar:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
backdropInfo.edgeFile = GetBorder()
bar:SetBackdrop(backdropInfo)
bar:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
bar:SetMovable(true)
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", bar.StartMoving)
bar:SetScript("OnDragStop", bar.StopMovingOrSizing)
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
valueText:SetFont(GetFont(), GetSetting("fontSize"), "OUTLINE")
valueText:SetPoint("CENTER", bar, "CENTER", 0, 0)
bar.valueText = valueText

-- Function to update appearance (texture, border, font, size, colors, lock)
local function UpdateBarAppearance()
    -- Update size
    bar:SetSize(GetSetting("barWidth"), GetSetting("barHeight"))

    -- Update texture
    statusBar:SetStatusBarTexture(GetBarTexture())

    -- Update bar color
    statusBar:SetStatusBarColor(GetBarColor())

    -- Update border (reuse backdrop table)
    local borderSize = GetSetting("borderSize")
    local inset = max(1, floor(borderSize / 4))
    backdropInfo.edgeFile = GetBorder()
    backdropInfo.edgeSize = borderSize
    backdropInfo.insets.left = inset
    backdropInfo.insets.right = inset
    backdropInfo.insets.top = inset
    backdropInfo.insets.bottom = inset
    bar:SetBackdrop(backdropInfo)
    bar:SetBackdropColor(GetBgColor())
    bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- Update font
    valueText:SetFont(GetFont(), GetSetting("fontSize"), "OUTLINE")

    -- Update lock state
    local locked = GetSetting("locked")
    bar:SetMovable(not locked)
    bar:EnableMouse(not locked)

    -- Update visibility
    if GetSetting("hidden") then
        bar:Hide()
    else
        bar:Show()
    end
end

-- Debug flag
local DEBUG = false

local function DebugPrint(...)
    if DEBUG then
        print("|cFF00FF00[AbsorbTracker]|r", ...)
    end
end

-- Track last absorb value to avoid redundant updates
local lastAbsorb = -1  -- Start at -1 to force first update

-- Function to update the absorb bar
local function UpdateAbsorbBar()
    -- Skip if hidden
    if GetSetting("hidden") then return end

    local totalAbsorb = UnitGetTotalAbsorbs("player") or 0
    local maxHealth = UnitHealthMax("player") or 1

    DebugPrint("Raw absorb:", AbbreviateNumbers(totalAbsorb), "MaxHP:", AbbreviateNumbers(maxHealth))

    -- Always keep bar visible
    bar:SetAlpha(1)

    -- Use raw secret value directly in UI functions for bar display
    statusBar:SetMinMaxValues(0, maxHealth)
    statusBar:SetValue(totalAbsorb)

    -- Use Blizzard's AbbreviateNumbers for text display
    local displayText = AbbreviateNumbers(totalAbsorb)
    valueText:SetText(displayText)

    DebugPrint("Display text:", displayText)
end

-- Forward declarations
local CreateOptionsPanel
local OpenOptionsPanel
local RestartUpdateTicker

-- Update on a timer as backup
local updateTicker

RestartUpdateTicker = function()
    if updateTicker then
        updateTicker:Cancel()
    end
    updateTicker = C_Timer.NewTicker(GetSetting("updateInterval"), UpdateAbsorbBar)
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        -- Initialize saved variables
        AbsorbTrackerDB = AbsorbTrackerDB or {}
        -- Clear LSM cache in case it loaded after initial fetch
        LSM = nil
        GetLSM()
        UpdateBarAppearance()
        UpdateAbsorbBar()
        RestartUpdateTicker()
        CreateOptionsPanel()
    elseif event == "PLAYER_ENTERING_WORLD" then
        lastAbsorb = -1  -- Reset cache on zone change to force update
        UpdateAbsorbBar()
    elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" and unit == "player" then
        UpdateAbsorbBar()
    end
end)

-- Helper function to print LSM list
local function PrintLSMList(mediaType, dbKey)
    local lsm = GetLSM()
    if not lsm then
        print("AbsorbTracker: LibSharedMedia not found. Install LibSharedMedia-3.0 to use custom " .. mediaType .. ".")
        return false
    end
    print("AbsorbTracker: Available " .. mediaType .. "s:")
    local list = lsm:List(mediaType)
    local current = GetSetting(dbKey)
    for _, name in ipairs(list) do
        local marker = current == name and " (current)" or ""
        print("  " .. name .. marker)
    end
    return true
end

-- Helper to parse color from string (handles 0-255 or 0-1 formats)
local function ParseColor(arg)
    local r, g, b, a = arg:match("^(%d+%.?%d*)%s+(%d+%.?%d*)%s+(%d+%.?%d*)%s*(%d*%.?%d*)$")
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not (r and g and b) then return nil end
    a = tonumber(a) or 0.8
    -- Convert from 0-255 to 0-1 if values are > 1
    if r > 1 or g > 1 or b > 1 then
        r, g, b = r / 255, g / 255, b / 255
    end
    if a > 1 then a = a / 255 end
    return { r = r, g = g, b = b, a = a }
end

-- Slash commands
SLASH_ABSORBTRACKER1 = "/absorbtracker"
SLASH_ABSORBTRACKER2 = "/at"
SlashCmdList["ABSORBTRACKER"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()

    if cmd == "debug" then
        DEBUG = not DEBUG
        print("AbsorbTracker: Debug mode", DEBUG and "ENABLED" or "DISABLED")

    elseif cmd == "update" then
        print("AbsorbTracker: Forcing update...")
        lastAbsorb = -1  -- Reset cache to force update
        UpdateAbsorbBar()

    elseif cmd == "test" then
        -- Test display with fake values
        local testVal = tonumber(arg) or 50000
        print("AbsorbTracker: Testing display with value:", AbbreviateNumbers(testVal))
        valueText:SetText(AbbreviateNumbers(testVal))
        statusBar:SetMinMaxValues(0, 100000)
        statusBar:SetValue(testVal)
        print("AbsorbTracker: Text set to:", valueText:GetText())
        print("AbsorbTracker: Bar value:", AbbreviateNumbers(statusBar:GetValue()), "min/max:", statusBar:GetMinMaxValues())

    elseif cmd == "texture" then
        if arg and arg ~= "" then
            AbsorbTrackerDB.barTexture = arg
            UpdateBarAppearance()
            print("AbsorbTracker: Texture set to '" .. arg .. "'")
        else
            if PrintLSMList("statusbar", "barTexture") then
                print("Usage: /at texture <name>")
            end
        end

    elseif cmd == "border" then
        if arg and arg ~= "" then
            AbsorbTrackerDB.border = arg
            UpdateBarAppearance()
            print("AbsorbTracker: Border set to '" .. arg .. "'")
        else
            if PrintLSMList("border", "border") then
                print("Usage: /at border <name>")
            end
        end

    elseif cmd == "font" then
        if arg and arg ~= "" then
            AbsorbTrackerDB.font = arg
            UpdateBarAppearance()
            print("AbsorbTracker: Font set to '" .. arg .. "'")
        else
            if PrintLSMList("font", "font") then
                print("Usage: /at font <name>")
            end
        end

    elseif cmd == "fontsize" then
        if arg and arg ~= "" then
            local size = tonumber(arg)
            if size and size >= 6 and size <= 32 then
                AbsorbTrackerDB.fontSize = size
                UpdateBarAppearance()
                print("AbsorbTracker: Font size set to " .. size)
            else
                print("AbsorbTracker: Invalid font size. Use a number between 6 and 32.")
            end
        else
            print("AbsorbTracker: Current font size: " .. GetSetting("fontSize"))
            print("Usage: /at fontsize <size>  (6-32)")
        end

    elseif cmd == "width" then
        if arg and arg ~= "" then
            local width = tonumber(arg)
            if width and width >= 50 and width <= 500 then
                AbsorbTrackerDB.barWidth = width
                UpdateBarAppearance()
                print("AbsorbTracker: Bar width set to " .. width)
            else
                print("AbsorbTracker: Invalid width. Use a number between 50 and 500.")
            end
        else
            print("AbsorbTracker: Current bar width: " .. GetSetting("barWidth"))
            print("Usage: /at width <pixels>  (50-500)")
        end

    elseif cmd == "height" then
        if arg and arg ~= "" then
            local height = tonumber(arg)
            if height and height >= 10 and height <= 100 then
                AbsorbTrackerDB.barHeight = height
                UpdateBarAppearance()
                print("AbsorbTracker: Bar height set to " .. height)
            else
                print("AbsorbTracker: Invalid height. Use a number between 10 and 100.")
            end
        else
            print("AbsorbTracker: Current bar height: " .. GetSetting("barHeight"))
            print("Usage: /at height <pixels>  (10-100)")
        end

    elseif cmd == "bordersize" then
        if arg and arg ~= "" then
            local size = tonumber(arg)
            if size and size >= 1 and size <= 32 then
                AbsorbTrackerDB.borderSize = size
                UpdateBarAppearance()
                print("AbsorbTracker: Border size set to " .. size)
            else
                print("AbsorbTracker: Invalid border size. Use a number between 1 and 32.")
            end
        else
            print("AbsorbTracker: Current border size: " .. GetSetting("borderSize"))
            print("Usage: /at bordersize <size>  (1-32)")
        end

    elseif cmd == "color" then
        if arg and arg ~= "" then
            local color = ParseColor(arg)
            if color then
                AbsorbTrackerDB.barColor = color
                UpdateBarAppearance()
                print(format("AbsorbTracker: Bar color set to %.2f %.2f %.2f %.2f", color.r, color.g, color.b, color.a))
            else
                print("AbsorbTracker: Invalid color format.")
                print("Usage: /at color <r> <g> <b> [a]  (0-255 or 0-1)")
            end
        else
            local r, g, b, a = GetBarColor()
            print(format("AbsorbTracker: Current bar color: %.2f %.2f %.2f %.2f", r, g, b, a))
            print("Usage: /at color <r> <g> <b> [a]  (0-255 or 0-1)")
        end

    elseif cmd == "bgcolor" then
        if arg and arg ~= "" then
            local color = ParseColor(arg)
            if color then
                AbsorbTrackerDB.bgColor = color
                UpdateBarAppearance()
                print(format("AbsorbTracker: Background color set to %.2f %.2f %.2f %.2f", color.r, color.g, color.b, color.a))
            else
                print("AbsorbTracker: Invalid color format.")
                print("Usage: /at bgcolor <r> <g> <b> [a]  (0-255 or 0-1)")
            end
        else
            local r, g, b, a = GetBgColor()
            print(format("AbsorbTracker: Current background color: %.2f %.2f %.2f %.2f", r, g, b, a))
            print("Usage: /at bgcolor <r> <g> <b> [a]  (0-255 or 0-1)")
        end

    elseif cmd == "lock" then
        AbsorbTrackerDB.locked = true
        UpdateBarAppearance()
        print("AbsorbTracker: Bar locked")

    elseif cmd == "unlock" then
        AbsorbTrackerDB.locked = false
        UpdateBarAppearance()
        print("AbsorbTracker: Bar unlocked")

    elseif cmd == "interval" then
        if arg and arg ~= "" then
            local interval = tonumber(arg)
            if interval and interval >= 0.1 and interval <= 10 then
                AbsorbTrackerDB.updateInterval = interval
                RestartUpdateTicker()
                print(format("AbsorbTracker: Update interval set to %.1f seconds", interval))
            else
                print("AbsorbTracker: Invalid interval. Use a number between 0.1 and 10.")
            end
        else
            print(format("AbsorbTracker: Current update interval: %.1f seconds", GetSetting("updateInterval")))
            print("Usage: /at interval <seconds>  (0.1-10)")
        end

    elseif cmd == "toggle" then
        AbsorbTrackerDB.hidden = not GetSetting("hidden")
        UpdateBarAppearance()
        if GetSetting("hidden") then
            print("AbsorbTracker: Hidden")
        else
            lastAbsorb = -1  -- Reset cache to force update
            UpdateAbsorbBar()
            print("AbsorbTracker: Shown")
        end

    elseif cmd == "" then
        OpenOptionsPanel()

    else
        print("AbsorbTracker commands:")
        print("  /at - Open settings panel")
        print("  /at toggle - Toggle visibility")
        print("  /at debug - Toggle debug mode")
        print("  /at test [value] - Test display with fake value")
        print("  /at lock - Lock bar position")
        print("  /at unlock - Unlock bar position")
        print("  /at texture [name] - List or set bar texture")
        print("  /at border [name] - List or set border")
        print("  /at bordersize <size> - Set border size (1-32)")
        print("  /at font [name] - List or set font")
        print("  /at fontsize <size> - Set font size (6-32)")
        print("  /at width <pixels> - Set bar width (50-500)")
        print("  /at height <pixels> - Set bar height (10-100)")
        print("  /at color <r> <g> <b> [a] - Set bar color")
        print("  /at bgcolor <r> <g> <b> [a] - Set background color")
        print("  /at interval <seconds> - Set update interval (0.1-10)")
    end
end

-- Options Panel (Settings API for WoW 10.0+)
CreateOptionsPanel = function()
    local panel = CreateFrame("Frame")
    panel.name = "AbsorbTracker"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("AbsorbTracker Settings")

    local yOffset = -50
    local leftColumn = 20
    local rightColumn = 280

    -- Helper: Create a checkbox
    local function CreateCheckbox(parent, x, y, label, dbKey, defaultVal)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        cb.Text:SetText(label)
        cb:SetChecked(AbsorbTrackerDB[dbKey] ~= nil and AbsorbTrackerDB[dbKey] or defaultVal)
        cb:SetScript("OnClick", function(self)
            AbsorbTrackerDB[dbKey] = self:GetChecked()
            UpdateBarAppearance()
        end)
        return cb, y - 30
    end

    -- Helper: Create a slider with input box
    local function CreateSlider(parent, x, y, label, dbKey, defaultVal, minVal, maxVal, step, decimals, onChangeCallback)
        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", x, y)
        container:SetSize(220, 50)

        local sliderLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        sliderLabel:SetPoint("TOPLEFT", 0, 0)
        sliderLabel:SetText(label)

        local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 0, -20)
        slider:SetWidth(155)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step or 1)
        slider:SetObeyStepOnDrag(true)
        slider.Low:SetText(minVal)
        slider.High:SetText(maxVal)
        slider.Text:SetText("")

        decimals = decimals or 0
        local formatStr = "%." .. decimals .. "f"

        -- Input box for manual entry
        local editBox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
        editBox:SetPoint("LEFT", slider, "RIGHT", 15, 0)
        editBox:SetSize(45, 20)
        editBox:SetAutoFocus(false)

        local initialized = false

        local function ApplyValue(value, skipCallback)
            if decimals == 0 then
                value = floor(value + 0.5)
            else
                local mult = 10 ^ decimals
                value = floor(value * mult + 0.5) / mult
            end
            value = max(minVal, min(maxVal, value))
            AbsorbTrackerDB[dbKey] = value
            if not skipCallback then
                if onChangeCallback then
                    onChangeCallback(value)
                else
                    UpdateBarAppearance()
                end
            end
            return value
        end

        slider:SetScript("OnValueChanged", function(self, value)
            if not initialized then return end
            value = ApplyValue(value)
            editBox:SetText(format(formatStr, value))
        end)

        editBox:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if value then
                value = ApplyValue(value)
                slider:SetValue(value)
                self:SetText(format(formatStr, value))
            else
                self:SetText(format(formatStr, AbsorbTrackerDB[dbKey] or defaultVal))
            end
            self:ClearFocus()
        end)

        editBox:SetScript("OnEscapePressed", function(self)
            self:SetText(format(formatStr, AbsorbTrackerDB[dbKey] or defaultVal))
            self:ClearFocus()
        end)

        -- Refresh editBox text when it becomes visible (with slight delay for frame initialization)
        editBox:SetScript("OnShow", function(self)
            C_Timer.After(0.01, function()
                local currentValue = AbsorbTrackerDB[dbKey] or defaultVal
                editBox:SetText(format(formatStr, currentValue))
            end)
        end)

        -- Initialize slider value and editBox text after scripts are set
        local currentValue = AbsorbTrackerDB[dbKey] or defaultVal
        slider:SetValue(currentValue)
        editBox:SetText(format(formatStr, currentValue))
        initialized = true

        return container, y - 55
    end

    -- Helper: Create a color picker button
    local function CreateColorButton(parent, x, y, label, dbKey, defaultColor)
        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", x, y)
        container:SetSize(220, 30)

        local colorLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        colorLabel:SetPoint("LEFT", 0, 0)
        colorLabel:SetText(label)

        local colorBtn = CreateFrame("Button", nil, container)
        colorBtn:SetPoint("LEFT", colorLabel, "RIGHT", 10, 0)
        colorBtn:SetSize(24, 24)

        local colorTex = colorBtn:CreateTexture(nil, "BACKGROUND")
        colorTex:SetAllPoints()
        local c = AbsorbTrackerDB[dbKey] or defaultColor
        colorTex:SetColorTexture(c.r, c.g, c.b, c.a or 1)

        colorBtn:SetScript("OnClick", function()
            local currentColor = AbsorbTrackerDB[dbKey] or defaultColor
            local info = {
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    AbsorbTrackerDB[dbKey] = { r = r, g = g, b = b, a = a }
                    colorTex:SetColorTexture(r, g, b, a)
                    UpdateBarAppearance()
                end,
                opacityFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    AbsorbTrackerDB[dbKey] = { r = r, g = g, b = b, a = a }
                    colorTex:SetColorTexture(r, g, b, a)
                    UpdateBarAppearance()
                end,
                cancelFunc = function(prev)
                    AbsorbTrackerDB[dbKey] = { r = prev.r, g = prev.g, b = prev.b, a = prev.a }
                    colorTex:SetColorTexture(prev.r, prev.g, prev.b, prev.a)
                    UpdateBarAppearance()
                end,
                hasOpacity = true,
                opacity = currentColor.a or 0.8,
                r = currentColor.r,
                g = currentColor.g,
                b = currentColor.b,
                previousValues = { r = currentColor.r, g = currentColor.g, b = currentColor.b, a = currentColor.a or 0.8 },
            }
            ColorPickerFrame:SetupColorPickerAndShow(info)
        end)

        return container, y - 35
    end

    -- Helper: Create a dropdown for LSM media
    local function CreateMediaDropdown(parent, x, y, label, mediaType, dbKey, defaultVal)
        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", x, y)
        container:SetSize(220, 50)

        local dropLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        dropLabel:SetPoint("TOPLEFT", 0, 0)
        dropLabel:SetText(label)

        local dropdown = CreateFrame("Frame", nil, container, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", -16, -15)

        local function Initialize(self, level)
            local LSM = GetLSM()
            local list = LSM and LSM:List(mediaType) or {}
            local currentVal = AbsorbTrackerDB[dbKey] or defaultVal

            for _, name in ipairs(list) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.checked = (name == currentVal)
                info.func = function()
                    AbsorbTrackerDB[dbKey] = name
                    UIDropDownMenu_SetText(dropdown, name)
                    UpdateBarAppearance()
                end
                UIDropDownMenu_AddButton(info, level)
            end

            if #list == 0 then
                local info = UIDropDownMenu_CreateInfo()
                info.text = defaultVal
                info.checked = true
                info.disabled = true
                UIDropDownMenu_AddButton(info, level)
            end
        end

        UIDropDownMenu_SetWidth(dropdown, 160)
        UIDropDownMenu_SetText(dropdown, AbsorbTrackerDB[dbKey] or defaultVal)
        UIDropDownMenu_Initialize(dropdown, Initialize)

        return container, y - 55
    end

    -- Helper: Create a section header
    local function CreateSectionHeader(parent, x, y, text)
        local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        header:SetPoint("TOPLEFT", x, y)
        header:SetText(text)
        header:SetTextColor(1, 0.82, 0)

        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
        line:SetSize(230, 1)
        line:SetColorTexture(0.6, 0.6, 0.6, 0.8)

        return y - 25
    end

    -- Layout columns
    local col1 = 20
    local col2 = 280

    -- =====================
    -- LEFT COLUMN
    -- =====================
    local y1 = -50

    -- GENERAL SECTION
    y1 = CreateSectionHeader(panel, col1, y1, "General")

    -- Show Bar checkbox
    local showCb = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
    showCb:SetPoint("TOPLEFT", col1, y1)
    showCb.Text:SetText("Show Bar")
    showCb:SetChecked(not GetSetting("hidden"))
    showCb:SetScript("OnClick", function(self)
        AbsorbTrackerDB.hidden = not self:GetChecked()
        UpdateBarAppearance()
        if not GetSetting("hidden") then
            lastAbsorb = -1  -- Reset cache to force update
            UpdateAbsorbBar()
        end
    end)
    y1 = y1 - 30

    -- Lock Position checkbox
    local lockCb
    lockCb, y1 = CreateCheckbox(panel, col1, y1, "Lock Position", "locked", defaults.locked)

    y1 = y1 - 10

    -- BAR SIZE SECTION
    y1 = CreateSectionHeader(panel, col1, y1, "Bar Size")

    local widthSlider
    widthSlider, y1 = CreateSlider(panel, col1, y1, "Bar Width", "barWidth", defaults.barWidth, 50, 500, 1)

    local heightSlider
    heightSlider, y1 = CreateSlider(panel, col1, y1, "Bar Height", "barHeight", defaults.barHeight, 10, 100, 1)

    y1 = y1 - 10

    -- FONT SECTION (save y position for Border alignment)
    local fontYPos = y1
    y1 = CreateSectionHeader(panel, col1, y1, "Font")

    local fontDropdown
    fontDropdown, y1 = CreateMediaDropdown(panel, col1, y1, "Font Face", "font", "font", defaults.font)

    local fontSizeSlider
    fontSizeSlider, y1 = CreateSlider(panel, col1, y1, "Font Size", "fontSize", defaults.fontSize, 6, 32, 1)

    -- =====================
    -- RIGHT COLUMN
    -- =====================
    local y2 = -50

    -- PERFORMANCE SECTION
    y2 = CreateSectionHeader(panel, col2, y2, "Performance")

    local intervalSlider
    intervalSlider, y2 = CreateSlider(panel, col2, y2, "Update Interval (sec)", "updateInterval", defaults.updateInterval, 0.1, 10, 0.1, 1, RestartUpdateTicker)

    y2 = y2 - 10

    -- BAR COLOR SECTION
    y2 = CreateSectionHeader(panel, col2, y2, "Bar Color")

    local barColorBtn
    barColorBtn, y2 = CreateColorButton(panel, col2, y2, "Bar Color", "barColor", defaults.barColor)

    local bgColorBtn
    bgColorBtn, y2 = CreateColorButton(panel, col2, y2, "Background Color", "bgColor", defaults.bgColor)

    local textureDropdown
    textureDropdown, y2 = CreateMediaDropdown(panel, col2, y2, "Bar Texture", "statusbar", "barTexture", defaults.barTexture)

    -- BORDER SECTION (aligned with Font section)
    y2 = fontYPos
    y2 = CreateSectionHeader(panel, col2, y2, "Border")

    local borderDropdown
    borderDropdown, y2 = CreateMediaDropdown(panel, col2, y2, "Border Style", "border", "border", defaults.border)

    local borderSizeSlider
    borderSizeSlider, y2 = CreateSlider(panel, col2, y2, "Border Size", "borderSize", defaults.borderSize, 1, 32, 1)

    -- Register with Settings API (WoW 10.0+)
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
        AddonTable.settingsCategory = category
    else
        -- Fallback for older WoW versions
        InterfaceOptions_AddCategory(panel)
    end

    AddonTable.optionsPanel = panel
end

-- Helper function to open settings panel
OpenOptionsPanel = function()
    if Settings and Settings.OpenToCategory and AddonTable.settingsCategory then
        Settings.OpenToCategory(AddonTable.settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(AddonTable.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(AddonTable.optionsPanel)
    end
end

print("AbsorbTracker loaded. /at for commands")
