# Scope

What's in scope, what's out, and the resolved decisions that shaped the contract. The contract itself (bar behavior, slash UX, settings panel) is documented in [README.md](../README.md) — this doc records the *boundary* decisions so a fresh contributor can tell whether a feature request is in or out of scope without re-litigating it.

## In scope

- **A single movable absorb status bar** for the player, displaying the total of all active absorb shields as one combined value.
- **LibSharedMedia-backed media** for fill texture, background texture, border style, and font. Each is independently configurable.
- **Independent class-color overrides** on bar fill, background, and border via three separate `useClassColor*` toggles.
- **AceDB-3.0 profile management** with a Profiles sub-page exposed under Blizzard Settings.
- **Per-profile saved bar position** (the bar is unlocked by default — `flatDefaults.locked = false`; drag to position, `/at lock` to fix once placed).
- **Five-page Blizzard Settings panel** (General, Bar, Border, Font, Profiles) plus a matching `/at` slash CLI for every panel-shaped operation via `/at list / get / set / reset / resetall`.
- **Cyan `[AT]` chat prefix** on all addon output.
- **Retail Midnight only** (Interface 120007). English only.

## Out of scope

These have been considered and explicitly declined. A change of heart needs an issue + design discussion, not a stealth PR.

- **Per-aura breakdown.** The bar shows the *sum* of all absorbs from `UnitGetTotalAbsorbs("player")`. No segmented display, no per-aura list, no tooltips listing contributing buffs.
- **Separate bars for individual shield sources** (Power Word: Shield vs. Ice Barrier vs. trinket procs). One combined bar, by design.
- **Group / raid / target absorb tracking.** Player only. The unit is hard-coded to `"player"` in `modules/Display.lua`.
- **Aura whitelist / blacklist** to filter which absorbs count. The bar always reflects the engine's total.
- **Localization plumbing.** English only. `locales/enUS.lua` installs an identity `NS.L` (`setmetatable({}, {__index = function(_, k) return k end})`); nothing is wrapped yet. Slash commands, chat strings, and setting names are English. The bar value is purely numeric so the in-game display itself is locale-neutral.
- **LDB / minimap icon.** The settings panel and slash commands are the entry points.
- **Drag-and-drop reorderable settings panel.** Page order is fixed.
- **Profile import / export.** AceDB profiles persist in `AbsorbTrackerDB`; no serialization layer.
- **Auto-detect class color.** Class-color overrides are explicit opt-in toggles per surface (bar / bg / border). No "always use class color" master switch.
- **OO framework / `:NewModule()` runtime.** Plain-Lua modules attached to a shared `NS`. AceAddon carries the AceEvent / AceTimer / AceConsole mixins and the AceDB database (`NS.addon = LibStub("AceAddon-3.0"):NewAddon(NS, addonName, ...)`), but there is no per-module class hierarchy.

## Resolved decisions

Decisions made during requirements review and earlier releases — these are settled, not open.

