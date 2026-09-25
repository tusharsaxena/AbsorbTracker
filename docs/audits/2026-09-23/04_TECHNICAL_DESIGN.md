# 04 — Technical Design

This is the remediation design for every deviation in `02_DEVIATIONS.md`: all 18 roots, the one
dependent and the Info items that need action. It is keyed to the `AT-` IDs. Nothing here has been
applied. The audit is read-only.

The design splits the work by **where the change has to land**, because three findings cannot be
closed from this repo alone. Upstream changes (LibKa0s, WowAddonStandards) come first. Then the
addon re-vendors. Then the addon-local work.

---

## A. Upstream prerequisites (outside this repo)

### A1. `LibKa0s-Options-1.0`: composers that answer without the Options major (for AT-62 / AT-63)

`options-ui-§1` names the cure outright: *"`LibKa0s-Options-1.0` shipping the composers from a file
that loads and answers **without** the Options major, the way `LibStub` itself does. Until that
lands, hollow is the compliant answer."* This addon cannot take the hollow answer, because its host
verbs reach the composed rows `enabled` and `locked` on a degraded load (see `AT-62`). So the
library change is the real fix.

- **Shape.** Move the pure row-emitting half of `OptionsCompose.lua` into a unit that does not floor
  on the Options shell. That could be a new minor of Schema, or an `OptionsCompose` guard that does
  not return when `LibKa0s-Options-1.0` is absent. It would publish `ColorPair`, `FontGroup`,
  `BorderGroup`, `BarGroup`, `MasterControls` and `MASTER_GROUP` as data-only functions: rows out,
  no widget. The afterGroup tail keeps a no-op on the degraded side.
- **Constraint.** The whole-payload property must still hold. If Core is absent, everything is
  absent. The composers may drop their Options floor. They may not drop their Core floor unless
  open-evolutions' "runtime-critical majors" question is ruled first.
- **Consumer effect.** The host stub's composer arms become calls to the library, and the host copy
  is deleted. `#NS2.Schema == #NS.Schema` becomes true **by construction** rather than by a copy.

### A2. Standard clarifications (WowAddonStandards), for the Info items that are standard defects

- **Info-6** (`options-ui-§1`): the fall-together bound meets `slash-commands-§1/§2`'s live host
  verbs. Rule which one wins, or require A1 collection-wide.
- **Info-7** (`options-ui-§15`, `preview-mode`): state whether a one-shot value-hold verb is permitted
  in the lock-is-preview shape. This decides `AT-76`'s fix.
- **Info-5** (`AUDIT.md`): the step 4 High versus step 5's impact table for the re-vendor-bundle
  check.
- **`AT-77`** (`compat`): state whether an addon whose deprecated API needs are fully met by
  `LibKa0s-Env-1.0` owes a `core/Compat.lua` at all, or add an applicability condition.
  library-stack-§7 already records that this addon and PrettyChat carry none.
- **Info-4** (LibKa0s): `DebugLog.lua` `MAX_BUFFER = 1500` against `debug-logging-§1`'s 500. One of
  the two has to move.

### A3. The kit's citation form (for part of AT-79)

The kit's own case names spell `localization-5`, `line-endings-5` and `layout-1`, and
`docs/test-cases.md` inherits them. That fix is in `LibKa0s/testkit` (`test_prose.lua`,
`test_eol.lua`, `test_layout_cap.lua`). This repo only regenerates `docs/test-cases.md` after the
re-vendor.

---

## B. Re-vendor (after A1 and A3 ship)

**AT-62 / AT-63 / AT-79 (kit half).** Copy the whole ship folder and the whole `testkit/` at the new
tag. Bump `CLAUDE.md:43` in the same commit. Set the runner mode in the index with
`git update-index --chmod=+x`. Write the **consolidated re-vendor bundle** at the same time (see C1),
so this re-vendor and the 24-tag backlog get one record rather than two.

---

## C. Addon-local changes

### C1. AT-72: consolidated re-vendor bundle (documentation only)

- Create `docs/revendor/<date>-v1.18.0-v1.53.0/` with `01_DELTA.md`, which opens with the span
  (`LibKa0s v1.18.0 → v1.53.0`, 24 tags, listed), and `05_SUMMARY.md`. For each tag, the summary
  says either that the payload was carried by the collection sweep with nothing adopted, or names
  the adoption commit.
- Do not write per-tag `02`–`04` files. `audit-review-history` says a consolidated bundle discharges
  the backlog and forbids manufactured deliberation.
