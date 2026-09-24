# Slash dispatch

`/at` and `/absorbtracker` are two names for one command set. The dispatcher, the help renderer, the
row and key/value formatters, the `/at list` builder and the type-aware value parser are all
**LibKa0s-Slash-1.0**'s (`libs/LibKa0s/Slash.lua`). `settings/Slash.lua` — last in the TOC, because
the table it builds has to see every page's handlers — supplies the descriptor, owns the
`NS.COMMANDS` table, and implements the verbs that are genuinely this addon's.

This page exists because the verb set is no longer flat. Nineteen verbs is over
`documentation-§3`'s eight, and four of them take a sub-verb or a token: `profile` dispatches through
a table of its own, `perf` hands its remainder to the perf library, and `debug` and `toggle` each
parse one word. The trigger fires on either half.

## Registration

`Sl:Register` (`settings/Slash.lua:713`) registers both names through AceConsole-3.0, called once
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

`NS.COMMANDS` (`settings/Slash.lua:71`) is an ordered list of positional triples
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

### The disabled gate is the LIBRARY's, and this file declares the live set

`slash-commands-§2` says a **disabled** addon SHOULD answer a feature verb rather than act on it:
one tagged line naming `/at enable`, and nothing else. This addon takes it.

**It is no longer implemented here.** `LibKa0s-Slash-1.0` grew the gate at minor 12, restored the
v2.57.0 surface at minor 13 and answers every reserved verb exactly at minor 14 (LibKa0s v1.42.0), so `settings/Slash.lua` passes three descriptor fields and the dispatcher
does the rest:

| Field | What it is |
|---|---|
| `isEnabled` | `NS.GetSetting("enabled") ~= false`, asked at **dispatch** time and never cached, so the command straight after an `/at enable` works. It reads the STORE, not the stand-down latch — a read of the perf hold would refuse a player's feature verb mid-capture over an addon they never disabled. |
| `brandName` | `NS.Constants.BRAND`, the plain-text `Ka0s Absorb Tracker`, and the **same string** the LDB object carries as `label`. |
| `liveVerbs` | Built **from** `SlashLib.LIVE_VERBS` plus this addon's own two, rather than re-typed. |

What went with it was a loop that wrapped `entry[3]` for every verb not on a local `ALWAYS_LIVE`
table, and a refusal line of this addon's own routed through `NS.L`. Both were a second
implementation of a rule the dispatcher now applies, and the second one is the one that drifts.

**The refusal line is the collection's, not this addon's.** `lib.DISABLED_LINE_FORMAT` is one
spelling for eleven addons — plain-text brand, an em dash with a single space either side,
`enable it with` and the command in gold with its leading slash, no trailing period and no second
line. It is **not** routed through `NS.L`: a translated override here would give a player running
four Ka0s addons four different answers to the same question. `NS.Slash:DisabledLine()` publishes
it, and the launcher's refused left click prints that same member rather than a second copy of the
sentence: the launcher descriptor's `disabledLine` returns it, and the gate itself is
`LibKa0s-Launcher-1.0`'s (`isEnabled`, minor 2), not a check inside this addon's `onClick`.

The polarity is still deliberate. `liveVerbs` names what keeps answering, so **a verb added tomorrow
is gated by default** and has to argue its way onto the list:

| Verb | Why it stays live |
|---|---|
| `help`, `config`, `version` | A player must be able to reach the panel and see what they are running while the addon is off. |
| `enable`, `disable` | `enable` above all, or the pair is one-way — the standard MUSTs this one. |
| `debug`, `perf` | Diagnostics, not features. The usual reason to reach for either is that the addon is misbehaving. |
| `get`, `set`, `list`, `reset`, `resetall` | The schema CLI. Reading and repairing settings is exactly what a player does while the addon is off. |
| `resetposition` | **This addon's own reading, not the standard's list.** It is `reset` for the one piece of stored state no schema row addresses (`units.<unit>.position`); refusing it would withhold from a bar's anchor the repair the CLI guarantees for every value beside it, purely because of where that anchor is stored. |
| `profile` | **Also ours.** Settings management — list, switch, copy, create, delete, reset. A player who turned the addon off to get out from under a broken profile is the one who needs to switch away from it. |

