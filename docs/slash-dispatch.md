# Slash dispatch

`/at` and `/absorbtracker` are two names for one command set. The dispatcher, the help renderer, the
row and key/value formatters, the `/at list` builder and the type-aware value parser are all
**LibKa0s-Slash-1.0**'s (`libs/LibKa0s/Slash.lua`). `settings/Slash.lua` — last in the TOC, because
the table it builds has to see every page's handlers — supplies the descriptor, owns the
`NS.COMMANDS` table, and implements the verbs that are genuinely this addon's.

This page exists because the verb set is no longer flat. Seventeen verbs is over
`documentation-§3`'s eight, and four of them take a sub-verb or a token: `profile` dispatches through
a table of its own, `perf` hands its remainder to the perf library, and `debug` and `toggle` each
parse one word. The trigger fires on either half.

## Registration

`Sl:Register` (`settings/Slash.lua:499`) registers both names through AceConsole-3.0, called once
from the AceAddon `OnInitialize` (`core/AbsorbTracker.lua:44`, guarded so a load where
`settings/Slash.lua` never ran degrades rather than errors):

```lua
NS.addon:RegisterChatCommand("at",            function(msg) Sl:OnSlash(msg) end)
NS.addon:RegisterChatCommand("absorbtracker", function(msg) Sl:OnSlash(msg) end)
```

AceConsole is the single registrar — no `SLASH_*` globals, no `SlashCmdList` entry
(slash-commands-§1). The library registers no chat command of its own, so every line the perf verb
produces comes back as text and is printed through this addon's tagged printer rather than escaping
to `DEFAULT_CHAT_FRAME`.

## The `COMMANDS` table

`NS.COMMANDS` (`settings/Slash.lua:60`) is an ordered list of positional triples
`{name, description, fn(rest)}` — the shape the library reads as `entry[1]` / `[2]` / `[3]`. A table
of named fields is silently invisible to it. The handler takes `rest` **alone**, never `self` plus
`rest`.

The table is passed **into** the library on the descriptor's `commands` field rather than owned by
it, and that is deliberate: `settings/About.lua` renders the same rows through
`NS.Slash:LandingRows()`, so a slash library that owned the verbs would force the options library to
consume this one, and two libraries reaching for each other is a real dependency cycle. Crossing as
plain data is what keeps them independent.

Order in the table is the order of both `/at help` and the About page's command list. Adding a verb
is one row, wherever it reads sensibly.

Forward declarations above the table let it name handlers defined below it:

```lua
local printHelp, listSettings, getSetting, setSetting
local runReset, runResetAll, runResetPosition
local runDebug, runUpdate, runTest, runProfile, runToggle, runPerf
```

## Case-preserving parse

The library lowercases only the verb; the remainder is passed through untouched. That is load-bearing
here, because every schema path in this addon is camelCase and per-unit —
`/at set units.target.barWidth 250` is the shipped form, and folding the whole line would address a
row that does not exist. `/at profile` repeats the rule one level down: `runProfile`
(`settings/Slash.lua:373`) lowercases the sub-verb and leaves its argument alone, because AceDB
profile names are case-sensitive and a folded name deletes or switches to the wrong profile.

**Schema paths are fully qualified.** The pre-1.9 unqualified `/at set barWidth 250` is rejected:
`FindSchemaRow` has no bare-key row for a per-unit setting. Only the seven unit-agnostic rows —
`enabled`, `visibility`, `scale`, `alpha`, `locked`, `throttleWindow` and the session-only
`state.debugConsole` — take a bare path.

## The verbs

