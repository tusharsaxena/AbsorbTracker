local _, NS = ...

-- Single source of unit identity + per-unit config resolution for the player/target/focus
-- tracking feature. modules/Bar.lua, modules/Display.lua and core/Data.lua never reach
-- db.profile.units directly for appearance — they call NS.Units.Get(unit, key), so the "mirror
-- the player bar" behavior lives in exactly one place.
--
-- Mirror semantics (spec §2/§3): when units.<unit>.mirror == true, that unit renders with the
-- player's appearance values. `enabled` and `position` stay per-unit even while mirrored — a
-- mirrored position would stack every bar on one spot, and a mirrored enable would make the
-- per-unit toggle meaningless. Player is never mirrored; it is the source.

local Units = {}
NS.Units = Units

Units.LIST  = { "player", "target", "focus" }
Units.LABEL = { player = "Player", target = "Target", focus = "Focus" }

-- The nineteen appearance keys, in profile order. Mirror resolution and CopyFromPlayer both walk
-- this list, so adding a per-unit setting means adding its key here as well as to the defaults.
--
-- The v3 migration (core/Database.lua) walks it too, to lift the pre-v3 FLAT keys onto the player
-- unit. A key added here after v3 shipped never existed as a flat key, so that loop finds nothing
-- for it and lifts nothing -- which is why growing this list is safe for the ladder.
Units.APPEARANCE_KEYS = {
    "barTexture", "bgTexture", "border", "borderSize", "borderColor",
    "font", "fontSize", "fontFlags", "fontShadow", "fontColor",
    "barWidth", "barHeight", "barAlpha",
    "barColor", "bgColor",
    "useClassColorBar", "useClassColorBg", "useClassColorBorder", "useClassColorText",
}

local function profile()
    return NS.db and NS.db.profile
end

local function defaultsFor(unit)
    local d = NS.defaults and NS.defaults.profile and NS.defaults.profile.units
    return (d and d[unit]) or (d and d.player) or {}
end

local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, vv in pairs(v) do out[k] = deepcopy(vv) end
    return out
end
Units.DeepCopy = deepcopy

function Units.Config(unit)
    local p = profile()
    if not (p and p.units) then return nil end
    return p.units[unit]
end

function Units.IsEnabled(unit)
    local c = Units.Config(unit)
    if c == nil then return defaultsFor(unit).enabled == true end
    return c.enabled == true
end

-- Player is the mirror source and can never itself be mirrored, regardless of what a
-- hand-edited SavedVariables might contain.
function Units.IsMirrored(unit)
    if unit == "player" then return false end
    local c = Units.Config(unit)
    return c ~= nil and c.mirror == true
end

function Units.SourceUnit(unit)
    return Units.IsMirrored(unit) and "player" or unit
end

--- Mirror-resolved appearance read. THE read path for all nineteen appearance keys.
function Units.Get(unit, key)
    local src = Units.SourceUnit(unit)
    local c = Units.Config(src)
    if c ~= nil and c[key] ~= nil then return c[key] end
    local d = defaultsFor(src)
    if d[key] ~= nil then return d[key] end
    return defaultsFor("player")[key]
end

function Units.Position(unit)
    local c = Units.Config(unit)
    return c and c.position
end

function Units.SetPosition(unit, pos)
    local c = Units.Config(unit)
    if c then c.position = pos end
end

--- One-shot snapshot: deep-copy the player's nineteen appearance keys onto `unit`, then clear
--- the mirror so the unit becomes independently editable. `position` and `enabled` are
--- deliberately NOT copied — both stay per-unit by design.
---
--- Through NS.SetByPath, one call per key, rather than `dst[key] = …` onto the config table, so
--- each row's onChange fires. It is a BULK COPY, so debug-logging-§10 logs it as one line, not
--- twenty: the writes run inside NS.Bulk.Run (settings/Schema.lua), which mutes the per-row line
--- and emits `[Set] copy player→<unit>: N rows`, N being the keys whose stored value changed.
---
--- `deepcopy` has NOT become optional. SetByPath stores the value it is handed, so passing
--- `src[key]` bare would leave the two units sharing one color table and one unit's color picker
--- repainting the other unit's bar.
---
--- The mirror clear goes LAST, deliberately. Every write fires its row's onChange, and the
--- appearance rows declare none, so each falls through to the schema's default APPEARANCE
--- broadcast. Clearing the flag first would publish nineteen restyles of an already-unlinked unit
--- reading a half-copied config; clearing it last makes the final broadcast the one that shows the
--- finished snapshot. Nothing flickers either way — the values being written are the player's,
--- which is what a mirrored unit was already drawing.
function Units.CopyFromPlayer(unit)
    if unit == "player" then return end
    local src = Units.Config("player")
    if not (src and Units.Config(unit)) then return end
    local base = "units." .. unit .. "."
    NS.Bulk.Run("copy", "player\226\134\146" .. unit, function()
        for _, key in ipairs(Units.APPEARANCE_KEYS) do
            NS.SetByPath(base .. key, deepcopy(src[key]))
        end
        NS.SetByPath(base .. "mirror", false)
    end)
end
