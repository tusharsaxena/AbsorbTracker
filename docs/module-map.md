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
- Sub-tables that namespace a module's surface (`Constants`, `Compat`, `Util`, `Slash`).
- Library instances published under an addon-owned name: `DebugLog` (`LibKa0s-DebugLog-1.0`'s console), `Helpers` (`LibKa0s-Options-1.0`'s options instance), `Perf` (`LibKa0s-Perf-1.0`'s probe). These are not addon sub-tables — they are what `lib:New(descriptor)` returned, assigned outright.
- Helper functions attached directly (`Print`, `Debug`, `GetSetting`, `SetSetting`, `GetBarColor`, ...).
- The schema registry (`Schema`) and the localized-string table (`L`).
- The slash command list (`COMMANDS`) — also rendered on the about page.
- The stashed AceGUI reference (`AceGUI`), handed over by `LibKa0s-Options-1.0` through the descriptor's `onAceGUI` callback, which fires once during `CreateOptionsPanel`.

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
NS.MSG                 -- catalog (all Ka0s_AbsorbTracker_*, payload-free):
                       --   REPAINT    -> modules/Timer.lua   (coalesced repaint via RequestRepaint)
                       --   APPEARANCE -> modules/Display.lua (UpdateBarAppearance)
                       --   VISIBILITY -> modules/Display.lua (ApplyVisibility)
                       --   POSITION   -> modules/Display.lua (RestoreBarPosition)
                       --   UNITS      -> core/AbsorbTracker.lua (SyncUnitEventFrames --
                       --                 registers events only for enabled units)
```

Senders: `core/AbsorbTracker.lua` (event/lifecycle), `settings/Slash.lua`, `settings/General.lua`, `settings/Schema.lua`, `settings/UnitPanel.lua` (`Helpers.ResetAllPositions` publishes `POSITION`). Consumers register at file load in `modules/Timer.lua` (`NS.Timer.__ev`), `modules/Display.lua` (`NS.Display.__ev`) and `core/AbsorbTracker.lua` (`NS.Events.__ev`, which owns the sole `UNITS` subscription). Full catalog (sender/consumer/effect) in [ARCHITECTURE.md → Message Bus](./ARCHITECTURE.md#message-bus).

### CoreSetup (`core/CoreSetup.lua`)

Wires the addon into `LibKa0s-Core-1.0` — the secret guard, the stringifier and the prefixed chat
printer are library code now (`libs/LibKa0s/Core.lua`), vendored the same way Ace3 is. They were
identical in every Ka0s addon and wrong in slightly different ways in several of them. This file
supplies only the part that's ours: which tag the lines carry, and what happens when the library is
not there.

```lua
local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)
local printer = lib:New({ prefix = function() return NS.PREFIX end })
-- The prefix goes in as a FUNCTION, not as the value of NS.PREFIX: the printer is built once at
-- load, and the function form keeps a later change to NS.PREFIX from being frozen out.

NS.Print(...)       -- prepends NS.PREFIX and prints via DEFAULT_CHAT_FRAME; every arg routes
                    -- through SafeToString, so a secret value never kills the line
NS.Util.print       -- THE SAME function object as NS.Print, not a second wrapper: AceAddon:NewAddon
                    -- stamps AceConsole's :Print over NS.Print, and core/AbsorbTracker.lua reclaims
                    -- it by repointing NS.Print at NS.Util.print. That only restores what the
                    -- settings files captured at load because it is the identical object.
NS.IsConcatSafe(v)  -- lib.IsConcatSafe: probes table.concat({v}) to detect a WoW "secret" value
NS.SafeToString(v)  -- lib.SafeToString: renders a secret as "<secret>"

-- With the library absent this file falls back to the pre-library implementations rather than to
-- a no-op — five settings files do `local print = NS.Print` at load, so a nil printer takes the
-- settings UI down and a silent one makes /at answer nothing — and says the "LibKa0s is missing"
-- line ONCE, on the first line the addon prints.

