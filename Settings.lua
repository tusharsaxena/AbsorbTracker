-- AbsorbTracker: Settings module - Database and LSM functions
local AddonName, AddonTable = ...

local flatDefaults = AddonTable.flatDefaults

-- Database reference (set on PLAYER_LOGIN)
AddonTable.db = nil

-- Cached LibSharedMedia reference
local LSM

-- Fallback paths
AddonTable.FALLBACK_TEXTURE = "Interface\\TargetingFrame\\UI-StatusBar"
AddonTable.FALLBACK_BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
AddonTable.FALLBACK_FONT = "Fonts\\FRIZQT__.TTF"

-- LibSharedMedia support (fetched once, then cached)
function AddonTable.GetLSM()
    if LSM then return LSM end
    if LibStub then
        LSM = LibStub("LibSharedMedia-3.0", true)
    end
    return LSM
end

-- Clear LSM cache (called after PLAYER_LOGIN to pick up late-loading libs)
function AddonTable.ClearLSMCache()
    LSM = nil
end

-- Generic setting getter with fallback
function AddonTable.GetSetting(key)
    local db = AddonTable.db
    if db and db.profile then
        local val = db.profile[key]
        if val == nil then
            return flatDefaults[key]
        end
        return val
    end
    return flatDefaults[key]
end

-- Generic setting setter
function AddonTable.SetSetting(key, value)
    local db = AddonTable.db
    if db and db.profile then
        db.profile[key] = value
        if key == "updateInterval" then
            AddonTable.DebugPrint("SetSetting updateInterval =", value, "at time:", AddonTable.format("%.3f", GetTime()))
        end
    elseif key == "updateInterval" then
        AddonTable.DebugPrint("SetSetting FAILED for updateInterval - db or db.profile is nil")
    end
end

function AddonTable.GetBarTexture()
    local lsm = AddonTable.GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", AddonTable.GetSetting("barTexture"))
        if texture then return texture end
    end
    return AddonTable.FALLBACK_TEXTURE
end

function AddonTable.GetBgTexture()
    local lsm = AddonTable.GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", AddonTable.GetSetting("bgTexture"))
        if texture then return texture end
    end
    return AddonTable.FALLBACK_TEXTURE
end

function AddonTable.GetBorder()
    local lsm = AddonTable.GetLSM()
    if lsm then
        local border = lsm:Fetch("border", AddonTable.GetSetting("border"))
        if border then return border end
    end
    return AddonTable.FALLBACK_BORDER
end

function AddonTable.GetFont()
    local lsm = AddonTable.GetLSM()
    if lsm then
        local font = lsm:Fetch("font", AddonTable.GetSetting("font"))
        if font then return font end
    end
    return AddonTable.FALLBACK_FONT
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

function AddonTable.GetBarColor()
    local c = AddonTable.GetSetting("barColor")
    if AddonTable.GetSetting("useClassColorBar") then
        local cc = GetPlayerClassColor()
        return cc.r, cc.g, cc.b, c.a
    end
    return c.r, c.g, c.b, c.a
end

function AddonTable.GetBgColor()
    local c = AddonTable.GetSetting("bgColor")
    if AddonTable.GetSetting("useClassColorBg") then
        local cc = GetBgClassColor()
        return cc.r, cc.g, cc.b, c.a
    end
    return c.r, c.g, c.b, c.a
end

function AddonTable.GetBorderColor()
    local c = AddonTable.GetSetting("borderColor")
    if AddonTable.GetSetting("useClassColorBorder") then
        local cc = GetPlayerClassColor()
        return cc.r, cc.g, cc.b, c.a
    end
    return c.r, c.g, c.b, c.a
end
