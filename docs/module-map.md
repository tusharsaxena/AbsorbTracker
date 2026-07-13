# Module map

The `NS` bus, the public APIs each module publishes, and the load-order rules. Pair this with [data-flow.md](./data-flow.md) for how the modules talk to each other.

## The `NS` bus

Every Lua file begins with:

```lua
local addonName, NS = ...
```

`...` is the WoW-supplied vararg pair. **`NS` is the same table for every file in this addon**, so writing `NS.foo = ...` in one file makes it readable from any other file loaded afterward. `NS` is the addon's single private table — there is no `_G[addonName]`.

`NS` is also the AceAddon object. `core/AbsorbTracker.lua` promotes the bootstrap table:

```lua
local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
NS.addon = addon
```

Passing `NS` as the first argument to `:NewAddon` makes the bootstrap table and the AceAddon object one and the same, so `NS:OnInitialize` / `NS:OnEnable` are the lifecycle methods and the AceEvent / AceTimer / AceConsole mixins are stamped onto `NS.addon`. **AceAddon is a full participant now** — the repaint throttle (`NS.addon:ScheduleTimer`), the events (`self:RegisterEvent`), and the slash registration (`NS.addon:RegisterChatCommand`) all flow through it. There is still no `:NewModule()` hierarchy; the runtime modules are plain Lua files that attach functions to `NS`.

State that lives on `NS` (rather than as a global):

- The bar frame and its children (`bar`, `statusBar`, `valueText`, `backdropInfo`).
- The AceAddon object (`addon`) and the database reference (`db`).
- Defaults (`defaults`, `flatDefaults`).
- Session state (`State` — `State.debug`, never persisted).
- Sub-tables that namespace a module's surface (`Constants`, `Compat`, `Util`, `Slash`, `DebugLog`, `Helpers`).
- Helper functions attached directly (`Print`, `DebugPrint`, `Debug`, `GetSetting`, `SetSetting`, `GetBarColor`, ...).
- The schema registry (`Schema`) and the localized-string table (`L`).
- The slash command list (`COMMANDS`, aliased `SlashCommands`) — also rendered on the about page.
- The stashed AceGUI reference (`AceGUI`), set once in `CreateOptionsPanel`.

The only WoW-required global is the SavedVariables table `AbsorbTrackerDB`. The bar frame is named `AbsorbTrackerFrame`; the debug console frames are `AbsorbTrackerDebugWindow` / `AbsorbTrackerDebugCopyWindow`. There are **no** `SLASH_*` / `SlashCmdList` globals — slash registration is AceConsole (`RegisterChatCommand`).

### Imports as locals

Each file pulls its imports as locals at the top of the chunk:

```lua
local C = NS.Constants
local print = NS.Print
```

Two consequences:

