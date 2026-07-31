local addonName, NS = ...
NS.Slash = NS.Slash or {}
local Sl = NS.Slash

-- Schema-driven slash dispatcher registered via AceConsole (Ka0s standard §7.1 — no hand-rolled
-- SLASH_* globals). /at list, /at get and /at set walk NS.Schema directly, so adding an option is
-- one schema row (in some settings/<page>.lua) and the slash surface picks it up automatically.
--
-- NS.COMMANDS is an ordered {name, desc, fn} table; the help block and the About page both iterate
-- it, so they stay in lockstep with the dispatcher.
--
-- The dispatcher, the help renderer, the key/value formatters, the list builder and the type-aware
-- value parser are LibKa0s-Slash-1.0 (libs/LibKa0s/Slash.lua), shared across every Ka0s addon. What
-- stays here is what is genuinely ours: the verb table, the host verbs that reach into this addon's
-- own state, and the mirror note.
--
-- NS.COMMANDS is passed INTO the library rather than owned by it. The About page renders the same
-- table, so a library that owned it would force the options library to consume this one, and two
-- libraries reaching for each other is a real dependency cycle.

local print = NS.Print

-- The dispatcher, the help renderer, the formatters, the list builder and the parser.
local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
-- Built at the bottom of this file, once NS.COMMANDS exists to pass in. Every handler below
-- reaches it at CALL time, which is why a forward-declared local is enough.
local cli

