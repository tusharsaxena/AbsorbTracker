# 01 — Current State

**Addon:** Ka0s Absorb Tracker (`AbsorbTracker`)
**Audit date:** 2026-07-12
**Deviation prefix:** `AT-`
**Standard audited against:** Ka0s WoW Addon Standard **v1.0.0 (2026-07-12)** — `standards/01_STANDARD.md` @ `github.com/tusharsaxena/WowAddonStandards` (master).
**Playbook:** `AUDIT.md` @ same repo (76-line revision fetched 2026-07-12).
**Run type:** First audit for this addon. No prior `audit/` folder existed; `AT-*` IDs are assigned fresh here and are stable for future runs.

This is a **read-only** snapshot. No addon source was modified.

---

## What the addon is

A single movable **absorb status bar** for the player. It renders `UnitGetTotalAbsorbs("player")` into one `StatusBar` inside a backdrop frame, with independently configurable bar size, fill texture/color, background texture/color, border style/size/color, and font face/size/outline — all LibSharedMedia-backed. Bar/background/border each carry an opt-in class-color override. Position is saved per profile. Retail Midnight only (`## Interface: 120007`). English only.

---

## Section-by-section snapshot (cited)

### §1 Layout / tier
- **20 source `.lua` files** (excluding `libs/`, `media/`, `docs/`): 11 at root (`Core.lua`, `Utils.lua`, `LSMPatch.lua`, `Settings.lua`, `Schema.lua`, `UI.lua`, `Display.lua`, `Timer.lua`, `Events.lua`, `SlashCommands.lua`, `OptionsPanel.lua`), 5 under `Options/`, 4 under `Panel/`. `AbsorbTracker.toc:26-45`.
- Source count > 8 ⇒ Tier-2 territory, but the layout is a **flat root + two PascalCase subfolders** (`Options/`, `Panel/`), not the Tier-2 canonical `core/ defaults/ settings/ locales/ modules/` tree (§1.2). No tier is declared in `CLAUDE.md`.
- `media/` holds five files all under `media/screenshots/`, including the runtime logo `absorbracker.logo.v2.tga` and source art — no `media/logos/` (§1.4).

### §2 TOC (`AbsorbTracker.toc`)
- Metadata block `:1-11`. `## Interface: 120007` single value (compliant, §2.3). `## Title: Ka0s Absorb Tracker` (compliant). `## iconTexture: 512902` — **wrong case** (`:6`; standard field is `IconTexture`). **Missing** `## X-Standard:`, `## X-Curse-Project-ID:`, `## X-Wago-ID:` despite the addon being published (CurseForge project `1450165`, README badge; git tags `1.0.0-release`…`1.8.0-release`).
- `## OptionalDeps: LibStub, CallbackHandler-1.0, Ace3, LibSharedMedia-3.0` `:8` — no hard `Dependencies` (compliant, §2.1).
- File listing `:13-45` uses packager `#@no-lib-strip@` guards and a flat, **unsectioned** file list — no `# Libraries / # Locales / # Core / # Defaults / # Modules / # Settings` headers (§2.5).
- No `schemaVersion` anywhere; the only migration is an ad-hoc flat→profile copy in `Events.lua:51-64`. No `Database.lua`.

### §3 Library stack
- Vendored under `libs/`: `Ace3/` (AceAddon, AceDB, AceGUI, AceConfig, AceDBOptions, AceGUI-3.0-SharedMediaWidgets), `CallbackHandler-1.0/`, `LibSharedMedia-3.0/`, `LibStub-1.0/`.
- **Not vendored:** AceEvent-3.0, AceTimer-3.0, AceConsole-3.0 (all mandatory, §3.1). The addon instead hand-rolls events (`Events.lua:29`, `LSMPatch.lua:25`), timers (`Timer.lua:29` `C_Timer.NewTicker`), and slash (`SlashCommands.lua:334`).
- Folder layout is non-standard: `libs/LibStub-1.0/` (should be `libs/LibStub/`) and Ace3 libs nested under `libs/Ace3/AceX/` instead of folder-per-lib at the `libs/` root (§3.3).
- `LibStub("AceGUI-3.0")` is re-fetched inside many builders (`Panel/Helpers.lua:101,146,209,249,275`, `Panel/About.lua:31,41`) rather than stashed once (§3.4). LSM is correctly cached once (`Settings.lua:18-24`).

### §4 Architecture
- Every file starts `local AddonName, AddonTable = ...` (e.g. `Core.lua:2`) — a private shared table (good: no `_G[addonName]`), but named `AddonTable`, not the standard `NS`, and header is not the prescribed `local addonName, NS = ...` (§4.1).
- **No AceAddon registration.** AceDB is created via bare `LibStub("AceDB-3.0", true)` in the `PLAYER_LOGIN` handler (`Events.lua:37-44`); AceAddon is vendored but unused as a lifecycle (§4.2).
- **Schema-as-single-source is implemented well** (§4.5, a strength): `AddonTable.Schema` flat array (`Schema.lua:37`), `RegisterSchemaRows` (`Schema.lua:45`), one write seam `SetByPath` → validate/write/onChange (`Schema.lua:101`), and a boot-time `ValidateSchema` (`Schema.lua:182`, called `OptionsPanel.lua:113`). The validator checks `path`/`page`/`type` shape but **does not** verify each `path` resolves against the defaults table (§4.5 last bullet).

### §5 SavedVariables / AceDB
- Single global `AbsorbTrackerDB` (`AbsorbTracker.toc:7`), AceDB profile scope with a flat-table fallback shim when AceDB is absent (`Events.lua:37-65`) — the soft-fallback pattern §5.1 praises. Defaults live in `Core.lua:10-32` (a Tier-1 shape; a Tier-2 addon would use `defaults/Profile.lua`).
- **No `schemaVersion`, no migration runner** (§5.1 MUST).

