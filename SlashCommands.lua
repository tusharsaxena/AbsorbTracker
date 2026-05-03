-- AbsorbTracker: SlashCommands module
--
-- Schema-driven slash dispatcher. /at list, /at get and /at set walk
-- AddonTable.Schema directly — adding a new option is one schema row
-- (in some Options/<page>.lua) and the slash surface picks it up
-- automatically.
--
-- Pattern lifted from Ka0s KickCD: a commands table maps name -> desc +
-- handler, printHelp iterates it for the help block, and the dispatcher
-- looks up by lowercased command name. The table is exposed on
-- AddonTable so the top-level Settings page can render the same list
-- without duplicating it.

local AddonName, AddonTable = ...

local print = AddonTable.Print

-- Help row formatter — yellow command + em-dash + white description.
local function PrintCmd(cmd, desc)
    print(("  |cFFFFFF00%s|r — |cFFFFFFFF%s|r"):format(cmd, desc))
end

-- Forward declarations so the commands table can reference handlers
-- defined further down.
local printHelp, listSettings, getSetting, setSetting
local runReset, runResetAll, runResetPosition
local runDebug, runUpdate, runTest, runProfile

AddonTable.SlashCommands = {
    {"help",          "List available commands",
        function() printHelp() end},
    {"config",        "Open the settings panel",
        function() AddonTable.OpenOptionsPanel() end},
    {"list",          "List every setting and its current value",
        function() listSettings() end},
    {"get",           "Print a setting's current value — `/at get <path>`",
        function(rest) getSetting(rest) end},
    {"set",           "Set a setting — `/at set <path> <value>` (try /at list)",
        function(rest) setSetting(rest) end},
    {"reset",         "Reset a panel to defaults — `/at reset <general|bar|border|font>`",
        function(rest) runReset(rest) end},
    {"resetall",      "Reset every setting to defaults",
        function() runResetAll() end},
    {"resetposition", "Move the bar back to the screen center",
        function() runResetPosition() end},
    {"lock",          "Lock the bar in place",
        function()
            AddonTable.SetByPath("locked", true)
            print("Bar locked")
        end},
    {"unlock",        "Unlock the bar so it can be dragged",
        function()
            AddonTable.SetByPath("locked", false)
            print("Bar unlocked")
        end},
    {"toggle",        "Toggle bar visibility",
        function()
            local hidden = not AddonTable.GetSetting("hidden")
            AddonTable.SetByPath("hidden", hidden)
            if hidden then
                print("Hidden")
            else
                if AddonTable.UpdateAbsorbBar then AddonTable.UpdateAbsorbBar() end
                print("Shown")
            end
        end},
    {"debug",         "Toggle debug mode",
        function() runDebug() end},
    {"update",        "Force a bar refresh",
        function() runUpdate() end},
    {"test",          "Test display with a fake value — `/at test [value] [hold-secs]`",
        function(rest) runTest(rest) end},
    {"profile",       "Profile management — try `/at profile` for the list",
        function(rest) runProfile(rest) end},
}

local function findCommand(name)
    for _, entry in ipairs(AddonTable.SlashCommands) do
        if entry[1] == name then return entry end
    end
end

-- ---------------------------------------------------------------------
-- /at help
-- ---------------------------------------------------------------------

local function getVersion()
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(AddonName, "Version") or "?"
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(AddonName, "Version") or "?"
    end
    return "?"
end

function printHelp()
    print(("v%s — slash commands (|cFFFFFF00/absorbtracker|r is an alias for |cFFFFFF00/at|r):")
        :format(getVersion()))
    for _, entry in ipairs(AddonTable.SlashCommands) do
        PrintCmd("/at " .. entry[1], entry[2])
    end
end

-- ---------------------------------------------------------------------
-- Schema-driven /at list / /at get / /at set
-- ---------------------------------------------------------------------

-- Page order for /at list grouping. Profiles is omitted (its schema
-- is supplied by AceDBOptions, not our schema array).
local PAGE_ORDER = { "general", "bar", "border", "font" }

