# 01 — Current State

**Addon:** Ka0s Absorb Tracker · **Version:** 1.9.0 (TOC/`core/Namespace.lua`)
**Audited against:** Ka0s WoW Addon Standard **v2.7.0 (2026-07-17)** — resolved live from
`https://github.com/tusharsaxena/WowAddonStandards` (`AUDIT.md` playbook + `standards/STANDARDS.md`
index and every section file it links).
**Run date:** 2026-07-18 · **Audit type:** read-only compliance snapshot (no addon code changed).
**Prior run:** `docs/audits/2026-07-12/` (against standard v1.0.0, pre-remediation — 25 deviations,
almost all since closed per that run's `06_EXECUTION_OUTCOME.md`).

This addon is a **reference implementation** the standard itself cites by description (the
"absorb-shield tracker" / "modular tracker") for the secret-safe printer, AceDB-missing shim, schema
boot-validation, always-show scrollbar, and the `CLAUDE.md`/`agent-context.md` standards blocks. It
is highly compliant; the deviations below are narrow.

## Snapshot by section

### Layout (`layout`)
Modular tree present: `core/`, `defaults/`, `settings/`, `locales/`, `modules/`, plus `libs/`,
`media/`, `tests/`, `docs/`. Subfolders lowercase; Lua files PascalCase. No source loose at root.
Largest non-lib file `settings/Slash.lua` = 369 LOC (well under the 1500 cap). `media/` uses typed
subfolders (`fonts/`, `logos/`, `screenshots/`). One data-access module lives at `core/Data.lua`
(getters/LSM/class-colour), not a pure `defaults/Data*.lua` data table — acceptable (it is logic, not
a Retail data table). Green gate: `lua tests/run.lua` = **73/73**, `luacheck .` = **0/0**.

### TOC (`toc-file`)
`AbsorbTracker.toc`: field order matches `toc-file-§1` (Interface 120007, Title, Notes, Author,
Version, IconTexture, SavedVariables, OptionalDeps, DefaultState, Category-enUS, X-License MIT,
X-Standard, X-Curse-Project-ID). Single Retail Interface line. Libraries listed **directly** (no
`embeds.xml`). **Gaps:** file-listing `#` section order places `# Locales` after `# Core`/`# Defaults`
instead of directly after `# Libraries` (toc-file-§5); `X-Wago-ID` absent though the addon is
published (Curse 1450165) (toc-file-§1). See AT-28, AT-05.

### Libraries (`library-stack`)
All mandatory Ace3 libs vendored under `libs/` folder-per-lib and committed. Optional
AceConfig/AceDBOptions (Profiles page), LibSharedMedia, AceGUI-SharedMediaWidgets present and used.
`LibStub("AceGUI-3.0")` stashed once at `NS.AceGUI` (`settings/Panel.lua:78`); LSM cached in
`core/Data.lua`. No lib forks, no suite dependencies.

### Architecture (`architecture`)
`local addonName, NS = ...` header everywhere; no `_G[addonName]`. AceAddon promotion at
`core/AbsorbTracker.lua:7` with the NS-first arg; the custom secret-safe printer is **reclaimed**
after `:NewAddon` (`core/AbsorbTracker.lua:17`, architecture-§2). Modules published idempotently.
Schema-as-single-source is the addon's strongest surface (`settings/Schema.lua`): single write seam
`NS.SetByPath`, boot path-validation `NS.ValidateSchema` counting resolved/missing. **Gap:** no closed
message bus — cross-module communication is direct `NS.X` calls (documented as an accepted deviation
in `docs/ARCHITECTURE.md`). See AT-29.

### SavedVariables (`savedvariables`)
`AbsorbTrackerDB` single global; `NS.defaults.profile`/`.global`; `schemaVersion` in global defaults
(`defaults/Profile.lua:34`); `NS:RunMigrations` runner with a real v1 backfill + v2 orphan-delete
(`core/Database.lua`). AceDB-missing soft fallback present.

### Options UI (`options-ui`)
Blizzard `Settings.RegisterCanvasLayoutCategory` landing page + subcategories, eager register / lazy
body, combat-refuse open with the canonical grey notice (`settings/Panel.lua:107`), raw AceGUI,
always-show scrollbar patch, layout constants matched, AceGUI Defaults button (not a raw template).
In-place scalar refresh via per-widget `refreshers` (options-ui-§11) — no full-page rebuild.
**Gap:** the 50/50 action-button pair uses `SetRelativeWidth(0.5)` instead of `BUTTON_PAIR_REL`
0.492 (options-ui-§6/§8, anti-pattern #31). See AT-27.

### Standalone windows (`standalone-windows`)
No separate data-browser window; the debug console is the only standalone frame (skinned from stock
Blizzard textures, `UISpecialFrames`, clamped). N/A otherwise.

### Preview mode (`preview-mode`)
`/at test [value] [seconds]` feeds a placeholder value through the live bar render path. Satisfied.

### Slash (`slash-commands`)
AceConsole `:RegisterChatCommand("at" / "absorbtracker")`; schema-driven `list`/`get`/`set` with the
mandated colour scheme + shared `FormatKV`; help generated from `NS.COMMANDS`; cyan `NS.PREFIX`;
secret-safe printer; no trailing colons. **Gap:** no standalone `version` verb (slash-commands-§3,
required since standard v1.9.0). See AT-26.

### Localization (`localization`)
`locales/enUS.lua` ships the metatable-fallback `NS.L`. Game-data matching keys on tokens
(`classFilename` from `UnitClass`, `core/Data.lua:91`) — localization-§4 clean, no localized-string
branches. **Gap:** user-facing output strings are hardcoded English, not routed through `NS.L`
(seam present but unused) — documented accepted deviation. See AT-30.

### Events / frames / taint (`events-frames-taint`)
AceEvent for global events; secret-safe stringifier (`core/Util.lua`) probing `table.concat`;
`UnitAffectingCombat("player")` drives visibility (not `InCombatLockdown`); `InCombatLockdown` gates
the panel open. **Deviation (documented/justified):** a private `RegisterUnitEvent("player")` frame
for `UNIT_ABSORB_AMOUNT_CHANGED`/`UNIT_MAXHEALTH` instead of AceEvent (events-frames-taint-§1). See
AT-31.

### Public API (`public-api`)
Exposes nothing publicly — N/A.

### Compat (`compat`)
`core/Compat.lua` is the sole caller of `GetAddOnMetadata` (routed via `Compat.GetAddOnMetadata`); no
direct deprecated-API calls elsewhere (grep clean). No `WOW_PROJECT_ID` branching.

### Debug logging (`debug-logging`)
On-screen console `AbsorbTrackerDebugWindow` (700×344, DIALOG strata, monospace JetBrains Mono 10pt,
pure Format Plain/Colored formatters, Copy/Clear, session-only flag, colour-coded ON/OFF ack, `[Init]`
summary on enable, coalesced `[Combat]` rollup, `[Set]` at the single write seam). Fully compliant.

### Packaging (`packaging`) / Lint (`lint`)
`.pkgmeta` present, no `externals:`, ignores docs/tests/_dev. `.luacheckrc` std lua51, excludes
libs/audits/reviews/tests, declares `AbsorbTrackerDB`. `luacheck .` = 0/0.

### Testing (`testing`)
Headless Lua 5.1 harness (`tests/run.lua` + `loader.lua` + `wow_mock.lua` + 8 suites), 73/73 green.
Generated `docs/test-cases.md` (total 73) is the authoritative count; README `[tests]` badge = 73/73
in lockstep.

### Documentation (`documentation`)
Root README (player-facing, all required sections in order incl. `## How the bar works`,
`## Issues and feature requests`, `## Version History`; five canonical badges in order). Root
`CLAUDE.md` is a stub with `## Standards compliance (read first)`. `docs/` quartet present
(`agent-context.md`, `ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`) + generated `test-cases.md`.
Standards reference in all four places (TOC, README badge, CLAUDE.md, agent-context Hard rules). No
`TODO.md`.

### Audit/review history (`audit-review-history`)
`docs/audits/2026-07-12/` and `docs/reviews/2026-05-02/` retained; this run adds
`docs/audits/2026-07-18/` without touching them.

### Versioning/git (`versioning-git`)
Semver 1.9.0, trunk-based, clean tree. Sanctioned debug-font + logo media (v2.6.0) present and, per
the standard, **not** flagged.
