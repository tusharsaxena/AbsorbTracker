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

-- Generic setting getter with fallback to the flat defaults when a key or the DB is absent.
function NS.GetSetting(key)
    local db = NS.db
    if db and db.profile then
        local val = db.profile[key]
        if val == nil then
            return NS.flatDefaults[key]
        end
        return val
    end
    return NS.flatDefaults[key]
end

-- Generic setting setter.
function NS.SetSetting(key, value)
    local db = NS.db
    if db and db.profile then
        db.profile[key] = value
    end
end

function NS.GetBarTexture()
    local lsm = NS.GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", NS.GetSetting("barTexture"))
        if texture then return texture end
    end
    return C.FALLBACK_TEXTURE
end

function NS.GetBgTexture()
    local lsm = NS.GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", NS.GetSetting("bgTexture"))
        if texture then return texture end
    end
    return C.FALLBACK_TEXTURE
end

function NS.GetBorder()
    local lsm = NS.GetLSM()
    if lsm then
        local border = lsm:Fetch("border", NS.GetSetting("border"))
        if border then return border end
    end
    return C.FALLBACK_BORDER
end

function NS.GetFont()
    local lsm = NS.GetLSM()
    if lsm then
        local font = lsm:Fetch("font", NS.GetSetting("font"))
        if font then return font end
    end
    return C.FALLBACK_FONT
end

local playerClassColor
local function GetPlayerClassColor()
    if not playerClassColor then
        local _, classFilename = UnitClass("player")
        if classFilename then
            local color = C_ClassColor.GetClassColor(classFilename)
            if color then
                playerClassColor = { r = color.r, g = color.g, b = color.b }
            end
        end
        if not playerClassColor then
            playerClassColor = { r = 1, g = 1, b = 1 }
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
        else
            playerBgClassColor = { r = 1, g = 1, b = 1 }
        end
    end
    return playerBgClassColor
end

function NS.GetBarColor()
    local c = NS.GetSetting("barColor")
    if NS.GetSetting("useClassColorBar") then
        local cc = GetPlayerClassColor()
        return cc.r, cc.g, cc.b, c.a
    end
    return c.r, c.g, c.b, c.a
end

function NS.GetBgColor()
    local c = NS.GetSetting("bgColor")
    if NS.GetSetting("useClassColorBg") then
        local cc = GetBgClassColor()
        return cc.r, cc.g, cc.b, c.a
    end
    return c.r, c.g, c.b, c.a
end

function NS.GetBorderColor()
    local c = NS.GetSetting("borderColor")
    if NS.GetSetting("useClassColorBorder") then
        local cc = GetPlayerClassColor()
        return cc.r, cc.g, cc.b, c.a
    end
    return c.r, c.g, c.b, c.a
end
