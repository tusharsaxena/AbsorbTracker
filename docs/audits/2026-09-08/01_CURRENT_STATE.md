# 01 — Current State

**Addon:** Ka0s Absorb Tracker (`AbsorbTracker`), version `1.9.0` (`AbsorbTracker.toc:5`).
**Audited against:** Ka0s WoW Addon Standard **v2.39.0 (2026-09-07)** — line 1 of
`standards/STANDARDS.md` on `master`, fetched with `curl -fsSL` and read verbatim. The index's
**Sections** list was followed and **all 26 section files** under `standards/standards/` were
fetched and read; none is unassessed. `AUDIT.md` and `standards/ADDONS.md` were fetched the same way.
**Rule set:** the **addon** sections. This repo carries a `.toc`, so `AUDIT.md` step 1's library-repo
switch does not apply.
**Commit audited:** `a5a68ba273b6f391b0fcde371dbdbc331f34dc4d` on `master`, working tree clean.
**Run date:** 2026-09-08.

This is a **read-only measurement**. No addon source, TOC, config or doc outside this folder was
touched.

---

## Why this run exists

The v2.39.0 cycle amended fifteen sections. Sixteen of those amendments were verified during M1 by
grepping the standard for its own keyword, which proves a token was typed and nothing more. This run
measures the amended rules against the repository they govern. Where an amendment changed what an
audit can see, the section walk below says so.

---

## Layout (`layout`)

`core/ defaults/ locales/ modules/ settings/` plus `libs/`, `media/`, `tests/`, `docs/`. Folder load
order in `AbsorbTracker.toc:15-70` is Libraries → Locales → Core → Defaults → Modules → Settings.
`media/` holds two typed subfolders, `logos/` and `screenshots/`, and nothing the shared payload
already ships.

**`layout-§1`'s cap, measured under v2.39.0's stated scope** — every authored `.lua` the repository
tracks, `tests/` included, with vendored code the carve-out:

```
git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn | head -3
  1296 tests/test_slashcmds.lua
  1171 tests/test_helpers.lua
   904 tests/test_widgets.lua
```

Nothing is over the 1500 cap; two files sit in the 1000–1500 on-notice band, and both carry a dated
`Disposition` in `docs/automated-tests/RESULTS.md:81-82`.

## TOC (`toc-file`)

Thirteen metadata fields in the mandated order, single Retail `## Interface: 120007`,
`## X-Curse-Project-ID: 1450165` (real and published — the README's live CurseForge badge resolves
it), `## X-Standard:` present. File listing is `#`-sectioned in the mandated header order and ends
with one trailing newline.

**Position annotations (`toc-file-§5`, denominator measured, not counted by line).** The `# Core`
block carries two comments: `AbsorbTracker.toc:36-38` marks `core\EnvSetup.lua` **conventional** with
its reason, and `:39-40` marks `core\MediaSetup.lua` **load-bearing**, naming `Constants.FONT_MONO`
and the `NS.MediaFont` seam it resolves from. The standard's own worked example is these lines.
Reading the seam files established **four** load-bearing positions inside `# Core`; two are
annotated, two are not — see `02_DEVIATIONS.md` `AT-64` and `AT-65`, and `03_EVIDENCE.md` for the
denominator and for why `core\Constants.lua` is not a third.

## Library stack (`library-stack`)

Ace3 substrate vendored under `libs/`; `libs\LibKa0s\LibKa0s.xml` listed **once** in
`AbsorbTracker.toc:27`, after Ace3, with no individual module `.lua` named. The vendored payload is
the whole ship folder: `LibKa0s.xml` lists **14** `Script` entries and `libs/LibKa0s/*.lua` is 14
files. `libs/LibKa0s/media/` is present. `libs/LibStub/` now holds `LibStub.lua` alone.

Provenance: `CLAUDE.md:69` — `Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0
(MIT).` Not in `README.md`. Both `diff -r` runs against the sibling checkout at tag `v1.27.0` are
**empty** (`03_EVIDENCE.md`).

