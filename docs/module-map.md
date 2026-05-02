# Module map

The `AddonTable` bus, the public APIs each module publishes, and the load-order rules. Pair this with [data-flow.md](./data-flow.md) for how the modules talk to each other.

## The `AddonTable` bus

Every Lua file begins with:

```lua
local AddonName, AddonTable = ...
```

`...` is the WoW-supplied vararg pair. **`AddonTable` is the same table for every file in this addon**, so writing `AddonTable.foo = ...` in one file makes it readable from any other file loaded afterward.

There is no Ace3 `:NewModule()` or class hierarchy on the runtime side — modules are plain Lua files; functions are attached to `AddonTable`. AceAddon is bundled but only used as the carrier for AceDB.

State that lives on `AddonTable` (rather than as a global):

- The bar frame and its children (`bar`, `statusBar`, `valueText`).
- The database reference (`db`).
- Defaults (`defaults`, `flatDefaults`).
- Helper functions (`Print`, `GetSetting`, `SetSetting`, `GetBarColor`, ...).
- The schema registry (`Schema`).

The only WoW-required globals are `AbsorbTrackerDB`, `SLASH_ABSORBTRACKER1` / `SLASH_ABSORBTRACKER2`, and `AbsorbTrackerFrame` (the frame's name).

### Imports as locals

Each file pulls its imports as locals at the top of the chunk:

```lua
local GetSetting = AddonTable.GetSetting
local SetSetting = AddonTable.SetSetting
```

Two consequences:

1. **Locals capture the value at load time.** A function only seen via local import will be the version that existed when the importing file was loaded. For functions defined in later-loaded modules, callers must reference them through `AddonTable.X` directly so the lookup happens at call time.
2. **No circular re-entry.** Files lower in the TOC can call functions defined higher up; the reverse requires the runtime nil-check pattern (see [Forward references](#forward-references)).

## Public APIs per module

### Core (`Core.lua`)

```lua
AddonTable.defaults      -- AceDB-shaped { profile = { ... } }
AddonTable.flatDefaults  -- alias to defaults.profile (direct-lookup convenience)

-- Cached math/format on AddonTable to avoid global lookups in hot paths
AddonTable.floor   = math.floor
AddonTable.max     = math.max
AddonTable.min     = math.min
AddonTable.format  = format
```

### Utils (`Utils.lua`)

```lua
AddonTable.DEBUG               -- bool flag, toggled by /at debug

AddonTable.Print(...)          -- prepends cyan |cFF00FFFF[AT]|r and prints
AddonTable.DebugPrint(...)     -- conditional on AddonTable.DEBUG; same prefix
```

### Settings (`Settings.lua`)

```lua
-- Database access
AddonTable.GetSetting(key)            -> value
AddonTable.SetSetting(key, value)     -- writes to db.profile, falls back to flatDefaults if db is nil

-- LibSharedMedia wrappers (return path; fall back to FALLBACK_* Blizzard constants when LSM missing)
AddonTable.GetBarTexture()            -> texturePath
AddonTable.GetBgTexture()             -> texturePath
AddonTable.GetBorder()                -> texturePath
AddonTable.GetFont()                  -> fontPath
AddonTable.ClearLSMCache()            -- reset cached LSM ref; called once at PLAYER_LOGIN

-- Color resolution (resolves useClassColor* at call time)
AddonTable.GetBarColor()              -> r, g, b, a
AddonTable.GetBgColor()               -> r, g, b, a
AddonTable.GetBorderColor()           -> r, g, b, a
AddonTable.GetPlayerClassColor()      -> r, g, b, a
AddonTable.GetBgClassColor()          -> r, g, b, a    -- darkened bg variant
```

### Schema (`Schema.lua`)

```lua
AddonTable.Schema                          -- flat array of rows; the source of truth

-- Registration (called from Options/*.lua at file-load time)
AddonTable.RegisterSchemaRows(rows)        -- append rows to AddonTable.Schema

-- Lookup
AddonTable.FindSchemaRow(path)             -> row | nil
AddonTable.SchemaForPage(pageKey)          -> { rows }

-- Write / reset (reads go through GetSetting directly)
AddonTable.SetByPath(path, value)          -- writes via SetSetting + fires row.onChange
AddonTable.ApplyDefault(row)               -- resets row to row.default + fires onChange

-- Slash IO
AddonTable.FormatSchemaValue(row, value)   -> string
AddonTable.ParseSchemaValue(row, text)     -> value | nil, errMsg

-- AceConfig table builder
AddonTable.BuildPageOptions(pageKey, pageName) -> AceConfig options table
```

Detail in [schema.md](./schema.md).

### UI (`UI.lua`)

Runs at file-load time, not as a function. Exports the frame handles for everyone else to push into:

```lua
AddonTable.bar           -- the outer movable BackdropTemplate frame (also registered as AbsorbTrackerFrame globally)
AddonTable.statusBar     -- child StatusBar
AddonTable.valueText     -- FontString child of statusBar
AddonTable.backdropInfo  -- reusable backdrop info table; mutated in place by UpdateBarAppearance
```

### Display (`Display.lua`)

```lua
AddonTable.UpdateBarAppearance()    -- re-applies size, textures, colors, border, font, lock, visibility
AddonTable.UpdateAbsorbBar()         -- reads UnitGetTotalAbsorbs + UnitHealthMax, pushes into statusBar/valueText
AddonTable.RestoreBarPosition()      -- re-applies saved position table or centers the bar
```

### Timer (`Timer.lua`)

```lua
AddonTable.RestartUpdateTicker(forceRestart?)   -- short-circuits when interval unchanged unless forced
AddonTable.ResetTickerInterval()                -- clears tracked interval; next call rebuilds the ticker
```

### Events (`Events.lua`)

```lua
AddonTable.OnProfileChanged()    -- registered for AceDB OnProfileChanged / OnProfileCopied / OnProfileReset
                                 -- runs RestoreBarPosition + UpdateBarAppearance + UpdateAbsorbBar
                                 --     + ResetTickerInterval + RestartUpdateTicker(true)
                                 --     + RefreshOptionsPanel
```

The login bootstrap and event handlers are local to `Events.lua`; nothing about them is exposed on `AddonTable`. Detail in [data-flow.md](./data-flow.md).

### SlashCommands (`SlashCommands.lua`)

No public exports — registers `SLASH_ABSORBTRACKER1 = "/at"`, `SLASH_ABSORBTRACKER2 = "/absorbtracker"`, and `SlashCmdList["ABSORBTRACKER"]` at file-load time. The handler walks an internal `COMMANDS` array.

### OptionsPanel (`OptionsPanel.lua`)

```lua
AddonTable.RegisterOptionsPage(key, name, builder, opts)
    -- key:     "general" / "bar" / "border" / "font" / "profiles"
    -- name:    display name shown in the Blizzard Settings tree
    -- builder: () -> AceConfig options table (called at PLAYER_LOGIN)
    -- opts.isDefault = true flags the page that /at config opens (typically General)

AddonTable.CreateOptionsPanel()    -- called from Events.lua on PLAYER_LOGIN once db is ready
AddonTable.RefreshOptionsPanel()   -- AceConfigRegistry:NotifyChange per registered page
AddonTable.OpenOptionsPanel()      -- Settings.OpenToCategory(defaultCategoryID); combat-lockdown gated
```

Detail in [settings-panel.md](./settings-panel.md).

## Forward references

A small number of call sites reach across load order:

- `Events.lua` calls `AddonTable.CreateOptionsPanel()` (defined in `OptionsPanel.lua`, loaded later).
- `Events.lua` calls `AddonTable.RefreshOptionsPanel()` inside `OnProfileChanged` (same).

These are guarded with runtime nil checks:

```lua
if AddonTable.RefreshOptionsPanel then
    AddonTable.RefreshOptionsPanel()
end
```

In practice the calls always succeed because all files are loaded synchronously before any event fires — but the nil-check keeps the load-order coupling soft, so a future refactor that splits the options panel into a separately-loaded file won't error.

## Load order

`AbsorbTracker.toc` is the source of truth. Order is dependency order, not alphabetical:

1. `libs/` — LibStub + CallbackHandler + LibSharedMedia + the Ace3 stack + the in-tree LSM widgets (via the `#@no-lib-strip@` block).
2. `Core.lua` — defaults + cached globals on `AddonTable`.
3. `Utils.lua` — `Print` / `DebugPrint`.
4. `Settings.lua` — db access + LSM wrappers + color getters.
5. `Schema.lua` — schema registry + builders.
6. `UI.lua` — bar frame creation (runs at file-load time).
7. `Display.lua` — render functions.
8. `Timer.lua` — ticker management.
9. `Events.lua` — event frame + login bootstrap (registered, fires later).
10. `SlashCommands.lua` — `/at` dispatcher (registered at load).
11. `OptionsPanel.lua` — registration shell (queues are empty at load; pages drain at PLAYER_LOGIN).
12. `Options/General.lua` → `Bar.lua` → `Border.lua` → `Font.lua` → `Profiles.lua` — each calls `RegisterSchemaRows` + `RegisterOptionsPage` at file-load time.

If you add a new runtime file, put it in the right place in `AbsorbTracker.toc`.

## Module publishing pattern (idiom)

Modules don't follow a `KCM = KCM or {}` style guard because there's only one shared `AddonTable` rather than a global registry. The closest equivalent is the import-as-locals pattern at the top of each file plus the `if AddonTable.X then ... end` nil check around forward references.