| Command | Handler | Behavior |
|---|---|---|
| `/at` (no args) / `/at help` | `cli:PrintHelp` (library) | Version header, then one row per `NS.COMMANDS` entry. |
| `/at config` (alias `/at options`) | `NS.OpenOptionsPanel` (library) | Open the settings category. Combat-gated inside `OpenOptionsPanel`, so every caller is refused, not just this verb. The alias is declared on the descriptor's `aliases` map, not as a second row. |
| `/at list` | `cli:CliList` | Every schema row and its current value, grouped by `groupKey` — `[appearance / player]` for a per-unit page, a bare `[general]` otherwise. |
| `/at get <path>` | `cli:CliGet` | One row's stored value, in the same `key = value` shape `/at list` prints. |
| `/at set <path> <value>` | `cli:CliSet` | Type-aware parse, then `NS.SetByPath` plus `NS.RefreshOptionsPanel` — the same seam the panel widget writes through. The echo **re-reads** what was stored, so a clamp is visible. |
| `/at reset <path>` | `cli:CliReset` | Reset one row to its default via `NS.ApplyDefault`. A whole page is the panel's Defaults button, not a verb. |
| `/at resetall` | `runResetAll` → `NS.Helpers.RestoreAllDefaults` | Reset the active profile to the shipped defaults. Shared with the panel's Reset All button and the popup; the acknowledgment sits **inside** the guard, so a load without `settings/OptionsSetup.lua` says it cannot rather than claiming success. |
| `/at resetposition` | `runResetPosition` → `NS.Helpers.ResetAllPositions` | Clear every unit's saved position and re-anchor. Same guard, same reason. |
| `/at lock` / `/at unlock` | inline | `NS.SetByPath("locked", …)`. |
| `/at toggle [player\|target\|focus]` | `runToggle` | Bare: flip **every** bar — all off if any is on, otherwise all on. With a unit token: that one bar. See the note below. |
| `/at debug [on\|off]` | `runDebug` | Bare toggles the console **window**; `on`/`off` set session logging through `NS.DebugLog:SetEnabled`. |
| `/at perf [sub]` | `runPerf` → `NS.Perf.OnCommand` | The guided perf run. Sub-verbs are the library's; see [performance.md](./performance.md). |
| `/at update` | `runUpdate` | Publish `MSG.REPAINT`. |
| `/at version` | inline | `v<version>` from `NS.Version()`. |
| `/at test [value] [hold-secs]` | `runTest` | Paint a fake absorb for visual tweaking, held for the announced duration by `NS.HoldPreview`. |
| `/at profile <sub> [name]` | `runProfile` | The sub-verb tree below. |

## The sub-verb trees

Four verbs parse a remainder of their own. Three of them parse one word; only `profile` carries a
dispatch table, and it is the one this page is really about.

**`profile`** — `PROFILE_VERBS` (`settings/Slash.lua:327`), a table keyed by the lowercased sub-verb,
built once at load and dispatched at `:386`:

| Sub-verb | Takes a name | What it does |
|---|---|---|
| `list` | no | Every profile, the current one marked. |
| `current` | no | The current profile's name. |
| `use <name>` | yes | `db:SetProfile(name)`. |
| `new <name>` | yes | `SetProfile` **then** `ResetProfile` — the reset has to land on the new profile, not the one being left behind. |
| `copy <name>` | yes | `db:CopyProfile(name)`. |
| `delete <name>` | yes | Refuses the current profile; otherwise `db:DeleteProfile(name, true)` and prints its own line. |
| `reset` | no | `db:ResetProfile()`. |

A bare `/at profile` prints the sub-help built from `PROFILE_HELP` (`:298`), whose row order is the
contract — the table is what the help iterates, so the two cannot drift. An unknown sub-verb prints
`Unknown profile subcommand '<name>'` and then that same help. The four name-taking verbs share one
guard, `needsName(verb, fn)` (`:317`), which wraps at file load rather than at dispatch: a missing
name prints `Usage: /at profile <verb> <name>` and the handler never runs, and a dispatch allocates
nothing. Adding a sub-verb is one `PROFILE_VERBS` entry plus one `PROFILE_HELP` row.

The whole tree is gated on AceDB: with no `db.SetProfile` the verb prints
`Profile system requires AceDB-3.0` and stops, rather than indexing a shim that has no profiles.
Detail in [profiles.md](./profiles.md).

**`perf`** — `runPerf` strips nothing and hands the remainder straight to `NS.Perf.OnCommand`, which
returns lines for this addon to print. The sub-verbs, and the panel that shares them, belong to
`LibKa0s-Perf-1.0` and are documented once in [performance.md](./performance.md) rather than copied
here.

