# 01 — Current State

**Addon:** Ka0s Absorb Tracker (`AbsorbTracker`), version `1.10.0` (`AbsorbTracker.toc:5`).
**Audited against:** Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**, line 1 of
`standards/STANDARDS.md` on `master`. Fetched with `curl -fsSL` from
`https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master` and read verbatim.
**All 27 section files** linked from the index's **Sections** list were fetched and read, and none is
left unassessed. `AUDIT.md` (990 lines) and `standards/ADDONS.md` were fetched the same way.
**Repo kind:** **Addon.** The repo carries `AbsorbTracker.toc`, and `ADDONS.md` lists it in *In-scope
addons* with launcher rung **(b) lock / unlock**. The whole addon rule set applies. The
library-stack-§7 and documentation-§8 applicability lists do not.
**Commit audited:** `8f64eb6c4ec3938919de42f9d8182c683c07ff11`, on branch
`feat/2026-09-23-review-audit-remediation` (the orchestrating run checked it out). The working tree
was clean at the start of the run.
**Run date:** 2026-09-23. **Bounded runner:** `/home/tushar/.claude/wow-addon/bin/ka0s-bounded`
exists on this machine, and every lint, suite and lizard run went through it. The `timeout 900`
fallback the task mentioned was never needed.

This is a **read-only measurement**. The only files it writes are the five in this folder.

**Deviation IDs:** prefix `AT-`. The prior bundle was `docs/audits/2026-09-08/`, and its highest ID
was `AT-68`. Deviations that recur keep their IDs (`AT-60`, `AT-62`, `AT-63`, `AT-64`, `AT-65`,
`AT-67`). New IDs in this run start at `AT-69`.

---

## Why the result differs from 2026-09-08

The previous audit measured against v2.39.0. Twenty-five versions have shipped since, and several of
them added checks this addon had never been measured against:

- the re-vendor bundle check (`audit-review-history`, *A re-vendor commit implies a bundle*);
- the per-event `pcall` registration MUST, and the `RegisterUnitEvent` carve-out (`events-frames-taint-§1`);
- the stated denominator for load-bearing TOC positions (`toc-file-§5`);
- the options-ui-§1 fall-together bound on the hollow-composer exemption;
- the Test-mode exemption's "no `test` verb" clause (`options-ui-§15`, `preview-mode`);
- the census and cap gate (`layout-§1`), which **this addon already satisfies**.

The addon has also changed a lot since then. It re-vendored LibKa0s from v1.27.0 to v1.55.0 and
adopted the Lifecycle latch, the launcher, the Bus record and the Schema runtime. The test count went
from 562 to 710.

---

## Layout (`layout`)

- The modular skeleton is in place: `core/` (14 files), `defaults/Profile.lua`, `modules/`
  (`Bar`, `Display`, `Timer`), `settings/` (8 files), `locales/enUS.lua`, `media/logos/`,
  `media/screenshots/`, `libs/`, `tests/`, `docs/`. There is no `tools/` directory, and
  `git ls-files '*.py' '*.sh'` outside `libs/` and `tests/_kit/` returns nothing, so there is no
  authored generator to place.
- **Census scope:** 61 authored `.lua` files (28 source + 33 under `tests/`, `tests/_kit/` excluded).
  Largest: `tests/test_helpers.lua` at 1416 lines. **Nothing is over the 1500-line cap.**
  Two files sit in the 1000–1500 band: `tests/test_helpers.lua` (1416) and `tests/test_slashcmds.lua`
  (1304, peeled into `tests/test_perfcmds.lua` since the last automated-test run).
- The census heading `### Files over the 1500-line cap` sits under `## Documented deviations` at
  `docs/ARCHITECTURE.md:718` and reads "Nothing is over the cap today". The kit gate
  `tests/_kit/test_layout_cap.lua` is declared `{ name = "test_layout_cap", dir = "tests/_kit/" }`
  (`tests/run.lua:131`). All 13 of its cases pass.
- Media: `media/logos/` holds `absorbtracker.logo.128.tga` (TGA type 2, 128×128, 32 bpp, 65 580 bytes),
  the landing-page `absorbtracker.logo.tga`, and the `.png` and `.jpg` sources. `media/screenshots/`
  holds one screenshot. There is no private `fonts/`, `icons/` or `textures/`.