1. **Locals capture the value at load time.** A function only seen via local import will be the version that existed when the importing file was loaded. For functions defined in later-loaded modules, callers must reference them through `NS.X` directly so the lookup happens at call time.
2. **No circular re-entry.** Files lower in the TOC can call functions defined higher up; the reverse requires the runtime nil-check pattern (see [Forward references](#forward-references)).

## Public APIs per module

### Namespace (`core/Namespace.lua`)

```lua
NS.name    -- addonName
NS.version -- "1.9.0" string constant
NS.PREFIX  -- "|cFF00FFFF[AT]|r" — the one shared cyan [AT] chat tag

-- Cached math/string on NS to avoid global lookups in the bar paint path
NS.floor  = math.floor
NS.max    = math.max
NS.format = format or string.format
```

### Constants (`core/Constants.lua`)

```lua
NS.Constants.FALLBACK_TEXTURE  -- Blizzard statusbar path (bar / bg fallback)
NS.Constants.FALLBACK_BORDER   -- Blizzard tooltip-border fallback
NS.Constants.FALLBACK_FONT     -- FRIZQT__ fallback
NS.Constants.FONT_MONO         -- addon-relative path to the vendored JetBrains Mono TTF
NS.Constants.LOGO_PATH         -- media/logos/ about-page logo TGA
```

### Compat (`core/Compat.lua`)

The **only** file that calls a deprecated/varying WoW API. Every other module routes metadata reads through it.

```lua
NS.Compat.GetAddOnMetadata(name, field)  -- C_AddOns.GetAddOnMetadata with a
                                          -- _G.GetAddOnMetadata pre-11.0 fallback; nil if absent
```

### State (`core/State.lua`)

```lua
NS.State        -- session-only runtime table; nothing here is persisted
NS.State.debug  -- bool, defaults nil/off, reset on every reload/login;
                -- flipped by /at debug on|off and the console header toggle
```

### Util (`core/Util.lua`)

```lua
NS.Print(...)       -- prepends NS.PREFIX and prints via DEFAULT_CHAT_FRAME
NS.DebugPrint(tag, ...)  -- routes to the on-screen console (NS.Debug) when State.debug is on;
                         -- first arg is the [tag] (source event/fn name), rest is the message;
                         -- zero-cost when off. No longer prints to chat.
NS.Util.print       -- alias of NS.Print
```

### Data (`core/Data.lua`)

The AceDB read/write seam plus the LSM fetchers and the class-color-aware color resolvers. `NS.db` is declared here (nil until `InitDB`).

```lua
-- Database access
NS.GetSetting(key)            -> value        -- reads db.profile, falls back to flatDefaults
NS.SetSetting(key, value)     -- writes to db.profile (no-op if db unset)

-- LibSharedMedia
NS.GetLSM()                   -> LSM | nil     -- cached LibStub lookup
NS.ClearLSMCache()            -- reset the cached LSM ref; called on enable
NS.GetBarTexture()            -> texturePath   -- falls back to FALLBACK_TEXTURE
NS.GetBgTexture()             -> texturePath
NS.GetBorder()                -> borderPath    -- falls back to FALLBACK_BORDER
NS.GetFont()                  -> fontPath      -- falls back to FALLBACK_FONT

-- Color resolution (re-reads useClassColor* at call time)
NS.GetBarColor()              -> r, g, b, a
NS.GetBgColor()               -> r, g, b, a
NS.GetBorderColor()           -> r, g, b, a
```

`GetPlayerClassColor` / `GetBgClassColor` are private upvalues used internally by the color getters. They're not exposed on `NS`.

### Database (`core/Database.lua`)

AceDB init + the idempotent migration seam. Available headlessly for the test harness.

```lua
NS:InitDB()         -- AceDB:New("AbsorbTrackerDB", NS.defaults, true); registers
                    -- OnProfileChanged/OnProfileCopied/OnProfileReset -> NS.OnProfileChanged
                    -- (RegisterCallback guarded for the headless mock); falls back to a
                    -- raw-SV table when AceDB is absent; then calls RunMigrations.
NS:RunMigrations()  -- reads/writes db.global.schemaVersion (v1); backfills missing profile
                    -- keys from flatDefaults, deep-copying table defaults. Idempotent.
```

### LSMPatch (`core/LSMPatch.lua`)

```lua
NS.ApplyLSMBorderPatch()  -- called once on enable
```

Wraps whatever constructor `AceGUI.WidgetRegistry["LSM30_Border"]` currently holds and registers the wrapper at `currentVersion + 1`. Per instance it:

1. Calls the original constructor.
2. `frame.displayButton:Hide()` — kills the 42×42 border-preview tile pinned to the widget's TOPLEFT by `AGSMW:GetBaseFrameWithWindow`.
3. Re-anchors `frame.label` to the frame's TOPLEFT/TOPRIGHT (was anchored to `displayButton`).
4. Re-anchors `frame.DLeft` (the dropdown bar's left cap) to the frame's BOTTOMLEFT.

No-ops cleanly if AceGUI isn't loaded or no `LSM30_Border` is registered. `LSM30_Font` / `LSM30_Statusbar` use `AGSMW:GetBaseFrame` (no displayButton), so this is Border-specific. The suppressor lives in addon code rather than a lib edit so future `AceGUI-3.0-SharedMediaWidgets` refreshes are a clean drop-in.

### DebugLog (`core/DebugLog.lua`)

The on-screen debug console (a `ScrollingMessageFrame` in the vendored monospace font), replacing chat-based debug spam. Session-only.

```lua
NS.Debug(tag, fmt, ...)   -- the global debug sink; no-op (zero alloc) when State.debug is off,
                          -- otherwise appends a formatted line to the console.

NS.DebugLog.Show() / Hide() / Toggle()   -- the console window
NS.DebugLog:Add(tag, msg)                -- append one line + mirror to the plain-text buffer
NS.DebugLog:Clear()                      -- clear the log + buffer
NS.DebugLog:ShowCopy()                   -- read-through EditBox with the whole log as plain text
NS.DebugLog:SetEnabled(on)               -- single seam for flipping State.debug (chat ack + header)
NS.DebugLog:RefreshHeader()              -- resync the ON/OFF toggle label + colour
NS.DebugLog.FormatPlain(ts, tag, msg)    -- pure formatter: "<ts> | [<tag>] <msg>" (Copy buffer)
NS.DebugLog.FormatColored(ts, tag, msg)  -- pure colour-coded formatter (console view)
NS.DebugLog.buffer                       -- capped plain-text mirror of the log
```

Both console + copy frames register in `UISpecialFrames` (Esc-closable). Detail in [midnight-quirks.md](./midnight-quirks.md).

### AbsorbTracker (`core/AbsorbTracker.lua`)

The AceAddon lifecycle. Promotes `NS` (see [The `NS` bus](#the-ns-bus)) and defines the handlers.

```lua
NS.addon               -- the AceAddon object (== NS via NewAddon(NS, ...))

addon:OnInitialize()   -- ADDON_LOADED timing: register the LSM monospace font, NS:InitDB(),
                       -- NS.Slash:Register().
addon:OnEnable()       -- PLAYER_LOGIN timing: ClearLSMCache -> GetLSM -> ApplyLSMBorderPatch ->
                       -- RestoreBarPosition -> UpdateBarAppearance -> UpdateAbsorbBar (direct
                       -- paint); RegisterEvent UNIT_ABSORB_AMOUNT_CHANGED / UNIT_MAXHEALTH /
                       -- PLAYER_ENTERING_WORLD; CreateOptionsPanel.
addon:OnAbsorbChanged(_, unit)  -- UNIT_ABSORB_AMOUNT_CHANGED; records a debug line, then calls
                                -- NS.RequestRepaint() (a burst coalesces into one repaint).
addon:OnMaxHealthChanged(_, unit)  -- UNIT_MAXHEALTH; NS.RequestRepaint() (absorb is shown as a
                                    -- fraction of max health, so it must repaint too).
addon:OnEnterWorld()   -- PLAYER_ENTERING_WORLD; NS.RequestRepaint().

NS.OnProfileChanged()  -- registered as the AceDB profile callback inside InitDB; runs
                       -- RestoreBarPosition + UpdateBarAppearance + UpdateAbsorbBar (direct
                       -- paint) + RefreshOptionsPanel.
```

Events are AceEvent (`self:RegisterEvent`), not raw `CreateFrame` frames. Detail in [data-flow.md](./data-flow.md).

### Defaults (`defaults/Profile.lua`)

Runs at file-load time; publishes the AceDB-shaped defaults.

```lua
NS.defaults          -- { profile = { ... }, global = { schemaVersion = 1 } }
NS.flatDefaults      -- alias to defaults.profile (GetSetting fallback + per-key panel defaults)
```

### Locale (`locales/enUS.lua`)

```lua
NS.L  -- setmetatable({}, { __index = function(_, k) return k end })
```

English-only in v1.9.0 — the metatable returns the key itself, so untranslated strings work and a missing key never errors. Nothing is wrapped in `NS.L[...]` yet; the seam is in place for a future localization pass.

### Bar (`modules/Bar.lua`)

Runs at file-load time, not as a function. Builds the frame from flat defaults and exports the handles for the paint path (`modules/Display.lua`):

```lua
NS.bar           -- the outer movable BackdropTemplate frame (named AbsorbTrackerFrame)
NS.statusBar     -- child StatusBar (also bar.statusBar)
NS.valueText     -- FontString child of statusBar (also bar.valueText)
NS.backdropInfo  -- reusable backdrop info table; mutated in place by UpdateBarAppearance
```

The `OnDragStop` handler persists the new position via `NS.SetSetting("position", ...)`.

### Display (`modules/Display.lua`)

```lua
NS.RestoreBarPosition()      -- re-applies the saved position table or centers the bar
NS.UpdateBarAppearance()     -- re-applies size, textures, colors, border, font, lock, visibility
NS.UpdateAbsorbBar()         -- reads UnitGetTotalAbsorbs + UnitHealthMax, pushes into
                             -- statusBar/valueText; honors the /at test hold window
```

`UpdateBarAppearance` does the `SetBackdrop(nil)` → `SetBackdrop(info)` clear-then-reapply dance (WoW's backdrop API no-ops on unchanged table identity). `UpdateAbsorbBar` hands the raw (possibly "secret") absorb value straight to `AbbreviateNumbers` — never through `tonumber`. Detail in [midnight-quirks.md](./midnight-quirks.md).

### Timer (`modules/Timer.lua`)

The coalescing repaint scheduler, driven by AceTimer (not `C_Timer`). No polling — repaints are
event-driven (see AbsorbTracker above).

```lua
NS.RequestRepaint()   -- trailing-edge one-shot: NS.addon:ScheduleTimer(fn, throttleWindow).
                       -- A repaint already pending coalesces (no-op); the timer self-clears
                       -- (pending = nil) inside its own callback before calling UpdateAbsorbBar.
```

### Schema (`settings/Schema.lua`)

```lua
NS.Schema                          -- flat array of rows; the source of truth

-- Registration (called from settings/<page>.lua at file-load time)
NS.RegisterSchemaRows(rows)        -- append rows to NS.Schema

-- Lookup
NS.FindSchemaRow(path)             -> row | nil
NS.SchemaForPage(pageKey)          -> { rows }   -- sorted group-stably (each group's
                                                 -- first-seen registration index, then
                                                 -- row.order within the group)

-- Write / reset (reads go through GetSetting directly)
NS.SetByPath(path, value)          -- SetSetting + fires row.onChange — the single write seam
                                   -- shared by /at set and every panel widget
NS.ApplyDefault(row)               -- resets row to row.default (deep-copying color tables) + onChange

-- Slash IO
NS.FormatSchemaValue(row, value)   -> string
NS.ParseSchemaValue(row, text)     -> value | nil, errMsg   -- type-aware parser (bool/number/
                                                            -- string/color)

-- Validation (called once from CreateOptionsPanel)
NS.ValidateSchema()                -> errors, resolved, missing
```

`ValidateSchema` now returns **three** values. Beyond checking row shape (path present, valid `page`, valid `type`), it verifies every non-profiles row's `path` resolves against `NS.defaults.profile` and warns on a miss — a typo'd path would otherwise silently read/write nothing. It only prints; it never refuses to register. Detail in [schema.md](./schema.md).

### Slash (`settings/Slash.lua`)

The AceConsole-registered `/at` dispatcher. `/at list` / `get` / `set` walk `NS.Schema` directly.

```lua
NS.COMMANDS         -- ordered { name, desc, fn } array of 15 verbs: help, config, list, get,
                    -- set, reset, resetall, resetposition, lock, unlock, toggle, debug, update,
                    -- test, profile. printHelp and the about page both iterate it.
NS.SlashCommands    -- alias of NS.COMMANDS (kept for settings/About.lua)

NS.Slash:OnSlash(msg)  -- parse + dispatch; unknown verb prints "unknown command '<verb>'" then help
NS.Slash:Register()    -- NS.addon:RegisterChatCommand("at", ...) + ("absorbtracker", ...)
```

No `SLASH_*` globals, no `SlashCmdList`. `/at options` is a back-compat alias for `/at config`. Profile subcommands are handled inline in `runProfile`. Detail in [profiles.md](./profiles.md).

### OptionsPanel (`settings/Panel.lua`)

The settings UI is split across `settings/Panel.lua` (registration shell) and the toolkit/widget/about slices (`settings/Helpers.lua`, `settings/ScrollPatch.lua`, `settings/Widgets.lua`, `settings/About.lua`) that decorate the same shared `NS.Helpers` table, plus the five `settings/<page>.lua` builders. `Panel.lua` publishes the empty `NS.Helpers` before those slices load; each slice extends it; the page files consume the toolkit at enable time.

```lua
-- Registration shell (settings/Panel.lua)
NS.PARENT_TITLE            -- "Ka0s Absorb Tracker" — single source of truth for the top-level
                           -- canvas title and the buildHeader breadcrumb prefix
NS.RegisterOptionsPage(key, name, builder)
    -- key:     "general" / "bar" / "border" / "font" / "profiles"
    -- name:    display name shown in the Blizzard Settings tree (and breadcrumb header)
    -- builder: function(mainCategory) -> sub-category | nil   (called at enable time)

NS.CreateOptionsPanel()    -- called from OnEnable once db is ready. Stashes NS.AceGUI once,
                           -- runs ValidateSchema, registers the main canvas category, then drains
                           -- the pending page builders.
NS.RefreshOptionsPanel()   -- routes to Helpers.RefreshAllPanels (re-runs every refresher)
NS.OpenOptionsPanel()      -- Settings.OpenToCategory(mainCategoryID) + expandMainCategory();
                           -- combat-lockdown gated (early-returns with a chat notice in combat).

NS.AceGUI                  -- the AceGUI-3.0 handle, stashed once in CreateOptionsPanel; the
                           -- toolkit / widget / about builders read this upvalue instead of
                           -- re-LibStub-ing.
```

```lua
-- Panel toolkit, decorated across settings/*.lua and exposed as NS.Helpers:
NS.Helpers
    -- settings/Helpers.lua
    Helpers.CreatePanel(name, title, opts)         -- canvas frame + header + optional Defaults btn
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
    Helpers.SECTION_HEADING_H                      -- (read by settings/Widgets.lua and settings/About.lua)

    -- settings/ScrollPatch.lua
    Helpers.PatchAlwaysShowScrollbar(scroll)       -- always-visible scrollbar override

    -- settings/Widgets.lua
    Helpers.RenderField(ctx, row, parent, w)       -- dispatches by row.type
    Helpers.RenderSchema(ctx, pageKey, afterGroup?) -- two-column layout from schema rows

    -- settings/About.lua
    Helpers.BuildMainContent(ctx)                  -- top-level "Ka0s Absorb Tracker" page builder
```

The color-picker drag throttle in `settings/Widgets.lua` uses `NS.addon:ScheduleTimer` (AceTimer one-shot), not `C_Timer.NewTimer`. Detail in [settings-panel.md](./settings-panel.md).

### Options pages (`settings/General|Bar|Border|Font|Profiles.lua`)

Each runs at file-load time: it calls `NS.RegisterSchemaRows({...})` (except Profiles, whose UI is AceDBOptions-supplied) and `NS.RegisterOptionsPage(key, name, build)`. The `build` closure calls `Helpers.RenderSchema(ctx, pageKey)` (General/Bar/Border/Font) at enable time. The LSM-backed rows in Bar/Border/Font set `dialogControl = "LSM30_Statusbar" | "LSM30_Border" | "LSM30_Font"` and `values = NS.Helpers.LSMValues(mediaType)`. `Profiles.build` returns nil (opting the page out) when AceDBOptions / AceConfigDialog / AceConfig / AceGUI aren't all present.

## Forward references

A small number of call sites reach across load order — the runtime modules (Core / Modules) load before the Settings tier:

- `core/AbsorbTracker.lua` (`OnEnable`) calls `NS.CreateOptionsPanel()` (defined in `settings/Panel.lua`, loaded later).
- `core/AbsorbTracker.lua` (`OnEnable`) calls `NS.ApplyLSMBorderPatch()` (defined in `core/LSMPatch.lua`).
- `NS.OnProfileChanged` calls `NS.RefreshOptionsPanel()` (defined in `settings/Panel.lua`).
- `settings/Slash.lua` handlers call `NS.RefreshOptionsPanel` / `NS.RestoreBarPosition` / `NS.UpdateAbsorbBar`.

These are guarded with runtime nil checks:

```lua
if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
```

In practice the calls always succeed because all files are loaded synchronously before `OnEnable` fires — but the nil-check keeps the load-order coupling soft, so a future refactor that moves a file won't error.

## Load order

`AbsorbTracker.toc` is the source of truth. Order is dependency order, not alphabetical. The tiers are **Libraries → Core → Defaults → Locales → Modules → Settings**:

1. `libs/` — LibStub, CallbackHandler-1.0, then the Ace3 stack (AceAddon / AceEvent / AceTimer / AceConsole / AceDB / AceGUI / AceConfig / AceDBOptions), LibSharedMedia-3.0, and the vendored upstream `AceGUI-3.0-SharedMediaWidgets` (LSM30_* swatch widgets) — all inside the `#@no-lib-strip@` block. Vendored **folder-per-lib** at `libs/` root (not `libs/Ace3/…`).
2. **Core** — `core/Compat.lua` (loads first: the deprecated-API shim), `Constants.lua`, `Namespace.lua`, `State.lua`, `Util.lua`, `Data.lua`, `Database.lua`, `LSMPatch.lua`, `DebugLog.lua`, `AbsorbTracker.lua` (AceAddon promotion + lifecycle).
3. **Defaults** — `defaults/Profile.lua` (AceDB defaults; runs at file-load).
4. **Locales** — `locales/enUS.lua` (`NS.L` metatable seam).
5. **Modules** — `modules/Bar.lua` (bar frame creation at file-load), `Display.lua` (render functions), `Timer.lua` (coalescing repaint scheduler).
6. **Settings** (last — depend on everything else being initialized) — `settings/Schema.lua` (registry), `Slash.lua` (`/at` dispatcher), `Panel.lua` (registration shell; publishes empty `NS.Helpers` + `NS.PARENT_TITLE`), then the toolkit slices `Helpers.lua` → `ScrollPatch.lua` → `Widgets.lua` → `About.lua` (each decorates `NS.Helpers`; order matters only between `Helpers` (defines `EnsureScroll`) and `ScrollPatch` (defines `PatchAlwaysShowScrollbar` that `EnsureScroll` references)), then the page builders `General.lua` → `Bar.lua` → `Border.lua` → `Font.lua` → `Profiles.lua` (each calls `RegisterSchemaRows` + `RegisterOptionsPage` at file-load; LSM-backed rows call `NS.Helpers.LSMValues(mediaType)`).

If you add a new runtime file, put it in the right tier in `AbsorbTracker.toc`.

## Module publishing pattern (idiom)

Modules that own a sub-surface publish it with the `NS.X = NS.X or {}` guard (`NS.Constants`, `NS.Compat`, `NS.Util`, `NS.State`, `NS.Slash`, `NS.DebugLog`, `NS.Helpers`, `NS.Schema`), then alias it to a file-local upvalue (`local C = NS.Constants`). Modules that only attach top-level functions (`Data`, `Display`, `Timer`) write straight to `NS`. The closest thing to a load-order guard is the import-as-locals pattern at the top of each file plus the `if NS.X then ... end` nil check around forward references.

## Test harness

There **is** a headless test harness at `tests/` — any doc claiming "there are no automated tests" is stale. `tests/run.lua` loads the runtime files in TOC order through `tests/loader.lua` against `tests/wow_mock.lua`, then runs `test_schema.lua`, `test_database.lua`, `test_compat.lua`, `test_util.lua`, `test_debuglog.lua`, `test_slash.lua`, `test_timer.lua`, and `test_visibility.lua` (60 tests total). The green gate is `lua tests/run.lua` + `luacheck .` (0/0) + `luac -p <file>`. See [smoke-tests.md](./smoke-tests.md) for the manual in-game QA recipe that complements it.