function listSettings()
    if not AddonTable.Schema or #AddonTable.Schema == 0 then
        return print("No settings registered yet.")
    end
    print("Available settings:")

    local byPage = {}
    for _, row in ipairs(AddonTable.Schema) do
        local key = row.page or "?"
        byPage[key] = byPage[key] or {}
        byPage[key][#byPage[key] + 1] = row
    end

    for _, page in ipairs(PAGE_ORDER) do
        local rows = byPage[page]
        if rows then
            print("  [" .. page .. "]")
            for _, row in ipairs(rows) do
                local v = AddonTable.GetSetting(row.path)
                print(("    %s = %s"):format(
                    row.path, AddonTable.FormatSchemaValue(row, v)))
            end
        end
    end
end

function getSetting(rest)
    local path = (rest or ""):match("^(%S+)")
    if not path or path == "" then
        return print("Usage: /at get <path>")
    end
    local row = AddonTable.FindSchemaRow(path)
    if not row then
        return print("Setting not found: " .. path)
    end
    local v = AddonTable.GetSetting(row.path)
    print(("%s = %s"):format(row.path, AddonTable.FormatSchemaValue(row, v)))
end

function setSetting(rest)
    local path, value = (rest or ""):match("^(%S+)%s*(.*)$")
    if not path or path == "" then
        return print("Usage: /at set <path> <value>  (try /at list)")
    end
    local row = AddonTable.FindSchemaRow(path)
    if not row then
        return print("Setting not found: " .. path)
    end

    local v, err = AddonTable.ParseSchemaValue(row, value or "")
    if v == nil then
        print("Invalid value for " .. row.path)
        if err and err ~= "" then print("  " .. err) end
        return
    end

    AddonTable.SetByPath(row.path, v)
    print(("%s = %s"):format(row.path,
        AddonTable.FormatSchemaValue(row, AddonTable.GetSetting(row.path))))
    if AddonTable.RefreshOptionsPanel then AddonTable.RefreshOptionsPanel() end
end

-- ---------------------------------------------------------------------
-- /at reset / /at resetall / /at resetposition
-- ---------------------------------------------------------------------

local RESET_PAGES = {
    general = true, bar = true, border = true, font = true,
}

function runReset(rest)
    local page = (rest or ""):match("^(%S+)")
    page = page and page:lower() or ""
    if page == "" then
        return print("Usage: /at reset <general|bar|border|font>")
    end
    if not RESET_PAGES[page] then
        return print("Unknown page '" .. page .. "'. Valid: general, bar, border, font")
    end
    local rows = AddonTable.SchemaForPage(page)
    for _, row in ipairs(rows) do
        AddonTable.ApplyDefault(row)
    end
    if AddonTable.RefreshOptionsPanel then AddonTable.RefreshOptionsPanel() end
    print(page .. " page reset to defaults")
end

function runResetAll()
    for _, row in ipairs(AddonTable.Schema) do
        AddonTable.ApplyDefault(row)
    end
    if AddonTable.db and AddonTable.db.profile then
        AddonTable.db.profile.position = nil
    end
    if AddonTable.RestoreBarPosition then AddonTable.RestoreBarPosition() end
    if AddonTable.RefreshOptionsPanel then AddonTable.RefreshOptionsPanel() end
    print("All settings reset to defaults")
end

function runResetPosition()
    if AddonTable.db and AddonTable.db.profile then
        AddonTable.db.profile.position = nil
    end
    if AddonTable.RestoreBarPosition then AddonTable.RestoreBarPosition() end
    print("Bar position reset")
end

-- ---------------------------------------------------------------------
-- /at debug / /at update / /at test
-- ---------------------------------------------------------------------

function runDebug()
    AddonTable.DEBUG = not AddonTable.DEBUG
    print("Debug mode " .. (AddonTable.DEBUG and "ENABLED" or "DISABLED"))
end

function runUpdate()
    if AddonTable.UpdateAbsorbBar then AddonTable.UpdateAbsorbBar() end
    print("Forced refresh")
end

function runTest(rest)
    local args = {}
    for w in (rest or ""):gmatch("%S+") do args[#args + 1] = w end
    local n    = tonumber(args[1]) or 50000
    local hold = tonumber(args[2]) or 5

    if AddonTable.GetSetting("hidden") then
        print("Bar is hidden; run /at toggle to show it before testing.")
        return
    end

    print(("Testing display with value: %s for %d s"):format(AbbreviateNumbers(n), hold))
    if AddonTable.valueText and AddonTable.statusBar then
        AddonTable.valueText:SetText(AbbreviateNumbers(n))
        AddonTable.statusBar:SetMinMaxValues(0, math.max(n, 100000))
        AddonTable.statusBar:SetValue(n)
    end
    AddonTable.testHoldUntil = GetTime() + hold
end

-- ---------------------------------------------------------------------
-- /at profile (unchanged from previous implementation)
-- ---------------------------------------------------------------------

function runProfile(rest)
    local db = AddonTable.db
    if not db or not db.SetProfile then
        return print("Profile system requires AceDB-3.0.")
    end

    local sub, subarg = (rest or ""):match("^(%S*)%s*(.*)$")
    sub = (sub or ""):lower()

    if sub == "" then
        print("Profile commands:")
        PrintCmd("/at profile list",          "List all profiles")
        PrintCmd("/at profile current",       "Show current profile name")
        PrintCmd("/at profile use <name>",    "Switch to profile")
        PrintCmd("/at profile new <name>",    "Create new profile with defaults")
        PrintCmd("/at profile copy <name>",   "Copy settings from another profile")
        PrintCmd("/at profile delete <name>", "Delete a profile")
        PrintCmd("/at profile reset",         "Reset current profile to defaults")
        return
    end

    if sub == "list" then
        print("Available profiles:")
        local current = db:GetCurrentProfile()
        for _, name in ipairs(db:GetProfiles()) do
            local marker = (name == current) and " (current)" or ""
            print("  " .. name .. marker)
        end
    elseif sub == "current" then
        print("Current profile: " .. db:GetCurrentProfile())
    elseif sub == "use" or sub == "set" then
        if subarg ~= "" then
            db:SetProfile(subarg)
            print("Switched to profile '" .. subarg .. "'")
        else
            print("Usage: /at profile use <name>")
        end
    elseif sub == "new" or sub == "create" then
        if subarg ~= "" then
            db:SetProfile(subarg)
            db:ResetProfile()
            print("Created and switched to new profile '" .. subarg .. "'")
        else
            print("Usage: /at profile new <name>")
        end
    elseif sub == "copy" then
        if subarg ~= "" then
            db:CopyProfile(subarg)
            print("Copied settings from profile '" .. subarg .. "'")
        else
            print("Usage: /at profile copy <name>")
        end
    elseif sub == "delete" or sub == "remove" then
        if subarg ~= "" then
            if subarg == db:GetCurrentProfile() then
                print("Cannot delete the current profile.")
            else
                db:DeleteProfile(subarg, true)
                print("Deleted profile '" .. subarg .. "'")
            end
        else
            print("Usage: /at profile delete <name>")
        end
    elseif sub == "reset" then
        db:ResetProfile()
        print("Profile reset to defaults")
    else
        print("Unknown profile subcommand '" .. sub .. "'")
        runProfile("")
    end
end

-- ---------------------------------------------------------------------
-- Slash registration + dispatcher
-- ---------------------------------------------------------------------

SLASH_ABSORBTRACKER1 = "/absorbtracker"
SLASH_ABSORBTRACKER2 = "/at"

SlashCmdList["ABSORBTRACKER"] = function(msg)
    local raw = (msg or ""):match("^%s*(.-)%s*$") or ""
    if raw == "" then return printHelp() end

    -- Lowercase only the command name; preserve case in `rest` so
    -- schema paths like `barTexture` survive `/at set ...`.
    local cmd, rest = raw:match("^(%S+)%s*(.*)$")
    cmd  = (cmd or ""):lower()
    rest = rest or ""

    -- Backward-compat alias: `/at options` -> `/at config`.
    if cmd == "options" then cmd = "config" end

    local entry = findCommand(cmd)
    if entry then return entry[3](rest) end

    print("Unknown command '" .. cmd .. "'")
    printHelp()
end
