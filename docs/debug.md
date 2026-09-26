# Debug surface

The console is **`LibKa0s-DebugLog-1.0`**'s, wired by `core/DebugLogSetup.lua`: the window, the
buffer (3000 lines, `lib.MAX_BUFFER`), the **Copy** box, the `on`/`off` seam and the chat
acknowledgment are the library's, and `/at debug`, `/at debug on` and `/at debug off` drive it the
way they drive every Ka0s console (`debug-logging`; the in-game walk is section H of
[smoke-tests.md](smoke-tests.md)). The descriptor and the instance's surface are in
[module-map.md](module-map.md#debuglogsetup-coredebuglogsetuplua).

This page covers what the library does not: the **diagnostics report**, whose sections this addon
writes, the two addon-owned `debug` words, and the trace tags this addon logs under.

| Verb | Runs | Console tag | Answers |
|---|---|---|---|
| `/at diagnostics` or `/at debug diagnostics` | `NS.DebugLog:RunDiagnostics()` over `NS.Diagnostics.Sections()` (`modules/Diagnostics.lua`) | `[Diag]` markers, one tag per section | Everything a maintainer asks first: build, state, settings, each bar's show ladder, frames, media, colors, the absorb readout, events, the repaint throttle, the combat counters and the UI |
| `/at debug events` | `printRejectedEvents` (`settings/Slash.lua`) | none (chat) | The event names the client refused this session |
| `/at debug hold <value> [secs]` | `runHold` (`settings/Slash.lua`) | none (chat) | Paints a fake absorb on the bars for 0.5 to 60 s (default 5), so a layout can be checked without a shield |

All of them live on the `debug` row of `NS.COMMANDS` (`settings/Slash.lua`), and the report has its
own `diagnostics` row as well. `runDebug` tests `diagnostics` first, then `on`, `off`, `events` and
`hold`; any other word, or none, toggles the console window.

## The raw-append rule

The report writes through the library's raw append (`NS.DebugLog:Add(tag, line)`, which
`RunDiagnostics` calls), and **not** through the gated sink `NS.Debug`. So it prints whether logging
is on or off: you do not need `/at debug on` first, and turning logging on adds nothing to it. A
report the player asked for is not idle cost, and a console that stays empty because the flag
happened to be off reads as a broken verb (`debug-logging-§4`).

Two consequences follow:

- `debug` and `diagnostics` are reserved verbs (`slash-commands-§2`), so the report still answers
  while the addon is **disabled**, through both forms. The sections that describe released machinery
  say so (see **Stood down** below). `/at debug hold` is the one `debug` word that refuses while
  disabled, because it paints the bars ([slash-dispatch.md](slash-dispatch.md)).
- Without LibKa0s, `core/DebugLogSetup.lua`'s degraded stub keeps the verbs from raising: `Show`
  prints the one "debug console window is unavailable" line and `Add` is a no-op. `/at diagnostics`
  prints `/at diagnostics is unavailable: the LibKa0s library did not load.`, writes nothing and
  returns 0. A report of a hundred lines sent to chat instead would be worse than none.

## `/at diagnostics`

The report (`debug-logging-§14`). Run it **after** reproducing the problem, not before: it is
appended below whatever the console already holds, so the trace you just produced and the state it
left behind travel in one **Copy**.

**Two forms, no third.** `/at diagnostics` and `/at debug diagnostics` (either case, and through
`/absorbtracker` as well as `/at`) are the same call. There is no `diag`, `dump` or `dx` alias:
`/at debug diag` is an ordinary unknown word, which toggles the console like any other, and
`/at diag` is an unknown command.

**What it does to the console.** It never clears it, and it never changes the logging flag, only
prints it. It shows the console if it was hidden. Then it prints one chat line, the only localized
line of the report: *Diagnostic report written to the debug console: N lines. Use Copy to share it.*

**The shape.** The library writes the frame and this addon writes the sections, in this order:

