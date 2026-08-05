local addonName, NS = ...

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

-- The fifteen appearance keys, in profile order. Mirror resolution and CopyFromPlayer both walk
-- this list, so adding a per-unit setting means adding its key here as well as to the defaults.
Units.APPEARANCE_KEYS = {
    "barTexture", "bgTexture", "border", "borderSize", "borderColor",
    "font", "fontSize", "fontFlags", "barWidth", "barHeight",
    "barColor", "bgColor", "useClassColorBar", "useClassColorBg", "useClassColorBorder",
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

--- Mirror-resolved appearance read. THE read path for all fifteen appearance keys.
function Units.Get(unit, key)
    local src = Units.SourceUnit(unit)
    local c = Units.Config(src)
    if c ~= nil and c[key] ~= nil then return c[key] end
    local d = defaultsFor(src)
    if d[key] ~= nil then return d[key] end
    return defaultsFor("player")[key]
end

--- Write an appearance key onto the unit's OWN config. Deliberately not mirror-resolved: a
--- write while mirrored would silently edit the player's bar, which is not what the user
--- clicked.
---
--- Exported without a production caller, deliberately: this is the published write half of the
--- `Units.Get` seam, and it is the shape any future per-unit write path should take. It is NOT on
--- the slash CLI's path — `/at set` goes `NS.SetByPath` -> `NS.SetSetting` (`settings/Schema.lua`)
--- -> `NS.SetPath` (`core/Data.lua`), walking the dotted profile path directly. The mirror-unaware
--- write the comment above describes is real, it just also lives there.
function Units.Set(unit, key, value)
    local c = Units.Config(unit)
    if c then c[key] = value end
end

function Units.Position(unit)
    local c = Units.Config(unit)
    return c and c.position
end

function Units.SetPosition(unit, pos)
    local c = Units.Config(unit)
    if c then c.position = pos end
end

--- One-shot snapshot: deep-copy the player's fifteen appearance keys onto `unit`, then clear
--- the mirror so the unit becomes independently editable. `position` and `enabled` are
--- deliberately NOT copied — both stay per-unit by design.
function Units.CopyFromPlayer(unit)
    if unit == "player" then return end
    local src, dst = Units.Config("player"), Units.Config(unit)
    if not (src and dst) then return end
    for _, key in ipairs(Units.APPEARANCE_KEYS) do
        dst[key] = deepcopy(src[key])
    end
    dst.mirror = false
end