**`debug`** — one token, `on` or `off`, sets session logging; anything else (including nothing)
toggles the console window. The window and the flag are two different things, which is why the
Master controls checkbox is not a second switch for the same state.

**`toggle`** — one optional unit token, validated against `NS.Units.LABEL`; an unknown token prints
the expected list rather than silently doing nothing. Both arms write through `NS.SetByPath`, so the
enable row's `onChange` fires exactly as it does from the panel checkbox and the two affordances
cannot reach different code.

The bare form's asymmetry is deliberate. Flipping each unit independently would invert a mixed set —
player on, target off becomes player off, target on — which is not what "toggle the bars" means to
anybody. So bare `toggle` turns everything off if anything is on, and everything on otherwise.

## The mirror note

`MirrorNote` (`settings/Slash.lua:48`) is handed to the library through `cli:SetRowAnnotator`
(`:481`). It appends `(mirrored — the bar shows Player's appearance)` in gray to a row whose unit is
currently mirroring, and it exists because `/at get` and `/at set` resolve through `NS.GetSetting`,
which walks the raw profile path and never consults `NS.Units.Get`. They therefore read and write the
unit's **stored** value, not the mirror-resolved one. That is deliberate and self-consistent — it is
exactly what `/at set` would write, and resolving on read would make get and set asymmetric — but it
is silent, and the note is what stops `/at set units.focus.barWidth 400` echoing a confident
confirmation while the focus bar does not move.

Only appearance rows are annotated. `enabled` and `mirror` carry `alwaysPerUnit` and are honored
per-unit even while mirrored, so a note on them would be a lie. The library decides only **where** an
annotation may appear — after the colored pair, on `list`/`get`/`set` and never on a reset; what it
says is this addon's, because `NS.Units.IsMirrored` and the row's `alwaysPerUnit` flag are things a
generic dispatcher knows nothing about.

## Help output convention

```
[AT] v1.10.0 — slash commands (/absorbtracker is an alias for /at)
  /at help — List available commands
  /at config — Open the settings panel
```

- Cyan `[AT]` prefix on every line, from the shared printer. The header is the library's
  `HELP_HEADER` plus `HELP_ALIAS`, which names `/absorbtracker` from the descriptor's
  `slashAliases` list.
- One row per command from the library's single formatter: gold command, an em dash with one space
  either side, white description. `PrintCmd` adds the two-space chat indent; the About page renders
  the same rows un-indented, because a panel label sitting under its own header does not want one.
- The version comes from `NS.Version()` — TOC metadata through `LibKa0s-Env-1.0` — so it cannot drift
  from the packaged manifest.
- No trailing colon on any printed line (slash-commands-§4).

## When the library is absent

`/at` is registered unconditionally, so something has to answer it. With `LibKa0s-Slash-1.0` missing,
`settings/Slash.lua:406` installs a stand-in: dispatch and a plain help index still render, the host
verbs — which never went to the library — keep working untouched, and each schema verb (`list`,
`get`, `set`, `reset`, `resetall`) prints one honest line naming the missing library through
`NS.LIBKA0S_MISSING`.

What the degraded arm deliberately does **not** contain is a second copy of the row formatter, the
`key = value` shape or the value parser. Hand-copying the strings whose drift the extraction exists to
end is precisely the duplicate testing-§8 forbids, so a degraded help row renders plainly and says
so. The stub and the real instance are both file-scope locals, which is why `Sl.__cli` (`:488`) is
published under the same `__` convention the options helpers use —
`tests/test_surface_parity.lua` is its only reader, and a stub surface that cannot be reached cannot
be compared against the one it stands in for.

## See also

- [module-map.md](./module-map.md) — where `settings/Slash.lua` sits in the load order.
- [schema.md](./schema.md) — the registry `/at list`, `/at get` and `/at set` walk.
- [profiles.md](./profiles.md) — what `/at profile` is driving.
- [performance.md](./performance.md) — the `perf` sub-verbs and the step panel.
- [settings-panel.md](./settings-panel.md) — the panel affordances these verbs share a body with.
