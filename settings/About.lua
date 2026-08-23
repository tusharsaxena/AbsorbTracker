-- AbsorbTracker: settings/About.lua
--
-- Top-level "Ka0s Absorb Tracker" page builder. Logo, addon Notes
-- one-liner, "Slash Commands" heading, and one row per NS.Slash:LandingRows()
-- entry — the same formatter /at help prints through, minus the chat indent,
-- so the about page and the help block cannot drift. Decorates
-- NS.Helpers.BuildMainContent, which settings/OptionsSetup.lua hands
-- the library as its `buildMain` callback; it fires on the main panel's
-- first OnShow, and again on any re-show after a refresh marked the page dirty.
--
-- The body is DATA, not drawing code: LibKa0s-Options-1.0 owns the landing-page
-- renderer (O.BuildLandingPage), and this file only says what goes on it. The
-- hand-rolled copy that used to live here predated that renderer and had drifted
-- away from it in the one way that shows: it never cleared the scroll, so every
-- re-render stacked a second logo, description and command list under the first.

local addonName, NS = ...

local Helpers = NS.Helpers

-- Deprecated-API access routes through the single Compat shim (Ka0s standard compat).
local function getMetadata(field)
    return NS.Compat.GetAddOnMetadata(NS.name, field)
end

-- `notes` and `rows` are functions because both are resolved at RENDER time: the TOC's Notes field
-- is not readable when this spec is declared, and NS.COMMANDS keeps growing as later files load.
local SPEC = {
    logo  = NS.Constants.LOGO_PATH,
    notes = function() return getMetadata("Notes") or "" end,
    sections = {
        {
            heading = "Slash Commands",
            rows    = function() return NS.Slash:LandingRows() end,
        },
    },
}

function Helpers.BuildMainContent(ctx)
    Helpers.BuildLandingPage(ctx, SPEC)
end
