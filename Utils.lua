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
