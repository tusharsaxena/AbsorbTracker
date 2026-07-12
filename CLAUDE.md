# CLAUDE.md — working notes for future sessions

Guidance for Claude Code (and other LLM-assisted editors) working on **Ka0s Absorb Tracker**. Read this first before touching code.

## What this addon is

A single movable absorb status bar for the player. Bar size, fill texture and color, background texture and color, border style / size / color, and font face / size / outline are all independently configurable through LibSharedMedia-backed pickers. Bar fill, background, and border each have an opt-in class-color override. Position is saved per-profile. Retail Midnight only (Interface 120007). English only.

User-facing reference: [README.md](./README.md). Subsystems + invariants: [ARCHITECTURE.md](./ARCHITECTURE.md).

## Hard rules

- **Schema is the single source of truth for settings.** `AddonTable.Schema` is a flat array; each `Options/<page>.lua` calls `AddonTable.RegisterSchemaRows({ ... })` at file-load time. The same array drives both the canvas-layout AceGUI panel widgets (via `Helpers.RenderSchema`) AND the `/at list/get/set/reset/resetall` slash CLI. Adding a new option = one schema row in some `Options/<page>.lua`. Don't add per-setting code in `SlashCommands.lua` or in a per-page builder; the row-grammar covers it.
- **Color getters resolve at call time.** `GetBarColor` / `GetBgColor` / `GetBorderColor` re-read `useClassColor*` on every paint. Class change / respec / profile switch all "just work" without explicit refresh wiring. Don't cache the resolved color on a frame.
- **`SetBackdrop(nil)` before `SetBackdrop(info)`.** WoW's backdrop API is a no-op when the table identity is unchanged, even if its fields changed. `UpdateBarAppearance` clears first, then re-applies. Don't optimize this away.
- **Combat-lockdown gate on `/at config`.** `Settings.OpenToCategory` is protected; calling it during combat taints the panel for the rest of the session. `OpenOptionsPanel` early-returns with a chat notice while `InCombatLockdown()` is true. Don't try to clever-defer.
- **Cyan `[AT]` chat prefix on all addon output.** Routes through `AddonTable.Print(...)` which prepends `|cFF00FFFF[AT]|r`. Files that emit chat shadow the global `print` with `local print = AddonTable.Print` so existing call sites stay unchanged. **No raw `print(...)` calls.**
- **`UnitGetTotalAbsorbs` may return a "secret" value.** Use `AbbreviateNumbers` directly — never run the value through `tonumber` before display. Detail in [docs/midnight-quirks.md](./docs/midnight-quirks.md#secret-values-from-unitgettotalabsorbs).

## `AddonTable` bus

Every Lua file begins with:

```lua
local AddonName, AddonTable = ...
```

`...` is the WoW-supplied vararg pair. `AddonTable` is the same table for every file in this addon. There is no `:NewModule()` or class hierarchy on the runtime side — modules are plain Lua files; functions are attached to `AddonTable`. AceAddon is bundled but only used as the carrier for AceDB.

For functions defined in later-loaded modules, callers reference them through `AddonTable.X` directly so the lookup happens at call time (and guard with `if AddonTable.X then ... end` for the soft load-order coupling). See [docs/module-map.md](./docs/module-map.md#forward-references).

## Working environment

- **Dual-path WSL.** The repo is mirrored at `/mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker/` and `/home/tushar/GIT/AbsorbTracker/`. Either path works for git and file tools.
- **CRLF line endings on disk.** Enforced via `.gitattributes` (`* text=auto eol=crlf` plus explicit `*.lua/*.toc/*.xml/*.md text eol=crlf`). After any direct disk write of a text file, convert with `sed -i 's/$/\r/'` if the tool wrote LF.
- **Bundled libs in `libs/`.** LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, the Ace3 stack (AceAddon / AceDB / AceGUI / AceConfig / AceDBOptions), and the canonical upstream `AceGUI-3.0-SharedMediaWidgets` r65 (LSM30_* swatch widgets) loaded via `widget.xml`. All tracked in git (standard WoW addon practice). The displayButton tile that upstream's `LSM30_Border` pins to TOPLEFT is suppressed by `LSMPatch.lua` — addon-side code, not a lib edit, so future `r66+` refreshes are a clean drop-in.
- **No automated tests.** Validation is manual, in-game. See [docs/smoke-tests.md](./docs/smoke-tests.md) for the full manual QA recipe.

## Response style for this repo

- **Terse.** State the change, not the deliberation.
- **Use `file_path:line_number` references** when pointing at code.
- **Don't write summaries** the user can read from the diff.
- **Ship functional, defer polish.** When core functionality lands, move on — don't stop to polish UX mid-milestone.
- **No comments explaining *what* well-named code does.** Only add a comment when the *why* is non-obvious (subtle invariant, workaround for a specific Blizzard quirk, hidden constraint).
- **Don't create docs or planning files unless asked.**
- **Never auto-stage, auto-commit, or auto-push.** The user chooses when to `git add`, `git commit`, and `git push`. This includes `git add <file>`, `git add -A`, `git add -p`, `git add --renormalize`, `git stash`, or any other index-mutating command. Editing files on disk is fine; touching the git index is not. Offering to stage/commit at the end of a turn is fine; doing it yourself is not. **Exception**: invoking a commit-purpose slash command (e.g. `/wow-addon:commit`) IS the explicit instruction. Proceed through the skill's confirmation flow and treat the user's `y` as authorization to run `git add` + `git commit` on the files the skill named. Pushing still requires a separate explicit ask.
- **Never bump the version without an explicit instruction.** Do not edit `## Version:` in `AbsorbTracker.toc`, the version badge / Version History row in `README.md`, unless the user has explicitly asked. Releases are the user's call.

## Doc index

Topic-specific detail lives in `docs/`. Read on demand — these are not auto-loaded.

| Topic | File | When to read |
|-------|------|--------------|
| Scope boundaries (in / out / resolved decisions) | [docs/scope.md](./docs/scope.md) | Evaluating a feature request; deciding whether something belongs in the addon. |
| Per-file responsibility map | [docs/file-index.md](./docs/file-index.md) | "Which file owns X?" |
| `AddonTable` bus + public APIs + load order | [docs/module-map.md](./docs/module-map.md) | Designing a cross-module change. |
| Schema-driven settings (registry, row knobs, `/at` mapping, settings reference) | [docs/schema.md](./docs/schema.md) | Adding a setting; debugging the slash CLI. |
| Multi-page Settings panel (canvas-layout shell, `Helpers` toolkit, AceGUI widgets, LSM swatch dropdowns, `OpenOptionsPanel`) | [docs/settings-panel.md](./docs/settings-panel.md) | Touching `OptionsPanel.lua`, any `Panel/<slice>.lua`, or any `Options/<page>.lua`. |
| Data flow (bootstrap, absorb update, settings write, profile change) | [docs/data-flow.md](./docs/data-flow.md) | Touching event handling, the ticker, or `OnProfileChanged`. |
| Profiles (AceDB integration, `/at profile`, fallback shim) | [docs/profiles.md](./docs/profiles.md) | Touching profile callbacks or the `/at profile` subcommands. |
| Midnight quirks (secret values, backdrop refresh, combat lockdown, Interface line) | [docs/midnight-quirks.md](./docs/midnight-quirks.md) | Patch-day breakage; protected-API gotchas. |
| Recipes (add a setting, add a sub-page, troubleshoot LSM, bump Interface) | [docs/common-tasks.md](./docs/common-tasks.md) | Routine modifications. |
| Manual QA / smoke-test recipe | [docs/smoke-tests.md](./docs/smoke-tests.md) | Before a release; spot-check after non-trivial changes. |
