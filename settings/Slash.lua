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

-- Trailing note for a row whose unit is CURRENTLY mirroring the player.
--
-- Why it is needed: `/at get` and `/at set` resolve through NS.GetSetting, which walks the raw
-- profile path and never consults NS.Units.Get — so they read and write the unit's STORED value,
-- not the mirror-resolved one. That is deliberate and self-consistent (it is exactly what `/at
-- set` would write; resolving on read would make get/set asymmetric), but it is silent: `/at set
-- units.focus.barWidth 400` echoes a confident confirmation while the focus bar does not move,
-- because it is rendering the player's width. The note says so.
--
-- Only appearance rows are annotated. `enabled` and `mirror` carry alwaysPerUnit and are honoured
-- per-unit even while mirrored, so a note on them would be a lie. Grey (808080) keeps it visually
-- subordinate to the gold key / white value of the Ka0s scheme (slash-commands-§5).
local function MirrorNote(row)
    if row and row.unit and not row.alwaysPerUnit and NS.Units.IsMirrored(row.unit) then
        return "  |cff808080(mirrored \226\128\148 the bar shows Player's appearance)|r"
    end
    return ""
end

-- Forward declarations so the commands table can reference handlers defined below.
local printHelp, listSettings, getSetting, setSetting
local runReset, runResetAll, runResetPosition
local runDebug, runUpdate, runTest, runProfile, runToggle, runPerf
local getVersion

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
    {"reset",         "Reset a panel to defaults across every unit \226\128\148 `/at reset <general|bar|border|font>`",
        function(rest) runReset(rest) end},
    {"resetall",      "Reset every setting to defaults",
        function() runResetAll() end},
    {"resetposition", "Move every bar back to its default position",
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
    {"toggle",        "Toggle bars on or off \226\128\148 `/at toggle [player|target|focus]`",
        function(rest) runToggle(rest) end},
    {"debug",         "Toggle the debug console \226\128\148 `on`/`off` enable/disable logging",
        function(rest) runDebug(rest) end},
    {"perf",          "Measure performance \226\128\148 try `/at perf` for the workflow",
        function(rest) runPerf(rest) end},
    {"update",        "Force a bar refresh",
        function() runUpdate() end},
    {"version",       "Print the addon version",
        function() print(("v%s"):format(getVersion())) end},
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

function getVersion()
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
-- Which pages carry per-unit rows and therefore list once per unit.
local PER_UNIT_PAGES = { general = false, bar = true, border = true, font = true }

function listSettings()
    if not NS.Schema or #NS.Schema == 0 then
        return print("No settings registered yet")
    end
    -- Colour scheme (Ka0s standard, slash-commands-§5): header green (33ff99), group headers
    -- azure (3399ff), key/value via FormatKV. No trailing colons.
    print("|cff33ff99Available settings|r")

    local function printRows(header, rows)
        if #rows == 0 then return end
        print("  |cff3399ff[" .. header .. "]|r")
        for _, row in ipairs(rows) do
            local v = NS.GetSetting(row.path)
            print("    " .. FormatKV(row.path, NS.FormatSchemaValue(row, v)) .. MirrorNote(row))
        end
    end

    for _, page in ipairs(PAGE_ORDER) do
        if PER_UNIT_PAGES[page] then
            for _, unit in ipairs(NS.Units.LIST) do
                printRows(page .. " / " .. unit, NS.SchemaForPage(page, unit))
            end
        else
            printRows(page, NS.SchemaForPage(page))
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
    print(FormatKV(row.path, NS.FormatSchemaValue(row, v)) .. MirrorNote(row))
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
    print(FormatKV(row.path, NS.FormatSchemaValue(row, NS.GetSetting(row.path))) .. MirrorNote(row))
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
    -- Delegate to the single shared helper so the slash command and the
    -- "Reset All Settings" popup can never diverge — same rows reset,
    -- same position clear + recenter, same panel refresh.
    if NS.Helpers and NS.Helpers.RestoreAllDefaults then
        NS.Helpers.RestoreAllDefaults()
    end
    print("All settings reset to defaults")
end

function runResetPosition()
    -- Delegate to the single shared helper so this verb and the General page's "Reset Position"
    -- button can never diverge — same per-unit clear, same POSITION publish.
    -- The acknowledgement lives INSIDE the guard: printing it unconditionally would claim success
    -- on a load where settings/Helpers.lua never ran — the same silent-lie shape as the Reset
    -- Position button that nil'd an already-nil key and reported nothing.
    if NS.Helpers and NS.Helpers.ResetAllPositions then
        NS.Helpers.ResetAllPositions()
        print("Bar positions reset")
    else
        print("Cannot reset positions \226\128\148 the settings helpers failed to load")
    end
end

-- ---------------------------------------------------------------------
-- /at debug / /at update / /at test
-- ---------------------------------------------------------------------
--
-- /at debug        toggles the on-screen debug console window (state unchanged).
-- /at debug on|off enables / disables session logging (§12.5).

-- Emit a block of lines to BOTH the debug console and chat. The console is the real destination
-- (monospace, scrollable, copyable via its Copy button), but it writes through D:Add — which is
-- deliberately NOT gated on NS.State.debug — so `/at perf` output appears whether or not debug
-- logging is enabled. Without that, running a capture with logging off would look like it did
-- nothing.
local function emitPerfLines(lines)
    for _, line in ipairs(lines) do
        if NS.DebugLog and NS.DebugLog.Add then
            NS.DebugLog:Add("Perf", line)
        else
            print(line)
        end
    end
end

local PERF_USAGE = {
    "usage: /at perf <start|measure|finish|report|dump|suspend|resume>",
    "  start [label]  begin a run (resets counters); label distinguishes runs",
    "  measure a      arm Experiment A \226\128\148 addon ACTIVE, records while in combat",
    "  measure b      arm Experiment B \226\128\148 addon SUSPENDED, records while in combat",
    "  finish         end the run, save to AbsorbTrackerPerfDB, print the summary",
    "  report         print the summary without ending the run",
    "  dump           render the run as JSON in the copy window",
    "  suspend        make the addon inert by hand (measure b does this for you)",
    "  resume         restore it",
    "typical run: start \226\134\146 measure a \226\134\146 pull \226\134\146 measure b \226\134\146 same pull \226\134\146 finish \226\134\146 /reload",
}

-- Sub-verb handlers, one entry each. A dispatch table rather than an if/elseif ladder: the ladder
-- form measured CCN 24 under `lizard`, the highest in the addon, purely from the shape of the
-- dispatch — and this file already carries the repo's other complexity warning in runProfile. Each
-- handler here is CCN 1-3 and reads on its own.
local PERF_SUBS = {
    -- `rest` is the free text after the sub-verb: an optional capture label. Captures accumulate in
    -- a 10-run ring across sessions, so an auto-timestamp alone makes two runs from the same
    -- afternoon (e.g. "solo" vs "full addon set") near-impossible to tell apart when reading the
    -- SavedVariables file later. A supplied label is appended to the timestamp, never replaces it.
    start = function(P, rest)
        local stamp = date and date("%Y-%m-%d %H:%M") or "capture"
        local label = (rest or ""):match("^%s*(.-)%s*$")
        P.Start(label ~= "" and (stamp .. " " .. label) or stamp)
        P.__announce("perf run |cff40ff40STARTED|r \226\128\148 now `/at perf measure a`, then pull")
        for _, line in ipairs(P.ContextLines(P.context)) do print(line) end
        if NS.DebugLog and NS.DebugLog.Show then NS.DebugLog:Show() end
    end,

    measure = function(P, rest)
        local token = (rest or ""):match("^(%S*)")
        local arm, err = P.Measure(token)
        if not arm then
            if err == "no experiment" then
                return print("start one first \226\128\148 `/at perf start`")
            end
            return print(("unknown window '%s' \226\128\148 use `measure a` or `measure b`")
                :format(token ~= "" and token or "?"))
        end
        print(("Experiment |cFFFFFF00%s|r |cffffff00ARMED|r (%s) \226\128\148 recording starts when "
            .. "combat does, and ends when combat does"):format(token:upper(),
            arm == "suspended" and "addon |cffff4040SUSPENDED|r" or "addon |cff40ff40active|r"))
    end,

    finish = function(P)
        if not P.run then return print("no perf run is active \226\128\148 `/at perf start`") end
        local record = P.Stop()
        P.Save(record)
        emitPerfLines(P.FormatReport(record))
        P.__announce("perf run |cffff4040FINISHED|r \226\128\148 saved; `/reload` to flush it to "
            .. "SavedVariables")
        -- Leaving suspend on after a capture would silently disable the addon for the rest of the
        -- session, and nobody expects `off` to leave anything switched off but the capture itself.
        if P.suspended then
            P.Resume()
            print("perf suspend lifted \226\128\148 bars restored")
        end
    end,

    report = function(P)
        emitPerfLines(P.FormatReport(P.BuildRecord(P.label)))
    end,

    dump = function(P)
        local json = P.EncodeJSON(P.BuildRecord(P.label))
        if not (NS.DebugLog and NS.DebugLog.Add) then return print(json) end
        NS.DebugLog:Add("Perf", json)
        if NS.DebugLog.ShowCopy then NS.DebugLog:ShowCopy() end
    end,

    suspend = function(P)
        if P.Suspend() then
            print("addon |cffff4040SUSPENDED|r \226\128\148 inert until `/at perf resume` or /reload")
        else
            print("already suspended")
        end
    end,

    resume = function(P)
        if P.Resume() then
            print("addon |cff40ff40RESUMED|r")
        else
            print("not suspended")
        end
    end,
}

-- Bare `/at perf`, and the fallback for anything unrecognised.
local function printPerfStatus(P)
    local phase = "|cffff4040stopped|r"
    if P.recording then
        phase = ("|cff40ff40SAMPLING window %s|r"):format(P.recording)
    elseif P.armed then
        phase = ("|cffffff00window %s armed|r \226\128\148 waiting for combat"):format(P.armed)
    elseif P.run then
        phase = "|cffffff00run active|r \226\128\148 no experiment armed"
    end
    print(("perf %s, addon %s"):format(phase,
        P.suspended and "|cffff4040SUSPENDED|r" or "|cff40ff40active|r"))
    for _, line in ipairs(PERF_USAGE) do print(line) end
end

function runPerf(rest)
    rest = rest or ""
    local sub = rest:match("^(%S*)"):lower()
    local P = NS.Perf
    return (PERF_SUBS[sub] or printPerfStatus)(P, rest:match("^%S*%s+(.*)$"))
end

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

-- ---------------------------------------------------------------------
-- /at toggle [unit]
-- ---------------------------------------------------------------------
--
-- Bare: flips EVERY bar at once — off if any is currently on, otherwise all on. That asymmetry is
-- deliberate: a plain flip of each unit independently would invert the user's mix (player on,
-- target off becomes player off, target on), which is not what "toggle the bars" means to anyone.
--
-- With a unit token: flips that one unit only, leaving the others alone.
--
-- Both write through NS.SetByPath, so the enable row's onChange fires exactly as it does from the
-- panel checkbox — publishing UNITS (re-syncing event registrations), APPEARANCE and REPAINT.
-- The CLI and the checkbox therefore can never drift onto different code paths.
function runToggle(rest)
    local token = (rest or ""):match("^(%S*)"):lower()

    if token ~= "" then
        if not NS.Units.LABEL[token] then
            local names = table.concat(NS.Units.LIST, ", ")
            return print(("unknown unit '%s' \226\128\148 expected one of: %s"):format(token, names))
        end
        local on = not NS.Units.IsEnabled(token)
        NS.SetByPath("units." .. token .. ".enabled", on)
        return print(("%s bar %s"):format(NS.Units.LABEL[token], on and "shown" or "hidden"))
    end

    local anyEnabled = false
    for _, unit in ipairs(NS.Units.LIST) do
        if NS.Units.IsEnabled(unit) then anyEnabled = true break end
    end
    local on = not anyEnabled
    for _, unit in ipairs(NS.Units.LIST) do
        NS.SetByPath("units." .. unit .. ".enabled", on)
    end
    print(on and "All bars shown" or "All bars hidden")
end

function runUpdate()
    NS.bus:SendMessage(NS.MSG.REPAINT)
    print("Forced refresh")
end

function runTest(rest)
    local args = {}
    for w in (rest or ""):gmatch("%S+") do args[#args + 1] = w end
    local n    = tonumber(args[1]) or 50000
    local hold = tonumber(args[2]) or 5

    -- Nothing to paint if every bar is off. Checks `enabled` per unit rather than a master
    -- toggle — there is no `hidden` global any more (schema v4).
    local anyEnabled = false
    for _, unit in ipairs(NS.Units.LIST) do
        if NS.Units.IsEnabled(unit) then anyEnabled = true break end
    end
    if not anyEnabled then
        print("Every bar is disabled; run /at toggle to turn them on before testing")
        return
    end

    print(("Testing display with value: %s for %d s"):format(AbbreviateNumbers(n), hold))
    for _, unit in ipairs(NS.Units.LIST) do
        local bar = NS.bars[unit]
        if bar and NS.ShouldShowBar(unit) then
            bar.valueText:SetText(AbbreviateNumbers(n))
            bar.statusBar:SetMinMaxValues(0, math.max(n, 100000))
            bar.statusBar:SetValue(n)
        end
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
