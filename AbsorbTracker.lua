-- AbsorbTracker: Shows total absorb on your character
local AddonName, AddonTable = ...

-- Cache frequently used functions
local floor, max, min = math.floor, math.max, math.min
local format = format
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local UnitHealthMax = UnitHealthMax

-- Default settings (AceDB format)
local defaults = {
    profile = {
        barTexture = "Blizzard Raid Bar",
        bgTexture = "Blizzard Raid Bar",
        border = "Blizzard Tooltip",
        borderSize = 12,
        font = "Friz Quadrata TT",
        fontSize = 12,
        fontFlags = "OUTLINE",
        barWidth = 200,
        barHeight = 20,
        barColor = { r = 0.4, g = 0.7, b = 1.0, a = 0.8 },
        bgColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
        locked = false,
        hidden = false,
        updateInterval = 1.0,
        position = nil,
    },
}

-- Database reference (set on PLAYER_LOGIN)
local db

-- Flat defaults for fallback when AceDB is not available
local flatDefaults = defaults.profile

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
    if db and db.profile then
        local val = db.profile[key]
        if val == nil then
            return flatDefaults[key]
        end
        return val
    end
    return flatDefaults[key]
end

-- Generic setting setter
local function SetSetting(key, value)
    if db and db.profile then
        db.profile[key] = value
    end
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

local function GetBgTexture()
    local lsm = GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", GetSetting("bgTexture"))
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
bar:SetSize(flatDefaults.barWidth, flatDefaults.barHeight)
bar:SetPoint("CENTER", UIParent, "CENTER", 0, -200)
backdropInfo.edgeFile = GetBorder()
bar:SetBackdrop(backdropInfo)
bar:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
bar:SetMovable(true)
bar:EnableMouse(true)
bar:RegisterForDrag("LeftButton")
bar:SetScript("OnDragStart", bar.StartMoving)
bar:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save position
    local point, _, relPoint, x, y = self:GetPoint()
    SetSetting("position", { point = point, relPoint = relPoint, x = x, y = y })
end)
bar:SetClampedToScreen(true)

-- Function to restore bar position from saved variables
local function RestoreBarPosition()
    local pos = GetSetting("position")
    if pos then
        bar:ClearAllPoints()
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    end
end

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
valueText:SetFont(GetFont(), GetSetting("fontSize"), GetSetting("fontFlags") or "")
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

    -- Update border and background texture (reuse backdrop table)
    local borderSize = GetSetting("borderSize")
    local inset = max(1, floor(borderSize / 4))
    backdropInfo.bgFile = GetBgTexture()
    backdropInfo.edgeFile = GetBorder()
    backdropInfo.edgeSize = borderSize
    backdropInfo.insets.left = inset
    backdropInfo.insets.right = inset
    backdropInfo.insets.top = inset
    backdropInfo.insets.bottom = inset
    bar:SetBackdrop(nil)  -- Clear first to force refresh
    bar:SetBackdrop(backdropInfo)
    bar:SetBackdropColor(GetBgColor())
    bar:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    -- Update font
    valueText:SetFont(GetFont(), GetSetting("fontSize"), GetSetting("fontFlags") or "")

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

    if UnitAffectingCombat("player") then
        DebugPrint("Raw absorb:", AbbreviateNumbers(totalAbsorb), "MaxHP:", AbbreviateNumbers(maxHealth))
    end

    -- Always keep bar visible
    bar:SetAlpha(1)

    -- Use raw secret value directly in UI functions for bar display
    statusBar:SetMinMaxValues(0, maxHealth)
    statusBar:SetValue(totalAbsorb)

    -- Use Blizzard's AbbreviateNumbers for text display
    local displayText = AbbreviateNumbers(totalAbsorb)
    valueText:SetText(displayText)
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

-- Profile change callback
local function OnProfileChanged()
    RestoreBarPosition()
    UpdateBarAppearance()
    lastAbsorb = -1
    UpdateAbsorbBar()
    RestartUpdateTicker()
