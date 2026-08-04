# 01 — Current State

**Run:** `/wow-addon:standards-audit`, 2026-08-04.
**Repo:** `AbsorbTracker` (Ka0s Absorb Tracker), whole repo.
**Head:** `9899026 docs+i18n: complete the v2.17.1 dialect sweep` (working tree clean apart from an
untracked `docs/reviews/2026-08-03/`).
**Audited against:** **Ka0s WoW Addon Standard v2.17.1 (2026-08-03)**.

This audit is **read-only**. No addon source, TOC, config, doc or test was modified; the only files
written are the five artifacts in this folder.

## Standard provenance

The rules were fetched **from the raw URL**, not reconstructed:

```
$ curl -fsSL --max-time 20 https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/AUDIT.md
$ curl -fsSL --max-time 20 .../standards/STANDARDS.md
$ for f in <the 24 files linked from STANDARDS.md's Sections list>; do
      curl -fsSL --max-time 10 .../standards/standards/$f.md ; done
```

All 24 section files linked from `STANDARDS.md`'s **Sections** list downloaded successfully, plus
`AUDIT.md` and `STANDARDS.md`. Each was then diffed against the local canonical checkout at
`/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards`
(clean tree, `2141229 v2.17.1 — finish the v2.17.0 rollout: no fourth slot, no drop-in imperative`):

```
$ diff -r <checkout>/standards/standards <fetched>/std     # no differences
$ diff <checkout>/standards/STANDARDS.md <fetched>/STANDARDS.md   # identical
$ diff <checkout>/AUDIT.md <fetched>/AUDIT.md                     # identical
```

**Every section of the standard was read in full before judging compliance.** No section is
unassessed. Section references below use the `filename-§N` form the standard mandates; the retired
global `§N.M` notation appears nowhere in this bundle except where it is quoted as evidence of a
finding.

**One inconsistency inside the standard itself, recorded rather than charged to the addon.**
`layout-§1` orders the load as *core → defaults → locales → settings → modules*, while
`toc-file-§5`'s normative template and its MUST order the TOC's `#` sections as
*Libraries → Locales → Core → Defaults → Modules → Settings*. The two disagree about where locales
and modules sit. The addon follows `toc-file-§5` (which carries the explicit MUST and the template),
so it is recorded compliant, not deviant.

## Deviation-ID continuity

The addon's prefix is **`AT-`**, assigned in `docs/audits/2026-07-12/` and reused in
`docs/audits/2026-07-18/` (highest prior ID `AT-31`). Recurring deviations keep their IDs
(`AT-30`, `AT-31`); new ones start at `AT-32`.

---

## Snapshot, section by section

### layout

Modular layout, exactly as `layout-§1` describes: `core/` (13 files), `defaults/` (1), `locales/`
(1), `modules/` (3), `settings/` (10), plus `libs/`, `tests/`, `docs/`, `media/`.
No source sits loose at the root. Folder casing is lowercase throughout, `libs/` included; Lua files
are PascalCase (`layout-§2`).

Largest file is `settings/Slash.lua` at **471 LOC** — the whole addon is 3,630 LOC across 28 own
files, so the 1500-LOC cap is not in sight.

Media is in typed subfolders (`layout-§3`): `media/fonts/` (JetBrainsMono-Regular.ttf + OFL.txt),
`media/logos/` (`.tga` runtime + `.jpg` source), `media/screenshots/` (4 PNGs). Nothing loose in
`media/`.

`docs/` carries `audits/` and `reviews/` histories.

### toc-file

`AbsorbTracker.toc` metadata block is in the exact `toc-file-§1` order: Interface, Title, Notes,
Author, Version, IconTexture, SavedVariables, OptionalDeps, DefaultState, Category-enUS, X-License,
X-Standard, X-Curse-Project-ID. `X-Wago-ID` / `X-WoWI-ID` are omitted, which v2.x makes a **MAY** —
the addon publishes on CurseForge only. Single `## Interface: 120007`. No `Dependencies`.

Exactly two SavedVariables globals in order — `AbsorbTrackerDB, AbsorbTrackerPerfDB` (`toc-file-§2`,
`savedvariables-§4`). File listing uses `#` section headers in the mandated
Libraries → Locales → Core → Defaults → Modules → Settings order, wraps the lib block in
`#@no-lib-strip@`, lists `libs\LibKa0s\LibKa0s.xml` once after Ace3, and puts `core\PerfSetup.lua`
ahead of every consumer. File ends in a single trailing CRLF.

