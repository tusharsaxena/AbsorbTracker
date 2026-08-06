local addonName, NS = ...
NS.Compat = NS.Compat or {}
local Compat = NS.Compat

-- Retail-only addon: no game-flavor branching. Every deprecated/varying API is gated by a
-- direct C_*/global presence check so a shim degrades to nil when its API is absent — never
-- by reading a game-flavor project id (Ka0s standard compat). This is the ONLY file that calls
-- the deprecated metadata API; every other module routes through Compat.GetAddOnMetadata.

-- Addon metadata (Title / Version / Notes …). C_AddOns is the Midnight home for the call;
-- the bare _G.GetAddOnMetadata is the pre-11.0 fallback.
function Compat.GetAddOnMetadata(name, field)
  if C_AddOns and C_AddOns.GetAddOnMetadata then
    return C_AddOns.GetAddOnMetadata(name, field)
  end
  if GetAddOnMetadata then
    return GetAddOnMetadata(name, field)
  end
  return nil
end
