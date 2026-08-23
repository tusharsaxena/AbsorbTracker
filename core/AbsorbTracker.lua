local addonName, NS = ...

-- Perf probe (the LibKa0s-Perf instance built in core/PerfSetup.lua), taken as a load-time upvalue
-- for the same reason modules/Display.lua and modules/Timer.lua do: OnAbsorbChanged is the addon's
-- highest-frequency entry point, and a dormant bracket should cost an upvalue read rather than a
-- table lookup through NS. PerfSetup loads earlier in the TOC, so this is never nil.
local Perf = NS.Perf

-- AceAddon promotion (Ka0s standard architecture-§2). Pass NS as the first arg so the bootstrap table and
-- the AceAddon object are one and the same; the AceEvent/AceTimer/AceConsole mixins are stamped
-- onto NS.addon.
local AceAddon = LibStub("AceAddon-3.0")
local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon

-- Reclaim NS.Print from AceConsole. NewAddon(NS, …) embeds the AceConsole-3.0 mixins directly onto
-- NS, and its :Print method OVERWRITES the secret-safe, cyan-[AT]-prefixed NS.Print that
-- core/CoreSetup.lua built from LibKa0s-Core (CoreSetup loads before this file). Left clobbered,
-- every `local print = NS.Print` call site would render AceConsole's "|cff33ff99<msg>|r:" form —
-- green text, a trailing colon, and NO [AT] tag — violating slash-commands-§4. core/CoreSetup.lua
-- stashed the real printer at NS.Util.print (which the embed does not touch), so restore NS.Print
-- from it — and the two are the SAME function object, which is the only reason restoring one
-- restores what every settings file already captured.
-- (KickCD sidesteps this entirely by only ever calling NS.Util.print; we keep the NS.Print name.)
if NS.Util and NS.Util.print then NS.Print = NS.Util.print end

-- Debug coalescing (debug-logging-§9): per-combat counters + last non-secret absorb, all maintained only when
-- debug is on. Reset at combat start, flushed as one [Combat] rollup at combat end.
local dbgAbsorbEvents, dbgRepaints = 0, 0
local dbgLastAbsorb   -- last NON-secret absorb value seen (nil until a non-secret read)

-- Called by modules/Display.lua on each actual repaint. Gated: counts nothing when debug is off.
function NS.NoteRepaint()
    if NS.State and NS.State.debug then dbgRepaints = dbgRepaints + 1 end
end

function addon:OnInitialize()
    -- No LSM font registration here any more. It used to register "JetBrains Mono" against this
    -- addon's own media/fonts/ copy; the face now ships in the LibKa0s payload and core/MediaSetup.lua
    -- registers it at FILE LOAD through Media.RegisterLSM — earlier than this, which is the point, and
    -- under one key pointing at one set of bytes for the whole collection rather than one per addon.
    NS:InitDB()

    if NS.Slash and NS.Slash.Register then NS.Slash:Register() end
end

-- OnEnable fires at PLAYER_LOGIN timing, so this reproduces the old Events.lua PLAYER_LOGIN
-- sequence exactly — minus the DB init, which has moved earlier into OnInitialize.
function addon:OnEnable()
    NS.ClearLSMCache()
    NS.GetLSM()
    if NS.ApplyLSMBorderPatch then NS.ApplyLSMBorderPatch() end
    NS.bus:SendMessage(NS.MSG.POSITION)
    NS.bus:SendMessage(NS.MSG.APPEARANCE)
    NS.bus:SendMessage(NS.MSG.REPAINT)

    -- UNIT_ABSORB_AMOUNT_CHANGED and UNIT_MAXHEALTH fire for EVERY unit the client knows about (all
    -- raid members, their pets, nameplates, target/focus) — a flood of events per second in combat,
    -- of which we care about exactly three units. The vendored AceEvent-3.0 (MINOR 4) registers on a
    -- shared frame with plain RegisterEvent and has no unit filtering, so routing these two through
    -- AceEvent would pay a full C→Lua dispatch for every unit only to discard all but ours.
    --
    -- events-frames-taint-§1 deviation (see docs/ARCHITECTURE.md): register them on private frames via
    -- RegisterUnitEvent instead, so the client filters at the C level and OnEvent never fires for
    -- other units. (The rest are global, payload-free events and stay on AceEvent.)
    --
    -- Extracted to its own method (rather than inlined here, as the original brief had it) purely
    -- so a test can call it directly without paying for the rest of OnEnable's side effects
    -- (CreateOptionsPanel is not safely re-callable). Behavior is identical either way.
    -- Also registers PLAYER_TARGET_CHANGED / PLAYER_FOCUS_CHANGED, but only for units whose bar
    -- is enabled — which is why those two are not registered unconditionally alongside the three
    -- below. Re-runs on every UNITS message (subscribed at the bottom of this file).
    self:SyncUnitEventFrames()
    self:RegisterLifecycleEvents()

    -- Create the options panel (defined in settings/OptionsSetup.lua).
    if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
    -- No [Init] boot summary here: the debug flag is session-only and off at login, so a
    -- login-time NS.Debug line would always be gated off. Per debug-logging-§5 the session summary
    -- is emitted from DebugLog:SetEnabled on enable, the only point where it is current and visible.
