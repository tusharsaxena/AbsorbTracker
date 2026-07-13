# 03 — Evidence

**Addon:** Ka0s Absorb Tracker · **Standard:** v1.0.0 (2026-07-12) · **Run:** 2026-07-12

Every deviation in `02_DEVIATIONS.md` is backed by a `file:line` citation below. Compliance claims that offset a finding are cited too.

---

### AT-01 — §1.2 no Tier-2 layout
- `AbsorbTracker.toc:26-45` — 20 source files listed: 11 flat (`Core.lua`…`OptionsPanel.lua`), 5 `Options\*`, 4 `Panel\*`. Count > 8 mandates Tier 2; no `core/ defaults/ settings/ locales/ modules/` tree exists on disk (root file list).
- `CLAUDE.md` — declares no tier (the standard requires the tier be stated in the CLAUDE stub / docs it points to, §1).

### AT-02 — §1.3 non-canonical PascalCase subfolders
- On disk: `Options/` and `Panel/` (PascalCase). §1.3 requires lowercase subfolders drawn from the canonical set (`core/ modules/ settings/ locales/ defaults/ …`); neither `Options` nor `Panel` is in it.
- `AbsorbTracker.toc:37-45` references `Panel\...` and `Options\...`.

### AT-03 — §1.4 media not typed
- `media/screenshots/absorbracker.logo.v2.tga`, `media/screenshots/absorbracker.logo.v2.jpg`, `media/screenshots/absorbtracker.logo.png` — logo art lives under `screenshots/`, not `media/logos/`. Loader points at it: `Panel/About.lua:19` `LOGO_PATH = [[Interface\AddOns\AbsorbTracker\media\screenshots\absorbracker.logo.v2.tga]]`.

### AT-04 — §2.1 TOC field order/content
- `AbsorbTracker.toc:6` `## iconTexture: 512902` — lowercase `iconTexture` (standard field is `## IconTexture:`).
- `AbsorbTracker.toc:1-11` — no `## X-Standard:` line anywhere in the metadata block.
- `AbsorbTracker.toc:8` `## OptionalDeps: LibStub, CallbackHandler-1.0, Ace3, LibSharedMedia-3.0` — differs from the §2.1 reference ordering.

### AT-05 — §2.1 missing published IDs
- Published: `README.md:4` `![CurseForge Version](https://img.shields.io/curseforge/v/1450165)`; git tags `1.0.0-release … 1.8.0-release`.
- `AbsorbTracker.toc:1-11` — no `## X-Curse-Project-ID:` and no `## X-Wago-ID:`.

### AT-06 — §2.5 file-listing structure
- `AbsorbTracker.toc:13-45` — `#@no-lib-strip@` guard around lib paths, then a bare flat list `Core.lua … Options\Profiles.lua` with **no** `# Libraries / # Locales / # Core / # Defaults / # Modules / # Settings` section comments.

### AT-07 — §2.2/§5.1 no schemaVersion / migration runner
- `Core.lua:10-32` — `AddonTable.defaults.profile` has no `schemaVersion`; there is no `global` table.
- `Events.lua:51-64` — the only migration is an inline flat→profile default backfill; no versioned `RunMigrations`, no `Database.lua` file exists.

### AT-08 — §3.1 mandatory libs missing
- `libs/Ace3/` contains AceAddon, AceDB, AceGUI, AceConfig, AceDBOptions, AceGUI-3.0-SharedMediaWidgets — **no** AceEvent-3.0, AceTimer-3.0, AceConsole-3.0 folders.
- Hand-rolled substitutes: events `Events.lua:29-33`; timer `Timer.lua:29` `C_Timer.NewTicker(...)`; slash `SlashCommands.lua:334-337`.

### AT-09 — §3.3 lib folder layout
- `libs/LibStub-1.0/` (should be `libs/LibStub/`); `AbsorbTracker.toc:14` `libs\LibStub-1.0\LibStub.lua`.
- Ace3 nested: `libs/Ace3/AceAddon-3.0/…`; `AbsorbTracker.toc:16-20` `libs\Ace3\AceAddon-3.0\AceAddon-3.0.xml` etc. §3.3 wants folder-per-lib at the `libs/` root.

### AT-10 — §3.4 repeated LibStub
- `Panel/Helpers.lua:101`, `:146`, `:209`, `:249`, `:275` and `Panel/About.lua:31`, `:41` each call `LibStub("AceGUI-3.0")` at render time rather than reading a stashed reference. (Contrast the correct one-time LSM cache: `Settings.lua:18-24`.)

### AT-11 — §4.1 namespace naming
- `Core.lua:2` `local AddonName, AddonTable = ...` (and identically in every source file). Standard header is `local addonName, NS = ...`. Private table is correct (no `_G[addonName]` assignment anywhere) — only the naming deviates.

