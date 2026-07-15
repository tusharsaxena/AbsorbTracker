# File index

Where each responsibility lives in the source tree. Match this map to the actual files before editing — `AbsorbTracker.toc` is the source of truth for load order.

The tree is modular (Ka0s standard): `core/` (bootstrap + data + infrastructure), `defaults/` (AceDB defaults), `locales/` (strings), `modules/` (the bar runtime), `settings/` (schema + slash CLI + the multi-page panel), `tests/` (headless harness). Every file opens with `local addonName, NS = ...`; `NS` is the single shared private table, promoted to an AceAddon object in `core/AbsorbTracker.lua`.

## core/ — bootstrap, data, infrastructure

Loaded first among addon source (after libs). `Compat` leads so its shim exists before anything calls it; `AbsorbTracker` (the AceAddon lifecycle) loads last in the group so `InitDB` / the enable sequence can reference everything else.

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 1 | `core/Compat.lua` | 20 | The ONLY file that calls deprecated / flavor-varying APIs. `Compat.GetAddOnMetadata(name, field)` wraps `C_AddOns.GetAddOnMetadata` with a `_G.GetAddOnMetadata` pre-11.0 fallback, degrading to `nil` when neither exists. `settings/About.lua` and `settings/Slash.lua` route through it. |
| 2 | `core/Constants.lua` | 16 | `NS.Constants`: the `FALLBACK_TEXTURE` / `FALLBACK_BORDER` / `FALLBACK_FONT` Blizzard paths returned when LSM is absent or a key doesn't resolve, `FONT_MONO` (the vendored JetBrains Mono path used by the debug console), and `LOGO_PATH` (the About-page TGA). |
| 3 | `core/Namespace.lua` | 15 | Shared-namespace bootstrap. `NS.name` / `NS.version`, the cyan `NS.PREFIX` (`|cFF00FFFF[AT]|r`), and the hot-path `NS.floor` / `NS.max` caches used by the bar paint path (`NS.format` is cached here too but currently has no caller — a dead-export candidate). Runs early so metadata + caches exist regardless of load order. |
| 4 | `core/State.lua` | 5 | `NS.State` — session-only runtime state, never persisted. Holds `NS.State.debug` (the debug flag, defaults off, resets on every `/reload` and login). |
| 5 | `core/Util.lua` | 48 | `NS.Print(...)` — the cyan-`[AT]` chat-prefix pipeline; every arg routes through `NS.SafeToString`. Files that emit chat do `local print = NS.Print`. `NS.IsConcatSafe` / `NS.SafeToString` (the secret-value guard) also live here. The secret-safe debug sink is `NS.Debug(tag, fmt, ...)`, defined in `core/DebugLog.lua`. |
| 6 | `core/Data.lua` | 167 | Bar data + media access layer. `NS.db` ref, `GetSetting(key)` / `SetSetting(key, value)` over `db.profile` (falling back to `flatDefaults`), the cached LSM fetchers (`GetBarTexture` / `GetBgTexture` / `GetBorder` / `GetFont` with `FALLBACK_*`), `GetLSM` / `ClearLSMCache`, and the class-color-aware color getters (`GetBarColor` / `GetBgColor` / `GetBorderColor`) that re-read `useClassColor*` at call time. `GetPlayerClassColor` / `GetBgClassColor` are the upvalue resolvers. |
| 7 | `core/Database.lua` | 61 | `NS:InitDB()` — creates the AceDB `"AbsorbTrackerDB"` from `NS.defaults`, registers `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` → `NS.OnProfileChanged` (guarded for the headless AceDB mock), and installs the no-AceDB fallback shim. `NS:RunMigrations()` — idempotent, reads/writes `db.global.schemaVersion`; its v1 step backfills any missing profile key from `flatDefaults` (deep-copying table defaults), absorbing the old inline flat→profile migration; its v2 step drops the dead `profile.updateInterval` key now that repaints are event-driven (`throttleWindow` is already seeded by the v1 backfill). See [data-flow.md](./data-flow.md). |
| 8 | `core/LSMPatch.lua` | 50 | Third-party-lib fixup. `NS.ApplyLSMBorderPatch()` (called once on enable) wraps the currently-registered `LSM30_Border` constructor at `currentVer + 1` via `AceGUI:RegisterWidgetType`, hides upstream's 42×42 `displayButton` preview tile, and re-anchors `frame.label` and `frame.DLeft` to the frame's left edge so the closed dropdown sits flush with neighbouring sliders/checkboxes. No-ops cleanly when AceGUI / the widget isn't loaded. |
| 9 | `core/DebugLog.lua` | 280 | The on-screen debug console (Ka0s §12). Builds a movable `ScrollingMessageFrame` window (`AbsorbTrackerDebugWindow`, registered with `UISpecialFrames`) rendered in the vendored monospace font, plus a Copy window (read-through `EditBox`) and Clear. Pure `FormatPlain` / `FormatColored` line formatters; `D:SetEnabled` is the single seam the slash command and the header toggle share — it flips `NS.State.debug`, refreshes the header, prints a **colour-coded** chat ack (ON green `40ff40` / OFF red `ff4040`, debug-logging §5), brackets the console with `[Debug] logging enabled`/`disabled`, and **on enable** appends an `[Init]` session summary (name + version, schema version, active profile). `NS.Debug(tag, fmt, ...)` is the global sink — zero-alloc no-op when `NS.State.debug` is off. |
| 10 | `core/AbsorbTracker.lua` | 154 | AceAddon lifecycle. Promotes `NS` via `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")` and stashes the object as `NS.addon`. `OnInitialize` (ADDON_LOADED) registers the LSM monospace font, calls `NS:InitDB()`, and `NS.Slash:Register()`. `OnEnable` (PLAYER_LOGIN timing) reproduces the old bootstrap in order (ClearLSMCache → GetLSM → ApplyLSMBorderPatch → RestoreBarPosition → UpdateBarAppearance → UpdateAbsorbBar), registers `UNIT_ABSORB_AMOUNT_CHANGED`/`UNIT_MAXHEALTH` on a private `RegisterUnitEvent(event, "player")` frame (a documented §9.1 deviation — C-level unit filter, since AceEvent-3.0 shares one frame and cannot `RegisterUnitEvent`) and `PLAYER_ENTERING_WORLD`/`PLAYER_REGEN_DISABLED`/`PLAYER_REGEN_ENABLED` via AceEvent, then `NS.CreateOptionsPanel()` (no `[Init]` boot line here — the debug flag is off at login, so per debug-logging §5 the session summary is emitted from `DebugLog:SetEnabled` on enable). Debug coverage (§8) + coalescing (§9): `OnEnterWorld` logs `[World]`; `OnAbsorbChanged` no longer logs per event — it bumps a debug-gated `dbgAbsorbEvents` counter and logs a non-secret `[Absorb]` shield-up/shield-gone transition only when `NS.IsConcatSafe` says the value isn't a combat secret, then calls `NS.RequestRepaint()`; `OnMaxHealthChanged` (absorb is shown as a fraction of max health) calls `NS.RequestRepaint()` with no debug line; `OnEnterCombat` resets the per-combat counters and logs `[Combat] entered`; `OnLeaveCombat` (sole handler of `PLAYER_REGEN_ENABLED`) applies visibility + repaints, then flushes one `[Combat] left: N events, M repaints` rollup, appending `final=<value>` only when the post-combat read is concat-safe (the value is a secret while `InCombatLockdown()` still lags) — no deferred `/at config` to replay (options-ui-§2); `NS.OnProfileChanged` logs `[Profile]`, repaints directly, and refreshes an open panel. `NS.NoteRepaint()` is defined here (module-local counters `dbgAbsorbEvents`/`dbgRepaints`/`dbgLastAbsorb`) and called by `modules/Display.lua`'s `UpdateAbsorbBar`. |

