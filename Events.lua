-- AbsorbTracker: Events module - Event handlers
local AddonName, AddonTable = ...

local defaults = AddonTable.defaults
local flatDefaults = AddonTable.flatDefaults
local DebugPrint = AddonTable.DebugPrint
local GetLSM = AddonTable.GetLSM
local ClearLSMCache = AddonTable.ClearLSMCache
local RestoreBarPosition = AddonTable.RestoreBarPosition
local UpdateBarAppearance = AddonTable.UpdateBarAppearance
local UpdateAbsorbBar = AddonTable.UpdateAbsorbBar
local RestartUpdateTicker = AddonTable.RestartUpdateTicker
local ResetTickerInterval = AddonTable.ResetTickerInterval

-- Profile change callback
function AddonTable.OnProfileChanged()
    RestoreBarPosition()
    UpdateBarAppearance()
    UpdateAbsorbBar()
    ResetTickerInterval()  -- Reset to force ticker restart with new profile's interval
    RestartUpdateTicker(true)
    -- Refresh options panel if it exists (forward reference)
    if AddonTable.RefreshOptionsPanel then
        AddonTable.RefreshOptionsPanel()
    end
end

-- Event handling
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_LOGIN" then
        -- Initialize AceDB if available
        if LibStub then
            local AceDB = LibStub("AceDB-3.0", true)
            if AceDB then
                AddonTable.db = AceDB:New("AbsorbTrackerDB", defaults, true)
                AddonTable.db.RegisterCallback(AddonTable, "OnProfileChanged", AddonTable.OnProfileChanged)
                AddonTable.db.RegisterCallback(AddonTable, "OnProfileCopied", AddonTable.OnProfileChanged)
                AddonTable.db.RegisterCallback(AddonTable, "OnProfileReset", AddonTable.OnProfileChanged)
            end
        end
        -- Fallback if AceDB not available
        if not AddonTable.db then
            AbsorbTrackerDB = AbsorbTrackerDB or {}
            -- Create a minimal db-like structure for compatibility
            AddonTable.db = { profile = AbsorbTrackerDB }
            -- Migrate old flat settings to profile if needed
            for key, defaultVal in pairs(flatDefaults) do
                if AddonTable.db.profile[key] == nil then
                    AddonTable.db.profile[key] = defaultVal
                end
            end
        end
        -- Clear LSM cache in case it loaded after initial fetch
        ClearLSMCache()
        GetLSM()
        RestoreBarPosition()
        UpdateBarAppearance()
        UpdateAbsorbBar()
        RestartUpdateTicker(true)  -- Force start on login
        -- Create options panel (forward reference, set by OptionsPanel.lua)
        if AddonTable.CreateOptionsPanel then
            AddonTable.CreateOptionsPanel()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateAbsorbBar()
    elseif event == "UNIT_ABSORB_AMOUNT_CHANGED" and unit == "player" then
        -- Don't update directly - let the ticker handle updates at the configured interval
        -- The ticker will read the latest absorb value when it fires
        DebugPrint("UNIT_ABSORB_AMOUNT_CHANGED - ", AbbreviateNumbers(UnitGetTotalAbsorbs("player") or 0))
    end
end)