### AT-12 — §4.2 no AceAddon registration
- `Events.lua:37-44` — `local AceDB = LibStub("AceDB-3.0", true); AddonTable.db = AceDB:New("AbsorbTrackerDB", defaults, true)` inside a raw `OnEvent`. No `AceAddon:NewAddon(...)` call exists in the codebase; AceAddon is vendored but only pulled transitively.

### AT-13 — §4.5 boot validation gap
- `Schema.lua:182-207` `ValidateSchema` checks `row.path` non-empty, `row.page` in `_validPages`, `row.type` in `_validTypes` — but never resolves `row.path` against `AddonTable.defaults.profile`. (Strength for context: single write seam `Schema.lua:101-105` `SetByPath`, called by panel and slash.)

### AT-14 — §7.1 SLASH_* globals
- `SlashCommands.lua:334-337` — `SLASH_ABSORBTRACKER1 = "/absorbtracker"`, `SLASH_ABSORBTRACKER2 = "/at"`, `SlashCmdList["ABSORBTRACKER"] = function(msg) …`. No `:RegisterChatCommand`. (Dispatch itself is schema/COMMANDS-driven and compliant: `SlashCommands.lua:29-75, 350-354`.)

### AT-15 — §7.4 prefix not shared constant
- `Utils.lua:8` `local PREFIX = "|cFF00FFFF[AT]|r"` — file-local, exposed only indirectly through `AddonTable.Print` (`Utils.lua:9-11`). No `AddonTable.PREFIX`/`NS.PREFIX`.

### AT-16 — §8 no locale module
- No `locales/` directory; no `NS.L` / `AddonTable.L` assignment anywhere. User-facing strings are inline literals, e.g. `SlashCommands.lua:30-74` (command descriptions), `Options/General.lua:69` (StaticPopup text), `Options/Bar.lua:25,48` (labels/tooltips).

### AT-17 — §9.1 raw event frames
- `Events.lua:29-33` `local eventFrame = CreateFrame("Frame"); eventFrame:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED")` …
- `LSMPatch.lua:25-27` `local hookFrame = CreateFrame("Frame"); hookFrame:RegisterEvent("PLAYER_LOGIN")`. Neither uses AceEvent-3.0.

### AT-18 — §11 no Compat.lua
- No `Compat.lua` / `core/Compat.lua` on disk.
- Deprecated-API fallback duplicated: `SlashCommands.lua:87-95` (`C_AddOns.GetAddOnMetadata` → `GetAddOnMetadata`) and `Panel/About.lua:21-28` (same shim, copy-pasted).

### AT-19 — §12 debug to chat, no console
- `Utils.lua:17-21` `AddonTable.DebugPrint` → `print(...)` to chat; toggled `SlashCommands.lua:224-227`. No `ScrollingMessageFrame`/`DebugWindow` anywhere. (Compliant nuance: flag session-only, `Utils.lua:5` `AddonTable.DEBUG = false`, not in SV.)

### AT-20 — §13 no .pkgmeta
- No `.pkgmeta` at repo root (confirmed absent; root holds `.gitattributes`, `.gitignore` only among dotfiles).

### AT-21 — §14 no .luacheckrc
- No `.luacheckrc` at repo root (confirmed absent).

### AT-22 — §14A no tests
- No `tests/` directory. Only manual QA doc `docs/smoke-tests.md`. Pure logic that should be headless-tested and is not: `Schema.lua:263-272` `ParseSchemaValue`, `Schema.lua:128-145` `FormatSchemaValue`, `Schema.lua:61-83` `SchemaForPage`, `Events.lua:54-64` flat→profile migration.

### AT-23 — §15.2 CLAUDE not a stub
- `CLAUDE.md` — a full working-notes brief (hard rules, `AddonTable` bus, working environment, doc index) rather than a short stub pointing into `docs/`.

### AT-24 — §15 ARCHITECTURE at root
- `ARCHITECTURE.md` present at repo root (9.4 KB). §15 restricts root to `README.md` + stub `CLAUDE.md` + `LICENSE`; architecture belongs at `docs/ARCHITECTURE.md`.

### AT-25 — §15.1 README structure
- `README.md:1-104` headings: `# Ka0s Absorb Tracker`, badges (`:3` wow, `:4` CurseForge, `:5` license — **no X-Standard, no Wago badge**), `## Screenshots`, `## Usage`, `## Critical settings` (`:58`, non-canonical), `## Optional dependencies` (`:70`, non-canonical), `## FAQ`, `## Troubleshooting`, `## Issues and feature requests`, `## Version History`. **No `## Testing` section** (grep for `testing|luacheck|tests/run` returns nothing).
