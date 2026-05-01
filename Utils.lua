-- AbsorbTracker: Utils module - Debug functions and helpers
local AddonName, AddonTable = ...

-- Debug flag
AddonTable.DEBUG = false

-- Every chat message from the addon goes through this helper so it gets the cyan [AT] prefix.
local PREFIX = "|cFF00FFFF[AT]|r"
function AddonTable.Print(...)
    print(PREFIX, ...)
end

-- Shadow the global `print` for this file so naked print(...) calls below get the prefix too.
local print = AddonTable.Print

-- Debug print function
function AddonTable.DebugPrint(...)
    if AddonTable.DEBUG then
        print(...)
    end
end

-- Helper function to print LSM list
function AddonTable.PrintLSMList(mediaType, dbKey)
    local lsm = AddonTable.GetLSM()
    if not lsm then
        print("LibSharedMedia not found. Install LibSharedMedia-3.0 to use custom " .. mediaType .. ".")
        return false
    end
    print("Available " .. mediaType .. "s:")
    local list = lsm:List(mediaType)
    local current = AddonTable.GetSetting(dbKey)
    for _, name in ipairs(list) do
        local marker = current == name and " (current)" or ""
        print("  " .. name .. marker)
    end
    return true
end

-- Helper to parse color from string (handles 0-255 or 0-1 formats)
function AddonTable.ParseColor(arg)
    local r, g, b, a = arg:match("^(%d+%.?%d*)%s+(%d+%.?%d*)%s+(%d+%.?%d*)%s*(%d*%.?%d*)$")
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    if not (r and g and b) then return nil end
    a = tonumber(a) or 0.8
    -- Convert from 0-255 to 0-1 if values are > 1
    if r > 1 or g > 1 or b > 1 then
        r, g, b = r / 255, g / 255, b / 255
    end
    if a > 1 then a = a / 255 end
    return { r = r, g = g, b = b, a = a }
end
