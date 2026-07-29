local addonName, NS = ...

-- Single source of truth for every user-facing setting. Each settings/<page>.lua file populates
-- this array via NS.RegisterSchemaRows({...}); the panel renderer (settings/Widgets.lua:
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
--     inverse    = true,                              -- bool only: widget shows !value
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

function NS.FormatSchemaValue(row, v)
    if v == nil then return "nil" end
    if row.type == "color" and type(v) == "table" then
        return ("{%.2f, %.2f, %.2f, %.2f}"):format(
            v.r or 0, v.g or 0, v.b or 0, v.a or 1)
    end
    if row.type == "number" then
        if row.fmt then return row.fmt:format(v) end
        return tostring(v)
    end
    if row.type == "bool" then
        return v and "true" or "false"
    end
    if row.type == "string" and (v == nil or v == "") then
        return "(none)"
    end
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

-- ---------------------------------------------------------------------
-- /at set type-aware parser
-- ---------------------------------------------------------------------

local function parseBool(args)
    local s = (args[1] or ""):lower()
    if s == "true"  or s == "1" or s == "on"  or s == "yes" then return true  end
    if s == "false" or s == "0" or s == "off" or s == "no"  then return false end
    return nil, "expected true/false/on/off/1/0/yes/no"
end

local function parseNumber(args, row)
    local n = tonumber(args[1])
    if not n then return nil, "expected a number" end
    if row.min then n = math.max(row.min, n) end
    if row.max then n = math.min(row.max, n) end
    return n
end

local function allowedValues(row)
    local v = type(row.values) == "function" and row.values() or row.values or {}
    local keys = {}
    for k in pairs(v) do keys[#keys + 1] = k end
    table.sort(keys)
    return keys
end

local function parseString(args, row)
    local v = args[1]
    if not v then return nil, "expected a value" end
    local allowed = allowedValues(row)
    for _, a in ipairs(allowed) do
        if a == v then return v end
    end
    return nil, "allowed values: " .. table.concat(allowed, ", ")
end

local function parseColor(args)
    local r, g, b = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    local a = tonumber(args[4]) or 1
    if not (r and g and b) then return nil, "expected: r g b [a] (each 0-1 or 0-255)" end
    if r > 1 or g > 1 or b > 1 then
        r, g, b = r / 255, g / 255, b / 255
    end
    if a > 1 then a = a / 255 end
    local function clamp01(n) return math.max(0, math.min(1, n)) end
    return { r = clamp01(r), g = clamp01(g), b = clamp01(b), a = clamp01(a) }
end

function NS.ParseSchemaValue(row, text)
    local args = {}
    for w in (text or ""):gmatch("%S+") do args[#args + 1] = w end

    if row.type == "bool"   then return parseBool(args)        end
    if row.type == "number" then return parseNumber(args, row) end
    if row.type == "string" then return parseString(args, row) end
    if row.type == "color"  then return parseColor(args)       end
    return nil, "unknown setting type '" .. tostring(row.type) .. "'"
end