Everything else refuses: `lock`, `unlock`, `toggle`, `update`, `test`. Each draws, shows, hides or
tests the thing the addon exists to do, which is `§2`'s own definition of a feature verb.

Three inputs are worth their own sentence, because they are where minor 12 and minors 13–14 differ and
where a reader's instinct is usually wrong:

- **A bare `/at` opens the settings panel**, exactly as it does when the addon is running. This is
  the case that reversed the standard's v2.56.0 narrowing: the panel is the one surface a player
  uses to switch the addon back on by hand, and a rule that hides the off switch has mistaken which
  half of the pair it protects.
- **`/at help` prints the whole index**, with the refusal line immediately under the header and
  unindented. It is not a refusal *of* `help` — the player has to be able to SEE `enable` in the
  list — it is a statement about the rows below it, some of which are the feature verbs that ARE
  refused.
- **A typo still gets `unknown command '<verb>'` and the index.** The gate sits AFTER the `COMMANDS`
  lookup: a verb the addon ships and is standing down from is refused, and a word it does not ship
  is a case where nothing was refused and the addon genuinely did not understand.

`tests/test_slashcmds.lua` and `tests/test_disabled.lua` both walk the whole `COMMANDS` table rather
than a remembered list, so an unclassified verb goes red; and for each refusing verb they assert
**both** that the line was printed **and** that the state did not move — a case that only checks the
message passes over a gate that prints and then acts anyway. What `test_disabled.lua` adds is that
this section is only half the rule: its steps 1-6 assert the **stand-down** itself, on the
registration set, and a green slash surface says nothing about whether the addon is inert.

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
(`settings/Slash.lua:524`) lowercases the sub-verb and leaves its argument alone, because AceDB
profile names are case-sensitive and a folded name deletes or switches to the wrong profile.

**Schema paths are fully qualified.** The pre-1.9 unqualified `/at set barWidth 250` is rejected:
`FindSchemaRow` has no bare-key row for a per-unit setting. Only the eight unit-agnostic rows —
`enabled`, `visibility`, `scale`, `alpha`, `locked`, `throttleWindow`, the session-only
`state.debugConsole` and the global-store `global.minimap.hide` — take a bare path.

## The verbs

