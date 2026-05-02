-- AbsorbTracker: Options/Profiles.lua
--
-- Profiles sub-page. Defers to AceDBOptions-3.0 which builds the
-- standard create/copy/reset/delete UI plus the per-character/class/
-- realm/faction/default scope buttons. Optional dependency: if
-- AceDBOptions isn't loaded the page is skipped silently.

local AddonName, AddonTable = ...

local function build()
    if not LibStub then return nil end
    local AceDBOptions = LibStub("AceDBOptions-3.0", true)
    if not AceDBOptions then return nil end
    if not AddonTable.db then return nil end
    return AceDBOptions:GetOptionsTable(AddonTable.db)
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("profiles", "Profiles", build)
end
