# 01 — Current State

**Addon:** Ka0s Absorb Tracker (`AbsorbTracker`), version `1.11.0` (`AbsorbTracker.toc:5`).
**Audited against:** Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**, line 1 of
`standards/STANDARDS.md` on `master`. Fetched with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` and read verbatim. The
index's **Sections** list links **27** section files; all 27 were fetched the same way
(`anti-patterns`, `architecture`, `audit-review-history`, `automated-tests`, `compat`,
`debug-logging`, `documentation`, `events-frames-taint`, `launcher`, `layout`, `library-stack`,
`line-endings`, `lint`, `localization`, `naming-cheatsheet`, `open-evolutions`, `options-ui`,
`packaging`, `performance`, `preview-mode`, `public-api`, `savedvariables`, `slash-commands`,
`standalone-windows`, `testing`, `toc-file`, `versioning-git`). `AUDIT.md` (1157 lines) and
`standards/ADDONS.md` were fetched the same way. The changelog entries v2.65.0 through v2.76.1 (the
versions released since the previous audit, which measured v2.64.0) were read in full to find the
checks this addon had never been measured against.

**Repo kind:** **Addon.** `dev-copilot-profile` reports `profile=wow`, `kind=addon`,
`reason=toc:## Interface`. The repo carries `AbsorbTracker.toc`, and `ADDONS.md:19` lists it under
the in-scope addons with launcher menu entries **Enabled · Locked**. The detector and the table
agree. The whole addon rule set and the whole `AUDIT.md` playbook apply; the library-stack-§7 and
documentation-§8 applicability lists do not.

**Commit audited:** `4cedffabeb437e9475d91771b620cafff46f3876` (2026-10-07 13:39 +0530), branch
`feat/2026-10-07-review-audit-remediation`, clean tree at the start of the run.
**Run date:** 2026-10-07. **Bounded runner:** every `luacheck`, `lua tests/run.lua` and complexity
run went through `~/.claude/dev-copilot/bin/ka0s-bounded`; none exited 124 or 137.

This is a **read-only measurement**. The only files it writes are the five in this folder.

**Deviation IDs:** prefix `AT-`. The prior bundle is `docs/audits/2026-09-23/`, whose highest ID was
`AT-81`. Two IDs recur with new evidence (`AT-78`, `AT-80`). New IDs start at `AT-82`.

---

## What changed since the 2026-09-23 audit

The 2026-09-23 remediation executed. Re-measured against the tree, these prior deviations are
**closed**: `AT-60` (v2.65.0 ruled that the library's suite pins the strip's wrap invariance and the
addon **MUST NOT** duplicate it; `tests/test_widgets.lua:851-853` now says so and does not), `AT-62`
and its dependent `AT-63` (the Options stub's composers are hollow, `settings/OptionsSetup.lua:246-249`,
and the composed `enabled`/`locked` paths reach the store through `settings/Schema.lua`'s
`writeThrough` list, the v2.65.0 route (a)), `AT-64`, `AT-65`, `AT-69`, `AT-70`, `AT-71` (the five
core TOC positions are annotated, `AbsorbTracker.toc:45-62`), `AT-67` (parity cases for Perf and
Lifecycle, `tests/test_surface_parity.lua:241`, `:273`), `AT-72` (span bundle
`docs/revendor/2026-09-23-v1.16.0-v1.54.2/`), `AT-73` (the `events-frames-taint-§1` register row is
retired), `AT-74` (every registration goes through `LibKa0s-Core-1.0`'s `SafeRegister*` helpers,
`core/AbsorbTracker.lua:138-149`), `AT-75` (hub now 406 lines, every mandated section under 60),
`AT-76` (`/at test` became `/at debug hold`), `AT-77` (compat's v2.65.0 applicability condition;
`compat-layer.md` is a *Not applicable* row), `AT-79` (no malformed or retired citation in the live
tree), `AT-81` (no hand-written chat tag outside `core/Namespace.lua:10`).

