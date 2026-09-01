local addonName, NS = ...

-- Bar data + media access layer: the AceDB read/write seam (GetSetting/SetSetting), the cached
-- LibSharedMedia fetchers (texture/border/font with fallbacks), and the class-color-aware color
-- resolvers.
--
-- Color getters re-read the useClassColor* toggles on every call so a class change / respec /
-- profile switch "just works" without explicit refresh wiring — do NOT cache the resolved color
-- on a frame.

local C = NS.Constants

-- AceDB instance, set by core/Database.lua at init.
NS.db = nil

-- Cached LibSharedMedia reference.
local LSM

function NS.GetLSM()
    if LSM then return LSM end
    if LibStub then
        LSM = LibStub("LibSharedMedia-3.0", true)
    end
    return LSM
end

-- Clear the LSM cache (called on enable to pick up late-loading libs).
function NS.ClearLSMCache()
    LSM = nil
end

-- Generic setting getter with fallback to the defaults when a key or the DB is absent. Accepts
-- both a flat global key ("locked") and a dotted per-unit path ("units.target.barWidth").
function NS.GetSetting(path)
    local db = NS.db
    if db and db.profile then
        local val = NS.ResolvePath(db.profile, path)
        if val ~= nil then return val end
    end
    return NS.ResolvePath(NS.flatDefaults, path)
end

-- Generic setting setter. Same path grammar as GetSetting.
function NS.SetSetting(path, value)
    local db = NS.db
    if db and db.profile then
        NS.SetPath(db.profile, path, value)
    end
end

-- Media getters. `unit` defaults to "player" so existing single-bar call sites keep working;
-- every read routes through Units.Get, which applies the mirror.
local function unitSetting(unit, key)
    return NS.Units.Get(unit or "player", key)
end

