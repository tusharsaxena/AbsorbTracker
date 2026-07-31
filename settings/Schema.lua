local addonName, NS = ...

-- Single source of truth for every user-facing setting. Each settings/<page>.lua file populates
-- this array via NS.RegisterSchemaRows({...}); the panel renderer (LibKa0s-Options-1.0:
-- RenderSchema) and the slash dispatcher (/at list, /at get, /at set, /at reset) both walk it.
--
-- Adding a new option is one schema row — the AceGUI widget on the relevant sub-page and the
-- slash-command surface for that path are wired automatically.
--
-- Schema row shape:
--   {
--     path    = "barWidth",        -- key in db.profile (also /at set path)
--     page    = "bar",             -- which settings/<page>.lua renders it
--     group   = "Size",            -- section heading on the page (optional)
--     order   = 10,                -- render order within the group
--     type    = "bool"|"number"|"string"|"color",
--     label   = "Bar width",       -- widget label and /at list/get display
--     desc    = "...",             -- tooltip
--     default = 200,               -- used by /at reset and /at resetall
--     min, max, step,                                 -- number
--     values        = function() return {...} end,    -- string (select); k=v map
--     dialogControl = "LSM30_Statusbar",              -- string (LSM swatch dropdown)
--     hasAlpha      = true,                           -- color
--     onChange   = function(v) ... end,               -- defaults to UpdateBarAppearance
--     disabledIf = "useClassColorBar",                -- color only: greys out when sibling on
--     fmt        = "%.1f sec",                        -- /at list/get formatting hint
--     solo       = true,                              -- panel only: render alone in a row
--   }

NS.Schema = NS.Schema or {}

-- ---------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------

