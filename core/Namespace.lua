local addonName, NS = ...

-- Shared namespace bootstrap. Runs early so common metadata and hot-path caches exist
-- regardless of load order. NS is the addon's single private table (Ka0s standard architecture-§1);
-- we never create _G[addonName].
NS.name = addonName
NS.version = "1.9.0"

-- Cyan [AT] chat tag — one shared constant so every module prints identically (slash-commands-§4).
NS.PREFIX = "|cFF00FFFF[AT]|r"

-- Hot-path math caches used by the bar paint path (Display / Timer).
NS.floor  = math.floor
NS.max    = math.max