-- Help row formatter — gold command + em-dash + white description. The coloring and the spacing
-- are the library's one formatter; the two-space indent belongs to this renderer, because a chat
-- line sits under a header and a settings-panel label does not.
local function PrintCmd(cmd, desc)
    print("  " .. SlashLib.FormatRow(cmd, desc))
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
-- Only appearance rows are annotated. `enabled` and `mirror` carry alwaysPerUnit and are honored
-- per-unit even while mirrored, so a note on them would be a lie. Gray (808080) keeps it visually
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
    {"reset",        "Reset one setting to its default \226\128\148 `/at reset <path>`",
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

-- ---------------------------------------------------------------------
-- /at help
-- ---------------------------------------------------------------------

function getVersion()
    return NS.Compat.GetAddOnMetadata(NS.name, "Version") or NS.version or "?"
end

function printHelp() cli:PrintHelp() end

-- ---------------------------------------------------------------------
-- Schema-driven /at list / /at get / /at set
-- ---------------------------------------------------------------------

-- Page order for /at list grouping. Profiles is omitted (its schema is supplied by AceDBOptions).
local PAGE_ORDER = { "general", "bar", "border", "font" }
-- Which pages carry per-unit rows and therefore list once per unit.
local PER_UNIT_PAGES = { general = false, bar = true, border = true, font = true }

-- The three schema verbs are the library's: it walks the rows, formats the key/value pairs, parses
-- the typed value and re-reads what was stored so a clamp is visible. What stays ours is WHICH rows
-- exist and in what order, and the mirror note appended to each — both handed over as descriptor
-- functions below.

function listSettings() cli:CliList() end
function getSetting(rest) cli:CliGet(rest) end
function setSetting(rest) cli:CliSet(rest) end

--- Every schema row, in the order /at list should print them: page by page, and for a per-unit
--- page once per unit. The library groups on whatever key it is given and preserves this order, so
--- the listing still matches the panel's page order rather than the schema's declaration order.
local function allRows()
    local out = {}
    local function add(rows)
        for _, row in ipairs(rows) do out[#out + 1] = row end
    end
    for _, page in ipairs(PAGE_ORDER) do
        if PER_UNIT_PAGES[page] then
            for _, unit in ipairs(NS.Units.LIST) do add(NS.SchemaForPage(page, unit)) end
        else
            add(NS.SchemaForPage(page))
        end
    end
    return out
end


-- ---------------------------------------------------------------------
-- /at reset / /at resetall / /at resetposition
-- ---------------------------------------------------------------------

-- `/at reset <path>` resets ONE setting, which is the shape the whole collection uses. The
-- page-shaped form this addon used to carry is gone: a page is a property of a settings panel,
-- and every schema-driven page already has a Defaults button that resets it across every unit.
-- That path is untouched — see NS.Helpers.RestoreDefaults and tests/test_helpers.lua.
function runReset(rest) cli:CliReset(rest) end


function runResetAll()
    -- Delegate to the single shared helper so the slash command and the
    -- "Reset All Settings" popup can never diverge — same rows reset,
    -- same position clear + recenter, same panel refresh.
    -- The acknowledgement lives INSIDE the guard, for the reason runResetPosition spells out
    -- below: on a load where settings/OptionsSetup.lua never ran there is nothing to delegate to,
    -- and printing the ack anyway would claim success for work that did not happen.
    if NS.Helpers and NS.Helpers.RestoreAllDefaults then
        NS.Helpers.RestoreAllDefaults()
        print("All settings reset to defaults")
    else
        print("Cannot reset settings \226\128\148 the settings helpers failed to load")
    end
end

function runResetPosition()
    -- Delegate to the single shared helper so this verb and the General page's "Reset Position"
    -- button can never diverge — same per-unit clear, same POSITION publish.
    -- The acknowledgement lives INSIDE the guard: printing it unconditionally would claim success
    -- on a load where settings/UnitPanel.lua never ran — the same silent-lie shape as the Reset
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

-- The whole guided run lives in LibKa0s-Perf; this is only the dispatch. The lib deliberately
-- registers no slash command of its own (slash-commands-§: every verb goes through this table with
-- the cyan tag), so it hands back lines and we print them.
function runPerf(rest)
    for _, line in ipairs(NS.Perf.OnCommand(rest or "")) do print(line) end
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

-- A missing vendored lib must degrade, not error at load. `/at` is registered unconditionally, so
-- something has to answer it. Note what is NOT here: no copy of the row formatter, no copy of the
-- parser, no copy of the key/value shape. Hand-copying the strings whose drift the extraction
-- exists to end is the one duplicate testing-§8 most specifically forbids, so a degraded help row
-- renders plainly and says so instead.
--
-- The host verbs never went to the library, so they keep working untouched. What is lost is the
-- schema CLI, and each of those verbs names the missing library rather than going quiet.
if not SlashLib then
    local missing = " is unavailable: the LibKa0s library is missing from this installation of " ..
        "Absorb Tracker (expected in libs/LibKa0s)."
    SlashLib = { FormatRow = function(cmd, desc) return cmd .. " \226\128\148 " .. desc end }

    function SlashLib:New(d)
        local stub = { SetRowAnnotator = function() end }
        local function absent(verb)
            return function() print("/at " .. verb .. missing) end
        end
        for _, verb in ipairs({ "List", "Get", "Set", "Reset", "ResetAll" }) do
            stub["Cli" .. verb] = absent(verb:lower())
        end
        stub.CliVersion  = function() print(("v%s"):format(d.version())) end
        stub.LandingRows = function()
            local out = {}
            for _, e in ipairs(d.commands) do
                out[#out + 1] = SlashLib.FormatRow("/at " .. e[1], e[2])
            end
            return out
        end
        stub.PrintHelp = function()
            print(("v%s \226\128\148 slash commands"):format(d.version()))
            for _, row in ipairs(stub.LandingRows()) do print("  " .. row) end
        end
        stub.OnSlash = function(_, msg)
            local raw = (msg or ""):match("^%s*(.-)%s*$") or ""
            if raw == "" then return stub.PrintHelp() end
            local cmd, rest = raw:match("^(%S+)%s*(.*)$")
            cmd = (cmd or ""):lower()
            cmd = (d.aliases or {})[cmd] or cmd
            for _, e in ipairs(d.commands) do
                if e[1] == cmd then return e[3](rest or "") end
            end
            print("unknown command '" .. cmd .. "'")
            stub.PrintHelp()
        end
        return stub
    end
end

-- Build the dispatcher now that NS.COMMANDS exists. The table is passed IN, not owned: the About
-- page renders the same one, and a library that owned it would drag the options library into
-- depending on this one.
cli = SlashLib:New({
    slash        = "/at",
    slashAliases = { "/absorbtracker" },
    commands     = NS.COMMANDS,
    aliases      = { options = "config" },   -- backward-compat: `/at options` -> `/at config`

    print   = function(line) print(line) end,
    version = getVersion,

    -- The schema seams. SetByPath rather than a bare write, so a CLI change takes the same path a
    -- panel change does: the [Set] debug line, the row's onChange, and the panel refresh.
    get          = function(path) return NS.GetSetting(path) end,
    set          = function(path, v)
        NS.SetByPath(path, v)
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    end,
    findRow      = function(path) return NS.FindSchemaRow(path) end,
    applyDefault = function(row)
        NS.ApplyDefault(row)
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    end,
    allRows      = allRows,

    -- `[bar / player]` for a per-unit page, a bare `[general]` otherwise.
    groupKey = function(row)
        if row.unit and PER_UNIT_PAGES[row.page] then return row.page .. " / " .. row.unit end
        return row.page
    end,
})

-- The mirror note is ours, not the library's: it reads NS.Units.IsMirrored and the row's
-- alwaysPerUnit flag, neither of which a generic dispatcher knows about. The library decides only
-- WHERE an annotation may appear — after the colored pair, on list/get/set and never on a reset.
cli:SetRowAnnotator(MirrorNote)

--- The command list the About page renders. Same coloring and spacing as `/at help`, without the
--- chat indent: each row there is its own label, where a leading indent reads as a mistake.
function Sl:LandingRows() return cli:LandingRows() end

function Sl:OnSlash(msg)
    cli:OnSlash(msg)
end


function Sl:Register()
    NS.addon:RegisterChatCommand("at", function(msg) Sl:OnSlash(msg) end)
    NS.addon:RegisterChatCommand("absorbtracker", function(msg) Sl:OnSlash(msg) end)
end
