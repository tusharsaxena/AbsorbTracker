local addonName, NS = ...

-- Coalescing repaint scheduler (Ka0s standard §3.1 — one-shot AceTimer, same pattern as
-- LibKa0s-Options-1.0's widget makers). Repaints are event-driven (core/AbsorbTracker.lua wires the absorb /
-- max-health / world events to RequestRepaint). This trailing-edge throttle caps the repaint rate
-- to one per `throttleWindow` so a burst of UNIT_ABSORB_AMOUNT_CHANGED events during combat can't
-- cause a repaint storm. Idle = zero repaints; there is no polling fallback.

local Perf = NS.Perf

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
    local t0 = Perf.on and debugprofilestop()
    -- Fan out over every tracked unit. UpdateAbsorbBar defaults its `unit` argument to "player",
    -- so calling it bare here painted the player bar and left the target/focus StatusBars at their
    -- untouched frame defaults (full fill, no text) however many absorb events arrived.
    --
    -- Count ONE repaint for the whole pass, not one per bar. The `[Combat]` rollup reads
    -- "N events, M repaints" to show the throttle coalescing, and its N counts player events only
    -- — an M that scaled with the visible bar count could exceed N and read as if the throttle
    -- were amplifying work. A pass in which no bar painted (all hidden, or a /at test hold) still
    -- counts nothing, so the "hidden bar is not a repaint" property is unchanged.
    local painted = false
    NS.ForEachUnit(function(unit)
        if NS.UpdateAbsorbBar(unit) then painted = true end
    end)
    if painted and NS.NoteRepaint then NS.NoteRepaint() end
    -- One `repaintPass` note per coalesced pass, painted or not: the bucket measures what the
    -- throttle actually costs when it fires, and a pass that early-outs on every bar is still a
    -- pass that ran. This is the same accounting rule NoteRepaint follows one line above, for the
    -- same reason — see the comment on NS.UpdateAbsorbBar.
    if t0 then Perf.Note("repaintPass", debugprofilestop() - t0) end
end

function NS.RequestRepaint()
    -- Suspended = inert. Bail before arming rather than inside doRepaint: an armed timer would
    -- still allocate, still fire, and still show up as work in the very capture that suspend
    -- exists to zero out.
    if Perf.suspended then return end
    if pending then return end            -- a repaint is already queued; coalesce into it
    pending = NS.addon:ScheduleTimer(doRepaint, NS.GetSetting("throttleWindow"))
end

--- Drop any queued repaint. Used by the perf probe's suspend path so a pass armed a moment before
--- suspending cannot land in the middle of the suspended measurement arm.
function NS.CancelPendingRepaint()
    if not pending then return false end
    if NS.addon and NS.addon.CancelTimer then NS.addon:CancelTimer(pending) end
    pending = nil
    return true
end

-- Bus subscription (architecture-§4). This module owns the SOLE subscription to
-- RepaintRequested; the event / slash / lifecycle layers publish it instead of
-- calling RequestRepaint across the module boundary. Registered on Timer's own
-- target so no receiver ever shares a table with another (anti-pattern #32).
NS.Timer = NS.Timer or {}
if NS.NewBusTarget then
    NS.Timer.__ev = NS.NewBusTarget()
    NS.Timer.__ev:RegisterMessage(NS.MSG.REPAINT, function() NS.RequestRepaint() end)
end
