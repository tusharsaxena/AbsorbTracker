-- AbsorbTracker: Schema module
--
-- Single source of truth for every user-facing setting. Each Options/*.lua
-- file populates this array via AddonTable.RegisterSchemaRows({...}); the
-- panel renderer (BuildPageOptions) and the slash dispatcher
-- (/at list, /at get, /at set, /at reset) both walk it.
--
-- Adding a new option is one schema row — the AceConfig widget on the
-- relevant sub-page and the slash-command surface for that path are
-- wired automatically.
--
-- Schema row shape:
--   {
--     path    = "barWidth",        -- key in db.profile (also /at set path)
--     page    = "bar",             -- which Options/<page>.lua renders it
--     group   = "Size",            -- inline group label within the page (optional)
--     order   = 10,                -- render order within the group
--     type    = "bool"|"number"|"string"|"color",
--     label   = "Bar Width",       -- widget label and /at list/get display
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

function AddonTable.GetByPath(path)
    return AddonTable.GetSetting(path)
end

--- Write a value for `path`, fire its onChange. Used by /at set and by
--- /at reset; the panel widgets go through their own AceConfig set
--- callback (which calls SetByPath internally so behaviour stays
--- consistent).
function AddonTable.SetByPath(path, value)
    AddonTable.SetSetting(path, value)
    local row = AddonTable.FindSchemaRow(path)
    if row then fireOnChange(row, value) end
end

--- Reset one row to its default. Used by /at reset <page> and
--- /at resetall.
function AddonTable.ApplyDefault(row)
    if row.default == nil then return end
    -- DeepCopy color tables so two profiles can't end up sharing the
    -- same nested table (RGBA arrays are the only nested defaults today
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
-- AceConfig options-table builder
-- ---------------------------------------------------------------------
--
-- BuildPageOptions assembles a full AceConfig options table for one page
-- from its schema rows. Inline groups are created on demand for each
-- distinct row.group; rows without a group land directly under the page
-- root. Within a group, rows render in row.order then registration order.

local function getColor(path)
    local c = AddonTable.GetSetting(path) or {}
    return c.r or 1, c.g or 1, c.b or 1, c.a or 1
end

local function setColor(row, r, g, b, a)
    AddonTable.SetSetting(row.path, { r = r, g = g, b = b, a = a })
    fireOnChange(row, AddonTable.GetSetting(row.path))
end

local function buildEntry(row)
    local entry = {
        order = row.order or 100,
        name  = row.label or row.path,
        desc  = row.desc,
        width = row.width or "full",
    }

    if row.type == "bool" then
        entry.type = "toggle"
        if row.inverse then
            entry.get = function() return not AddonTable.GetSetting(row.path) end
            entry.set = function(_, v)
                AddonTable.SetSetting(row.path, not v)
                fireOnChange(row, AddonTable.GetSetting(row.path))
            end
        else
            entry.get = function() return AddonTable.GetSetting(row.path) and true or false end
            entry.set = function(_, v)
                AddonTable.SetSetting(row.path, v and true or false)
                fireOnChange(row, v)
            end
        end

    elseif row.type == "number" then
        entry.type    = "range"
        entry.min     = row.min
        entry.max     = row.max
        entry.step    = row.step
        entry.bigStep = row.step
        entry.get = function() return AddonTable.GetSetting(row.path) end
        entry.set = function(_, v)
            AddonTable.SetSetting(row.path, v)
            fireOnChange(row, v)
        end

    elseif row.type == "string" then
        entry.type   = "select"
        entry.values = row.values or {}
        if row.dialogControl then entry.dialogControl = row.dialogControl end
        if row.sorting then entry.sorting = row.sorting end
        entry.get = function() return AddonTable.GetSetting(row.path) end
        entry.set = function(_, v)
            AddonTable.SetSetting(row.path, v)
            fireOnChange(row, v)
        end

    elseif row.type == "color" then
        entry.type     = "color"
        entry.hasAlpha = row.hasAlpha and true or false
        entry.get = function() return getColor(row.path) end
        entry.set = function(_, r, g, b, a) setColor(row, r, g, b, a) end
        if row.disabledIf then
            entry.disabled = function() return AddonTable.GetSetting(row.disabledIf) end
        end
    end

    if row.disabled then
        -- Caller-provided disabled callback (rare). We OR with disabledIf
        -- so both can apply; in practice only one is used.
        local existing = entry.disabled
        entry.disabled = function()
            return (existing and existing()) or row.disabled()
        end
    end

    return entry
end

--- Assemble an AceConfig options table for one page. Returned table is
--- ready to hand to AceConfig:RegisterOptionsTable.
function AddonTable.BuildPageOptions(pageKey, pageName)
    local rows = AddonTable.SchemaForPage(pageKey)

    local args  = {}
    local groupOrder = {}
    local groups = {}
    local nextStandaloneOrder = 1
    local nextGroupOrder      = 1

    for _, row in ipairs(rows) do
        if row.group then
            local g = groups[row.group]
            if not g then
                g = {
                    type   = "group",
                    inline = true,
                    name   = row.group,
                    order  = nextGroupOrder,
                    args   = {},
                }
                nextGroupOrder = nextGroupOrder + 10
                groups[row.group] = g
                groupOrder[#groupOrder + 1] = row.group
            end
            g.args[row.path] = buildEntry(row)
        else
            local entry = buildEntry(row)
            entry.order = entry.order or nextStandaloneOrder
            nextStandaloneOrder = nextStandaloneOrder + 10
            args[row.path] = entry
        end
    end

    for _, name in ipairs(groupOrder) do
        args[name] = groups[name]
    end

    return {
        name = pageName or pageKey,
        type = "group",
        args = args,
    }
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
