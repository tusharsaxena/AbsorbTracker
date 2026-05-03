-- AbsorbTracker: Schema module
--
-- Single source of truth for every user-facing setting. Each Options/*.lua
-- file populates this array via AddonTable.RegisterSchemaRows({...}); the
-- panel renderer (OptionsPanel.lua: Helpers.RenderSchema) and the slash
-- dispatcher (/at list, /at get, /at set, /at reset) both walk it.
--
-- Adding a new option is one schema row — the AceGUI widget on the
-- relevant sub-page and the slash-command surface for that path are
-- wired automatically.
--
-- Schema row shape:
--   {
--     path    = "barWidth",        -- key in db.profile (also /at set path)
--     page    = "bar",             -- which Options/<page>.lua renders it
--     group   = "Size",            -- section heading on the page (optional)
--     order   = 10,                -- render order within the group
--     type    = "bool"|"number"|"string"|"color",
--     label   = "Bar width",       -- widget label and /at list/get display
--     desc    = "...",             -- tooltip
--     default = 200,               -- used by /at reset and /at resetall
--     -- type-specific:
--     min, max, step,                                 -- number
--     values        = function() return {...} end,    -- string (select); k=v map
--     dialogControl = "LSM30_Statusbar",              -- string (LSM swatch dropdown)
--     hasAlpha      = true,                           -- color
--     -- behavior:
--     onChange   = function(v) ... end,               -- defaults to UpdateBarAppearance
--     inverse    = true,                              -- bool only: widget shows !value
--     disabledIf = "useClassColorBar",                -- color only: greys out when sibling toggle is on
--     fmt        = "%.1f sec",                        -- /at list/get formatting hint
--     solo       = true,                              -- panel only: render alone in a row
--   }

local AddonName, AddonTable = ...

AddonTable.Schema = AddonTable.Schema or {}

-- ---------------------------------------------------------------------
-- Registration
-- ---------------------------------------------------------------------

--- Append a list of schema rows to the global schema. Called once per
--- Options/*.lua at file-load time.
function AddonTable.RegisterSchemaRows(rows)
    for _, row in ipairs(rows) do
        AddonTable.Schema[#AddonTable.Schema + 1] = row
    end
end

-- ---------------------------------------------------------------------
-- Lookup
-- ---------------------------------------------------------------------

function AddonTable.FindSchemaRow(path)
    for _, row in ipairs(AddonTable.Schema) do
        if row.path == path then return row end
    end
end

function AddonTable.SchemaForPage(pageKey)
    local out = {}
    for _, row in ipairs(AddonTable.Schema) do
        if row.page == pageKey then out[#out + 1] = row end
    end
    table.sort(out, function(a, b)
        return (a.order or 100) < (b.order or 100)
    end)
    return out
end

-- ---------------------------------------------------------------------
-- Read / write
-- ---------------------------------------------------------------------

local function defaultOnChange()
    if AddonTable.UpdateBarAppearance then AddonTable.UpdateBarAppearance() end
end

local function fireOnChange(row, value)
    local fn = row.onChange or defaultOnChange
    fn(value)
end

--- Write a value for `path`, fire its onChange. Used by /at set, by
--- /at reset, and by every panel widget — single dispatch path so no
--- code duplication between UI and CLI.
function AddonTable.SetByPath(path, value)
    AddonTable.SetSetting(path, value)
    local row = AddonTable.FindSchemaRow(path)
    if row then fireOnChange(row, value) end
end

--- Reset one row to its default. Used by /at reset <page> and
--- /at resetall, plus the per-panel Defaults button.
function AddonTable.ApplyDefault(row)
    if row.default == nil then return end
    -- DeepCopy color tables so two profiles can't end up sharing the
    -- same nested table (RGBA tables are the only nested defaults today
    -- but anything deeper would silently leak).
    local v = row.default
    if type(v) == "table" then
        local copy = {}
        for k, vv in pairs(v) do copy[k] = vv end
        v = copy
    end
    AddonTable.SetSetting(row.path, v)
    fireOnChange(row, v)
end

-- ---------------------------------------------------------------------
-- /at list / /at get value formatting
-- ---------------------------------------------------------------------

function AddonTable.FormatSchemaValue(row, v)
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
-- Run once at panel-registration time after every Options/*.lua file
-- has finished loading. Catches misspelled `page` / `type` enum values,
-- missing `path`, and other schema-row typos that would otherwise
-- silently fail to render or fail to wire into the slash command.
--
-- The validator only PRINTS errors — it never refuses to register.
-- A broken row is an addon-author bug; the right user-visible behaviour
-- is "the option you wanted is missing AND a chat error tells you why,"
-- not "the entire settings panel refuses to register."

local _validPages = {
    general = true, bar = true, border = true, font = true, profiles = true,
}
local _validTypes = {
    bool = true, number = true, string = true, color = true,
}

local function _printSchemaError(prefix, msg)
    local print = AddonTable.Print
    if print then
        print("|cffff0000schema error|r: " .. prefix .. ": " .. msg)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cFF00FFFF[AT]|r |cffff0000schema error|r: " .. prefix .. ": " .. msg)
    end
end

--- Walk the assembled schema and surface any malformed row. Called from
--- CreateOptionsPanel after all Options/*.lua files have loaded their
--- rows. Returns the count of errors found (always called for side
--- effects; the count is exposed for future debug use).
function AddonTable.ValidateSchema()
    local errors = 0
    for i, row in ipairs(AddonTable.Schema or {}) do
        local where = "row #" .. i .. " (" .. tostring(row.path or "<no path>") .. ")"
        if type(row) ~= "table" then
            _printSchemaError(where, "row is not a table")
            errors = errors + 1
        else
            if type(row.path) ~= "string" or row.path == "" then
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
        end
    end
    return errors
end

-- ---------------------------------------------------------------------
-- /at set type-aware parser
-- ---------------------------------------------------------------------
--
-- Convert a string tail (everything after the path on the slash command
-- line) into a typed value matching row.type. Returns (value, errMsg).
-- On parse failure, errMsg is a human-readable explanation suitable
-- for chat output.

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

function AddonTable.ParseSchemaValue(row, text)
    local args = {}
    for w in (text or ""):gmatch("%S+") do args[#args + 1] = w end

    if row.type == "bool"   then return parseBool(args)        end
    if row.type == "number" then return parseNumber(args, row) end
    if row.type == "string" then return parseString(args, row) end
    if row.type == "color"  then return parseColor(args)       end
    return nil, "unknown setting type '" .. tostring(row.type) .. "'"
end
