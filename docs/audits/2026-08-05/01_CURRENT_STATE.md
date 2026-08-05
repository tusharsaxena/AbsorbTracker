# 01 — Current State

**Addon:** Ka0s Absorb Tracker (`AbsorbTracker`), version `1.9.0` (`AbsorbTracker.toc:5`).
**Run date:** 2026-08-05. **HEAD:** `e31b79d` (working tree clean apart from the untracked
`docs/reviews/2026-08-05/` bundle written by the review that ran immediately before this audit).
**Audited against:** Ka0s WoW Addon Standard **v2.21.0 (2026-08-04)**.

**Provenance of the standard.** `AUDIT.md` and `standards/STANDARDS.md` were fetched verbatim with
`curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/`, then **every** file the
index's *Sections* list links was fetched from `.../standards/standards/<file>.md` by following
those links — no filename was hard-coded. All **25** sections were retrieved and read; none is
unassessed:

`anti-patterns`, `architecture`, `audit-review-history`, `automated-tests`, `compat`,
`debug-logging`, `documentation`, `events-frames-taint`, `layout`, `library-stack`, `lint`,
`localization`, `naming-cheatsheet`, `open-evolutions`, `options-ui`, `packaging`, `performance`,
`preview-mode`, `public-api`, `savedvariables`, `slash-commands`, `standalone-windows`, `testing`,
`toc-file`, `versioning-git`.

Section references below use the `filename-§N` form. The retired global `§N.M` notation is not used
here — its survival **inside the addon** is itself a finding (AT-36).

**Prior runs.** `docs/audits/2026-07-12/`, `docs/audits/2026-07-18/`, `docs/audits/2026-08-04/`
(the last against v2.17.1). Deviation prefix `AT-`, highest prior ID `AT-41`; this run continues
from `AT-42`. The three frozen prior folders are untouched.

---

## 1. Layout (`layout`)

Modular layout as required: `core/`, `defaults/`, `settings/`, `locales/`, `modules/`, `libs/`,
`media/`, `tests/`, `docs/`. Nothing loose at the root beyond the three docs plus `LICENSE`,
`.luacheckrc`, `.pkgmeta`, `.gitattributes`, `.gitignore`.

Folder casing is lowercase throughout, Lua files PascalCase, `libs/` lowercase. Media is in typed
subfolders — `media/fonts/`, `media/logos/`, `media/screenshots/` — with the logo shipped as both
`.tga` (runtime) and `.jpg` (source), per `layout-§3`.

LOC cap: the largest runtime file is `settings/Slash.lua` at 496 lines; nothing in `core/`,
`modules/`, `settings/` or `defaults/` is within an order of magnitude of the 1500 cap. Exactly one
file in the repo is in the 1000–1500 on-notice band — `tests/test_slashcmds.lua` at 1256 — and it is
carried on the `RESULTS.md` watch list with a disposition and a trigger
(`docs/automated-tests/RESULTS.md:97`).

## 2. TOC (`toc-file`)

`AbsorbTracker.toc` carries the metadata block in the exact required order (`toc-file-§1`), with a
single `## Interface: 120007`, `## X-License: MIT`, `## X-Standard:` pointing at the standards repo,
and `## X-Curse-Project-ID: 1450165`. `## X-Wago-ID` / `## X-WoWI-ID` are absent, which is correct —
the addon publishes on CurseForge only, and `toc-file-§1` makes both **MAY**.

`## SavedVariables: AbsorbTrackerDB, AbsorbTrackerPerfDB` — exactly the two globals `toc-file-§2`
allows, in the required order. No `Dependencies:`; `OptionalDeps` names Ace3, LibStub,
CallbackHandler-1.0, LibSharedMedia-3.0.

File listing is sectioned `# Libraries` → `# Locales` → `# Core` → `# Defaults` → `# Modules` →
`# Settings`, every library listed directly (no addon-authored `embeds.xml`), and
`libs\LibKa0s\LibKa0s.xml` appears **once**, as the single aggregate, after the Ace3 entries
(`toc-file-§4`/`§5`, `library-stack-§7`). No individual `LibKa0s` `.lua` file is TOC-listed.