**Seven majors are wired**, each through its own setup file with a `LibStub(major, true)` lookup and
a degradation branch: `LibKa0s-Env-1.0` (`core/EnvSetup.lua:54`), `-Media-1.0`
(`core/MediaSetup.lua:82`), `-Core-1.0` (`core/CoreSetup.lua:25`), `-Perf-1.0`
(`core/PerfSetup.lua:14`), `-DebugLog-1.0` (`core/DebugLogSetup.lua:14`), `-Slash-1.0`
(`settings/Slash.lua:24`), `-Options-1.0` (`settings/OptionsSetup.lua:45`). `Widgets`, `Item` and
`Pool` are declined, each with a closed `state:will-not-do` issue giving the reason (#26, #27, #28) —
`library-stack-§7` makes adoption per module and on the addon's own schedule, so these are
compliance, not deviation.

**`library-stack-§9` / anti-pattern #76 (new in v2.39.0).** `core/LSMPatch.lua` is gone. The one
process-global widget re-registration is `lib.__PatchLSM30Border()` at
`settings/OptionsSetup.lua:397` — the library's member, idempotent behind the library's own sentinel.
`grep -rn 'RegisterWidgetType' core/ modules/ settings/` returns nothing.

## Architecture (`architecture`)

`local _, NS = ...` bootstrap; AceAddon promotion at `core/AbsorbTracker.lua:12-13` passing `NS` as
the addon object; three feature modules (`modules/Bar.lua`, `Display.lua`, `Timer.lua`); a closed
message bus at `core/Bus.lua:50` publishing **five** messages; the schema in `settings/Schema.lua` is
the single source for `list`/`get`/`set`/`reset`, the panel and the defaults.

## SavedVariables (`savedvariables`)

AceDB with `AbsorbTrackerDB`; `AbsorbTrackerPerfDB` as the sanctioned diagnostics global
(`savedvariables-§4`). Defaults in `defaults/Profile.lua`. A migration runner in `core/Database.lua`
walks `SCHEMA_STEPS` (`:161`, run at `:225-229`) against an account-wide `db.global.schemaVersion`,
plus a **per-profile** stamp — a ratified register row, see below. Falsy-state defaulting uses
`== nil` (`core/Units.lua:58`, `core/Database.lua:137`, `:151`), not `or`.

## Options UI (`options-ui`)

Blizzard canvas landing page plus General, Appearance and Profiles subcategories, built by
`LibKa0s-Options-1.0` from the descriptor at `settings/OptionsSetup.lua:51-...`, instantiated at
`:404`. Tab strips on both flow-rendered pages: General `[Master controls][Bars]`, Appearance
`[Size][Bar][Background][Border][Text]`. The landing page and the AceConfig-drawn Profiles page are
the two pages `options-ui-§13` exempts. `Master controls` is **composed**, not typed
(`settings/General.lua:88`, `H.MasterControls`), with `frameless = false` stated explicitly. Every
color row carries its class-color companion; no `disabledIf` on any color row; no hand-rolled
reorder list; one chrome block per page, unboxed.

**The degradation stub is the thing v2.39.0 changed.** `settings/OptionsSetup.lua:166` opens the
library-absent branch, and it publishes **five composers** — `ColorPair` `:225`, `FontGroup` `:236`,
`BorderGroup` `:247`, `BarGroup` `:261`, `MasterControls` `:276` — each emitting the full canonical
leaf set through a local `composeBlock` at `:194`. Amended `options-ui-§1` now rules that those
members **MUST answer an empty row list**. See `AT-62`/`AT-63`.

## Slash commands (`slash-commands`)

`NS.COMMANDS` at `settings/Slash.lua:60` carries **17** verbs; `profile` is a subcommand tree
(`PROFILE_VERBS` at `:327`, dispatched at `:386`). Dispatch is `LibKa0s-Slash-1.0`'s, handed the
addon's own table at `:451`. Cyan `[AT]` chat tag.

## Localization (`localization`)

`NS.L` seam exported; `locales/enUS.lua` is the only locale file and answers every key it declares (a
suite case proves it). English-only is a **ratified register row** citing `localization-§1`, and
`localization-§3` still names that a terminal compliant state in v2.39.0.

**`localization-§5`'s canonical list is new in v2.39.0**, and it names this repo's gate by name. The
gate is `tests/test_docs.lua:338`, reading a private whole-word map at `:192`. See `AT-66`.

## Events, frames, taint (`events-frames-taint`)

AceEvent for lifecycle events; per-unit `CreateFrame` + `RegisterUnitEvent` for the two `UNIT_*`
events, which is a ratified register row. Combat-protected reads at `core/AbsorbTracker.lua:171` and
`:234` are guarded by `NS.IsConcatSafe` and passed to the sink unformatted.

## Debug logging, performance, packaging

Console is `LibKa0s-DebugLog-1.0`'s, wired from `core/DebugLogSetup.lua`; the addon owns no console
window. The perf harness is wired (`core/PerfSetup.lua:33`), so `performance-§12`'s exemption does
not apply; `core/PerfSetup.lua:137` records that the descriptor deliberately carries **no**
`decorate` hook. One frozen capture bundle under `docs/perf-analysis/20260807-125002/` with all three
artifacts, indexed in `docs/perf-analysis/README.md:136-140`.

`.pkgmeta` accounts for every root dot-entry except `.git`, which never needs one, and names the
shipped half (`media/screenshots`, `:26`) separately from the untracked half (`:20-21`).

## `.gitattributes` (`line-endings`) — recorded verbatim per `AUDIT.md` step 3

Present at the repo root, **81 lines**. Pin at `:26` is `* text=auto eol=crlf` (client-bound, correct
kind); `*.sh text eol=lf` at `:34`; 20 `binary` marks. The first 81 lines diff **empty** against
`line-endings-§5`'s canonical client-bound body, and there is nothing after them — no appendix, and
none is owed. The working-tree check returns **0**. The vendored gate `tests/_kit/test_eol.lua`
(`line-endings-§7`, kit revision 15) is present and green.

## Root doc set (`documentation-§1/§2/§7`)

`README.md` follows the canonical order (title, five badges, logo, description, `## What's new in
1.9.0`, Screenshots, Usage, How the bar works, FAQ, Troubleshooting, Issues, Version History; no
`## Credits`, correctly, since nothing external is credited). The three cheap checks `AUDIT.md` step
3 asks for:

- standard badge is the **bare** `![Standard](…)` at `README.md:6`, not wrapped in a link;
- **no** bundled-library inventory — no `## Libraries`/`## Bundled libraries`/`## Credits*` heading
  and no roll-call in the intro prose;
- the LibKa0s provenance line is in `CLAUDE.md:69` and **not** in `README.md`.

The README slash table is in lockstep with all 17 `NS.COMMANDS` verbs. `CLAUDE.md` is a 111-line stub
carrying `## Standards compliance (read first)`. `DEPENDENCIES.md` carries the WSL2/Ubuntu toolchain
contract with a verification section.

## `docs/` (`documentation-§3`) — measured as a directory listing

**Tier 1:** all six present under their canonical names. **Tier 2:** `slash-dispatch.md` (17 verbs
and a subtree — trigger fired, present), `midnight-quirks.md` (present), `profiles.md` (present),
`perf-analysis/README.md` (harness wired, present); `message-bus.md` (5 messages, threshold >10),
`compat-layer.md` (no `core/Compat.lua` at all, so the v2.39.0 count is 0 against a threshold of 3)
and `debug.md` each carry a *Not applicable* row with the trigger. **Tier 3:** none exists.

`## Documentation map` at `:283` covers every `.md` under `docs/` exactly once — 16 files against 16
present rows plus 3 *Not applicable* rows, no orphan and no dangling row — with the frozen and
generated directories named once each in the scope sentence. **`### Verification and record` is
present at `:311`** with exactly the six rows v2.39.0 mandates, in the mandated position, and no note
justifying it against the retired three-table MUST. `ARCHITECTURE.md` is 454 lines; all four
spillable mandated sections are well under 60. No retired doc survives; there is no `docs/perf-runs/`
and no `docs/pending/LEDGER.md`.

## The deviation register, read first (`audit-review-history`)

`docs/ARCHITECTURE.md:323` carries `## Documented deviations` with four ratified rows at `:333-336`.
All four were checked three ways, as `audit-review-history` now requires:

| Row | Rule changed in v2.39.0? | Trigger fired? | Cited ids resolve? |
|---|---|---|---|
| `events-frames-taint-§1` (per-unit event frames) | No — section not amended | No | `AT-31` → `docs/audits/2026-08-05/` ✓ |
| `savedvariables-§1` (per-profile stamp) | No — section not amended | No — the lift is live at `core/Database.lua:59`/`:87` | — |
| `events-frames-taint-§8` SHOULD half (18 pre-formatted lines) | No | No — none of the 18 reads a §8-named API | `AT-35` ✓, but two `file:line` citations have gone stale — `AT-68` |
| `localization-§1` (English only) | No — `localization-§3` still names this terminal | No — `locales/` holds `enUS.lua` alone | `AT-30` ✓, issue [#24](https://github.com/tusharsaxena/AbsorbTracker/issues/24) ✓ |

The **inverse** rule was run too: every closed `state:will-not-do` issue was read against the
register, and none of the seven declines a rule of this standard, so none owes a row. Reasoning per
issue is in `03_EVIDENCE.md`.

## Shared subsystems — wiring snapshot, not a search for hand-rolled code

| Module | Descriptor / seam | Degradation branch | Parity case |
|---|---|---|---|
| `Core` | `core/CoreSetup.lua:25`, wrapper at `:123` | yes | `tests/test_surface_parity.lua:47` |
| `DebugLog` | `core/DebugLogSetup.lua:14` | yes | `:71` |
| `Options` | `settings/OptionsSetup.lua:45`, `:404` | `:166` (load-completing) | `:97` |
| `Slash` | `settings/Slash.lua:24` | yes | `:161` |
| `Perf` | `core/PerfSetup.lua:14`, `:33` | `:22` | **none** — `AT-67` |
| `Env` | `core/EnvSetup.lua:54` | inline nil-guard, no stub table | n/a |
| `Media` | `core/MediaSetup.lua:82` | inline nil-guard, no stub table | n/a |

The addon carries no console window, no widget makers, no dispatcher and no test framework of its
own, and `libs/LibKa0s/` is unpatched — the compliant state under anti-patterns #47 and #48.

## Gates as measured today

`luacheck .` — **0 warnings / 0 errors in 54 files**. `lua tests/run.lua` — **562 passed, 0 failed,
0 skipped, 562 total**. `lizard` — **no thresholds exceeded**, max CCN 15, 0 warned functions.
Commands and full output in `03_EVIDENCE.md`.
