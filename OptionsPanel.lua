-- AbsorbTracker: OptionsPanel module - Settings UI panel
local AddonName, AddonTable = ...

local floor, max, min = AddonTable.floor, AddonTable.max, AddonTable.min
local flatDefaults = AddonTable.flatDefaults
local GetSetting = AddonTable.GetSetting
local SetSetting = AddonTable.SetSetting
local GetLSM = AddonTable.GetLSM
local UpdateBarAppearance = AddonTable.UpdateBarAppearance
local UpdateAbsorbBar = AddonTable.UpdateAbsorbBar
local RestartUpdateTicker = AddonTable.RestartUpdateTicker

-- Options Panel (Settings API for WoW 10.0+)
function AddonTable.CreateOptionsPanel()
    local db = AddonTable.db
    local panel = CreateFrame("Frame")
    panel.name = "AbsorbTracker"

    -- Table to store refresh functions for all controls
    local panelRefreshFuncs = {}

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
        -- Register refresh function
        table.insert(panelRefreshFuncs, function()
            cb:SetChecked(GetSetting(dbKey) or defaultVal)
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
            if not initialized then return end
            value = ApplyValue(value)
            editBox:SetText(format(formatStr, value))
            editBox:SetCursorPosition(0)  -- Force visual update
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

        -- Register refresh function for panel
        local function refreshEditBox()
            local currentValue = GetSetting(dbKey) or defaultVal
            slider:SetValue(currentValue)
            editBox:SetText(format(formatStr, currentValue))
            editBox:SetCursorPosition(0)  -- Force visual update
        end
        table.insert(panelRefreshFuncs, refreshEditBox)

        -- Initialize slider value and editBox text after scripts are set
        local currentValue = GetSetting(dbKey) or defaultVal
        slider:SetValue(currentValue)
        editBox:SetText(format(formatStr, currentValue))
        editBox:SetCursorPosition(0)  -- Force visual update
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

        -- Register refresh function
        table.insert(panelRefreshFuncs, function()
            local c = GetSetting(dbKey) or defaultColor
            colorTex:SetColorTexture(c.r, c.g, c.b, c.a or 1)
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

        -- Register refresh function
        table.insert(panelRefreshFuncs, function()
            local val = GetSetting(dbKey)
            if val == nil then
                val = defaultVal
            end
            local text = defaultVal
            for _, opt in ipairs(options) do
                if opt.value == val then
                    text = opt.text
                    break
                end
            end
            UIDropDownMenu_SetText(dropdown, text)
        end)

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

        -- Register refresh function
        table.insert(panelRefreshFuncs, function()
            UIDropDownMenu_SetText(dropdown, GetSetting(dbKey) or defaultVal)
        end)

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

        return y - 30
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

    -- LEFT SIDE: Reset to Defaults button
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", col1, yProfile + 5)
    resetBtn:SetSize(230, 22)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        if db and db.ResetProfile then
            db:ResetProfile()
            print("AbsorbTracker: Profile reset to defaults")
        end
    end)

    -- RIGHT SIDE: Delete Profile dropdown and button
    local deleteContainer = CreateFrame("Frame", nil, content)
    deleteContainer:SetPoint("TOPLEFT", col2, yProfile)
    deleteContainer:SetSize(220, 50)

    local deleteDropLabel = deleteContainer:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    deleteDropLabel:SetPoint("TOPLEFT", 0, 0)
    deleteDropLabel:SetText("Delete Profile")

    local profileDeleteDropdown = CreateFrame("Frame", nil, deleteContainer, "UIDropDownMenuTemplate")
    profileDeleteDropdown:SetPoint("TOPLEFT", -16, -15)

    local selectedDeleteProfile = nil

    local function InitializeDeleteDropdown(self, level)
        if not db or not db.GetProfiles then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "AceDB not available"
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
            return
        end

        local profiles = db:GetProfiles()
        local current = db:GetCurrentProfile()
        local hasOtherProfiles = false

        for _, name in ipairs(profiles) do
            if name ~= current then
                hasOtherProfiles = true
                local info = UIDropDownMenu_CreateInfo()
                info.text = name
                info.checked = (name == selectedDeleteProfile)
                info.func = function()
                    selectedDeleteProfile = name
                    UIDropDownMenu_SetText(profileDeleteDropdown, name)
                    CloseDropDownMenus()
                end
                UIDropDownMenu_AddButton(info, level)
            end
        end

        if not hasOtherProfiles then
            local info = UIDropDownMenu_CreateInfo()
            info.text = "No other profiles"
            info.disabled = true
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_SetWidth(profileDeleteDropdown, 148)
    UIDropDownMenu_SetText(profileDeleteDropdown, "Select...")
    UIDropDownMenu_Initialize(profileDeleteDropdown, InitializeDeleteDropdown)

    local deleteBtn = CreateFrame("Button", nil, deleteContainer, "UIPanelButtonTemplate")
    deleteBtn:SetPoint("LEFT", profileDeleteDropdown, "RIGHT", -10, 2)
    deleteBtn:SetSize(60, 22)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", function()
        if selectedDeleteProfile and db and db.DeleteProfile then
            db:DeleteProfile(selectedDeleteProfile, true)
            print("AbsorbTracker: Deleted profile '" .. selectedDeleteProfile .. "'")
            selectedDeleteProfile = nil
            UIDropDownMenu_SetText(profileDeleteDropdown, "Select...")
        else
            print("AbsorbTracker: Select a profile to delete.")
        end
    end)

    -- =====================
    -- LEFT COLUMN (below profiles)
    -- =====================
    local y1 = yProfile - 60

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
            AddonTable.lastAbsorb = -1  -- Reset cache to force update
            UpdateAbsorbBar()
        end
    end)
    -- Register refresh function (inverted logic: checked = not hidden)
    table.insert(panelRefreshFuncs, function()
        showCb:SetChecked(not GetSetting("hidden"))
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

    local borderColorBtn
    borderColorBtn, y2 = CreateColorButton(content, col2, y2, "Border Color", "borderColor", flatDefaults.borderColor)

    y2 = y2 - 10

    -- Align Font with Bar Color section (use lower position to ensure spacing after Border)
    y2 = min(y2, barColorY)

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

    -- Function to refresh all controls in the panel
    local function RefreshOptionsPanel()
        for _, refreshFunc in ipairs(panelRefreshFuncs) do
            refreshFunc()
        end
        -- Refresh profile UI
        if db and db.GetCurrentProfile then
            local current = db:GetCurrentProfile()
            profileCurrentLabel:SetText(current)
            UIDropDownMenu_SetText(profileDropdown, current)
        end
    end

    -- Store refresh function in AddonTable for OnProfileChanged to call
    AddonTable.RefreshOptionsPanel = RefreshOptionsPanel

    -- Refresh all controls when panel is shown
    panel:SetScript("OnShow", RefreshOptionsPanel)

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
function AddonTable.OpenOptionsPanel()
    -- Cannot open settings panel during combat (protected function)
    if InCombatLockdown() then
        print("AbsorbTracker: Cannot open settings panel during combat. Try again after combat ends.")
        return
    end
    if Settings and Settings.OpenToCategory and AddonTable.settingsCategory then
        Settings.OpenToCategory(AddonTable.settingsCategory:GetID())
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(AddonTable.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(AddonTable.optionsPanel)
    end
end

print("AbsorbTracker loaded. /at for commands")
