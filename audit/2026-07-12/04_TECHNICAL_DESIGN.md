# 04 — Technical Design (remediation)

**Addon:** Ka0s Absorb Tracker · **Standard:** v1.0.0 (2026-07-12) · **Run:** 2026-07-12

How to close each gap in `02_DEVIATIONS.md`. This is design only — no code was changed by this audit. Work is grouped by theme; each block names files to touch, the shape of the change, and risks. The ordered, sprint-level sequencing is in `05_EXECUTION_PLAN.md`.

The animating tension: this addon is **architecturally healthy on its highest-value surfaces** (schema-as-single-source §4.5, options UI §6) but **misses most of the ecosystem scaffolding** (Ace substrate wiring, locales, Compat, tests, lint, packaging, doc shape). Remediation should preserve the schema/panel design while re-seating it on the standard's substrate.

---

## Theme A — Ace3 substrate re-seat (AT-08, AT-12, AT-14, AT-17)

The keystone change; several other deviations fall out of it.

- **Vendor** `libs/AceEvent-3.0/`, `libs/AceTimer-3.0/`, `libs/AceConsole-3.0/` (folder-per-lib, AT-09 layout). Copy from a sibling Ka0s addon's `libs/` so versions match the suite (§3.3).
- **Promote NS to an AceAddon** (new `core/AbsorbTracker.lua`):
  ```lua
  local addonName, NS = ...
  local addon = LibStub("AceAddon-3.0"):NewAddon(NS, addonName,
      "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
  NS.addon = addon
  function addon:OnInitialize() NS:InitDB(); NS:RegisterMigrations() end
  function addon:OnEnable() … register events, build bar, restore position … end
  ```
- **Events** (AT-17): replace the `Events.lua` raw frame with `addon:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", handler)` etc. `LSMPatch.lua`'s `PLAYER_LOGIN` frame becomes a one-shot AceEvent registration that unregisters itself.
- **Timer** (AT-08): swap `C_Timer.NewTicker` in `Timer.lua` for `addon:ScheduleRepeatingTimer`/`:CancelTimer`, keeping the interval-change guard.
- **Slash** (AT-14): replace `SLASH_*`/`SlashCmdList` with `addon:RegisterChatCommand("at", "OnSlash")` + `:RegisterChatCommand("absorbtracker", "OnSlash")`. The existing schema/COMMANDS dispatcher body (`SlashCommands.lua:29-75, 337-355`) moves into `OnSlash` almost verbatim — this is a registration swap, not a dispatcher rewrite.

**Risk:** load-order and init timing shift from "everything on PLAYER_LOGIN" to AceAddon's `OnInitialize`/`OnEnable`. The bar-build and DB-init sequencing (currently `Events.lua:35-76`) must be reproduced exactly, or the panel's forward references (`AddonTable.CreateOptionsPanel`, `RefreshOptionsPanel`) fire before their definitions. Cover with the new harness (Theme F) before touching runtime.

## Theme B — Tier-2 layout + naming (AT-01, AT-02, AT-11)

- Adopt the Tier-2 tree: `core/` (`Compat`, `Constants`, `Namespace`, `<Addon>`, `Database`, `Util` ← from `Utils.lua`, `Timer`, `Events`, `Display`, `UI`), `defaults/Profile.lua` (from `Core.lua` defaults), `settings/` (`Schema.lua`, `Panel.lua` ← `OptionsPanel.lua` + `Panel/*`, `Slash.lua` ← `SlashCommands.lua`), `locales/enUS.lua`, `modules/` (the bar display if peeled). Fold `Panel/Helpers|Widgets|ScrollPatch|About` and `Options/*` into `settings/`.
- Update the TOC file listing to the new paths (ties to AT-06).
- **AT-11 (naming):** rename `AddonName, AddonTable` → `addonName, NS` repo-wide. Mechanical but touches every file — do it as one isolated commit with the harness green, so the diff is reviewable as a pure rename.

**Risk:** high churn; this is the largest-diff theme. Do it after Theme F (tests) exists so behavior is pinned. Keep the schema/panel *logic* intact — only files move and identifiers rename.

## Theme C — TOC + packaging + lint (AT-04, AT-05, AT-06, AT-20, AT-21)

- **TOC** (AT-04/05/06): rewrite the metadata block to exact §2.1 field order — fix `IconTexture` case, add `X-Standard`, `X-Curse-Project-ID: 1450165`, `X-Wago-ID: <id>`; reorder `OptionalDeps`. Reformat the file listing under `# Libraries / # Locales / # Core / # Defaults / # Modules / # Settings` in load order, single trailing newline.
- **`.pkgmeta`** (AT-20): `package-as: AbsorbTracker`, `ignore: [audit, docs, tests, _dev, .luacheckrc, .gitignore, "*.bak"]`, no `externals:`.
- **`.luacheckrc`** (AT-21): `std="lua51"`, `exclude_files={"libs/","audit/","tests/","_dev/"}`, `read_globals` per §14 plus this addon's WoW APIs (`UnitGetTotalAbsorbs`, `UnitHealthMax`, `AbbreviateNumbers`, `C_ClassColor`, `UnitClass`, `StaticPopupDialogs`, `StaticPopup_Show`, `Settings`, `SettingsPanel`, `LibStub`, `C_Timer`, `C_AddOns`, `CreateFrame`, `UIParent`, `GameTooltip`, `DEFAULT_CHAT_FRAME`, `SlashCmdList`), `globals={"AbsorbTrackerDB"}`. Run `luacheck .` to 0 errors; fix any unused-local warnings surfaced.