end

-- The three always-on, unit-agnostic registrations. Extracted from OnEnable so the perf probe's
-- Resume() restores exactly the set Suspend() tore down, rather than a hand-maintained copy of it
-- that could drift the moment a fourth event is added here (core/PerfSetup.lua). The per-unit and
-- swap registrations are NOT part of this set — SyncUnitEventFrames owns those, because they
-- depend on which units are currently enabled.
function addon:RegisterLifecycleEvents()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")
end

-- One private RegisterUnitEvent frame PER UNIT, registered only while that unit's bar is enabled.
--
-- Per-unit frames rather than the old two (RegisterUnitEvent accepts at most two unit tokens, so
-- three units used to mean one frame for player+target and a second for focus): with a frame each,
-- enabling or disabling one unit is a registration change on that unit's frame alone, with no
-- token-packing to redo. The frames are created once and reused; only their registrations change.
--
-- Called from OnEnable and from the UNITS message (settings/Slash.lua and the General page's
-- enable toggles publish it), so the registration set always matches the enabled set.
--
-- Honest note on the win: RegisterUnitEvent already filters at the C level, so the disabled-unit
-- events were never reaching Lua for OTHER units anyway — this saves the dispatch for the two or
-- three tokens we ourselves asked for. The material saving is PLAYER_TARGET_CHANGED /
-- PLAYER_FOCUS_CHANGED below, which fire on every target and focus swap regardless of absorbs.
function addon:SyncUnitEventFrames()
    local frames = self.__unitEventFrames
    if not frames then
        local function onEvent(_, event, unit)
            if event == "UNIT_ABSORB_AMOUNT_CHANGED" then
                self:OnAbsorbChanged(event, unit)
            elseif event == "UNIT_MAXHEALTH" then
                self:OnMaxHealthChanged(event, unit)
            end
        end

        frames = {}
        for _, unit in ipairs(NS.Units.LIST) do
            local f = CreateFrame("Frame")
            f:SetScript("OnEvent", onEvent)
            frames[unit] = f
        end
        self.__unitEventFrames = frames
    end

    for _, unit in ipairs(NS.Units.LIST) do
        local f = frames[unit]
        if NS.Units.IsEnabled(unit) then
            -- RegisterUnitEvent replaces any prior registration for the same event on this frame,
            -- so re-registering an already-registered unit is a harmless no-op.
            f:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit)
            f:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
        else
            f:UnregisterAllEvents()
        end
    end

    -- The swap events only matter while that unit's bar is enabled: they exist to re-evaluate the
    -- UnitExists step of the visibility ladder and repaint the new unit's absorb. With the bar off
    -- there is nothing to re-evaluate, and PLAYER_TARGET_CHANGED in particular fires constantly in
    -- ordinary play. AceEvent's Unregister is safe to call when not registered.
    if NS.Units.IsEnabled("target") then
        self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnUnitSwap")
    else
        self:UnregisterEvent("PLAYER_TARGET_CHANGED")
    end
    if NS.Units.IsEnabled("focus") then
        self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnUnitSwap")
    else
        self:UnregisterEvent("PLAYER_FOCUS_CHANGED")
    end
end

-- The absorb event drives a coalesced repaint (modules/Timer.lua) for EVERY tracked unit (the
-- RegisterUnitEvent frames above already filter dispatch to player/target/focus), so the repaint
-- itself never branches on `unit`. The debug rollup below is deliberately narrower: it counts and
-- reports only the PLAYER's own absorb events (dbgAbsorbEvents / the "[Combat] left: N events"
-- line / the [Absorb] shield-up/shield-gone transitions all read UnitGetTotalAbsorbs("player")),
-- so it stays gated on unit == "player" — counting target/focus events here would make the rollup
-- report a number that doesn't match what it prints. Gate the debug read so it costs nothing when
-- debug is off (debug-logging-§4).
function addon:OnAbsorbChanged(_, unit)
    local t0 = Perf.on and debugprofilestop()
    if unit == "player" and NS.State and NS.State.debug then
        dbgAbsorbEvents = dbgAbsorbEvents + 1
        local v = UnitGetTotalAbsorbs("player") or 0
        -- Only compare when the value is NOT a combat secret (IsConcatSafe == readable).
        if NS.IsConcatSafe(v) then
            local prev = dbgLastAbsorb
            if prev ~= nil and prev == 0 and v ~= 0 then
                NS.Debug("Absorb", "shield up: %s \226\134\146 %s", prev, AbbreviateNumbers(v))
            elseif prev ~= nil and prev ~= 0 and v == 0 then
                NS.Debug("Absorb", "shield gone: %s \226\134\146 0", AbbreviateNumbers(prev))
            end
            dbgLastAbsorb = v
        end
    end
    NS.bus:SendMessage(NS.MSG.REPAINT)
    -- Measures the handler only — bus publish included, the repaint itself NOT (that is deferred
    -- into `repaintPass` by the throttle). This bucket is what answers "does the addon cost
    -- anything per absorb event", which at a training dummy is the highest-frequency path it has.
    if t0 then Perf.Note("absorbEvent", debugprofilestop() - t0) end