| Part | Tag | Written by | What it holds |
|---|---|---|---|
| Begin marker | `[Diag]` | the library | `==== Ka0s Absorb Tracker diagnostics begin ====` |
| Identity header | `[Diag]` | the library | The `[Init]` summary line (version, schema, profile), the client version, build, date and interface, the locale, the debug flag, `InCombatLockdown()` and `UnitAffectingCombat("player")`, and every LibKa0s file **running** in the client with its minor. Running, because under LibStub another addon's newer copy may be the one loaded |
| `state` | `[Diag]` | this addon | The schema version stored (global and profile stamp) and in code, the active profile, stored `enabled` against the stand-down latch, and test mode: none, because the unlocked view is this addon's preview (`options-ui-§15`), so the line says whether the bars are unlocked |
| `lifecycle` | `[Life]` | this addon | The Lifecycle holds, the perf probe (capturing, run, armed) and whether the bus is live or stood down |
| `settings` | `[Set]` | this addon | The six addon-wide globals (`enabled`, `visibility`, `alpha`, `scale`, `locked`, `throttleWindow`) and `global.minimap.shown` always; every other schema row only when it differs from its default, each as `path = value (default)`; then the session-only console toggle `state.debugConsole` |
| `units` | `[Unit]` | this addon | Per unit (player, target, focus): its switch, the mirror and its source unit, `UnitExists`, then `NS.ShouldShowBar` with the rung that decided it (`NS.VisibilityReason`) against what `ApplyVisibility` last applied (`NS.LastAppliedVisibility`) |
| `frames` | `[Frame]` | this addon | Per bar frame: shown and visible, alpha against `NS.GetBarAlpha`, scale, size, the live anchor against the stored position and the default-position flag, and the drag handle. `not built` for a bar never created |
| `media` | `[Media]` | this addon | Per unit, the four media rows (`barTexture`, `bgTexture`, `border`, `font`): the stored LibSharedMedia name, the path it resolved to, and the rung that resolved it, asked of LSM itself: `lsm`, `lsm default` (LSM answered its own default for a name nobody registered, as when a SharedMedia pack is uninstalled) or `fallback` |
| `colors` | `[Color]` | this addon | Per unit: the class token of the unit the bar renders (not the mirror source's, `options-ui-§17`), the four class-color flags, and the resolved RGBA of bar, background, border and text |
| `absorb` | `[Absorb]` | this addon | Per unit: `UnitGetTotalAbsorbs` and `UnitHealthMax`, printed as they are when a concat can survive them and as `<secret>` when not |
| `events` | `[Events]` | this addon | The AceEvent events the addon holds, read off AceEvent's own registry, and each unit frame's `UNIT_ABSORB_AMOUNT_CHANGED` / `UNIT_MAXHEALTH` registration |
| `rejected` | `[Events]` | this addon | What `/at debug events` prints: every event name the client refused this session. The topic word stays for a quick look without the rest |
| `repaint` | `[Repaint]` | this addon | Whether a coalesced repaint is pending (`NS.IsRepaintPending`), the throttle window, and the time left on a `/at debug hold` |
| `counters` | `[Counters]` | this addon | `NS.SessionCounters()`: absorb events, repaints and the last absorb since the last combat start. They count only while logging is on, which the line says |
| `ui` | `[UI]` | this addon | Whether the settings panel is open, the launcher registered and shown, and any library from the addon's list that is missing from this install |
| `truncated` line | `[Diag]` | the library | Only when a cap bit: `truncated: N line(s) omitted, per-list caps hit=yes/no` |
| End marker | `[Diag]` | the library | `==== Ka0s Absorb Tracker diagnostics end: N line(s) ====`, counting both markers |

A full report on a default install runs to well under 150 lines; `tests/test_diagnostics.lua`
holds it there.

**Stood down.** While the addon is disabled every section still runs. `events` prints one line,
`stood down: every registration released (holds: ...)`, rather than an empty registration set that
looks like a fault, `lifecycle` reports the bus as stood down, and `repaint` reads `pending=stood
down`. Stored configuration (settings, units, media, colors) prints as normal.

**Caps.**

- The whole report: at most `min(lib.DIAG_MAX_LINES, lib.MAX_BUFFER - 100)` lines, markers
  included. That is **1200** at LibKa0s v1.60.0 (`min(1200, 3000 - 100)`), so a full report leaves at
  least 1800 lines of trace above it in a full console. Two lines stay reserved for the `truncated`
  line and the end marker, so a capped report still ends properly.
- The rejected-events list: 40 names (the library's `DIAG_MAX_PER_LIST`), then `(+N more)`.
- A long list on one line (the AceEvent set, missing libraries) wraps onto continuation lines at
  200 characters rather than being cut.

**What it deliberately does not read or call.**

- **No writes and no machinery.** No setter or `NS.SetByPath`, no bus publish, no
  `NS.RequestRepaint`, no `SyncUnitEventFrames`, no Lifecycle hold, no timer, no `Show`/`Hide`, no
  `OpenOptionsPanel`, and never `Clear()`. It reads through the four read-only seams (`NS.VisibilityReason`,
  `NS.LastAppliedVisibility`, `NS.IsRepaintPending`, `NS.SessionCounters`) and through getters.
- **No arithmetic on a secret.** In restricted content `UnitGetTotalAbsorbs` and `UnitHealthMax`
  answer secret values. The report never compares, converts or formats them: `NS.IsConcatSafe` is
  the only question asked of them, and a secret prints as `<secret>`. It never reads the bar's own
  `GetValue` or `GetText`, which hold the same secret. A number it formats is first proved readable
  with `out:readable`; one that is not prints as `?`.
- **No protected API**, so it is safe in combat.
- **No raw values.** Every value reaches a line as an argument to the library's `out:add`, which
  stringifies it through `SafeToString` before any format sees it. Color, texture and hyperlink
  escapes are stripped, so the **Copy** text is clean.
- **Each section under its own `pcall`.** A section that raises costs one line, `section <name>
  failed: <err>`, and the next section still runs.
- **AceEvent's registry is walked, never indexed.** CallbackHandler builds an empty entry for any
  event name it is indexed with, so the `events` section uses `pairs` and changes nothing.

Nothing is redacted: the report goes to the maintainer privately with a bug report. Report lines
are English diagnostic text and do not go through `NS.L`; the one chat line does.

## Trace tags

With `/at debug on`, the gated sink `NS.Debug` writes these tags. They are what the report's trace
above the begin marker is made of.

| Tag | Written by | When |
|---|---|---|
| `[Init]`, `[Debug]` | the library | On `/at debug on` and `off`: the session summary and the flag change |
| `[Absorb]` | `core/AbsorbTracker.lua` | A shield comes up or goes away (values only when readable) |
| `[Bar]` | `modules/Display.lua` | A bar is shown or hidden, with the rung that decided it |
| `[Combat]` | `core/AbsorbTracker.lua` | Combat starts, and on leaving it, the absorb-event and repaint counts |
| `[World]` | `core/AbsorbTracker.lua` | `PLAYER_ENTERING_WORLD` |
| `[Events]` | `core/AbsorbTracker.lua` | The client refused an event registration |
| `[Bus]` | `core/Bus.lua` | A subscription was refused on stand-up |
| `[Migrate]` | `core/Database.lua` | A schema migration step ran or failed |
| `[Set]` | `LibKa0s-Schema-1.0` | One line per bulk copy or reset (`debug-logging-§10`) |
| `[Launcher]` | `core/LauncherSetup.lua` | A launcher click found no `/at` handler to run |
| `[Perf]` | `LibKa0s-Perf-1.0` | The perf run's lines, written ungated ([performance.md](performance.md)) |

## Which to paste

For any bug, follow the README's **Reporting a bug** steps: `/at debug on`, reproduce the problem,
run `/at diagnostics`, then open the console with `/at debug` if it is not already open, press
**Copy** and include the entire output with the report. That one copy holds the trace and the whole
report, and the report already carries what `/at debug events` prints.

- For a bar that is missing or showing when it should not, run the report **while the bar is in
  that state**: the `units` section names the rung of the show ladder that decided it.
- For a bar that draws with the wrong texture, border or font, the `media` section says whether
  LibSharedMedia resolved the stored name or the addon fell back to its own literal.