## TOC (`toc-file`)

- The field order is exact (`AbsorbTracker.toc:1-13`). `## Interface: 120100` is a single value.
  `## IconTexture` names `Interface\AddOns\AbsorbTracker\media\logos\absorbtracker.logo.128.tga`.
  `## SavedVariables: AbsorbTrackerDB, AbsorbTrackerPerfDB` (two, because the perf harness is wired).
  `## X-License: MIT`, `## X-Standard`, and `## X-Curse-Project-ID: 1450165` (the addon is published).
- Section headers are in order: Libraries → Locales → Core → Defaults → Modules → Settings. There is
  one `libs\LibKa0s\LibKa0s.xml` line (`:29`), after the Ace3 block. The file ends with a single
  CRLF newline.
- Annotated positions: `core\EnvSetup.lua` (conventional, `:38-40`), `core\MediaSetup.lua`
  (load-bearing, `:41-43`), `core\Lifecycle.lua` (load-bearing, `:49-52`) and `core\LauncherSetup.lua`
  (`:58-61`). Five load-bearing positions are **unannotated**: `core\Namespace.lua` (`:45`),
  `core\Bus.lua` (`:47`), `core\CoreSetup.lua` (`:48`), `core\PerfSetup.lua` (`:53`) and
  `core\Units.lua` (`:55`). See `AT-64`, `AT-65`, `AT-69`, `AT-70` and `AT-71`.

## Libraries (`library-stack`)

- Vendored: LibStub, CallbackHandler, AceAddon, AceEvent, AceTimer, AceConsole, AceDB, AceGUI,
  AceConfig, AceDBOptions, LibDataBroker-1.1, LibDBIcon-1.0, LibKa0s, LibSharedMedia-3.0 and
  AceGUI-3.0-SharedMediaWidgets (`AbsorbTracker.toc:17-31`).
- **Provenance:** `CLAUDE.md:43` reads `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).`
  `README.md` carries neither the line nor a library inventory.
- **`diff -r` against the sibling `../LibKa0s` at tag `v1.55.0` returns nothing** for both
  `LibKa0s/` → `libs/LibKa0s/` (146 files on each side) and `testkit/` → `tests/_kit/` (11 files on
  each side). `tests/_kit/run-automated-tests.sh` is recorded `100755`.
- Wired LibKa0s seams. Each has a setup file and a degradation stub:
  - Core: `core/CoreSetup.lua`.
  - Env: `core/EnvSetup.lua`, a guarded function with no stub table.
  - Media: `core/MediaSetup.lua`, a guarded function.
  - Lifecycle: `core/Lifecycle.lua`, a hold-set stub.
  - Bus: `core/Bus.lua`, the untracked-target stub.
  - Perf: `core/PerfSetup.lua`.
  - DebugLog: `core/DebugLogSetup.lua`.
  - Launcher: `core/LauncherSetup.lua`.
  - Schema: `settings/Schema.lua`, the runtime-completing stub citing `docs/api/Schema/version-1-docs.md`.
  - Options: `settings/OptionsSetup.lua`, the load-completing stub.
  - Slash: `settings/Slash.lua`.
  - Widgets is bound without a seam (`modules/Bar.lua` DragHandle).
  - Compat, Pool and Item are vendored and not read. Issues #31, #28 and #27 decline them.
    library-stack-§7 makes adoption optional, so these need no register row.
- `library-stack-§9`: there is no private `LSMPatch.lua`. The one re-registration is the library's
  own `lib.__PatchLSM30Border()` (`settings/OptionsSetup.lua:493`).
- `compat`: **there is no `core/Compat.lua`.** The deprecated `GetAddOnMetadata` rung lives in
  `core/EnvSetup.lua`'s fallback (`AT-77`).

## Architecture (`architecture`)

- `NS` is promoted to AceAddon at `core/AbsorbTracker.lua:12-14`, and `NS.Print` is reclaimed from
  AceConsole at `:25`.
- Bus: five messages are declared once through `Bus.Catalog` (`core/Bus.lua:114-120`), all
  `Ka0s_AbsorbTracker_<PascalCase>`, with no literal at any call site. Receivers are on tracked
  targets: `core/AbsorbTracker.lua:358`, `modules/Display.lua:454-460`, `modules/Timer.lua:81`.