## defaults/

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 11 | `defaults/Profile.lua` | 39 | AceDB-shaped defaults. `NS.defaults.profile` (all per-bar appearance/position keys, incl. `throttleWindow = 0.1` and `showOnlyInCombat = false`), `NS.defaults.global` (`schemaVersion = 1`, the migration stamp — the live DB is migrated to `2` by `NS:RunMigrations`), and `NS.flatDefaults` — a flat alias to `defaults.profile` read by `GetSetting` on the no-AceDB path and by the Options pages for per-key defaults. |

## locales/

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 12 | `locales/enUS.lua` | 12 | Canonical locale. Sets `NS.L = setmetatable({}, { __index = function(_, k) return k end })` so a missing key returns itself and never errors. English-only in v1.9.0 — the seam is in place, but no user-facing string is wrapped yet. |

## modules/ — the bar runtime

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 13 | `modules/Bar.lua` | 55 | Bar-frame creation at file-load time (from `flatDefaults`, before the DB is ready). Creates `AbsorbTrackerFrame` (outer movable `BackdropTemplate`, exported as `NS.bar`), the child `statusBar` (`NS.statusBar`), and `valueText` (`NS.valueText`), plus the reusable `NS.backdropInfo` table. The drag handler writes the new `position` via `NS.SetSetting`. |
| 14 | `modules/Display.lua` | 107 | `RestoreBarPosition` (re-applies the saved `position` or centers), `UpdateBarAppearance` (re-applies *every* visual setting; `SetBackdrop(nil)` first to force refresh; ends with `NS.ApplyVisibility()`), `NS.ShouldShowBar()` / `NS.ApplyVisibility()` (composes the `hidden` master toggle with the `showOnlyInCombat` + `UnitAffectingCombat("player")` gate — actual player combat, not `InCombatLockdown()`, which lags `PLAYER_REGEN_DISABLED`; see [midnight-quirks.md](./midnight-quirks.md) — shows/hides `NS.bar`, and logs a `[Bar]` shown/hidden transition line only when the applied visibility actually changes), `UpdateAbsorbBar` (reads `UnitGetTotalAbsorbs` / `UnitHealthMax`, formats with `AbbreviateNumbers` — never through `tonumber`; early-returns when `NS.ShouldShowBar()` is false; early-outs while `NS.testHoldUntil` is in the future so a `/at test` paint survives the next tick; calls `NS.NoteRepaint()` on every actual repaint instead of logging a per-tick debug line — the repaint count is coalesced into the `core/AbsorbTracker.lua` `[Combat]` rollup). |
| 15 | `modules/Timer.lua` | 26 | Coalescing repaint scheduler via AceTimer. `NS.RequestRepaint()` is a trailing-edge one-shot throttle: a repaint already pending coalesces (no-op); otherwise `NS.addon:ScheduleTimer(doRepaint, throttleWindow)` schedules `NS.UpdateAbsorbBar`, self-clearing (`pending = nil`) inside the callback. The `doRepaint` callback is hoisted to module scope (reused, not re-allocated per arm). No polling fallback; idle = zero repaints. |

