# 01 — Current state

**Addon:** Ka0s Absorb Tracker (`AbsorbTracker`), TOC version `1.9.0`, `## Interface: 120007`.
**Repo HEAD at audit:** `686cae5a0d662f3e43fbe9eeb54efdc9d8572c2f` (2026-09-03), working tree clean.
**Audited against:** Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)** — resolved from
`standards/STANDARDS.md` at `https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master`.
All 26 section files linked from the index's Sections list were fetched by following those links
(`layout`, `toc-file`, `library-stack`, `architecture`, `savedvariables`, `options-ui`,
`standalone-windows`, `preview-mode`, `slash-commands`, `localization`, `events-frames-taint`,
`public-api`, `compat`, `debug-logging`, `packaging`, `line-endings`, `lint`, `testing`,
`performance`, `automated-tests`, `documentation`, `audit-review-history`, `versioning-git`,
`naming-cheatsheet`, `anti-patterns`, `open-evolutions`) and read. Playbook: `AUDIT.md` at the same
ref. The repo has a `.toc`, so the **addon** rule set applies, not `library-stack-§7`'s library list.

**Rule-set note.** This is a read-only run. Nothing outside this folder was written.

---

## Layout (`layout`)

`core/ defaults/ locales/ modules/ settings/ libs/ media/ tests/ docs/`, all lower-case. `core/`
holds 14 files, `modules/` three (`Bar.lua`, `Display.lua`, `Timer.lua`), `settings/` eight,
`defaults/Profile.lua`, `locales/enUS.lua`. `media/` holds only `logos/` and `screenshots/` — no
private `fonts/`, `icons/` or `textures/` duplicating `libs/LibKa0s/media/`. Largest own-source file
is `settings/Slash.lua` at 502 lines; nothing is near `layout-§1`'s 1000-line notice band.

## TOC (`toc-file`)

