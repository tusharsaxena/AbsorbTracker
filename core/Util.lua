local addonName, NS = ...
NS.Util = NS.Util or {}
local Util = NS.Util

-- Secret-value guard. In combat, WoW protects combat-sensitive returns (e.g.
-- UnitGetTotalAbsorbs("player") and AbbreviateNumbers() of it) as "secret" values. A secret
-- survives tostring() AND the `..` operator (which silently propagates the secretness) but RAISES
-- `invalid value (secret) ... for 'concat'` the moment it reaches `table.concat`. Since every
-- chat and debug line here ends in a table.concat, an unguarded secret both spams a Lua error
-- AND — when it happens inside the repeating repaint ticker — kills the ticker so the bar freezes
-- until /reload.
--
-- Detection MUST probe the operation that actually rejects a secret: `table.concat`, NOT `..`.
-- `pcall(function() return v .. "" end)` reports a secret as *safe* (the operator doesn't raise),
-- which is the bug that let a secret slip through. Concat a one-element table — exactly what
-- NS.Print / NS.DebugPrint do downstream — so the probe fails on precisely what the real call
-- fails on. A public `issecretvalue()` exists as of 12.0, but this pcall probe is kept as a
-- version-agnostic detector that tests the exact operation (`table.concat`) that rejects a secret.
local function probeConcat(v) return table.concat({ v }) end
function NS.IsConcatSafe(v)
  return (pcall(probeConcat, v))
end

-- Concat-safe stringifier used by every line the addon emits. Ordinary values -> tostring(v);
-- an un-concatenable (secret) value -> the sentinel "<secret>", so the surrounding table.concat
-- can never raise. nil and booleans are handled up front — table.concat also rejects a boolean
-- element, but they are never secret, so they must not be masked. Real secrets are numbers/strings,
-- which the concat probe catches. (A bare table would also probe unsafe and render as "<secret>",
-- but no call site passes bare tables — every arg is a string/number log fragment.)
function NS.SafeToString(v)
  if v == nil then return "nil" end
  if type(v) == "boolean" then return tostring(v) end
  if NS.IsConcatSafe(v) then return tostring(v) end
  return "<secret>"
end

-- Every chat line from the addon carries the cyan [AT] prefix (Ka0s standard §7.4). Multiple
-- args are space-separated, mirroring print(). Files that emit chat do `local print = NS.Print`
-- so existing naked print(...) call sites keep the prefix without change.
function NS.Print(...)
  local n = select("#", ...)
  local parts = { NS.PREFIX }
  for i = 1, n do parts[i + 1] = NS.SafeToString((select(i, ...))) end
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage(table.concat(parts, " "))
  end
end
Util.print = NS.Print

-- Debug helper. Routes through the on-screen debug console (NS.Debug, core/DebugLog.lua) when
-- session debug is on; zero-cost (no allocation, no formatting) when off. Replaces the old
-- chat-based DebugPrint so debug spam never lands in the player's chat frame (§12). The first arg
-- is the console [tag] — the source event/function name, a trusted literal — and the remaining
-- message args pass through NS.SafeToString so a combat secret logs as "<secret>" instead of
-- erroring the concat.
function NS.DebugPrint(tag, ...)
  if not (NS.State and NS.State.debug and NS.Debug) then return end
  local n = select("#", ...)
  local parts = {}
  for i = 1, n do parts[i] = NS.SafeToString((select(i, ...))) end
  NS.Debug(tag, table.concat(parts, " "))
end