**Risk:** low. TOC path changes must land in the same commit as the Theme B file moves or the addon won't load. Get the real Wago ID from the publisher before adding `X-Wago-ID` (omit the line if genuinely unpublished there).

## Theme D — SavedVariables migration (AT-07, AT-13)

- Add `schemaVersion` to a new `global` defaults table (`defaults/Profile.lua`): `global = { schemaVersion = 1 }`.
- New `core/Database.lua` with `function NS:RunMigrations()` — start with the version-guard skeleton; migrate the existing inline flat→profile backfill (`Events.lua:54-64`) into a versioned step so it is idempotent and testable.
- **AT-13:** extend `ValidateSchema` (`Schema.lua:182`) to resolve each `row.path` against `NS.defaults.profile`, warn on miss, and return the resolved-vs-missing counts for the harness to assert.

**Risk:** low; additive. The migration must be a no-op on an already-migrated profile — pin with a test that runs it twice.

## Theme E — Locales + Compat + prefix (AT-16, AT-18, AT-15)

- **AT-16:** `locales/enUS.lua` exporting `NS.L = setmetatable({}, {__index=function(_,k) return k end})`; seed keys from the inline strings in `settings/*`, slash, and the StaticPopup. Because keys are the English source, wrapping is incremental and low-risk (missing keys fall back to English).
- **AT-18:** `core/Compat.lua` exposing `Compat.GetAddOnMetadata(name, field)` (the `C_AddOns` → `_G` fallback); replace both inline copies (`SlashCommands.lua:87-95`, `Panel/About.lua:21-28`) with the shim.
- **AT-15:** expose `NS.PREFIX = "|cff00ffff[AT]|r"` in `core/Constants.lua`; `Print` reads it; drop the `local PREFIX`.

**Risk:** low. Locale wrapping is large-surface but mechanically safe; do it incrementally per page.

## Theme F — Tests + lint gate (AT-22)

The highest-leverage missing scaffold — build it **first** so every later theme lands test-first (§14A).

- `tests/run.lua` (micro-framework + runner), `tests/loader.lua` (TOC-order source loader with `setfenv`), `tests/wow_mock.lua` (self-returning no-op frame, `CreateFrame`, `Settings.*`, `LibStub` with AceDB/AceAddon fakes, `C_Timer`, `AbbreviateNumbers`, `UnitClass`/`C_ClassColor`).
- Suites: `test_schema.lua` (`ParseSchemaValue` bool/number/color clamping, `FormatSchemaValue`, `SchemaForPage` group ordering, path-vs-defaults validation), `test_database.lua` (migration idempotency), `test_slash.lua` (dispatch/unknown-verb/help generation).
- Wire the commit gate: `lua tests/run.lua` green + `luacheck .` clean before commits (§14A/§17).

**Risk:** the mock must model AceDB profile semantics closely enough for `SetByPath`/`ApplyDefault` to exercise real writes; budget for iterating the mock.

## Theme G — Docs (AT-23, AT-24, AT-25)

- **AT-23:** cut root `CLAUDE.md` to a stub (tier, "adheres to Ka0s standard + URL", pointer to `docs/`); move the current brief to `docs/` (e.g. `docs/agent-context.md`).
- **AT-24:** `git mv ARCHITECTURE.md docs/ARCHITECTURE.md`; ensure its sections match §15.3 (Overview, Module Map, Settings Schema, Message Bus, Slash Commands, Events, Taint, Known Limitations); fix inbound links in `CLAUDE.md`/`README.md`.
- **AT-25:** normalize README to §15.1 order; add the X-Standard badge/link and Wago badge; add `## Testing` (harness + `luacheck` + smoke-tests link); fold `## Critical settings` / `## Optional dependencies` into `## Usage`/`## FAQ` so canonical section order holds.

**Risk:** none to runtime; keep the slash-command and version-history tables in lockstep with code (they already are).

## Theme H — Media + debug console (AT-03, AT-19)

- **AT-03:** create `media/logos/`; move `absorbracker.logo.v2.tga` + `.jpg` there; repoint `LOGO_PATH` (`Panel/About.lua:19` → new `settings/` location). Keep screenshots under `media/screenshots/`.
- **AT-19:** decide the addon's tier posture. If it remains a positionable-display addon without a §6A browser window, the §12.7 chat fallback is defensible and AT-19 can be closed as "chat fallback, documented deviation." If a console is wanted, add `core/DebugLog.lua` per §12 (ScrollingMessageFrame, monospace font under `media/fonts/`, `FormatPlain`/`FormatColored`, session-only gate already present). Recommended: ship the console since post-Theme-B the addon is Tier 2.

**Risk:** the console (if chosen) pulls in a vendored monospace font + license — schedule last.
