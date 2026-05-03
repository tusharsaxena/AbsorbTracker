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
- The settings-panel helpers table (`Helpers` — `CreatePanel`, `RenderSchema`, `RefreshAllPanels`, etc.).
- The slash command list (`SlashCommands`) — also rendered on the about page.

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
AddonTable.format  = format
```

### Utils (`Utils.lua`)

```lua
AddonTable.DEBUG               -- bool flag, toggled by /at debug

AddonTable.Print(...)          -- prepends cyan |cFF00FFFF[AT]|r and prints
AddonTable.DebugPrint(...)     -- conditional on AddonTable.DEBUG; same prefix
```

### LSMPatch (`LSMPatch.lua`)

No public API. The whole file is one `CreateFrame("Frame")` registered for `PLAYER_LOGIN`. On fire, it looks up whatever constructor `AceGUI.WidgetRegistry["LSM30_Border"]` currently holds, and if a constructor is registered (i.e. the upstream `AceGUI-3.0-SharedMediaWidgets` ran), registers a wrapper at `currentVer + 1` that:

1. Calls the original constructor.
2. `frame.displayButton:Hide()` on the returned widget — kills the 42×42 border-preview tile pinned to the widget's TOPLEFT by `AGSMW:GetBaseFrameWithWindow`.
3. Re-anchors `frame.label` to the frame's TOPLEFT/TOPRIGHT (was anchored to `displayButton.TOPRIGHT` by upstream).
4. Re-anchors `frame.DLeft` (the dropdown bar's left cap) to the frame's BOTTOMLEFT (was anchored to `displayButton.BOTTOMRIGHT` by upstream).

If `AceGUI` isn't loaded, or no `LSM30_Border` is registered, the hook no-ops cleanly.

The displayButton suppressor lives in addon code rather than as an edit to the vendored lib so future `AceGUI-3.0-SharedMediaWidgets` refreshes are a clean drop-in.

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
```

`GetPlayerClassColor` / `GetBgClassColor` are private upvalues used internally by the color getters. They're not exposed on `AddonTable`.

### Schema (`Schema.lua`)

```lua
AddonTable.Schema                          -- flat array of rows; the source of truth

-- Registration (called from Options/*.lua at file-load time)
AddonTable.RegisterSchemaRows(rows)        -- append rows to AddonTable.Schema

-- Lookup
AddonTable.FindSchemaRow(path)             -> row | nil
AddonTable.SchemaForPage(pageKey)          -> { rows }   -- sorted by row.order

-- Write / reset (reads go through GetSetting directly)
AddonTable.SetByPath(path, value)          -- writes via SetSetting + fires row.onChange
                                           -- (the single seam both /at set and the panel widget
                                           -- set() use; pre-M1.3 the panel open-coded this two-step)
AddonTable.ApplyDefault(row)               -- resets row to row.default + fires onChange

-- Slash IO
AddonTable.FormatSchemaValue(row, value)   -> string
AddonTable.ParseSchemaValue(row, text)     -> value | nil, errMsg

-- Validation (called once at PLAYER_LOGIN by CreateOptionsPanel)
AddonTable.ValidateSchema()                -> errorCount   -- chat-prints any malformed rows
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

```lua
AddonTable.SlashCommands           -- ordered { name, desc, handler } array;
                                   -- /at help and the about page both walk this list
