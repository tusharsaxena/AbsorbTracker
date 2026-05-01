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

-- Route all chat output through the cyan-[AT] helper.
local print = AddonTable.Print

-- Options Panel (Settings API for WoW 10.0+)
function AddonTable.CreateOptionsPanel()
    local db = AddonTable.db
    local panel = CreateFrame("Frame")
    panel.name = "Ka0s Absorb Tracker"

    -- Table to store refresh functions for all controls
    local panelRefreshFuncs = {}

    -- Title stays on the main panel (outside scroll area)
    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Ka0s Absorb Tracker Settings")

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

    -- Shared state for custom scrollable media dropdowns
    local activeDropdownCloseFunc = nil

    local dropdownClickCatcher = CreateFrame("Button", nil, UIParent)
    dropdownClickCatcher:SetAllPoints(UIParent)
    dropdownClickCatcher:SetFrameStrata("FULLSCREEN")
    dropdownClickCatcher:SetFrameLevel(0)
    dropdownClickCatcher:Hide()
    dropdownClickCatcher:SetScript("OnClick", function()
        if activeDropdownCloseFunc then
            activeDropdownCloseFunc()
        end
    end)

    -- Helper: Create a custom scrollable dropdown
    -- getItems: function() returning array of {text=string, checked=bool, disabled=bool}
    -- onSelect: function(text) called when an item is clicked
    -- Returns: container, setTextFunc, newY
    local function CreateCustomDropdown(parent, x, y, label, dropWidth, initialText, getItems, onSelect)
        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", x, y)
        container:SetSize(dropWidth, 50)

        local dropLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        dropLabel:SetPoint("TOPLEFT", 0, 0)
        dropLabel:SetText(label)

        local btnFrame = CreateFrame("Button", nil, container, "BackdropTemplate")
        btnFrame:SetPoint("TOPLEFT", 0, -18)
        btnFrame:SetSize(dropWidth, 24)
        btnFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        btnFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)
        btnFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)

        local selectedText = btnFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        selectedText:SetPoint("LEFT", 8, 0)
        selectedText:SetPoint("RIGHT", -24, 0)
        selectedText:SetJustifyH("LEFT")
        selectedText:SetText(initialText)

        local arrow = btnFrame:CreateTexture(nil, "ARTWORK")
        arrow:SetPoint("RIGHT", -5, 0)
        arrow:SetSize(16, 16)
        arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")

        local ITEM_HEIGHT = 18
        local MAX_VISIBLE = 10
        local SCROLLBAR_WIDTH = 16

        local listFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        listFrame:SetFrameStrata("FULLSCREEN")
        listFrame:SetFrameLevel(1)
        listFrame:SetClampedToScreen(true)
        listFrame:EnableMouse(true)
        listFrame:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        listFrame:SetBackdropColor(0.15, 0.15, 0.15, 0.95)
        listFrame:SetBackdropBorderColor(0.4, 0.4, 0.4, 0.8)
        listFrame:Hide()

        local ddScrollFrame = CreateFrame("ScrollFrame", nil, listFrame)
        ddScrollFrame:SetPoint("TOPLEFT", 6, -6)

        local scrollChild = CreateFrame("Frame", nil, ddScrollFrame)
        ddScrollFrame:SetScrollChild(scrollChild)

        local scrollBar = CreateFrame("Slider", nil, listFrame, "BackdropTemplate")
        scrollBar:SetPoint("TOPRIGHT", -6, -6)
        scrollBar:SetPoint("BOTTOMRIGHT", -6, 6)
        scrollBar:SetWidth(SCROLLBAR_WIDTH)
        scrollBar:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            insets = { left = 4, right = 4, top = 4, bottom = 4 },
        })
        scrollBar:SetBackdropColor(0, 0, 0, 0.4)
        scrollBar:SetValueStep(ITEM_HEIGHT)
        scrollBar:SetObeyStepOnDrag(true)

        local thumb = scrollBar:CreateTexture(nil, "OVERLAY")
        thumb:SetSize(SCROLLBAR_WIDTH - 4, 24)
        thumb:SetColorTexture(0.5, 0.5, 0.5, 0.7)
        scrollBar:SetThumbTexture(thumb)

        scrollBar:SetScript("OnValueChanged", function(self, value)
            ddScrollFrame:SetVerticalScroll(value)
        end)

        local itemButtons = {}

        local function CloseList()
            listFrame:Hide()
            dropdownClickCatcher:Hide()
            activeDropdownCloseFunc = nil
        end

        local function OpenList()
            if activeDropdownCloseFunc then
                activeDropdownCloseFunc()
            end
            CloseDropDownMenus()

            local items = getItems()
            local numItems = #items
            if numItems == 0 then return end

            local needsScroll = numItems > MAX_VISIBLE
            local visibleItems = min(numItems, MAX_VISIBLE)
            local listHeight = visibleItems * ITEM_HEIGHT + 12

            listFrame:SetSize(dropWidth, listHeight)
            listFrame:ClearAllPoints()
            listFrame:SetPoint("TOPLEFT", btnFrame, "BOTTOMLEFT", 0, -2)

            local scrollRightOffset = needsScroll and -(SCROLLBAR_WIDTH + 8) or -6
            ddScrollFrame:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", scrollRightOffset, 6)

            local contentWidth = needsScroll and (dropWidth - SCROLLBAR_WIDTH - 14) or (dropWidth - 12)
            scrollChild:SetSize(contentWidth, numItems * ITEM_HEIGHT)

            for i, item in ipairs(items) do
                local itemBtn = itemButtons[i]
                if not itemBtn then
                    itemBtn = CreateFrame("Button", nil, scrollChild)
                    itemBtn:SetHeight(ITEM_HEIGHT)

                    local hl = itemBtn:CreateTexture(nil, "HIGHLIGHT")
                    hl:SetAllPoints()
                    hl:SetColorTexture(0.3, 0.3, 0.7, 0.4)

                    local checkMark = itemBtn:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
                    checkMark:SetPoint("LEFT", 2, 0)
                    checkMark:SetWidth(14)
                    itemBtn.checkMark = checkMark

                    local text = itemBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    text:SetPoint("LEFT", 16, 0)
                    text:SetPoint("RIGHT", -4, 0)
                    text:SetJustifyH("LEFT")
                    itemBtn.text = text

                    itemButtons[i] = itemBtn
                end

                itemBtn:SetParent(scrollChild)
                itemBtn:ClearAllPoints()
                itemBtn:SetPoint("TOPLEFT", 0, -(i - 1) * ITEM_HEIGHT)
                itemBtn:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

                itemBtn.text:SetText(item.text)
                itemBtn.checkMark:SetText(item.checked and "|cFF00FF00>|r" or "")

                if item.disabled then
                    itemBtn.text:SetTextColor(0.5, 0.5, 0.5)
                    itemBtn:SetScript("OnClick", nil)
                else
                    itemBtn.text:SetTextColor(1, 0.82, 0)
                    local itemText = item.text
                    itemBtn:SetScript("OnClick", function()
                        onSelect(itemText)
                        CloseList()
                    end)
                end

                itemBtn:Show()
            end

            for i = numItems + 1, #itemButtons do
                itemButtons[i]:Hide()
            end

            if needsScroll then
                local maxScroll = (numItems - visibleItems) * ITEM_HEIGHT
                scrollBar:SetMinMaxValues(0, maxScroll)

                -- Scroll to show the checked (selected) item
                local scrollTo = 0
                for i, item in ipairs(items) do
                    if item.checked then
                        -- Position the selected item in the middle of the visible area
                        local itemTop = (i - 1) * ITEM_HEIGHT
                        local centerOffset = floor((visibleItems - 1) / 2) * ITEM_HEIGHT
                        scrollTo = max(0, min(maxScroll, itemTop - centerOffset))
                        break
                    end
                end
                scrollBar:SetValue(scrollTo)
                ddScrollFrame:SetVerticalScroll(scrollTo)
                scrollBar:Show()
            else
                scrollBar:Hide()
                ddScrollFrame:SetVerticalScroll(0)
            end

            activeDropdownCloseFunc = CloseList
            dropdownClickCatcher:Show()
            listFrame:Show()
        end

        btnFrame:SetScript("OnClick", function()
            if listFrame:IsShown() then
                CloseList()
            else
                OpenList()
            end
        end)

        listFrame:EnableMouseWheel(true)
        listFrame:SetScript("OnMouseWheel", function(self, delta)
            if scrollBar:IsShown() then
                local current = scrollBar:GetValue()
                local _, maxVal = scrollBar:GetMinMaxValues()
                local step = ITEM_HEIGHT * 2
                if delta > 0 then
                    scrollBar:SetValue(max(0, current - step))
                else
                    scrollBar:SetValue(min(maxVal, current + step))
                end
            end
        end)

        container:SetScript("OnHide", function()
            if listFrame:IsShown() then
                CloseList()
            end
        end)

        local function setText(text)
            selectedText:SetText(text)
        end

        return container, setText, y - 55
    end

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
    local function CreateColorButton(parent, x, y, label, dbKey, defaultColor, classColorKey, classColorGetter)
        local container = CreateFrame("Frame", nil, parent)
        container:SetPoint("TOPLEFT", x, y)
        container:SetSize(250, 30)

        local colorLabel = container:CreateFontString(nil, "ARTWORK", "GameFontNormal")
        colorLabel:SetPoint("LEFT", 0, 0)
        colorLabel:SetText(label)

        local colorBtn = CreateFrame("Button", nil, container)
        colorBtn:SetPoint("LEFT", container, "LEFT", 120, 0)
        colorBtn:SetSize(24, 24)

        local colorTex = colorBtn:CreateTexture(nil, "BACKGROUND")
        colorTex:SetAllPoints()

        local function UpdateSwatchColor()
            if classColorKey and GetSetting(classColorKey) then
                local cc = classColorGetter()
                local c = GetSetting(dbKey) or defaultColor
                colorTex:SetColorTexture(cc.r, cc.g, cc.b, c.a or 1)
            else
                local c = GetSetting(dbKey) or defaultColor
                colorTex:SetColorTexture(c.r, c.g, c.b, c.a or 1)
            end
        end

        local function UpdateColorBtnState()
            if classColorKey and GetSetting(classColorKey) then
                colorBtn:Disable()
                colorBtn:SetAlpha(0.5)
            else
                colorBtn:Enable()
                colorBtn:SetAlpha(1.0)
            end
        end

        UpdateSwatchColor()
        UpdateColorBtnState()

        colorBtn:SetScript("OnClick", function()
            local currentColor = GetSetting(dbKey) or defaultColor
            local info = {
                swatchFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    SetSetting(dbKey, { r = r, g = g, b = b, a = a })
                    UpdateSwatchColor()
                    UpdateBarAppearance()
                end,
                opacityFunc = function()
                    local r, g, b = ColorPickerFrame:GetColorRGB()
                    local a = ColorPickerFrame:GetColorAlpha()
                    SetSetting(dbKey, { r = r, g = g, b = b, a = a })
                    UpdateSwatchColor()
                    UpdateBarAppearance()
                end,
                cancelFunc = function(prev)
                    SetSetting(dbKey, { r = prev.r, g = prev.g, b = prev.b, a = prev.a })
                    UpdateSwatchColor()
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

        -- Class Color checkbox (optional)
        local classColorCb
        if classColorKey then
            classColorCb = CreateFrame("CheckButton", nil, container, "InterfaceOptionsCheckButtonTemplate")
            classColorCb:SetPoint("LEFT", colorBtn, "RIGHT", 4, 0)
            classColorCb.Text:SetText("Class Color")
            classColorCb:SetChecked(GetSetting(classColorKey))
            classColorCb:SetScript("OnClick", function(self)
                SetSetting(classColorKey, self:GetChecked())
                UpdateSwatchColor()
                UpdateColorBtnState()
                UpdateBarAppearance()
            end)
        end

        -- Register refresh function
        table.insert(panelRefreshFuncs, function()
            UpdateSwatchColor()
            UpdateColorBtnState()
            if classColorCb then
                classColorCb:SetChecked(GetSetting(classColorKey))
            end
        end)

        return container, y - 35
    end

    -- Helper: Create a simple dropdown (non-LSM)
    local function CreateSimpleDropdown(parent, x, y, label, dbKey, defaultVal, options)
        local function getDisplayText(val)
            for _, opt in ipairs(options) do
                if opt.value == val then return opt.text end
            end
            return defaultVal
        end

        local currentVal = GetSetting(dbKey)
        if currentVal == nil then currentVal = defaultVal end

        local container, setText
        container, setText, y = CreateCustomDropdown(parent, x, y, label, 220, getDisplayText(currentVal),
            function()
                local cv = GetSetting(dbKey)
                if cv == nil then cv = defaultVal end
                local items = {}
                for _, opt in ipairs(options) do
                    table.insert(items, { text = opt.text, checked = (opt.value == cv) })
                end
                return items
            end,
            function(text)
                for _, opt in ipairs(options) do
                    if opt.text == text then
                        SetSetting(dbKey, opt.value)
                        setText(text)
                        UpdateBarAppearance()
                        break
                    end
                end
            end
        )

        table.insert(panelRefreshFuncs, function()
            local val = GetSetting(dbKey)
            if val == nil then val = defaultVal end
            setText(getDisplayText(val))
        end)

        return container, y
    end

    -- Helper: Create a scrollable dropdown for LSM media
    local function CreateMediaDropdown(parent, x, y, label, mediaType, dbKey, defaultVal)
        local container, setText
        container, setText, y = CreateCustomDropdown(parent, x, y, label, 220, GetSetting(dbKey) or defaultVal,
            function()
                local LSM = GetLSM()
                local list = LSM and LSM:List(mediaType) or {}
                local currentVal = GetSetting(dbKey) or defaultVal
                local items = {}
                if #list == 0 then
                    table.insert(items, { text = defaultVal, checked = true })
                else
                    for _, name in ipairs(list) do
                        table.insert(items, { text = name, checked = (name == currentVal) })
                    end
                end
                return items
            end,
            function(name)
                SetSetting(dbKey, name)
                setText(name)
                UpdateBarAppearance()
            end
        )

        table.insert(panelRefreshFuncs, function()
            setText(GetSetting(dbKey) or defaultVal)
        end)

        return container, y
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
    local profileSetText
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
            profileSetText(name)
            profileCurrentLabel:SetText(name)
            print("Created profile '" .. name .. "'")
        end
    end)

    yProfile = yProfile - 30

    -- LEFT SIDE: Switch Profile dropdown
    local switchY = yProfile
    local profileDropContainer
    profileDropContainer, profileSetText = CreateCustomDropdown(content, col1, switchY, "Switch Profile", 220,
        db and db.GetCurrentProfile and db:GetCurrentProfile() or "Default",
        function()
            if not db or not db.GetProfiles then
                return { { text = "AceDB not available", disabled = true } }
            end
            local profiles = db:GetProfiles()
            local current = db:GetCurrentProfile()
            local items = {}
            for _, name in ipairs(profiles) do
                table.insert(items, { text = name, checked = (name == current) })
            end
            return items
        end,
        function(name)
            if db and db.SetProfile then
                db:SetProfile(name)
                profileSetText(name)
                profileCurrentLabel:SetText(name)
            end
        end
    )

    -- RIGHT SIDE: Copy From dropdown
    local copySetText
    local copyDropContainer
    copyDropContainer, copySetText = CreateCustomDropdown(content, col2, switchY, "Copy From Profile", 220,
        "Select...",
        function()
            if not db or not db.GetProfiles then
                return { { text = "AceDB not available", disabled = true } }
            end
            local profiles = db:GetProfiles()
            local current = db:GetCurrentProfile()
            local items = {}
            for _, name in ipairs(profiles) do
                if name ~= current then
                    table.insert(items, { text = name })
                end
            end
            return items
        end,
        function(name)
            if db and db.CopyProfile then
                db:CopyProfile(name)
                copySetText("Select...")
                print("Copied settings from '" .. name .. "'")
            end
        end
    )

    yProfile = yProfile - 55

    -- LEFT SIDE: Reset to Defaults button
    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetPoint("TOPLEFT", col1, yProfile + 5)
    resetBtn:SetSize(230, 22)
    resetBtn:SetText("Reset to Defaults")
    resetBtn:SetScript("OnClick", function()
        if db and db.ResetProfile then
            db:ResetProfile()
            print("Profile reset to defaults")
        end
    end)

    -- RIGHT SIDE: Delete Profile dropdown and button
    local selectedDeleteProfile = nil
    local deleteSetText
    local deleteDropContainer
    deleteDropContainer, deleteSetText = CreateCustomDropdown(content, col2, yProfile, "Delete Profile", 150,
        "Select...",
        function()
            if not db or not db.GetProfiles then
                return { { text = "AceDB not available", disabled = true } }
            end
            local profiles = db:GetProfiles()
            local current = db:GetCurrentProfile()
            local items = {}
            for _, name in ipairs(profiles) do
                if name ~= current then
                    table.insert(items, { text = name, checked = (name == selectedDeleteProfile) })
                end
            end
            if #items == 0 then
                table.insert(items, { text = "No other profiles", disabled = true })
            end
            return items
        end,
        function(name)
            selectedDeleteProfile = name
            deleteSetText(name)
        end
    )

    local deleteBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    deleteBtn:SetPoint("TOPLEFT", deleteDropContainer, "TOPRIGHT", 5, -18)
    deleteBtn:SetSize(60, 22)
    deleteBtn:SetText("Delete")
    deleteBtn:SetScript("OnClick", function()
        if selectedDeleteProfile and db and db.DeleteProfile then
            db:DeleteProfile(selectedDeleteProfile, true)
            print("Deleted profile '" .. selectedDeleteProfile .. "'")
            selectedDeleteProfile = nil
            deleteSetText("Select...")
        else
            print("Select a profile to delete.")
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
    barColorBtn, y1 = CreateColorButton(content, col1, y1, "Bar Color", "barColor", flatDefaults.barColor, "useClassColorBar", AddonTable.GetPlayerClassColor)

    local bgColorBtn
    bgColorBtn, y1 = CreateColorButton(content, col1, y1, "Background Color", "bgColor", flatDefaults.bgColor, "useClassColorBg", AddonTable.GetBgClassColor)

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
    borderColorBtn, y2 = CreateColorButton(content, col2, y2, "Border Color", "borderColor", flatDefaults.borderColor, "useClassColorBorder", AddonTable.GetPlayerClassColor)

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
            profileSetText(current)
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
        print("Cannot open settings panel during combat. Try again after combat ends.")
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