| Command | Handler | Behavior |
|---|---|---|
| `/at` (no args) | the `config` handler (library) | Runs `config` with an empty rest, so a bare `/at` opens the settings panel on its landing page (slash-commands-§4). Whitespace-only input counts as bare. The library prints help instead only for a host with no `config` verb, which is not this one. |
| `/at help` | `cli:PrintHelp` (library) | Version header, then one row per `NS.COMMANDS` entry. |
| `/at config` (alias `/at options`) | `NS.OpenOptionsPanel` (library) | Open the settings category. Combat-gated inside `OpenOptionsPanel`, so every caller is refused, not just this verb. The alias is declared on the descriptor's `aliases` map, not as a second row. |
| `/at enable` / `/at disable` | `setEnabled` | The reserved pair (slash-commands-§2), and **aliases rather than a second switch**: each writes the `enabled` path the Master controls tab's Enable checkbox writes, through the same `NS.SetByPath` seam, so the row's `onChange` runs whichever surface was used and neither surface can hold a different answer. No second key, no session flag. The echo is slash-commands-§5's single-line `path = value` form, read back from the store. **The pair is not one-way:** the write moves the `disabled` hold on the stand-down latch (`core/Lifecycle.lua`) so the addon goes genuinely inert, but the dispatcher, the `COMMANDS` table, the settings registration, the AceDB handle and the launcher registration are **setup, not features** and stay up — so a bare `/at`, `/at help`, `/at version`, the whole schema CLI and `/at enable` itself all still answer with the addon off. |
| `/at list` | `cli:CliList` | Every schema row and its current value, grouped by `groupKey` — `[appearance / player]` for a per-unit page, a bare `[general]` otherwise. |
| `/at get <path>` | `cli:CliGet` | One row's stored value, in the same `key = value` shape `/at list` prints. |
| `/at set <path> <value>` | `cli:CliSet` | Type-aware parse, then `NS.SetByPath` plus `NS.RefreshOptionsPanel` — the same seam the panel widget writes through. The echo **re-reads** what was stored, so a clamp is visible. |
| `/at reset <path>` | `cli:CliReset` | Reset one row to its default via `NS.ApplyDefault`. A whole page is the panel's Defaults button, not a verb. |
| `/at resetall` | `runResetAll` → `NS.Helpers.RestoreAllDefaults` | Reset the active profile to the shipped defaults. Shared with the panel's Reset All button and the popup; the acknowledgment sits **inside** the guard, so a load without `settings/OptionsSetup.lua` says it cannot rather than claiming success. |
| `/at resetposition` | `runResetPosition` → `NS.Helpers.ResetAllPositions` | Clear every unit's saved position and re-anchor. Same guard, same reason. |
| `/at lock` / `/at unlock` | inline | `NS.SetByPath("locked", …)`, then `echoStored("locked")` — the same helper `setEnabled` uses: it refreshes an open options panel so **Lock frame** moves with the verb, and prints slash-commands-§5's `locked = true` shape read back from the store, so an unlock the row's `onChange` refuses in combat is echoed as the `locked = true` it left behind rather than as a success line. The launcher's LEFT-click is the third writer of the same path, through the same seam (launcher-§2 rung (b), `core/LauncherSetup.lua`). |
| `/at toggle [player\|target\|focus]` | `runToggle` | Bare: flip **every** bar — all off if any is on, otherwise all on. With a unit token: that one bar. See the note below. |
| `/at debug [on\|off]` | `runDebug` | Bare toggles the console **window**; `on`/`off` set session logging through `NS.DebugLog:SetEnabled`. |
| `/at debug events` | `runDebug` → `printRejectedEvents` | Every event name the client refused this session (`NS.State.rejectedEvents`, events-frames-taint-§1), comma-joined, or `Rejected events: none`. |
| `/at perf [sub]` | `runPerf` → `NS.Perf.OnCommand` | The guided perf run. Sub-verbs are the library's; see [performance.md](./performance.md). |
| `/at update` | `runUpdate` | Publish `MSG.REPAINT`. |
| `/at version` | inline | `v<version>` from `NS.Version()`. |
| `/at test <value> [secs]` | `runTest` | The one-shot timed hold, and the verb's only form: `<value>` painted on every visible bar and held by `NS.HoldPreview` for the seconds given (default 5), refused while every bar is disabled. A diagnostic, not a switch. The `[on\|off]` form went with the Test mode row under options-ui-§15 — `/at unlock` / `/at lock` are the preview switch — so a bare `/at test`, or any non-numeric word, prints the usage. |
| `/at profile <sub> [name]` | `runProfile` | The sub-verb tree below. |

## The sub-verb trees

Four verbs parse a remainder of their own. Three of them parse one word; only `profile` carries a
dispatch table, and it is the one this page is really about.

**`profile`** — `PROFILE_VERBS` (`settings/Slash.lua:465`), a table keyed by the lowercased sub-verb,
built once at load and dispatched at `:469`:

| Sub-verb | Takes a name | What it does |
|---|---|---|
| `list` | no | Every profile, the current one marked. |
| `current` | no | The current profile's name. |
| `use <name>` | yes | `db:SetProfile(name)`. |
| `new <name>` | yes | `SetProfile` **then** `ResetProfile` — the reset has to land on the new profile, not the one being left behind. |
| `copy <name>` | yes | `db:CopyProfile(name)`. |
| `delete <name>` | yes | Refuses the current profile; otherwise `db:DeleteProfile(name, true)` and prints its own line. |
| `reset` | no | `db:ResetProfile()`. |

