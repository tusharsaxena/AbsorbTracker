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
- **Group / raid / target absorb tracking.** Player only. The unit is hard-coded to `"player"` in `Display.lua`.
- **Aura whitelist / blacklist** to filter which absorbs count. The bar always reflects the engine's total.
- **Localization plumbing.** English only — slash commands are English, all chat strings are English. Setting names are English. The bar value is purely numeric so the in-game display itself is locale-neutral.
- **LDB / minimap icon.** The settings panel and slash commands are the entry points.
- **Drag-and-drop reorderable settings panel.** Page order is fixed.
- **Profile import / export.** AceDB profiles persist in `AbsorbTrackerDB`; no serialization layer.
- **Auto-detect class color.** Class-color overrides are explicit opt-in toggles per surface (bar / bg / border). No "always use class color" master switch.
- **OO framework / `:NewModule()` runtime.** Plain-Lua modules attached to a shared `NS`. AceAddon is bundled but only used as the AceDB carrier.

## Resolved decisions

Decisions made during requirements review and earlier releases — these are settled, not open.

- **Position is per-profile.** Same profile across multiple characters means the bar lands in the same place; per-character divergence requires a per-character profile in the Profiles panel.
- **Class colors are opt-in toggles, not auto-detect.** Three independent toggles (`useClassColorBar` / `useClassColorBg` / `useClassColorBorder`) drive whether each surface uses a class color instead of the configured RGB. The matching color picker greys out when the toggle is on.
- **Background class color is darkened.** Bar / border use `C_ClassColor.GetClassColor()` directly; the background uses a hard-coded per-class table multiplied by `0.2` so the absorb fill stays readable against it.
- **Color getters resolve at call time.** `GetBarColor` / `GetBgColor` / `GetBorderColor` re-read the toggle on every paint. Class change / respec / profile switch all "just work" without explicit refresh logic.
- **Secret-value handling.** `UnitGetTotalAbsorbs` may return WoW's opaque-token "secret" value for very large numbers. `AbbreviateNumbers()` is the only sanctioned formatter — `tonumber()` would lose precision and produce wrong text.
- **Ticker drives visual updates, not events.** `UNIT_ABSORB_AMOUNT_CHANGED` only logs at debug level; the periodic `C_Timer.NewTicker` is the source of truth for `UpdateAbsorbBar` calls. Decouples the ~Hz event flow from the user-configurable update interval.
- **Backdrop refresh requires double-set.** `SetBackdrop(nil)` before `SetBackdrop(info)` to force a visual update — passing the same table identity is a Blizzard no-op even if its fields changed.
- **Combat lockdown gate on `/at config`.** `Settings.OpenToCategory` is protected; opening any settings subcategory during combat would taint the panel. `OpenOptionsPanel` early-returns with a chat notice while `InCombatLockdown()` is true.
- **Schema is the single source of truth.** Adding a new option = one row in some `settings/<page>.lua` via `RegisterSchemaRows`. The widget AND the `/at set <path>` CLI are wired automatically. Per-setting subcommands like `/at width 250` were removed in favor of `/at set barWidth 250`.
- **Cyan `[AT]` chat prefix.** All addon chat output goes through `NS.Print` (which prepends `|cFF00FFFF[AT]|r`). Files that emit chat shadow the global `print` with `local print = NS.Print` so existing call sites stay unchanged. No raw `print(...)` calls.
- **Parent canvas hosts an about page; sub-pages hold every setting.** The "Ka0s Absorb Tracker" parent renders a logo + the TOC `Notes` blurb + the slash-command list. The five sub-pages (General / Bar / Border / Font / Profiles) hold every user setting; the parent never holds settings of its own.

## Where the contract lives

- User-facing behavior: [README.md](../README.md) — slash commands, settings panel, FAQ, troubleshooting.
- Engineer working notes: [../CLAUDE.md](../CLAUDE.md) — hard rules + response style + doc index.
- Big-picture map: [./ARCHITECTURE.md](./ARCHITECTURE.md) — subsystems + invariants + doc index.
- Topic chunks: `docs/*.md` (this file is one of them).