## settings/ — settings-panel toolkit

The `settings/` slices decorate the same `NS.Helpers` table that `settings/Panel.lua` publishes empty. `Schema` / `Slash` / `Panel` load first, then the toolkit slices (`Helpers` / `ScrollPatch` / `Widgets` / `About`) before any `settings/<page>.lua` that consumes them.

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 16 | `settings/Schema.lua` | 269 | The schema registry. `RegisterSchemaRows(rows)` (append), `FindSchemaRow(path)` / `SchemaForPage(pageKey)` (lookup; group-stable sort by first-seen registration index, then `row.order`), `SetByPath(path, value)` — the single write seam (`SetSetting` + `fireOnChange`), logging one `[Set] path = value` debug line per write (§10) — and `ApplyDefault(row)` (deep-copies table defaults). `FormatSchemaValue` / `ParseSchemaValue` (slash IO). `ValidateSchema()` returns THREE values (`errors, resolved, missing`) and additionally checks that every non-Profiles `row.path` resolves against `NS.defaults.profile`, printing on a miss. See [schema.md](./schema.md). |
| 17 | `settings/Slash.lua` | 371 | AceConsole slash dispatcher (no `SLASH_*` globals). `NS.COMMANDS` is the ordered `{name, desc, fn}` table of 15 verbs (`help`, `config`, `list`, `get`, `set`, `reset`, `resetall`, `resetposition`, `lock`, `unlock`, `toggle`, `debug`, `update`, `test`, `profile`); `NS.SlashCommands` is an alias the About page renders. `Sl:Register()` binds `/at` and `/absorbtracker` via `NS.addon:RegisterChatCommand`. `list`/`get`/`set`/`reset` walk `NS.Schema`; an unknown verb prints `unknown command '<verb>'` then help. |
| 18 | `settings/Panel.lua` | 132 | Settings UI registration shell. Publishes empty `NS.Helpers` for the toolkit slices to decorate, sets `NS.PARENT_TITLE`, owns the `pendingPages` queue. `RegisterOptionsPage(key, name, builder)` appends to it; `CreateOptionsPanel()` (enable-time drain) stashes `NS.AceGUI` once, runs `ValidateSchema`, registers the top-level canvas via `Helpers.CreatePanel`, defers `Helpers.BuildMainContent` to first OnShow, then runs each queued page builder; `OpenOptionsPanel()` is combat-lockdown gated — in combat it **refuses** (prints a grey `[AT]` notice and logs `[Cfg]` refused, options-ui-§2), never touching the protected category-switch and never deferring, logging `[Cfg]` opened otherwise; `RefreshOptionsPanel()` routes to `Helpers.RefreshAllPanels`. See [settings-panel.md](./settings-panel.md). |
| 19 | `settings/Helpers.lua` | 355 | Layout constants (`PADDING_X` / `HEADER_HEIGHT` / `SECTION_HEADING_H` …) plus the canvas + AceGUI scroll machinery: `Helpers.CreatePanel` (frame factory + unified header + Defaults button), `Helpers.EnsureScroll` (lazy AceGUI ScrollFrame; calls `PatchAlwaysShowScrollbar` once), `Helpers.Section` (Heading), `Helpers.InlineButtonPair`, `Helpers.AttachTooltip`, `Helpers.AddSpacer`, `Helpers.RestoreDefaults` / `RestoreAllDefaults` / `RefreshAllPanels` (panel registry + reset/refresh wiring), `Helpers.LSMValues(mediaType)` (deferred LSM hash factory). |
| 20 | `settings/ScrollPatch.lua` | 127 | `Helpers.PatchAlwaysShowScrollbar(scroll)` — rebinds `FixScroll` / `MoveScroll` / `OnRelease` on a single AceGUI ScrollFrame so the scrollbar (and its 20 px gutter) stays visible across every panel; parks the thumb at the top when there's nothing to scroll, restores originals on `OnRelease`. Called by `Helpers.EnsureScroll`. |
| 21 | `settings/Widgets.lua` | 292 | Schema-row → AceGUI widget translation. `Helpers.RenderField(ctx, row, parent, relativeWidth)` dispatches by `row.type`; the four widget makers (`makeCheckbox` / `makeSlider` / `makeDropdown` / `makeColorPicker`) write via `NS.SetByPath` and register a refresher closure on `ctx.refreshers`. The ColorPicker's drag throttle uses a single re-armed `NS.addon:ScheduleTimer` (AceTimer one-shot) + reused `pendingArgs` table so a sustained drag is O(1) garbage. `Helpers.RenderSchema(ctx, pageKey, afterGroup?)` lays a page's rows into 50/50 flow rows with `Section` headings and `AddSpacer` gutters. |
| 22 | `settings/About.lua` | 104 | `Helpers.BuildMainContent(ctx)` — top-level "Ka0s Absorb Tracker" page builder. Renders the logo TGA, the addon `Notes` one-liner, a "Slash Commands" Heading, and one row per `NS.SlashCommands` entry so the page stays in lockstep with `/at help`. Metadata reads route through `NS.Compat.GetAddOnMetadata`. |