### library-stack

All mandatory libs vendored and committed: LibStub, CallbackHandler-1.0, AceAddon-3.0, AceDB-3.0,
AceEvent-3.0, AceTimer-3.0, AceConsole-3.0, AceGUI-3.0. Optional: LibSharedMedia-3.0,
AceGUI-3.0-SharedMediaWidgets, AceDBOptions-3.0 + AceConfig-3.0 (Profiles page only — the one
sanctioned AceConfig use, `options-ui-§3`). No lib fork; the one AceGUI adjustment goes through
`AceGUI:RegisterWidgetType` (`core/LSMPatch.lua`), which is exactly what `library-stack-§5`
prescribes. No suite dependency anywhere.

`libs/LibKa0s/` holds the whole ship folder — all 8 module files plus `LibKa0s.xml` and `LICENSE` —
and **`diff -r ../LibKa0s/LibKa0s libs/LibKa0s` is empty**. The vendored harness sits at
`tests/_kit/`, never under `libs/`, and **`diff -r ../LibKa0s/testkit tests/_kit` is empty**. No
partial vendoring, no local patch. See `03_EVIDENCE.md` for the commands and output.

### architecture

Every file opens `local addonName, NS = ...`; no `_G[addonName]`. AceAddon promotion in
`core/AbsorbTracker.lua:13` passes `NS` as the first arg, and **reclaims `NS.Print` from AceConsole's
`:Print` mixin immediately after** (`core/AbsorbTracker.lua:25`) — the `architecture-§2` /
anti-pattern #36 trap, handled the second of the two sanctioned ways, with the printer and
`NS.Util.print` deliberately the same function object.

Modules publish as `NS.<Module> = NS.<Module> or {}`. The closed message bus is real
(`core/Bus.lua`): five `Ka0s_AbsorbTracker_*` messages, each with one sender, every receiver on its
own `NS.NewBusTarget()` AceEvent embed (anti-pattern #32 avoided at
`modules/Display.lua:214`, `modules/Timer.lua:68`, `core/AbsorbTracker.lua:270`), all documented in
`docs/ARCHITECTURE.md`.

Schema-as-single-source is fully implemented: `settings/Schema.lua` owns `NS.Schema`, the single
write seam `NS.SetByPath`, dotted-path walkers, and a boot validator that walks every row's `path`
against `defaults/Profile.lua` and returns counts for the harness.

### savedvariables

AceDB tree at `AbsorbTrackerDB` (`core/Database.lua:8`), defaults declared only in
`defaults/Profile.lua`, account-wide `schemaVersion` in `db.global` with a real migration runner
(`NS:RunMigrations`, v2/v3/v4 steps, whole-store sweeps). `AbsorbTrackerPerfDB` is the second
top-level global, outside the AceDB tree, bounded ring — the one carve-out `savedvariables-§4`
sanctions. No third global.

The addon additionally carries a **per-profile** `schemaVersion` stamp; nothing in
`savedvariables` forbids a profile-level key, and the account-wide stamp required by
`savedvariables-§1` is present, so this is recorded as compliant with a rationale in
`docs/ARCHITECTURE.md`, not as a deviation.

### options-ui

Panel is `LibKa0s-Options-1.0`, wired from a descriptor in `settings/OptionsSetup.lua`.
`NS.Helpers` **is** the library instance (`settings/OptionsSetup.lua:190`), not a copy-across.
`get`/`set` route through `NS.GetSetting` / `NS.SetByPath` — the same seam the CLI uses.
`skipRestoreAll` and `afterRestoreAll` are supplied and the Profiles veto is named once and shared
with the stub. `colorDecode`/`colorEncode` are written out even though the shape matches the
default. The degradation stub is the documented **load-completing** exception, with the member set
determined by measurement (`LSMValues` only) and pinned by `tests/test_optionssetup.lua` and
`tests/test_perf.lua` — correct, and explicitly not to be flagged.

Landing page (`settings/About.lua`) renders logo → tagline → "Slash Commands" heading → one row per
`NS.COMMANDS` entry through the library's own formatter, and reads `Helpers.SECTION_HEADING_H` off
the instance rather than copying the constant. Combat gate lives inside the library; the addon wires
no second open path.

**One gap:** `settings/Profiles.lua` creates its AceGUI `SimpleGroup` inside the page builder, which
runs at category-registration time rather than in the panel's first `OnShow` — see AT-34.