-- The debug sink itself, NS.Debug(tag, fmt, ...), is LibKa0s-DebugLog-1.0's, published under
-- that name by core/DebugLogSetup.lua: it routes every vararg through NS.SafeToString (handed to
-- the library as a call-time hook) then fmt:format(...), so call sites use %s-only format
-- strings and can never raise on a secret. Routes to the on-screen console (never chat) when
-- State.debug is on; zero-cost when off.
```

### PerfSetup (`core/PerfSetup.lua`)

Wires the addon into `LibKa0s-Perf-1.0` (issue #17) — the probe, its record schema, and the
clickable step panel are all library code now (`libs/LibKa0s/Perf.lua` /
`libs/LibKa0s/PerfPanel.lua`), vendored the same way Ace3 is. This file supplies only the part
that's ours: a **descriptor** passed to `lib:New(descriptor)`.

```lua
local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)
NS.Perf = lib and lib:New({
    name = addonName, sv = "AbsorbTrackerPerfDB", version = NS.version, slash = "/at",
    buckets = { {key="absorbEvent"}, {key="repaintPass"},
                {key="paintBar", within="repaintPass"}, ... },
    suspend = function() ... end,  -- makes the addon inert WITHOUT a /reload
    resume  = function() ... end,  -- restores events, registrations and bars
    log = ..., print = ..., showLog = ..., decorate = ...,
}) or {
    -- Degrades cleanly when the lib is absent. Covers everything the addon calls: the bracket
    -- idiom, the show ladder, and — because `/at perf` is registered either way — an OnCommand
    -- that says why there is nothing to run.
    on = false, suspended = false, Note = function() end,
    OnCommand = function() return { "...the LibKa0s library is missing..." } end,
}
```

`NS.Perf` is the returned instance — same shape as before extraction (`on`, `suspended`, `Note`,
`Reset`, `Start`, `Stop`, `Suspend`, `Resume`, `BuildRecord`, `FormatReport`, `EncodeJSON`, `Save`,
`ShowPanel`/`HidePanel`/`TogglePanel`/`RefreshPanel`, `OnCommand`, …). This file must load before any
module takes `local Perf = NS.Perf` as an upvalue — hence its position immediately after
`core/CoreSetup.lua` in the TOC, same slot the old `core/Perf.lua` held.

Suspend enforces visibility **at the source** rather than hiding frames imperatively: because
`NS.ShouldShowBar` checks `NS.Perf.suspended` first, `suspend` only has to publish `VISIBILITY` once
and no later publish — a combat transition, a target swap, a settings edit — can re-show a bar
mid-measurement. The descriptor's `suspend` also cancels any pending repaint.

The clickable step panel is drawn and refreshed entirely inside the library, off the instance's own
state (`RefreshPanel`) — there is no addon-side `NS.PerfPanel` and no bus message for it. Buttons
call the lib's own `P.OnCommand` directly, not this addon's slash layer, so a click and a typed
command run one code path; the lib prints the returned lines through the descriptor's `print` hook,
which is what makes a click say in chat exactly what typing says.

The full descriptor contract and public surface `lib:New` returns are documented in the library
itself, not duplicated here: see the
[LibKa0s README](https://github.com/tusharsaxena/LibKa0s/blob/master/README.md). Protocol and how to
read the output from this addon's side: [performance.md](./performance.md).

### Data (`core/Data.lua`)

The AceDB read/write seam plus the LSM fetchers and the class-color-aware color resolvers. `NS.db` is declared here (nil until `InitDB`).

```lua
-- Database access
NS.GetSetting(key)            -> value        -- reads db.profile, falls back to flatDefaults
NS.SetSetting(key, value)     -- writes to db.profile (no-op if db unset)

-- LibSharedMedia
NS.GetLSM()                   -> LSM | nil     -- cached LibStub lookup
NS.ClearLSMCache()            -- reset the cached LSM ref; called on enable
NS.GetBarTexture(unit)        -> texturePath   -- falls back to FALLBACK_TEXTURE
NS.GetBgTexture(unit)         -> texturePath
NS.GetBorder(unit)            -> borderPath    -- falls back to FALLBACK_BORDER
NS.GetFont(unit)              -> fontPath      -- falls back to FALLBACK_FONT
                              -- all four resolve the unit through NS.Units.Get, so a mirrored
                              -- bar reads the player's media live

-- Color resolution (re-reads useClassColor* at call time)
NS.GetBarColor(unit)          -> r, g, b, a   -- the class color itself is ALWAYS the player's
NS.GetBgColor(unit)           -> r, g, b, a
NS.GetBorderColor(unit)       -> r, g, b, a
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
                    -- backfill step (backfillFlatKeys + backfillUnitKeys) then fills any missing
                    -- flat OR per-unit key from NS.defaults.profile; then the loop walks the
                    -- file-local SCHEMA_STEPS ladder -- v2 drops the dead profile.updateInterval
                    -- key (repaints are event-driven now), v3 is stamp-only, v4 drops `hidden`.
                    -- A new version is ONE new SCHEMA_STEPS row, not another `if` arm.
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

### DebugLogSetup (`core/DebugLogSetup.lua`)

Wires the addon into `LibKa0s-DebugLog-1.0` — the console window, its Copy window, the two
formatters, the 500-line buffer and the enable seam are all library code now
(`libs/LibKa0s/DebugLog.lua`), vendored the same way Ace3 is. This file supplies only the part
that's ours: a **descriptor** passed to `lib:New(descriptor)`.

