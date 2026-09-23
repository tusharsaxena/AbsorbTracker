local _, NS = ...

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
--     page    = "appearance",      -- which settings/<page>.lua renders it
--     group   = "Size",            -- the page's TAB this row belongs to (options-ui-§13); tabs are
--                                  -- drawn in the order their first row was registered
--     order   = 10,                -- render order within the group
--     type    = "bool"|"number"|"string"|"color",
--     subgroup = "Border",         -- a heading INSIDE a tab, for a tab that mixes control kinds
--                                  -- (options-ui-§7). General's Bars tab is the one that does:
--                                  -- "Tracked units" over the three enable toggles and "Updates"
--                                  -- over the throttle (settings/General.lua). A subgroup
--                                  -- repeating its tab's own name is forbidden
--     label   = "Bar width",       -- widget label and /at list/get display
--     tooltip = "...",             -- tooltip body. `desc` is the older spelling and still read --
--                                  -- the flow engine answers `row.tooltip or row.desc` -- so the
--                                  -- composed rows carry `tooltip` and the hand-written ones `desc`
--     default = 200,               -- used by /at reset and /at resetall
--     min, max, step,                                 -- number
--     values        = function() return {...} end,    -- string (select); k=v map
--     dialogControl = "LSM30_Statusbar",              -- string (LSM swatch dropdown)
--     hasAlpha      = true,                           -- color
--     classColorSource = "unit"|"player",             -- color pair: WHOSE class this surface means
--     classColorUnit   = "target",                    -- ... and which unit, when it is "unit"
--     onChange   = function(v) ... end,               -- defaults to UpdateBarAppearance
--     fmt        = "%.1f sec",                        -- /at list/get formatting hint
--     solo       = true,                              -- panel only: render alone in the LEFT HALF
--     startsLine = true,                              -- panel only: flush the pending line first,
--                                                     -- so a declared pair cannot be split
--     sessionOnly = true,                             -- value is NOT in the profile; see
--                                                     -- the row carries its own get / set
--     skipRender  = true,                             -- keep it in the schema; the host draws it
--   }
--
-- NO ROW CARRIES `disabledIf`, and no color row ever may (options-ui-§17, anti-pattern #74): a
-- swatch is still read for its ALPHA while its class-color companion is on, so graying it would
-- tell the player something untrue. The field is the library's and still works; this addon simply
-- does not ask for it.

NS.Schema = NS.Schema or {}

-- ---------------------------------------------------------------------
-- The runtime: LibKa0s-Schema-1.0, or the host's degradation stub
-- ---------------------------------------------------------------------
--
-- This file is the major's setup file. The ROWS are ours: the page files register them, and every
-- path, default, widget and onChange is this addon's. The MACHINERY around them is the library's
-- (libs/LibKa0s/Schema.lua; contract in LibKa0s docs/api/Schema/version-1-docs.md): the dotted-path
-- walkers, the path index, the single write seam (architecture-§5), the bulk bracket
-- (debug-logging-§10), the profile reset's changed-row count, and the load-time shape check. Each
-- of those used to be written out here, and eight sibling addons carried their own copy.
--
-- The public names below are the ones every caller already used, bound to the instance's members,
-- so no call site moved: NS.SetByPath, NS.FindSchemaRow, NS.RegisterSchemaRows, NS.ApplyDefault,
-- NS.Bulk, NS.ResolvePath / NS.SetPath, the reset count trio and NS.ValidateSchema.

--- The degradation stub (LibKa0s docs/api/Schema/version-2-docs.md, "The degradation stub"). It
--- keeps pace with the major's minor 2: SetMany (the all-or-nothing batch), row.normalize, the
--- instance id reaching a row's own get and ApplyDefault, and the writeThrough store -- the
--- descriptor's list of row-less paths it stores raw and announces with a synthetic row.
---
--- WRITE-COMPLETING AND LOG-SILENT, and a deliberate, documented duplication. This major is not
--- reached only by the panel and the CLI, which a library-less build has lost anyway: the repaint
--- pass reads settings through it, and three HOST writers write through it on the degraded path --
--- the host verbs (settings/Slash.lua), the Options stub's Reset All (settings/OptionsSetup.lua)
--- and the combat re-lock (core/AbsorbTracker.lua). A stub that refused a write would leave all
--- three dead on exactly the install this exists for (slash-commands-§1, options-ui-§1; anti-pattern
--- #56 shape 2). options-ui-§1 names this shape, the RUNTIME-COMPLETING stub, and ties it to this
--- major alone.
---
--- It completes what a player can observe -- reads, writes (one at a time or as a batch), the
--- row's reaction, the announce and the sweep veto -- and not what only feeds the debug console:
--- the [Set] line, the bracket's tally and the reset count. The degraded DebugLog stub
--- (core/DebugLogSetup.lua) discards those lines, so the degraded build has nowhere to show one. It is the reference stub the library's own suite pins
--- against a live instance, whole: tests/test_surface_parity.lua holds it to the same surface.
local function HostSchemaStub()
    local stubLib = {}
    local function copy(v)
        if type(v) ~= "table" then return v end
        local out = {}
        for k, x in pairs(v) do out[k] = copy(x) end
        return out
    end
    function stubLib.SplitPath(path)
        local parts = {}
        if path ~= nil then
            for seg in tostring(path):gmatch("[^%.]+") do parts[#parts + 1] = seg end
        end
        return parts
    end
    local function partsOf(p) return type(p) == "table" and p or stubLib.SplitPath(p) end
    function stubLib.Read(root, p, first)
        local parts, node = partsOf(p), root
        first = first or 1
        if type(root) ~= "table" or #parts < first then return nil end
        for i = first, #parts do
            if type(node) ~= "table" then return nil end
            node = node[parts[i]]
        end
        return node
    end
    function stubLib.Write(root, p, value, first)
        local parts, node = partsOf(p), root
        first = first or 1
        if type(root) ~= "table" or #parts < first then return end
        for i = first, #parts - 1 do
            if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
            node = node[parts[i]]
        end
        node[parts[#parts]] = value
    end
    function stubLib.SameValue(a, b)
        if a == b then return true end
        if type(a) ~= "table" or type(b) ~= "table" then return false end
        for k, v in pairs(a) do if not stubLib.SameValue(v, b[k]) then return false end end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end

    -- Colon-called like every major's constructor (`SchemaLib:New{...}`); the stub needs no self.
    function stubLib.New(_, d)
        local S, depth = {}, 0
        local rows = d.rows
        -- writeThrough (since 2): one synthetic row per listed path, built here once and handed
        -- out by identity. It has no validate, normalize, set or onChange, so the seam below stores
        -- it raw and reacts to nothing; `row.writeThrough` is how the host's announce tells it apart.
        local through = {}
        if type(d.writeThrough) == "table" then
            for _, p in ipairs(d.writeThrough) do
                if type(p) == "string" then through[p] = { path = p, writeThrough = true } end
            end
        end
        local function resolve(parts, id)
            if type(d.resolveRoot) ~= "function" then return nil end
            return d.resolveRoot(parts, id)
        end
        function S.AllRows() return rows end
        function S.FindRow(path)
            if type(path) ~= "string" then return nil end
            for _, row in ipairs(rows) do
                if type(row) == "table" and row.path == path then return row end
            end
        end
        -- The row a write goes through: the real row, else a listed path's synthetic one. A path
        -- with a row always takes the row; FindRow never answers a synthetic row.
        local function writeRow(path)
            local row = S.FindRow(path)
            if row then return row end
            if type(path) == "string" then return through[path] end
        end
        function S.AddRows(list, at)
            if type(list) ~= "table" then return 0 end
            at = type(at) == "number" and math.floor(at) or #rows + 1
            if at > #rows + 1 then at = #rows + 1 elseif at < 1 then at = 1 end
            for i, row in ipairs(list) do table.insert(rows, at + i - 1, row) end
            return #list
        end
        function S.Reindex() end
        function S.Get(path, id)
            local row = S.FindRow(path)
            if row and type(row.get) == "function" then return row.get(id) end
            if type(path) ~= "string" or (row and row.sessionOnly) then return nil end
            local parts = stubLib.SplitPath(path)
            local root, first = resolve(parts, id)
            if type(root) ~= "table" then return nil end
            return stubLib.Read(root, parts, first)
        end
        -- validate, then normalize (since 2): the value to store, or `false, err, why`.
        local function checkValue(row, path, value, rid)
            if type(row.validate) == "function" then
                local ok, why = row.validate(value, rid)
                if not ok then return false, "AbsorbTracker: invalid value for " .. path, why end
            end
            if type(row.normalize) == "function" then
                local out, why = row.normalize(value, rid)
                if out == nil then return false, "AbsorbTracker: invalid value for " .. path, why end
                value = out
            end
            return true, value
        end
        -- Everything the seam checks before it stores, shared by Set and SetMany so a batch refuses
        -- on exactly the rules a single write does: resolve, validate, normalize, the missing root.
        -- Answers `true, prep`, or `false, err, why, withWhy` with nothing stored. `withWhy` keeps
        -- the answer count: `false, err, why` for a bad value, `false, err` for a missing root.
        local function prepareWrite(row, path, value, id)
            local stored = type(row.set) ~= "function" and not row.sessionOnly
            local prep = { row = row, path = path, rid = id }
            if stored then
                prep.parts = stubLib.SplitPath(path)
                local r, f, got = resolve(prep.parts, id)
                if type(r) == "table" then prep.root, prep.first = r, f end
                if got ~= nil then prep.rid = got end
            end
            local ok, v, why = checkValue(row, path, value, prep.rid)
            if not ok then return false, v, why, true end
            if stored and not prep.root then
                return false, "AbsorbTracker: nowhere to store " .. path, nil, false
            end
            prep.value = v
            return true, prep
        end
        -- The store: the row's own set with the value as given, or a COPY written at the path; a
        -- sessionOnly row without a set stores nothing.
        local function store(prep)
            if type(prep.row.set) == "function" then
                prep.row.set(prep.value)
            elseif prep.root then
                stubLib.Write(prep.root, prep.parts, copy(prep.value), prep.first)
            end
        end
        local function react(prep)
            local onChange = prep.row.onChange
            if type(onChange) == "function" then onChange(prep.value, prep.rid) end
        end
        local function commit(prep)
            store(prep)
            react(prep)
        end
        -- The write seam's order without its log and tally: refuse, validate, normalize, store,
        -- react, announce. A listed writeThrough path with no row is not refused (see above).
        function S.Set(path, value, id)
            local row = writeRow(path)
            if not row then return false, "AbsorbTracker: no setting " .. tostring(path) end
            local ok, prep, why, withWhy = prepareWrite(row, path, value, id)
            if not ok then
                if withWhy then return false, prep, why end
                return false, prep
            end
            commit(prep)
            if type(d.announce) == "function" then d.announce(row, path, prep.value, prep.rid) end
            return true
        end
        -- One batch entry, checked as Set checks it: a prep, or `nil, err, why`.
        local function prepareEntry(entry, id)
            local path = type(entry) == "table" and entry.path or nil
            local row = writeRow(path)
            if not row then return nil, "AbsorbTracker: no setting " .. tostring(path) end
            local ok, prep, why = prepareWrite(row, path, entry.value, id)
            if not ok then return nil, prep, why end
            return prep
        end
        -- The batch's tail: announceBatch once with `{ row, path, value, rid }` per write and the
        -- first write's id, else announce per write. Nothing for an empty batch.
        local function announceAll(preps)
            if #preps == 0 then return end
            if type(d.announceBatch) == "function" then
                local writes = {}
                for i, p in ipairs(preps) do
                    writes[i] = { row = p.row, path = p.path, value = p.value, rid = p.rid }
                end
                d.announceBatch(writes, preps[1].rid)
                return
            end
            if type(d.announce) ~= "function" then return end
            for _, p in ipairs(preps) do d.announce(p.row, p.path, p.value, p.rid) end
        end
        -- SetMany (since 2), all or nothing and log-silent: every entry prepared first, and the
        -- first refusal answers `false, err, why, index` with nothing stored; then every store,
        -- every onChange, and the announce. `opts.act` is not read -- there is no line to make.
        function S.SetMany(entries, opts)
            if type(entries) ~= "table" then entries = {} end
            local id = type(opts) == "table" and opts.instanceId or nil
            local preps = {}
            for i = 1, #entries do
                local prep, err, why = prepareEntry(entries[i], id)
                if not prep then return false, err, why, i end
                preps[i] = prep
            end
            for _, p in ipairs(preps) do store(p) end
            for _, p in ipairs(preps) do react(p) end
            announceAll(preps)
            return true
        end
        function S.Default(path)
            local row = S.FindRow(path)
            return row and copy(row.default)
        end
        function S.ApplyDefault(row, id)
            if type(row) ~= "table" or type(row.path) ~= "string" or row.default == nil then
                return false
            end
            local exempt = d.resetExempt
            if depth > 0 and type(exempt) == "table" and exempt[row.path] then return false end
            return S.Set(row.path, copy(row.default), id)
        end
        -- The bracket keeps its depth, because the sweep veto above reads it; it counts nothing.
        function S.BulkBegin() depth = depth + 1 end
        function S.BulkEnd() if depth > 0 then depth = depth - 1 end end
        function S.BulkRun(act, scope, fn)
            S.BulkBegin(act, scope)
            local ok, err = pcall(fn, { profileReset = false })
            S.BulkEnd(act, scope)
            if not ok then error(err, 0) end
        end
        function S.BulkAdd() end
        function S.InBulk() return depth > 0 end
        function S.CountOffDefault() return 0 end
        function S.ResetCounted(fn) fn() end
        function S.ConsumeResetCount() return nil end
        function S.Validate()
            if type(d.print) == "function" then
                d.print("LibKa0s-Schema-1.0 is missing, so the schema was not checked")
            end
            return 0, 0, 0
        end
        return S
    end
    return stubLib
end

-- Resolved once, at file load (library-stack-§4): the TOC loads libs\LibKa0s\LibKa0s.xml in the
-- lib block, so the major is registered by now or absent for good.
local SchemaLib = LibStub and LibStub("LibKa0s-Schema-1.0", true) or HostSchemaStub()
-- Suite seam only: tests/test_surface_parity.lua holds the stub to the library's surface by name,
-- which it can only do on a degraded load if the stub is reachable.
NS.__schemaLib = SchemaLib

-- The minimap button's row survives every SWEEP (launcher-§3): a page's Defaults button and Reset
-- all settings leave it alone. The library honors this only while a bracket is open, so a player
-- who names the row (`/at reset global.minimap.hide`) still gets exactly that row reset.
local MINIMAP_PATH = NS.Constants.MINIMAP_PATH

local function chatPrint(line)
    if NS.Print then
        NS.Print(line)
    elseif DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[AT]|r " .. line)
    end
end

local S = SchemaLib:New({
    -- The live array, never copied: the page files register into it through NS.RegisterSchemaRows.
    rows = NS.Schema,

    -- Where a STORED row lives. Almost every path is the active profile's; a `global.` path is the
    -- account-wide store. Two rows keep their value somewhere else entirely and carry their own
    -- get/set instead (settings/General.lua stamps them): the console toggle (session state) and
    -- the minimap button (LibDBIcon's inverted key). Before the db exists this answers nil, and a
    -- write is refused rather than lost somewhere nobody reads (NS.GetSetting's read falls back to
    -- the shipped defaults).
    resolveRoot = function(parts)
        local db = NS.db
        if parts[1] == "global" then return db and db.global, 2 end
        return db and db.profile, 1
    end,

    -- A row with no onChange of its own falls through to a restyle of every bar. Sent from here,
    -- after the write and the row's reaction, so a write path signals the display module rather
    -- than calling it across the module boundary.
    announce = function(row)
        if not row.onChange and NS.bus then NS.bus:SendMessage(NS.MSG.APPEARANCE) end
    end,

    -- Looked up at call time, not captured: the debug sink is wired later in the load on some
    -- paths, and the suites spy on NS.Debug.
    debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,
    -- Asked BEFORE a line is formatted: a ColorPicker drag reaches the seam every frame, and with
    -- debug off it must do no string work at all.
    debugEnabled = function() return NS.State and NS.State.debug end,
    -- The same renderer `/at get` echoes with (LibKa0s-Slash-1.0), so the two never disagree.
    format = function(row, v) return NS.FormatSchemaValue(row, v) end,
    print = chatPrint,
    resetExempt = { [MINIMAP_PATH] = true },
})
NS.SchemaRuntime = S

-- ---------------------------------------------------------------------
-- The host's names, bound to the instance
-- ---------------------------------------------------------------------

--- Append a list of schema rows. Called once per settings/<page>.lua at file-load time.
NS.RegisterSchemaRows = S.AddRows
--- The row at `path`, or nil. First registered wins on a duplicate (ValidateSchema reports one).
NS.FindSchemaRow = S.FindRow

--- Write a value for `path`, then its row's onChange, then the announce. The single write seam for
--- every schema-row path (architecture-§5): /at set, /at lock, /at unlock, /at toggle and every
--- panel widget call it, and every reset to a row's default reaches it through NS.ApplyDefault. A
--- path with no schema row is REFUSED (`false, reason`) and stores nothing, and a table value is
--- stored as a copy, so the caller's table and the store never alias.
NS.SetByPath = S.Set

--- Reset one row to its default, through the same seam (a deep copy of the default). Used by
--- /at reset <path>, the per-page Defaults button and Reset All's sessionOnly sweep. A row with no
--- `default` writes nothing; inside a sweep the minimap row writes nothing either.
NS.ApplyDefault = S.ApplyDefault

-- The dotted-path primitives. Per-unit settings live at `units.<unit>.<key>`; a flat key ("locked")
-- is the one-segment case. Read allocates nothing once a path has been seen (the split is cached),
-- which is what the dormant repaint pass's ceiling in tests/perf.lua holds it to.
NS.ResolvePath, NS.SetPath = SchemaLib.Read, SchemaLib.Write

-- The bulk bracket (debug-logging-§10): a bulk copy or reset is ONE `[Set] <act> <scope>: N rows`
-- line, N the rows whose stored value moved; nested brackets are one act; a level that reset the
-- whole profile silences the line (OnProfileReset logs that once); a raised error marks the line
-- ` (stopped by an error)` and is re-raised unchanged. Run hands its walk an `info` table.
NS.Bulk = { Begin = S.BulkBegin, End = S.BulkEnd, Run = S.BulkRun }

-- The profile reset's count (debug-logging-§10). `[Set] reset profile '<name>' to defaults (N rows)`
-- is OnProfileReset's line, and N is the rows the reset CHANGED. Only a caller that runs before the
-- reset can know that, so every reset this addon drives goes through NS.ResetProfileCounted, which
-- leaves the number pending for the handler to take once (NS.ConsumeResetCount); the count is
-- cleared when the reset returns or raises. The minimap row is not counted, for the same reason a
-- sessionOnly row is not: a profile reset cannot reach it (its value is in the GLOBAL store). Nor is
-- a profiles-page row, which AceDBOptions owns.
local function reachedByProfileReset(row)
    return row.path ~= MINIMAP_PATH and row.page ~= "profiles"
end

function NS.ProfileRowsOffDefault() return S.CountOffDefault(reachedByProfileReset) end

function NS.ResetProfileCounted(db)
    S.ResetCounted(function() db:ResetProfile() end, reachedByProfileReset)
end

NS.ConsumeResetCount = S.ConsumeResetCount

-- ---------------------------------------------------------------------
-- Lookup
-- ---------------------------------------------------------------------

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

-- ---------------------------------------------------------------------
-- /at list / /at get value formatting
-- ---------------------------------------------------------------------

-- Rendering a stored value for display is LibKa0s-Slash-1.0's, so `/at get`'s echo and the [Set]
-- debug line above can never disagree about how a color or an empty string reads. Kept under this
-- name because the schema layer is where callers look for it.
--
-- Resolved once, here at file load, and stashed (library-stack-§4). The TOC loads
-- libs\LibKa0s\LibKa0s.xml (which pulls in Slash.lua) in the lib block, long before
-- settings\Schema.lua, so by this line the major is either registered or permanently absent —
-- re-asking per call could never find it later. It mattered because this sits on the write seam
-- every panel widget and every `/at set` goes through.
local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)

-- The library-absent fallback is deliberately minimal, and stays that way: its only caller is the
-- [Set] debug line above, which is gated behind NS.State.debug and in that build is handed to a
-- NS.DebugLog stub that swallows it. Nothing renders these strings to a user, so re-growing the
-- typed branches here would be a second copy of a formatter this extraction exists to delete
-- (testing-§8). tests/test_schema.lua pins both arms.
function NS.FormatSchemaValue(row, v)
    if SlashLib then return SlashLib.FormatValue(row, v) end
    if v == nil then return "nil" end
    return tostring(v)
end

-- ---------------------------------------------------------------------
-- Schema-shape validation
-- ---------------------------------------------------------------------
--
-- Run once at panel-registration time after every settings/<page>.lua has loaded its rows. The
-- library's check: a row that is not a table, a missing path, a type or page outside the sets
-- below, a missing `group` (options-ui-§13), a duplicate path, and (architecture-§5) a path that
-- does NOT resolve against the defaults that hold it -- a typo'd path would otherwise silently
-- read and write nothing. It only PRINTS; it never refuses to register.
--
-- The Bar / Border / Font trio collapsed into one `appearance` page: they were three copies of the
-- same Unit picker over one piece of state (settings/Appearance.lua says why). A page is where a
-- row is EDITED, never where it is stored, so not one path moved with them.
local VALID_PAGES = { general = true, appearance = true, profiles = true }

--- Which defaults tree a row's path resolves against. Almost every row means `defaults.profile`; a
--- `global.` path means `defaults.global`, which is where launcher-§3 puts the minimap button's
--- table. A profiles-page row is AceDBOptions-supplied and in no defaults tree, so it is skipped
--- (answering no root). A sessionOnly row is skipped by the library itself: its value is
--- deliberately not in the profile.
local function defaultsRoot(parts, row)
    if row.page == "profiles" then return nil end
    local d = NS.defaults
    if parts[1] == "global" then return d and d.global, 2 end
    return d and d.profile, 1
end

--- Walk the assembled schema and surface any malformed row. Returns three counts for the test
--- harness to assert: shape `errors`, paths `resolved` against the defaults that hold them, and
--- `missing` paths (present rows whose path has no matching default).
function NS.ValidateSchema()
    return S.Validate({ pages = VALID_PAGES, defaultsRoot = defaultsRoot })
end

-- The type-aware value parser moved to LibKa0s-Slash-1.0 (`lib.ParseValue`): clamping, the
-- case-sensitive enum check, the 0-1 / 0-255 color rescale and the nil-plus-reason failure
-- contract all live there, and settings/Slash.lua hands the library the schema rows to parse
-- against. Nothing here called it once the dispatcher was extracted, and a second copy of a parser
-- is precisely the drift the extraction exists to end.