- Re-run the `AUDIT.md` step 4 script afterwards. The unrecorded count must be 0. The consolidated
  folder name carries both tags, and the check's `head -1 01_DELTA.md` fallback should read
  `v1.53.0`. Name the folder so that its **first** tag is one the check will match, or make the
  first line list the span explicitly.

### C2. AT-64, AT-65, AT-69, AT-70, AT-71: TOC annotations (config only)

These five comments go into `AbsorbTracker.toc`'s `# Core` block. Each sits immediately above its
line, names the symbol that resolves, and names the consumer. Nothing in the load order moves.

| Line | Comment |
|---|---|
| `core\Namespace.lua` | `# LOAD-BEARING: publishes NS.version, captured into the perf descriptor by core/PerfSetup.lua at file load.` |
| `core\Bus.lua` | `# LOAD-BEARING: publishes NS.NewBusTarget / NS.MSG; core/AbsorbTracker.lua subscribes UNITS with them at file load behind a guard, so a later position fails silently.` |
| `core\CoreSetup.lua` | `# LOAD-BEARING: publishes NS.Print / NS.Util.print and NS.LIBKA0S_MISSING, captured at file load by LauncherSetup, AbsorbTracker and the stub branches of DebugLogSetup and PerfSetup.` |
| `core\PerfSetup.lua` | `# LOAD-BEARING: publishes NS.Perf, a file-scope upvalue in core/AbsorbTracker.lua, modules/Display.lua and modules/Timer.lua (performance-§1).` |
| `core\Units.lua` | `# LOAD-BEARING: publishes NS.Units, whose DeepCopy core/Database.lua takes at file load.` |

- **Also:** add one conventional-group note (the `toc-file-§5` SHOULD) over `State.lua`, `Data.lua`
  and `Database.lua`, saying their positions are free relative to one another.
- **Risk:** none at runtime, since these are comments. `tests/test_loadorder.lua` reads TOC files
  with `Loader.tocFiles`, which skips comments, so the tests do not move.
- **Optional hardening:** a `test_loadorder` case asserting each annotated producer precedes its
  named consumer, derived from the comment text. This is not required.

### C3. AT-73: retire the `events-frames-taint-§1` register row

- Delete the row at `docs/ARCHITECTURE.md:652`. Replace the long-form "The per-unit event frames, in
  full" section (`:676-697`) with a short **design note** outside the register. It should cite the
  carve-out ("the one permitted private frame") and list how each of its four conditions is met,
  with symbols rather than line numbers.
- Update `docs/ARCHITECTURE.md:507` ("a documented events-frames-taint-§1 deviation") and the comment
  at `core/AbsorbTracker.lua:84` to say "the events-frames-taint-§1 unit-filter carve-out".
- The retirement is a doc change, not a re-decision (`audit-review-history`). No test moves.

### C4. AT-74: isolate every event registration and record the rejects

- **New helper,** file-local in `core/AbsorbTracker.lua`:
  - `safeRegister(target, event, method)` does `pcall(target.RegisterEvent, target, event, method)`.
  - `safeRegisterUnit(frame, event, unit)` does
    `pcall(frame.RegisterUnitEvent, frame, event, unit)`.
  - On failure, each appends `event` to `NS.State.rejectedEvents`, a session-only list, and makes
    one `NS.Debug("Events", "rejected: %s", event)` call.
- Route `RegisterLifecycleEvents` (three calls) and `SyncUnitEventFrames` (two per unit plus the two
  swap events) through the helpers. `StandUp` already calls those two methods, so it inherits the
  isolation.
- **Reachable record:** add `/at debug events` as a dump sub-verb (`debug-logging-§4` allows
  structured dump verbs). Or have the `[Init]` summary append `, rejected events: <list>` when the
  list is non-empty. Either one satisfies "reachable by the player".
- **SHOULD:** front-gate with `C_EventUtils.IsEventValid(event)` where it exists. The `pcall` stays
  the guard.
- **Tests:** a case in `tests/test_units.lua` or a new `tests/test_events.lua` that sets
  `M.__badEvents = { PLAYER_FOCUS_CHANGED = true }`, calls `SyncUnitEventFrames`, and asserts:
  - every other registration landed;
  - the rejected name is recorded;
  - add `-- red under: drop the pcall in safeRegister`.
- **Risk:** the teardown lists in `core/Lifecycle.lua:68-71` are by name and stay correct. A
  rejected event is simply never registered, and `UnregisterEvent` on it is safe.