## settings/ — sub-page schemas

Each file (except `Profiles.lua`) registers schema rows for the page, declares a `build(mainCategory)` closure that creates a canvas via `Helpers.CreatePanel`, defers `Helpers.RenderSchema(ctx, pageKey)` to first `OnShow`, and returns `Settings.RegisterCanvasLayoutSubcategory`. Then `RegisterOptionsPage(key, name, build)`.

| # | File | Lines | Schema rows |
|---|------|-------|-------------|
| 23 | `settings/General.lua` | 151 | `hidden` (rendered inverse as "Show Bar"), `showOnlyInCombat` (order 15, label "Show only in combat"; `onChange` calls `NS.ApplyVisibility()`), `locked`, `throttleWindow` (Performance group, `solo`, label "Update throttle (in sec)"). Build closure injects an `InlineButtonPair` ("Reset Position" + "Reset All Settings") under the **Master controls** group via the `afterGroup` callback; defines the `ABSORBTRACKER_RESET_ALL` `StaticPopupDialog` for the destructive confirm. |
| 24 | `settings/Bar.lua` | 145 | `barWidth` / `barHeight` (**Size** pair). The **Bar** section: `barTexture` (solo) above `barColor` paired with `useClassColorBar`. The **Background** section: `bgTexture` (solo) above `bgColor` paired with `useClassColorBg`. The color rows carry `disabledIf = "useClassColorBar"` / `"useClassColorBg"`. LSM dropdowns call `NS.Helpers.LSMValues("statusbar")`. |
| 25 | `settings/Border.lua` | 91 | One section "Border" laid out 2×2: `border` (LSM border style) / `borderSize`; `borderColor` / `useClassColorBorder`. LSM dropdown calls `NS.Helpers.LSMValues("border")`. |
| 26 | `settings/Font.lua` | 96 | One section "Typography": `font` / `fontSize`; `fontFlags` (solo). LSM dropdown calls `NS.Helpers.LSMValues("font")`. |
| 27 | `settings/Profiles.lua` | 70 | Custom canvas with the unified header (no Defaults button), an AceGUI `SimpleGroup` parented to `ctx.body`, and `AceConfigDialog:Open("AbsorbTracker-Profiles", container)` on first `OnShow`. Not schema-driven; AceDBOptions supplies its own options table. `build` returns `nil` (silently skips the page) if AceDBOptions / AceConfigDialog / AceGUI is missing. |

