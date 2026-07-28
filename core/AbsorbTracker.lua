local addonName, NS = ...

-- AceAddon promotion (Ka0s standard §4.2). Pass NS as the first arg so the bootstrap table and
-- the AceAddon object are one and the same; the AceEvent/AceTimer/AceConsole mixins are stamped
-- onto NS.addon.
local AceAddon = LibStub("AceAddon-3.0")
local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon

-- Reclaim NS.Print from AceConsole. NewAddon(NS, …) embeds the AceConsole-3.0 mixins directly onto
-- NS, and its :Print method OVERWRITES the secret-safe, cyan-[AT]-prefixed NS.Print that
-- core/Util.lua defined earlier (Util loads before this file). Left clobbered, every
-- `local print = NS.Print` call site would render AceConsole's "|cff33ff99<msg>|r:" form — green
-- text, a trailing colon, and NO [AT] tag — violating slash-commands-§4. core/Util.lua stashed the
-- real printer at NS.Util.print (which the embed does not touch), so restore NS.Print from it.
-- (KickCD sidesteps this entirely by only ever calling NS.Util.print; we keep the NS.Print name.)
if NS.Util and NS.Util.print then NS.Print = NS.Util.print end

-- Debug coalescing (§9): per-combat counters + last non-secret absorb, all maintained only when
-- debug is on. Reset at combat start, flushed as one [Combat] rollup at combat end.
local dbgAbsorbEvents, dbgRepaints = 0, 0
local dbgLastAbsorb   -- last NON-secret absorb value seen (nil until a non-secret read)

-- Called by modules/Display.lua on each actual repaint. Gated: counts nothing when debug is off.
function NS.NoteRepaint()
    if NS.State and NS.State.debug then dbgRepaints = dbgRepaints + 1 end
end

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
    NS.bus:SendMessage(NS.MSG.POSITION)
    NS.bus:SendMessage(NS.MSG.APPEARANCE)
    NS.bus:SendMessage(NS.MSG.REPAINT)

    -- UNIT_ABSORB_AMOUNT_CHANGED and UNIT_MAXHEALTH fire for EVERY unit the client knows about (all
    -- raid members, their pets, nameplates, target/focus) — a flood of events per second in combat,
    -- of which we care about exactly three units. The vendored AceEvent-3.0 (MINOR 4) registers on a
    -- shared frame with plain RegisterEvent and has no unit filtering, so routing these two through
    -- AceEvent would pay a full C→Lua dispatch for every unit only to discard all but ours.
    --
    -- §9.1 deviation (see docs/ARCHITECTURE.md): register them on private frames via
    -- RegisterUnitEvent instead, so the client filters at the C level and OnEvent never fires for
    -- other units. (The rest are global, payload-free events and stay on AceEvent.)
    --
    -- Extracted to its own method (rather than inlined here, as the original brief had it) purely
    -- so a test can call it directly without paying for the rest of OnEnable's side effects
    -- (CreateOptionsPanel is not safely re-callable). Behaviour is identical either way.
    self:EnsureUnitEventFrames()

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")

    -- Target / focus swaps change which bars should be visible and what they should read.
    -- Global, payload-free events with no unit to filter, so they stay on AceEvent (§9.1).
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnUnitSwap")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnUnitSwap")

    -- Create the options panel (defined in settings/Panel.lua).
    if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
    -- No [Init] boot summary here: the debug flag is session-only and off at login, so a
    -- login-time NS.Debug line would always be gated off. Per debug-logging §5 the session summary
    -- is emitted from DebugLog:SetEnabled on enable, the only point where it is current and visible.
end

-- Build the two private RegisterUnitEvent frames (see the comment in OnEnable above for why two
-- are required). Guarded so a disable/enable cycle — or a direct re-call — doesn't leak a second
-- pair of frames; registration is unconditional (not gated on the per-unit `enabled` flag) since
-- the C-side filter already limits dispatch to three units, so conditional registration would add
-- lifecycle complexity for no measurable gain.
function addon:EnsureUnitEventFrames()
    if self.__unitEventFrames then return end

    local function onEvent(_, event, unit)
        if event == "UNIT_ABSORB_AMOUNT_CHANGED" then
            self:OnAbsorbChanged(event, unit)
        elseif event == "UNIT_MAXHEALTH" then
            self:OnMaxHealthChanged(event, unit)
        end
    end

    -- Frame A: player + target. RegisterUnitEvent filters at most TWO unit tokens per
    -- registration, and we now track three (player/target/focus) — a future reader will be
    -- tempted to merge this with frame B; don't, the two-token cap is a hard client-side limit,
    -- not a style choice.
    local frameA = CreateFrame("Frame")
    frameA:SetScript("OnEvent", onEvent)
    frameA:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player", "target")
    frameA:RegisterUnitEvent("UNIT_MAXHEALTH", "player", "target")

    -- Frame B: the third unit that didn't fit on frame A.
    local frameB = CreateFrame("Frame")
    frameB:SetScript("OnEvent", onEvent)
    frameB:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "focus")
    frameB:RegisterUnitEvent("UNIT_MAXHEALTH", "focus")

    self.__unitEventFrames = { frameA, frameB }
end

-- The absorb event drives a coalesced repaint (modules/Timer.lua) for EVERY tracked unit (the
-- RegisterUnitEvent frames above already filter dispatch to player/target/focus), so the repaint
-- itself never branches on `unit`. The debug rollup below is deliberately narrower: it counts and
-- reports only the PLAYER's own absorb events (dbgAbsorbEvents / the "[Combat] left: N events"
-- line / the [Absorb] shield-up/shield-gone transitions all read UnitGetTotalAbsorbs("player")),
-- so it stays gated on unit == "player" — counting target/focus events here would make the rollup
-- report a number that doesn't match what it prints. Gate the debug read so it costs nothing when
-- debug is off (§12.4).
function addon:OnAbsorbChanged(_, unit)
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
-- the settings panel REFUSES to open in combat (settings/Panel.lua) rather than deferring, so there
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
    NS.bus:SendMessage(NS.MSG.POSITION)
    NS.bus:SendMessage(NS.MSG.APPEARANCE)
    NS.bus:SendMessage(NS.MSG.REPAINT)
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
end