### standalone-windows

N/A as a *window* surface: the addon's display is three non-secure movable bars, not a data browser.
Bar position and size persist in the profile; the debug console and perf panel are the library's
windows and take `LibKa0s-Core-1.0`'s `SKIN` / `ApplySkin` untouched (`core/DebugLogSetup.lua` passes
neither `skin` nor `applySkin`), so the normative Ka0s window edge is inherited rather than
re-drawn.

### preview-mode

`/at test [value] [seconds]` fills the visible bars with a placeholder value through the real render
path (`settings/Slash.lua:265`, honored by `modules/Display.lua:186`). There is **no** automatic
preview while the bars are unlocked — unlocking shows only a small unit label — and the verb is a
timed fill with no toggle-off. Both are SHOULD-level in `preview-mode`; recorded as AT-38.

### slash-commands

`LibKa0s-Slash-1.0` dispatcher built from a descriptor in `settings/Slash.lua:424`, registered
through AceConsole `:RegisterChatCommand` for `at` and `absorbtracker` (`settings/Slash.lua:468`).
`NS.COMMANDS` stays host-owned, 17 positional triples, and includes every reserved verb —
`help get set list reset resetall config version debug perf`. `reset` takes a path, not a page.
Cyan tag is one shared constant `NS.PREFIX = "|cFF00FFFF[AT]|r"` (`core/Namespace.lua:10`). The
degradation stub carries `OnSlash`, `PrintHelp`, `LandingRows`, `SetRowAnnotator` and each `Cli*`
verb, re-implements none of the library's rendering, and names the missing library per verb. A host
row annotator supplies the mirror note.

**One gap:** several host verbs build their line with `..` / `:format` before handing it to the
shared printer — see AT-35.

### localization