### §6 Options UI — **strong compliance area**
- `Settings.RegisterCanvasLayoutCategory` landing page + `RegisterCanvasLayoutSubcategory` subpages (`OptionsPanel.lua:100`, `Options/*.lua`); eager registration at `PLAYER_LOGIN` via `CreateOptionsPanel` (`Events.lua:74`), lazy body on first `OnShow` (`OptionsPanel.lua:92`, each `Options/*.lua` `OnShow`). Raw AceGUI content, no AceConfigDialog for content (§6.1). Combat gate on open (`OptionsPanel.lua:150-154`, §6.2). Landing page renders logo + notes tagline + "Slash Commands" heading + one row per command (`Panel/About.lua:40-108`, §6.5). Header constants match §6.8 (`Panel/Helpers.lua:26-45`). Always-visible scrollbar patch (`Panel/ScrollPatch.lua`, §6.10). Profiles subpage via AceDBOptions+AceConfigDialog (`Options/Profiles.lua`, the one sanctioned AceConfig use, §6.3).
- Gap: the landing logo is loaded from `media\screenshots\absorbracker.logo.v2.tga` (`Panel/About.lua:19`), not `media/logos/` (§6.5/§1.4).

### §6B Preview / test mode
- `/at test [value] [hold]` paints a placeholder through the live render path with a hold window (`SlashCommands.lua:234-252`, `Display.lua:87-90`) — satisfies §6B intent.

### §7 Slash commands
- Ordered `AddonTable.SlashCommands` command table (`SlashCommands.lua:29-75`); help generated from it (`SlashCommands.lua:97-103`); schema-driven `list/get/set/reset/resetall` (`SlashCommands.lua:113-218`); unknown verb prints error + help (`SlashCommands.lua:353-354`); verb lowercased, remainder case-preserved (`SlashCommands.lua:343-345`). All good.
- **Registered via `SLASH_ABSORBTRACKER1/2` globals + `SlashCmdList`** (`SlashCommands.lua:334-337`), not AceConsole `:RegisterChatCommand` (§7.1, anti-pattern #5).
- Chat tag `|cFF00FFFF[AT]|r` is centralized through `AddonTable.Print` (`Utils.lua:8-11`) but defined as a `local PREFIX`, not exposed as a shared `NS.PREFIX` constant (§7.4).

### §8 Localization
- **No locale module.** No `NS.L`, no metatable-fallback table, no `locales/enUS.lua`. All user strings are inline literals (e.g. `SlashCommands.lua`, `Options/*.lua`, `Panel/*.lua`). §8 MUST ship at least `enUS.lua`.

### §9 Events / frames / taint
- Raw `CreateFrame("Frame")` event frames (`Events.lua:29-33`, `LSMPatch.lua:25-27`) instead of AceEvent-3.0 (§9.1). Frames are created in Lua, not XML (good for Tier-1, §9.6). Combat-lockdown gate present on options open (§9.2). Custom AceGUI widget extension is done correctly via `RegisterWidgetType` (`LSMPatch.lua:39`, §3.5).

### §11 Compat
- **No `Compat.lua`.** The one deprecated-API fallback (`GetAddOnMetadata` → `C_AddOns.GetAddOnMetadata`) is duplicated inline in `SlashCommands.lua:87-95` and `Panel/About.lua:21-28` instead of a single shim (§11).

### §12 Debug / logging
- Debug routes to the **chat frame** via `AddonTable.DebugPrint` (`Utils.lua:17-21`); toggled by `/at debug` (`SlashCommands.lua:224-227`). Flag is session-only (`Utils.lua:5`, not in SV) — matches §12.5. No dedicated on-screen debug console (§12, anti-pattern #18 for windowed addons).

### §13 Packaging
- **No `.pkgmeta`** at root (§13 MUST).

### §14 Lint
- **No `.luacheckrc`** at root (§14 MUST).

### §14A Tests
- **No `tests/` directory / harness at all** (§14A MUST, anti-pattern #24). Validation is manual only (`docs/smoke-tests.md`).

### §15 Docs
- Root ships `README.md`, `CLAUDE.md`, `LICENSE`, **and** `ARCHITECTURE.md`. `CLAUDE.md` is a **full agent brief** (~200 lines of working notes), not a stub (§15.2, anti-pattern #26). `ARCHITECTURE.md` sits at root, not `docs/` (§15). `docs/` is otherwise rich (module-map, schema, data-flow, profiles, midnight-quirks, smoke-tests, etc.). No `TODO.md` (compliant, §15.4).
- README (`README.md`) has H1, WoW badge, CurseForge-version badge, license badge, logo, Screenshots, Usage (slash + settings tables), FAQ, Troubleshooting, Issues, Version History. **Missing** `## Testing` (§15.1 #11 MUST), an **X-Standard** badge/link, and a **Wago** badge; and inserts non-canonical sections ("## Critical settings", "## Optional dependencies") that break the canonical order (§15.1, anti-pattern #28).

### §17 Versioning / git
- Semver in TOC (`## Version: 1.8.0`) and README Version History; per-release git tags exist. Commit gate (green tests + clean lint) is unmet because neither tests nor lint config exist (see §14/§14A).

---

## Compliance strengths (carry forward)
- Schema-as-single-source (§4.5) — well implemented, drives panel + slash + reset.
- Options panel structure, constants, lazy body, combat gate, always-show scrollbar (§6) — closely matches the standard.
- AceDB-missing and LSM-missing soft fallbacks (§2.1, §5.1).
- `RegisterWidgetType` extension rather than forking AceGUI (§3.5).
- Session-only debug flag (§12.5), preview/test mode (§6B), single `<Addon>DB` SV (§2.2).