The addon re-vendored LibKa0s from v1.55.0 through **v1.70.0** (kit revision 25 → **37**), adopted
the diagnostics dump, the launcher menu and status tooltip, the library's debug lines, the sighted
complexity gate and the Options `addonName` field. The suite grew from 710 to 877 cases.

---

## Layout (`layout`)

- Modular skeleton in place: `core/` (14 files), `defaults/Profile.lua`, `locales/enUS.lua`,
  `modules/` (`Bar`, `Display`, `Timer`, `Diagnostics`), `settings/` (8 files), `media/logos/`,
  `media/screenshots/`, `libs/`, `tests/`, `docs/`. No `tools/`; `git ls-files '*.py' '*.sh'` outside
  `libs/` and `tests/_kit/` returns nothing, so there is no authored generator to place.
- **Cap census** (scope: `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`, `tests/` in,
  vendored excluded, no generated-data exemption declared): **69** files, **23 483** lines. Largest
  `tests/test_slashcmds.lua` **1079** and `tests/test_widgets.lua` **1073**, both in the 1000–1500
  band; **nothing over 1500**.
- The census heading `### Files over the 1500-line cap` sits under `## Documented deviations`
  (`docs/ARCHITECTURE.md:384`) and reads "Nothing is over the cap today", naming 1079 as the largest.
  It agrees with the tree. The kit gate `test_layout_cap` is declared `{ name = "test_layout_cap", dir
  = "tests/_kit/" }` (`tests/run.lua:173`) and is green.
- Media: `media/logos/absorbtracker.logo.128.tga` is TGA type 2, 128×128, 32 bpp (header bytes
  `0 0 2 … 128 0 128 0 32`); the landing-page `absorbtracker.logo.tga` sits beside it. No private copy
  of a library font, icon or texture under `media/`.

## TOC (`toc-file`)

- Field order matches toc-file-§1 (`AbsorbTracker.toc:1-13`). `## IconTexture` names the addon's own
  128 TGA (`:6`). `## X-Curse-Project-ID: 1450165` (`:13`) is real and matches the README badge.
  `## SavedVariables: AbsorbTrackerDB, AbsorbTrackerPerfDB` (`:7`): two, the harness is wired.
- `# Libraries` lists `libs\LibKa0s\LibKa0s.xml` once, after Ace3 (`:29`).
- Section headers in mandated order (`:15`, `:34`, `:37`, `:71`, `:74`, `:82`).
- **Core block annotations:** `MediaSetup` (`:41-42`), `Namespace` (`:45`), `Bus` (`:50`),
  `CoreSetup` (`:52`), `Lifecycle` (`:54-56`), `PerfSetup` (`:58`) and `Units` (`:61`) carry
  load-bearing comments naming what resolves; `EnvSetup` (`:38-39`), `State`/`Data`/`Database`
  (`:47-48`) and `LauncherSetup` (`:65-67`) carry conventional notes. **Settings block:**
  `settings\Schema.lua` (`:83`) and `settings\OptionsSetup.lua` (`:85`) are load-bearing (see
  `AT-84`, `AT-85`) and carry no comment; the only note is the section header's "last — depend on
  everything else being initialized" (`:82`).

## Library stack (`library-stack`)

- Provenance: `CLAUDE.md:43` reads `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s)
  v1.70.0 (MIT).` — once, and not in `README.md`.
- **Vendored payloads match tag v1.70.0** (`26f441a`): `diff -r` of `git archive v1.70.0 LibKa0s` vs
  `libs/LibKa0s` and of `testkit` vs `tests/_kit` are both empty (159 and 22 files each side).
  `tests/_kit/run-automated-tests.sh` is tracked `100755`. Kit `VERSION = 37`.
- **Seams (descriptor + stub):** `core/CoreSetup.lua` (Core, stub `:28-118`), `core/EnvSetup.lua`
  (Env, call-time fallback), `core/MediaSetup.lua` (Media), `core/Lifecycle.lua` (Lifecycle, hold-set
  stub `:152-190`), `core/Bus.lua` (Bus), `core/PerfSetup.lua` (Perf, stub `:17-33`),
  `core/DebugLogSetup.lua` (DebugLog, stub `:16-100`), `core/LauncherSetup.lua` (Launcher, stub
  `:81-105`), `settings/Schema.lua` (Schema, runtime-completing host stub), `settings/Slash.lua`
  (Slash), `settings/OptionsSetup.lua` (Options, load-completing stub `:220-332`).
