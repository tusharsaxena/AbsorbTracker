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
    NS.RestartUpdateTicker(true)   -- force start on login

    self:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", "OnAbsorbChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")

    -- Create the options panel (defined in settings/Panel.lua).
    if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
end

-- The ticker (modules/Timer.lua) drives the actual repaint at the configured interval; the
-- absorb event only records that the value changed, so a burst of events can't repaint faster
-- than the interval. Gate the debug read so it costs nothing when debug is off (§12.4).
function addon:OnAbsorbChanged(_, unit)
    if unit == "player" and NS.State and NS.State.debug then
        NS.DebugPrint("UNIT_ABSORB_AMOUNT_CHANGED -",
            AbbreviateNumbers(UnitGetTotalAbsorbs("player") or 0))
    end
end

function addon:OnEnterWorld()
    NS.UpdateAbsorbBar()
end

-- AceDB profile-change callback (registered in core/Database.lua). Repaint the bar from the new
-- profile, restart the ticker with the new interval, and refresh an open settings panel.
function NS.OnProfileChanged()
    NS.RestoreBarPosition()
    NS.UpdateBarAppearance()
    NS.UpdateAbsorbBar()
    NS.ResetTickerInterval()       -- force ticker restart with the new profile's interval
    NS.RestartUpdateTicker(true)
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
end
