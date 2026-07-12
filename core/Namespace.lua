local addonName, NS = ...

-- Shared namespace bootstrap. Runs early so common metadata and hot-path caches exist
-- regardless of load order. NS is the addon's single private table (Ka0s standard §4.1);
-- we never create _G[addonName].
NS.name = addonName
NS.version = "1.8.0"

-- Cyan [AT] chat tag — one shared constant so every module prints identically (§7.4).
NS.PREFIX = "|cFF00FFFF[AT]|r"

-- Hot-path math/string caches used by the bar paint path (Display / Timer).
NS.floor  = math.floor
NS.max    = math.max
NS.format = format or string.format
