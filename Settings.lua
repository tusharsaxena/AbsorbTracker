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

function AddonTable.GetBarColor()
    local c = AddonTable.GetSetting("barColor")
    return c.r, c.g, c.b, c.a
end

function AddonTable.GetBgColor()
    local c = AddonTable.GetSetting("bgColor")
    return c.r, c.g, c.b, c.a
end

function AddonTable.GetBorderColor()
    local c = AddonTable.GetSetting("borderColor")
    return c.r, c.g, c.b, c.a
end