- **`LibKa0s-Widgets-1.0` has no seam:** it is looked up twice, at `modules/Bar.lua:15` and
  `modules/Display.lua:26`, with inline nil-guards and no stub table (`AT-88`). Compat, Pool and Item
  are vendored and unread.
- No hand-rolled console, widget maker, dispatcher or harness (#47 clean). The LSM30_Border fix-up is
  the library's member, called once (`settings/OptionsSetup.lua:370`, library-stack-§9).

## Architecture, bus, events (`architecture`, `events-frames-taint`)

- AceAddon over `NS` (`core/AbsorbTracker.lua:12-14`); `NS.Print` reclaimed from AceConsole (`:25`).
- Bus: five messages declared once in `core/Bus.lua:116-120`, PascalCase tails, no call-site literal
  (the two greps return no `Send/RegisterMessage("Ka0s_` literal). Tracked receivers through
  `LibKa0s-Bus-1.0`.
- Event registration: every call goes through `NS.SafeRegisterEvent` / `NS.SafeRegisterUnitEvent`
  (`core/AbsorbTracker.lua:143-149`); rejected names land in `NS.State.rejectedEvents`, are logged once
  through `DebugOnce` (`:138-141`) and are readable through `/at debug events` and the `[Init]` line.
- Per-unit frames: three private `CreateFrame("Frame")` whose only job is `RegisterUnitEvent`, held on
  `addon.__unitEventFrames`, unregistered in `StandDown` (`core/Lifecycle.lua:104`), reused — the
  events-frames-taint-§1 carve-out, compliant, no row needed.
- Secret values: `traceAbsorb` probes with `NS.IsConcatSafe` before comparing (`:241-260`).

## Settings, schema, SavedVariables (`savedvariables`, `options-ui`)

- `defaults/Profile.lua`: global `schemaVersion = 0`; a per-profile `schemaVersion = 1` for the v3 lift.
  `core/Database.lua`: runner `NS:RunMigrations` (`SCHEMA_STEPS` to v5), the runner owns the stamp,
  profile-scoped steps walk every stored profile through `forEachProfile`, and the v3 lift also runs
  from all three AceDB profile callbacks against the per-profile stamp (`core/AbsorbTracker.lua:359-417`).
  That is now a route savedvariables-§1 sanctions by name (v2.65.0), which is why the register row for
  it is stale (`AT-86`).
- Options descriptor passes `addonName` (`settings/OptionsSetup.lua:82`, options-ui-§1, v2.75.0) and
  `debug` (`:85`). Pages: General (`Master controls`, `Bars`), Appearance (`Size`, `Bar`, `Background`,
  `Border`, `Text`), About (landing, exempt), Profiles (AceConfig, exempt). `Master controls` first and
  composed; no Test mode row (lock is the preview, options-ui-§15). No `disabledIf` on a color row, no
  reorder arrows, no hand-written font/border/bar group, one unboxed chrome block, no host second
  combat lock, and no host close of `SettingsPanel` (the only hit, `modules/Diagnostics.lua:295`, reads
  `IsShown`).
- Minimap row at `global.minimap.shown` inverting onto `minimap.hide`, vetoed from every sweep
  (`settings/OptionsSetup.lua:61-69`).
- Write paths: no assignment into the stored tree outside the helper and the load pass; drag position
  is named non-setting state (`docs/ARCHITECTURE.md:136-138`).

## Slash surface and the disabled state (`slash-commands`)

- `NS.COMMANDS` (`settings/Slash.lua:71-131`): 19 verbs — `help`, `config`, `enable`, `disable`, `list`,
  `get`, `set`, `reset`, `resetall`, `resetposition`, `lock`, `unlock`, `toggle`, `debug`,
  `diagnostics`, `perf`, `update`, `version`, `profile`. No `test` verb.
- `enable`/`disable` write the `enabled` path through `NS.SetByPath`; `lock`/`unlock` (a MAY) write
  `locked` through the same seam.
- **Disabled state:** one latch with two holds (`core/Lifecycle.lua`); `StandDown` cancels the
  pending repaint and the preview hold, publishes `VISIBILITY` so the ladder hides the bars, unregisters
  the per-unit frames and the five AceEvent events, then the bus record (`:87-115`). Registration
  census: every `Register*` in the addon's Lua has its undo in `StandDown` (03, §Disabled). The
  `OnEnterCombat` SavedVariables write (`core/AbsorbTracker.lua:318-322`) cannot fire while disabled,
  because `PLAYER_REGEN_DISABLED` is unregistered. The dispatcher's `liveVerbs` is built on
  `SlashLib.LIVE_VERBS` (`settings/Slash.lua:759-761`); feature verbs refuse on the library's line.
  `tests/test_disabled.lua` (18 cases) asserts on the recording mock's registration set and dispatches
  both diagnostics forms.

## Launcher (`launcher`)

- One object (`core/LauncherSetup.lua:107-167`), label `NS.Constants.BRAND` ("Ka0s Absorb Tracker"),
  icon the 128 TGA, `isEnabled`/`setEnabled` and `isLocked`/`toggleLock` routed to the verbs' own
  handlers through `runVerb` (`:63-68`), `version` for the tooltip, `debug` and `debugAtEnable`
  passed. No host `OnTooltipShow`, no host menu. Matches `ADDONS.md`'s *Enabled · Locked*.

## Debug console and diagnostics (`debug-logging`)

- `core/DebugLogSetup.lua:123-185`: `name`, `addonName`, `title`, `font`, `slash`, call-time
  `isEnabled`/`setEnabled`, `print`, `safeToString`, `initSummary`, `onVisibilityChanged`, `brandName`,
  `diagnostics`, `L = { DIAG_WRITTEN = … }`. **No `onClear`.** `diagnosticsEnablesLogging` not set
  (default: the run turns logging on, documented in `docs/debug.md:15`, `:59-65`).
- `diagnostics` is one `COMMANDS` row (`settings/Slash.lua:119`) and the first word `runDebug` tests
  (`:377`); no `diag`/`dump`/`dx` alias; no host `SetEnabled` around `RunDiagnostics`; the stub answers
  `RunDiagnostics` with the library-absent line (`core/DebugLogSetup.lua:34-40`).
- Library lines: Slash (`settings/Slash.lua:722`), Options (`settings/OptionsSetup.lua:85`), Launcher
  and Lifecycle (`core/Lifecycle.lua:201`) all receive the gated sink; the Launcher's `debugAtEnable`
  goes to the console's queue. Host stand-down/up lines add only what the library cannot know.
- Two hand-rolled log-on-change memos survive (`AT-87`).
- README `## Reporting a bug` (`README.md:110-116`) is verbatim with `/at`, bulleted.

## Tests, lint, complexity (`testing`, `lint`, `automated-tests`, `performance`)

- `lua tests/run.lua`: **876 passed, 0 failed, 1 skipped, 877 total** (the skip is the kit's
  diagnostics opt-out case, which this addon does not take). `docs/test-cases.md` regenerates
  byte-identically; README badge `876/876`.
- `luacheck .`: **0 warnings / 0 errors in 69 files**. `exclude_files` narrows to `tests/_kit/` (plus
  `libs/`, `docs/audits/`, `docs/reviews/`, `_dev/`), the harness global sits in `files["tests/"]`,
  no top-level `ignore`.
- Sighted complexity (`bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle`):
  **pass, 0 warnings, max CCN 14, 2219 functions, 14 461 NLOC**. `test_lizard_sighted` wired
  (`tests/run.lua:176`). Newest bundle `20260927-030336` (release 1.11.0) measured `9b5a369`, **57
  commits** behind HEAD, recorded before kit 35 (no `blindFiles` key) — unsighted; the next release
  run is the sighted one.
- `docs/automated-tests/README.md:29` still quotes raw `lizard` as the complexity suite's command
  (`AT-83`).
- Watch list: `tests/test_slashcmds.lua` (now 1079, was 1321 at the bundle) and
  `tests/test_widgets.lua` (1073, *Accepted* for one release run). No function warned. No #53 shelf
  life reached.
- Perf harness wired (`core/PerfSetup.lua`), `AbsorbTrackerPerfDB` declared, the latch carried in the
  descriptor (no second teardown path).

## Packaging and line endings (`packaging`, `line-endings`)

- `.pkgmeta`: every named dev entry and every root dot-entry ignored except `.git` (needs none); no
  false conditional line (`.claude` and `.superpowers` exist on disk).
- `.gitattributes` (verbatim pin `* text=auto eol=crlf`, `.gitattributes:26`; `*.sh text eol=lf` `:36`;
  `*.py text eol=lf` `:37`; 20 `binary` lines). Its 84 lines are byte-identical to the canonical
  client-bound body (`line-endings-§5`), no appendix. Working-tree check (e) over all **637** tracked
  files returns **0**. `test_eol` is wired from `tests/_kit/` (`tests/run.lua:169`).

## Root docs and `docs/` (`documentation`)

- Root ships `README.md`, `CLAUDE.md`, `DEPENDENCIES.md`, `LICENSE`. No `CHANGELOG.md`, no `TODO.md`,
  no `docs/agent-context.md`, no `docs/pending/`.
- README: H1, five badges in order with the bare `![Standard](…)` (`README.md:3-7`), no logo image,
  no numbered list outside a fence, no library inventory, `## Credits` holds external credit only.
- `CLAUDE.md`: stub shape, `## Standards compliance (read first)`, doc pointers, green gate, provenance.
- `docs/ARCHITECTURE.md` (406 lines): ten mandated sections; `## Documentation map` (`:309`) with four
  tables — Required (6), Conditional (7: six *Present*, `compat-layer.md` *Not applicable* citing
  compat's v2.65.0 condition), Verification and record (exactly the six), Addon-specific (`lifecycle.md`,
  `launcher.md`, `recorded-decisions.md`). **22** `.md` files under `docs/` outside the frozen stores;
  21 rows plus the hub, which is not registered (a MAY) — every file maps once, no dangling row.
  Tier 2 triggers match the code (19 verbs and a `profile` sub-tree; five messages; profiles page;
  diagnostics; harness wired; own client-version workarounds). No non-canonical or retired filename.
- **Doc/code drift** after the v1.69.0 and v1.70.0 re-vendors and older (`AT-80`).

## Register and issue store (`audit-review-history`)

- `## Documented deviations` (`docs/ARCHITECTURE.md:365-377`), three rows:
  `savedvariables-§1` (2026-07-28) — **stale since v2.65.0**, filed for retirement as `AT-86`;
  `events-frames-taint-§8` SHOULD half (2026-08-05) — accepted, trigger not fired, count 17 re-measured
  correct; `localization-§1` (2026-08-05) — accepted, trigger not fired (only `locales/enUS.lua`).
  Evidence ids `AT-30` and `AT-35` resolve in `docs/audits/2026-08-05/02_DEVIATIONS.md`; issue #24
  exists.
- Issue store (`gh issue list --state all`): 33 issues, labels only (`state:*` + `severity:*`), no
  `[status]` title prefix, no LEDGER. Eight open `state:triaged` feature requests; eight
  `state:will-not-do` (#16, #21, #22, #23, #26, #27, #28, #31) — none declines a rule of the standard.
- Re-vendor store: horizon 2026-08-25; **v1.69.0 and v1.70.0 have no bundle** (`AT-82`).

## Recorded checks that file nothing

- Close-button grep: no host `MakeCloseButton(` call; the addon builds no close control.
- `Interface\` paths in `core/Constants.lua:7-8` are the LSM-failure fallback ladder
  library-stack-§8 requires a caller to have; `:38`, `:54` are the addon's own logos.
- Register decline of a close-button wrapper: not applicable (no host window).
