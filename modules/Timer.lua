local addonName, NS = ...

-- Coalescing repaint scheduler (Ka0s standard §3.1 — one-shot AceTimer, same pattern as
-- settings/Widgets.lua). Repaints are event-driven (core/AbsorbTracker.lua wires the absorb /
-- max-health / world events to RequestRepaint). This trailing-edge throttle caps the repaint rate
-- to one per `throttleWindow` so a burst of UNIT_ABSORB_AMOUNT_CHANGED events during combat can't
-- cause a repaint storm. Idle = zero repaints; there is no polling fallback.

local pending

function NS.RequestRepaint()
    if pending then return end            -- a repaint is already queued; coalesce into it
    pending = NS.addon:ScheduleTimer(function()
        pending = nil
        NS.UpdateAbsorbBar()
    end, NS.GetSetting("throttleWindow"))
end
