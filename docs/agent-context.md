# Agent context — Ka0s Absorb Tracker

Full working brief for Claude Code (and other LLM-assisted editors). Read this before touching
code. The root [CLAUDE.md](../CLAUDE.md) is only a stub that points here.

## What this addon is

Three movable absorb status bars — **player, target, and focus** — each displaying the total of
all active absorb shields on that unit as one combined value. Target and focus ship **disabled**
and **mirrored**: turned off by default, and once turned on they live-link to the player bar's
appearance until the user unchecks the link. Bar size, fill texture and color, background texture
and color, border style / size / color, and font face / size / outline are all independently
configurable **per unit** through LibSharedMedia-backed pickers, via a Unit dropdown on the
Bar/Border/Font pages. Bar fill, background, and border each have an opt-in class-color override
(always the player's class, on all three bars). Position and the per-unit enable flag are per-unit
and **never** mirrored. Two models exist for bringing a unit's appearance in line with the player:
**mirror** is a live link (`units.<unit>.mirror = true` — the unit's appearance re-reads the
player's settings on every paint) and **copy** is a one-shot snapshot
(`NS.Units.CopyFromPlayer(unit)` — deep-copies the player's current values once, then the unit
diverges independently). Position is saved per-profile, per unit. **Modular layout**; Retail
Midnight only (Interface 120007); English only.

User-facing reference: [../README.md](../README.md). Subsystems + invariants:
[ARCHITECTURE.md](./ARCHITECTURE.md).

## Hard rules

- **Conform to the Ka0s WoW Addon Standard** (https://github.com/tusharsaxena/WowAddonStandards).
  It is the source of truth for layout, TOC, the Ace substrate, schema-driven settings,
  slash/prefix conventions, locales, Compat, tests/lint, and doc structure. **If a change would
  deviate, STOP and flag it** — never silently deviate or silently conform. The user decides
  whether it is (a) an accepted, documented deviation for this addon, or (b) a change to the
  standard itself (updated upstream in the standards repo, then this addon follows the new rule).
  See the root [CLAUDE.md](../CLAUDE.md) "Standards compliance" section.
- **Schema is the single source of truth for settings.** `NS.Schema` is a flat array; each
  `settings/<page>.lua` calls `NS.RegisterSchemaRows({ ... })` at file-load time. The same array
  drives both the AceGUI panel widgets (via `NS.Helpers.RenderSchema` / `NS.Helpers.RenderField` —
  `LibKa0s-Options-1.0`, `libs/LibKa0s/OptionsWidgets.lua`) AND
  the `/at list/get/set/reset/resetall` CLI. Adding a new option = one schema row in some
  `settings/<page>.lua`. Don't add per-setting code in `settings/Slash.lua`; the row grammar
  covers it. Those five verbs are implemented by `LibKa0s-Slash-1.0` (`libs/LibKa0s/Slash.lua`),
  which walks the rows `settings/Slash.lua` hands it; `settings/Slash.lua` itself keeps only
  `NS.COMMANDS`, the host verbs, and the mirror note.
- **Color getters resolve at call time.** `NS.GetBarColor(unit)` / `GetBgColor(unit)` /
  `GetBorderColor(unit)` (`core/Data.lua:146,155,164`) take a `unit` argument and re-read that
  unit's `useClassColor*` on every paint (the resolved class color itself is always the player's).
  Class change / respec / profile switch all "just work" without explicit refresh wiring. Don't
  cache the resolved color on a frame.
- **Only `core/Units.lua` reads `db.profile.units` for appearance.** Every other file —
  `modules/Bar.lua`, `modules/Display.lua`, `core/Data.lua`, the settings pages — calls
  `NS.Units.Get(unit, key)` instead of indexing `db.profile.units` directly, so mirror resolution
  (does this unit read its own config or the player's?) lives in exactly one place. Don't add a
  second `db.profile.units[...]` read site.
- **Slash paths are fully qualified.** `/at set units.target.barWidth 250` works; the pre-1.9
  unqualified `/at set barWidth 250` is rejected (`FindSchemaRow` has no bare-key row for a
  per-unit setting). Only the three flat globals (`locked`, `showOnlyInCombat`,
  `throttleWindow`) use a bare path.
- **`SetBackdrop(nil)` before `SetBackdrop(info)`.** WoW's backdrop API is a no-op when the table
  identity is unchanged, even if its fields changed. `UpdateBarAppearance` (`modules/Display.lua`)
  clears first, then re-applies. Don't optimize this away.
- **Combat-lockdown gate on `/at config` (refuse, options-ui-§2).** `Settings.OpenToCategory` is
  protected; calling it during combat taints the panel for the rest of the session.
  `NS.OpenOptionsPanel` (`settings/OptionsSetup.lua`) is a one-line delegate to
  `LibKa0s-Options-1.0`'s `O.OpenOptionsPanel` (`libs/LibKa0s/Options.lua`), which **refuses**
  while `InCombatLockdown()` is true — prints a gray `[AT]` notice and returns, never
  deferring/replaying on `PLAYER_REGEN_ENABLED`. The gate is the library's; the behavior is
  unchanged.
- **`NS.Helpers` IS the `LibKa0s-Options-1.0` instance** (`settings/OptionsSetup.lua`), not a table
  decorated from a copy of it. `settings/UnitPanel.lua` and `settings/About.lua` hang their members
  on that same table. Don't replace it with a wrapper: a test that swaps a member out to spy on it
  must swap the one the library's own callers see, and a page file has to be able to call
  `H.RenderUnitPanel` and `H.RenderSchema` without knowing which side owns which.
- **Cyan `[AT]` chat prefix on all addon output.** Routes through `NS.Print(...)` which prepends
  `NS.PREFIX` (`|cFF00FFFF[AT]|r`, defined in `core/Namespace.lua`). Files that emit chat shadow
  the global `print` with `local print = NS.Print`. Debug output does NOT go to chat — it routes
  to the on-screen console via `NS.Debug` — `LibKa0s-DebugLog-1.0` (`libs/LibKa0s/DebugLog.lua`,
  vendored), wired up by `core/DebugLogSetup.lua`, which keeps the `NS.State.debug` flag on our
  side of the seam.
- **`UnitGetTotalAbsorbs` may return a "secret" value.** Use `AbbreviateNumbers` directly for
  display — never run it through `tonumber` first, and never compare it with `<`/`>`. A secret
  survives `tostring()` **and the `..` operator** but **raises in `table.concat`/`string.format`**,
  so **never build a chat/debug line from a raw combat value** — every arg to `NS.Print` /
  `NS.Debug` goes through `NS.SafeToString` (`LibKa0s-Core-1.0`, `libs/LibKa0s/Core.lua` — the
  addon takes it off the library in `core/CoreSetup.lua`), which renders a secret as
  `<secret>`. Its detector probes `table.concat`, not `..` (a `..` probe passes secrets through).
  This is Ka0s standard **§9.8**. Detail in [midnight-quirks.md](./midnight-quirks.md).
- **Deprecated APIs go through `core/Compat.lua`.** `Compat.GetAddOnMetadata` is the only metadata
  accessor. Never call `GetAddOnMetadata` / `C_AddOns.GetAddOnMetadata` inline.
- **Keep the static README badges in lockstep with their source of truth (documentation-§1,
  testing-§5).** The `[WoW]` and `[Tests]` badges are static shields.io badges that go stale
  silently, so each MUST move in the **same change** as its source: (a) `[WoW]` ↔ the TOC
  `## Interface:` on every client-patch bump (both show one number, e.g. `Midnight_12.0.7` ↔
  `120007`); (b) `[Tests]` ↔ the regenerated `docs/test-cases.md` whenever the suite changes — a
  case added, removed, or renamed, or the pass count moves (i.e. whenever a failing test is
  resolved) — regenerate via `lua tests/run.lua --list` and update the badge count together, not as
  a follow-up. `docs/test-cases.md` is generated (never hand-edit) and is the authoritative count;
  there is no CI and no dynamic badge. See [testing.md](./testing.md).

## The `NS` bus

Every Lua file begins with:

```lua
local addonName, NS = ...
```

`NS` is the single shared private table for the addon (Ka0s standard §4.1); there is no
`_G[addonName]`. `core/AbsorbTracker.lua` promotes it to an AceAddon via
`AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")` — so the
bootstrap table and the AceAddon object (`NS.addon`) are the same object.

There is no `:NewModule()` hierarchy — modules are plain files hanging functions on `NS`. Callers
reference functions defined in later-loaded modules through `NS.X` directly (looked up at call
time), guarding with `if NS.X then ... end` for the soft load-order coupling.

Cross-module *notifications*, though, do **not** go through direct `NS.X` calls — they run over the
closed message bus (`core/Bus.lua`): producers `NS.bus:SendMessage(NS.MSG.X)`, and the display
modules subscribe on their own `NS.NewBusTarget()` targets (architecture-§4; see
[ARCHITECTURE.md](./ARCHITECTURE.md) → Message Bus). Direct `NS.X` calls remain for queries
(`NS.GetSetting`, `NS.ShouldShowBar`) and intra-concern work (e.g. `Timer`'s coalescer painting via
`NS.UpdateAbsorbBar`).

## Working environment

- **Dual-path WSL.** Mirrored at `/mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker/` and
  `/home/tushar/GIT/AbsorbTracker/`.
- **CRLF line endings on disk.** Enforced via `.gitattributes`. After any direct disk write of a
  text file, convert with `sed -i 's/\r$//; s/$/\r/'` if the tool wrote LF.
- **Libs vendored folder-per-lib in `libs/`** (`libs/LibStub/`, `libs/AceAddon-3.0/`, …): LibStub,
  CallbackHandler-1.0, the Ace3 stack (AceAddon / AceEvent / AceTimer / AceConsole / AceDB /
  AceGUI / AceConfig / AceDBOptions), `LibKa0s` (five majors across eight files, loaded in this
  order through `libs/LibKa0s/LibKa0s.xml`: `LibKa0s-Core-1.0` = `Core.lua`,
  `LibKa0s-DebugLog-1.0` = `DebugLog.lua`, `LibKa0s-Slash-1.0` = `Slash.lua`,
  `LibKa0s-Options-1.0` = `Options.lua` + `OptionsWidgets.lua` + `OptionsScroll.lua`, and
  `LibKa0s-Perf-1.0` = `Perf.lua` + `PerfPanel.lua`; DebugLog, Slash, Options and Perf each declare
  `NEEDS_CORE` and refuse to register below it, so a stale Core drops the module rather than
  half-registering it — and a multi-file major's attach files bail on their own
  `LibStub(…, true)` lookup when the shell never registered; ours, and the only one of these
  re-vendored whole-folder from a sibling repo on every release), LibSharedMedia-3.0,
  and the upstream `AceGUI-3.0-SharedMediaWidgets` r65. The displayButton tile is suppressed by
  `core/LSMPatch.lua` (addon-side, not a lib edit), so `r66+` refreshes are a clean drop-in.
- **Headless tests (`tests/`) + lint gate.** `lua tests/run.lua` (schema parse/format/validate plus
  the build-time schema-integrity invariants, DB migrations, Compat, the `LibKa0s-Core-1.0` wiring
  in `core/CoreSetup.lua` (including the degraded load with the library absent), the
  `LibKa0s-DebugLog-1.0` wiring in `core/DebugLogSetup.lua`, the full `/at`
  surface including `/at profile`, repaint-throttle coalescing, combat-visibility, message-bus
  dispatch, the `core/Data.lua` settings/media/color seam, the `modules/Display.lua` paint path,
  the `LibKa0s-Options-1.0` wiring in `settings/OptionsSetup.lua` (including the load-completing
  degraded stub), the per-unit page in `settings/UnitPanel.lua`, the schema → AceGUI widget layer,
  and `core/Units.lua`
  unit identity + mirror resolution)
  must be green and `luacheck .` clean
  (0/0) before every commit. Syntax-check one file with `luac -p <file>`. Toolchain: Lua 5.1 +
  luacheck. `tests/run.lua` mirrors the in-game lifecycle — it calls `NS:InitDB()` **and**
  `NS.CreateOptionsPanel()` at bootstrap, so every `settings/<page>.lua` builder runs for real and a
  page that breaks fails the gate instead of waiting to be opened in-game.
  The authoritative case list & count are in the generated `docs/test-cases.md`
  (regenerate with `lua tests/run.lua --list`); see [testing.md](./testing.md) for the sync rule and
  [smoke-tests.md](./smoke-tests.md) for the in-game QA recipe.

## Response style for this repo

- **Terse.** State the change, not the deliberation.
- **Use `file_path:line_number` references** when pointing at code.
- **Don't write summaries** the user can read from the diff.
- **Ship functional, defer polish.**
- **No comments explaining *what* well-named code does.** Comment only when the *why* is
  non-obvious (invariant, Blizzard quirk, hidden constraint).
- **Don't create docs or planning files unless asked.**
- **Never auto-stage, auto-commit, or auto-push.** The user chooses when to touch the git index.
  Editing files on disk is fine; touching the index is not. **Exception**: a commit-purpose slash
  command (e.g. `/wow-addon:commit`) IS the explicit instruction.
- **Never bump the version without an explicit instruction** (TOC `## Version:`, code constants,
  README badge / Version History).

## Doc index

Topic-specific detail lives in `docs/`. Read on demand.

| Topic | File |
|-------|------|
| Subsystems + invariants (module map, schema, bus, slash, events, taint) | [ARCHITECTURE.md](./ARCHITECTURE.md) |
| Scope boundaries (in / out / resolved decisions) | [scope.md](./scope.md) |
| Per-file responsibility map | [file-index.md](./file-index.md) |
| `NS` bus + public APIs + load order | [module-map.md](./module-map.md) |
| Schema-driven settings (registry, row knobs, `/at` mapping) | [schema.md](./schema.md) |
| Multi-page Settings panel toolkit | [settings-panel.md](./settings-panel.md) |
| Data flow (bootstrap, absorb update, settings write, profile change) | [data-flow.md](./data-flow.md) |
| Profiles (AceDB, `/at profile`, fallback shim) | [profiles.md](./profiles.md) |
| Midnight quirks (secret values, backdrop refresh, combat lockdown) | [midnight-quirks.md](./midnight-quirks.md) |
| Recipes (add a setting, add a sub-page, bump Interface) | [common-tasks.md](./common-tasks.md) |
| Manual QA / smoke-test recipe | [smoke-tests.md](./smoke-tests.md) |
| Measuring performance (offline runner + `/at perf`) | [performance.md](./performance.md) |
| Cyclomatic complexity report | [complexity.md](./complexity.md) |