end

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        -- Initialize AceDB if available
        if LibStub then
            local AceDB = LibStub("AceDB-3.0", true)
            if AceDB then
                db = AceDB:New("AbsorbTrackerDB", defaults, true)
                db.RegisterCallback(AddonTable, "OnProfileChanged", OnProfileChanged)
                db.RegisterCallback(AddonTable, "OnProfileCopied", OnProfileChanged)
                db.RegisterCallback(AddonTable, "OnProfileReset", OnProfileChanged)
                AddonTable.db = db
            end
        end
        -- Fallback if AceDB not available
        if not db then
            AbsorbTrackerDB = AbsorbTrackerDB or {}
            -- Create a minimal db-like structure for compatibility
            db = { profile = AbsorbTrackerDB }
            -- Migrate old flat settings to profile if needed
            for key, defaultVal in pairs(flatDefaults) do
                if db.profile[key] == nil then
                    db.profile[key] = defaultVal
                end
            end
        end
        -- Clear LSM cache in case it loaded after initial fetch
        LSM = nil
        GetLSM()
        RestoreBarPosition()
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
            SetSetting("barTexture", arg)
            UpdateBarAppearance()
            print("AbsorbTracker: Texture set to '" .. arg .. "'")
        else
            if PrintLSMList("statusbar", "barTexture") then
                print("Usage: /at texture <name>")
            end
        end

    elseif cmd == "bgtexture" then
        if arg and arg ~= "" then
            SetSetting("bgTexture", arg)
            UpdateBarAppearance()
            print("AbsorbTracker: Background texture set to '" .. arg .. "'")
        else
            if PrintLSMList("statusbar", "bgTexture") then
                print("Usage: /at bgtexture <name>")
            end
        end

    elseif cmd == "border" then
        if arg and arg ~= "" then
            SetSetting("border", arg)
            UpdateBarAppearance()
            print("AbsorbTracker: Border set to '" .. arg .. "'")
        else
            if PrintLSMList("border", "border") then
                print("Usage: /at border <name>")
            end
        end

    elseif cmd == "font" then
        if arg and arg ~= "" then
            SetSetting("font", arg)
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
                SetSetting("fontSize", size)
                UpdateBarAppearance()
                print("AbsorbTracker: Font size set to " .. size)
            else
                print("AbsorbTracker: Invalid font size. Use a number between 6 and 32.")
            end
        else
            print("AbsorbTracker: Current font size: " .. GetSetting("fontSize"))
            print("Usage: /at fontsize <size>  (6-32)")
        end

    elseif cmd == "fontflags" or cmd == "outline" then
        local validFlags = {
            ["none"] = "",
            ["outline"] = "OUTLINE",
            ["thickoutline"] = "THICKOUTLINE",
            ["monochrome"] = "MONOCHROME",
            ["monochrome, outline"] = "MONOCHROME, OUTLINE",
            ["monochrome, thickoutline"] = "MONOCHROME, THICKOUTLINE",
        }
        if arg and arg ~= "" then
            local lowerArg = arg:lower()
            if validFlags[lowerArg] ~= nil then
                SetSetting("fontFlags", validFlags[lowerArg])
                UpdateBarAppearance()
                local displayName = lowerArg == "none" and "None" or validFlags[lowerArg]
                print("AbsorbTracker: Font flags set to '" .. displayName .. "'")
            else
                print("AbsorbTracker: Invalid font flags.")
                print("Valid options: none, outline, thickoutline, monochrome, monochrome, outline, monochrome, thickoutline")
            end
        else
            local current = GetSetting("fontFlags")
            local displayCurrent = (current == "" or current == nil) and "None" or current
            print("AbsorbTracker: Current font flags: " .. displayCurrent)
            print("Usage: /at fontflags <option>")
            print("Options: none, outline, thickoutline, monochrome, monochrome, outline, monochrome, thickoutline")
        end

    elseif cmd == "width" then
        if arg and arg ~= "" then
            local width = tonumber(arg)
            if width and width >= 50 and width <= 500 then
                SetSetting("barWidth", width)
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
                SetSetting("barHeight", height)
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
                SetSetting("borderSize", size)
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
                SetSetting("barColor", color)
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
                SetSetting("bgColor", color)
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
        SetSetting("locked", true)
        UpdateBarAppearance()
        print("AbsorbTracker: Bar locked")

    elseif cmd == "unlock" then
        SetSetting("locked", false)
        UpdateBarAppearance()
        print("AbsorbTracker: Bar unlocked")

    elseif cmd == "interval" then
        if arg and arg ~= "" then
            local interval = tonumber(arg)
            if interval and interval >= 0.1 and interval <= 10 then
                SetSetting("updateInterval", interval)
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
        SetSetting("hidden", not GetSetting("hidden"))
        UpdateBarAppearance()
        if GetSetting("hidden") then
            print("AbsorbTracker: Hidden")
        else
            lastAbsorb = -1  -- Reset cache to force update
            UpdateAbsorbBar()
            print("AbsorbTracker: Shown")
        end

    elseif cmd == "profile" then
        -- Profile management commands
        if not db or not db.SetProfile then
            print("AbsorbTracker: Profile system requires AceDB-3.0. Install Ace3 to use profiles.")
            return
        end

        local subcmd, subarg = arg:match("^(%S*)%s*(.*)$")
        subcmd = (subcmd or ""):lower()

        if subcmd == "list" then
            print("AbsorbTracker: Available profiles:")
            local current = db:GetCurrentProfile()
            for _, name in ipairs(db:GetProfiles()) do
                local marker = (name == current) and " (current)" or ""
                print("  " .. name .. marker)
            end
        elseif subcmd == "use" or subcmd == "set" then
            if subarg and subarg ~= "" then
                db:SetProfile(subarg)
                print("AbsorbTracker: Switched to profile '" .. subarg .. "'")
            else
                print("Usage: /at profile use <name>")
            end
        elseif subcmd == "new" or subcmd == "create" then
            if subarg and subarg ~= "" then
                db:SetProfile(subarg)
                db:ResetProfile()
                print("AbsorbTracker: Created and switched to new profile '" .. subarg .. "'")
            else
                print("Usage: /at profile new <name>")
            end
        elseif subcmd == "copy" then
            if subarg and subarg ~= "" then
                db:CopyProfile(subarg)
                print("AbsorbTracker: Copied settings from profile '" .. subarg .. "'")
            else
                print("Usage: /at profile copy <name>")
                print("Copies settings from another profile to the current one.")
            end
        elseif subcmd == "delete" or subcmd == "remove" then
            if subarg and subarg ~= "" then
                local current = db:GetCurrentProfile()
                if subarg == current then
                    print("AbsorbTracker: Cannot delete the current profile.")
                else
                    db:DeleteProfile(subarg, true)
                    print("AbsorbTracker: Deleted profile '" .. subarg .. "'")
                end
            else
                print("Usage: /at profile delete <name>")
            end
        elseif subcmd == "reset" then
            db:ResetProfile()
            print("AbsorbTracker: Profile reset to defaults")
        elseif subcmd == "current" then
            print("AbsorbTracker: Current profile: " .. db:GetCurrentProfile())
        else
            print("AbsorbTracker profile commands:")
            print("  /at profile list - List all profiles")
            print("  /at profile current - Show current profile name")
            print("  /at profile use <name> - Switch to profile")
            print("  /at profile new <name> - Create new profile with defaults")
            print("  /at profile copy <name> - Copy settings from another profile")
            print("  /at profile delete <name> - Delete a profile")
            print("  /at profile reset - Reset current profile to defaults")
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
        print("  /at bgtexture [name] - List or set background texture")
        print("  /at border [name] - List or set border")
        print("  /at bordersize <size> - Set border size (1-32)")
        print("  /at font [name] - List or set font")
        print("  /at fontsize <size> - Set font size (6-32)")
        print("  /at fontflags <option> - Set font outline (none, outline, thickoutline, etc.)")
        print("  /at width <pixels> - Set bar width (50-500)")
        print("  /at height <pixels> - Set bar height (10-100)")
        print("  /at color <r> <g> <b> [a] - Set bar color")
        print("  /at bgcolor <r> <g> <b> [a] - Set background color")
        print("  /at interval <seconds> - Set update interval (0.1-10)")
        print("  /at profile - Profile management commands")
    end