```

Also registers `SLASH_ABSORBTRACKER1 = "/at"`, `SLASH_ABSORBTRACKER2 = "/absorbtracker"`, and `SlashCmdList["ABSORBTRACKER"]` at file-load time.

### OptionsPanel (`OptionsPanel.lua`)

The settings UI is split across `OptionsPanel.lua` (registration shell) and four `Panel/*.lua` slices that decorate the same shared `AddonTable.Helpers` table. `OptionsPanel.lua` publishes the empty table; each `Panel/*.lua` file extends it with its own surface; `Options/<page>.lua` consume the toolkit at PLAYER_LOGIN.

```lua
-- Registration shell (OptionsPanel.lua)
AddonTable.PARENT_TITLE            -- "Ka0s Absorb Tracker" — single source of truth for the
                                   -- top-level canvas title and the buildHeader breadcrumb prefix
AddonTable.RegisterOptionsPage(key, name, builder)
    -- key:     "general" / "bar" / "border" / "font" / "profiles"
    -- name:    display name shown in the Blizzard Settings tree (and breadcrumb header)
    -- builder: function(mainCategory) -> sub-category | nil    (called at PLAYER_LOGIN)

AddonTable.CreateOptionsPanel()    -- called from Events.lua on PLAYER_LOGIN once db is ready
AddonTable.RefreshOptionsPanel()   -- routes to Helpers.RefreshAllPanels (re-runs every refresher)
AddonTable.OpenOptionsPanel()      -- Settings.OpenToCategory(mainCategoryID) + expandMainCategory();
                                   -- combat-lockdown gated. Always opens the parent (about page) and
                                   -- expands the sub-page tree so every page is visible at once.
```

```lua
-- Panel toolkit, decorated across Panel/*.lua and exposed as AddonTable.Helpers:
AddonTable.Helpers
    -- Panel/Helpers.lua
    Helpers.CreatePanel(name, title, opts)         -- canvas frame + header + Defaults button
    Helpers.EnsureScroll(ctx)                      -- lazy AceGUI ScrollFrame; calls PatchAlwaysShowScrollbar
    Helpers.Section(ctx, label)                    -- AceGUI Heading row
    Helpers.InlineButtonPair(ctx, leftSpec, rightSpec)
    Helpers.AttachTooltip(widget, label, tooltip)
    Helpers.AddSpacer(scroll, height)              -- invisible full-width SimpleGroup
    Helpers.LSMValues(mediaType)                   -- deferred LSM hash factory for schema rows
    Helpers.RestoreDefaults(pageKey, ctx)
    Helpers.RestoreAllDefaults()                   -- every schema-driven page; skips profiles
    Helpers.RefreshAllPanels()                     -- run every panel ctx's refresher closures
    Helpers.ROW_VSPACER                            -- layout constants exposed for cross-slice use
    Helpers.SECTION_HEADING_H                      -- (read by Panel/Widgets.lua and Panel/About.lua)

    -- Panel/ScrollPatch.lua
    Helpers.PatchAlwaysShowScrollbar(scroll)       -- always-visible scrollbar override

    -- Panel/Widgets.lua
    Helpers.RenderField(ctx, row, parent, w)       -- dispatches by row.type
    Helpers.RenderSchema(ctx, pageKey, afterGroup?) -- two-column layout from schema rows

    -- Panel/About.lua
    Helpers.BuildMainContent(ctx)                  -- top-level "Ka0s Absorb Tracker" page builder
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

1. `libs/` — LibStub + CallbackHandler + LibSharedMedia + the Ace3 stack + the canonical upstream `AceGUI-3.0-SharedMediaWidgets` r65 LSM widgets (via the `#@no-lib-strip@` block).
2. `Core.lua` — defaults + cached globals on `AddonTable`.
3. `Utils.lua` — `Print` / `DebugPrint`.
4. `LSMPatch.lua` — registers `PLAYER_LOGIN` hook for upstream `LSM30_Border` displayButton suppression.
5. `Settings.lua` — db access + LSM wrappers + color getters.
6. `Schema.lua` — schema registry + builders.
7. `UI.lua` — bar frame creation (runs at file-load time).
8. `Display.lua` — render functions.
9. `Timer.lua` — ticker management.
10. `Events.lua` — event frame + login bootstrap (registered, fires later).
11. `SlashCommands.lua` — `/at` dispatcher (registered at load).
12. `OptionsPanel.lua` — registration shell. Publishes empty `AddonTable.Helpers = {}` and `AddonTable.PARENT_TITLE`; queues are empty at load; pages drain at PLAYER_LOGIN.
13. `Panel/Helpers.lua` → `Panel/ScrollPatch.lua` → `Panel/Widgets.lua` → `Panel/About.lua` — each decorates `AddonTable.Helpers` with its own surface. Order matters only between Helpers (defines `EnsureScroll`) and ScrollPatch (defines `PatchAlwaysShowScrollbar` that `EnsureScroll` references at panel-creation time).
14. `Options/General.lua` → `Bar.lua` → `Border.lua` → `Font.lua` → `Profiles.lua` — each calls `RegisterSchemaRows` + `RegisterOptionsPage` at file-load time. LSM-backed schema rows in `Bar.lua` / `Border.lua` / `Font.lua` call `AddonTable.Helpers.LSMValues(mediaType)` at file-load to get a deferred values closure.

If you add a new runtime file, put it in the right place in `AbsorbTracker.toc`.

## Module publishing pattern (idiom)

Modules don't follow a `KCM = KCM or {}` style guard because there's only one shared `AddonTable` rather than a global registry. The closest equivalent is the import-as-locals pattern at the top of each file plus the `if AddonTable.X then ... end` nil check around forward references.
