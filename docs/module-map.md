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
                               -- mirrored would silently edit the player's bar). NO production
                               -- caller: `/at set` goes NS.SetByPath -> NS.SetSetting ->
                               -- NS.SetPath. Published as the write half of the Get seam.
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

-- Bound bare, which is why all thirteen NS.Debug call sites across five files are unchanged.
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

Cross-module signaling goes through the message bus (see [Bus](#bus-corebuslua) above) — the handlers publish `NS.MSG.*` rather than calling the display module directly. Events are AceEvent (`self:RegisterEvent`), **except** the two `UNIT_*` events (`UNIT_ABSORB_AMOUNT_CHANGED`, `UNIT_MAXHEALTH`), which use one private `CreateFrame` frame PER UNIT with `RegisterUnitEvent` for C-level unit filtering — a documented events-frames-taint-§1 deviation ([ARCHITECTURE.md → Documented deviations](./ARCHITECTURE.md#documented-deviations)). A frame each (rather than packing two tokens onto one, `RegisterUnitEvent`'s cap) lets a unit's registration be added or dropped on its own as its bar is enabled or disabled, so a disabled unit is registered for nothing at all; `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` are gated on the same flag. Detail in [data-flow.md](./data-flow.md).

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
                           -- re-LibStub-ing (library-stack-§4).
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
| `scheduleTimer` | `NS.addon:ScheduleTimer` (AceTimer per library-stack-§1, not a raw `C_Timer`); backs the color picker's 50 ms drag throttle. Optional at the library level — without it the library commits every drag frame |
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

## File index

Every non-vendored file, by directory. Folded in from the retired `module-map.md` (standard v2.23.0), which duplicated this map at a different granularity.

Where each responsibility lives in the source tree. Match this map to the actual files before editing — `AbsorbTracker.toc` is the source of truth for load order.

The tree is modular (Ka0s standard): `core/` (bootstrap + data + infrastructure), `defaults/` (AceDB defaults), `locales/` (strings), `modules/` (the bar runtime), `settings/` (schema + slash CLI + the panel wiring and the two bespoke renderers), `tests/` (headless harness). Every file opens with `local addonName, NS = ...`; `NS` is the single shared private table, promoted to an AceAddon object in `core/AbsorbTracker.lua`.

### locales/

Loaded first among addon source (after libs, before `core/`) — the `NS.L` seam has no dependency on `core/*`, so it loads earliest per `toc-file-§5` (Locales directly after Libraries).

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 1 | `locales/enUS.lua` | 12 | Canonical locale. Sets `NS.L = setmetatable({}, { __index = function(_, k) return k end })` so a missing key returns itself and never errors. English-only in v1.9.0 — the seam is in place, but no user-facing string is wrapped yet. |

### core/ — bootstrap, data, infrastructure

Loaded after libs and the locale seam. `Compat` leads so its shim exists before anything calls it; `AbsorbTracker` (the AceAddon lifecycle) loads last in the group so `InitDB` / the enable sequence can reference everything else.

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 2 | `core/Compat.lua` | 20 | The ONLY file that calls deprecated / flavor-varying APIs. `Compat.GetAddOnMetadata(name, field)` wraps `C_AddOns.GetAddOnMetadata` with a `_G.GetAddOnMetadata` pre-11.0 fallback, degrading to `nil` when neither exists. `settings/About.lua` and `settings/Slash.lua` route through it. |
| 3 | `core/Constants.lua` | 16 | `NS.Constants`: the `FALLBACK_TEXTURE` / `FALLBACK_BORDER` / `FALLBACK_FONT` Blizzard paths returned when LSM is absent or a key doesn't resolve, `FONT_MONO` (the vendored JetBrains Mono path used by the debug console), and `LOGO_PATH` (the About-page TGA). |
| 4 | `core/Namespace.lua` | 14 | Shared-namespace bootstrap. `NS.name` / `NS.version`, the cyan `NS.PREFIX` (`|cFF00FFFF[AT]|r`), and the hot-path `NS.floor` / `NS.max` caches used by the bar paint path. Runs early so metadata + caches exist regardless of load order. |
| 5 | `core/State.lua` | 5 | `NS.State` — session-only runtime state, never persisted. Holds `NS.State.debug` (the debug flag, defaults off, resets on every `/reload` and login). |
| 6 | `core/Bus.lua` | 56 | The closed cross-module message bus (architecture-§4). `AceEvent:Embed`s `NS.bus` (the shared publish target), exposes `NS.NewBusTarget()` (a fresh AceEvent-embedded table per receiver, so no two subscriptions ever share one target — anti-pattern #32), and publishes the `NS.MSG` catalog: `REPAINT` / `APPEARANCE` / `VISIBILITY` / `POSITION` / `UNITS` (`Ka0s_AbsorbTracker_RepaintRequested` / `…AppearanceChanged` / `…VisibilityChanged` / `…PositionChanged` / `…UnitsChanged`). Producers (`core/AbsorbTracker.lua`, `settings/{Slash,General,Schema,UnitPanel}.lua`) `SendMessage` these; `modules/Timer.lua` (REPAINT) and `modules/Display.lua` (APPEARANCE/VISIBILITY/POSITION) subscribe on their own targets. All messages are payload-free — the consumer re-reads live state. See [ARCHITECTURE.md](./ARCHITECTURE.md) → Message Bus. |
| 7 | `core/CoreSetup.lua` | 78 | Wires the addon into `LibKa0s-Core-1.0` (`libs/LibKa0s/Core.lua`, vendored). The secret-value guard, the stringifier and the chat-prefix pipeline are library code now; this file supplies only the part that is ours — which tag the lines carry, and what happens when the library is not there. Publishes `NS.Print(...)` (the cyan-`[AT]` pipeline, built via `lib:New{ prefix = function() return NS.PREFIX end }` — the prefix goes in as a *function*, so a later change to `NS.PREFIX` isn't frozen into a printer that is built once at load), `NS.Util.print` (**the identical function object**, not a second wrapper — `core/AbsorbTracker.lua` reclaims `NS.Print` from it after AceConsole stamps over it), and `NS.IsConcatSafe` / `NS.SafeToString` taken straight off the library. Files that emit chat do `local print = NS.Print`. With the library absent it degrades to the pre-library implementations rather than to a no-op — four settings files (`Schema`, `Slash`, `OptionsSetup`, `General`) do `local print = NS.Print` at load, so a nil printer takes the settings UI down with it and a silent one makes `/at` answer nothing — and says the "LibKa0s is missing" line ONCE, on the first line the addon prints, rather than stapling it to every one of them. Sits in the old `core/Util.lua` TOC slot for two reasons that both matter: `core/Namespace.lua` defines `NS.PREFIX` just above it, and everything below it — `core/PerfSetup.lua` first — either calls `NS.Print` or takes it as a load-time upvalue. The secret-safe debug sink is `NS.Debug(tag, fmt, ...)`, published by `core/DebugLogSetup.lua`. |
| 7a | `core/PerfSetup.lua` | 130 | Wires the addon into `LibKa0s-Perf-1.0` (`libs/LibKa0s/Perf.lua`, vendored — issue #17). The probe, the record schema, and the clickable step panel are all library code now; this file supplies only the **descriptor** — `name`/`sv`/`version`/`slash`, the ordered `buckets` declaration (nesting via `within`, e.g. `paintBar` within `repaintPass`), and the `suspend`/`resume` pair that makes the addon inert without a `/reload` (enforced at the source via a `NS.Perf.suspended` check as step 0 of `NS.ShouldShowBar`, not by imperatively hiding frames), plus `log`/`print`/`showLog`/`decorate` hooks into the debug console `core/DebugLogSetup.lua` publishes as `NS.DebugLog` — `decorate` borrows that console's own `MakeCloseButton` factory (looked up lazily at frame-build time, and nil-guarded because `LibKa0s-Core-1.0`'s factory answers nil where `CreateFrame` is unavailable) so the perf panel and the console cannot drift apart. Degrades to a stub (`on`/`suspended`/`Note`, plus an `OnCommand` that returns one line saying the library is missing) if `LibStub("LibKa0s-Perf-1.0", true)` fails, so a missing vendored lib never breaks the addon's own function — `/at perf` is registered unconditionally, so the stub has to answer it rather than error. Must load before any module takes `NS.Perf` as an upvalue — sits in the same TOC slot the old `core/Perf.lua` held, immediately after `core/CoreSetup.lua`. Descriptor contract and full public surface: [LibKa0s README](https://github.com/tusharsaxena/LibKa0s/blob/master/README.md). |
| 8 | `core/Data.lua` | 171 | Bar data + media access layer. `NS.db` ref, `GetSetting(path)` / `SetSetting(path, value)` over `db.profile` (dotted-path aware via `NS.ResolvePath`/`NS.SetPath`, falling back to `flatDefaults`), the cached LSM fetchers (`GetBarTexture(unit)` / `GetBgTexture(unit)` / `GetBorder(unit)` / `GetFont(unit)` with `FALLBACK_*`, each resolved through `NS.Units.Get`), `GetLSM` / `ClearLSMCache`, and the class-color-aware color getters (`GetBarColor(unit)` / `GetBgColor(unit)` / `GetBorderColor(unit)`) that re-read that unit's `useClassColor*` at call time — the class color itself is always the player's. `GetPlayerClassColor` / `GetBgClassColor` are the upvalue resolvers. |
| 9 | `core/Units.lua` | 113 | `NS.Units` — the only file that reads `db.profile.units` for appearance. `LIST`/`LABEL` (player/target/focus identity), `APPEARANCE_KEYS` (the 15 per-unit keys), `Config(unit)`, `IsEnabled(unit)`, `IsMirrored(unit)` (always false for player), `SourceUnit(unit)`, `Get(unit, key)` (the mirror-resolved read path), `Set(unit, key, value)` (writes the unit's own config, never mirror-resolved — published without a production caller as the write half of the `Get` seam; `/at set` does **not** come through here), `DeepCopy(v)` (the addon's ONE recursive table copy — `core/Database.lua` uses it too), `Position(unit)` / `SetPosition(unit, pos)` (never mirrored), and `CopyFromPlayer(unit)` (one-shot deep-copy of the 15 appearance keys, then clears `mirror`; does not copy `position` or `enabled`). |
| 10 | `core/Database.lua` | 215 | `NS:InitDB()` — creates the AceDB `"AbsorbTrackerDB"` from `NS.defaults`, registers `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` → `NS.OnProfileChanged` (guarded for the headless AceDB mock), and installs the no-AceDB fallback shim. `NS:RunMigrations()` — idempotent, reads/writes `db.global.schemaVersion` (currently `4`); logs `[Migrate] lifted N profile(s) to v3` only when a flat key was actually moved, so a fresh install is silent. Runs in this order: the **v3 lift** (`migrateAllProfiles` → the public `NS.MigrateProfileToV3(profile)`, gated PER PROFILE on `profile.schemaVersion`, not on the account-wide stamp and not on `profile.units == nil` — real AceDB's `copyDefaults` already backfills `units` from `NS.defaults` the moment `db.profile` is first read, so a nil-guard would make the block permanently dead) moves pre-v3 flat appearance keys onto `profile.units.player` for the active profile **and every profile in the guarded `db.sv.profiles` store**; the unconditional **backfill** (`backfillFlatKeys` + `backfillUnitKeys`, two file-local helpers) then fills any missing key, flat or per-unit, from `NS.defaults.profile`; then the account-wide ladder walks the file-local `SCHEMA_STEPS` array in order — `{ to = 2 }` drops the dead `profile.updateInterval` key, `{ to = 3 }` is stamp-only (the per-unit lift is gated per profile and already ran), `{ to = 4 }` drops the dead `hidden` master toggle from every profile in the store (`dropKeyEverywhere`, same all-profiles reasoning as the v3 lift). Each step's `apply` runs before its own `vX → vY` line is logged, and the loop stamps `g.schemaVersion` after it. **A new schema version is one new row in `SCHEMA_STEPS`, not another `if` arm.** See [data-flow.md](./data-flow.md). |
| 11 | `core/LSMPatch.lua` | 50 | Third-party-lib fixup. `NS.ApplyLSMBorderPatch()` (called once on enable) wraps the currently-registered `LSM30_Border` constructor at `currentVer + 1` via `AceGUI:RegisterWidgetType`, hides upstream's 42×42 `displayButton` preview tile, and re-anchors `frame.label` and `frame.DLeft` to the frame's left edge so the closed dropdown sits flush with neighboring sliders/checkboxes. No-ops cleanly when AceGUI / the widget isn't loaded. |
| 12 | `core/DebugLogSetup.lua` | 110 | Wires the addon into `LibKa0s-DebugLog-1.0` (`libs/LibKa0s/DebugLog.lua`, vendored — issue #17). The console window and its Copy window, the two formatters, the 500-line buffer and the enable seam are all library code now; this file supplies only the **descriptor** — `name` (which seeds `AbsorbTrackerDebugWindow` / `…DebugCopyWindow` / `…DebugCopyScroll`), `title` (`"Absorb Tracker"`; the library appends `" — Debug"`), `font` (`NS.Constants.FONT_MONO`), `slash` (`/at`, which composes the console checkbox's tooltip), the `print` / `safeToString` hooks (both written as `function(v) return NS.X(v) end` so they resolve at CALL time — `NS.Print` is reclaimed from AceConsole's embed in `core/AbsorbTracker.lua`, which loads *after* this file, and a captured reference would freeze to the wrong function), `onVisibilityChanged` → `NS.Helpers.RefreshAllPanels` (so a console opened by `/at debug` moves the General page's checkbox on an already-open panel), and `initSummary`, the `[Init]` line only this addon can write (name + version, `db.global.schemaVersion`, active profile — the library owns *when* it lands, on enable, because the flag is off at login). **The flag stays ours:** `isEnabled`/`setEnabled` read and write `NS.State.debug` and the library keeps no copy, because `NS.ShouldShowBar`'s ladder and the settings panel both read that one variable and a second would be a second truth. Ends by binding the gated sink bare — `NS.Debug = NS.DebugLog.Debug` — which is why all fifteen `NS.Debug(tag, fmt, ...)` call sites across five files (`core/{Database,AbsorbTracker}.lua`, `modules/Display.lua`, `settings/{Schema,OptionsSetup}.lua`) are byte-identical to what they were. Degrades to a stub if `LibStub("LibKa0s-DebugLog-1.0", true)` fails: the stub covers every member the addon calls (`/at debug`, the General page's checkbox, `core/PerfSetup.lua`'s log sink) and **still flips the flag**, because `NS.State.debug` is ours and `/at debug on` must not silently do nothing; what is lost is the window, and it says so once. Sits in the old `core/DebugLog.lua` TOC slot, which puts it after `Constants` (FONT_MONO), `State` (the flag) and `CoreSetup` (`NS.Print`/`NS.SafeToString`), and before everything that calls `NS.Debug`. |
| 13 | `core/AbsorbTracker.lua` | 276 | AceAddon lifecycle. Promotes `NS` via `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")` and stashes the object as `NS.addon`. `OnInitialize` (ADDON_LOADED) registers the LSM monospace font, calls `NS:InitDB()`, and `NS.Slash:Register()`. `OnEnable` (PLAYER_LOGIN timing) reproduces the old bootstrap in order (ClearLSMCache → GetLSM → ApplyLSMBorderPatch → then **publishes** `POSITION` → `APPEARANCE` → `REPAINT` on the bus), calls `self:SyncUnitEventFrames()` (one private `RegisterUnitEvent` frame PER unit, registered for `UNIT_ABSORB_AMOUNT_CHANGED`/`UNIT_MAXHEALTH` only while that unit's bar is `enabled` and `UnregisterAllEvents`'d otherwise, plus `PLAYER_TARGET_CHANGED`/`PLAYER_FOCUS_CHANGED` gated the same way — so a disabled bar costs no event dispatch at all; a documented events-frames-taint-§1 deviation. Frames are created once and reused; re-run on every `UNITS` message, which this file also owns the sole subscription to via `NS.Events.__ev`), then `RegisterEvent` for `PLAYER_ENTERING_WORLD`/`PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED` via AceEvent, then `NS.CreateOptionsPanel()` (no `[Init]` boot line here — the debug flag is off at login, so per debug-logging §5 the session summary is emitted from `DebugLog:SetEnabled` on enable). The event handlers don't call the display module directly — they publish bus messages (see [ARCHITECTURE.md](./ARCHITECTURE.md) → Message Bus). Debug coverage (§8) + coalescing (§9): `OnEnterWorld` logs `[World]` then publishes `VISIBILITY` + `REPAINT`; `OnAbsorbChanged` (player/target/focus) no longer logs per event — it bumps a debug-gated `dbgAbsorbEvents` counter and logs a non-secret `[Absorb]` shield-up/shield-gone transition, **player only**, only when `NS.IsConcatSafe` says the value isn't a combat secret, then publishes `REPAINT`; `OnMaxHealthChanged` (player/target/focus; absorb is shown as a fraction of max health) publishes `REPAINT` with no debug line; `OnUnitSwap` (`PLAYER_TARGET_CHANGED`/`PLAYER_FOCUS_CHANGED`) publishes `VISIBILITY` + `REPAINT`; `OnEnterCombat` publishes `VISIBILITY` + `REPAINT`, resets the per-combat counters, and logs `[Combat] entered`; `OnLeaveCombat` (sole handler of `PLAYER_REGEN_ENABLED`) publishes `VISIBILITY` + `REPAINT`, then flushes one `[Combat] left: N events, M repaints` rollup (player events only, deliberately, so the printed count matches what it reports), appending `final=<value>` only when the post-combat read is concat-safe (the value is a secret while `InCombatLockdown()` still lags) — no deferred `/at config` to replay (options-ui-§2); `NS.OnProfileChanged` logs `[Profile]`, publishes `POSITION` + `APPEARANCE` + `REPAINT`, and refreshes an open panel. `NS.NoteRepaint()` is defined here (module-local counters `dbgAbsorbEvents`/`dbgRepaints`/`dbgLastAbsorb`) and called directly by `modules/Display.lua`'s `UpdateAbsorbBar` (an intra-implementation debug hook, not a bus message). |

### defaults/

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 14 | `defaults/Profile.lua` | 95 | AceDB-shaped defaults. Three flat globals (`locked`, `showOnlyInCombat`, `throttleWindow` — no `hidden`; v4 dropped it and the per-unit `enabled` flags are the visibility switch) plus `NS.defaults.profile.units.{player,target,focus}` — each unit's own appearance table, built by an `appearance()` factory so no table is shared across units (target/focus additionally get `enabled = false, mirror = true`; player gets `enabled = true, mirror = nil`, since the player is the mirror source). `NS.defaults.global.schemaVersion = 4` (the account-wide, DB-wide migration stamp) and `NS.defaults.profile.schemaVersion = 1` (the per-profile lift stamp — default `1`, not `3`, so `copyDefaults` cannot mark a pre-v3 profile as already migrated; a documented savedvariables-§1 deviation). `NS.flatDefaults` — alias to `defaults.profile` (the no-AceDB `GetSetting` fallback). `NS.unitDefaults` — alias to `defaults.profile.units.player`, the canonical per-row default source `settings/{Bar,Border,Font}.lua` read from. |

### modules/ — the bar runtime

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 15 | `modules/Bar.lua` | 96 | Bar-frame creation at file-load time, once per unit (from `NS.unitDefaults`, before the DB is ready). `NS.CreateBar(unit, globalName)` builds one frame, each with its own `backdropInfo` table (border size differs per unit; `SetBackdrop` keys off table identity). `NS.bars = { player = ..., target = ..., focus = ... }` (named `AbsorbTrackerFrame` / `AbsorbTrackerTargetFrame` / `AbsorbTrackerFocusFrame`), plus `NS.bar`/`statusBar`/`valueText`/`backdropInfo` as player aliases kept for the **test harness alone** — no production call site remains, `modules/Display.lua` and `settings/Slash.lua` both index `NS.bars[unit]`. Each frame also owns `bar.unitLabel`, a FontString anchored above the bar naming its unit — created hidden, shown only while unlocked (`modules/Display.lua` owns the toggle). The drag handler writes the new position via `NS.Units.SetPosition(self.unit, ...)` — never mirrored, so it always targets the dragged frame's own unit. |
| 16 | `modules/Display.lua` | 320 | Every function takes a `unit` (default `"player"`). `NS.ForEachUnit(fn)` runs `fn(unit)` for each of `NS.Units.LIST`; `NS.DefaultPosition(unit)` stacks target/focus above the player bar's pre-drag default. `RestoreBarPosition(unit)` (re-applies the saved `position` or the stacked default), `UpdateBarAppearance(unit)` (re-applies *every* visual setting via `NS.Units.Get(unit, key)` — mirror-resolved, so a mirrored bar reads the player's live settings; `SetBackdrop(nil)` first to force refresh; shows or hides `bar.unitLabel` with the global `locked` flag at a fixed 10pt in the unit's own font face; ends with a direct `NS.ApplyVisibility(unit)` — intra-concern), `NS.ShouldShowBar(unit)` / `NS.ApplyVisibility(unit)` (the four-step visibility ladder: per-unit `enabled` → `showOnlyInCombat` vs. `UnitAffectingCombat("player")` → target/focus `UnitExists(unit)` → shown; logs a `[Bar]` shown/hidden transition line only when the applied visibility actually changes), `UpdateAbsorbBar(unit)` (reads `UnitGetTotalAbsorbs(unit)` / `UnitHealthMax(unit)`, formats with `AbbreviateNumbers` — never through `tonumber`; early-returns when `NS.ShouldShowBar(unit)` is false; early-outs while `NS.testHoldUntil` is in the future so a `/at test` paint survives the next tick; returns whether it painted, which `modules/Timer.lua` turns into ONE `NS.NoteRepaint()` per coalesced pass rather than one per bar — so the `core/AbsorbTracker.lua` `[Combat]` rollup's M stays comparable to its player-only N). **Bus consumer:** subscribes on its own `NS.Display.__ev` target (from `NS.NewBusTarget()`) to `APPEARANCE`/`VISIBILITY`/`POSITION`, each handler fanning out over `NS.ForEachUnit` so the messages stay payload-free. |
| 17 | `modules/Timer.lua` | 70 | Coalescing repaint scheduler via AceTimer. `NS.RequestRepaint()` is a trailing-edge one-shot throttle: a repaint already pending coalesces (no-op); otherwise `NS.addon:ScheduleTimer(doRepaint, throttleWindow)` schedules a repaint that fans out over `NS.ForEachUnit` into `NS.UpdateAbsorbBar(unit)` (a direct intra-concern call) — **one pass paints all three bars**; calling it bare would paint only the player, since `UpdateAbsorbBar` defaults its unit. Calls `NS.NoteRepaint()` once per pass if any bar reported a paint (not once per bar, and not at all for a pass that painted nothing). Self-clearing (`pending = nil`) inside the callback. The `doRepaint` callback is hoisted to module scope (reused, not re-allocated per arm). No polling fallback; idle = zero repaints. **Bus consumer:** owns the SOLE subscription to `REPAINT` on its own `NS.Timer.__ev` target → funnels it through `NS.RequestRepaint`. |

### settings/ — schema, slash, panel wiring

The panel toolkit is no longer in `settings/`: it is `LibKa0s-Options-1.0` (`libs/LibKa0s/Options.lua` + `OptionsWidgets.lua` + `OptionsScroll.lua`), and `settings/OptionsSetup.lua` **assigns** `NS.Helpers` to the instance `lib:New(descriptor)` returns rather than publishing an empty table for slices to fill. `settings/UnitPanel.lua` and `settings/About.lua` then decorate that instance with the three members that stayed addon-side. TOC order (`AbsorbTracker.toc:59–68`): `Schema.lua` → `Slash.lua` → `OptionsSetup.lua` → `UnitPanel.lua` → `About.lua` → the five page files. The one order rule that carries weight is that **`OptionsSetup.lua` must precede every `settings/<page>.lua`**, because `Bar`/`Border`/`Font` call `NS.Helpers.LSMValues(...)` inside schema-row literals at file load; `UnitPanel.lua` must follow it for the same class of reason (it takes `local Helpers = NS.Helpers` at load).

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 18 | `settings/Schema.lua` | 270 | The schema registry. `RegisterSchemaRows(rows)` (append), `FindSchemaRow(path)` / `SchemaForPage(pageKey, unit)` (lookup; group-stable sort by first-seen registration index, then `row.order`; `unit` filters to that unit's rows plus unit-agnostic ones), `PartitionUnitRows(rows)` (alwaysPerUnit rows vs. mirror-hidden appearance rows), `ResolvePath`/`SetPath` (dotted-path walkers — `units.<unit>.<key>` vs. flat keys, one seam), `SetByPath(path, value)` — the single write seam (`SetSetting` + `fireOnChange`), logging one `[Set] path = value` debug line per write (§10) — and `ApplyDefault(row)` (deep-copies table defaults). The generic `defaultOnChange` (for rows without a custom `onChange`) **publishes** `APPEARANCE` on the bus. `FormatSchemaValue` (slash IO) is now a thin delegate to `LibKa0s-Slash-1.0`'s `lib.FormatValue`, kept under this name because the schema layer is where callers look for it; `ParseSchemaValue` is gone — the type-aware parser is the library's `lib.ParseValue`, and `settings/Slash.lua` hands the library the rows to parse against. `ValidateSchema()` returns THREE values (`errors, resolved, missing`) and additionally checks that every non-Profiles `row.path` (dotted or flat) resolves against `NS.defaults.profile` via `ResolvePath`, printing on a miss. See [schema.md](./schema.md). |
| 19 | `settings/Slash.lua` | 507 | The verb table and this addon's own verbs. The dispatcher, the help renderer, the `key = value` and value formatters, the list builder and the type-aware parser are `LibKa0s-Slash-1.0` (`libs/LibKa0s/Slash.lua`); this file supplies the descriptor. `NS.COMMANDS` is the ordered `{name, desc, fn}` table of 17 verbs (`help`, `config`, `list`, `get`, `set`, `reset`, `resetall`, `resetposition`, `lock`, `unlock`, `toggle`, `debug`, `perf`, `update`, `version`, `test`, `profile`) and stays HERE rather than moving into the library — the About page renders the same table, so a library owning it would drag the options library into depending on the slash one. About renders that same list through `Sl:LandingRows()`. `Sl:Register()` binds `/at` and `/absorbtracker` via `NS.addon:RegisterChatCommand`. The descriptor's `allRows` fixes the `/at list` order (page by page, per-unit pages once per unit) and `groupKey` produces the `[bar / player]` headings. `reset <path>` resets ONE setting — the page-shaped form was removed deliberately; a page is reset by its own Defaults button. `resetall` and `resetposition` stay host verbs delegating to `Helpers.RestoreAllDefaults` / `Helpers.ResetAllPositions`, the latter acknowledging *inside* the guard so it cannot claim success when the helpers failed to load. `MirrorNote` is handed to the library as a row annotator, so it is appended on `list`/`get`/`set` and never on a reset. With the library absent a stub keeps the host verbs working and reports the schema CLI as unavailable. |
| 20 | `settings/OptionsSetup.lua` | 199 | Wires the addon into `LibKa0s-Options-1.0` (`libs/LibKa0s/{Options,OptionsWidgets,OptionsScroll}.lua`, vendored). The canvas shell, the header, the lazy Defaults button, the AceGUI scroll machinery, the always-visible-scrollbar patch, the four widget makers and the 50/50 flow engine are all library code now; this file supplies the **descriptor** — where a value lives, which rows belong to which page, what a color looks like on disk, and what "reset everything" has to clear that no schema row owns. Holds the brand string as a file-scope `PARENT_TITLE` local, passed in as `descriptor.parentTitle` rather than exported on the namespace, then `NS.Helpers = lib:New(descriptor)` — **the instance itself, not a decorated copy**, so `settings/UnitPanel.lua` and `settings/About.lua` decorate the same table the library's own members live on, and a suite that swaps a member out to spy on it is swapping the one the library's callers see. Descriptor fields: `parentTitle`, `mainPanelName`, `print`, `debug`, `get`/`set` (via `NS.GetSetting`/`NS.SetByPath`, so a panel change takes exactly the path a `/at set` takes — the `[Set]` line, the row's `onChange`, the refresh), `applyDefault`, `allRows`, `rowsForPage(pageKey, filter)` (`filter` is `ctx.unit`, passed through uninterpreted — which is what makes a per-unit page render one unit's rows while General, whose `ctx.unit` is nil, gets every unit's), `skipRestoreAll` (skips `page == "profiles"`: those rows are AceDBOptions-supplied and resetting them is data loss), `afterRestoreAll` (→ `Helpers.ResetAllPositions`, because `position` is written by dragging and `ApplyDefault` never touches it), `scheduleTimer` (AceTimer through `NS.addon` per library-stack-§1, backing the color picker's 50 ms drag throttle), `getLSM`, `validate`, `onAceGUI` (publishes `NS.AceGUI`), `buildMain` (nil-guarded, because `settings/About.lua` supplies `BuildMainContent` *after* this file loads), `colorDecode`/`colorEncode` (the `{r,g,b,a}` named-key shape `core/Data.lua` reads). Publishes thin `NS.RegisterOptionsPage` / `NS.CreateOptionsPanel` / `NS.OpenOptionsPanel` / `NS.RefreshOptionsPanel` over the library's own. Its stub is **load-completing, not member-answering** — the one setup file in this addon that breaks the honest-line-per-member pattern, and not because the panel matters less but because of WHEN it is reached: `settings/{Bar,Border,Font}.lua` evaluate `NS.Helpers.LSMValues("statusbar")` inside a schema-row literal at FILE LOAD, so a nil aborts the file, `NS.RegisterSchemaRows` never runs, a third of `NS.Schema` vanishes and `/at list|set|reset` and the profile defaults break with it — the addon would not degrade, it would half-load, and nothing would say so. The stub therefore carries exactly the three load-time members (`LSMValues`, `SECTION_HEADING_H` for About, `RestoreAllDefaults` for General's StaticPopup table literal) plus `ROW_VSPACER` / `BUTTON_PAIR_REL`, no-ops everything reached from a builder or a click, and prints one honest MISSING line from `CreateOptionsPanel` / `OpenOptionsPanel`. No widget maker, flow engine or header is hand-copied — that duplicate is what testing-§8 most specifically forbids. `tests/test_perf.lua`'s `loadDegraded()` loads the whole TOC without the library and asserts `#NS.Schema` against the fully-loaded environment; it is the only thing standing between this stub and a silent half-load. See [settings-panel.md](./settings-panel.md). |
| 21 | `settings/UnitPanel.lua` | 212 | The two pieces of the old `settings/Helpers.lua` that are genuinely this addon's and did not go upstream. **Decorates** `NS.Helpers` — which *is* the library instance — so a page file calls `H.RenderUnitPanel` and `H.RenderSchema` without knowing or caring which is which. `Helpers.ResetAllPositions()` is the SINGLE reset-position implementation: clears every unit's saved position via `NS.Units.SetPosition(unit, nil)`, then publishes `POSITION`. `/at resetposition`, the General page's button and the descriptor's `afterRestoreAll` all call it, so the CLI, the panel and Reset All cannot diverge — **they diverged here once already**, when the panel button nil'd `db.profile.position`, the pre-v3 flat key the v3 migration deletes, making the button a silent no-op. Do not re-inline the loop at any call site. `Helpers.RenderUnitPanel(ctx, pageKey)` draws the Bar/Border/Font pages: Unit dropdown + mirror header (checkbox + copy button, hidden-while-mirrored hint), then the schema rows filtered to the selected unit. Full rebuild on every call rather than a persistent header widget — the library's ScrollFrame anchors flush to `ctx.body`, leaving no real estate above it, and AceGUI's widget pool exists to make release-and-recreate cheap. Guarded against re-entry by `ctx.__rendering`, because the last thing it does is register a refresher that re-renders the whole panel. That refresher is **two-tier**: always re-sync the mirror checkbox in place, and re-render *only* when the mirror state actually changed — an unconditional re-render would `ClearScroll` the very widget whose `OnValueChanged` is still on the stack. Bails early on a nil `NS.AceGUI`. Everything it stands on (`ClearScroll`, `EnsureScroll`, `RenderRows`, `AttachTooltip`) is the library's, reached through the same table. |
| 24 | `settings/About.lua` | 104 | `Helpers.BuildMainContent(ctx)` — top-level "Ka0s Absorb Tracker" page builder, decorated onto `NS.Helpers` and invoked through the options descriptor's `buildMain` hook on the main panel's first OnShow. That hook is nil-guarded in `settings/OptionsSetup.lua` precisely because this file loads *after* it. Renders the logo TGA, the addon `Notes` one-liner, a "Slash Commands" Heading, and one Label per `NS.Slash:LandingRows()` entry — the same `LibKa0s-Slash-1.0` row formatter `/at help` uses, minus the chat indent, so the page and the help block cannot drift. (Rows are therefore uppercase-hex gold, a single-spaced em dash and a white description — the library's shape, not the lowercase double-spaced uncoloured one this page drew before.) Metadata reads route through `NS.Compat.GetAddOnMetadata`. |

### settings/ — sub-page schemas

Each file (except `Profiles.lua`) registers schema rows for the page, declares a `build(mainCategory)` closure that creates a canvas via `Helpers.CreatePanel`, defers `Helpers.RenderSchema(ctx, pageKey)` to first `OnShow`, and returns `Settings.RegisterCanvasLayoutSubcategory`. Then `RegisterOptionsPage(key, name, build)`. The names are unchanged from before the extraction; the implementations behind `CreatePanel` / `RenderSchema` / `RegisterOptionsPage` are `LibKa0s-Options-1.0`'s, reached through `NS.Helpers`.

| # | File | Lines | Schema rows |
|---|------|-------|-------------|
| 25 | `settings/General.lua` | 231 | `showOnlyInCombat` (order 25, label "Show only in combat"; `onChange` publishes `VISIBILITY`, and `REPAINT` when the bar should show), `locked` (order 15), one `units.<unit>.enabled` row per `NS.Units.LIST` entry (labels "Enable Player/Target/Focus Bar", orders 10 / 20 / 30 so each LEADS a row with a global on its right; `alwaysPerUnit` so `/at get` never tags them with the mirrored note; `onChange` publishes `UNITS` → `APPEARANCE` → `REPAINT`-when-on — the only unit-scoped rows on this page, and the addon's only visibility switch since v4 dropped `hidden`), `throttleWindow` (Performance group, `solo`, label "Update throttle (in sec)"). Build closure injects an `InlineButtonPair` ("Reset Position" — delegates to the shared `Helpers.ResetAllPositions` — + "Reset All Settings") under the **Master controls** group via the `afterGroup` callback, and the **Debug console** checkbox (`Helpers.SessionCheckbox` + `NS.DebugLog:ConsoleCheckbox()`, shows/hides the console window) beside `units.focus.enabled` via `RenderSchema`'s `pairWith` seam — which only fires because the five schema rows pair off as 2 + 2 + 1, leaving that row alone. Defines the `ABSORBTRACKER_RESET_ALL` `StaticPopupDialog` for the destructive confirm. |
| 26 | `settings/Bar.lua` | 183 | Per-unit page. `addUnitRows(unit)` generates one row set per `NS.Units.LIST` entry (path `units.<unit>.*`, tagged `unit = unit`): `barWidth` / `barHeight` (**Size** pair) — the **Bar** section: `barTexture` (solo) above `barColor` paired with `useClassColorBar` — the **Background** section: `bgTexture` (solo) above `bgColor` paired with `useClassColorBg` — plus, target/focus only, a group-less `mirror` row (`alwaysPerUnit`, `skipRender` — drawn bespoke by `Helpers.RenderUnitPanel`'s header instead; group-less because `RenderRows` emits a group heading before it checks `skipRender`, so naming one would draw an empty section). The enable toggle that used to head this page in a **This bar** group now lives on General. The color rows carry `disabledIf = "units.<unit>.useClassColorBar"` / `"...Bg"`. LSM dropdowns call `NS.Helpers.LSMValues("statusbar")`. Build closure calls `Helpers.RenderUnitPanel(ctx, "bar")` on every `OnShow` (no one-shot guard). |
| 27 | `settings/Border.lua` | 104 | Per-unit page, same `addUnitRows(unit)` pattern as Bar.lua. One section "Border" laid out 2×2: `border` (LSM border style) / `borderSize`; `borderColor` (`disabledIf = "units.<unit>.useClassColorBorder"`) / `useClassColorBorder`. Target/focus also get the `skipRender` `mirror` row. LSM dropdown calls `NS.Helpers.LSMValues("border")`. |
| 28 | `settings/Font.lua` | 108 | Per-unit page, same `addUnitRows(unit)` pattern. One section "Typography": `font` / `fontSize`; `fontFlags` (solo). Target/focus also get the `skipRender` `mirror` row. LSM dropdown calls `NS.Helpers.LSMValues("font")`. |
| 29 | `settings/Profiles.lua` | 75 | Custom canvas with the unified header (no Defaults button), an AceGUI `SimpleGroup` parented to `ctx.body`, and `AceConfigDialog:Open("AbsorbTracker-Profiles", container)` on first `OnShow`. Not schema-driven; AceDBOptions supplies its own options table. `build` returns `nil` (silently skips the page) if AceDBOptions / AceConfigDialog / AceGUI is missing. |

### tests/ — headless harness

Run from the repo root with `lua tests/run.lua`. Loads every addon source file with the `("AbsorbTracker", NS)` calling convention against a WoW-API mock, runs `NS:InitDB()`, then executes the suites. The authoritative per-suite and total case counts live in the generated [test-cases.md](./test-cases.md) (`lua tests/run.lua --list`).

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 30 | `tests/run.lua` | 85 | The runner. Builds mocks, **derives** the addon's load list from `AbsorbTracker.toc` (rather than carrying a copy) and loads it through `tests/_kit/loader.lua`, after the vendored `libs/LibKa0s/*.lua` — which the TOC reaches through an XML the loader cannot read, so that half is the one hand-maintained list, pinned by `test_loadorder.lua`. Then `NS:InitDB()`, `NS.CreateOptionsPanel()`, publishes the shared kit's registry and assertions as `AT_TEST` via `Kit.expose`, and runs the twenty-two suites (or, with `--list`, prints the `docs/test-cases.md` inventory and exits). Exits non-zero on any failure. |
| 31 | `tests/_kit/` | 1319 | The **shared headless harness**, vendored from `LibKa0s/testkit` and kept byte-identical to it (`diff -r` is part of the green gate). `framework.lua` (438) is the case registry, the assertions and the runner; `loader.lua` (128) `loadfile` + `setfenv`s each chunk into an environment where WoW globals resolve to the mock set (falling back to `_G`) and writes land in `_G`, plus `tocFiles()` for TOC-derived load lists and `xmlFiles()` for the vendored library half the TOC reaches through an XML; `mock_base.lua` (537) is the universal half of the WoW-API mock; `vendor_sync.lua` (216) is the shared vendor-drift comparator `tests/test_vendor_sync.lua` drives. It lives under `tests/` rather than `libs/` precisely so the `- tests` entry `.pkgmeta` already carries excludes it from the zip. |
| 30a | `tests/perf.lua` | 302 | The **offline perf runner** (issue #17) — standalone, deliberately **outside** the green gate (`lua tests/run.lua` never invokes it). `lua tests/perf.lua [--out <path>] [--label <text>]`. Loads the addon through `tests/_kit/loader.lua`, wraps the bar frames in a call-counting proxy layer (memoized per frame — under the mock `CreateFontString` returns its parent, so `valueText` and `statusBar` are the same table and independent wrapping would silently drop calls), then runs six scenarios: the 1,000-event coalescing burst, `absorbEvent`, `paintPass`, `appearancePass`, `settingsRead`, and `probeOverheadOff`/`On`. Hard-asserts only deterministic quantities (repaint counts, API calls per pass, bytes per pass via `collectgarbage("count")`) and reports wall time without asserting on it; exits non-zero on an assertion failure. Emits the shared (schema 2) record via `NS.Perf.EncodeJSON`, reading `NS.Perf.SCHEMA` off the `LibKa0s-Perf-1.0` instance rather than hardcoding it. Its buckets carry no `within`: each scenario is driven on its own and times only its own loop, so none of these totals is contained in another. |
| 32 | `tests/wow_mock.lua` | 27 | This addon's thin overlay on `tests/_kit/mock_base.lua`, which now owns the universal frame stub and the Ace3 mocks. What stays here is what is genuinely AbsorbTracker's: `C_AddOns` (deliberately absent from the base, because `test_compat` reaches its deprecated-global fallback by swapping `_G.C_AddOns` to nil and a base-level stub would shadow the swap) and the `UnitClass` fixture values the suites assert on. The behavior below is the base's and is described here because this is where a reader looks for it: `__timers` / `__fireTimers()` for driving `NS.addon:ScheduleTimer` deterministically. `RegisterUnitEvent(event, ...)` records the `(event -> unit tokens)` mapping per frame (`self.__unitEvents`) instead of no-opping it, so a test can assert the two-frame split (player+target on one frame, focus on the other) is real rather than assumed. The `AceDB-3.0` mock implements a real profile surface (named profile store, `SetProfile` / `CopyProfile` / `DeleteProfile` / `ResetProfile` / `GetProfiles`, plus the `OnProfileChanged` / `Copied` / `Reset` callbacks) so the `/at profile` verb is reachable at all; it exposes the raw store as `db.sv` (as the real lib does) and only merges defaults into a profile when that profile is ACTIVATED, so a pre-seeded, never-activated profile stays un-stamped and pre-v3 — the case the per-profile lift has to handle. The AceGUI mock records every widget it creates on `AceGUI.__created`, the only seam a test has for reaching widgets on a page whose `ctx` is private (the General page's Reset Position button). The `AceEvent-3.0` mock models real `(message, target)`-keyed message dispatch (one shared registry, `SendMessage` fans out to every registered target) so bus wiring — and the two-receivers-both-fire clobber case — is exercised faithfully (anti-pattern #33). |
| 32b | `tests/degraded_env.lua` | 38 | Not a suite — the **builder** for a second addon environment with LibKa0s absent, returned as a function so more than one suite can ask for one (`test_perf.lua`, `test_helpers.lua`, `test_optionssetup.lua`). Loads the WHOLE TOC list, in the TOC's own order, through a fresh `tests/_kit/loader.lua` with no `libs/LibKa0s/*.lua` — the mock's `LibStub` then answers nil for every major exactly as a real client would, so every setup file's degradation path is exercised as a **load** rather than as a hand-stub. Both properties are load-bearing: whole, because the hazard is a page file calling a helper at file load (`settings/Bar.lua` evaluates `LSMValues` inside a schema-row literal) and a list that stopped short would stay green through a total load failure; in TOC order, because `core/PerfSetup.lua` loads BEFORE `core/DebugLogSetup.lua`, which is why PerfSetup's `NS.DebugLog` lookups have to stay lazy. Calls neither `InitDB` nor `CreateOptionsPanel`, so the shared suite's SavedVariables globals are untouched. |
| 33 | `tests/test_schema.lua` | 461 | schema registry, group-stable sort, `SchemaForPage(page, unit)` filtering, `PartitionUnitRows`, `ResolvePath`/`SetPath` (dotted per-unit paths), `SetByPath`, `ValidateSchema` three-value return / path resolution (flat and dotted), format/parse. Plus the build-time integrity invariants: every row has a label/desc/default, paths are unique, each row's `default` agrees with `defaults.profile` **both ways**, number rows declare a sane `min`/`max` bracketing their default, string rows supply `values`, `disabledIf` resolves; and the `SetByPath` / `ApplyDefault` dispatch contract (own `onChange` vs. the `APPEARANCE` fallback, color deep-copy, nil-default no-op). |
| 34 | `tests/test_database.lua` | 405 | `InitDB`, `RunMigrations` idempotency + backfill (flat and per-unit), deep-copy isolation, `schemaVersion` v1→v2 migration (drops `updateInterval`, seeds `throttleWindow`), and the v3 migration (lifts pre-v3 flat appearance keys onto `profile.units.player`, gated on a version stamp rather than `profile.units == nil`). Plus the per-profile lift: two pre-v3 profiles both lifted at `InitDB` via `db.sv.profiles`, a profile that appears only after the upgrade lifted on profile change, proof the two mechanisms don't double-apply, and that the per-profile default stamp is `1`. |
| 35 | `tests/test_compat.lua` | 33 | `Compat.GetAddOnMetadata` C_AddOns path, `_G` fallback, and `nil` degradation. |
| 35a | `tests/test_coresetup.lua` | 64 | `core/CoreSetup.lua`: that the seam actually reaches `LibKa0s-Core-1.0` (`NS.IsConcatSafe` / `NS.SafeToString` are Core's own functions, identity-checked, not a leftover private copy), that `NS.Print` carries the `[AT]` tag and survives a secret arg, that `NS.Print` and `NS.Util.print` are one object after the AceConsole reclaim, and a **degraded install** — a second, self-contained load with `libs/LibKa0s/` absent, proving the fallbacks still guard secrets, the identity still holds, and the "LibKa0s is missing" line is said once rather than on every line. The algorithms themselves are the library's and are tested in the LibKa0s repo. |
| 37 | `tests/test_debuglog.lua` | 155 | This addon's side of the debug console — the console itself (`LibKa0s-DebugLog-1.0`: the two formatters, the buffer and its cap, the enable seam's write path and ordering, the window, and the checkbox contract) has its own suite in the LibKa0s repo; duplicating it here would mean two places to fix one bug. What this file covers: `FONT_MONO` really is the vendored JetBrains Mono TTF, the flag the library reads and writes is `NS.State.debug` (with a change made behind the library seen immediately, proving there is no second copy), `NS.Debug` is published and one call reaches the shared buffer unchanged, the window's title bar names this addon, the three `/at debug` forms reach the right member (`on`/`off` set the flag, bare toggles the window and must NOT change it), and the `[Init]` summary carries our name, version, schema version and active profile. |
| 38 | `tests/test_slash.lua` | 169 | `NS.COMMANDS` verb table, dispatch, unknown-verb handling, the `/at version` verb, `OpenOptionsPanel` `[Cfg]` refusal logging, `SetByPath` `[Set]` logging (§10). |
| 39 | `tests/test_timer.lua` | 149 | `NS.RequestRepaint` coalescing + `throttleWindow` delay, `OnAbsorbChanged` / `OnMaxHealthChanged` (player/target/focus) + `OnEnterWorld` + `OnUnitSwap` repaint wiring (via the bus). |
| 32a | `tests/test_loadorder.lua` | 125 | The load lists cannot drift. This repo names its files in load order in four places — the TOC, `tests/run.lua`, `tests/perf.lua` and `test_perf.lua`'s deliberately partial `loadDegraded()` — and only the first two are under the green gate. These cases pin `tocFiles()`'s derivation (order, libs/comments/directives skipped, backslashes converted, every derived path exists on disk), assert the runner loaded exactly the TOC's list, assert `tests/perf.lua` still derives rather than carrying a copy, and — because the library half **cannot** be TOC-derived — parse `libs/LibKa0s/LibKa0s.xml` and assert both runners load every file it lists, in its order. That last case exists because omitting a library file fails silently: the dependent module simply refuses to register and the runner measures a degradation stub. Also pins the strict LibStub mock (raises without the silent flag, nil with it, higher minor wins). |
| 39a | `tests/test_perf.lua` | 421 | This addon's side of the perf harness (issue #17) — the probe itself (`LibKa0s-Perf-1.0`: buckets, JSON, the record schema, the report, the ring, the measurement windows, the panel, and the idempotency of `Suspend`/`Resume`) has its own suite in the LibKa0s repo; duplicating it here would mean two places to fix one bug. What this file covers: `core/PerfSetup.lua`'s descriptor is well-formed and every bucket it declares is actually reached by a bracket, the brackets themselves (silent when off, `paintBar` excludes early-outed bars, one `repaintPass` note per coalesced pass), that the capture ring is reachable through its own SavedVariables global and by **no path at all** from `db.profile` / `db.global` (an identity walk, so it cannot pass for want of a field nobody writes), and that `Suspend`/`Resume` genuinely make THIS addon inert (the `ShouldShowBar` step-0 gate, unit-frame and lifecycle-event teardown/restore, `RequestRepaint` no-op, `CancelPendingRepaint`, session-only state). Ends with the **degraded install**: a second, self-contained load with `libs/LibKa0s/` absent, proving the addon loads, the bracket sites and the show ladder still run, and `/at perf` explains itself instead of erroring. |
| 40 | `tests/test_visibility.lua` | 286 | `ShouldShowBar` four-step ladder (incl. the lockdown-lags-combat regression and the target/focus `UnitExists` step) + combat-handler wiring, `[Combat]` rollup coalescing (player events only), per-event `[Absorb]` transition logging on non-secret values. |
| 41 | `tests/test_bus.lua` | 98 | The closed message bus: catalog (`NS.bus` / `NS.NewBusTarget` / `NS.MSG`) published, a receiver hears a message on its own target then goes silent after unregister, **two receivers of one message both fire** (anti-pattern #33 — no `(message,target)` clobber), payload delivery order, `REPAINT` → one coalesced repaint through `Timer`, and `APPEARANCE`/`VISIBILITY`/`POSITION` → their `Display` consumers. |
| 42 | `tests/test_data.lua` | 343 | `core/Data.lua`: the `GetSetting` / `SetSetting` DB seam (profile read, dotted-path resolution, `flatDefaults` fallback, stored-`false` survival, no-DB degradation), the four per-unit LibSharedMedia fetchers across all three branches (LSM absent / key resolves / key missing), `ClearLSMCache` late-load pickup, `Helpers.LSMValues`, and the three per-unit class-color resolvers (RGB substituted, alpha always preserved, toggles independent per unit, background dimmed by 0.2, class color always the player's). |
| 43 | `tests/test_display.lua` | 606 | `modules/Display.lua` paint path, per unit: `NS.ForEachUnit`, `NS.DefaultPosition` (stacked target/focus defaults), `RestoreBarPosition` (center / saved anchor / clear-first), `UpdateBarAppearance` (size, backdrop inset `max(1, floor(borderSize/4))`, the mandatory nil-then-set `SetBackdrop` refresh, lock ⇒ movable+mouse, font flags, trailing `ApplyVisibility`, mirror-resolved reads), and `UpdateAbsorbBar` (hidden and `testHoldUntil` early-outs, max-health scaling, nil-read fallbacks, `NoteRepaint` accounting). |
| 44 | `tests/test_helpers.lua` | 893 | The non-AceGUI half of what `NS.Helpers` answers — mostly `LibKa0s-Options-1.0` now, driven through this addon's descriptor, plus `settings/UnitPanel.lua`'s two members. The suite did not move when the code did, because what it pins is the *contract this addon depends on*, not the library's internals: `CreatePanel` ctx shape / unprefixed `panel.name` / the lazy Defaults-button *declaration* (options-ui-§5, anti-pattern #42), `EnsureDefaultsButton` no-op paths, `RestoreDefaults` page scoping + refresher isolation, `RestoreAllDefaults` (profiles page skipped, every unit's `position` cleared, `POSITION` published), `RefreshAllPanels` fault isolation, and the published cross-slice layout constants. Plus the **Blizzard canvas contract** the library stamps in `CreatePanel` as of `LibKa0s-Options-1.0` minor 5 — that the panel carries `OnCommit` / `OnRefresh` / `OnDefault`, and that `OnDefault` forwards to a `defaultsOnClick` parked *after* the panel is built (which is what all four pages do) and stays callable and inert on a page that parks none. All three read through `rawget`, because the frame mock synthesizes a no-op for any PascalCase key and a plain `type()` check would pass whether or not anything ever set it. |
| 45 | `tests/test_slashcmds.lua` | 1282 | The rest of `settings/Slash.lua`: `COMMANDS` table shape (triple, unique lower-case verbs), `lock`/`unlock`/`toggle` (incl. repaint coalescing), `update`, `reset` (spans all units) / `resetall` / `resetposition` (clears every unit), the `get`/`set` failure paths (fully-qualified paths only), `test` (hidden refusal, hold window, scale floor), and the whole `/at profile` sub-dispatcher (list/current/use/new/copy/delete/reset, usage lines, unknown sub-verb, no-AceDB degradation, and the `OnProfileChanged` republish). Also the whole `/at perf` dispatch surface — every sub-verb reaching the right probe call, where its output lands (console vs chat vs copy window), the panel as the entry point, and that a panel click prints in chat exactly what typing the same command prints. |
| 46 | `tests/test_widgets.lua` | 664 | The schema-row → AceGUI widget layer — `LibKa0s-Options-1.0`'s `OptionsWidgets.lua` and `OptionsScroll.lua`, driven through this addon's descriptor against the AceGUI mock: the four widget makers (checkbox read/write, slider range + step snapping relative to `min`, dropdown `dialogControl` fallback / alphabetical vs. explicit `sorting` / list rebuild on refresh, color picker `disabledIf` graying + the throttled-drag commit), `SessionCheckbox` (session-only, never persisted), `RenderField` dispatch, `RenderRows`/`RenderSchema` layout (50/50 pairing, `solo` rows, per-group `Heading`s, one-shot `afterGroup` and `pairWith`, `skipRender` rows omitted), the always-visible-scrollbar patch, and the four real pages driven through their deferred `OnShow` (lazy Defaults button, page-scoped reset, second-show idempotence, About content). |
| 47 | `tests/test_units.lua` | 155 | `core/Units.lua`: `LIST`/`LABEL` shape, `IsEnabled`/`IsMirrored`/`SourceUnit` (player never mirrored), the mirror-resolved `Get` (unit's own value wins, falls back to that unit's default, falls back to the player's default), `Position`/`SetPosition` (never mirror-resolved), and `CopyFromPlayer` (deep-copies all 15 appearance keys, clears `mirror`, leaves `position`/`enabled` untouched) — the last of which is also the only coverage `DeepCopy` has, through the shared color table it must not alias. **`Set` has no case here and no production caller** — it is the published write half of the `Get` seam, kept and annotated at `core/Units.lua`; do not restate it as covered. |
| 48 | `tests/test_optionssetup.lua` | 92 | `settings/OptionsSetup.lua` as a FILE — the descriptor's half of the reset contract and the degradation stub, the panel toolkit itself being `LibKa0s-Options-1.0`'s to test. Four cases: the live and degraded builds veto exactly the same rows from Reset All (driven through two probe rows appended for the duration, because no shipping row sits on the Profiles page today — the veto exists for the row added there next, which is what keeps the case non-vacuous); the degraded stub publishes `LSMValues`, the one member reached at **file load** and therefore the one whose absence would silently cost a third of `NS.Schema`; the stub keeps no private copy of the library's layout constants; and `PARENT_TITLE` reaches the library through `descriptor.parentTitle` with `NS.PARENT_TITLE` asserted nil, so a reflex re-export has to argue for itself. |
| 49 | `tests/test_docs.lua` | 242 | The shipped prose is checkable, so it is checked — two rules no code path enforces and no reviewer reliably catches. **(1)** `README.md` carries no angle-bracket argument placeholders: CurseForge's markdown renderer treats `<path>` as an unknown HTML tag and strips it — inside backticks too — so a command row that reads perfectly on GitHub ships to players with its argument silently deleted. Deliberate HTML (`<br>` in the Version History cells) is allowed through. **(2)** US English across every authored string and comment in the addon's OWN files, against a dictionary of British forms and their US counterparts (the `-our`/`-or`, `-ise`/`-ize` and `-re`/`-er` pairs, plus a handful of one-offs — the dictionary itself lives in `tests/test_docs.lua`, which the check skips along with the generated `docs/test-cases.md` — naming the forms is its job). Scope is deliberately narrow: `libs/` and `tests/_kit/` are vendored, where a local spelling fix is reverted by the next whole-folder re-vendor, and `docs/audits/`, `docs/reviews/`, `docs/superpowers/`, `docs/investigations/` and `docs/perf-runs/` are frozen dated bundles whose rewriting would destroy the record of what was true on the day they were written. |
| 50 | `tests/test_ltrap.lua` | 240 | The `L` trap, in the one place that sees all five seams at once. Every LibKa0s module taking an `L` override resolves the descriptor's table before its own `STRINGS`, and this addon's `NS.L` answers *every* key with a string (the standard's mandated metatable fallback), so `L = NS.L` would render raw SCREAMING_SNAKE keys for every key at once, in game only — the bug KickCD shipped. Five guards, each honest about what it can see: a **source** check that reads the five seam files and fails on any `L =` whose value can EVALUATE TO `NS.L` — the bare form and `L = NS.L or {}` alike, but not the legitimate `L = NS.L and { ... } or nil` (the only guard that can redden on the mistake itself, because a descriptor field is not observable after `lib:New` returns); a case driving that matcher against all three spellings, so it cannot be narrowed back to one anchored form while still reporting green; a non-vacuity case pinning that `locales/enUS.lua` really does synthesize, so the source check is guarding something; and three **library-regression** cases that hand the vendored DebugLog, Slash and Perf the exact fallback-table shape every Ka0s host has and require the built-in English back — the `rawget` hardening (landed at DebugLog 3 / Slash 4 / Perf 5; live here at DebugLog 6 / Slash 5 / Perf 5) is what makes that pass, and a re-vendor that regressed it would fail here rather than in a player's UI; and two **tripwires**, one on Core and one over the three Options files, for the two majors that cannot express the trap today. Core and Options take no `L` at all — Core has no `STRINGS`, and Options' `L` is `lib.LAYOUT` — so neither gets a descriptor-mutation case it could not fail, and the tripwires stand in: they read the vendored source and redden the day either grows an override path, which is the day the real assertion becomes writable. The Options tripwire is deliberately NOT the Core one's shape — Options ships its own `lib.STRINGS`, so asserting that table absent would fail against a module behaving as designed. The matching **rendered** assertions live in each module's own suite (`test_debuglog`, `test_slash`, `test_perf`, `test_helpers`). |
| 51 | `tests/test_surface_parity.lua` | 115 | Every degradation stub carries the whole live surface, asserted as a **set** rather than member by member. The addon adopts four LibKa0s seams — Core, DebugLog, Options and Slash — and each setup file carries a stub for the install where `libs/LibKa0s/` is missing; a stub is a second implementation of somebody else's surface, so it drifts the moment the library grows a member the host starts calling, and the live path stays green while the degraded path raises in exactly the install the stub exists for. The degraded arm comes from a **real load** with a partial file list (`tests/degraded_env.lua`), never a hand-written stub, and a member that is live-only on purpose is named in the case's `ignore` set with its reason, because otherwise a deliberate omission and a bug read identically (testing-§8). Each case names the grep that produced its member list. |
| 52 | `tests/test_vendor_sync.lua` | 30 | The **vendored-payload gate**: that `libs/LibKa0s/` and `tests/_kit/` are exactly what the LibKa0s repo published at the tag `README.md`'s provenance line says this addon bundles. One line of adoption — the comparator itself is `tests/_kit/vendor_sync.lua`, part of the payload it checks, so a local patch to the kit breaks the kit's own byte-identity assertion. Compared against the **tag**, not LibKa0s's working tree, so upstream progress this addon has not adopted cannot redden it (and cannot be "fixed" by vendoring bytes that exist at no ref). The provenance line is an **input, not a constant** — a line and a payload that disagree is the drift this file exists to catch. One normalization only: CR is stripped from the working-tree side, because `git show` hands back the LF blob while `.gitattributes` pins CRLF on disk. A missing sibling checkout reports a **skip carrying its reason**, never a pass. |

### Bundled libraries (libs/)

Folder-per-lib, loaded before any addon source via the `#@no-lib-strip@` block at the top of the TOC.

| Path | Purpose |
|------|---------|
| `libs/LibStub/` | Library loader. |
| `libs/CallbackHandler-1.0/` | Event/message callback transport for the Ace3 stack — keys callbacks by `(event, target)`, which is why each bus receiver owns its own `NS.NewBusTarget()`. |
| `libs/AceAddon-3.0/` | Addon lifecycle carrier. `NewAddon(NS, …)` promotes `NS` and stamps the AceEvent / AceTimer / AceConsole mixins onto `NS.addon`. |
| `libs/AceEvent-3.0/` | `self:RegisterEvent` event handling (global/lifecycle events) **and** the cross-module message bus: `core/Bus.lua` `Embed`s `NS.bus` and each `NS.NewBusTarget()` receiver so `SendMessage`/`RegisterMessage` carry the `NS.MSG` catalog. The two `UNIT_*` events use a private `RegisterUnitEvent` frame instead — AceEvent-3.0 shares one frame and cannot unit-filter (documented events-frames-taint-§1 deviation). |
| `libs/AceTimer-3.0/` | `ScheduleTimer` / `CancelTimer` — drives the coalescing repaint throttle (`NS.RequestRepaint`) and the color-picker drag throttle (replaces `C_Timer`). |
| `libs/AceConsole-3.0/` | `RegisterChatCommand` for `/at` and `/absorbtracker` (replaces hand-rolled `SLASH_*` globals). |
| `libs/AceDB-3.0/` | Profile management. Optional dep — addon falls back to a flat `AbsorbTrackerDB` shim when missing. |
| `libs/AceGUI-3.0/` | Widget framework used by the canvas-layout panel and AceConfigDialog. |
| `libs/AceConfig-3.0/` | Pulls in AceConfigRegistry / AceConfigCmd / AceConfigDialog. Required by the Profiles sub-page. |
| `libs/AceDBOptions-3.0/` | Builds the Profiles sub-page options table. |
| `libs/LibKa0s/` | The Ka0s shared libraries, vendored the same way Ace3 is, not depended on — **five majors across eight files**. `LibKa0s-Core-1.0` (`Core.lua`) — the secret-value guard (`IsConcatSafe`/`SafeToString`), the prefixed chat printer, and the shared window chrome (`SKIN`, `ApplySkin`, `MakeCloseButton`); read only by `core/CoreSetup.lua` (`LibStub("LibKa0s-Core-1.0", true)`). `LibKa0s-DebugLog-1.0` (`DebugLog.lua`) — the on-screen debug console (issue #17): the window and its Copy window, the `FormatPlain`/`FormatColored` formatters, the 500-line buffer (`MAX_BUFFER`), the gated `Debug` sink and the `SetEnabled` seam; read only by `core/DebugLogSetup.lua`, and it re-exports `Core`'s `MakeCloseButton` so the addon has ONE close-button factory. `LibKa0s-Slash-1.0` (`Slash.lua`) — the shared slash surface: the dispatcher and its verb aliases, the help renderer, the `cmd — desc` row formatter (`FormatRow`), the `key = value` formatter (`FormatKV`), the value renderer (`FormatValue`), the `/at list` builder and the type-aware value parser (`ParseValue` — clamping, the case-sensitive enum check, the color rescale); read by `settings/Slash.lua`, which hands it a descriptor, and by `settings/Schema.lua`'s `FormatSchemaValue` delegate. `LibKa0s-Options-1.0` (`Options.lua` + `OptionsWidgets.lua` + `OptionsScroll.lua`) — the settings-panel toolkit: the canvas shell and its unified header, the lazy Defaults button, the scroll machinery, the panel/refresher registry, `LSMValues`, the four schema widget makers, the 50/50 flow engine with its `afterGroup`/`pairWith` one-shot seams, and the always-visible-scrollbar patch; read only by `settings/OptionsSetup.lua` (`LibStub("LibKa0s-Options-1.0", true)`). Note the multi-file shape: `OptionsWidgets` and `OptionsScroll` attach onto the shell's instance and their guards pair on the **shell's** minor (`lib.__widgetsShellMinor` / `lib.__scrollShellMinor`), so a stale copy of one file cannot silently attach to a newer shell. If only one attach file fails to load, `lib:New` still succeeds and the failure surfaces at *call* time, not load time. `LibKa0s-Perf-1.0` (`Perf.lua` + `PerfPanel.lua`) — the perf-instrumentation harness (issue #17): the in-game probe, the record schema, and the clickable step panel; read only by `core/PerfSetup.lua`. `Core` is the root; `DebugLog`, `Slash`, `Options` and `Perf` each declare `NEEDS_CORE` and simply don't register if `Core` is missing or older. `LibKa0s.xml` fixes the order: `Core.lua` → `DebugLog.lua` → `Slash.lua` → `Options.lua` → `OptionsWidgets.lua` → `OptionsScroll.lua` → `Perf.lua` → `PerfPanel.lua`. |
| `libs/LibSharedMedia-3.0/` | Texture / font / border registry. Optional dep — addon falls back to `FALLBACK_*` Blizzard constants in `core/Data.lua` / `core/Constants.lua` when missing. |
| `libs/AceGUI-3.0-SharedMediaWidgets/` | Canonical upstream `AceGUI-3.0-SharedMediaWidgets` r65. Multi-file lib loaded via `widget.xml` — `prototypes.lua` (base-frame helpers) plus per-mediatype widget files for `LSM30_Statusbar` / `LSM30_Border` / `LSM30_Background` / `LSM30_Font` / `LSM30_Sound`. The addon references statusbar / border / font; the rest ship because the lib is monolithic. The 42×42 displayButton tile on `LSM30_Border` is suppressed by addon-side `core/LSMPatch.lua`. |

### Shared infrastructure

- `AbsorbTracker.toc` — Interface line (`120007`), `## Version:`, SavedVariables (`AbsorbTrackerDB, AbsorbTrackerPerfDB`), modular file load order (Libraries → Locales → Core → Defaults → Modules → Settings). Order is dependency order, not alphabetical.
- `media/` — bundled assets in typed subfolders: `media/logos/absorbracker.logo.v2.tga` (`NS.Constants.LOGO_PATH`) and `media/fonts/JetBrainsMono-Regular.ttf` (+ `OFL.txt`, `NS.Constants.FONT_MONO`).
- `.gitattributes` — enforces CRLF on `*.lua` / `*.toc` / `*.xml` / `*.md` (`* text=auto eol=crlf` plus explicit per-extension lines).
- `LICENSE` — MIT.

### Top-level docs

- `README.md` — user-facing.
- `CLAUDE.md` — the standards-compliance stub (working rules + doc pointers). Per documentation-§2 it stays a stub; the engineer brief is `docs/ARCHITECTURE.md`.
- `docs/ARCHITECTURE.md` — subsystems-at-a-glance + invariants + doc index.
- `docs/*.md` — topic chunks (this file is one of them).