function NS.GetBarTexture(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", unitSetting(unit, "barTexture"))
        if texture then return texture end
    end
    return C.FALLBACK_TEXTURE
end

function NS.GetBgTexture(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", unitSetting(unit, "bgTexture"))
        if texture then return texture end
    end
    return C.FALLBACK_TEXTURE
end

function NS.GetBorder(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local border = lsm:Fetch("border", unitSetting(unit, "border"))
        if border then return border end
    end
    return C.FALLBACK_BORDER
end

function NS.GetFont(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local font = lsm:Fetch("font", unitSetting(unit, "font"))
        if font then return font end
    end
    return C.FALLBACK_FONT
end

-- ANSWERS NIL WHEN THE CLASS IS UNKNOWN, and every caller below then keeps the configured color.
--
-- It used to substitute opaque white, which is a tenth hue invented for the occasion: a player who
-- had set a blue bar, ticked Use Class Color and landed on a client that could not name their class
-- got white -- a color they had never chosen and could not have predicted. Falling back to the
-- swatch they DID choose is both recoverable and legible. The cache still only fills on success, so
-- a class that resolves later (a lib loading after us, a reload) is picked up on the next read.
local playerClassColor
local function GetPlayerClassColor()
    if not playerClassColor then
        local _, classFilename = UnitClass("player")
        if classFilename and C_ClassColor and C_ClassColor.GetClassColor then
            local color = C_ClassColor.GetClassColor(classFilename)
            if color then
                playerClassColor = { r = color.r, g = color.g, b = color.b }
            end
        end
    end
    return playerClassColor
end

local backgroundMultiplier = 0.2

local bgClassColors = {
    DEATHKNIGHT = { r = 0.77, g = 0.12, b = 0.23 },  -- #C41E3A
    DEMONHUNTER = { r = 0.64, g = 0.19, b = 0.79 },  -- #A330C9
    DRUID       = { r = 1.00, g = 0.49, b = 0.04 },  -- #FF7C0A
    EVOKER      = { r = 0.20, g = 0.58, b = 0.50 },  -- #33937F
    HUNTER      = { r = 0.67, g = 0.83, b = 0.45 },  -- #AAD372
    MAGE        = { r = 0.25, g = 0.78, b = 0.92 },  -- #3FC7EB
    MONK        = { r = 0.00, g = 1.00, b = 0.60 },  -- #00FF98
    PALADIN     = { r = 0.96, g = 0.55, b = 0.73 },  -- #F48CBA
    PRIEST      = { r = 1.00, g = 1.00, b = 1.00 },  -- #FFFFFF
    ROGUE       = { r = 1.00, g = 0.96, b = 0.41 },  -- #FFF468
    SHAMAN      = { r = 0.00, g = 0.44, b = 0.87 },  -- #0070DD
    WARLOCK     = { r = 0.53, g = 0.53, b = 0.93 },  -- #8788EE
    WARRIOR     = { r = 0.78, g = 0.61, b = 0.43 },  -- #C69B6D
}

-- Same nil-on-unknown contract as GetPlayerClassColor above, and for the same reason.
local playerBgClassColor
local function GetBgClassColor()
    if not playerBgClassColor then
        local _, classFilename = UnitClass("player")
        local base = classFilename and bgClassColors[classFilename]
        if base then
            playerBgClassColor = {
                r = base.r * backgroundMultiplier,
                g = base.g * backgroundMultiplier,
                b = base.b * backgroundMultiplier,
            }
        end
    end
    return playerBgClassColor
end

--- Resolve one color row against its class-color toggle. Three rules, in one place because all
--- four surfaces obey them and four copies is how one of them stops:
---
---   1. THE CONFIGURED ALPHA SURVIVES THE MODE. A class color carries no alpha of its own, so it
---      takes the swatch's -- otherwise the opacity would silently change when the mode did.
---   2. AN UNKNOWN CLASS KEEPS THE CONFIGURED COLOR. `classColor` answers nil there (see
---      GetPlayerClassColor), and nil falls straight through to the stored swatch.
---   3. The swatch is read under BOTH modes, which is why no color row carries `disabledIf` any
---      more (settings/Appearance.lua states that reversal in full).
local function resolveColor(c, on, classColor)
    if type(c) ~= "table" then c = {} end
    local a = c.a or 1
    if on then
        local cc = classColor()
        if cc then return cc.r, cc.g, cc.b, a end
    end
    return c.r or 1, c.g or 1, c.b or 1, a
end

function NS.GetBarColor(unit)
    return resolveColor(unitSetting(unit, "barColor"),
        unitSetting(unit, "useClassColorBar"), GetPlayerClassColor)
end

function NS.GetBgColor(unit)
    return resolveColor(unitSetting(unit, "bgColor"),
        unitSetting(unit, "useClassColorBg"), GetBgClassColor)
end

function NS.GetBorderColor(unit)
    return resolveColor(unitSetting(unit, "borderColor"),
        unitSetting(unit, "useClassColorBorder"), GetPlayerClassColor)
end

--- The absorb amount's color. New surface, same three rules as the three above it.
function NS.GetFontColor(unit)
    return resolveColor(unitSetting(unit, "fontColor"),
        unitSetting(unit, "useClassColorText"), GetPlayerClassColor)
end

--- The whole frame's opacity, CLAMPED to the slider's own range.
---
--- The clamp is not belt and braces. This value comes out of SavedVariables, which a player can
--- hand-edit and an older profile can be holding anything in; `bar:SetAlpha(0)` is an invisible bar
--- with no error and no way to tell it from the addon having stopped working. Clamping to the same
--- 0.1 .. 1 the row advertises means the worst a bad value can do is look like the nearest legal
--- setting. A non-number reads as the default rather than raising inside a paint pass.
function NS.GetBarAlpha(unit)
    local v = tonumber(unitSetting(unit, "barAlpha"))
    if not v then return NS.unitDefaults.barAlpha end
    if v < 0.1 then return 0.1 end
    if v > 1 then return 1 end
    return v
end
