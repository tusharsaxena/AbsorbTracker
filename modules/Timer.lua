local addonName, NS = ...

-- Coalescing repaint scheduler (Ka0s standard §3.1 — one-shot AceTimer, same pattern as
-- settings/Widgets.lua). Repaints are event-driven (core/AbsorbTracker.lua wires the absorb /
-- max-health / world events to RequestRepaint). This trailing-edge throttle caps the repaint rate
-- to one per `throttleWindow` so a burst of UNIT_ABSORB_AMOUNT_CHANGED events during combat can't
-- cause a repaint storm. Idle = zero repaints; there is no polling fallback.

local pending

-- Hoisted to module scope so RequestRepaint reuses ONE callback instead of allocating a fresh
-- closure on every arm (up to ~1/throttleWindow ≈ 10/s in sustained combat). Reduces per-repaint
-- garbage; behaviour is identical. (AceTimer still allocates its own timer table per schedule
-- internally — that's inside the lib and bounded by the coalescing guard below.)
local function doRepaint()
    -- Clear `pending` BEFORE painting (not after): if UpdateAbsorbBar throws (e.g. the combat
    -- secret-value path), the next event still re-arms instead of the bar freezing until
    -- /reload — do not "tidy" this to after the paint call.
    pending = nil
    NS.UpdateAbsorbBar()
end

function NS.RequestRepaint()
    if pending then return end            -- a repaint is already queued; coalesce into it
    pending = NS.addon:ScheduleTimer(doRepaint, NS.GetSetting("throttleWindow"))
end