- Schema: `NS.Schema` has 70 rows (`docs/ARCHITECTURE.md:120`). There is one write seam,
  `NS.SetByPath`, which is `LibKa0s-Schema-1.0`'s `Set` (`settings/Schema.lua`). There is no
  structural registry. `units.<unit>.position` and `AbsorbTrackerPerfDB` are named non-setting state
  (`docs/ARCHITECTURE.md:191-232`). The write-path grep finds only the load pass
  (`core/Database.lua:71-154`).

## Settings panel (`options-ui`)

- **General:** `[ Master controls | Bars ]`. Master controls is composed by `H.MasterControls`
  (`settings/General.lua:93-127`) and holds enable, visibility, scale, alpha, lock, debug console and
  minimap, then the button pair Reset position | Reset all settings. That is a subsequence of the
  canonical set. Test mode is omitted under the "unlocked view is the preview" exemption.
- **Appearance:** `[ Size | Bar | Background | Border | Text ]` under one chrome block: `PageHeader`
  with the Unit picker and the mirror controls, with no boxing (`settings/UnitPanel.lua`). Bar, Border
  and Font are composed by `BarGroup`, `BorderGroup` and `FontGroup`, and Background is composed by
  `ColorPair` (`settings/Appearance.lua:157-251`).
- **About:** the landing page, exempt. **Profiles:** AceDBOptions, exempt.
- `disabledIf` is on no row. There are no reorder arrows. The confirmation text is the canonical one
  (`settings/General.lua:325`). Reset all settings is `db:ResetProfile()` through `resetProfile`
  (`settings/OptionsSetup.lua:125-128`). The minimap row survives both resets (`resetExempt`).
- The `#88` grep finds no host call to `SettingsPanel`, `HideUIPanel`, `ToggleGameMenu` or
  `OpenToCategory` outside `libs/`.
- **Options stub:** it still carries **host copies of all five composers**
  (`settings/OptionsSetup.lua:237-377`, `AT-62`).

## Slash (`slash-commands`)

- There are 19 verbs in `NS.COMMANDS` (`settings/Slash.lua:61-113`), registered as `/at` and
  `/absorbtracker` through AceConsole (`:645-648`). The dispatcher is `LibKa0s-Slash-1.0`. The
  disabled gate is the library's (`isEnabled`, `brandName`, `liveVerbs`, `:567-595`).
- `enable` and `disable` write `enabled` through `NS.SetByPath` (`:310-317`). `lock` and `unlock`
  write `locked` (`:89-98`).
- **`test` is a verb** (`:109-110`). It holds a fake value for a few seconds, in an addon whose
  unlocked view is its preview (`AT-76`).

## Disabled state (`slash-commands-§7`)

- **One latch:** `NS.lifecycle`, from `LibKa0s-Lifecycle-1.0` (`core/Lifecycle.lua:178-186`). The
  `disabled` hold comes from the stored path (`NS.SyncEnabledHold`, `:208-210`). The `perf` hold is
  taken by Perf 12 through `lifecycle = NS.lifecycle` (`core/PerfSetup.lua:88`). There is no second
  teardown.
- **Registration census:**
  - 5 AceEvent registrations (`core/AbsorbTracker.lua:120-122`, `:176`, `:181`);
  - 2 `RegisterUnitEvent` per unit frame (`:164-165`), on 3 frames held at
    `addon.__unitEventFrames`;
  - 5 `RegisterMessage`.
  - Every one of them is undone in `StandDown` (`core/Lifecycle.lua:95`, `:98`, `:105`).
  - Both timers are canceled (`:83-84`).
  - Bars are hidden at the source: rung 0 of `NS.ShouldShowBar` asks `NS.IsStoodDown()`
    (`modules/Display.lua`, `function NS.ShouldShowBar`).
- **No SavedVariables write from a game event while disabled.** `PLAYER_REGEN_DISABLED` is not
  registered while the latch is down.
- `tests/test_disabled.lua` (15 cases) asserts on the **mock registration set**. Steps 3, 6 and 10
  carry `red under:` comments. Step 7 pins the restored v2.57.0 surface, including the bare `/at`.
  Step 8 pins the refused left click.

