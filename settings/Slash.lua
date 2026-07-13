local addonName, NS = ...
NS.Slash = NS.Slash or {}
local Sl = NS.Slash

-- Schema-driven slash dispatcher registered via AceConsole (Ka0s standard §7.1 — no hand-rolled
-- SLASH_* globals). /at list, /at get and /at set walk NS.Schema directly, so adding an option is
-- one schema row (in some settings/<page>.lua) and the slash surface picks it up automatically.
--
-- NS.COMMANDS is an ordered {name, desc, fn} table; PrintHelp and the About page both iterate it,
-- so the help block and the panel command list stay in lockstep with the dispatcher.

local print = NS.Print

-- Help row formatter — gold command + em-dash + white description.
local function PrintCmd(cmd, desc)
    print(("  |cFFFFFF00%s|r \226\128\148 |cFFFFFFFF%s|r"):format(cmd, desc))
end

-- Shared `key = value` formatter for schema output (Ka0s standard, slash-commands-§5): setting
-- key gold (ffff00), value white (ffffff). Used by /at list rows and the /at get / /at set
-- single-line echo so the `key = value` shape reads identically everywhere. No trailing colon.
local function FormatKV(path, valueStr)
    return ("|cFFFFFF00%s|r = |cFFFFFFFF%s|r"):format(path, valueStr)
end

-- Forward declarations so the commands table can reference handlers defined below.
local printHelp, listSettings, getSetting, setSetting
local runReset, runResetAll, runResetPosition
local runDebug, runUpdate, runTest, runProfile

NS.COMMANDS = {
    {"help",          "List available commands",
        function() printHelp() end},
    {"config",        "Open the settings panel",
        function() NS.OpenOptionsPanel() end},
    {"list",          "List every setting and its current value",
        function() listSettings() end},
    {"get",           "Print a setting's current value \226\128\148 `/at get <path>`",
        function(rest) getSetting(rest) end},
    {"set",           "Set a setting \226\128\148 `/at set <path> <value>` (try /at list)",
        function(rest) setSetting(rest) end},
    {"reset",         "Reset a panel to defaults \226\128\148 `/at reset <general|bar|border|font>`",
        function(rest) runReset(rest) end},
    {"resetall",      "Reset every setting to defaults",
        function() runResetAll() end},
    {"resetposition", "Move the bar back to the screen center",
        function() runResetPosition() end},
    {"lock",          "Lock the bar in place",
        function()
            NS.SetByPath("locked", true)
            print("Bar locked")
        end},
    {"unlock",        "Unlock the bar so it can be dragged",
        function()
            NS.SetByPath("locked", false)
            print("Bar unlocked")
        end},
    {"toggle",        "Toggle bar visibility",
        function()
            local hidden = not NS.GetSetting("hidden")
            NS.SetByPath("hidden", hidden)
            if hidden then
                print("Hidden")
            else
                if NS.UpdateAbsorbBar then NS.UpdateAbsorbBar() end
                print("Shown")
            end
        end},
    {"debug",         "Toggle the debug console \226\128\148 `on`/`off` enable/disable logging",
        function(rest) runDebug(rest) end},
    {"update",        "Force a bar refresh",
        function() runUpdate() end},
    {"test",          "Test display with a fake value \226\128\148 `/at test [value] [hold-secs]`",
        function(rest) runTest(rest) end},
    {"profile",       "Profile management \226\128\148 try `/at profile` for the list",
        function(rest) runProfile(rest) end},
}

-- Alias kept for the About page, which renders the same list (settings/About.lua).
NS.SlashCommands = NS.COMMANDS

local function findCommand(name)
    for _, entry in ipairs(NS.COMMANDS) do
        if entry[1] == name then return entry end
    end
end

-- ---------------------------------------------------------------------
-- /at help
-- ---------------------------------------------------------------------

local function getVersion()
    return NS.Compat.GetAddOnMetadata(NS.name, "Version") or NS.version or "?"
end

function printHelp()
    print(("v%s \226\128\148 slash commands (|cFFFFFF00/absorbtracker|r is an alias for |cFFFFFF00/at|r)")
        :format(getVersion()))
    for _, entry in ipairs(NS.COMMANDS) do
        PrintCmd("/at " .. entry[1], entry[2])
    end
end

-- ---------------------------------------------------------------------
-- Schema-driven /at list / /at get / /at set
-- ---------------------------------------------------------------------

-- Page order for /at list grouping. Profiles is omitted (its schema is supplied by AceDBOptions).
local PAGE_ORDER = { "general", "bar", "border", "font" }