`AbsorbTracker.toc` carries all required fields in order, single Retail `120007`, `## X-License: MIT`,
`## X-Standard:` pointing at the standards repo, `## X-Curse-Project-ID: 1450165` (published; matches
the README's CurseForge badge). The file list is `#`-sectioned (`# Libraries`, `# Locales`, `# Core`,
`# Defaults`, `# Modules`, `# Settings`) and wrapped in `#@no-lib-strip@`. Position annotations are
present and specific: `core/EnvSetup.lua` is annotated **conventional** ("Nothing here is resolved at
load"), and `core/MediaSetup.lua` is annotated **load-bearing** naming exactly what resolves
("`Constants.FONT_MONO` is resolved from the `NS.MediaFont` seam this file publishes"). `LibKa0s` is
listed once as the aggregate `libs\LibKa0s\LibKa0s.xml`, after Ace3.

## Library stack (`library-stack`)

Ace3 set + `LibSharedMedia-3.0` + `AceGUI-3.0-SharedMediaWidgets` + `LibStub` +
`CallbackHandler-1.0`, all vendored. `libs/LibKa0s/` is the whole ship folder (14 payload entries plus
`media/`). Provenance line is in root `CLAUDE.md:69` — `Bundles [LibKa0s](…) v1.25.0 (MIT).` — and in
**no** other file. `v1.25.0` is the newest LibKa0s tag on this machine.

## Architecture / SavedVariables

AceAddon bootstrap (`core/AbsorbTracker.lua:12`), closed bus in `core/Bus.lua` (five messages),
schema-as-single-source in `settings/Schema.lua`. AceDB with account-wide `db.global.schemaVersion`
plus a per-profile stamp, and a `SCHEMA_STEPS` migration runner at `core/Database.lua:175-243` that
reaches **v5** — the step that maps the retired `showOnlyInCombat` boolean onto the four-value
`visibility` dropdown (`core/Database.lua:194-211`). Second SV global `AbsorbTrackerPerfDB` is the
sanctioned diagnostics carve-out.

## Shared LibKa0s subsystems — descriptors and stubs (not addon implementations)

| Module | Seam | Stub |
|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua:25` | library-absent branch; `NS.MakeCloseButton` wrapper at `:110-112` |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua:14`, descriptor `name`/`addonName` at `:75`/`:84` | present |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` (load-completing stub, `:319-343`) | present, deliberately load-completing |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua:445-451`, `commands = NS.COMMANDS` | present |
| `LibKa0s-Perf-1.0` | `core/PerfSetup.lua:14`, descriptor at `:33-43` | `:22-27`, covers all four members reached (`on`, `suspended`, `Note`, `OnCommand`) |
| `LibKa0s-Env-1.0` | `core/EnvSetup.lua:54` | present |
| `LibKa0s-Media-1.0` | `core/MediaSetup.lua:82`, fed the addon's own first vararg | present |
| test harness | `tests/_kit/` (never `libs/`) | vendored |

The addon carries **no** console window, widget maker, dispatcher or test framework of its own.

## Settings panel (`options-ui`)

Four pages. **General** (`settings/General.lua`) draws two tabs — `Master controls` (composed from
`H.MasterControls`, all eight canonical rows, `frameless = false` stated explicitly because the bars
are movable) and `Bars` with `Tracked units` / `Updates` subgroups. **Appearance**
(`settings/Appearance.lua`) draws one chrome block (unit picker + mirror controls) above a
`Size / Bar / Background / Border / Text` strip, rendered through `settings/UnitPanel.lua`.
**Profiles** is AceConfig-drawn (exempt). **About** is the landing page — `Helpers.BuildMainContent`
(`settings/About.lua:34`) — also exempt. Four color rows each carry a `Use class color` companion in
declaration order; **no** `disabledIf` on any row (`settings/Schema.lua:44`); no
`ScrollUp-Up`/`ScrollDown-Up` arrow art anywhere; `LSM30_*` controls come from the composers.

## Slash, debug, preview, performance

`NS.COMMANDS` (`settings/Slash.lua:60`) carries **17** verbs and `/at profile` has a **subcommand
tree** (`PROFILE_VERBS` at `:327`, dispatched at `:386`). Debug output goes to the LibKa0s console.
`/at test` + `NS.ClearPreview` give preview mode. `core/PerfSetup.lua` wires the harness with declared
buckets, `AbsorbTrackerPerfDB`, and one frozen in-game bundle at
`docs/perf-analysis/20260807-125002/` (`report.md`, `dump.json`, `ANALYSIS.md`).

## `.gitattributes` (`line-endings`)

Present at the repo root, CRLF kind, body matching the canonical client-bound file verbatim:
`* text=auto eol=crlf` (line 26), `*.sh text eol=lf` (line 34), 20 ` binary` marks, plus the
renormalize note. Working-tree agreement measured — see `03_EVIDENCE.md`.

## Packaging (`packaging`)

`.pkgmeta` ignores `docs`, `tests`, `_dev`, `.luacheckrc`, `.gitattributes`, `.gitignore`, `*.bak`
and the non-loadable logo masters. It does **not** ignore `.claude` or `.superpowers`.

## Root doc set and `docs/`

`README.md` follows the canonical section order (H1 → 5 badges in order, standard badge **bare** and
unlinked at `:6` → logo → description → `## What's new in 1.9.0` → `## Screenshots` → `## Usage` with
`### Slash commands` (17 rows) and `### Settings panel` → `## How the bar works` → `## FAQ` →
`## Troubleshooting` → `## Issues and feature requests` → `## Version History`), carries **no**
bundled-library inventory and no `## Credits`. `CLAUDE.md` is a stub with the mandated
`## Standards compliance (read first)`, the docs pointer, the green-gate line and the provenance
line. `DEPENDENCIES.md` present.

`docs/` carries the trio (`ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`), **all six Tier 1 docs**
(`scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`, `data-flow.md`, `common-tasks.md`),
Tier 2 `midnight-quirks.md`, `profiles.md`, `perf-analysis/README.md`, and Tier 3 `performance.md`,
`test-cases.md`. `ARCHITECTURE.md` (475 lines) carries all ten mandated sections including
`## Documentation map` (`:304`) and `## Documented deviations` (`:344`). No retired `file-index.md`,
`conventions.md`, `complexity.md`, `docs/perf-runs/` or `docs/pending/LEDGER.md`.

## Decision register read first

`docs/ARCHITECTURE.md:344-467` holds four ratified rows — `events-frames-taint-§1` (per-unit event
frames), `savedvariables-§1` (per-profile schema stamp), `events-frames-taint-§8` SHOULD half
(18 pre-formatted chat lines, re-graded against the now-scoped rule), `localization-§1` (English
only) — plus a "Retired on 2026-08-05" list of four rows whose cited rules the standard changed.
All four live rows still match the v2.38.0 text; none is re-filed here. The issue store was read with
`gh issue list` — see `03_EVIDENCE.md`. No `state:will-not-do` issue records a standards deviation
that lacks a register row.