## 3. Library stack and the LibKa0s seams (`library-stack`)

Every library is vendored and committed under `libs/`: LibStub, CallbackHandler-1.0, AceAddon,
AceEvent, AceTimer, AceConsole, AceDB, AceDBOptions, AceGUI, AceConfig, LibSharedMedia,
AceGUI-3.0-SharedMediaWidgets, and `libs/LibKa0s/`.

`libs/LibKa0s/` holds ten files — `Core.lua`, `DebugLog.lua`, `Slash.lua`, `Options.lua`,
`OptionsWidgets.lua`, `OptionsScroll.lua`, `Perf.lua`, `PerfPanel.lua`, `LibKa0s.xml`, `LICENSE` —
i.e. the five majors across eight files plus the aggregate and the license, matching what the addon's
own brief records (`CLAUDE.md:74-75`). No `Core.lua`-less major, no shell without its attach file:
nothing here reads as anti-pattern #48.

**The addon owns descriptors and stubs, not implementations.** There is no `modules/DebugLog.lua`,
no widget-maker file, no dispatcher and no hand-written test framework anywhere in the tree — the
compliant state. Five seams:

| Seam | File | Lookup | Stub shape |
|---|---|---|---|
| Core (printer / secret guard) | `core/CoreSetup.lua:25` | `LibStub("LibKa0s-Core-1.0", true)` | member-answering; announce-once, then fall back to the pre-library printer (`:27-59`) |
| Perf | `core/PerfSetup.lua:14` | `LibStub("LibKa0s-Perf-1.0", true)` | member-answering (`on`, `suspended`, `Note`, `OnCommand`) (`:15-30`) |
| DebugLog | `core/DebugLogSetup.lua:16` | `LibStub("LibKa0s-DebugLog-1.0", true)` | member-answering, 10 members, with the reason the formatters are deliberately omitted (`:16-60`) |
| Options | `settings/OptionsSetup.lua` | `LibStub("LibKa0s-Options-1.0", true)` | **load-completing, not member-answering** — the documented exception (`CLAUDE.md:83-88`) |
| Slash | `settings/Slash.lua` | `LibStub("LibKa0s-Slash-1.0", true)` | descriptor built here because `NS.COMMANDS` stays host-owned |

Stub coverage was re-checked against the call sites: the only members the addon reaches on
`NS.Perf` are `on`, `suspended`, `Note` and `OnCommand`, and the stub answers all four
(`core/PerfSetup.lua:23-29`). The Options stub's load-completing shape is the one documented
exception and is **not** a finding.

`core/LSMPatch.lua` extends AceGUI's LSM30_Border widget rather than forking the widget — the
sanctioned form.

## 4. Architecture (`architecture`)