## tests/ — headless harness

Run from the repo root with `lua tests/run.lua`. Loads every addon source file with the `("AbsorbTracker", NS)` calling convention against a WoW-API mock, runs `NS:InitDB()`, then executes the suites. The authoritative per-suite and total case counts live in the generated [test-cases.md](./test-cases.md) (`lua tests/run.lua --list`).

| # | File | Lines | Responsibility |
|---|------|-------|----------------|
| 28 | `tests/run.lua` | 134 | The runner. Builds mocks, loads all source files in TOC order via `loader.lua`, calls `NS:InitDB()`, exposes the tiny `AT_TEST` framework (`test` / `assertEqual` / `assertTrue` / `assertFalse`), `dofile`s the eight suites (stamping each case's `suite`), runs them (or, with `--list`, prints the `docs/test-cases.md` inventory and exits), and exits non-zero on any failure. |
| 29 | `tests/loader.lua` | 33 | Headless file loader. `loadfile` + `setfenv` each chunk into an environment where WoW globals resolve to the mock set (falling back to `_G`); writes land in `_G` so `AbsorbTrackerDB` and `StaticPopupDialogs` behave like the real client. |
| 30 | `tests/wow_mock.lua` | 117 | Minimal WoW-API mock builder — a fresh, isolated environment per run. Universal frame stub (any PascalCase method is a self-returning no-op) plus the specific globals the addon touches at load/test time, including `__timers` / `__fireTimers()` for driving `NS.addon:ScheduleTimer` deterministically. |
| 31 | `tests/test_schema.lua` | 91 | schema registry, group-stable sort, `SetByPath`, `ValidateSchema` three-value return / path resolution, format/parse. |
| 32 | `tests/test_database.lua` | 88 | `InitDB`, `RunMigrations` idempotency + `flatDefaults` backfill, deep-copy isolation, `schemaVersion` v1→v2 migration (drops `updateInterval`, seeds `throttleWindow`). |
| 33 | `tests/test_compat.lua` | 33 | `Compat.GetAddOnMetadata` C_AddOns path, `_G` fallback, and `nil` degradation. |
| 34 | `tests/test_util.lua` | 55 | `NS.Print` / `NS.Debug` (secret-safe sink) routing and gating, `NS.SafeToString` secret-value handling. |
| 35 | `tests/test_debuglog.lua` | 109 | `FormatPlain` / `FormatColored` formatters, `NS.Debug` gating, buffer cap, and the `SetEnabled` seam (colour-coded ON/OFF chat ack, `[Debug]` brackets, and the `[Init]` session summary on enable). |
| 36 | `tests/test_slash.lua` | 130 | `NS.COMMANDS` verb table, dispatch, unknown-verb handling, `OpenOptionsPanel` `[Cfg]` refusal logging, `SetByPath` `[Set]` logging (§10). |
| 37 | `tests/test_timer.lua` | 69 | `NS.RequestRepaint` coalescing + `throttleWindow` delay, `OnAbsorbChanged` / `OnMaxHealthChanged` player-only + `OnEnterWorld` repaint wiring. |
| 38 | `tests/test_visibility.lua` | 170 | `ShouldShowBar` truth table (incl. the lockdown-lags-combat regression) + combat-handler wiring, `[Combat]` rollup coalescing, per-event `[Absorb]` transition logging on non-secret values. |

## Bundled libraries (libs/)

Folder-per-lib, loaded before any addon source via the `#@no-lib-strip@` block at the top of the TOC.

| Path | Purpose |
|------|---------|
| `libs/LibStub/` | Library loader. |
| `libs/CallbackHandler-1.0/` | Event callback transport for the Ace3 stack. |
| `libs/AceAddon-3.0/` | Addon lifecycle carrier. `NewAddon(NS, …)` promotes `NS` and stamps the AceEvent / AceTimer / AceConsole mixins onto `NS.addon`. |
| `libs/AceEvent-3.0/` | `self:RegisterEvent` event handling (global/lifecycle events). The two `UNIT_*` events use a private `RegisterUnitEvent` frame instead — AceEvent-3.0 shares one frame and cannot unit-filter (documented §9.1 deviation). |
| `libs/AceTimer-3.0/` | `ScheduleTimer` / `CancelTimer` — drives the coalescing repaint throttle (`NS.RequestRepaint`) and the color-picker drag throttle (replaces `C_Timer`). |
| `libs/AceConsole-3.0/` | `RegisterChatCommand` for `/at` and `/absorbtracker` (replaces hand-rolled `SLASH_*` globals). |
| `libs/AceDB-3.0/` | Profile management. Optional dep — addon falls back to a flat `AbsorbTrackerDB` shim when missing. |
| `libs/AceGUI-3.0/` | Widget framework used by the canvas-layout panel and AceConfigDialog. |
| `libs/AceConfig-3.0/` | Pulls in AceConfigRegistry / AceConfigCmd / AceConfigDialog. Required by the Profiles sub-page. |
| `libs/AceDBOptions-3.0/` | Builds the Profiles sub-page options table. |
| `libs/LibSharedMedia-3.0/` | Texture / font / border registry. Optional dep — addon falls back to `FALLBACK_*` Blizzard constants in `core/Data.lua` / `core/Constants.lua` when missing. |
| `libs/AceGUI-3.0-SharedMediaWidgets/` | Canonical upstream `AceGUI-3.0-SharedMediaWidgets` r65. Multi-file lib loaded via `widget.xml` — `prototypes.lua` (base-frame helpers) plus per-mediatype widget files for `LSM30_Statusbar` / `LSM30_Border` / `LSM30_Background` / `LSM30_Font` / `LSM30_Sound`. The addon references statusbar / border / font; the rest ship because the lib is monolithic. The 42×42 displayButton tile on `LSM30_Border` is suppressed by addon-side `core/LSMPatch.lua`. |

## Shared infrastructure

- `AbsorbTracker.toc` — Interface line (`120007`), `## Version:`, SavedVariables (`AbsorbTrackerDB`), modular file load order (Libraries → Core → Defaults → Locales → Modules → Settings). Order is dependency order, not alphabetical.
- `media/` — bundled assets in typed subfolders: `media/logos/absorbracker.logo.v2.tga` (`NS.Constants.LOGO_PATH`) and `media/fonts/JetBrainsMono-Regular.ttf` (+ `OFL.txt`, `NS.Constants.FONT_MONO`).
- `.gitattributes` — enforces CRLF on `*.lua` / `*.toc` / `*.xml` / `*.md` (`* text=auto eol=crlf` plus explicit per-extension lines).
- `LICENSE` — MIT.

## Top-level docs

- `README.md` — user-facing.
- `CLAUDE.md` — engineer working-notes stub (hard rules + response style + doc index); the full agent brief is `docs/agent-context.md`.
- `docs/ARCHITECTURE.md` — subsystems-at-a-glance + invariants + doc index.
- `docs/agent-context.md` — the full agent brief.
- `docs/*.md` — topic chunks (this file is one of them).
