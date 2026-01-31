-- AbsorbTracker: Timer module - Ticker management
local AddonName, AddonTable = ...

local GetSetting = AddonTable.GetSetting
local DebugPrint = AddonTable.DebugPrint
local UpdateAbsorbBar = AddonTable.UpdateAbsorbBar

-- Update on a timer as backup
local updateTicker
local currentTickerInterval = nil

function AddonTable.RestartUpdateTicker(forceRestart)
    local newInterval = GetSetting("updateInterval")
    DebugPrint("RestartUpdateTicker called - forceRestart:", tostring(forceRestart), "currentInterval:", tostring(currentTickerInterval), "newInterval:", tostring(newInterval), "tickerExists:", tostring(updateTicker ~= nil))

    -- Only restart if interval changed or forced
    if not forceRestart and currentTickerInterval == newInterval and updateTicker then
        DebugPrint("  Skipped - interval unchanged and ticker exists")
        return
    end

    if updateTicker then
        updateTicker:Cancel()
        updateTicker = nil
        DebugPrint("  Cancelled existing ticker")
    end

    if newInterval and newInterval > 0 then
        currentTickerInterval = newInterval
        updateTicker = C_Timer.NewTicker(newInterval, AddonTable.UpdateAbsorbBar)
        DebugPrint("  NEW TICKER CREATED with interval:", newInterval, "seconds at time:", AddonTable.format("%.3f", GetTime()))
    else
        DebugPrint("  ERROR: Invalid interval:", tostring(newInterval))
    end
end

-- Function to reset ticker interval tracking (called on profile change)
function AddonTable.ResetTickerInterval()
    currentTickerInterval = nil
end