```lua
local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)
NS.DebugLog = lib:New({
    name  = addonName,              -- seeds AbsorbTrackerDebugWindow / …DebugCopyWindow / …Scroll
    title = "Absorb Tracker",       -- the library appends " — Debug"
    font  = NS.Constants.FONT_MONO, -- the fixed monospace face is ours to choose
    slash = "/at",                  -- composes the console checkbox's tooltip

    -- THE FLAG STAYS OURS. The library keeps no copy: NS.ShouldShowBar's ladder and the settings
    -- panel both read NS.State.debug, so a second copy would be a second truth.
    isEnabled  = function() return NS.State and NS.State.debug or false end,
    setEnabled = function(on) NS.State.debug = on end,

    -- Resolved at CALL time, not captured: core/AbsorbTracker.lua reclaims NS.Print from
    -- AceConsole's embed AFTER this file loads, and a captured reference would freeze.
    print        = function(line) NS.Print(line) end,
    safeToString = function(v) return NS.SafeToString(v) end,

    initSummary = function() ... end,          -- the [Init] line: name+version, schema, profile.
                                               -- The library owns WHEN it lands (on enable —
                                               -- the flag is off at login); only we know what
                                               -- it says.
    onVisibilityChanged = function() ... end,  -- NS.Helpers.RefreshAllPanels, so a console opened
                                               -- by /at debug moves the General page's checkbox
})

-- Bound bare, which is why all fifteen NS.Debug call sites across five files are unchanged.
NS.Debug = NS.DebugLog.Debug
```

With the library absent this file degrades to a stub covering **every** member the addon calls
(`/at debug`, the General page's checkbox, `core/PerfSetup.lua`'s log sink) — and the stub still
flips `NS.State.debug`, because the flag is ours and a user who types `/at debug on` should not be
told nothing happened. What is lost is the window, and the stub says so once.

The instance's surface, unchanged from before the extraction:

```lua
NS.Debug(tag, fmt, ...)   -- the global debug sink; no-op (zero alloc) when State.debug is off,
                          -- otherwise appends a formatted line to the console.

NS.DebugLog:Show() / :Hide() / :Toggle() -- the console window
NS.DebugLog:IsShown()                    -- window visibility; read-only, never builds the frame
NS.DebugLog:ConsoleCheckbox()            -- {label,tooltip,get,set} spec for the General page's
                                         -- Debug console checkbox (window visibility only —
                                         -- it does NOT touch the State.debug logging flag)
NS.DebugLog:Add(tag, msg)                -- append one line + mirror to the plain-text buffer
NS.DebugLog:Clear()                      -- clear the log + buffer
NS.DebugLog:UpdateScrollBar()            -- resync the §11 scrollbar thumb/range to the log offset
NS.DebugLog:UpdateStatus()               -- resync the bottom "N / 500 lines" counter
NS.DebugLog:ShowCopy()                   -- read-through EditBox with the whole log as plain text
NS.DebugLog:SetEnabled(on)               -- single seam for flipping State.debug: color-coded chat
                                         -- ack (ON green/OFF red, §5) + header + [Debug] bracket +
                                         -- [Init] session summary on enable
NS.DebugLog:RefreshHeader()              -- resync the ON/OFF toggle label + color
NS.DebugLog.FormatPlain(ts, tag, msg)    -- pure formatter: "<ts> | [<tag>] <msg>" (Copy buffer)
NS.DebugLog.FormatColored(ts, tag, msg)  -- pure color-coded formatter (console view)
NS.DebugLog.buffer                       -- capped plain-text mirror of the log (dense array)
NS.DebugLog:BufferSize() / :LastLine()   -- read seams over that buffer
NS.DebugLog:FindLine(substr)             -- newest buffered line containing substr, or nil
NS.DebugLog:IsEnabled()                  -- reads OUR flag back through the descriptor
NS.DebugLog.MakeCloseButton(parent, fn)  -- re-exported from LibKa0s-Core-1.0, so the console and
                                         -- the perf panel share ONE close-button factory
```

