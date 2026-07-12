local addonName, NS = ...

-- Backup repaint ticker, driven by AceTimer (Ka0s standard §3.1 — no raw C_Timer for repeating
-- work). The interval-change guard keeps a steady-state /at set of the same value from needlessly
-- churning the timer.

local updateTicker
local currentTickerInterval = nil

function NS.RestartUpdateTicker(forceRestart)
    local newInterval = NS.GetSetting("updateInterval")

    -- Only restart if the interval changed or the caller forces it.
    if not forceRestart and currentTickerInterval == newInterval and updateTicker then
        return
    end

    if updateTicker then
        NS.addon:CancelTimer(updateTicker)
        updateTicker = nil
    end

    if newInterval and newInterval > 0 then
        currentTickerInterval = newInterval
        updateTicker = NS.addon:ScheduleRepeatingTimer(NS.UpdateAbsorbBar, newInterval)
    end
end

-- Force the next RestartUpdateTicker to rebuild the ticker (called on profile change so the new
-- profile's interval takes effect).
function NS.ResetTickerInterval()
    currentTickerInterval = nil
end
