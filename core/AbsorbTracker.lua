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
    -- of which we care about exactly one unit. The vendored AceEvent-3.0 (MINOR 4) registers on a
    -- shared frame with plain RegisterEvent and has no unit filtering, so routing these two through
    -- AceEvent would pay a full C→Lua dispatch for every unit only to discard all but "player".
    -- Register them on a private frame with RegisterUnitEvent("player") instead: the client filters
    -- at the C level and OnEvent never fires for other units. (The rest are global, payload-free
    -- events and stay on AceEvent.) Guard so a disable/enable cycle doesn't leak a second frame.
    if not self.unitEventFrame then
        local f = CreateFrame("Frame")
        f:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
        f:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
        f:SetScript("OnEvent", function(_, event, unit)
            if event == "UNIT_ABSORB_AMOUNT_CHANGED" then
                addon:OnAbsorbChanged(event, unit)
            else
                addon:OnMaxHealthChanged(event, unit)
            end
        end)
        self.unitEventFrame = f
    end

    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnEnterWorld")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnLeaveCombat")

    -- Create the options panel (defined in settings/Panel.lua).
    if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
    -- No [Init] boot summary here: the debug flag is session-only and off at login, so a
    -- login-time NS.Debug line would always be gated off. Per debug-logging §5 the session summary
    -- is emitted from DebugLog:SetEnabled on enable, the only point where it is current and visible.
end

-- The absorb event drives a coalesced repaint (modules/Timer.lua). Gate the debug read so it
-- costs nothing when debug is off (§12.4).
function addon:OnAbsorbChanged(_, unit)
    if unit ~= "player" then return end
    if NS.State and NS.State.debug then
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
-- level) must repaint too even when the absorb value itself is unchanged.
function addon:OnMaxHealthChanged(_, unit)
    if unit == "player" then NS.bus:SendMessage(NS.MSG.REPAINT) end
end

function addon:OnEnterWorld()
    NS.Debug("World", "entering world")
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
    NS.Debug("Profile", "changed \226\134\146 %s",
        (NS.db and NS.db.GetCurrentProfile and NS.db:GetCurrentProfile()) or "?")
    NS.bus:SendMessage(NS.MSG.POSITION)
    NS.bus:SendMessage(NS.MSG.APPEARANCE)
    NS.bus:SendMessage(NS.MSG.REPAINT)
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
end