Both console + copy frames register in `UISpecialFrames` (Esc-closable). Detail in [midnight-quirks.md](./midnight-quirks.md).
The full descriptor contract and the surface `lib:New` returns are documented in the library
itself: see the
[LibKa0s README](https://github.com/tusharsaxena/LibKa0s/blob/master/README.md).

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

Cross-module signaling goes through the message bus (see [Bus](#bus-corebuslua) above) — the handlers publish `NS.MSG.*` rather than calling the display module directly. Events are AceEvent (`self:RegisterEvent`), **except** the two `UNIT_*` events (`UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_MAXHEALTH`), which use one private `CreateFrame` frame PER UNIT with `RegisterUnitEvent` for C-level unit filtering — a documented §9.1 deviation ([ARCHITECTURE.md → Standards Deviations](./ARCHITECTURE.md#standards-deviations)). A frame each (rather than packing two tokens onto one, `RegisterUnitEvent`'s cap) lets a unit's registration be added or dropped on its own as its bar is enabled or disabled, so a disabled unit is registered for nothing at all; `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` are gated on the same flag. Detail in [data-flow.md](./data-flow.md).

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
NS.FormatSchemaValue(row, value)   -> string   -- thin delegate to LibKa0s-Slash-1.0's
                                               -- lib.FormatValue; kept under this name because
                                               -- the schema layer is where callers look for it
-- There is no NS.ParseSchemaValue: the type-aware parser is the library's lib.ParseValue, and
-- settings/Slash.lua hands the library the rows to parse against.

-- Validation (called once from CreateOptionsPanel)
NS.ValidateSchema()                -> errors, resolved, missing
```

`ValidateSchema` now returns **three** values. Beyond checking row shape (path present, valid `page`, valid `type`), it verifies every non-profiles row's `path` resolves against `NS.defaults.profile` and warns on a miss — a typo'd path would otherwise silently read/write nothing. It only prints; it never refuses to register. Detail in [schema.md](./schema.md).

### Slash (`settings/Slash.lua`)

The AceConsole-registered `/at` surface. The dispatcher itself, the help renderer, the `cmd — desc` row formatter, the `key = value` formatter, the value renderer, the `/at list` builder and the type-aware value parser are `LibKa0s-Slash-1.0` (`libs/LibKa0s/Slash.lua`, vendored); this file supplies the descriptor. `/at list` / `get` / `set` walk `NS.Schema` through that descriptor's `allRows` / `findRow` / `get` / `set` seams, using **fully-qualified** dotted paths only — `/at set units.target.barWidth 250` works, the pre-1.9 unqualified `/at set barWidth 250` does not (a deliberate breaking change; see [scope.md](./scope.md)).

```lua
NS.COMMANDS         -- ordered { name, desc, fn } array of 17 verbs: help, config, list, get,
                    -- set, reset, resetall, resetposition, lock, unlock, toggle, debug, perf,
                    -- update, version, test, profile. Passed INTO the library rather than owned
                    -- by it — the about page renders the same table, so a library that owned it
                    -- would drag the options library into depending on the slash one.

NS.Slash:LandingRows() -- the formatted command rows settings/About.lua renders: the same
                       -- library formatter /at help uses, without the chat indent
NS.Slash:OnSlash(msg)  -- hands the line to the library dispatcher; unknown verb prints
                       -- "unknown command '<verb>'" then help
NS.Slash:Register()    -- NS.addon:RegisterChatCommand("at", ...) + ("absorbtracker", ...)
```

`/at list` groups Bar/Border/Font rows once per unit (`[bar / player]`, `[bar / target]`, `[bar / focus]`, etc. — `PER_UNIT_PAGES` in `settings/Slash.lua`); General has no per-unit rows. `/at reset <path>` resets ONE setting; there is no page-shaped form (a page is reset by its own Defaults button, `NS.Helpers.RestoreDefaults`). `/at resetposition` clears all three units' saved positions. No `SLASH_*` globals, no `SlashCmdList`. `/at options` is a back-compat alias for `/at config`. Profile subcommands dispatch through the file-local `PROFILE_VERBS` table in `settings/Slash.lua`, built once at load and keyed by the lowercased sub-verb; `runProfile` lowercases the verb, looks it up and calls `handler(db, subarg)`. A new sub-verb is one entry in that table plus one row in the `PROFILE_HELP` table above it (which fixes the order the help prints); the four name-taking verbs wrap their handler in `needsName(verb, fn)`, the shared `Usage: /at profile <verb> <name>` guard. The mirror note is handed to the library as a row annotator, so it is appended on `list` / `get` / `set` and never on a reset. With the vendored library absent a stub keeps the host verbs working and each schema verb names the missing library instead of going quiet. Detail in [profiles.md](./profiles.md).

### Options (`settings/OptionsSetup.lua` + `settings/UnitPanel.lua`)

The settings UI is `LibKa0s-Options-1.0` (`libs/LibKa0s/Options.lua` + `OptionsWidgets.lua` + `OptionsScroll.lua`, vendored) driven by a descriptor. `settings/OptionsSetup.lua` **assigns** `NS.Helpers = lib:New(descriptor)` — the library instance *itself*, not a table decorated from it. `settings/UnitPanel.lua` and `settings/About.lua` then decorate that same instance with the three members that did not generalize, which is what lets a page file call `H.RenderUnitPanel` and `H.RenderSchema` without knowing or caring which side of the boundary each lives on. There is no empty-table-published-first step and there are no toolkit slices; `settings/Panel.lua`, `Helpers.lua`, `ScrollPatch.lua` and `Widgets.lua` are gone.

```lua
-- The addon's half: the wrappers (settings/OptionsSetup.lua)
-- There is no NS.PARENT_TITLE: the brand string is a file-scope `PARENT_TITLE` local in
-- settings/OptionsSetup.lua, reaching the library as descriptor.parentTitle. The two files
-- that used to read it off the namespace (settings/Panel.lua, Helpers.lua) are in the library.
NS.RegisterOptionsPage(key, name, builder)
    -- key:     "general" / "bar" / "border" / "font" / "profiles"
    -- name:    display name shown in the Blizzard Settings tree (and breadcrumb header)
    -- builder: function(mainCategory) -> sub-category | nil   (called at enable time)

NS.CreateOptionsPanel()    -- called from OnEnable once db is ready. The library runs the
                           -- descriptor's validate, publishes AceGUI through onAceGUI, registers
                           -- the main canvas category, defers buildMain to first OnShow, then
                           -- drains the pending page builders.
NS.RefreshOptionsPanel()   -- routes to Helpers.RefreshAllPanels (re-runs every refresher)
NS.OpenOptionsPanel()      -- Settings.OpenToCategory(mainCategoryID) + expandMainCategory();
                           -- combat-lockdown gated INSIDE the library: in combat it REFUSES with
                           -- a gray notice (lib.STRINGS.COMBAT_REFUSED), printed through the
                           -- descriptor's print so it still carries [AT], and logged through its
                           -- debug under tag "Cfg" (options-ui-§2) — no defer-and-replay.

NS.AceGUI                  -- the AceGUI-3.0 handle. The library resolves it and hands it over via
                           -- the descriptor's onAceGUI callback during CreateOptionsPanel, so the
                           -- page builders and settings/About.lua read this upvalue rather than
                           -- re-LibStub-ing (§3.4).
```

The descriptor is the whole of what this addon tells the library. Everything else is the library's:

| Field | What the addon supplies |
|---|---|
| `parentTitle`, `mainPanelName` | the brand string, and `"AbsorbTrackerMainPanel"` so `/framestack` attributes the canvas |
| `print`, `debug` | `NS.Print` and `NS.Debug`, so library output carries this addon's tag and its debug lines land in this addon's console |
| `get`, `set` | `NS.GetSetting` / `NS.SetByPath` — `SetByPath` rather than a bare write, so a panel change takes exactly the path a `/at set` takes: the `[Set]` debug line, the row's `onChange`, and the refresh |
| `applyDefault`, `allRows` | `NS.ApplyDefault`, and `NS.Schema` itself |
| `rowsForPage(pageKey, filter)` | `NS.SchemaForPage`. `filter` is `ctx.unit`, passed through uninterpreted — that is what makes a per-unit page render one unit's rows while General, whose `ctx.unit` is nil, gets every unit's |
| `skipRestoreAll(row)` | `row.page == "profiles"` — those rows are AceDBOptions-supplied and resetting them is data loss, not a restore |
| `afterRestoreAll` | delegates to `Helpers.ResetAllPositions`, because `position` is written by dragging and no schema row owns it, so `ApplyDefault` never touches it |
| `scheduleTimer` | `NS.addon:ScheduleTimer` (AceTimer per §3.1, not a raw `C_Timer`); backs the color picker's 50 ms drag throttle. Optional at the library level — without it the library commits every drag frame |
| `getLSM`, `validate` | `NS.GetLSM`, `NS.ValidateSchema` |
| `onAceGUI`, `buildMain` | publishes `NS.AceGUI`; hands back `Helpers.BuildMainContent` under a nil-guard, because `settings/About.lua` loads *after* this file |
| `colorDecode`, `colorEncode` | the `{r=, g=, b=, a=}` named-key shape `core/Data.lua`'s color getters read. Written out rather than omitted even though it matches the library default, because the shape is a real contract with the rest of the addon |

```lua
-- What NS.Helpers answers, and where each member comes from:
NS.Helpers
    -- libs/LibKa0s/Options.lua — the shell
    Helpers.CreatePanel(name, title, opts)         -- canvas frame + header; records wantsDefaultsButton,
                                                   -- and stamps the Blizzard canvas contract OnCommit /
                                                   -- OnRefresh / OnDefault (Options minor 5). OnDefault
                                                   -- FORWARDS to panel.defaultsOnClick at click time, so
                                                   -- a handler parked after CreatePanel returns — which
                                                   -- is what every page here does — is still reached by
                                                   -- Blizzard's own footer defaults control
    Helpers.EnsureDefaultsButton(panel)            -- builds that Defaults button once, on the panel's
                                                   -- first OnShow, wiring the parked defaultsOnClick
                                                   -- (options-ui-§5: a widget created at load keeps
                                                   -- Blizzard's stock art — skins hook later)
    Helpers.EnsureScroll(ctx)                      -- lazy AceGUI ScrollFrame; calls PatchAlwaysShowScrollbar
    Helpers.ClearScroll(ctx)                       -- releases every AceGUI child + resets the
                                                   -- section-heading tracker and ctx.refreshers
    Helpers.LSMValues(mediaType)                   -- deferred LSM hash factory for schema rows
    Helpers.RestoreDefaults(pageKey, ctx)
    Helpers.RestoreAllDefaults()                   -- every schema-driven page; skipRestoreAll drops
                                                   -- profiles; afterRestoreAll clears the positions
    Helpers.RefreshAllPanels()                     -- run every panel ctx's refresher closures
    Helpers.RegisterOptionsPage / CreateOptionsPanel / OpenOptionsPanel  -- what the NS.* wrappers call
    Helpers.ROW_VSPACER                            -- layout constants exposed for host use
    Helpers.SECTION_HEADING_H                      -- (read by settings/About.lua)
    Helpers.BUTTON_PAIR_REL                        -- 0.492 — inline button-pair relative width
    Helpers.__panels() / __panelFor(pageKey)       -- test seams: the registered panel ctx tables

    -- libs/LibKa0s/OptionsWidgets.lua — the makers and the flow engine
    Helpers.Section(ctx, label)                    -- AceGUI Heading row
    Helpers.InlineButtonPair(ctx, leftSpec, rightSpec)
    Helpers.AttachTooltip(widget, label, tooltip)
    Helpers.AddSpacer(scroll, height)              -- invisible full-width SimpleGroup
    Helpers.RenderField(ctx, row, parent, w)       -- dispatches by row.type
    Helpers.SessionCheckbox(ctx, parent, w, spec)  -- non-schema checkbox (caller get/set)
    Helpers.RenderRows(ctx, rows, afterGroup?, pairWith?)      -- two-column layout over an
                                                               -- EXPLICIT row list; skips
                                                               -- skipRender rows
    Helpers.RenderSchema(ctx, pageKey, afterGroup?, pairWith?) -- thin wrapper:
                                                               -- RenderRows(ctx,
                                                               -- rowsForPage(pageKey,
                                                               -- ctx.unit), ...) — used by
                                                               -- General, which never sets
                                                               -- ctx.unit, so its three
                                                               -- units.<unit>.enabled rows all
                                                               -- render (no unit filter).
                                                               -- pairWith attaches the Debug
                                                               -- console beside the lone
                                                               -- Enable Focus Bar row

    -- libs/LibKa0s/OptionsScroll.lua
    Helpers.PatchAlwaysShowScrollbar(scroll)       -- always-visible scrollbar override

    -- settings/UnitPanel.lua — ours, because neither piece generalizes
    Helpers.RenderUnitPanel(ctx, pageKey)          -- Bar/Border/Font: Unit dropdown + mirror
                                                   -- header (checkbox + copy button), full
                                                   -- rebuild via ClearScroll on every call.
                                                   -- Reads NS.Units and the mirror partition,
                                                   -- which no other Ka0s addon has.
    Helpers.ResetAllPositions()                    -- THE single reset-position implementation:
                                                   -- clears every unit's saved position, then
                                                   -- publishes POSITION. /at resetposition, the
                                                   -- General page button and afterRestoreAll all
                                                   -- call it. Do not re-inline the loop.

    -- settings/About.lua — ours
    Helpers.BuildMainContent(ctx)                  -- top-level "Ka0s Absorb Tracker" page builder;
                                                   -- renders logo, Notes, a "Slash Commands"
                                                   -- heading, then one Label per
                                                   -- NS.Slash:LandingRows() entry. Invoked through
                                                   -- the descriptor's buildMain hook.
```

The color-picker drag throttle is library code (`COLOR_THROTTLE = 0.05` in `OptionsWidgets.lua`); the timer behind it arrives through the descriptor's `scheduleTimer` — `NS.addon:ScheduleTimer` (AceTimer one-shot), not `C_Timer.NewTimer`. Detail in [settings-panel.md](./settings-panel.md).

### Options pages (`settings/General|Bar|Border|Font|Profiles.lua`)

Each runs at file-load time and calls `NS.RegisterOptionsPage(key, name, build)`. General calls `NS.RegisterSchemaRows({...})` once for its three unit-agnostic globals (`showOnlyInCombat`, `locked`, `throttleWindow` — the fourth was `hidden`, dropped by schema v4). Its per-unit `units.<unit>.enabled` rows are registered separately and are not unit-agnostic; Bar/Border/Font instead define `addUnitRows(unit)` and call it once per `NS.Units.LIST` entry, so each registers its appearance keys three times (path prefixed `units.<unit>.`, tagged `unit = unit`) — plus a `mirror` row (`skipRender = true`) for target/focus only. Profiles registers no rows; its UI is AceDBOptions-supplied. At enable time, the `build` closure calls `Helpers.RenderSchema(ctx, pageKey)` (General — no dropdown) or `Helpers.RenderUnitPanel(ctx, pageKey)` (Bar/Border/Font — Unit dropdown + mirror header), with **no** `rendered` one-shot guard on the latter (`RenderUnitPanel` does a full rebuild every call, by design — unit switches and mirror toggles need it). The LSM-backed rows in Bar/Border/Font set `dialogControl = "LSM30_Statusbar" | "LSM30_Border" | "LSM30_Font"` and `values = NS.Helpers.LSMValues(mediaType)`. `Profiles.build` returns nil (opting the page out) when AceDBOptions / AceConfigDialog / AceConfig / AceGUI aren't all present.

## Forward references

A small number of call sites reach across load order — the runtime modules (Core / Modules) load before the Settings group:

- `core/AbsorbTracker.lua` (`OnEnable`) calls `NS.CreateOptionsPanel()` (defined in `settings/OptionsSetup.lua`, loaded later).
- `core/AbsorbTracker.lua` (`OnEnable`) calls `NS.ApplyLSMBorderPatch()` (defined in `core/LSMPatch.lua`).
- `NS.OnProfileChanged` calls `NS.RefreshOptionsPanel()` (defined in `settings/OptionsSetup.lua`).
- `settings/Slash.lua` handlers call `NS.RefreshOptionsPanel` directly, and publish bus messages for display work (`update` → `REPAINT`, `resetposition` → `POSITION`). `toggle` publishes nothing itself — it writes `units.<unit>.enabled` via `NS.SetByPath`, and that row's `onChange` (`settings/General.lua`) does the republishing: `UNITS` → `APPEARANCE` → `REPAINT`-when-on. There is no `hidden` key; schema v4 dropped it.

These are guarded with runtime nil checks:

```lua
if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
```

In practice the calls always succeed because all files are loaded synchronously before `OnEnable` fires — but the nil-check keeps the load-order coupling soft, so a future refactor that moves a file won't error.

## Load order

`AbsorbTracker.toc` is the source of truth. Order is dependency order, not alphabetical. The load groups are **Libraries → Locales → Core → Defaults → Modules → Settings**:

1. `libs/` — LibStub, CallbackHandler-1.0, then the Ace3 stack (AceAddon / AceEvent / AceTimer / AceConsole / AceDB / AceGUI / AceConfig / AceDBOptions), `LibKa0s` (**five majors across eight files**: `LibKa0s-Core-1.0` — the shared secret guard + chat printer + window chrome — then `LibKa0s-DebugLog-1.0`, the shared on-screen debug console, `LibKa0s-Slash-1.0`, the shared slash dispatcher + schema CLI, `LibKa0s-Options-1.0`, the shared settings-panel toolkit across three files, and `LibKa0s-Perf-1.0`, the shared perf-instrumentation harness across two, issue #17; `Core.lua` loads first, since the other four each declare `NEEDS_CORE` and refuse to register below it — `LibKa0s.xml` fixes the order `Core.lua` → `DebugLog.lua` → `Slash.lua` → `Options.lua` → `OptionsWidgets.lua` → `OptionsScroll.lua` → `Perf.lua` → `PerfPanel.lua`), LibSharedMedia-3.0, and the vendored upstream `AceGUI-3.0-SharedMediaWidgets` (LSM30_* swatch widgets) — all inside the `#@no-lib-strip@` block. Vendored **folder-per-lib** at `libs/` root (not `libs/Ace3/…`).
2. **Locales** — `locales/enUS.lua` (`NS.L` metatable seam; loads directly after Libraries per `toc-file-§5` — no dependency on `core/*`).
3. **Core** — `core/Compat.lua` (loads first: the deprecated-API shim), `Constants.lua`, `Namespace.lua`, `State.lua`, `Bus.lua` (the closed message bus — `NS.bus` / `NS.NewBusTarget` / `NS.MSG`), `CoreSetup.lua` (wires `NS.Print` / `NS.SafeToString` / `NS.IsConcatSafe` to `LibKa0s-Core-1.0`, in the slot the old `Util.lua` held — `Namespace.lua` defines `NS.PREFIX` above it and everything below it prints), `PerfSetup.lua` (wires `NS.Perf` to `LibKa0s-Perf-1.0` — must load before any module takes `NS.Perf` as an upvalue), `Data.lua`, `Units.lua` (unit identity + mirror resolution — loads after `Data.lua`, before `Database.lua` since migration needs `NS.Units.LIST`/`APPEARANCE_KEYS`), `Database.lua`, `LSMPatch.lua`, `DebugLogSetup.lua` (wires `NS.DebugLog` / `NS.Debug` to `LibKa0s-DebugLog-1.0`, in the slot the old `DebugLog.lua` held — it needs `Constants` (FONT_MONO), `State` (the flag) and `CoreSetup` above it, and everything below it calls `NS.Debug`), `AbsorbTracker.lua` (AceAddon promotion + lifecycle).
4. **Defaults** — `defaults/Profile.lua` (AceDB defaults; runs at file-load).
5. **Modules** — `modules/Bar.lua` (bar frame creation at file-load), `Display.lua` (render functions + `NS.Display.__ev` bus consumer), `Timer.lua` (coalescing repaint scheduler + `NS.Timer.__ev` bus consumer).
6. **Settings** (last — depend on everything else being initialized) — `settings/Schema.lua` (registry), `Slash.lua` (`/at` dispatcher), `OptionsSetup.lua` (assigns `NS.Helpers` = the `LibKa0s-Options-1.0` instance, and sets `NS.PARENT_TITLE` before the lib check so it exists on both paths), `UnitPanel.lua` and `About.lua` (each decorates that instance), then the page builders `General.lua` → `Bar.lua` → `Border.lua` → `Font.lua` → `Profiles.lua` (each calls `RegisterSchemaRows` + `RegisterOptionsPage` at file-load; LSM-backed rows call `NS.Helpers.LSMValues(mediaType)`). The order rule that carries weight here is that **`OptionsSetup.lua` must precede every `settings/<page>.lua`**, because `Bar`/`Border`/`Font` call `NS.Helpers.LSMValues(...)` inside schema-row literals at file load and a nil there aborts the file — taking that page's `RegisterSchemaRows` with it. `UnitPanel.lua` must follow `OptionsSetup.lua` for the same class of reason: it takes `local Helpers = NS.Helpers` at load.

If you add a new runtime file, put it in the right load group in `AbsorbTracker.toc`.

## Module publishing pattern (idiom)

Modules that own a sub-surface publish it with the `NS.X = NS.X or {}` guard (`NS.Constants`, `NS.Compat`, `NS.Util`, `NS.State`, `NS.Slash`, `NS.Schema`), then alias it to a file-local upvalue (`local C = NS.Constants`). The **three library seams are the exception**: `core/PerfSetup.lua`, `core/DebugLogSetup.lua` and `settings/OptionsSetup.lua` **assign** `NS.Perf`, `NS.DebugLog` and `NS.Helpers` outright, because the value is a library instance built by `lib:New(descriptor)` (or a degradation stub) — there is nothing for an earlier file to have half-populated, and an `or {}` guard would quietly keep a half-built table alive instead. `NS.Helpers` is the one of the three that is then *decorated* by later files (`settings/UnitPanel.lua`, `settings/About.lua`); they add members to the library's own instance rather than to a copy. Modules that mostly attach top-level functions (`Data`, `Display`, `Timer`) write straight to `NS` — `Display` and `Timer` additionally publish a small `NS.Display` / `NS.Timer` table to hold their `__ev` bus target, and `core/Bus.lua` publishes `NS.bus` / `NS.NewBusTarget` / `NS.MSG`. The closest thing to a load-order guard is the import-as-locals pattern at the top of each file plus the `if NS.X then ... end` nil check around forward references.

## Test harness

There **is** a headless test harness at `tests/` — any doc claiming "there are no automated tests" is stale. `tests/run.lua` derives the runtime file list from the TOC and loads it — after the vendored `libs/LibKa0s/*.lua` — through `tests/_kit/loader.lua`, against `tests/_kit/mock_base.lua` plus this addon's `tests/wow_mock.lua` overlay. It then runs `test_loadorder.lua`, `test_schema.lua`, `test_database.lua`, `test_units.lua`, `test_compat.lua`, `test_coresetup.lua`, `test_debuglog.lua`, `test_slash.lua`, `test_timer.lua`, `test_perf.lua`, `test_visibility.lua`, `test_bus.lua`, `test_data.lua`, `test_display.lua`, `test_helpers.lua`, `test_slashcmds.lua`, `test_widgets.lua`, `test_optionssetup.lua`, `test_docs.lua`, and `test_ltrap.lua` (authoritative case count in the generated [test-cases.md](./test-cases.md)). `test_helpers` and `test_widgets` kept their names through the Options extraction: what they exercise is now `LibKa0s-Options-1.0` driven through this addon's descriptor, plus `settings/UnitPanel.lua`. The green gate is `lua tests/run.lua` + `luacheck .` (0/0) + `luac -p <file>`. See [smoke-tests.md](./smoke-tests.md) for the manual in-game QA recipe that complements it.
