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
- Helper functions attached directly (`Print`, `Debug`, `GetSetting`, `SetSetting`, `GetBarColor`, ...).
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

-- Cached math on NS to avoid global lookups in the bar paint path.
-- modules/Display.lua pulls floor/max as locals.
NS.floor  = math.floor
NS.max    = math.max
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

### Bus (`core/Bus.lua`)

The closed cross-module message bus (architecture-§4). Producers publish; each consumer subscribes on its own target — never two receivers on one shared object (CallbackHandler keys by `(message, target)`, so a shared target silently overwrites — anti-pattern #32).

```lua
NS.bus                 -- AceEvent-embedded shared publish target (NS.bus:SendMessage(...))
NS.NewBusTarget()      -- returns a fresh AceEvent-embedded table; one per receiver
NS.MSG                 -- catalogue (all Ka0s_AbsorbTracker_*, payload-free):
                       --   REPAINT    -> modules/Timer.lua   (coalesced repaint via RequestRepaint)
                       --   APPEARANCE -> modules/Display.lua (UpdateBarAppearance)
                       --   VISIBILITY -> modules/Display.lua (ApplyVisibility)
                       --   POSITION   -> modules/Display.lua (RestoreBarPosition)
                       --   UNITS      -> core/AbsorbTracker.lua (SyncUnitEventFrames --
                       --                 registers events only for enabled units)
```

Senders: `core/AbsorbTracker.lua` (event/lifecycle), `settings/Slash.lua`, `settings/General.lua`, `settings/Schema.lua`, `settings/Helpers.lua`. Consumers register at file load in `modules/Timer.lua` (`NS.Timer.__ev`), `modules/Display.lua` (`NS.Display.__ev`) and `core/AbsorbTracker.lua` (`NS.Events.__ev`, which owns the sole `UNITS` subscription). Full catalogue (sender/consumer/effect) in [ARCHITECTURE.md → Message Bus](./ARCHITECTURE.md#message-bus).

### Util (`core/Util.lua`)

```lua
NS.Print(...)       -- prepends NS.PREFIX and prints via DEFAULT_CHAT_FRAME; every arg routes
                    -- through NS.SafeToString, so a secret value never kills the line
NS.Util.print       -- alias of NS.Print
NS.IsConcatSafe(v)  -- probes table.concat({v}) to detect a WoW "secret" value (12.0 combat guard)
NS.SafeToString(v)  -- secret-safe stringifier; renders a secret as "<secret>"

-- The debug sink itself, NS.Debug(tag, fmt, ...), is defined in core/DebugLog.lua: it routes
-- every vararg through NS.SafeToString then fmt:format(...), so call sites use %s-only format
-- strings and can never raise on a secret. Routes to the on-screen console (never chat) when
-- State.debug is on; zero-cost when off.
```

### Perf (`core/Perf.lua`)

The performance probe (issue #17). Session-only, off by default, reached only through
`/at perf`. Costs an upvalue read, a field read and a boolean test when capture is off.

```lua
NS.Perf.on            -- capture running? read directly by every bracket call site
NS.Perf.suspended     -- addon inert? checked as step 0 of NS.ShouldShowBar
NS.Perf.SCHEMA        -- record schema version (1)
NS.Perf.RING_MAX      -- captures kept in AbsorbTrackerPerfDB (10)
NS.Perf.BUCKET_ORDER  -- report order; the buckets NEST (repaintPass contains paintBar)

NS.Perf.Note(key, ms)      -- accumulate one bracketed measurement (calls / totalMs / maxMs)
NS.Perf.Reset()            -- zero every bucket and both FPS arms
NS.Perf.Start(label)       -- reset, arm the OnUpdate FPS sampler, flip the brackets on
NS.Perf.Stop()             -> record   -- stop the sampler, return the assembled record
NS.Perf.BuildRecord(label) -> record   -- snapshot without stopping
NS.Perf.FormatReport(rec)  -> {string} -- plain lines (no frames), so it is testable headlessly
NS.Perf.EncodeJSON(value)  -> string   -- sorted keys, shared with tests/perf.lua
NS.Perf.Save(record)       -- append to the AbsorbTrackerPerfDB ring, trimming oldest-first
NS.Perf.Suspend()          -> bool     -- make the addon inert WITHOUT a /reload
NS.Perf.Resume()           -> bool     -- restore events, registrations and bars

-- The bracket idiom at every call site (modules/Display.lua, modules/Timer.lua,
-- core/AbsorbTracker.lua):
local t0 = Perf.on and debugprofilestop()
-- ... work ...
if t0 then Perf.Note("paintBar", debugprofilestop() - t0) end
```

Suspend enforces visibility **at the source** rather than hiding frames imperatively: because
`NS.ShouldShowBar` checks `Perf.suspended` first, suspend only has to publish `VISIBILITY` once and
no later publish — a combat transition, a target swap, a settings edit — can re-show a bar
mid-measurement. `NS.RequestRepaint` bails while suspended, and `NS.CancelPendingRepaint()` drops
any pass armed a moment before.

Protocol and how to read the output: [performance.md](./performance.md).

### PerfPanel (`core/PerfPanel.lua`)

The clickable step panel for a perf run, shown by `/at perf start`.

```lua
NS.PerfPanel.STEPS        -- ordered {key, label, command}; the order IS the workflow
NS.PerfPanel.StateOf(key) -> "done" | "ready" | "busy" | "locked"
NS.PerfPanel:Show()  / :Hide()  / :IsShown()
NS.PerfPanel:Refresh()    -- idempotent repaint from NS.Perf.Progress()
```

A dumb renderer. The progression lives in `NS.Perf.Progress()` — pure state, no frames, testable
headlessly — and the panel draws whatever that returns. Strictly linear: exactly one step is
`ready` at a time, so a run cannot be done out of order. The slash verbs are deliberately **not**
gated this way, so a run that cannot complete Experiment B can still be closed with
`/at perf finish`.

Buttons dispatch through `NS.Slash:OnSlash(step.command)` rather than calling the probe directly,
so a click and a typed command are one code path. The click handler re-checks `StateOf` instead of
trusting `Disable()` — a step run out of order corrupts the run the panel exists to protect.

Refreshes off the `PERF` bus message (sole subscriber, own target), which `core/Perf.lua` publishes
on every phase transition.

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
NS:RunMigrations()  -- reads/writes db.global.schemaVersion. Idempotent. The v3 lift is gated
                    -- PER PROFILE on profile.schemaVersion (NOT on the account-wide stamp, and
                    -- NOT on profile.units == nil -- see core/Database.lua's comment) and runs
                    -- over the active profile AND every profile in db.sv.profiles; it lifts the
                    -- pre-v3 flat appearance keys onto profile.units.player. The unconditional
                    -- backfill step then fills any missing flat OR per-unit key from
                    -- NS.defaults.profile; v2 drops the dead profile.updateInterval key
                    -- (repaints are event-driven now).
NS.MigrateProfileToV3(profile)
                    -- The per-profile lift itself. Public so NS.OnProfileChanged can re-run it
                    -- for a profile copied/restored in after InitDB's sweep. Returns false
                    -- immediately once the profile carries its own schemaVersion = 3 stamp.
```

### Units (`core/Units.lua`)

Single source of unit identity + per-unit config resolution. **The only file that reads
`db.profile.units` for appearance** — `modules/Bar.lua`, `modules/Display.lua`, and `core/Data.lua`
all call `NS.Units.Get(unit, key)` instead, so mirror resolution lives in exactly one place.

```lua
NS.Units.LIST                  -- { "player", "target", "focus" }
NS.Units.LABEL                 -- { player = "Player", target = "Target", focus = "Focus" }
NS.Units.APPEARANCE_KEYS       -- the 15 appearance keys, in profile order; mirror resolution and
                               -- CopyFromPlayer both walk this list

NS.Units.Config(unit)          -> profile.units[unit] | nil
NS.Units.IsEnabled(unit)       -> bool             -- the per-unit `enabled` flag
NS.Units.IsMirrored(unit)      -> bool             -- always false for "player" (the mirror source)
NS.Units.SourceUnit(unit)      -> "player" | unit  -- IsMirrored(unit) and "player" or unit
NS.Units.Get(unit, key)        -> value            -- mirror-resolved read; THE read path for all
                                                    -- 15 appearance keys
NS.Units.Set(unit, key, value) -- writes the unit's OWN config, NOT mirror-resolved (a write while
                               -- mirrored would silently edit the player's bar)
NS.Units.Position(unit)        -> position | nil   -- never mirror-resolved
NS.Units.SetPosition(unit, pos)
NS.Units.CopyFromPlayer(unit)  -- one-shot: deep-copies the player's 15 appearance keys onto
                               -- `unit`, then clears mirror. Does NOT copy `position` or
                               -- `enabled` — both stay per-unit by design.
NS.Units.DeepCopy(v)           -- generic recursive table copy
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
NS.DebugLog:IsShown()                    -- window visibility; read-only, never builds the frame
NS.DebugLog:ConsoleCheckbox()            -- {label,tooltip,get,set} spec for the General page's
                                         -- Debug console checkbox (window visibility only —
                                         -- it does NOT touch the State.debug logging flag)
NS.DebugLog:Add(tag, msg)                -- append one line + mirror to the plain-text buffer
NS.DebugLog:Clear()                      -- clear the log + buffer
NS.DebugLog:UpdateScrollBar()            -- resync the §11 scrollbar thumb/range to the log offset
NS.DebugLog:UpdateStatus()               -- resync the bottom "N / 500 lines" counter
NS.DebugLog:ShowCopy()                   -- read-through EditBox with the whole log as plain text
NS.DebugLog:SetEnabled(on)               -- single seam for flipping State.debug: colour-coded chat
                                         -- ack (ON green/OFF red, §5) + header + [Debug] bracket +
                                         -- [Init] session summary on enable
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
                       -- publishes POSITION -> APPEARANCE -> REPAINT on the bus;
                       -- self:SyncUnitEventFrames(); RegisterEvent PLAYER_ENTERING_WORLD /
                       -- PLAYER_REGEN_DISABLED / PLAYER_REGEN_ENABLED; CreateOptionsPanel.
addon:SyncUnitEventFrames()    -- one private RegisterUnitEvent frame PER unit, registered for
                               -- UNIT_ABSORB_AMOUNT_CHANGED/UNIT_MAXHEALTH only while that unit's
                               -- bar is enabled, UnregisterAllEvents'd when it is not. Also gates
                               -- PLAYER_TARGET_CHANGED / PLAYER_FOCUS_CHANGED on the same flag --
                               -- those fire constantly in ordinary play, so that is where the
                               -- saving actually is. Frames are built once and reused; all share
                               -- one OnEvent stub dispatching to OnAbsorbChanged /
                               -- OnMaxHealthChanged. Re-run on every UNITS message.
NS.Events.__ev                 -- bus target owning the SOLE UNITS subscription -> the sync above
addon:OnAbsorbChanged(_, unit)  -- UNIT_ABSORB_AMOUNT_CHANGED (player/target/focus); records a
                                -- debug line (player only), then publishes REPAINT (a burst
                                -- coalesces into one repaint, all units repainted together).
addon:OnMaxHealthChanged(_, unit)  -- UNIT_MAXHEALTH (player/target/focus); publishes REPAINT
                                    -- (absorb is shown as a fraction of max health, so it must
                                    -- repaint too; unit argument itself is unused).
addon:OnEnterWorld()   -- PLAYER_ENTERING_WORLD; publishes VISIBILITY + REPAINT.
addon:OnUnitSwap()     -- PLAYER_TARGET_CHANGED / PLAYER_FOCUS_CHANGED; publishes VISIBILITY +
                       -- REPAINT (a swap changes both which bars should be visible, via the
                       -- UnitExists step of the visibility ladder, and what they should read).
addon:OnEnterCombat()  -- PLAYER_REGEN_DISABLED; publishes VISIBILITY + REPAINT, resets per-combat
                       -- debug counters.
addon:OnLeaveCombat()  -- PLAYER_REGEN_ENABLED; publishes VISIBILITY + REPAINT, flushes one
                       -- "[Combat] left: N events, M repaints" rollup (player events only,
                       -- deliberately; never replays /at config).

NS.NoteRepaint()       -- bumps the debug-gated repaint counter; called directly by
                       -- modules/Timer.lua's doRepaint ONCE per coalesced pass in which at
                       -- least one bar painted -- not once per bar, or M would scale with the
                       -- visible bar count and could exceed the player-only event count N.
                       -- (An intra-implementation debug hook, not a bus message.)
NS.OnProfileChanged()  -- registered as the AceDB profile callback inside InitDB; publishes
                       -- POSITION + APPEARANCE + REPAINT, then RefreshOptionsPanel.
```

Cross-module signalling goes through the message bus (see [Bus](#bus-corebuslua) above) — the handlers publish `NS.MSG.*` rather than calling the display module directly. Events are AceEvent (`self:RegisterEvent`), **except** the two `UNIT_*` events (`UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_MAXHEALTH`), which use one private `CreateFrame` frame PER UNIT with `RegisterUnitEvent` for C-level unit filtering — a documented §9.1 deviation ([ARCHITECTURE.md → Standards Deviations](./ARCHITECTURE.md#standards-deviations)). A frame each (rather than packing two tokens onto one, `RegisterUnitEvent`'s cap) lets a unit's registration be added or dropped on its own as its bar is enabled or disabled, so a disabled unit is registered for nothing at all; `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` are gated on the same flag. Detail in [data-flow.md](./data-flow.md).

### Defaults (`defaults/Profile.lua`)

Runs at file-load time; publishes the AceDB-shaped defaults.

```lua
NS.defaults          -- { profile = { schemaVersion = 1, <3 flat globals>,
                     --               units = { player, target, focus } },
                     --   global  = { schemaVersion = 4 } }
                     -- profile.schemaVersion defaults to 1 ("not yet lifted") on purpose:
                     -- AceDB copyDefaults fills it before RunMigrations reads it, so a
                     -- default of 3 would mark every upgrading profile as already migrated.
NS.flatDefaults      -- alias to defaults.profile (GetSetting fallback for flat keys)
NS.unitDefaults      -- alias to defaults.profile.units.player — the canonical per-row default
                     -- source settings/{Bar,Border,Font}.lua read from, shared by all 3 units
```

### Locale (`locales/enUS.lua`)

```lua
NS.L  -- setmetatable({}, { __index = function(_, k) return k end })
```

English-only in v1.9.0 — the metatable returns the key itself, so untranslated strings work and a missing key never errors. Nothing is wrapped in `NS.L[...]` yet; the seam is in place for a future localization pass.

### Bar (`modules/Bar.lua`)

Runs at file-load time, not as a function. `NS.CreateBar(unit, globalName)` builds one bar frame from `NS.unitDefaults`; called once per `NS.Units.LIST` entry:

```lua
NS.CreateBar(unit, globalName)  -- builds one bar frame; each owns its OWN backdropInfo table
                                -- (one shared table can't hold three different border sizes —
                                -- SetBackdrop keys off table identity)
NS.bars          -- { player = <frame>, target = <frame>, focus = <frame> }, named
                 -- AbsorbTrackerFrame / AbsorbTrackerTargetFrame / AbsorbTrackerFocusFrame
NS.bar           -- = NS.bars.player — player alias for call sites that predate multi-unit
NS.statusBar     -- = NS.bars.player.statusBar
NS.valueText     -- = NS.bars.player.valueText
NS.backdropInfo  -- = NS.bars.player.backdropInfo
```

Each frame also carries `bar.unitLabel` — a FontString anchored `BOTTOM` to the bar's `TOP`, holding
`NS.Units.LABEL[unit]`. It is created hidden and toggled by `UpdateBarAppearance` with the global
`locked` flag: the three bars stack and look alike, so the label is what identifies a drag target.
It is an affordance, not a styled element — no schema row, fixed 10pt, the unit's own font face.

The `OnDragStop` handler persists the new position via `NS.Units.SetPosition(self.unit, ...)` — never mirrored, so the write always targets the dragged frame's own unit.

### Display (`modules/Display.lua`)

Every function below takes a `unit` argument (defaulting to `"player"`):

```lua
NS.ForEachUnit(fn)            -- runs fn(unit) for every unit in NS.Units.LIST order; the bus
                               -- handlers drive all three bars through this
NS.DefaultPosition(unit)       -- pre-drag default anchor: player is CENTER; target/focus stack
                               -- upward, one player-bar-height + gap apart
NS.RestoreBarPosition(unit)   -- re-applies the saved position table or the stacked default
NS.UpdateBarAppearance(unit)  -- re-applies size, textures, colors, border, font, lock, the
                               -- unlocked-only unit label, and visibility (every value read via
                               -- NS.Units.Get(unit, key), so a mirrored unit re-reads the
                               -- player's live settings)
NS.UpdateAbsorbBar(unit)      -- reads UnitGetTotalAbsorbs(unit) + UnitHealthMax(unit), pushes into
                               -- that unit's statusBar/valueText; honors the /at test hold window
NS.ShouldShowBar(unit)        -- the four-step visibility ladder: per-unit enabled ->
                               -- showOnlyInCombat vs. UnitAffectingCombat("player") ->
                               -- (target/focus only) UnitExists(unit) -> shown. There is no
                               -- master `hidden` toggle above it -- v4 dropped it.
NS.ApplyVisibility(unit)      -- shows/hides that unit's bar frame per ShouldShowBar(unit)
```

`UpdateBarAppearance` does the `SetBackdrop(nil)` → `SetBackdrop(info)` clear-then-reapply dance (WoW's backdrop API no-ops on unchanged table identity); it ends with a direct `NS.ApplyVisibility(unit)` (intra-concern). `UpdateAbsorbBar` hands the raw (possibly "secret") absorb value straight to `AbbreviateNumbers` — never through `tonumber`. Detail in [midnight-quirks.md](./midnight-quirks.md).

**Bus consumer.** These functions are invoked through the message bus: at file load Display registers `NS.Display.__ev = NS.NewBusTarget()` and subscribes `APPEARANCE` → `NS.ForEachUnit(UpdateBarAppearance)`, `VISIBILITY` → `NS.ForEachUnit(ApplyVisibility)`, `POSITION` → `NS.ForEachUnit(RestoreBarPosition)` — fanning each handler out over every unit so the bus messages stay payload-free. The functions stay defined on `NS` (directly unit-testable); the bus handlers just call them.

### Timer (`modules/Timer.lua`)

The coalescing repaint scheduler, driven by AceTimer (not `C_Timer`). No polling — repaints are
event-driven (see AbsorbTracker above).

```lua
NS.RequestRepaint()   -- trailing-edge one-shot: NS.addon:ScheduleTimer(fn, throttleWindow).
                       -- A repaint already pending coalesces (no-op); the timer self-clears
                       -- (pending = nil) inside its own callback, then fans out over
                       -- NS.ForEachUnit into UpdateAbsorbBar(unit) — one pass paints all three
                       -- bars. Calling UpdateAbsorbBar bare here would paint the player only.
NS.Timer.__ev         -- bus target (NS.NewBusTarget()); owns the sole REPAINT subscription and
                       -- funnels it into NS.RequestRepaint. Registered at file load.
```

### Schema (`settings/Schema.lua`)

```lua
NS.Schema                          -- flat array of rows; the source of truth

-- Registration (called from settings/<page>.lua at file-load time)
NS.RegisterSchemaRows(rows)        -- append rows to NS.Schema

-- Lookup
NS.FindSchemaRow(path)             -> row | nil
NS.SchemaForPage(pageKey, unit)    -> { rows }   -- sorted group-stably (each group's
                                                 -- first-seen registration index, then
                                                 -- row.order within the group); `unit` filters to
                                                 -- that unit's rows plus unit-agnostic ones —
                                                 -- omit to get every unit's rows
NS.PartitionUnitRows(rows)         -> perUnit, styled   -- alwaysPerUnit rows vs. mirror-hidden
                                                         -- appearance rows

-- Dotted-path walkers (units.<unit>.<key> vs. flat keys — same seam)
NS.ResolvePath(tbl, path)          -> value | nil
NS.SetPath(tbl, path, value)

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

The AceConsole-registered `/at` dispatcher. `/at list` / `get` / `set` walk `NS.Schema` directly, using **fully-qualified** dotted paths only — `/at set units.target.barWidth 250` works, the pre-1.9 unqualified `/at set barWidth 250` does not (a deliberate breaking change; see [scope.md](./scope.md)).

```lua
NS.COMMANDS         -- ordered { name, desc, fn } array of 16 verbs: help, config, list, get,
                    -- set, reset, resetall, resetposition, lock, unlock, toggle, debug, update,
                    -- version, test, profile. printHelp and the about page both iterate it.
NS.SlashCommands    -- alias of NS.COMMANDS (kept for settings/About.lua)

NS.Slash:OnSlash(msg)  -- parse + dispatch; unknown verb prints "unknown command '<verb>'" then help
NS.Slash:Register()    -- NS.addon:RegisterChatCommand("at", ...) + ("absorbtracker", ...)
```

`/at list` groups Bar/Border/Font rows once per unit (`[bar / player]`, `[bar / target]`, `[bar / focus]`, etc. — `PER_UNIT_PAGES` in `settings/Slash.lua`); General has no per-unit rows. `/at reset <page>` spans all three units (`SchemaForPage(page)` with no unit filter). `/at resetposition` clears all three units' saved positions. No `SLASH_*` globals, no `SlashCmdList`. `/at options` is a back-compat alias for `/at config`. Profile subcommands are handled inline in `runProfile`. Detail in [profiles.md](./profiles.md).

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
                           -- combat-lockdown gated: in combat it REFUSES with a grey [AT] notice
                           -- and returns (options-ui-§2) — no defer-and-replay.

NS.AceGUI                  -- the AceGUI-3.0 handle, stashed once in CreateOptionsPanel; the
                           -- toolkit / widget / about builders read this upvalue instead of
                           -- re-LibStub-ing.
```

```lua
-- Panel toolkit, decorated across settings/*.lua and exposed as NS.Helpers:
NS.Helpers
    -- settings/Helpers.lua
    Helpers.CreatePanel(name, title, opts)         -- canvas frame + header; records wantsDefaultsButton
    Helpers.EnsureDefaultsButton(panel)            -- builds that Defaults button once, on the panel's
                                                   -- first OnShow, wiring the parked defaultsOnClick
                                                   -- (options-ui-§5: a widget created at load keeps
                                                   -- Blizzard's stock art — skins hook later)
    Helpers.EnsureScroll(ctx)                      -- lazy AceGUI ScrollFrame; calls PatchAlwaysShowScrollbar
    Helpers.Section(ctx, label)                    -- AceGUI Heading row
    Helpers.InlineButtonPair(ctx, leftSpec, rightSpec)
    Helpers.AttachTooltip(widget, label, tooltip)
    Helpers.AddSpacer(scroll, height)              -- invisible full-width SimpleGroup
    Helpers.LSMValues(mediaType)                   -- deferred LSM hash factory for schema rows
    Helpers.ClearScroll(ctx)                       -- releases every AceGUI child + resets the
                                                   -- section-heading tracker and ctx.refreshers
    Helpers.RenderUnitPanel(ctx, pageKey)          -- Bar/Border/Font: Unit dropdown + mirror
                                                   -- header (checkbox + copy button), full
                                                   -- rebuild via ClearScroll on every call
    Helpers.RestoreDefaults(pageKey, ctx)
    Helpers.RestoreAllDefaults()                   -- every schema-driven page; skips profiles;
                                                   -- clears every unit's saved position too
    Helpers.RefreshAllPanels()                     -- run every panel ctx's refresher closures
    Helpers.ROW_VSPACER                            -- layout constants exposed for cross-slice use
    Helpers.SECTION_HEADING_H                      -- (read by settings/Widgets.lua and settings/About.lua)
    Helpers.BUTTON_PAIR_REL                        -- 0.492 — inline button-pair relative width

    -- settings/ScrollPatch.lua
    Helpers.PatchAlwaysShowScrollbar(scroll)       -- always-visible scrollbar override

    -- settings/Widgets.lua
    Helpers.RenderField(ctx, row, parent, w)       -- dispatches by row.type
    Helpers.SessionCheckbox(ctx, parent, w, spec)  -- non-schema checkbox (caller get/set)
    Helpers.RenderRows(ctx, rows, afterGroup?, pairWith?)      -- two-column layout over an
                                                               -- EXPLICIT row list; skips
                                                               -- skipRender rows
    Helpers.RenderSchema(ctx, pageKey, afterGroup?, pairWith?) -- thin wrapper:
                                                               -- RenderRows(ctx,
                                                               -- NS.SchemaForPage(pageKey,
                                                               -- ctx.unit), ...) — used by
                                                               -- General, which never sets
                                                               -- ctx.unit, so its three
                                                               -- units.<unit>.enabled rows all
                                                               -- render (no unit filter).
                                                               -- pairWith attaches the Debug
                                                               -- console beside the lone
                                                               -- Enable Focus Bar row

    -- settings/About.lua
    Helpers.BuildMainContent(ctx)                  -- top-level "Ka0s Absorb Tracker" page builder
```

The color-picker drag throttle in `settings/Widgets.lua` uses `NS.addon:ScheduleTimer` (AceTimer one-shot), not `C_Timer.NewTimer`. Detail in [settings-panel.md](./settings-panel.md).

### Options pages (`settings/General|Bar|Border|Font|Profiles.lua`)

Each runs at file-load time and calls `NS.RegisterOptionsPage(key, name, build)`. General calls `NS.RegisterSchemaRows({...})` once for its four unit-agnostic globals; Bar/Border/Font instead define `addUnitRows(unit)` and call it once per `NS.Units.LIST` entry, so each registers its appearance keys three times (path prefixed `units.<unit>.`, tagged `unit = unit`) — plus a `mirror` row (`skipRender = true`) for target/focus only. Profiles registers no rows; its UI is AceDBOptions-supplied. At enable time, the `build` closure calls `Helpers.RenderSchema(ctx, pageKey)` (General — no dropdown) or `Helpers.RenderUnitPanel(ctx, pageKey)` (Bar/Border/Font — Unit dropdown + mirror header), with **no** `rendered` one-shot guard on the latter (`RenderUnitPanel` does a full rebuild every call, by design — unit switches and mirror toggles need it). The LSM-backed rows in Bar/Border/Font set `dialogControl = "LSM30_Statusbar" | "LSM30_Border" | "LSM30_Font"` and `values = NS.Helpers.LSMValues(mediaType)`. `Profiles.build` returns nil (opting the page out) when AceDBOptions / AceConfigDialog / AceConfig / AceGUI aren't all present.

## Forward references

A small number of call sites reach across load order — the runtime modules (Core / Modules) load before the Settings group:

- `core/AbsorbTracker.lua` (`OnEnable`) calls `NS.CreateOptionsPanel()` (defined in `settings/Panel.lua`, loaded later).
- `core/AbsorbTracker.lua` (`OnEnable`) calls `NS.ApplyLSMBorderPatch()` (defined in `core/LSMPatch.lua`).
- `NS.OnProfileChanged` calls `NS.RefreshOptionsPanel()` (defined in `settings/Panel.lua`).
- `settings/Slash.lua` handlers call `NS.RefreshOptionsPanel` directly, and publish bus messages for display work (`update` → `REPAINT`, `resetposition` → `POSITION`). `toggle` publishes nothing itself — it writes `hidden` via `NS.SetByPath` and that row's `onChange` does the republishing.

These are guarded with runtime nil checks:

```lua
if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
```

In practice the calls always succeed because all files are loaded synchronously before `OnEnable` fires — but the nil-check keeps the load-order coupling soft, so a future refactor that moves a file won't error.

## Load order

`AbsorbTracker.toc` is the source of truth. Order is dependency order, not alphabetical. The load groups are **Libraries → Locales → Core → Defaults → Modules → Settings**:

1. `libs/` — LibStub, CallbackHandler-1.0, then the Ace3 stack (AceAddon / AceEvent / AceTimer / AceConsole / AceDB / AceGUI / AceConfig / AceDBOptions), LibSharedMedia-3.0, and the vendored upstream `AceGUI-3.0-SharedMediaWidgets` (LSM30_* swatch widgets) — all inside the `#@no-lib-strip@` block. Vendored **folder-per-lib** at `libs/` root (not `libs/Ace3/…`).
2. **Locales** — `locales/enUS.lua` (`NS.L` metatable seam; loads directly after Libraries per `toc-file-§5` — no dependency on `core/*`).
3. **Core** — `core/Compat.lua` (loads first: the deprecated-API shim), `Constants.lua`, `Namespace.lua`, `State.lua`, `Bus.lua` (the closed message bus — `NS.bus` / `NS.NewBusTarget` / `NS.MSG`), `Util.lua`, `Data.lua`, `Units.lua` (unit identity + mirror resolution — loads after `Data.lua`, before `Database.lua` since migration needs `NS.Units.LIST`/`APPEARANCE_KEYS`), `Database.lua`, `LSMPatch.lua`, `DebugLog.lua`, `AbsorbTracker.lua` (AceAddon promotion + lifecycle).
4. **Defaults** — `defaults/Profile.lua` (AceDB defaults; runs at file-load).
5. **Modules** — `modules/Bar.lua` (bar frame creation at file-load), `Display.lua` (render functions + `NS.Display.__ev` bus consumer), `Timer.lua` (coalescing repaint scheduler + `NS.Timer.__ev` bus consumer).
6. **Settings** (last — depend on everything else being initialized) — `settings/Schema.lua` (registry), `Slash.lua` (`/at` dispatcher), `Panel.lua` (registration shell; publishes empty `NS.Helpers` + `NS.PARENT_TITLE`), then the toolkit slices `Helpers.lua` → `ScrollPatch.lua` → `Widgets.lua` → `About.lua` (each decorates `NS.Helpers`; order matters only between `Helpers` (defines `EnsureScroll`) and `ScrollPatch` (defines `PatchAlwaysShowScrollbar` that `EnsureScroll` references)), then the page builders `General.lua` → `Bar.lua` → `Border.lua` → `Font.lua` → `Profiles.lua` (each calls `RegisterSchemaRows` + `RegisterOptionsPage` at file-load; LSM-backed rows call `NS.Helpers.LSMValues(mediaType)`).

If you add a new runtime file, put it in the right load group in `AbsorbTracker.toc`.

## Module publishing pattern (idiom)

Modules that own a sub-surface publish it with the `NS.X = NS.X or {}` guard (`NS.Constants`, `NS.Compat`, `NS.Util`, `NS.State`, `NS.Slash`, `NS.DebugLog`, `NS.Helpers`, `NS.Schema`), then alias it to a file-local upvalue (`local C = NS.Constants`). Modules that mostly attach top-level functions (`Data`, `Display`, `Timer`) write straight to `NS` — `Display` and `Timer` additionally publish a small `NS.Display` / `NS.Timer` table to hold their `__ev` bus target, and `core/Bus.lua` publishes `NS.bus` / `NS.NewBusTarget` / `NS.MSG`. The closest thing to a load-order guard is the import-as-locals pattern at the top of each file plus the `if NS.X then ... end` nil check around forward references.

## Test harness

There **is** a headless test harness at `tests/` — any doc claiming "there are no automated tests" is stale. `tests/run.lua` loads the runtime files in TOC order through `tests/loader.lua` against `tests/wow_mock.lua`, then runs `test_schema.lua`, `test_database.lua`, `test_compat.lua`, `test_util.lua`, `test_debuglog.lua`, `test_slash.lua`, `test_timer.lua`, `test_visibility.lua`, `test_bus.lua`, `test_data.lua`, `test_display.lua`, `test_helpers.lua`, `test_slashcmds.lua`, `test_widgets.lua`, and `test_units.lua` (authoritative case count in the generated [test-cases.md](./test-cases.md)). The green gate is `lua tests/run.lua` + `luacheck .` (0/0) + `luac -p <file>`. See [smoke-tests.md](./smoke-tests.md) for the manual in-game QA recipe that complements it.