`core/Namespace.lua` is the single private `NS` table; `core/AbsorbTracker.lua:9` promotes it via
`AceAddon:NewAddon(NS, …)` and reclaims `NS.Print = NS.Util.print` afterwards so AceConsole's `:Print`
mixin cannot silently displace the prefixed printer (anti-pattern #36 avoided; asserted in
`tests/test_slash.lua`). `core/Bus.lua` publishes five `Ka0s_AbsorbTracker_*` messages, each with one
sender, and every receiver takes its own `NS.NewBusTarget()` embed rather than sharing `NS.bus`
(`architecture-§4`, anti-pattern #32).

## 5. Settings, options UI, slash (`options-ui`, `slash-commands`)

`settings/Schema.lua` is the single schema, one row per setting, with `NS.ValidateSchema` asserting
every row resolves against the defaults profile. Pages are registered through
`NS.RegisterOptionsPage` and built lazily on first `OnShow` — with **one** exception,
`settings/Profiles.lua:51-56`, which creates and anchors an AceGUI `SimpleGroup` inside the
registration-time builder (AT-34, unchanged from the prior run).

Slash: `settings/Slash.lua` registers `/at` and `/absorbtracker` through AceConsole against a
host-owned `NS.COMMANDS` table; the README's command table and `/at help` are in lockstep. The
CCN peel that landed on `feat/fix-ccn` moved `runProfile`'s verb chain onto a module-level
`PROFILE_VERBS` table (`settings/Slash.lua:327`) with its help rows in `PROFILE_HELP` (`:299`) —
built once at file load, named for things a reader recognizes, which is `performance-§11`'s
permitted shape 1, not anti-pattern #52.

## 6. SavedVariables (`savedvariables`)

`AbsorbTrackerDB` via AceDB with defaults declared only in `defaults/Profile.lua`. Two schema
stamps: a **per-profile** one defaulting to `1` with the load-bearing reason written down
(`defaults/Profile.lua:50-56`) and the **account-wide** one at `defaults/Profile.lua:78`, which
defaults to the current `4` (AT-49). Migrations run from `core/Database.lua:186` over a module-level
`SCHEMA_STEPS` ladder (`:166`) plus `backfillFlatKeys` / `backfillUnitKeys` (`:141`, `:152`).
`AbsorbTrackerPerfDB` is the sanctioned second global, written by the library outside the AceDB tree
(`savedvariables-§4`).

## 7. Events, frames, taint (`events-frames-taint`)

Registrations happen in `OnEnable`, not at file load. `UNIT_ABSORB_AMOUNT_CHANGED` and
`UNIT_MAXHEALTH` are registered per tracked unit on private `CreateFrame` frames via
`RegisterUnitEvent` rather than through AceEvent — the accepted, documented deviation AT-31.
Combat-secret handling is exemplary: `NS.SafeToString` / `NS.IsConcatSafe` come from the library and
every chat argument goes through the prefixed printer. What remains is that 17 call sites build the
line with `..`/`:format` **before** the seam (AT-35).

## 8. Debug logging (`debug-logging`)

Console, buffer, scrollbar and line counter all live in `LibKa0s-DebugLog-1.0`. The addon owns
`core/DebugLogSetup.lua` (descriptor + stub) and `NS.State.debug`, which defaults off and resets on
every reload. `/at debug`, `/at debug on|off` and the General-page console checkbox all route to the
library instance.

## 9. Performance (`performance`)

Brackets are the mandated gated form — `local t0 = Perf.on and debugprofilestop()` … `if t0 then
Perf.Note(...)` — in `core/AbsorbTracker.lua`, `modules/Display.lua` and `modules/Timer.lua`, with
`tests/perf.lua`'s `probeOverheadOff` / `probeOverheadOn` pair as the required zero-overhead
evidence. Five buckets are declared with nesting in `core/PerfSetup.lua:42-48`; two of the three
`within = "repaintPass"` declarations are **false** (AT-47).

`docs/performance.md` is the addon's perf page and `docs/perf-runs/` is the standing in-game capture
store with its own `README.md`. One passage of `docs/performance.md` contradicts `performance-§7`
(AT-48).

## 10. Testing and the automated-test record (`testing`, `automated-tests`)

`tests/_kit/` is the vendored LibKa0s test kit (harness, loader, mock base, runner) and sits under
`tests/`, never `libs/` — correct. `tests/run.lua` drives 22 suites; `tests/perf.lua` is the offline
scenario runner; `docs/test-cases.md` is the generated inventory and the README `[tests]` badge
tracks it (both read **470** today — AT-32 from the prior run is **closed**).

`docs/automated-tests/` carries `README.md`, `RESULTS.md` and three frozen bundles
(`20260804-182031`, `20260804-214639`, `20260804-233138`), each with `manifest.json`, `ANALYSIS.md`
and one file per suite. The retired `docs/complexity.md` is **absent** — correct as of v2.19.0.
`.gitattributes` carries `*.sh text eol=lf` with the reason written down. The runner is vendored and
unedited, but is recorded in the git index at mode `100644` — not executable (AT-43).

The watch list is present below the trend table; its **files-by-band** half is a real table with a
Band column, its **warned-functions** half is prose rather than a table (AT-44).

## 11. Documentation (`documentation`)

**Root — the three docs plus `LICENSE`**, and no fourth: `README.md` (full, player-facing),
`CLAUDE.md` (stub with `## Standards compliance (read first)`), `DEPENDENCIES.md`. No
`docs/agent-context.md` anywhere; `CLAUDE.md:48-57` states plainly that it must never be created
(anti-pattern #49 avoided, explicitly).

**The `docs/` canonical trio** — `docs/ARCHITECTURE.md`, `docs/testing.md`, `docs/smoke-tests.md` —
all three present.

**The five required topic-detail docs** — `docs/test-cases.md`, `docs/performance.md`,
`docs/perf-runs/README.md`, `docs/automated-tests/README.md`, `docs/automated-tests/RESULTS.md` —
all five present. `CLAUDE.md:40-41` calls them "**Four**" and then lists five (AT-42).

**The three-place standards reference** (`documentation-§6`) is complete: TOC
`## X-Standard:` (`AbsorbTracker.toc:14`), the README standard badge (`README.md:6`), and
`CLAUDE.md:6` `## Standards compliance (read first)` with the stop-and-flag directive verbatim in
substance. Anti-pattern #34 does not apply.

`README.md` follows `documentation-§1`'s twelve sections in order, with one addition
(`## Credits and libraries`, AT-41). `## What's new in 1.9.0` and the top `## Version History` row
still disagree (AT-33). `DEPENDENCIES.md` splits runtime / development / release, gives WSL2 install
plus verification commands per tool, and is evidence-based — `documentation-§7` is met.

**Where the docs are wrong is the release gate.** `docs/testing.md:22,47,49`,
`docs/automated-tests/README.md:25-30` and `docs/automated-tests/RESULTS.md:9-11` all state that
`perf` and `complexity` are "recorded, never gating" without naming the checkpoint, and
`docs/testing.md:57-58` says "Commits are gated on lint + tests only" without the other half — the
v2.21.0 release gate (`automated-tests-§3` *The release gate*, `§6`) appears nowhere in the repo
(AT-45).

## 12. Localization, compat, packaging, preview

`locales/enUS.lua` ships with the key-returning metatable and `NS.L` exists, but no user-facing
string is routed through it (AT-30). US spelling is enforced by a test case
(`tests/test_docs.lua`). `core/Compat.lua` is present and is the only caller of deprecated APIs; no
`WOW_PROJECT_ID` branching. `.pkgmeta` declares `package-as`, no `externals:`, and ignores `docs`,
`tests`, `_dev`, `.luacheckrc`, `.gitattributes`, `.gitignore`, `*.bak` — the `packaging` minimum,
though two dev-only dot-folders are not ignored (AT-46). Preview mode exists as `/at test` but is a
timed fill rather than a toggle and does not fire automatically while unlocked (AT-38).

No public API is exposed, so `public-api` is N/A. No standalone window is owned by the addon — the
debug console is the library's — so `standalone-windows` is satisfied through the library.

## 13. Mechanical checks, headline

Full commands and output are in `03_EVIDENCE.md`.

| Check | Result |
|---|---|
| `luacheck .` | **pass** — 0 warnings / 0 errors, 28 files |
| `lua5.1 tests/run.lua` | **pass** — 470 passed / 0 failed / 470 total |
| `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | **pass** — 7574 nloc, 1063 functions, avg CCN 1.7, **0** above CCN 15 |
| Complexity drift vs `20260804-233138/complexity.txt` | **none** — every footer figure identical |
| LOC-band drift vs the watch list | **none** — `tests/test_slashcmds.lua` still the only file in 1000–1500 |
| `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` | **NOT RUN** — out of scope for this run |
| `diff -r ../LibKa0s/testkit tests/_kit` | **NOT RUN** — out of scope for this run |

The latest bundle's stamp dates it two commits behind: `manifest.json` records
`"sha": "ab2603e…"`, `"branch": "feat/fix-ccn"`, `"dirty": true`, while HEAD is `e31b79d`. The two
intervening commits touched only `docs/`, `libs/` and `tests/_kit/`, so the numbers are still true —
the record is stale in stamp, not in substance.