### C5. AT-75: spill the hub

- `## Settings Schema`: keep about 20 lines. Say that there are 70 rows, how the pages and tabs
  divide them, that the runtime is `LibKa0s-Schema-1.0`, that the seam is `NS.SetByPath`, that there
  is no registry, and name the two pieces of named state in one sentence each. Add one link to
  `schema.md`. Move the runtime-binding paragraph, the bulk-bracket paragraph and the full
  named-state writer lists into `docs/schema.md` (their canonical home).
- `## Message Bus`: keep the table and the receiver rule. Move the Bus-record paragraph and the
  "other cross-cutting refresh" / AceDB-callback paragraph to `docs/data-flow.md`. Add one link.
- `## The disabled state is total` (87 lines): move it to a new Tier 3 `docs/lifecycle.md` and leave
  a three-line summary and a link. Register it in a new `### Addon-specific` table.
- **Target:** hub ≤ ~400 lines, and no mandated section over ~60.
- `tests/test_docs.lua`'s doc-shape assertions will need updating if they pin headings.

### C6. AT-76: the `test` verb

This depends on A2's ruling on Info-7.
- **Default path** (the standard stays as written): remove `{"test", …}` from `NS.COMMANDS`. Keep
  `runTestHold` as the body of a `debug` sub-verb (`/at debug hold <value> [secs]`). A diagnostic
  under `debug` is permitted and live while disabled, which is acceptable for a pure display
  diagnostic.
- Update the README Usage paragraph at `README.md:34-36` and the Troubleshooting row at `:120`,
  `docs/slash-dispatch.md`, `docs/smoke-tests.md`, `tests/test_slashcmds.lua` / `tests/test_disabled.lua`
  (the feature-verb list), and `docs/test-cases.md`.
- Run the README edit through the de-AI pass (`documentation-§1`).
- **If A2 permits it:** leave the verb and add nothing.

### C7. AT-77: `core/Compat.lua`

This depends on A2's `compat` ruling.
- **Default path:** add `core/Compat.lua`, loaded **first** in `# Core` (annotated conventional). It
  publishes `NS.Compat.GetAddOnMetadata(addon, field)` as the single deprecated-API rung
  (`C_AddOns.GetAddOnMetadata`, then the legacy global).
- `core/EnvSetup.lua`'s fallback calls it instead of the globals.
- Update the `compat-layer.md` Not-applicable row to "1 shim, threshold 3". Update `.luacheckrc`
  (the `GetAddOnMetadata` read-global stays). Add a module-map row.
- **If A2 adds an applicability condition:** nothing to do. **Alternatively,** file a register row
  keyed `compat`.

### C8. AT-78: pre-formatting outside the row's scope

- `core/DebugLogSetup.lua:47` becomes `NS.Print("debug logging", on and "|cff40ff40ON|r" or "|cffff4040OFF|r")`.
- `core/Lifecycle.lua:173` becomes `NS.Print(addonName .. ":", …)`, passing the holds as a second
  argument.
- `settings/UnitPanel.lua:409` becomes `NS.Print("Unit panel render failed:", err)`. The printer
  already runs every argument through `SafeToString`.
- Correct the register row's count from 18 to 17 in the same change. Re-count it with the recorded
  grep.

### C9. AT-79: citation forms

- Change `localization-5` to `localization-§5` at `tests/prose_waivers.lua:3` and `:7`,
  `tests/test_docs.lua:194` and `docs/module-map.md:852`.
- Change `packaging.md:28` to `packaging` at `.pkgmeta:17`, `:20` and `:21`.
- Change `lint.md` to `lint` at `.luacheckrc:9`, `:14` and `:78`.
- Check first that `tests/prose_waivers.lua` stays outside the prose scan (kit revision 24 says it
  does), so a `§` in its comments costs nothing.
- The kit-case half is covered by A3 and B.

### C10. AT-80: documentation and comment sync (one sweep)

