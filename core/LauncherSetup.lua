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
-- file supplies is the part that is genuinely ours: our folder name, our logo, what our LEFT button
-- does, and how our settings panel opens.
--
-- ---------------------------------------------------------------------------
-- THE RUNG: (b), AND IT IS THE LOCK
-- ---------------------------------------------------------------------------
--
-- launcher-§2 orders the left click by what the player most likely wants. This addon has no primary
-- window, so rung (a) does not apply. It DOES have a preview switch — and here the preview switch is
-- the lock: options-ui-§15 exempts an addon whose unlocked view already IS its preview from the Test
-- mode row, and this addon takes that exemption (settings/General.lua, `locked`). So rung (b) it is,
-- and left-click toggles the lock.
--
-- IT DRIVES THE SAME SEAM THE CHECKBOX DRIVES, and holds no copy of the state. `NS.SetByPath` is
-- that seam (architecture-§5): the Lock frame checkbox, `/at lock`, `/at unlock`, `/at set locked`,
-- `/at reset locked` and the Defaults button all land in it, and its `locked` onChange is where the
-- in-combat unlock refusal, the preview clear and the repaint live. A click here therefore inherits
-- all of that for free — including being refused in combat, with the refusal's own printed line —
-- rather than reimplementing any of it.
--
-- RIGHT-click always opens the settings panel, on every addon whatever its rung, which is what lets
-- the left button be spent on something better. That is the library's, not ours: we pass
-- `openSettings` and it wires both buttons.
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
    -- What a broker display prints beside the icon. The short player-facing name, matching the
    -- Master-controls block's `addonName`, rather than the full brand: a Titan Panel row is a strip
    -- a dozen addons share, and "Ka0s " in front of it buys the player nothing they cannot see from
    -- the logo already sitting next to it.
    label = "Absorb Tracker",

    -- REQUIRED, and a FUNCTION for the ordering reason at the head of this file.
    minimap = function()
        local g = NS.db and NS.db.global
        return type(g) == "table" and g.minimap or nil
    end,

    -- REQUIRED. Right-click ALWAYS lands here, and so does left-click on rung (c) — which is not us.
    -- Resolved at CLICK time rather than captured: settings/OptionsSetup.lua publishes
    -- NS.OpenOptionsPanel after this file loads.
    openSettings = function() NS.OpenOptionsPanel() end,

    -- THE LEFT CLICK, AND THE RUNG. Its presence is what says (b); passing nothing would say (c).
    --
    -- Reads the live value rather than tracking one, and writes through the single seam, so the
    -- click, the checkbox and the two verbs are the same act. The combat refusal inside the
    -- `locked` onChange may write the lock straight back and print its own line; the panel refresh
    -- below therefore runs against what was STORED, not against what was asked for.
    --
    -- Nothing is printed on success: the bars becoming draggable (or stopping) is the feedback, and
    -- a chat line on every minimap click would be noise the slash verbs only earn because a typed
    -- command with no echo reads as ignored.
    onClick = function()
        NS.SetByPath("locked", not NS.GetSetting("locked"))
        if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    end,

    print = function(line) print(line) end,
    debug = function(tag, message) NS.Debug(tag, "%s", message) end,
})
