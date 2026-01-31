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

-- Slash commands
SLASH_ABSORBTRACKER1 = "/absorbtracker"
SLASH_ABSORBTRACKER2 = "/at"
SlashCmdList["ABSORBTRACKER"] = function(msg)
    local cmd, arg = msg:match("^(%S*)%s*(.*)$")
    cmd = cmd:lower()

    if cmd == "debug" then
        AddonTable.DEBUG = not AddonTable.DEBUG
        print("AbsorbTracker: Debug mode", AddonTable.DEBUG and "ENABLED" or "DISABLED")

    elseif cmd == "update" then
        print("AbsorbTracker: Forcing update...")
        AddonTable.lastAbsorb = -1  -- Reset cache to force update
        UpdateAbsorbBar()

    elseif cmd == "test" then
        -- Test display with fake values
        local testVal = tonumber(arg) or 50000
        print("AbsorbTracker: Testing display with value:", AbbreviateNumbers(testVal))
        AddonTable.valueText:SetText(AbbreviateNumbers(testVal))
        AddonTable.statusBar:SetMinMaxValues(0, 100000)
        AddonTable.statusBar:SetValue(testVal)
        print("AbsorbTracker: Text set to:", AddonTable.valueText:GetText())
        print("AbsorbTracker: Bar value:", AbbreviateNumbers(AddonTable.statusBar:GetValue()), "min/max:", AddonTable.statusBar:GetMinMaxValues())

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

    elseif cmd == "bordercolor" then
        if arg and arg ~= "" then
            local color = ParseColor(arg)
            if color then
                SetSetting("borderColor", color)
                UpdateBarAppearance()
                print(format("AbsorbTracker: Border color set to %.2f %.2f %.2f %.2f", color.r, color.g, color.b, color.a))
            else
                print("AbsorbTracker: Invalid color format.")
                print("Usage: /at bordercolor <r> <g> <b> [a]  (0-255 or 0-1)")
            end
        else
            local r, g, b, a = GetBorderColor()
            print(format("AbsorbTracker: Current border color: %.2f %.2f %.2f %.2f", r, g, b, a))
            print("Usage: /at bordercolor <r> <g> <b> [a]  (0-255 or 0-1)")
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
                AddonTable.DebugPrint("Slash command setting interval to:", interval)
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
            AddonTable.lastAbsorb = -1  -- Reset cache to force update
            UpdateAbsorbBar()
            print("AbsorbTracker: Shown")
        end

    elseif cmd == "profile" then
        -- Profile management commands
        local db = AddonTable.db
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
        AddonTable.OpenOptionsPanel()

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
        print("  /at bordercolor <r> <g> <b> [a] - Set border color")
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