--- Append a list of schema rows to the global schema. Called once per settings/<page>.lua at
--- file-load time.
function NS.RegisterSchemaRows(rows)
    for _, row in ipairs(rows) do
        NS.Schema[#NS.Schema + 1] = row
    end
end

-- ---------------------------------------------------------------------
-- Lookup
-- ---------------------------------------------------------------------

function NS.FindSchemaRow(path)
    for _, row in ipairs(NS.Schema) do
        if row.path == path then return row end
    end
end

--- Rows for one page. `unit` (optional) filters to that unit's rows plus any unit-agnostic rows
--- (General's, which carry no `unit` field and always match). Omitting `unit` returns every
--- unit's rows — which is what RestoreDefaults / RestoreAllDefaults / `/at list` want.
function NS.SchemaForPage(pageKey, unit)
    local out = {}
    -- Track each group's first-seen registration index so groups stay in the order their rows
    -- were registered. Sorting purely on row.order would interleave groups (every group's
    -- order=10 row clustering before any order=20 row), which breaks the section-header layout.
    local groupIndex = {}
    for _, row in ipairs(NS.Schema) do
        if row.page == pageKey and (unit == nil or not row.unit or row.unit == unit) then
            out[#out + 1] = row
            local g = row.group or ""
            if groupIndex[g] == nil then
                groupIndex[g] = #out
            end
        end
    end
    table.sort(out, function(a, b)
        local ga, gb = groupIndex[a.group or ""], groupIndex[b.group or ""]
        if ga ~= gb then return ga < gb end
        return (a.order or 100) < (b.order or 100)
    end)
    return out
end

--- Split a unit page's rows into those that stay editable while mirrored (alwaysPerUnit — the
--- enable toggle) and the appearance rows the mirror hides. Pure; unit-tested.
function NS.PartitionUnitRows(rows)
    local perUnit, styled = {}, {}
    for _, row in ipairs(rows) do
        if row.alwaysPerUnit then
            perUnit[#perUnit + 1] = row
        else
            styled[#styled + 1] = row
        end
    end
    return perUnit, styled
end

-- ---------------------------------------------------------------------
-- Dotted-path walkers
-- ---------------------------------------------------------------------
--
-- Per-unit settings live at `units.<unit>.<key>`, so the single read/write seam has to walk a
-- path rather than index a flat table. Flat keys ("locked") pass through unchanged, so the three
-- globals keep working without a special case at every call site.

function NS.ResolvePath(tbl, path)
    if type(tbl) ~= "table" or type(path) ~= "string" then return nil end
    local node = tbl
    for segment in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[segment]
        if node == nil then return nil end
    end
    return node
end

function NS.SetPath(tbl, path, value)
    if type(tbl) ~= "table" or type(path) ~= "string" then return end
    local segments = {}
    for segment in path:gmatch("[^%.]+") do segments[#segments + 1] = segment end
    if #segments == 0 then return end
    local node = tbl
    for i = 1, #segments - 1 do
        local key = segments[i]
        if type(node[key]) ~= "table" then node[key] = {} end
        node = node[key]
    end
    node[segments[#segments]] = value
end

-- ---------------------------------------------------------------------
-- Read / write
-- ---------------------------------------------------------------------

local function defaultOnChange()
    if NS.bus then NS.bus:SendMessage(NS.MSG.APPEARANCE) end
end

local function fireOnChange(row, value)
    local fn = row.onChange or defaultOnChange
    fn(value)
end

--- Write a value for `path`, fire its onChange. Used by /at set, by /at reset, and by every
--- panel widget — single dispatch path so no code duplication between UI and CLI.
function NS.SetByPath(path, value)
    NS.SetSetting(path, value)
    local row = NS.FindSchemaRow(path)
    -- §10: log every settings mutation once, at this single write seam. Gate the whole line
    -- (including the value formatting) behind the debug flag so a ColorPicker drag — many writes
    -- per second — does zero string work when debug is off.
    if NS.State and NS.State.debug then
        NS.Debug("Set", "%s = %s", path, row and NS.FormatSchemaValue(row, value) or tostring(value))
    end
    if row then fireOnChange(row, value) end
end

--- Reset one row to its default. Used by /at reset <page> and /at resetall, plus the per-panel
--- Defaults button.
function NS.ApplyDefault(row)
    if row.default == nil then return end
    -- DeepCopy color tables so two profiles can't end up sharing the same nested table.
    local v = row.default
    if type(v) == "table" then
        local copy = {}
        for k, vv in pairs(v) do copy[k] = vv end
        v = copy
    end
    NS.SetSetting(row.path, v)
    fireOnChange(row, v)
end

-- ---------------------------------------------------------------------
-- /at list / /at get value formatting
-- ---------------------------------------------------------------------

-- Rendering a stored value for display is LibKa0s-Slash-1.0's, so `/at get`'s echo and the [Set]
-- debug line above can never disagree about how a colour or an empty string reads. Kept under this
-- name because the schema layer is where callers look for it; the fallback exists only for a build
-- with the library missing.
function NS.FormatSchemaValue(row, v)
    local lib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
    if lib then return lib.FormatValue(row, v) end
    if v == nil then return "nil" end
    return tostring(v)
end

-- ---------------------------------------------------------------------
-- Schema-shape validation
-- ---------------------------------------------------------------------
--
-- Run once at panel-registration time after every settings/<page>.lua has loaded its rows.
-- Catches misspelled page / type enum values, missing path, and (Ka0s standard §4.5) any row
-- whose `path` does NOT resolve against the defaults profile — a typo'd path would otherwise
-- silently read/write nothing. The validator only PRINTS; it never refuses to register.

local _validPages = {
    general = true, bar = true, border = true, font = true, profiles = true,
}
local _validTypes = {
    bool = true, number = true, string = true, color = true,
}

local function _printSchemaError(prefix, msg)
    local print = NS.Print
    if print then
        print("|cffff0000schema error|r: " .. prefix .. ": " .. msg)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cFF00FFFF[AT]|r |cffff0000schema error|r: " .. prefix .. ": " .. msg)
    end
end

--- Walk the assembled schema and surface any malformed row. Returns three counts for the test
--- harness to assert: shape `errors`, paths `resolved` against defaults.profile, and `missing`
--- paths (present rows whose path has no matching default).
function NS.ValidateSchema()
    local errors, resolved, missing = 0, 0, 0
    local defaults = (NS.defaults and NS.defaults.profile) or {}
    for i, row in ipairs(NS.Schema or {}) do
        local where = "row #" .. i .. " (" .. tostring(row.path or "<no path>") .. ")"
        if type(row) ~= "table" then
            _printSchemaError(where, "row is not a table")
            errors = errors + 1
        else
            local hasPath = type(row.path) == "string" and row.path ~= ""
            if not hasPath then
                _printSchemaError(where, "missing or empty `path`")
                errors = errors + 1
            end
            if not _validPages[row.page] then
                _printSchemaError(where, "invalid `page` = " .. tostring(row.page)
                    .. " (expected one of: general, bar, border, font, profiles)")
                errors = errors + 1
            end
            if not _validTypes[row.type] then
                _printSchemaError(where, "invalid `type` = " .. tostring(row.type)
                    .. " (expected one of: bool, number, string, color)")
                errors = errors + 1
            end
            -- §4.5: the path must resolve against the defaults profile. Profiles-page rows (if
            -- any) are AceDBOptions-supplied and exempt. Paths may be dotted (units.<unit>.<key>).
            if hasPath and row.page ~= "profiles" then
                if NS.ResolvePath(defaults, row.path) ~= nil then
                    resolved = resolved + 1
                else
                    _printSchemaError(where, "`path` does not resolve against defaults.profile")
                    missing = missing + 1
                end
            end
        end
    end
    return errors, resolved, missing
end

-- The type-aware value parser moved to LibKa0s-Slash-1.0 (`lib.ParseValue`): clamping, the
-- case-sensitive enum check, the 0-1 / 0-255 colour rescale and the nil-plus-reason failure
-- contract all live there, and settings/Slash.lua hands the library the schema rows to parse
-- against. Nothing here called it once the dispatcher was extracted, and a second copy of a parser
-- is precisely the drift the extraction exists to end.