## Launcher (`launcher`)

- There is one LDB object, `type = "launcher"`, named `AbsorbTracker` (the folder vararg). Its
  `label = NS.Constants.BRAND` ("Ka0s Absorb Tracker") and its icon is the 128 TGA
  (`core/LauncherSetup.lua:99-169`).
- Rung (b): left-click toggles `locked` through `NS.SetByPath`, and while disabled it refuses on the
  dispatcher's line (`:160-163`). Right-click opens the panel.
- The visibility row is `global.minimap.hide`, inverted by `NS.MinimapShown` and
  `NS.SetMinimapShown` (`core/Data.lua:67-89`).

## Debug (`debug-logging`)

- `NS.DebugLog` is built with `name`, `addonName`, `title`, `font = NS.Constants.FONT_MONO`, `slash`,
  `isEnabled` / `setEnabled` over `NS.State.debug`, call-time `print` / `safeToString` and
  `initSummary` (`core/DebugLogSetup.lua:72-116`). The stub flips the flag and prints the ack
  (`:33-68`).

## Tests, lint, complexity (`testing`, `lint`, `automated-tests`, `performance`)

- `luacheck .`: **0 warnings / 0 errors in 61 files**. `exclude_files` is
  `{ "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`
  (`.luacheckrc:13`). There is no top-level `ignore`. `AT_TEST` is declared in
  `files["tests/"]` (`:67-75`).
- `lua tests/run.lua`: **710 passed, 0 failed, 0 skipped, 710 total**. `docs/test-cases.md` is
  identical to a fresh `--list`. The README badge reads `710/710`.
- Kit revision 25 suites are wired with an explicit `dir`: `test_prose`, `test_eol` and
  `test_layout_cap` (`tests/run.lua:116`, `:127`, `:131`).
- `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` (lizard 1.24.0) reports **no thresholds
  exceeded**: NLOC 11389, 1639 functions, average CCN 1.7, 0 warnings.
- **Newest automated-test bundle:** `docs/automated-tests/20260916-184524/` at `1080857`, 37 commits
  behind HEAD. It recorded 635 tests, NLOC 10555 and 1479 functions. The last release bundle is
  `20260910-234511` (`"release": "1.10.0"`, max CCN 15, 0 warnings, and it has an `ANALYSIS.md`).
- Perf: wired. The buckets are `absorbEvent`, `repaintPass`, `paintBar` (inside `repaintPass`),
  `appearance`, and `visibility` (inside `appearance`) (`core/PerfSetup.lua:61-74`). `tests/perf.lua`
  exists. `docs/perf-analysis/` holds 2 bundles, each with `report.md`, `dump.json` and `ANALYSIS.md`,
  plus a `README.md`.

## Packaging (`packaging`)

- `.pkgmeta` ignores `docs`, `tests`, `_dev`, `.luacheckrc`, `.gitattributes`, `.gitignore`,
  `.pkgmeta`, `*.bak`, `.claude`, `.superpowers`, `media/screenshots`, `CLAUDE.md`, `DEPENDENCIES.md`
  and the logo sources. Enumerating every root dot-entry leaves only `.git`. There is no false
  conditional line and no `externals:`.

## `.gitattributes` (`line-endings`)

- **The pin, verbatim:** `* text=auto eol=crlf` (`.gitattributes:26`), with `*.sh text eol=lf` and
  `*.py text eol=lf` (`:36-37`) and 20 `binary` marks.
- **The 84-line body diffs clean against `line-endings-§5`'s client-bound canonical file**, and there
  is no appendix.
- The working-tree check (e) returns **0**. `tests/_kit/test_eol.lua` (revision 25, both cases) is
  wired and green.

## Root docs (`documentation-§1/§2/§7`)

- **README:**
  - H1 `# Ka0s Absorb Tracker`.
  - The badge row is the canonical five in order. The standard badge is bare (`README.md:6`).
    `[wow]` reads `Midnight_12.1.0`, which matches `120100`. `[tests]` reads `710%2F710`.
  - No logo image. No library inventory, heading or prose. No `## Credits`.
  - Sections: Screenshots, Usage (prose, closing with the config signpost), How the bar works, FAQ,
    Troubleshooting, Issues and feature requests, Version History (`- `-prefixed highlights).
