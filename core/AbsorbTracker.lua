local addonName, NS = ...

-- AceAddon promotion (Ka0s standard §4.2). Pass NS as the first arg so the bootstrap table and
-- the AceAddon object are one and the same; the AceEvent/AceTimer/AceConsole mixins are stamped
-- onto NS.addon.
local AceAddon = LibStub("AceAddon-3.0")
local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon

function addon:OnInitialize()
    -- Register the vendored monospace font with LSM for the debug console (§12.2).
    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
    if LSM then LSM:Register("font", "JetBrains Mono", NS.Constants.FONT_MONO) end

    NS:InitDB()

    if NS.Slash and NS.Slash.Register then NS.Slash:Register() end
end

-- OnEnable fires at PLAYER_LOGIN timing, so this reproduces the old Events.lua PLAYER_LOGIN
-- sequence exactly — minus the DB init, which has moved earlier into OnInitialize.
function addon:OnEnable()
    NS.ClearLSMCache()
    NS.GetLSM()
    if NS.ApplyLSMBorderPatch then NS.ApplyLSMBorderPatch() end
    NS.RestoreBarPosition()
    NS.UpdateBarAppearance()
    NS.UpdateAbsorbBar()

    self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", "OnAbsorbChanged")
    self:RegisterEvent("UNIT_MAXHEALTH", "OnMaxHealthChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")

    -- Create the options panel (defined in settings/Panel.lua).
    if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
end

-- The absorb event drives a coalesced repaint (modules/Timer.lua). Gate the debug read so it
-- costs nothing when debug is off (§12.4).
function addon:OnAbsorbChanged(_, unit)
    if unit ~= "player" then return end
    if NS.State and NS.State.debug then
        NS.DebugPrint("UNIT_ABSORB_AMOUNT_CHANGED", "Value:",
            AbbreviateNumbers(UnitGetTotalAbsorbs("player") or 0))
    end
    NS.RequestRepaint()
end

-- The bar shows absorb as a fraction of max health, so a max-health change (buffs, stamina,
-- level) must repaint too even when the absorb value itself is unchanged.
function addon:OnMaxHealthChanged(_, unit)
    if unit == "player" then NS.RequestRepaint() end
end

function addon:OnEnterWorld()
    NS.ApplyVisibility()
    NS.RequestRepaint()
end

-- Combat transitions re-evaluate bar visibility (the `showOnlyInCombat` gate) and repaint so the
-- bar is fresh if it just appeared. OnLeaveCombat is also the single owner of PLAYER_REGEN_ENABLED:
-- it replays a combat-deferred /at config (settings/Panel.lua sets the flag), which keeps AceEvent's
-- one-handler-per-event rule from colliding with the visibility handler.
function addon:OnEnterCombat()
    NS.ApplyVisibility()
    NS.RequestRepaint()
end

function addon:OnLeaveCombat()
    NS.ApplyVisibility()
    NS.RequestRepaint()
    if NS.State and NS.State.panelOpenPending then
        NS.State.panelOpenPending = nil
        if NS.OpenOptionsPanel then NS.OpenOptionsPanel() end
    end
end

-- AceDB profile-change callback (registered in core/Database.lua). Repaint the bar from the new
-- profile and refresh an open settings panel.
function NS.OnProfileChanged()
    NS.RestoreBarPosition()
    NS.UpdateBarAppearance()
    NS.UpdateAbsorbBar()
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
end