end

-- Options Panel (Settings API for WoW 10.0+)
CreateOptionsPanel = function()
    local panel = CreateFrame("Frame")
    panel.name = "AbsorbTracker"

    -- Table to store refresh functions for sliders
    local sliderRefreshFuncs = {}

    -- Title stays on the main panel (outside scroll area)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("AbsorbTracker Settings")

    -- Create scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 0, -40)
    scrollFrame:SetPoint("BOTTOMRIGHT", -26, 4)

    -- Create content frame (scroll child)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(540, 800)  -- Width and estimated height for content
    scrollFrame:SetScrollChild(content)

    local yOffset = -10
    local leftColumn = 20
    local rightColumn = 280

    -- Helper: Create a checkbox
    local function CreateCheckbox(parent, x, y, label, dbKey, defaultVal)
        local cb = CreateFrame("CheckButton", nil, parent, "InterfaceOptionsCheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x, y)
        cb.Text:SetText(label)
        cb:SetChecked(GetSetting(dbKey) or defaultVal)
        cb:SetScript("OnClick", function(self)
            SetSetting(dbKey, self:GetChecked())
            UpdateBarAppearance()
        end)
        return cb, y - 30
    end

    -- Helper: Create a slider with input box
    local function CreateSlider(parent, x, y, label, dbKey, defaultVal, minVal, maxVal, step, decimals, onChangeCallback)
        DebugPrint("CreateSlider called for:", dbKey, "defaultVal:", defaultVal)

        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", x, y)
        container:SetSize(220, 50)

        local sliderLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        sliderLabel:SetPoint("TOPLEFT", 0, 0)
        sliderLabel:SetText(label)

        local slider = CreateFrame("Slider", nil, container, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 0, -20)
        slider:SetWidth(170)
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
        editBox:SetFontObject(GameFontHighlightSmall)
        editBox:SetJustifyH("CENTER")

        DebugPrint("EditBox created for:", dbKey, "FontObject:", editBox:GetFontObject() and editBox:GetFontObject():GetName() or "nil")

        local initialized = false

        local function ApplyValue(value, skipCallback)
            if decimals == 0 then
                value = floor(value + 0.5)
            else
                local mult = 10 ^ decimals
                value = floor(value * mult + 0.5) / mult
            end
            value = max(minVal, min(maxVal, value))
            SetSetting(dbKey, value)
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
            DebugPrint("OnValueChanged for:", dbKey, "value:", value, "initialized:", initialized)
            if not initialized then return end
            value = ApplyValue(value)
            editBox:SetText(format(formatStr, value))
            editBox:SetCursorPosition(0)  -- Force visual update
            DebugPrint("OnValueChanged SetText:", format(formatStr, value), "GetText after:", editBox:GetText())
        end)

        editBox:SetScript("OnEnterPressed", function(self)
            local value = tonumber(self:GetText())
            if value then
                value = ApplyValue(value)
                slider:SetValue(value)
                self:SetText(format(formatStr, value))
            else
                self:SetText(format(formatStr, GetSetting(dbKey) or defaultVal))
            end
            self:ClearFocus()
        end)

        editBox:SetScript("OnEscapePressed", function(self)
            self:SetText(format(formatStr, GetSetting(dbKey) or defaultVal))
            self:ClearFocus()
        end)

        -- Register refresh function for panel OnShow
        local function refreshEditBox()
            local currentValue = GetSetting(dbKey) or defaultVal
            DebugPrint("refreshEditBox for:", dbKey, "currentValue:", currentValue, "formatStr:", formatStr)
            slider:SetValue(currentValue)
            editBox:SetText(format(formatStr, currentValue))
            editBox:SetCursorPosition(0)  -- Force visual update
            DebugPrint("refreshEditBox SetText:", format(formatStr, currentValue), "GetText after:", editBox:GetText())
        end
        table.insert(sliderRefreshFuncs, refreshEditBox)

        -- Initialize slider value and editBox text after scripts are set
        local currentValue = GetSetting(dbKey) or defaultVal
        DebugPrint("Initial setup for:", dbKey, "DB value:", GetSetting(dbKey), "currentValue:", currentValue)
        slider:SetValue(currentValue)
        editBox:SetText(format(formatStr, currentValue))
        editBox:SetCursorPosition(0)  -- Force visual update
        DebugPrint("Initial SetText:", format(formatStr, currentValue), "GetText after:", editBox:GetText())
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
        colorBtn:SetPoint("LEFT", container, "LEFT", 120, 0)
        colorBtn:SetSize(24, 24)

        local colorTex = colorBtn:CreateTexture(nil, "BACKGROUND")
        colorTex:SetAllPoints()
        local c = GetSetting(dbKey) or defaultColor
        colorTex:SetColorTexture(c.r, c.g, c.b, c.a or 1)

        colorBtn:SetScript("OnClick", function()
            local currentColor = GetSetting(dbKey) or defaultColor
            local info = {
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    SetSetting(dbKey, { r = r, g = g, b = b, a = a })
                    colorTex:SetColorTexture(r, g, b, a)
                    UpdateBarAppearance()
                end,
                opacityFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    SetSetting(dbKey, { r = r, g = g, b = b, a = a })
                    colorTex:SetColorTexture(r, g, b, a)
                    UpdateBarAppearance()
                end,
                cancelFunc = function(prev)
                    SetSetting(dbKey, { r = prev.r, g = prev.g, b = prev.b, a = prev.a })
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

    -- Helper: Create a simple dropdown (non-LSM)
    local function CreateSimpleDropdown(parent, x, y, label, dbKey, defaultVal, options)
        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", x, y)
        container:SetSize(220, 50)

        local dropLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        dropLabel:SetPoint("TOPLEFT", 0, 0)
        dropLabel:SetText(label)

        local dropdown = CreateFrame("Frame", nil, container, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", -16, -15)

        local function Initialize(self, level)
            local currentVal = GetSetting(dbKey)
            if currentVal == nil then
                currentVal = defaultVal
            end

            for _, opt in ipairs(options) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = opt.text
                info.checked = (opt.value == currentVal)
                info.func = function()
                    SetSetting(dbKey, opt.value)
                    UIDropDownMenu_SetText(dropdown, opt.text)
                    CloseDropDownMenus()
                    UpdateBarAppearance()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end

        -- Find display text for current value
        local currentVal = GetSetting(dbKey)
        if currentVal == nil then
            currentVal = defaultVal
        end
        local displayText = defaultVal
        for _, opt in ipairs(options) do
            if opt.value == currentVal then
                displayText = opt.text
                break
            end
        end

        UIDropDownMenu_SetWidth(dropdown, 213)
        UIDropDownMenu_SetText(dropdown, displayText)
        UIDropDownMenu_Initialize(dropdown, Initialize)

        return container, y - 55
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
            local currentVal = GetSetting(dbKey) or defaultVal

            for _, name in ipairs(list) do
                local info = UIDropDownMenu_CreateInfo()
                local selectedName = name  -- Capture in local for closure
                info.text = name
                info.checked = (name == currentVal)
                info.func = function()
                    SetSetting(dbKey, selectedName)
                    UIDropDownMenu_SetText(dropdown, selectedName)
                    CloseDropDownMenus()
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

        UIDropDownMenu_SetWidth(dropdown, 213)
        UIDropDownMenu_SetText(dropdown, GetSetting(dbKey) or defaultVal)
        UIDropDownMenu_Initialize(dropdown, Initialize)

        return container, y - 55
    end

    -- Helper: Create a section header
    local function CreateSectionHeader(parent, x, y, text)
        local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
        local fontName, fontSize, fontFlags = header:GetFont()
        header:SetFont(fontName, fontSize + 2, fontFlags)
        header:SetPoint("TOPLEFT", x, y)
        header:SetText(text)
        header:SetTextColor(1, 0.82, 0)

        local line = parent:CreateTexture(nil, "ARTWORK")
        line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -2)
        line:SetSize(230, 1)
        line:SetColorTexture(0.6, 0.6, 0.6, 0.8)

        return y - 35
    end

    -- Layout columns
    local col1 = 20
    local col2 = 280

    -- =====================
    -- PROFILES SECTION (spans both columns at top)
    -- =====================
    local yProfile = -10
    local profileDropdown, profileCopyDropdown
    local profileCurrentLabel

    -- Create wide section header for profiles
    local profileHeader = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    local fontName, fontSize, fontFlags = profileHeader:GetFont()
    profileHeader:SetFont(fontName, fontSize + 2, fontFlags)
    profileHeader:SetPoint("TOPLEFT", col1, yProfile)
    profileHeader:SetText("Profiles")
    profileHeader:SetTextColor(1, 0.82, 0)

    local profileLine = content:CreateTexture(nil, "ARTWORK")
    profileLine:SetPoint("TOPLEFT", profileHeader, "BOTTOMLEFT", 0, -2)
    profileLine:SetSize(490, 1)  -- Wide line spanning both columns
    profileLine:SetColorTexture(0.6, 0.6, 0.6, 0.8)

    yProfile = yProfile - 30

    -- LEFT SIDE: Current profile and Switch Profile
    -- Current profile label
    local profileLabelContainer = CreateFrame("Frame", nil, content)
    profileLabelContainer:SetPoint("TOPLEFT", col1, yProfile)
    profileLabelContainer:SetSize(220, 20)

    local profileLabelText = profileLabelContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    profileLabelText:SetPoint("LEFT", 0, 0)
    profileLabelText:SetText("Current Profile:")

    profileCurrentLabel = profileLabelContainer:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    profileCurrentLabel:SetPoint("LEFT", profileLabelText, "RIGHT", 5, 0)
    profileCurrentLabel:SetText(db and db.GetCurrentProfile and db:GetCurrentProfile() or "Default")

    -- RIGHT SIDE: New profile input
    local newProfileContainer = CreateFrame("Frame", nil, content)
    newProfileContainer:SetPoint("TOPLEFT", col2, yProfile)
    newProfileContainer:SetSize(220, 20)

    local newProfileLabel = newProfileContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    newProfileLabel:SetPoint("LEFT", 0, 0)
    newProfileLabel:SetText("New Profile:")

    local newProfileEditBox = CreateFrame("EditBox", nil, newProfileContainer, "InputBoxTemplate")
    newProfileEditBox:SetPoint("LEFT", newProfileLabel, "RIGHT", 10, 0)
    newProfileEditBox:SetSize(98, 20)
    newProfileEditBox:SetAutoFocus(false)

    local newProfileBtn = CreateFrame("Button", nil, newProfileContainer, "UIPanelButtonTemplate")
    newProfileBtn:SetPoint("LEFT", newProfileEditBox, "RIGHT", 5, 0)
    newProfileBtn:SetSize(60, 20)
    newProfileBtn:SetText("Create")
    newProfileBtn:SetScript("OnClick", function()
        local name = newProfileEditBox:GetText()
        if name and name ~= "" and db and db.SetProfile then
            db:SetProfile(name)
            db:ResetProfile()
            newProfileEditBox:SetText("")
            UIDropDownMenu_SetText(profileDropdown, name)
            profileCurrentLabel:SetText(name)
            print("AbsorbTracker: Created profile '" .. name .. "'")
        end
    end)

    yProfile = yProfile - 30

    -- LEFT SIDE: Switch Profile dropdown
    local profileContainer = CreateFrame("Frame", nil, content)
    profileContainer:SetPoint("TOPLEFT", col1, yProfile)
    profileContainer:SetSize(220, 50)

    local profileDropLabel = profileContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    profileDropLabel:SetPoint("TOPLEFT", 0, 0)
    profileDropLabel:SetText("Switch Profile")

    profileDropdown = CreateFrame("Frame", nil, profileContainer, "UIDropDownMenuTemplate")
    profileDropdown:SetPoint("TOPLEFT", -16, -15)

    local function InitializeProfileDropdown(self, level)
        if not db or not db.GetProfiles then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "AceDB not available"
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
            return
        end

        local profiles = db:GetProfiles()
        local current = db:GetCurrentProfile()

        for _, name in ipairs(profiles) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = name
            info.checked = (name == current)
            info.func = function()
                db:SetProfile(name)
                UIDropDownMenu_SetText(profileDropdown, name)
                profileCurrentLabel:SetText(name)
                CloseDropDownMenus()
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_SetWidth(profileDropdown, 213)
    UIDropDownMenu_SetText(profileDropdown, db and db.GetCurrentProfile and db:GetCurrentProfile() or "Default")
    UIDropDownMenu_Initialize(profileDropdown, InitializeProfileDropdown)

    -- RIGHT SIDE: Copy From dropdown
    local copyContainer = CreateFrame("Frame", nil, content)
    copyContainer:SetPoint("TOPLEFT", col2, yProfile)
    copyContainer:SetSize(220, 50)

    local copyDropLabel = copyContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    copyDropLabel:SetPoint("TOPLEFT", 0, 0)
    copyDropLabel:SetText("Copy From Profile")

    profileCopyDropdown = CreateFrame("Frame", nil, copyContainer, "UIDropDownMenuTemplate")
    profileCopyDropdown:SetPoint("TOPLEFT", -16, -15)

    local function InitializeCopyDropdown(self, level)
        if not db or not db.GetProfiles then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "AceDB not available"
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
            return
        end

        local profiles = db:GetProfiles()
        local current = db:GetCurrentProfile()

        for _, name in ipairs(profiles) do
            if name ~= current then
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.func = function()
                    db:CopyProfile(name)
                    UIDropDownMenu_SetText(profileCopyDropdown, "Select...")
                    CloseDropDownMenus()
                    print("AbsorbTracker: Copied settings from '" .. name .. "'")
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end
    end

    UIDropDownMenu_SetWidth(profileCopyDropdown, 213)
    UIDropDownMenu_SetText(profileCopyDropdown, "Select...")
    UIDropDownMenu_Initialize(profileCopyDropdown, InitializeCopyDropdown)

    yProfile = yProfile - 55

    -- Reset and Delete buttons (centered across both columns)
    local buttonContainer = CreateFrame("Frame", nil, content)
    buttonContainer:SetPoint("TOPLEFT", col1, yProfile)
    buttonContainer:SetSize(490, 25)

    local resetBtn = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
    resetBtn:SetPoint("LEFT", 0, 0)
    resetBtn:SetSize(111, 22)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        if db and db.ResetProfile then
            db:ResetProfile()
            print("AbsorbTracker: Profile reset to defaults")
        end
    end)

    local deleteBtn = CreateFrame("Button", nil, buttonContainer, "UIPanelButtonTemplate")
    deleteBtn:SetPoint("LEFT", resetBtn, "RIGHT", 10, 0)
    deleteBtn:SetSize(111, 22)
    deleteBtn:SetText("Delete Profile")
    deleteBtn:SetScript("OnClick", function()
        if db and db.DeleteProfile and db.GetCurrentProfile then
            local current = db:GetCurrentProfile()
            print("AbsorbTracker: Use '/at profile delete <name>' to delete profiles.")
            print("AbsorbTracker: Current profile '" .. current .. "' cannot be deleted while active.")
        end
    end)

    -- =====================
    -- LEFT COLUMN (below profiles)
    -- =====================
    local y1 = yProfile - 40

    -- Save Y position for aligning Performance with General
    local generalY = y1

    -- GENERAL SECTION
    y1 = CreateSectionHeader(content, col1, y1, "General")

    -- Show Bar checkbox
    local showCb = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
    showCb:SetPoint("TOPLEFT", col1, y1)
    showCb.Text:SetText("Show Bar")
    showCb:SetChecked(not GetSetting("hidden"))
    showCb:SetScript("OnClick", function(self)
        SetSetting("hidden", not self:GetChecked())
        UpdateBarAppearance()
        if not GetSetting("hidden") then
            lastAbsorb = -1  -- Reset cache to force update
            UpdateAbsorbBar()
        end
    end)
    y1 = y1 - 30

    -- Lock Position checkbox
    local lockCb
    lockCb, y1 = CreateCheckbox(content, col1, y1, "Lock Position", "locked", flatDefaults.locked)

    y1 = y1 - 20

    -- Save Y position for aligning Border with Bar Size
    local barSizeY = y1

    -- BAR SIZE SECTION
    y1 = CreateSectionHeader(content, col1, y1, "Bar Size")

    local widthSlider
    widthSlider, y1 = CreateSlider(content, col1, y1, "Bar Width", "barWidth", flatDefaults.barWidth, 50, 500, 1)

    local heightSlider
    heightSlider, y1 = CreateSlider(content, col1, y1, "Bar Height", "barHeight", flatDefaults.barHeight, 10, 100, 1)

    y1 = y1 - 20

    -- Save Y position for aligning Font with Bar Color
    local barColorY = y1

    -- BAR COLOR SECTION (left column)
    y1 = CreateSectionHeader(content, col1, y1, "Bar Color")

    local barColorBtn
    barColorBtn, y1 = CreateColorButton(content, col1, y1, "Bar Color", "barColor", flatDefaults.barColor)

    local bgColorBtn
    bgColorBtn, y1 = CreateColorButton(content, col1, y1, "Background Color", "bgColor", flatDefaults.bgColor)

    y1 = y1 - 20

    -- BAR TEXTURES SECTION (left column)
    y1 = CreateSectionHeader(content, col1, y1, "Bar Textures")

    local textureDropdown
    textureDropdown, y1 = CreateMediaDropdown(content, col1, y1, "Bar Texture", "statusbar", "barTexture", flatDefaults.barTexture)

    local bgTextureDropdown
    bgTextureDropdown, y1 = CreateMediaDropdown(content, col1, y1, "Background Texture", "statusbar", "bgTexture", flatDefaults.bgTexture)

    -- =====================
    -- RIGHT COLUMN (below profiles)
    -- =====================
    local y2 = generalY

    -- PERFORMANCE SECTION
    y2 = CreateSectionHeader(content, col2, y2, "Performance")

    local intervalSlider
    intervalSlider, y2 = CreateSlider(content, col2, y2, "Update Interval (sec)", "updateInterval", flatDefaults.updateInterval, 0.1, 10, 0.1, 1, RestartUpdateTicker)

    -- Align Border with Bar Size section
    y2 = barSizeY

    -- BORDER SECTION (right column)
    y2 = CreateSectionHeader(content, col2, y2, "Border")

    local borderDropdown
    borderDropdown, y2 = CreateMediaDropdown(content, col2, y2, "Border Style", "border", "border", flatDefaults.border)

    local borderSizeSlider
    borderSizeSlider, y2 = CreateSlider(content, col2, y2, "Border Size", "borderSize", flatDefaults.borderSize, 1, 32, 1)

    -- Align Font with Bar Color section
    y2 = barColorY

    -- FONT SECTION (right column, under Border)
    y2 = CreateSectionHeader(content, col2, y2, "Font")

    local fontDropdown
    fontDropdown, y2 = CreateMediaDropdown(content, col2, y2, "Font Face", "font", "font", flatDefaults.font)

    local fontSizeSlider
    fontSizeSlider, y2 = CreateSlider(content, col2, y2, "Font Size", "fontSize", flatDefaults.fontSize, 6, 32, 1)

    local fontFlagsOptions = {
        { text = "None", value = "" },
        { text = "Outline", value = "OUTLINE" },
        { text = "Thick Outline", value = "THICKOUTLINE" },
        { text = "Monochrome", value = "MONOCHROME" },
        { text = "Monochrome, Outline", value = "MONOCHROME, OUTLINE" },
        { text = "Monochrome, Thick Outline", value = "MONOCHROME, THICKOUTLINE" },
    }
    local fontFlagsDropdown
    fontFlagsDropdown, y2 = CreateSimpleDropdown(content, col2, y2, "Font Outline", "fontFlags", flatDefaults.fontFlags, fontFlagsOptions)

    -- Set content height based on the lowest point of content
    local contentHeight = max(-y1, -y2) + 40  -- Add padding at bottom
    content:SetHeight(contentHeight)

    -- Refresh all slider edit boxes and profile UI when panel is shown
    panel:SetScript("OnShow", function()
        DebugPrint("Panel OnShow fired, refreshing", #sliderRefreshFuncs, "sliders")
        for i, refreshFunc in ipairs(sliderRefreshFuncs) do
            DebugPrint("Calling refresh function", i)
            refreshFunc()
        end
        -- Refresh profile UI
        if db and db.GetCurrentProfile then
            local current = db:GetCurrentProfile()
            profileCurrentLabel:SetText(current)
            UIDropDownMenu_SetText(profileDropdown, current)
        end
        DebugPrint("Panel OnShow complete")
    end)

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
