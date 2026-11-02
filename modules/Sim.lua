local addonName, NS = ...
-- modules/Sim.lua — the absorb fight simulator, on LibKa0s-Sim-1.0 with its step window (SG-AT-1;
-- the same shape as MultiMeters' and KickCD's `/<slash> sim`).
--
-- THE WORLD. A made-up shield is painted onto the real bars: each timeline step is one shield value
-- handed to NS.PaintHold, and the bars are held (NS.HoldPreview) for the whole session, which is what
-- keeps live repaints off them. Nothing is read from the client, so the seam wraps nothing (an empty
-- compat table), and nothing is stored: the panel's position is session-only and no setting is written.
--
-- STEP DURATION. A step's `wait` is the gap to the next one, so a Run plays the fight on the same
-- clock the retired timer script used; a click on a step in the window jumps there at once.
--
-- THE STOP. Whatever ends the session (the window's Stop, `/at sim stop`, a lock toggle, a stand-down,
-- a debug hold) ends the hold with it, hands unlocked bars their placeholder back, and repaints live
-- data, so a finished sim leaves no state behind. NS.ClearPreview reaches the session through
-- NS.SimStop, and the session's own stop reaches the hold through ClearPreview; Host.arming and the
-- library's re-entrancy-safe Stop break the loop.

NS.SimHost = NS.SimHost or {}
local Host = NS.SimHost

-- The hold the session paints under: long enough that only a stop ends it.
Host.HOLD_SECONDS = 6 * 3600
Host.DEFAULT_WAIT = 1.5

-- The shield steps, { seconds after the start, shield value }. `fight` is the whole story; `drain` and
-- `refresh` are its two halves, each played alone.
local FIGHT = {
    { 0, 120000 }, { 1.5, 96000 }, { 3, 71000 }, { 4.5, 44000 }, { 6, 20000 },
    { 7, 200000 }, { 9, 158000 }, { 11, 90000 }, { 13, 31000 }, { 14.5, 0 },
}
Host.SCENARIO_STEPS = {
    fight   = { from = 1, to = #FIGHT, label = "A full fight: a shield drains, is refreshed, then breaks" },
    drain   = { from = 1, to = 5, label = "One shield draining away" },
    refresh = { from = 6, to = #FIGHT, label = "A bigger shield landing, then breaking" },
}
Host.SCENARIOS = Host.SCENARIOS or { names = { "fight", "drain", "refresh" }, defs = {} }

local function shortNumber(n)
    if n >= 1000 then return ("%gk"):format(n / 1000) end
    return tostring(n)
end

--- The steps of scenario `key`: fresh tables each call (the library previews while idle).
local function timeline(def, opts)
    local key = opts and opts.scenario or def and def.key or "fight"
    local s = Host.SCENARIO_STEPS[key] or Host.SCENARIO_STEPS.fight
    local steps = {}
    for i = s.from, s.to do
        local at, value = FIGHT[i][1], FIGHT[i][2]
        local nextAt = FIGHT[i + 1] and i < s.to and FIGHT[i + 1][1] or nil
        steps[#steps + 1] = {
            kind = "shield", value = value, wait = nextAt and (nextAt - at) or Host.DEFAULT_WAIT,
            label = value == 0 and "Shield breaks" or ("Shield at " .. shortNumber(value)),
        }
    end
    return steps
end
for key, s in pairs(Host.SCENARIO_STEPS) do
    Host.SCENARIOS.defs[key] = { key = key, label = s.label, timeline = timeline }
end

--- The descriptor's stepDelay: the pause after `step`.
function Host.DelayAfter(step)
    return step and step.wait or Host.DEFAULT_WAIT
end

--- Why a simulation may not start now, or nil. Runs inside the seam's Live.
function Host.Refusal()
    if NS.Perf and NS.Perf.on then
        return "A performance capture is running: finish it first (/at perf finish)."
    end
    for _, unit in ipairs(NS.Units.LIST) do
        if NS.Units.IsEnabled(unit) then return nil end
    end
    return "Every bar is disabled; run /at toggle to turn them on before the sim"
end

--- The bar the step window docks beside: the first one on screen, else it floats.
function Host.PanelAnchor()
    for _, unit in ipairs(NS.Units.LIST) do
        local bar = NS.bars and NS.bars[unit]
        if bar and bar.IsShown and bar:IsShown() then return bar end
    end
    return nil
end

--- The descriptor's prepare: hold the bars for the session, open the step window.
function Host.Prepare(_, _, _, ready)
    Host.arming = true
    NS.HoldPreview(Host.HOLD_SECONDS)
    Host.arming = false
    if NS.Sim and NS.Sim.ShowPanel then NS.Sim:ShowPanel() end
    ready()
end

--- One step is one shield value on the bars.
function Host.Play(step)
    NS.PaintHold(step.value)
    return step.label
end

--- NS.ClearPreview's hook: a lock toggle, a stand-down or a second hold ends the session.
function NS.SimStop()
    if Host.arming then return false end
    local sim = NS.Sim
    if sim and sim:IsActive() then return sim:Stop("preview") end
    return false
end

--- The launcher's Sim mode row.
function NS.IsSimRunning() return NS.Sim ~= nil and NS.Sim:IsActive() == true end
function NS.ToggleSim() NS.Sim:RunVerb(NS.IsSimRunning() and "stop" or "") end

local Lib = LibStub and LibStub("LibKa0s-Sim-1.0", true)
if Lib then
    NS.SimSeam = Lib:NewSeam({}, {
        name = addonName,
        debug = function(tag, fmt, ...) if NS.Debug then NS.Debug(tag, fmt, ...) end end,
    })
    NS.Sim = Lib:New({
        name = addonName,
        seam = NS.SimSeam,
        slash = "/at sim",
        deliver = function() return 0 end,
        isStoodDown = function() return NS.IsStoodDown() end,
        scenarios = Host.SCENARIOS,
        prepare = function(...) return Host.Prepare(...) end,
        play = function(step) return Host.Play(step) end,
        refusal = function() return Host.Refusal() end,
        stepDelay = function(step) return Host.DelayAfter(step) end,
        stopText = { preview = "Simulation stopped: the bars were released." },
        print = function(line) NS.Print(line) end,
        debug = function(_, fmt, ...) if NS.Debug then NS.Debug("Sim", fmt, ...) end end,
        panel = {
            title = function() return "Absorb Tracker - Simulation" end,
            anchorTo = function() return Host.PanelAnchor() end,
        },
    })
    -- The stop: the hold goes with the session, unlocked bars get their placeholder, live data returns.
    NS.Sim:OnStop(function()
        if NS.ClearPreview then NS.ClearPreview() end
        if NS.InPreview and NS.InPreview() then NS.ForEachUnit(NS.PaintPlaceholder) end
        if NS.bus then NS.bus:SendMessage(NS.MSG.REPAINT) end
    end)
else
    -- Library absent: the inert session, so every caller above still answers.
    local line = "The simulator needs LibKa0s-Sim-1.0."
    NS.Sim = {
        IsActive = function() return false end,
        Stop = function() return false end,
        ShowPanel = function() return false end,
        RunVerb = function() NS.Print(line); return false, "absent" end,
    }
end
