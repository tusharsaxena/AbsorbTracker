local addonName, NS = ...

-- core/LauncherSetup.lua — the LibKa0s-Launcher-1.0 seam: this addon's minimap button and its
-- broker plugin, which are ONE object registered twice (launcher-§1).
--
-- ---------------------------------------------------------------------------
-- WHY THERE IS ONLY ONE OBJECT
-- ---------------------------------------------------------------------------
--
-- A minimap button and a Titan/ElvUI/Bazooka row look like two features and are not. Both are drawn
-- from a single LibDataBroker-1.1 object of `type = "launcher"`: LibDBIcon-1.0 draws the button from
-- it, and any broker display the player has installed draws its own row from the very same table.
-- One OnClick, one icon, one label, one identity. Two of each is anti-pattern #81 — the second
-- behavior change is where they drift, and nothing reports it because both halves still work.
--
-- The library owns every line of that wiring, because it is identical in eleven addons. What this
-- file supplies is the part that is genuinely ours: our folder name, our logo, how our settings
-- panel opens, and the accessor-and-toggle pairs for the states we have.
--
-- ---------------------------------------------------------------------------
-- THE TWO BUTTONS, AND THE MENU'S TWO ENTRIES
-- ---------------------------------------------------------------------------
--
-- launcher-§2 (standard v2.67.0, LibKa0s-Launcher minor 4): LEFT-click opens the settings panel, on
-- every addon, in either state; RIGHT-click opens the client's own context menu, which the library
-- builds out of the pairs passed below. Neither button is ours to route (anti-pattern #81).
--
-- This addon's menu is Enabled and Locked, the row ADDONS.md records. There is no Test mode entry:
-- options-ui-§15 exempts an addon whose unlocked view already IS its preview, and this one takes the
-- exemption (settings/General.lua, `locked`), so the lock is the preview switch. There is no Show
-- window entry: nothing here is a primary window.
--
-- EACH TOGGLE IS THE SLASH VERB'S OWN HANDLER, looked up in NS.COMMANDS at click time — not a
-- second implementation that agrees with it today. `/at enable|disable` and `/at lock|unlock` all
-- write through `NS.SetByPath` (architecture-§5), whose onChange is where the stand-down latch,
-- the in-combat unlock refusal, the preview clear and the repaint live, and then echo the STORED
-- value (slash-commands-§8). A menu click therefore inherits all of it — including being refused in
-- combat with the refusal's own line — and says exactly what the typed verb says.
--
-- ---------------------------------------------------------------------------
-- WHY `minimap` IS A FUNCTION
-- ---------------------------------------------------------------------------
--
-- `db.global.minimap` does not exist when this file runs: the TOC loads it long before
-- `addon:OnInitialize` calls `NS:InitDB()`, and a table captured here would be a table AceDB later
-- replaces. The library resolves the closure at Register time instead, which is what keeps the table
-- LibDBIcon holds and the table the Master-controls row writes the SAME table. A wrong one here
-- would not raise — the button would simply forget its position every login.
--
-- ---------------------------------------------------------------------------
-- WHY THE NAME IS THE FOLDER NAME
-- ---------------------------------------------------------------------------
--
-- `addonName`, the first vararg every TOC-loaded file gets — never `## Title`, never the brand
-- string, never a hand-typed literal. LibDBIcon keys the button's SAVED POSITION by this name, so a
-- second spelling puts the button back at the library's default angle and labels the broker plugin
-- with the other name. It is the same reason core/MediaSetup.lua and core/EnvSetup.lua are told it.

local print = NS.Print

--- Run the slash verb `name` exactly as the dispatcher would, by its own NS.COMMANDS handler.
--- Resolved at click time: settings/Slash.lua builds NS.COMMANDS after this file loads.
local function runVerb(name)
    for _, command in ipairs(NS.COMMANDS or {}) do
        if command[1] == name then return command[3]("") end
    end
    NS.Debug("Launcher", "no /at %s handler to run", name)
end

local lib = LibStub and LibStub("LibKa0s-Launcher-1.0", true)

-- The store, and only the store. Both arms below answer `IsShown` / `SetShown` out of
-- `db.global.minimap` rather than out of the button, which is what makes the Master-controls
-- checkbox honest on a host where LibDBIcon never loaded: it reflects what the player chose instead
-- of reading `true` because nothing contradicted it.
local function minimapStore()
    local g = NS.db and NS.db.global
    return type(g) == "table" and g.minimap or nil
end

if not lib then
    -- A missing vendored lib must degrade, not error at load. Every member core/AbsorbTracker.lua
    -- and core/Data.lua call is published, answering honestly rather than going quiet — the STORE
    -- still works, so a player who unchecks Minimap button on a degraded install has that choice
    -- remembered and honored the day the library is back.
    --
    -- `Register` is the one member that says anything out loud, and it says it once, because it is
    -- called once (core/AbsorbTracker.lua's OnInitialize).
    local missing = NS.LIBKA0S_MISSING .. ", so there is no minimap button and no broker plugin."
    NS.Launcher = {
        Register      = function() print(missing) return false end,
        IsRegistered  = function() return false end,
        Object        = function() return nil end,
        IsShown       = function()
            local t = minimapStore()
            return not (t and t.hide)
        end,
        SetShown      = function(_, shown)
            local t = minimapStore()
            if t then t.hide = not shown end
            return false
        end,
    }
    return
end

NS.Launcher = lib:New({
    -- REQUIRED, and the folder name rather than the title. See the note above.
    name  = addonName,
    -- REQUIRED. The addon's own logo, the same file the TOC's `## IconTexture` names (launcher-§4);
    -- core/Constants.lua holds the path and says why it is a different file from the About page's.
    icon  = NS.Constants.LOGO_ICON_PATH,
    -- What a broker display prints in its own row, and it is the BRAND NAME IN PLAIN TEXT
    -- (launcher-§1). Not a judgment call: a Titan Panel strip is exactly the place the eleven Ka0s
    -- addons are seen TOGETHER, so `label` is the one field that decides whether they read as one
    -- collection or as eleven unrelated addons. Across the adoptions it came out three ways --
    -- "Absorb Tracker", "Ka0s KickCD", "Ka0s Pretty Chat" -- and a display sorting its plugins
    -- alphabetically filed this one under A while the rest sat together under K. That is the whole
    -- of the argument the short spelling used to make here, answered.
    --
    -- DELIBERATELY NOT THE TOC'S `## Title`, and the two are not wired to each other. A Title may
    -- carry color escapes and one in the collection does (Ka0s Pretty Chat's), which a display
    -- drawing the string raw would splatter across a row of otherwise plain text. Not the folder
    -- name either -- that is `name` above, which LibDBIcon keys the saved position by and which a
    -- player reads nowhere as prose. Three fields, three jobs.
    label = NS.Constants.BRAND,

    -- REQUIRED, and a FUNCTION for the ordering reason at the head of this file.
    minimap = function()
        local g = NS.db and NS.db.global
        return type(g) == "table" and g.minimap or nil
    end,

    -- REQUIRED. LEFT-click always lands here, in either state; so does right-click on a client
    -- with no context-menu API. Resolved at CLICK time rather than captured:
    -- settings/OptionsSetup.lua publishes NS.OpenOptionsPanel after this file loads.
    openSettings = function() NS.OpenOptionsPanel() end,

    -- THE OPTIONS MENU (Launcher minor 4). Each accessor is asked on every open and every hover,
    -- never cached; each toggle is the verb's own handler (see the head of this file).
    --
    -- Enabled: the store, not the latch, as the dispatcher's gate reads it. `setEnabled` is handed
    -- the state to move TO, which picks the verb.
    isEnabled  = function() return NS.GetSetting("enabled") ~= false end,
    setEnabled = function(on) runVerb(on and "enable" or "disable") end,

    -- Locked: the `locked` value the Lock frame checkbox reads. The verb is picked from the STORED
    -- lock, so a combat refusal that wrote the lock back is what the next click toggles from. The
    -- library grays this entry while the addon is disabled; `/at lock` refuses then too.
    isLocked   = function() return NS.GetSetting("locked") and true or false end,
    toggleLock = function() runVerb(NS.GetSetting("locked") and "unlock" or "lock") end,

    -- THE STATUS TOOLTIP (Launcher minor 3, launcher-§1), drawn by the library in either state out
    -- of `isEnabled` and `isLocked` above and `version` here. No `onTooltipShow`: nothing of ours to
    -- append. `version` is the TOC's `## Version` and nothing else: nil (headless, or an unreadable
    -- manifest) draws the label alone rather than NS.Version()'s "?" or the fallback constant.
    version = function() return NS.Meta("Version") end,

    print = function(line) print(line) end,
    debug = function(tag, message) NS.Debug(tag, "%s", message) end,
})