function listSettings()
    if not NS.Schema or #NS.Schema == 0 then
        return print("No settings registered yet")
    end
    -- Colour scheme for /at list (Ka0s standard, slash-commands-§5): header green (33ff99),
    -- [page] group headers azure (3399ff), key/value via FormatKV. No trailing colons.
    print("|cff33ff99Available settings|r")

    local byPage = {}
    for _, row in ipairs(NS.Schema) do
        local key = row.page or "?"
        byPage[key] = byPage[key] or {}
        byPage[key][#byPage[key] + 1] = row
    end

    for _, page in ipairs(PAGE_ORDER) do
        local rows = byPage[page]
        if rows then
            print("  |cff3399ff[" .. page .. "]|r")
            for _, row in ipairs(rows) do
                local v = NS.GetSetting(row.path)
                print("    " .. FormatKV(row.path, NS.FormatSchemaValue(row, v)))
            end
        end
    end
end

function getSetting(rest)
    local path = (rest or ""):match("^(%S+)")
    if not path or path == "" then
        return print("Usage: /at get <path>")
    end
    local row = NS.FindSchemaRow(path)
    if not row then
        return print("Setting not found: " .. path)
    end
    local v = NS.GetSetting(row.path)
    print(FormatKV(row.path, NS.FormatSchemaValue(row, v)))
end

function setSetting(rest)
    local path, value = (rest or ""):match("^(%S+)%s*(.*)$")
    if not path or path == "" then
        return print("Usage: /at set <path> <value>  (try /at list)")
    end
    local row = NS.FindSchemaRow(path)
    if not row then
        return print("Setting not found: " .. path)
    end

    local v, err = NS.ParseSchemaValue(row, value or "")
    if v == nil then
        print("Invalid value for " .. row.path)
        if err and err ~= "" then print("  " .. err) end
        return
    end

    NS.SetByPath(row.path, v)
    print(FormatKV(row.path, NS.FormatSchemaValue(row, NS.GetSetting(row.path))))
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
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
    local rows = NS.SchemaForPage(page)
    for _, row in ipairs(rows) do
        NS.ApplyDefault(row)
    end
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    print(page .. " page reset to defaults")
end

function runResetAll()
    for _, row in ipairs(NS.Schema) do
        NS.ApplyDefault(row)
    end
    if NS.db and NS.db.profile then
        NS.db.profile.position = nil
    end
    if NS.RestoreBarPosition then NS.RestoreBarPosition() end
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    print("All settings reset to defaults")
end

function runResetPosition()
    if NS.db and NS.db.profile then
        NS.db.profile.position = nil
    end
    if NS.RestoreBarPosition then NS.RestoreBarPosition() end
    print("Bar position reset")
end

-- ---------------------------------------------------------------------
-- /at debug / /at update / /at test
-- ---------------------------------------------------------------------
--
-- /at debug        toggles the on-screen debug console window (state unchanged).
-- /at debug on|off enables / disables session logging (§12.5).

function runDebug(rest)
    local sub = (rest or ""):match("^(%S*)") or ""
    sub = sub:lower()
    if sub == "on" or sub == "off" then
        if NS.DebugLog and NS.DebugLog.SetEnabled then
            NS.DebugLog:SetEnabled(sub == "on")
        elseif NS.State then
            NS.State.debug = (sub == "on")
        end
        return
    end
    if NS.DebugLog and NS.DebugLog.Toggle then
        NS.DebugLog:Toggle()
    else
        print("Debug console unavailable")
    end
end

function runUpdate()
    if NS.UpdateAbsorbBar then NS.UpdateAbsorbBar() end
    print("Forced refresh")
end

function runTest(rest)
    local args = {}
    for w in (rest or ""):gmatch("%S+") do args[#args + 1] = w end
    local n    = tonumber(args[1]) or 50000
    local hold = tonumber(args[2]) or 5

    if NS.GetSetting("hidden") then
        print("Bar is hidden; run /at toggle to show it before testing")
        return
    end

    print(("Testing display with value: %s for %d s"):format(AbbreviateNumbers(n), hold))
    if NS.valueText and NS.statusBar then
        NS.valueText:SetText(AbbreviateNumbers(n))
        NS.statusBar:SetMinMaxValues(0, math.max(n, 100000))
        NS.statusBar:SetValue(n)
    end
    NS.testHoldUntil = GetTime() + hold
end

-- ---------------------------------------------------------------------
-- /at profile
-- ---------------------------------------------------------------------

function runProfile(rest)
    local db = NS.db
    if not db or not db.SetProfile then
        return print("Profile system requires AceDB-3.0")
    end

    local sub, subarg = (rest or ""):match("^(%S*)%s*(.*)$")
    sub = (sub or ""):lower()

    if sub == "" then
        print("Profile commands")
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
        print("Available profiles")
        local current = db:GetCurrentProfile()
        for _, name in ipairs(db:GetProfiles()) do
            local marker = (name == current) and " (current)" or ""
            print("  " .. name .. marker)
        end
    elseif sub == "current" then
        print("Current profile: " .. db:GetCurrentProfile())
    elseif sub == "use" then
        if subarg ~= "" then
            db:SetProfile(subarg)
            print("Switched to profile '" .. subarg .. "'")
        else
            print("Usage: /at profile use <name>")
        end
    elseif sub == "new" then
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
    elseif sub == "delete" then
        if subarg ~= "" then
            if subarg == db:GetCurrentProfile() then
                print("Cannot delete the current profile")
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
-- Registration + dispatch (AceConsole)
-- ---------------------------------------------------------------------

function Sl:OnSlash(msg)
    local raw = (msg or ""):match("^%s*(.-)%s*$") or ""
    if raw == "" then return printHelp() end

    -- Lowercase only the command name; preserve case in `rest` so schema paths like `barTexture`
    -- survive `/at set ...`.
    local cmd, rest = raw:match("^(%S+)%s*(.*)$")
    cmd  = (cmd or ""):lower()
    rest = rest or ""

    -- Backward-compat alias: `/at options` -> `/at config`.
    if cmd == "options" then cmd = "config" end

    local entry = findCommand(cmd)
    if entry then return entry[3](rest) end

    print("unknown command '" .. cmd .. "'")
    printHelp()
end

function Sl:Register()
    NS.addon:RegisterChatCommand("at", function(msg) Sl:OnSlash(msg) end)
    NS.addon:RegisterChatCommand("absorbtracker", function(msg) Sl:OnSlash(msg) end)
end