- **CLAUDE.md** is the stub, in order:
  - H1;
  - the adherence line;
  - `## Standards compliance (read first)`;
  - the docs pointers;
  - the green-gate line;
  - the provenance line.
- **DEPENDENCIES.md** has Runtime, Development (Lua 5.1 with its reason, luacheck, lizard via `pipx`
  with the PEP 668 note, git, sibling `../LibKa0s`, POSIX shell, `diff`) and Release / assets.
  Each tool has a verification command.

## `docs/` (`documentation-§3`)

- **Tier 1 is present under the exact names:** `scope.md`, `module-map.md`, `schema.md`,
  `settings-panel.md`, `data-flow.md`, `common-tasks.md`.
- **Tier 2:**

  | Doc | Status | Trigger |
  |---|---|---|
  | `slash-dispatch.md` | Present | 19 verbs and the `profile` sub-tree |
  | `midnight-quirks.md` | Present | the addon has client-version workarounds |
  | `profiles.md` | Present | the Profiles page |
  | `perf-analysis/README.md` | Present | the harness is wired |
  | `message-bus.md` | *Not applicable* | 5 messages |
  | `compat-layer.md` | *Not applicable* | the file is absent, so 0 shims |
  | `debug.md` | *Not applicable* | no debug surface of the addon's own |

  Every status matches the code.
- **`## Documentation map`** (`docs/ARCHITECTURE.md:589`) has Required, Conditional and
  `### Verification and record` (six rows, exact). There is no Addon-specific table, because there is
  no Tier 3 doc. **16 `.md` files map to 16 rows**, with no orphan and no dangling row. The hub's
  self-row is absent, which is a MAY and not filed.
- There is no `file-index.md`, `conventions.md`, `complexity.md`, `perf-runs/`, `agent-context.md`,
  `TODO.md`, `CHANGELOG.md` or `docs/pending/`.
- **The hub is 788 lines.** `## Settings Schema` runs 116 lines (`:118-233`) and `## Message Bus`
  runs 73 lines (`:234-306`). Both are past the ~60-line spill threshold (`AT-75`).

## Deviation register (`documentation-§3`, `audit-review-history`)

The register at `docs/ARCHITECTURE.md:650-655` has four rows. Each was checked three ways: is the
cited rule still the same, has the trigger fired, and do the cited ids resolve.

| Rule | Row | Status this run |
|---|---|---|
| `events-frames-taint-§1` | per-unit `CreateFrame` + `RegisterUnitEvent` | **Cited rule has changed.** The v2.64.0 carve-out now permits exactly this shape, and all its conditions hold, so the row is filed for retirement (`AT-73`) |
| `savedvariables-§1` | per-profile `schemaVersion` | **Accepted.** Rule unchanged. Trigger not fired (`MigrateProfileToV3`, `core/Database.lua:59`, still live) |
| `events-frames-taint-§8` (SHOULD half) | pre-formatted chat lines in `Slash.lua` and `Schema.lua` | **Accepted.** Trigger not fired. The row's own count re-measures at 17, not 18, and three sites outside its scope are unrecorded (`AT-78`) |
| `localization-§1` | English only | **Accepted.** `localization-§3`'s terminal state. Trigger not fired (`locales/` holds `enUS.lua` only). `AT-30` and #24 resolve |

## Issue store (`audit-review-history`)

- `gh issue list --state all`: 31 issues. Every one carries one `state:` label and one `severity:`
  label. No title has a `[status]` prefix. There is no `docs/pending/LEDGER.md`.
- The will-not-do issues are #16, #21, #22, #23, #26, #27, #28 and #31. None of them declines a
  rule of the standard, so none owes a register row.
- #26 (Widgets declined) is stale: Widgets is now bound. #25 is open over a condition that no longer
  exists. Both are Info.

## Re-vendor history (`audit-review-history`)

- The horizon is 2026-08-25. **31 distinct tags** have been vendored since, read from `CLAUDE.md` at
  each `libs/LibKa0s` commit (32 commits). The nine bundles record 9 tags, and 7 of those are in the
  vendored set. **24 vendored tags have no bundle** and no register row (`AT-72`).