`NS.L` exports with a key-returning metatable (`locales/enUS.lua:6`), `enUS.lua` ships. No non-enUS
locale, which is opt-in. Game data is matched on stable tokens throughout — the only entity lookups
are `select(2, UnitClass("player"))` at `core/Data.lua:96,131`, the classFile token, which is the
*correct* form. US English is enforced by a real test case ("the addon's own files use US
spellings"). The `NS.L` seam is in place but no user-facing string is wrapped yet — recurring
AT-30.

### events-frames-taint

AceEvent for lifecycle events. No protected API anywhere; no `SetAttribute`, no secure template, no
insecure hook on a Blizzard frame. Combat display logic correctly uses `UnitAffectingCombat("player")`
rather than `InCombatLockdown()` (`modules/Display.lua:134`) — the exact distinction
`events-frames-taint-§2` draws, and the live bug it names.

Combat-secret handling is thorough: `UnitGetTotalAbsorbs` values reach only C-side sinks
(`AbbreviateNumbers`, `SetValue`, `SetMinMaxValues`) and every debug read is fenced behind
`NS.IsConcatSafe`, which is `LibKa0s-Core-1.0`'s `table.concat` probe, not a `..` probe
(`core/AbsorbTracker.lua:170,232`).

**Deviations:** private per-unit `RegisterUnitEvent` frames for the two `UNIT_*` floods (recurring
AT-31, documented and justified), and the pre-concatenation at chat call sites (AT-35).

### public-api

The addon exposes no public surface; `public-api` is N/A by its own terms.

### compat

`core/Compat.lua` is the single file touching a deprecated API (`GetAddOnMetadata`, behind a
`C_AddOns` presence check). Its two callers both go through the shim
(`settings/About.lua:25`, `settings/Slash.lua:109`). No `WOW_PROJECT_ID` branch anywhere.

### debug-logging

`LibKa0s-DebugLog-1.0` wired in `core/DebugLogSetup.lua` — silent `LibStub(..., true)` lookup,
guarded `:New`, five required descriptor fields plus `slash`, `onVisibilityChanged` and an
`initSummary` returning name + version + schema version + active profile. `print` and `safeToString`
are **call-time forwarders**, exactly as `debug-logging-§1` requires, because `NS.Print` is reclaimed
in a later-loading file. `NS.Debug` is bound bare off the instance. The stub answers every member
the addon calls, still flips `NS.State.debug`, still prints the ack, says the honest line once, and
deliberately carries no formatter copy. The vendored JetBrains Mono font is the sanctioned styling
exception.

Coverage: lifecycle (`[Init]` on enable), the absorb transitions, the visibility ladder with its
deciding rung, migrations, and `[Set]` at the single write seam. Per-pass coalescing is real — the
combat rollup is one `[Combat] left: N events, M repaints` line, not per-event spam, and all of its
string work is behind the flag.

### packaging

`.pkgmeta`: `package-as: AbsorbTracker`, no `externals:`, ignores `docs`, `tests`, `_dev`,
`.luacheckrc`, `.gitignore`, `.gitattributes`, `*.bak`. No `enable-toc-creation`.

### lint

`.luacheckrc` present, `std = "lua51"`, `debugprofilestop` in `read_globals` with a comment naming
the bracket sites, both SV globals and `StaticPopupDialogs` in `globals`, each with a justifying
comment. `libs/` and `tests/` excluded. **`luacheck .` → 0 warnings / 0 errors in 28 files.**

### testing

Kit vendored whole at `tests/_kit/` (byte-identical to `LibKa0s/testkit`), never under `libs/`,
never edited. `tests/run.lua` derives the addon's file list with `Loader.tocFiles("AbsorbTracker.toc")`
and lists all 8 vendored LibKa0s files explicitly in XML order; `tests/wow_mock.lua` is a thin
extender over `mock_base.lua`. `tests/test_loadorder.lua` pins the derivation itself — TOC order,
on-disk existence, no `libs/` leak, and that `tests/perf.lua` derives its list the same way.
`docs/test-cases.md` is generated by `--list` and its `## Totals` reads **469**.
**`lua tests/run.lua` → 469 passed, 0 failed, 469 total.**

`tests/perf.lua` is the offline runner, outside the gate, asserting on call counts and bytes only,
with the required `probeOverheadOff` / `probeOverheadOn` zero-overhead scenario.

**One gap:** the README `[tests]` badge still reads 467/467 — AT-32.

### performance

`LibKa0s-Perf-1.0` wired in `core/PerfSetup.lua` with a stub covering every member the addon calls.
Five buckets declared in report order with `within` nesting stated. Bracket idiom is the mandated
shape at every site — `local Perf = NS.Perf` load-time upvalue, `Perf.on and debugprofilestop()`,
`if t0 then Perf.Note(...)`. `perf` verb dispatches through `NS.COMMANDS`, printing lines the library
returns. `AbsorbTrackerPerfDB` declared in TOC and `.luacheckrc`. Suspend/resume is enforced **at the
source** — `NS.ShouldShowBar` checks `Perf.suspended` as step 0 — and resume rebuilds registrations
from the current enabled set. `docs/perf-runs/` holds two committed captures plus its README;
`docs/performance.md` and `docs/complexity.md` both exist.

### documentation

Root ships exactly `README.md`, `CLAUDE.md`, `LICENSE`. `CLAUDE.md` is a stub with the H1, the
adherence line, the verbatim-in-substance `## Standards compliance (read first)` section, the docs
pointer list and the green-gate line — and an explicit note that `docs/agent-context.md` does not
exist and must not be created (anti-pattern #49 clear; the file is absent). The canonical `docs/`
trio is present, as are the three required topic docs. No `TODO.md` anywhere.

`docs/pending/LEDGER.md` is a decision record keyed to GitHub issue numbers, not a competing
backlog, so it is not treated as a `TODO.md` under `documentation-§4`.

The three-place standards reference (`documentation-§6`) is complete: TOC `X-Standard`, README badge
#4, `CLAUDE.md` compliance section.

**Gaps:** the stale `[tests]` badge (AT-32), the `## What's new` / Version History disagreement
(AT-33), the retired `§N.M` notation still used throughout code comments and docs (AT-36), and three
entries in `docs/ARCHITECTURE.md`'s "Standards Deviations" that the current standard now sanctions
outright (AT-37).

### audit-review-history

`docs/audits/2026-07-12/`, `docs/audits/2026-07-18/` and `docs/reviews/2026-08-03/` are retained and
untouched. This run writes a new dated folder beside them.

### versioning-git

Semver `1.9.0` agrees across TOC, `core/Namespace.lua:7` and the README Version History top row.
Trunk-based on `master`, no stray feature branch. Both gate commands are green at head.

### anti-patterns sweep

Clear on #1–#38 and #41–#49, with these exceptions recorded as deviations: **#40** (stale
`## What's new` — AT-33), **#42** (an AceGUI widget built during the load window — AT-34). #45 and
#48 are provably clear: both `diff -r` checks ran and were empty. #47 is clear in both directions —
the addon hand-rolls none of the five modules and forks none of them.