A bare `/at profile` prints the sub-help built from `PROFILE_HELP` (`:379`), whose row order is the
contract — the table is what the help iterates, so the two cannot drift. An unknown sub-verb prints
`Unknown profile subcommand '<name>'` and then that same help. The four name-taking verbs share one
guard, `needsName(verb, fn)` (`:398`), which wraps at file load rather than at dispatch: a missing
name prints `Usage: /at profile <verb> <name>` and the handler never runs, and a dispatch allocates
nothing. Adding a sub-verb is one `PROFILE_VERBS` entry plus one `PROFILE_HELP` row.

The whole tree is gated on AceDB: with no `db.SetProfile` the verb prints
`Profile system requires AceDB-3.0` and stops, rather than indexing a shim that has no profiles.
Detail in [profiles.md](./profiles.md).

**`perf`** — `runPerf` strips nothing and hands the remainder straight to `NS.Perf.OnCommand`, which
returns lines for this addon to print. The sub-verbs, and the panel that shares them, belong to
`LibKa0s-Perf-1.0` and are documented once in [performance.md](./performance.md) rather than copied
here.

**`debug`** — `DEBUG_VERBS`, a table keyed by the lowercased token: `on` or `off` sets session
logging, `events` prints the session's rejected event names; anything else (including nothing)
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

`MirrorNote` (`settings/Slash.lua:58`) is handed to the library through `cli:SetRowAnnotator`
(`:621`). It appends `(mirrored — the bar shows Player's appearance)` in gray to a row whose unit is
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
`settings/Slash.lua:559` installs a stand-in in the shape slash-commands-§1 prescribes: dispatch and
a plain help index still render, a bare `/at` still runs the `config` verb exactly as the library
does, the host verbs — which never went to the library — keep working untouched, and each schema verb
(`list`, `get`, `set`, `reset`, `resetall`) prints the collection's library-absent line through the
locale, keyed by its English text (localization-§2):

```
[AT] /at list is unavailable: the LibKa0s library did not load.
```

What the degraded arm deliberately does **not** contain is a second copy of the row formatter, the
`key = value` shape or the value parser. Hand-copying the strings whose drift the extraction exists to
end is precisely the duplicate testing-§8 forbids, so a degraded help row renders plainly —
`/at list  List every setting and its current value`, command and description separated by two
spaces, no color escapes — and `PrintCmd` falls back to the same plain shape for `/at profile`'s rows.

The one library string the stub **does** carry is the disabled line's format. `STUB_DISABLED_LINE_FORMAT`
is `LibKa0s-Slash-1.0`'s `DISABLED_LINE_FORMAT`, byte for byte (em dash as the library spells it), so
the degraded `DisabledLine()` — which the launcher's refused left click prints — says exactly what the
live one says, gold command included. slash-commands-§1 sanctions exactly this copy and requires a pin
beside it: the value is published as `Sl.__STUB_DISABLED_LINE_FORMAT` and `tests/test_slashcmds.lua`
compares it with the live library's constant through `Kit.assertLibraryConstant`, so a re-worded
library line turns the suite red rather than leaving a stale sentence in the stub.

The stub and the real instance are both file-scope locals, which is why `Sl.__cli` (`:696`) is
published under the same `__` convention the options helpers use —
`tests/test_surface_parity.lua` is its only reader, and a stub surface that cannot be reached cannot
be compared against the one it stands in for.

## See also

- [module-map.md](./module-map.md) — where `settings/Slash.lua` sits in the load order.
- [schema.md](./schema.md) — the registry `/at list`, `/at get` and `/at set` walk.
- [profiles.md](./profiles.md) — what `/at profile` is driving.
- [performance.md](./performance.md) — the `perf` sub-verbs and the step panel.
- [settings-panel.md](./settings-panel.md) — the panel affordances these verbs share a body with.