end

-- The bar shows absorb as a fraction of max health, so a max-health change (buffs, stamina,
-- level) must repaint too even when the absorb value itself is unchanged. Fires for player,
-- target, or focus; the repaint stays a single coalesced all-bars pass regardless of which, so
-- (unlike OnAbsorbChanged) there is no per-unit debug rollup here to keep in sync, and the unit
-- argument itself is unused.
function addon:OnMaxHealthChanged(_)
    NS.bus:SendMessage(NS.MSG.REPAINT)
end

function addon:OnEnterWorld()
    NS.Debug("World", "entering world")
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
    NS.bus:SendMessage(NS.MSG.REPAINT)
end

-- Target / focus swaps change both which bars should be visible (UnitExists gate) and what they
-- should read, so re-evaluate visibility and repaint together — the same pair every other
-- transition handler in this file sends.
function addon:OnUnitSwap()
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
    NS.bus:SendMessage(NS.MSG.REPAINT)
end

-- Combat transitions re-evaluate bar visibility (the `showOnlyInCombat` gate) and repaint so the
-- bar is fresh if it just appeared. That is all these handlers do: per Ka0s standard options-ui-§2
-- the settings panel REFUSES to open in combat (LibKa0s-Options-1.0, wired in
-- settings/OptionsSetup.lua) rather than deferring, so there
-- is no combat-deferred /at config for OnLeaveCombat to replay — it only handles visibility now.
function addon:OnEnterCombat()
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
    NS.bus:SendMessage(NS.MSG.REPAINT)
    -- Reset the coalescing counters unconditionally (two assignments, harmless when debug is off)
    -- so a fight that began before `/at debug on` still yields an accurate leave-rollup instead of
    -- carrying stale residue from the previous debug-on combat.
    dbgAbsorbEvents, dbgRepaints = 0, 0
    if NS.State and NS.State.debug then
        NS.Debug("Combat", "entered")
    end
end

function addon:OnLeaveCombat()
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
    NS.bus:SendMessage(NS.MSG.REPAINT)
    if NS.State and NS.State.debug then
        local v = UnitGetTotalAbsorbs("player") or 0
        if NS.IsConcatSafe(v) then
            NS.Debug("Combat", "left: %s events, %s repaints, final=%s",
                dbgAbsorbEvents, dbgRepaints, AbbreviateNumbers(v))
        else
            NS.Debug("Combat", "left: %s events, %s repaints", dbgAbsorbEvents, dbgRepaints)
        end
    end
end

-- AceDB profile-change callback (registered in core/Database.lua). Repaint the bar from the new
-- profile and refresh an open settings panel.
function NS.OnProfileChanged()
    -- Belt and braces for the per-profile v3 lift. NS:InitDB sweeps every profile in the saved
    -- store, but a profile that only APPEARS afterwards — copied in from another character,
    -- restored from a backup SavedVariables file, or reset back to the shipped defaults — never
    -- passed through that sweep. Its own `schemaVersion` stamp still reads pre-v3, so lift it the
    -- moment it becomes active. Composes with the InitDB sweep without double-applying: the stamp,
    -- not the account-wide one, is the authority for "has THIS profile been lifted", and
    -- MigrateProfileToV3 returns immediately once it is set (core/Database.lua).
    if NS.MigrateProfileToV3 and NS.db then
        NS.MigrateProfileToV3(NS.db.profile)
    end
    NS.Debug("Profile", "changed \226\134\146 %s",
        (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?")
    -- The new profile carries its own enable flags, so the event registrations have to follow it.
    NS.bus:SendMessage(NS.MSG.UNITS)
    NS.bus:SendMessage(NS.MSG.POSITION)
    NS.bus:SendMessage(NS.MSG.APPEARANCE)
    NS.bus:SendMessage(NS.MSG.REPAINT)
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
end

-- Bus subscription (architecture-§4). This module owns the SOLE subscription to UNITS, on its own
-- target so no two receivers share a table (anti-pattern #32). Publishers are the General page's
-- enable toggles, `/at toggle`, and the reset helpers — anything that can change which units are
-- enabled. Looks the method up at dispatch time so a test can stub it.
NS.Events = NS.Events or {}
if NS.NewBusTarget then
    NS.Events.__ev = NS.NewBusTarget()
    NS.Events.__ev:RegisterMessage(NS.MSG.UNITS, function()
        if NS.addon and NS.addon.SyncUnitEventFrames then
            NS.addon:SyncUnitEventFrames()
        end
    end)
end
