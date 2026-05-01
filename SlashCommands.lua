-- AbsorbTracker: SlashCommands module - Slash command handlers
local AddonName, AddonTable = ...

local GetSetting = AddonTable.GetSetting
local SetSetting = AddonTable.SetSetting
local UpdateBarAppearance = AddonTable.UpdateBarAppearance
local UpdateAbsorbBar = AddonTable.UpdateAbsorbBar
local RestartUpdateTicker = AddonTable.RestartUpdateTicker
local PrintLSMList = AddonTable.PrintLSMList
local ParseColor = AddonTable.ParseColor
local GetBarColor = AddonTable.GetBarColor
local GetBgColor = AddonTable.GetBgColor
local GetBorderColor = AddonTable.GetBorderColor

-- Route all chat output through the cyan-[AT] helper.
local print = AddonTable.Print

-- Print a help row with the command in yellow and the explanation in white.
local function PrintCmd(cmd, desc)
    print(format("  |cFFFFFF00%s|r - |cFFFFFFFF%s|r", cmd, desc))
end

-- Slash commands
SLASH_ABSORBTRACKER1 = "/absorbtracker"
SLASH_ABSORBTRACKER2 = "/at"
SlashCmdList["ABSORBTRACKER"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()

    if cmd == "debug" then
        AddonTable.DEBUG = not AddonTable.DEBUG
        print("Debug mode", AddonTable.DEBUG and "ENABLED" or "DISABLED")

    elseif cmd == "update" then
        print("Forcing update...")
        AddonTable.lastAbsorb = -1  -- Reset cache to force update
        UpdateAbsorbBar()

    elseif cmd == "test" then
        -- Test display with fake values
        local testVal = tonumber(arg) or 50000
        print("Testing display with value:", AbbreviateNumbers(testVal))
        AddonTable.valueText:SetText(AbbreviateNumbers(testVal))
        AddonTable.statusBar:SetMinMaxValues(0, 100000)
        AddonTable.statusBar:SetValue(testVal)
        print("Text set to:", AddonTable.valueText:GetText())
        print("Bar value:", AbbreviateNumbers(AddonTable.statusBar:GetValue()), "min/max:", AddonTable.statusBar:GetMinMaxValues())

    elseif cmd == "texture" then
        if arg and arg ~= "" then
            SetSetting("barTexture", arg)
            UpdateBarAppearance()
            print("Texture set to '" .. arg .. "'")
        else
            if PrintLSMList("statusbar", "barTexture") then
                print("Usage: /at texture <name>")
            end
        end

    elseif cmd == "bgtexture" then
        if arg and arg ~= "" then
            SetSetting("bgTexture", arg)
            UpdateBarAppearance()
            print("Background texture set to '" .. arg .. "'")
        else
            if PrintLSMList("statusbar", "bgTexture") then
                print("Usage: /at bgtexture <name>")
            end
        end

    elseif cmd == "border" then
        if arg and arg ~= "" then
            SetSetting("border", arg)
            UpdateBarAppearance()
            print("Border set to '" .. arg .. "'")
        else
            if PrintLSMList("border", "border") then
                print("Usage: /at border <name>")
            end
        end

    elseif cmd == "font" then
        if arg and arg ~= "" then
            SetSetting("font", arg)
            UpdateBarAppearance()
            print("Font set to '" .. arg .. "'")
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
                print("Font size set to " .. size)
            else
                print("Invalid font size. Use a number between 6 and 32.")
            end
        else
            print("Current font size: " .. GetSetting("fontSize"))
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
                print("Font flags set to '" .. displayName .. "'")
            else
                print("Invalid font flags.")
                print("Valid options: none, outline, thickoutline, monochrome, monochrome, outline, monochrome, thickoutline")
            end
        else
            local current = GetSetting("fontFlags")
            local displayCurrent = (current == "" or current == nil) and "None" or current
            print("Current font flags: " .. displayCurrent)
            print("Usage: /at fontflags <option>")
            print("Options: none, outline, thickoutline, monochrome, monochrome, outline, monochrome, thickoutline")
        end

    elseif cmd == "width" then
        if arg and arg ~= "" then
            local width = tonumber(arg)
            if width and width >= 50 and width <= 500 then
                SetSetting("barWidth", width)
                UpdateBarAppearance()
                print("Bar width set to " .. width)
            else
                print("Invalid width. Use a number between 50 and 500.")
            end
        else
            print("Current bar width: " .. GetSetting("barWidth"))
            print("Usage: /at width <pixels>  (50-500)")
        end

    elseif cmd == "height" then
        if arg and arg ~= "" then
            local height = tonumber(arg)
            if height and height >= 10 and height <= 100 then
                SetSetting("barHeight", height)
                UpdateBarAppearance()
                print("Bar height set to " .. height)
            else
                print("Invalid height. Use a number between 10 and 100.")
            end
        else
            print("Current bar height: " .. GetSetting("barHeight"))
            print("Usage: /at height <pixels>  (10-100)")
        end

    elseif cmd == "bordersize" then
        if arg and arg ~= "" then
            local size = tonumber(arg)
            if size and size >= 1 and size <= 32 then
                SetSetting("borderSize", size)
                UpdateBarAppearance()
                print("Border size set to " .. size)
            else
                print("Invalid border size. Use a number between 1 and 32.")
            end
        else
            print("Current border size: " .. GetSetting("borderSize"))
            print("Usage: /at bordersize <size>  (1-32)")
        end

    elseif cmd == "bordercolor" then
        if arg:lower():match("^classcolor") then
            local toggle = arg:lower():match("^classcolor%s+(.+)")
            local new
            if toggle == "on" then
                new = true
            elseif toggle == "off" then
                new = false
            else
                new = not GetSetting("useClassColorBorder")
            end
            SetSetting("useClassColorBorder", new)
            UpdateBarAppearance()
            print("Border class color " .. (new and "enabled" or "disabled"))
        elseif arg ~= "" then
            local color = ParseColor(arg)
            if color then
                SetSetting("borderColor", color)
                UpdateBarAppearance()
                print(format("Border color set to %.2f %.2f %.2f %.2f", color.r, color.g, color.b, color.a))
            else
                print("Invalid color format.")
                print("Usage: /at bordercolor <r> <g> <b> [a]  (0-255 or 0-1)")
            end
        else
            local r, g, b, a = GetBorderColor()
            print(format("Current border color: %.2f %.2f %.2f %.2f", r, g, b, a))
            print("Class color: " .. (GetSetting("useClassColorBorder") and "enabled" or "disabled"))
            print("Usage: /at bordercolor <r> <g> <b> [a]  (0-255 or 0-1)")
            print("Usage: /at bordercolor classcolor [on|off]")
        end

    elseif cmd == "color" then
        if arg:lower():match("^classcolor") then
            local toggle = arg:lower():match("^classcolor%s+(.+)")
            local new
            if toggle == "on" then
                new = true
            elseif toggle == "off" then
                new = false
            else
                new = not GetSetting("useClassColorBar")
            end
            SetSetting("useClassColorBar", new)
            UpdateBarAppearance()
            print("Bar class color " .. (new and "enabled" or "disabled"))
        elseif arg ~= "" then
            local color = ParseColor(arg)
            if color then
                SetSetting("barColor", color)
                UpdateBarAppearance()
                print(format("Bar color set to %.2f %.2f %.2f %.2f", color.r, color.g, color.b, color.a))
            else
                print("Invalid color format.")
                print("Usage: /at color <r> <g> <b> [a]  (0-255 or 0-1)")
            end
        else
            local r, g, b, a = GetBarColor()
            print(format("Current bar color: %.2f %.2f %.2f %.2f", r, g, b, a))
            print("Class color: " .. (GetSetting("useClassColorBar") and "enabled" or "disabled"))
            print("Usage: /at color <r> <g> <b> [a]  (0-255 or 0-1)")
            print("Usage: /at color classcolor [on|off]")
        end

    elseif cmd == "bgcolor" then
        if arg:lower():match("^classcolor") then
            local toggle = arg:lower():match("^classcolor%s+(.+)")
            local new
            if toggle == "on" then
                new = true
            elseif toggle == "off" then
                new = false
            else
                new = not GetSetting("useClassColorBg")
            end
            SetSetting("useClassColorBg", new)
            UpdateBarAppearance()
            print("Background class color " .. (new and "enabled" or "disabled"))
        elseif arg ~= "" then
            local color = ParseColor(arg)
            if color then
                SetSetting("bgColor", color)
                UpdateBarAppearance()
                print(format("Background color set to %.2f %.2f %.2f %.2f", color.r, color.g, color.b, color.a))
            else
                print("Invalid color format.")
                print("Usage: /at bgcolor <r> <g> <b> [a]  (0-255 or 0-1)")
            end
        else
            local r, g, b, a = GetBgColor()
            print(format("Current background color: %.2f %.2f %.2f %.2f", r, g, b, a))
            print("Class color: " .. (GetSetting("useClassColorBg") and "enabled" or "disabled"))
            print("Usage: /at bgcolor <r> <g> <b> [a]  (0-255 or 0-1)")
            print("Usage: /at bgcolor classcolor [on|off]")
        end

    elseif cmd == "lock" then
        SetSetting("locked", true)
        UpdateBarAppearance()
        print("Bar locked")

    elseif cmd == "unlock" then
        SetSetting("locked", false)
        UpdateBarAppearance()
        print("Bar unlocked")

    elseif cmd == "interval" then
        if arg and arg ~= "" then
            local interval = tonumber(arg)
            if interval and interval >= 0.1 and interval <= 10 then
                AddonTable.DebugPrint("Slash command setting interval to:", interval)
                SetSetting("updateInterval", interval)
                RestartUpdateTicker()
                print(format("Update interval set to %.1f seconds", interval))
            else
                print("Invalid interval. Use a number between 0.1 and 10.")
            end
        else
            print(format("Current update interval: %.1f seconds", GetSetting("updateInterval")))
            print("Usage: /at interval <seconds>  (0.1-10)")
        end

    elseif cmd == "toggle" then
        SetSetting("hidden", not GetSetting("hidden"))
        UpdateBarAppearance()
        if GetSetting("hidden") then
            print("Hidden")
        else
            AddonTable.lastAbsorb = -1  -- Reset cache to force update
            UpdateAbsorbBar()
            print("Shown")
        end

    elseif cmd == "profile" then
        -- Profile management commands
        local db = AddonTable.db
        if not db or not db.SetProfile then
            print("Profile system requires AceDB-3.0. Install Ace3 to use profiles.")
            return
        end

        local subcmd, subarg = arg:match("^(%S*)%s*(.*)$")
        subcmd = (subcmd or ""):lower()

        if subcmd == "list" then
            print("Available profiles:")
            local current = db:GetCurrentProfile()
            for _, name in ipairs(db:GetProfiles()) do
                local marker = (name == current) and " (current)" or ""
                print("  " .. name .. marker)
            end
        elseif subcmd == "use" or subcmd == "set" then
            if subarg and subarg ~= "" then
                db:SetProfile(subarg)
                print("Switched to profile '" .. subarg .. "'")
            else
                print("Usage: /at profile use <name>")
            end
        elseif subcmd == "new" or subcmd == "create" then
            if subarg and subarg ~= "" then
                db:SetProfile(subarg)
                db:ResetProfile()
                print("Created and switched to new profile '" .. subarg .. "'")
            else
                print("Usage: /at profile new <name>")
            end
        elseif subcmd == "copy" then
            if subarg and subarg ~= "" then
                db:CopyProfile(subarg)
                print("Copied settings from profile '" .. subarg .. "'")
            else
                print("Usage: /at profile copy <name>")
                print("Copies settings from another profile to the current one.")
            end
        elseif subcmd == "delete" or subcmd == "remove" then
            if subarg and subarg ~= "" then
                local current = db:GetCurrentProfile()
                if subarg == current then
                    print("Cannot delete the current profile.")
                else
                    db:DeleteProfile(subarg, true)
                    print("Deleted profile '" .. subarg .. "'")
                end
            else
                print("Usage: /at profile delete <name>")
            end
        elseif subcmd == "reset" then
            db:ResetProfile()
            print("Profile reset to defaults")
        elseif subcmd == "current" then
            print("Current profile: " .. db:GetCurrentProfile())
        else
            print("Profile commands:")
            PrintCmd("/at profile list", "List all profiles")
            PrintCmd("/at profile current", "Show current profile name")
            PrintCmd("/at profile use <name>", "Switch to profile")
            PrintCmd("/at profile new <name>", "Create new profile with defaults")
            PrintCmd("/at profile copy <name>", "Copy settings from another profile")
            PrintCmd("/at profile delete <name>", "Delete a profile")
            PrintCmd("/at profile reset", "Reset current profile to defaults")
        end

    elseif cmd == "config" then
        AddonTable.OpenOptionsPanel()

    else
        print("Commands (use |cFFFFFF00/at|r or |cFFFFFF00/absorbtracker|r):")
        PrintCmd("/at", "Show this help")
        PrintCmd("/at config", "Open settings panel")
        PrintCmd("/at toggle", "Toggle visibility")
        PrintCmd("/at debug", "Toggle debug mode")
        PrintCmd("/at test [value]", "Test display with fake value")
        PrintCmd("/at lock", "Lock bar position")
        PrintCmd("/at unlock", "Unlock bar position")
        PrintCmd("/at texture [name]", "List or set bar texture")
        PrintCmd("/at bgtexture [name]", "List or set background texture")
        PrintCmd("/at border [name]", "List or set border")
        PrintCmd("/at bordersize <size>", "Set border size (1-32)")
        PrintCmd("/at bordercolor <r> <g> <b> [a]", "Set border color")
        PrintCmd("/at bordercolor classcolor [on|off]", "Toggle border class color")
        PrintCmd("/at font [name]", "List or set font")
        PrintCmd("/at fontsize <size>", "Set font size (6-32)")
        PrintCmd("/at fontflags <option>", "Set font outline (none, outline, thickoutline, etc.)")
        PrintCmd("/at width <pixels>", "Set bar width (50-500)")
        PrintCmd("/at height <pixels>", "Set bar height (10-100)")
        PrintCmd("/at color <r> <g> <b> [a]", "Set bar color")
        PrintCmd("/at color classcolor [on|off]", "Toggle bar class color")
        PrintCmd("/at bgcolor <r> <g> <b> [a]", "Set background color")
        PrintCmd("/at bgcolor classcolor [on|off]", "Toggle background class color")
        PrintCmd("/at interval <seconds>", "Set update interval (0.1-10)")
        PrintCmd("/at profile", "Profile management commands")
    end
end
