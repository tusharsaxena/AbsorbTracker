local addonName, NS = ...
NS.Util = NS.Util or {}
local Util = NS.Util

-- Every chat line from the addon carries the cyan [AT] prefix (Ka0s standard §7.4). Multiple
-- args are space-separated, mirroring print(). Files that emit chat do `local print = NS.Print`
-- so existing naked print(...) call sites keep the prefix without change.
function NS.Print(...)
  local n = select("#", ...)
  local parts = { NS.PREFIX }
  for i = 1, n do parts[i + 1] = tostring((select(i, ...))) end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
  end
end
Util.print = NS.Print

-- Debug helper. Routes through the on-screen debug console (NS.Debug, core/DebugLog.lua) when
-- session debug is on; zero-cost (no allocation, no formatting) when off. Replaces the old
-- chat-based DebugPrint so debug spam never lands in the player's chat frame (§12).
function NS.DebugPrint(...)
  if not (NS.State and NS.State.debug and NS.Debug) then return end
  local n = select("#", ...)
  local parts = {}
  for i = 1, n do parts[i] = tostring((select(i, ...))) end
  NS.Debug("AT", table.concat(parts, " "))
end