- **Position is per-profile.** Same profile across multiple characters means the bar lands in the same place; per-character divergence requires a per-character profile in the Profiles panel.
- **Class colors are opt-in toggles, not auto-detect.** Three independent toggles (`useClassColorBar` / `useClassColorBg` / `useClassColorBorder`) drive whether each surface uses a class color instead of the configured RGB. The matching color picker greys out when the toggle is on.
- **Background class color is darkened.** Bar / border use `C_ClassColor.GetClassColor()` directly; the background uses a hard-coded per-class table multiplied by `0.2` so the absorb fill stays readable against it.
- **Color getters resolve at call time.** `GetBarColor` / `GetBgColor` / `GetBorderColor` (in `core/Data.lua`) re-read the toggle on every paint. Class change / respec / profile switch all "just work" without explicit refresh logic.
- **Secret-value handling.** `UnitGetTotalAbsorbs` may return WoW's opaque-token "secret" value for very large numbers. `AbbreviateNumbers()` is the only sanctioned formatter — `tonumber()` would lose precision and produce wrong text.
- **Repaints are event-driven, throttled, and coalescing — not a poll.** `UNIT_ABSORB_AMOUNT_CHANGED` / `UNIT_MAXHEALTH` / `PLAYER_ENTERING_WORLD` all call `NS.RequestRepaint()`. `modules/Timer.lua` implements it as a trailing-edge one-shot AceTimer (`NS.addon:ScheduleTimer`, delay = `throttleWindow`, default 0.1s): a repaint already pending coalesces further requests into it (no-op), so a ~Hz event burst during combat produces at most one repaint per `throttleWindow`. Idle = zero repaints; there is no repeating ticker.
- **Backdrop refresh requires double-set.** `SetBackdrop(nil)` before `SetBackdrop(info)` to force a visual update — passing the same table identity is a Blizzard no-op even if its fields changed.
- **Combat lockdown gate on `/at config`.** `Settings.OpenToCategory` is protected; opening any settings subcategory during combat would taint the panel. `NS.OpenOptionsPanel` early-returns with a chat notice while `InCombatLockdown()` is true.
- **Visibility is two composing inputs, master wins.** `NS.ShouldShowBar()` composes the master `hidden` toggle with the `showOnlyInCombat` gate: `hidden == true` always hides the bar regardless of combat state; otherwise, when `showOnlyInCombat` is on, the bar shows only while `UnitAffectingCombat("player")` is true (actual player combat — **not** `InCombatLockdown()`, which lags the `PLAYER_REGEN_DISABLED` edge; see [midnight-quirks.md](./midnight-quirks.md)). `NS.ApplyVisibility()` applies the result. `UpdateBarAppearance` and `UpdateAbsorbBar` route every paint through these two functions rather than reading `hidden` directly.
- **Schema is the single source of truth.** Adding a new option = one row in some `settings/<page>.lua` via `RegisterSchemaRows`. The widget AND the `/at set <path>` CLI are wired automatically. Per-setting subcommands like `/at width 250` were removed in favor of `/at set barWidth 250`.
- **Cyan `[AT]` chat prefix.** All addon chat output goes through `NS.Print` (in `core/Util.lua`, which prepends `|cFF00FFFF[AT]|r`). Files that emit chat shadow the global `print` with `local print = NS.Print` so existing call sites stay unchanged. No raw `print(...)` calls.
- **Debug output is an on-screen console, not chat.** `NS.DebugPrint` / `NS.Debug` route to `core/DebugLog.lua`'s `ScrollingMessageFrame` (vendored monospace `media/fonts/JetBrainsMono-Regular.ttf`), never the chat frame. Debug is session-only via `NS.State.debug` — never persisted, resets each reload; `/at debug` toggles the window, `/at debug on|off` sets the flag. The old persistent `NS.DEBUG` bool is gone.
- **Deprecated APIs are quarantined.** `core/Compat.lua` is the only file that touches deprecated APIs; `Compat.GetAddOnMetadata` wraps `C_AddOns.GetAddOnMetadata` with a `_G.GetAddOnMetadata` fallback. `settings/About.lua` and `settings/Slash.lua` route through it.
- **Parent canvas hosts an about page; sub-pages hold every setting.** The "Ka0s Absorb Tracker" parent renders a logo + the TOC `Notes` blurb + the slash-command list. The five sub-pages (General / Bar / Border / Font / Profiles) hold every user setting; the parent never holds settings of its own.

## Testing posture

- **A headless test harness exists** at `tests/` (`run.lua`, `loader.lua`, `wow_mock.lua` plus `test_schema` / `test_database` / `test_compat` / `test_util` / `test_debuglog` / `test_slash` / `test_timer` / `test_visibility`). It runs outside WoW against a mock and is the green gate together with `luacheck .` (0/0) and `luac -p`. Any claim that "there are no automated tests" is stale.
- **In-game smoke tests remain the manual layer.** The harness cannot exercise real frames, protected APIs, or the live absorb engine; [docs/smoke-tests.md](./smoke-tests.md) is still the manual QA recipe run before a release.

## Where the contract lives

- User-facing behavior: [README.md](../README.md) — slash commands, settings panel, FAQ, troubleshooting.
- Engineer working notes: [../CLAUDE.md](../CLAUDE.md) — stub pointing at the full brief; [agent-context.md](./agent-context.md) is the full agent brief.
- Big-picture map: [./ARCHITECTURE.md](./ARCHITECTURE.md) — subsystems + invariants + doc index.
- Topic chunks: `docs/*.md` (this file is one of them).