| Where | Change |
|---|---|
| `docs/ARCHITECTURE.md:30-34` | "nine files bind `addonName` … the other nineteen", naming the nine: AbsorbTracker, Bus, DebugLogSetup, EnvSetup, LauncherSetup, Lifecycle, MediaSetup, Namespace, PerfSetup |
| `docs/ARCHITECTURE.md:74`, `core/PerfSetup.lua:11-13` | "loads after `core/Lifecycle.lua`, whose latch the descriptor carries" |
| `docs/module-map.md:756` | add `Lifecycle.lua` and `LauncherSetup.lua` to the Core order, with their constraints |
| `.luacheckrc:25-27` | name the nine binding files, drop CoreSetup |
| `settings/General.lua:14-27`, `:38-43` | redraw the diagram without Test mode and with `[Minimap button]`, and say "seven rows plus the button pair" |
| `settings/Slash.lua:292-304` | describe the latch: `enabled` moves the `disabled` hold, and the stand-down unregisters |
| `docs/ARCHITECTURE.md:655` vs `:570` | settle on the release the key actually left in (check `git log -S`) |
| `docs/ARCHITECTURE.md:728` | state the measured count, or drop the number in favor of the gate |
| `docs/settings-panel.md:68` | add "show or hide the minimap button" to the Master controls cell |

Run `/wow-addon:sync-docs` afterwards to catch anything this list missed.

### C11. AT-81: the dead hand-written tag

Delete the `elseif DEFAULT_CHAT_FRAME` arm of `chatPrint` in `settings/Schema.lua`, and have it call
`NS.Print` directly. `core/CoreSetup.lua` guarantees the printer on both paths.

### C12. AT-60: the wrap-stability case

- **Test only.** In `tests/test_widgets.lua`, build the General or Appearance page under a width
  narrow enough to wrap the Appearance strip's five tabs. Use a mocked parent width, or pad labels
  with a test-only row set.
- Read the pitch inputs from `M.__atlasSizes` (28 unselected, 33 selected). Do not hard-code them.
- For each tab index, select it and record `ctx.chromeHeight` and every row's y offset.
- Assert all selections are equal. Carry `-- red under: pitch measured off Options_Tab_Active_*`.
- This case can fail against a wrong library, which is the point. If it goes red at the current tag,
  that is a LibKa0s defect, fixed upstream (`options-ui-§13`, anti-pattern #70).

### C13. AT-67: parity cases for Perf and Lifecycle

- Add two cases to `tests/test_surface_parity.lua`:
  - `T.assertSurfaceParity(NS2.Perf, "LibKa0s-Perf-1.0", {…ignore…})`;
  - `T.assertSurfaceParity(NS2.lifecycle, "LibKa0s-Lifecycle-1.0", {…})`.
- Register the live halves in `Kit.setSurfaceSource` (`tests/run.lua`), which are `NS.Perf` and
  `NS.lifecycle`.
- The ignore sets name the live-only members the host never calls, each with its reason. For
  example, Perf's `Suspend` and `Resume` are called only by tests.
- Put the member-list greps in the case comments.
- Change the header's "seven" to "nine".

### C14. AT-62 / AT-63: interim, if A1 is not available when this addon's pass runs

Choose one path and record it.

- **(a) Register row** (lowest risk). Add
  `| options-ui-§1 | Options stub carries host copies of the five composed blocks | fall-together fails: host verbs enable/disable/lock/unlock write composed rows on a library-less load, and the Schema stub refuses an unknown path | <date> | LibKa0s ships the composers without the Options major (A1) |`.
  Tests stay as they are.
- **(b) Close the path.** Hollow composers (`return {}, function() end`). The degraded Slash stub's
  host verbs check `NS.FindSchemaRow(path)` and print one honest line when the row is missing.
  Rewrite the pins to three figures: the full count, the degraded count, and the named gap
  attributed to the five composers. Delete `composeBlock` and `ORDER_STEP`.
- **Recommendation:** (a) now, and A1 plus the deletion at the next re-vendor. Path (b) makes a
  broken install's `/at disable` stop working, which is a worse degraded experience than keeping the
  copy for one more cycle.

---

## Ordering constraints and risks

1. **A before B before C14/C6/C7.** The fixes that depend on library or standard decisions wait for
   those decisions. Everything else in C is independent of upstream and can land first, in any order.
2. **C1 and B belong in the same commit window.** The consolidated bundle should also record the new
   re-vendor, so the store has no new gap the moment it closes the old one.
3. **C4 touches the registration path that `tests/test_disabled.lua` measures.** Run that suite in
   the same commit, because step 3 and step 9 compare registration sets by name.
4. **C5 and C10 touch the same files** (`docs/ARCHITECTURE.md`). Do C10's line-level fixes first,
   then C5's moves, so the spill does not carry stale text into `schema.md`.
5. **Every change regenerates `docs/test-cases.md` and the README `[tests]` badge** when the case
   count moves (`testing-§5`).
