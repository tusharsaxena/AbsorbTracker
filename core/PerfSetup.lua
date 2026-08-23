local addonName, NS = ...

-- core/PerfSetup.lua — wires the addon into LibKa0s-Perf (issue #17).
--
-- The probe itself lives in libs/LibKa0s/Perf.lua and is shared across every Ka0s addon; this file
-- is only the part that is ours: which hot paths get buckets, what "suspended" means here, and where
-- the output goes. The descriptor contract is documented in the LibKa0s repo (its README's
-- descriptor table, and docs/record-schema.md for what a saved run looks like).
--
-- The instance is created at LOAD TIME, before any module takes `local Perf = NS.Perf` as an
-- upvalue — this file sits immediately after core/CoreSetup.lua in the TOC for exactly that reason,
-- and because the descriptor's `log` and `print` sinks below both go through NS.Print.

local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)
if not lib then
    -- A missing vendored lib must degrade, not error at load: the addon's own function is unaffected
    -- by the absence of a diagnostics harness. The stub therefore has to cover EVERY member the
    -- addon calls, not just the bracket idiom (`on`/`Note`) and the show-decision ladder
    -- (`suspended`) — `/at perf` is registered unconditionally, so OnCommand has to answer too, and
    -- an honest "it is not installed" beats a Lua error in exactly the install this branch exists
    -- for.
    NS.Perf = {
        on        = false,
        suspended = false,
        Note      = function() end,
        OnCommand = function()
            return { NS.LIBKA0S_MISSING .. ", so performance measurement is unavailable." }
        end,
    }
    return
end

NS.Perf = lib:New({
    name    = addonName,
    title   = "Absorb Tracker",
    slash   = "/at",
    version = NS.version,
    sv      = "AbsorbTrackerPerfDB",

    -- Ordered for the report, and the nesting is DECLARED rather than left as prose, so two
    -- totals are never summed as if they were disjoint. Each declaration below is the containment
    -- the call graph actually has, and every nested bracket also SUPPLIES its parent to Perf.Note,
    -- so the capture reports containment it observed rather than one this table merely claims
    -- (performance-§3).
    --
    -- What this used to say, and why it was wrong: `appearance` and `visibility` both declared
    -- `within = "repaintPass"`. Neither runs there. `repaintPass` is doRepaint, which fans out over
    -- NS.UpdateAbsorbBar and nothing else; NS.UpdateBarAppearance is entered from the APPEARANCE bus
    -- message and from a settings row's onChange, and NS.ApplyVisibility from the VISIBILITY message
    -- — or from inside UpdateBarAppearance, which is the one real nesting here.
    buckets = {
        { key = "absorbEvent" },                        -- addon:OnAbsorbChanged
        { key = "repaintPass" },                        -- doRepaint, one coalesced pass over every unit
        { key = "paintBar",    within = "repaintPass" },-- NS.UpdateAbsorbBar, per bar, inside doRepaint
        -- A root: UpdateBarAppearance is an entry point (APPEARANCE message / settings onChange),
        -- contained in nothing. Declaring a parent it never runs under is the claim this table is
        -- supposed to make checkable, so it declares none — and the bracket still supplies whatever
        -- bucket happens to be open, so the day it does run inside one, the capture says so.
        { key = "appearance" },                         -- NS.UpdateBarAppearance, per bar
        -- UpdateBarAppearance ends by calling ApplyVisibility inside its own open bracket, so this
        -- IS nested — in `appearance`, never in `repaintPass`. Dropping `within` here would trade a
        -- wrong-parent claim for a disjoint-totals claim, which is worse: nothing contradicts it.
        { key = "visibility",  within = "appearance" }, -- NS.ApplyVisibility, per bar
    },

    --- Make the addon inert without a /reload.
    ---
    --- Visibility is NOT enforced by hiding frames here. NS.ShouldShowBar checks NS.Perf.suspended
    --- as step 0 of its ladder, so publishing VISIBILITY is enough and nothing — a combat
    --- transition, a target swap, a settings change — can re-show a bar behind suspend's back.
    suspend = function()
        local addon = NS.addon
        if addon then
            local frames = addon.__unitEventFrames
            if frames then
                for _, f in pairs(frames) do f:UnregisterAllEvents() end
            end
            if addon.UnregisterEvent then
                for _, event in ipairs({
                    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
                    "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",
                }) do
                    addon:UnregisterEvent(event)
                end
            end
        end
        if NS.CancelPendingRepaint then NS.CancelPendingRepaint() end
        if NS.bus then NS.bus:SendMessage(NS.MSG.VISIBILITY) end
    end,

    --- Restore everything suspend took away. SyncUnitEventFrames rebuilds the per-unit registrations
    --- from the CURRENT enabled set, so a unit toggled while suspended comes back correctly.
    resume = function()
        local addon = NS.addon
        if addon then
            if addon.RegisterLifecycleEvents then addon:RegisterLifecycleEvents() end
            if addon.SyncUnitEventFrames then addon:SyncUnitEventFrames() end
        end
        if NS.bus then
            NS.bus:SendMessage(NS.MSG.VISIBILITY)
            NS.bus:SendMessage(NS.MSG.APPEARANCE)
            NS.bus:SendMessage(NS.MSG.REPAINT)
        end
    end,

    -- Perf output is deliberately NOT gated on NS.State.debug, unlike NS.Debug. That gate keeps the
    -- addon free when idle, and a perf run is explicit user action — none of it executes unless
    -- someone typed `/at perf start`. Gating it meant a user who started a run without first
    -- enabling debug logging watched a console that stayed empty while a capture was plainly running.
    log = function(line)
        if NS.DebugLog and NS.DebugLog.Add then
            NS.DebugLog:Add("Perf", line)
        else
            NS.Print(line)
        end
    end,

    print = function(line) NS.Print(line) end,

    -- `start`, `report` and `dump` want the console in front of the user. Everything else must not
    -- pop it open — a lifecycle line mid-combat is the last moment to throw a window on screen.
    showLog = function()
        if NS.DebugLog and NS.DebugLog.Show and not NS.DebugLog:IsShown() then
            NS.DebugLog:Show()
        end
    end,

    -- Built by the addon's own close-button factory rather than a lookalike, so the perf panel and
    -- the debug console cannot drift apart: NS.MakeCloseButton (core/CoreSetup.lua) and the console's
    -- own control both end at LibKa0s-Core's MakeCloseButton, and the wrapper is the single place
    -- that tells the library which addon folder to build the mark's texture path from.
    --
    -- IT USED TO BE `NS.DebugLog.MakeCloseButton(frame, api.Hide)` — a two-argument call onto a
    -- three-argument function, which is why this panel drew a multiplication sign while every suite
    -- stayed green: the dropped third argument is the addon name, and a texture path that is never
    -- built draws nothing and raises nothing. Going through the wrapper means the argument cannot be
    -- dropped at a call site again.
    --
    -- Guarded only because a close button is worth degrading over, not erroring over.
    decorate = function(frame, api)
        if NS.MakeCloseButton then
            local close = NS.MakeCloseButton(frame, api.Hide)
            -- The factory answers nil where CreateFrame is unavailable — a close button is worth
            -- degrading over, not erroring over.
            if close then
                close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(api.TITLE_H - 18) / 2)
                frame.closeButton = close
            end
        end
    end,
})
