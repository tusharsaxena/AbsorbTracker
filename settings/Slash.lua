local _, NS = ...
NS.Slash = NS.Slash or {}
local Sl = NS.Slash

-- Schema-driven slash dispatcher registered via AceConsole (Ka0s standard slash-commands-§1 — no hand-rolled
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

-- The disabled line's format, the ONE library string the library-absent stub below carries, and it
-- carries it verbatim: these are the bytes of LibKa0s-Slash-1.0's `lib.DISABLED_LINE_FORMAT`
-- (v1.56.0), em dash spelled as the library spells it. slash-commands-§1 sanctions exactly this
-- copy and requires the pin beside it: tests/test_slashcmds.lua compares it against the live
-- library with Kit.assertLibraryConstant, so a re-worded library line turns the suite red instead
-- of leaving a stale sentence behind. Published as a suite seam; nothing in the addon reads it.
local STUB_DISABLED_LINE_FORMAT = "%s is disabled \226\128\148 enable it with |cFFFFFF00%s|r"
Sl.__STUB_DISABLED_LINE_FORMAT = STUB_DISABLED_LINE_FORMAT

-- Help row formatter — gold command + em-dash + white description. The coloring and the spacing
-- are the library's one formatter; the two-space indent belongs to this renderer, because a chat
-- line sits under a header and a settings-panel label does not. With the library absent there is
-- no formatter to borrow and none is copied (slash-commands-§1), so the row renders plainly.
local function PrintCmd(cmd, desc)
    print("  " .. (SlashLib.FormatRow and SlashLib.FormatRow(cmd, desc) or (cmd .. "  " .. desc)))
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
local runDebug, runUpdate, runProfile, runToggle, runPerf
local setEnabled, echoStored, runHold

NS.COMMANDS = {
    {"help",          "List available commands",
        function() printHelp() end},
    {"config",        "Open the settings panel",
        function() NS.OpenOptionsPanel() end},
    -- THE RESERVED PAIR (slash-commands-§2), and ALIASES rather than a second switch: both write
    -- the `enabled` path the Master controls tab's `Enable Absorb Tracker` checkbox writes, through
    -- the same NS.SetByPath seam, so the checkbox and the verbs can never show two answers.
    --
    -- Listed HERE, second and third, rather than down beside `lock`/`toggle`. The player most
    -- likely to be reading `/at help` at all is the one who just turned the addon off and wants it
    -- back, and a recovery verb below eleven others is a recovery verb they scroll past.
    {"enable",        "Turn the addon on",
        function() setEnabled(true) end},
    {"disable",       "Turn the addon off \226\128\148 `/at enable` turns it back on",
        function() setEnabled(false) end},
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
    -- The echo is the STORED value, not the argument: the locked row's onChange refuses an unlock in
    -- combat and writes true back, and a fixed "unlocked" line would contradict it (slash-commands-§8).
    {"lock",          "Lock the bars in place",
        function()
            NS.SetByPath("locked", true)
            echoStored("locked")
        end},
    {"unlock",        "Unlock the bars so they can be dragged",
        function()
            NS.SetByPath("locked", false)
            echoStored("locked")
        end},
    {"toggle",        "Toggle bars on or off \226\128\148 `/at toggle [player|target|focus]`",
        function(rest) runToggle(rest) end},
    {"debug",         "Toggle the debug console \226\128\148 `on`/`off` logging, `events`, `hold <value> [secs]`",
        function(rest) runDebug(rest) end},
    {"perf",          "Measure performance \226\128\148 try `/at perf` for the workflow",
        function(rest) runPerf(rest) end},
    {"update",        "Force a bar refresh",
        function() runUpdate() end},
    {"version",       "Print the addon version",
        function() print(("v%s"):format(NS.Version())) end},
    {"profile",       "Profile management \226\128\148 try `/at profile` for the list",
        function(rest) runProfile(rest) end},
}

-- ── the disabled gate lives in the LIBRARY now (slash-commands-§2, §7) ───────────────────
--
-- THIS FILE USED TO CARRY THE GATE, as a loop that wrapped every handler not named in a local
-- ALWAYS_LIVE table, and a refusal line of its own routed through NS.L. Both are gone, and the
-- deletion is the adoption rather than a simplification: LibKa0s-Slash-1.0 minor 12 grew the gate
-- and minor 14 (LibKa0s v1.42.0) settled what it refuses, so the wrapper here was a second implementation of a rule
-- the dispatcher now applies -- and a second wording of the one line the whole collection says.
--
-- WHAT MOVED, EXACTLY. The descriptor at the foot of this file gains `isEnabled`, `brandName` and
-- `liveVerbs`, and the library does the rest at DISPATCH time:
--
--   * every one of slash-commands-§2's thirteen reserved verbs answers normally while disabled, and
--     so does the bare `/at`, which runs `config` and opens the settings panel. That is the case
--     that settled it: a player reaches for the panel precisely when the addon is off, and the
--     narrowing that refused it (standard v2.56.0, Slash minor 12) was reversed the same day.
--   * this addon's own FEATURE verbs -- `lock`, `unlock`, `toggle`, `update` -- get ONE tagged line
--     naming `/at enable` and reach no seam. §2's SHOULD, and this addon takes it. `debug` is live,
--     but its `hold` sub-verb paints the bars, so runHold asks the same question and prints the
--     same line itself.
--   * a TYPO still gets `unknown command` and the index, because the addon did not understand it;
--     the gate sits after the COMMANDS lookup, which is what tells the two cases apart.
--
-- THE WORDING IS NOT OURS AND IS NO LONGER ROUTED THROUGH NS.L. `lib.DISABLED_LINE_FORMAT` is the
-- one spelling for eleven addons; a translated override here would give a player running four of
-- them four different answers to the same question. The NS.L seam is unchanged and still exists --
-- what left it is a key nothing reads any more (localization-§3).

-- ---------------------------------------------------------------------
-- /at help
-- ---------------------------------------------------------------------

function printHelp() cli:PrintHelp() end

-- ---------------------------------------------------------------------
-- Schema-driven /at list / /at get / /at set
-- ---------------------------------------------------------------------

-- Page order for /at list grouping. Profiles is omitted (its schema is supplied by AceDBOptions).
local PAGE_ORDER = { "general", "appearance" }
-- Which pages carry per-unit rows and therefore list once per unit.
local PER_UNIT_PAGES = { general = false, appearance = true }

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
    -- same profile reset, same panel refresh.
    -- The acknowledgment lives INSIDE the guard, for the reason runResetPosition spells out
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
    -- The acknowledgment lives INSIDE the guard: printing it unconditionally would claim success
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
-- /at debug / /at update
-- ---------------------------------------------------------------------
--
-- /at debug        toggles the on-screen debug console window (state unchanged).
-- /at debug on|off enables / disables session logging (debug-logging-§5).
-- /at debug events lists the event names the client refused this session.
-- /at debug hold <value> [secs] holds a fake absorb value on the bars (below).

-- The whole guided run lives in LibKa0s-Perf; this is only the dispatch. The lib deliberately
-- registers no slash command of its own (slash-commands-§3: every verb goes through this table with
-- the cyan tag), so it hands back lines and we print them.
function runPerf(rest)
    for _, line in ipairs(NS.Perf.OnCommand(rest or "")) do print(line) end
end

local function setDebugLogging(on)
    if NS.DebugLog and NS.DebugLog.SetEnabled then
        NS.DebugLog:SetEnabled(on)
    elseif NS.State then
        NS.State.debug = on
    end
end

-- `/at debug events`: every event name the client refused this session (events-frames-taint-§1),
-- as the SafeRegister helpers recorded it in NS.State.rejectedEvents (core/AbsorbTracker.lua).
local function printRejectedEvents()
    local list = NS.State and NS.State.rejectedEvents
    if type(list) ~= "table" or #list == 0 then
        print("Rejected events: none")
    else
        print("Rejected events: " .. table.concat(list, ", "))
    end
end

-- `/at debug hold <value> [secs]` paints that value on every visible bar and holds it for a few
-- seconds. It is a DIAGNOSTIC, not a visibility switch: it fakes an absorb amount so the bar's text,
-- fill and abbreviation can be eyeballed without waiting for a real shield.
--
-- It used to be the top-level `test <value> [secs]` verb. This addon's unlocked view is its
-- preview, and options-ui-§15 and preview-mode say an addon in that shape ships no `test` verb
-- (anti-pattern #80): `/at unlock` and `/at lock` are the switch. The value hold answers a
-- different question, so it stays, under `debug`, which is where the standard puts a kept
-- one-shot hold.
--
-- The duration is validated rather than passed through: -3 used to be announced as "-3 s" and
-- handed to AceTimer, which clamps it to almost nothing, and `%d` announced 2.5 as "2 s".
local HOLD_USAGE = "Usage: /at debug hold <value> [secs] \226\128\148 secs from 0.5 to 60, default 5"
local HOLD_MIN, HOLD_MAX, HOLD_DEFAULT = 0.5, 60, 5

--- The value and the seconds from `/at debug hold`'s arguments, or nil when either is unusable.
--- A word after the seconds is ignored. The range test is written as `not (min <= secs <= max)`
--- so that a NaN, which compares false with everything, is refused rather than slipping past two
--- `<`/`>` checks.
local function parseHold(rest)
    local first, second = (rest or ""):match("^(%S*)%s*(%S*)")
    local n = tonumber(first)
    local secs = HOLD_DEFAULT
    if second ~= "" then secs = tonumber(second) end
    if not n or n ~= n or not secs then return nil end
    if not (secs >= HOLD_MIN and secs <= HOLD_MAX) then return nil end
    return n, secs
end

local function paintHold(n)
    for _, unit in ipairs(NS.Units.LIST) do
        local bar = NS.bars[unit]
        if bar and NS.ShouldShowBar(unit) then
            bar.valueText:SetText(AbbreviateNumbers(n))
            bar.statusBar:SetMinMaxValues(0, math.max(n, 100000))
            bar.statusBar:SetValue(n)
        end
    end
end

function runHold(rest)
    -- `debug` is a live verb (slash-commands-§2), so the library's gate never sees this one. A hold
    -- paints the bars, which is a feature, so it refuses on the collection's one line itself.
    if NS.GetSetting("enabled") == false then return print(Sl:DisabledLine()) end

    local n, secs = parseHold(rest)
    if not n then return print(HOLD_USAGE) end

    -- Nothing to paint if every bar is off. Checks `enabled` per unit rather than a master
    -- toggle — there is no `hidden` global any more (schema v4).
    local anyEnabled = false
    for _, unit in ipairs(NS.Units.LIST) do
        if NS.Units.IsEnabled(unit) then anyEnabled = true break end
    end
    if not anyEnabled then
        return print("Every bar is disabled; run /at toggle to turn them on before testing")
    end

    print(("Holding %s on the bars for %s s"):format(AbbreviateNumbers(n), ("%g"):format(secs)))
    paintHold(n)
    -- Honors the duration just announced: NS.HoldPreview arms a one-shot that clears the hold and
    -- republishes REPAINT at expiry (modules/Display.lua).
    NS.HoldPreview(secs)
end

-- The sub-verbs `/at debug` takes; anything else (including nothing) toggles the console window.
-- Each handler gets the rest of the line after its sub-verb.
local DEBUG_VERBS = {
    on     = function() setDebugLogging(true) end,
    off    = function() setDebugLogging(false) end,
    events = printRejectedEvents,
    hold   = function(rest) runHold(rest) end,
}

function runDebug(rest)
    local sub, subrest = (rest or ""):match("^(%S*)%s*(.*)$")
    local handler = DEBUG_VERBS[(sub or ""):lower()]
    if handler then
        handler(subrest)
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

-- ── /at enable | /at disable ───────────────────────────────────────────────────
--
-- NO STATE OF THEIR OWN (slash-commands-§2): no second key, no session flag, no `NS.enabled` local.
-- The one write goes through NS.SetByPath, which is the seam the Master-controls checkbox,
-- `/at set enabled true` and the Defaults button all go through, so the row's `onChange` --
-- NS.SyncEnabledHold (settings/General.lua) -- runs whichever surface was used.
--
-- WHAT *DISABLED* MEANS HERE (slash-commands-§7). NS.SyncEnabledHold moves the `disabled` hold on
-- the one stand-down latch (core/Lifecycle.lua). On the edge the latch runs StandDown, which
-- unregisters the three per-unit event frames, the five AceEvent registrations and the internal
-- bus, so the addon stops watching rather than merely stops drawing. What StandDown leaves alone
-- is SETUP, not a feature: the dispatcher (registered unconditionally in OnInitialize), the
-- COMMANDS table and the settings registration. That is what keeps the pair from being one-way --
-- `/at`, `/at enable`, `/at help` and `/at config` all still answer with the addon off, which
-- slash-commands-§2 makes a MUST because the alternative strands a player in a settings panel they
-- were trying not to open. tests/test_slashcmds.lua pins it.
function setEnabled(on)
    NS.SetByPath("enabled", on)
    echoStored("enabled")
end

-- The one confirmation line for a verb that writes a schema path (slash-commands-§8): refresh an
-- open panel so its widget moves with the verb, then print slash-commands-§5's `set` shape, read
-- back from the STORE rather than from the argument -- an onChange that refused or coerced the
-- write is what the player is told about. Same formatter `/at get` and the [Set] debug line use.
-- The colored pair is the library's; with the library absent it renders plainly, exactly as the
-- degraded help rows do, rather than this file carrying a second copy of the color codes
-- (testing-§8).
function echoStored(path)
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    local row    = NS.FindSchemaRow(path)
    local stored = NS.GetSetting(path)
    local value  = row and NS.FormatSchemaValue(row, stored) or tostring(stored)
    print(SlashLib.FormatKV and SlashLib.FormatKV(path, value) or (path .. " = " .. value))
end

function runUpdate()
    NS.bus:SendMessage(NS.MSG.REPAINT)
    print("Forced refresh")
end

-- ---------------------------------------------------------------------
-- /at profile
-- ---------------------------------------------------------------------

-- The sub-help rows, in the order they print. One row per sub-verb, and the order is the contract.
local PROFILE_HELP = {
    { "list",            "List all profiles" },
    { "current",         "Show current profile name" },
    { "use <name>",      "Switch to profile" },
    { "new <name>",      "Create new profile with defaults" },
    { "copy <name>",     "Copy settings from another profile" },
    { "delete <name>",   "Delete a profile" },
    { "reset",           "Reset current profile to defaults" },
}

local function printProfileHelp()
    print("Profile commands")
    for _, row in ipairs(PROFILE_HELP) do
        PrintCmd("/at profile " .. row[1], row[2])
    end
end

-- The four name-taking verbs share one guard: no name means print that verb's own Usage line and
-- do nothing. Wrapping is done once at file load, so a dispatch allocates nothing.
local function needsName(verb, fn)
    return function(db, name)
        if name == "" then
            return print("Usage: /at profile " .. verb .. " <name>")
        end
        return fn(db, name)
    end
end

-- True when `name` is one of the stored profiles. Exact and case-sensitive, as AceDB names are.
-- new, copy and delete check the name here first, so AceDB never sees a name it would raise on
-- (CopyProfile) or silently ignore (DeleteProfile).
local function profileExists(db, name)
    for _, existing in ipairs(db:GetProfiles()) do
        if existing == name then return true end
    end
    return false
end

local function printNotFound(name)
    print("Profile '" .. name .. "' not found \226\128\148 /at profile list shows them")
end

-- The sub-verb table, keyed by the lowercased verb. Built once at load.
local PROFILE_VERBS = {
    list = function(db)
        print("Available profiles")
        local current = db:GetCurrentProfile()
        for _, name in ipairs(db:GetProfiles()) do
            local marker = (name == current) and " (current)" or ""
            print("  " .. name .. marker)
        end
    end,

    current = function(db)
        print("Current profile: " .. db:GetCurrentProfile())
    end,

    use = needsName("use", function(db, name)
        db:SetProfile(name)
        print("Switched to profile '" .. name .. "'")
    end),

    -- `new` only ever makes a profile: an existing name is refused, never switched to and reset,
    -- because that would wipe it on one typed command. SetProfile first, THEN ResetProfile, so the
    -- reset lands on the new profile, not the one being left behind. The reset is counted
    -- (NS.ResetProfileCounted), so OnProfileReset's line reads `(0 rows)` for the fresh profile
    -- (debug-logging-§10).
    new = needsName("new", function(db, name)
        if profileExists(db, name) then
            return print("Profile '" .. name .. "' already exists \226\128\148 /at profile use "
                .. name .. " switches to it, /at profile reset resets it")
        end
        db:SetProfile(name)
        NS.ResetProfileCounted(db)
        print("Created and switched to new profile '" .. name .. "'")
    end),

    -- AceDB's CopyProfile raises on the current or a missing name, so both are refused first.
    copy = needsName("copy", function(db, name)
        if name == db:GetCurrentProfile() then
            return print("Cannot copy a profile onto itself")
        end
        if not profileExists(db, name) then return printNotFound(name) end
        db:CopyProfile(name)
        print("Copied settings from profile '" .. name .. "'")
    end),

    delete = needsName("delete", function(db, name)
        if name == db:GetCurrentProfile() then
            return print("Cannot delete the current profile")
        end
        if not profileExists(db, name) then return printNotFound(name) end
        db:DeleteProfile(name, true)   -- silent: we print our own line
        print("Deleted profile '" .. name .. "'")
    end),

    reset = function(db)
        NS.ResetProfileCounted(db)
        print("Profile reset to defaults")
    end,
}

function runProfile(rest)
    local db = NS.db
    if not db or not db.SetProfile then
        return print("Profile system requires AceDB-3.0")
    end

    -- Only the VERB is lowercased. The argument keeps its case — AceDB profile names are
    -- case-sensitive, and folding one would address the wrong profile.
    local sub, subarg = (rest or ""):match("^(%S*)%s*(.*)$")
    sub = (sub or ""):lower()

    if sub == "" then return printProfileHelp() end

    local handler = PROFILE_VERBS[sub]
    if not handler then
        print("Unknown profile subcommand '" .. sub .. "'")
        return printProfileHelp()
    end
    return handler(db, subarg)
end

-- ---------------------------------------------------------------------
-- Registration + dispatch (AceConsole)
-- ---------------------------------------------------------------------

-- A missing vendored lib must degrade, not error at load. `/at` is registered unconditionally, so
-- something has to answer it. The stub takes the shape slash-commands-§1 prescribes: no copy of
-- the row formatter, no copy of the parser, no copy of the key/value shape. Hand-copying the
-- strings whose drift the extraction exists to end is the duplicate testing-§8 forbids, so a
-- degraded help row renders plainly (`/at list  List every setting ...`). The single library string
-- it does carry is the disabled line's format, verbatim and pinned (STUB_DISABLED_LINE_FORMAT).
--
-- The host verbs never went to the library, so they keep working untouched. What is lost is the
-- schema CLI, and each of those verbs prints the collection's library-absent line through the
-- locale (keyed by its English text, localization-§2) rather than going quiet.
if not SlashLib then
    SlashLib = {}

    function SlashLib:New(d)
        local stub = { SetRowAnnotator = function() end }
        -- The one line a disabled addon says, and the degraded arm has to be able to say it:
        -- runHold (`/at debug hold`, above) calls this member directly on a disabled addon, and a
        -- nil there would raise on the verb rather than refuse it.
        --
        -- The SAME line the library builds, color escapes and all: the stub formats the library's
        -- verbatim format string (STUB_DISABLED_LINE_FORMAT, pinned by the suite) with the same two
        -- arguments the library's DisabledLine passes. slash-commands-§1 sanctions this one copy.
        stub.DisabledLine = function()
            return STUB_DISABLED_LINE_FORMAT:format(NS.Constants.BRAND, "/at enable")
        end
        local function absent(verb)
            return function() print(NS.L["%s is unavailable: the LibKa0s library did not load."]:format("/at " .. verb)) end
        end
        for _, verb in ipairs({ "List", "Get", "Set", "Reset", "ResetAll" }) do
            stub["Cli" .. verb] = absent(verb:lower())
        end
        stub.LandingRows = function()
            local out = {}
            for _, e in ipairs(d.commands) do
                out[#out + 1] = "/at " .. e[1] .. "  " .. e[2]
            end
            return out
        end
        stub.PrintHelp = function()
            print(("v%s \226\128\148 slash commands"):format(d.version()))
            for _, row in ipairs(stub.LandingRows()) do print("  " .. row) end
        end
        local function find(name)
            for _, e in ipairs(d.commands) do
                if e[1] == name then return e end
            end
        end
        stub.OnSlash = function(_, msg)
            local raw = (msg or ""):match("^%s*(.-)%s*$") or ""
            -- Bare /at runs the host's `config` verb, as the library does (slash-commands-§4);
            -- help is only the fallback for a descriptor that registered none.
            if raw == "" then
                local config = find("config")
                if config then return config[3]("") end
                return stub.PrintHelp()
            end
            local cmd, rest = raw:match("^(%S+)%s*(.*)$")
            cmd = (cmd or ""):lower()
            cmd = (d.aliases or {})[cmd] or cmd
            local e = find(cmd)
            if e then return e[3](rest or "") end
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
    version = NS.Version,

    -- ── the disabled gate ──────────────────────────────────────────────────────
    --
    -- Asked at DISPATCH time and never cached, which is what makes the command straight after an
    -- `/at enable` work. It reads the STORE, not the latch: `enabled` has no state of its own
    -- (slash-commands-§2), and a read of the perf hold here would refuse a player's feature verb
    -- mid-capture with a line telling them to enable an addon they never disabled.
    isEnabled = function() return NS.GetSetting("enabled") ~= false end,

    -- The plain-text brand name the refusal line is about, and the SAME string the LDB object
    -- carries as `label` (core/Constants.lua). launcher-§1 forbids escape sequences in that field,
    -- which is exactly what makes it safe to drop into a colored line.
    brandName = NS.Constants.BRAND,

    -- §2's thirteen, PLUS two this addon argues for -- and built FROM the library's own array
    -- rather than re-typed, so a new reserved verb arrives here by re-vendoring instead of by
    -- someone remembering. That is how `diagnostics` (debug-logging-§14, Slash minor 16, LibKa0s
    -- v1.60.0) joined the list: no edit here. Re-typing the thirteen is how a host ends up quietly
    -- narrowing the surface it meant to keep.
    --
    --   `resetposition`  is `reset` for the one piece of stored state no schema row addresses
    --                    (`units.<unit>.position`, architecture-§5's named non-setting state).
    --                    Refusing it would withhold from a bar's anchor the repair the schema CLI
    --                    guarantees for every value beside it, purely over where that anchor lives.
    --   `profile`        is settings management -- list, switch, copy, create, delete, reset. A
    --                    player who turned the addon off to get out from under a broken profile is
    --                    exactly the player who needs to switch away from it.
    --
    -- Everything NOT here is gated by default, which is the polarity that matters: a verb added to
    -- NS.COMMANDS tomorrow refuses while disabled until someone argues it onto this list.
    liveVerbs = (function()
        local out = {}
        for _, verb in ipairs(SlashLib.LIVE_VERBS or {}) do out[#out + 1] = verb end
        out[#out + 1] = "resetposition"
        out[#out + 1] = "profile"
        return out
    end)(),

    -- The schema seams. SetByPath rather than a bare write, so a CLI change takes the same path a
    -- panel change does: the [Set] debug line, the row's onChange, and the panel refresh.
    get          = function(path) return NS.GetSetting(path) end,
    set          = function(path, v)
        NS.SetByPath(path, v)
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    end,
    findRow      = NS.SchemaRuntime.FindRow,
    applyDefault = function(row)
        NS.ApplyDefault(row)
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    end,
    allRows      = allRows,

    -- `[appearance / player]` for a per-unit page, a bare `[general]` otherwise.
    groupKey = function(row)
        if row.unit and PER_UNIT_PAGES[row.page] then return row.page .. " / " .. row.unit end
        return row.page
    end,
})

-- The mirror note is ours, not the library's: it reads NS.Units.IsMirrored and the row's
-- alwaysPerUnit flag, neither of which a generic dispatcher knows about. The library decides only
-- WHERE an annotation may appear — after the colored pair, on list/get/set and never on a reset.
cli:SetRowAnnotator(MirrorNote)

-- The dispatcher itself, published for introspection under the same `__` convention the options
-- helpers use (Helpers.__panels, Helpers.__pages). Nothing in the addon calls through it — the two
-- wrappers below are the seam every caller uses — but the degraded arm's stub and the library's
-- instance are otherwise both file-scope locals, and a stub surface that cannot be reached cannot
-- be compared. tests/test_surface_parity.lua is the only reader.
Sl.__cli = cli

--- The one line a disabled addon says, built by the library and re-spelled nowhere
--- (slash-commands-§7). Published because runHold's refusal (`/at debug hold`, a live verb the
--- library's gate never sees) prints the very same line, and the suites compare against it; a second
--- copy of one sentence is how eleven addons ended up with eleven wordings.
function Sl:DisabledLine() return cli:DisabledLine() end

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
