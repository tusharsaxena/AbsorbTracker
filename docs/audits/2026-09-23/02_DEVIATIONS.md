# 02 — Deviations

**Audited against:** Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**. All 27 section files linked
from the index were fetched and read. Every count below comes from a command recorded in
`03_EVIDENCE.md`, with its output and its scope. None of them is copied from an earlier bundle.

**Verdict: minor deviations.** Nothing here breaks anything a player, their SavedVariables or their
session can reach today. The gates are all green:

- `luacheck .` is 0/0 over 61 files.
- `lua tests/run.lua` is 710/710 with 0 skipped.
- `lizard` warns on nothing.
- Both vendored-payload diffs against LibKa0s `v1.55.0` are empty.
- The working-tree line-ending check returns 0, and `.gitattributes` diffs clean against the
  canonical body.
- The disabled state is a genuine stand-down. The registration set empties, and
  `tests/test_disabled.lua` asserts that on the mock's recording registry.

The one **High** is a missing record: 24 re-vendored LibKa0s tags have no `docs/revendor/` bundle.
`AUDIT.md` grades that check High explicitly, and this run follows it. Nothing in the running addon is
affected. Everything else is Low: structural gaps, annotations and doc drift.

## Counts, and what each count covers

- **Headline tally (roots only): 18.**
- **Total including `derived from` dependents: 19.**
- **By impact, roots:** High **1** · Medium **0** · Low **17**. The one dependent (`AT-63`) is Low.
- **MUST failures, same basis: 17 roots** (every root except `AT-78`, which is a SHOULD) plus
  **1 dependent** (`AT-63`).
- **Info: 10.** They are listed separately and are not in either tally.
- **Recorded deviations accepted: 3.** One further register row is filed for retirement as `AT-73`.

**IDs.** Prefix `AT-`, continuing from `docs/audits/2026-09-08/`, where the highest ID was `AT-68`.
Six IDs recur and keep their numbers: `AT-60`, `AT-62`, `AT-63`, `AT-64`, `AT-65` and `AT-67`.
New in this run: `AT-69` through `AT-81`. Three prior IDs are closed:

- `AT-66`: the private British list is gone, and the kit's `test_prose` is wired with `dir`.
- `AT-68`: the register row's `core/AbsorbTracker.lua:199` / `:279` citations resolve to the two
  `UnitGetTotalAbsorbs` reads again.
- `AT-Info-1`: superseded by `AT-75`.

**Why the grades are low.** Every Low entry is either code that runs only on a broken install (no
`libs/LibKa0s`), a TOC comment, a test, a document, or a comment. The MUST each one fails is named
in its row regardless.

---

## Roots

| ID | Section | Rule strength | Sev | Deviation | Fix direction |
|---|---|---|---|---|---|
| **AT-72** | `audit-review-history` (*A re-vendor commit implies a bundle*) | MUST | **High** (graded as `AUDIT.md` step 4 prescribes. Under step 5's impact table it would be Low, see Info-5) | **24 vendored LibKa0s tags have no `docs/revendor/` bundle and no `## Documented deviations` row.** The horizon is the store's oldest bundle, 2026-08-25. The payload-read tags are v1.18.0, v1.18.1, v1.19.0, v1.23.0, v1.24.0, v1.26.0–v1.29.0, v1.36.0–v1.39.0 (including v1.36.1 and v1.36.2), v1.42.0, v1.44.0, v1.45.0, v1.46.1, v1.47.0 and v1.50.0–v1.53.0. Most were carried by the collection's bulk sweeps, so the payload is correct. What is missing is the record of what arrived. | Write **one consolidated bundle** naming the span, for example `docs/revendor/<date>-v1.18.0-v1.53.0/` carrying `01_DELTA.md` and `05_SUMMARY.md`. `audit-review-history` allows that instead of one folder per tag. Do not backfill per-tag deliberation that never happened. |
| **AT-62** | `options-ui-§1` · anti-pattern #73 | MUST | Low | *Recurs from 2026-09-08, with corrected reasoning.* The Options degradation stub still carries a **host copy of all five composed blocks**: `composeBlock` at `settings/OptionsSetup.lua:241`, then `ColorPair` `:278`, `FontGroup` `:289`, `BorderGroup` `:300`, `BarGroup` `:314` and `MasterControls` `:329`. **The prior bundle's fix, "go hollow", is not available to this addon as it stands.** §1 bounds the hollow exemption by the *fall-together property*: "An addon that *can* reach a composed row from a path still working without the Options major does **not** get this exemption and **MUST** close that path's gap instead." Here the path exists. The host verbs `enable`, `disable`, `lock` and `unlock` still work on a library-less load, because the Slash stub routes them (`settings/Slash.lua:540-541`). They write the composed rows `enabled` and `locked` through `NS.SetByPath` (`:311`, `:91`, `:96`), and so do the combat re-lock (`core/AbsorbTracker.lua:259`) and the launcher stub path. The Schema stub **refuses a path with no row** (`settings/Schema.lua:160-161`). So a hollow composer would silently break `/at disable` on a degraded install. Neither shape complies: the copy is #73, and hollow leaves a composed row addressable but missing. The only case this can reach is a broken install. | Upstream first. The standard names the cure: "`LibKa0s-Options-1.0` shipping the composers from a file that loads and answers **without** the Options major". Once that lands and is re-vendored, delete the host copy. Until then, choose one of two and record it: (a) keep the copy and file a `## Documented deviations` row citing the fall-together gap and the upstream issue; or (b) make the degraded host verbs report the missing row on one honest line, which closes the path, then go hollow. Raise the §1 tension upstream (Info-6). |
| **AT-60** | `options-ui-§13` | MUST | Low | *Recurs.* No case asserts that the strip's reserved band and every row's y offset are **identical for every value of the selection**. `tests/test_widgets.lua:850` asserts only `ctx.chromeHeight > 0`. **The upstream blocker the prior bundle cited is gone.** The kit fixture now answers `Options_Tab_*` at 28 and `Options_Tab_Active_*` at 33 (`tests/_kit/mock_base.lua:102-109`), so a real case can now fail. No page wraps today (two tabs on General, five on Appearance). | Add a case that forces a wrap. Either narrow the page width or pad the labels, reading the atlas heights from `M.__atlasSizes` rather than hard-coding them. Render once per tab selection, then assert `chromeHeight` and each row's y offset are equal. Add a `-- red under:` comment naming the mutation: measure the pitch off the active atlas. |
| **AT-64** | `toc-file-§5` | MUST | Low | *Recurs.* `AbsorbTracker.toc:53`, `core\PerfSetup.lua`, is a load-bearing position with no comment of its own. `NS.Perf` is taken as a file-scope upvalue at `core/AbsorbTracker.lua:7`, in the same `# Core` block, and at `modules/Display.lua:8` and `modules/Timer.lua:9`. The comment at `:49-51` annotates `core\Lifecycle.lua`'s constraint, not this one. | At `:53`: `# LOAD-BEARING: publishes NS.Perf, which core/AbsorbTracker.lua, modules/Display.lua and modules/Timer.lua take as a file-scope upvalue (performance-§1).` |
| **AT-65** | `toc-file-§5` | MUST | Low | *Recurs.* `AbsorbTracker.toc:55`, `core\Units.lua`, is load-bearing and unannotated. `core/Database.lua:32` takes `local deepcopy = NS.Units.DeepCopy` at file load. | At `:55`: `# LOAD-BEARING: publishes NS.Units, whose DeepCopy core/Database.lua takes at file load.` |
| **AT-69** | `toc-file-§5` | MUST | Low | `AbsorbTracker.toc:47`, `core\Bus.lua`, is load-bearing and unannotated. `core/AbsorbTracker.lua:357-362` calls `NS.NewBusTarget()` and reads `NS.MSG.UNITS` at file load, behind an `if NS.NewBusTarget then` guard. That is the silent kind: move the line below `core\AbsorbTracker.lua` and the `UNITS` subscription is never made, with nothing reporting it. | At `:47`: `# LOAD-BEARING: publishes NS.NewBusTarget and NS.MSG, which core/AbsorbTracker.lua subscribes with at file load (a guarded call, so a later position fails silently).` |
| **AT-70** | `toc-file-§5` | MUST | Low | `AbsorbTracker.toc:48`, `core\CoreSetup.lua`, is load-bearing and unannotated. `NS.Print` is captured at load by `core/LauncherSetup.lua:60`. `NS.Util.print` is read at load by `core/AbsorbTracker.lua:25`. `NS.LIBKA0S_MISSING` is read at load by the stub branches of `core/DebugLogSetup.lua:22` and `core/PerfSetup.lua:28`. The constraint is written only in the file's own header, at `core/CoreSetup.lua:12-14`. | At `:48`: `# LOAD-BEARING: publishes NS.Print / NS.Util.print and NS.LIBKA0S_MISSING, captured at file load by LauncherSetup, AbsorbTracker and the stub branches of DebugLogSetup and PerfSetup.` |
| **AT-71** | `toc-file-§5` | MUST | Low | `AbsorbTracker.toc:45`, `core\Namespace.lua`, is load-bearing and unannotated. `core/PerfSetup.lua:47` captures `version = NS.version` into the perf descriptor at file load. Moving Namespace below PerfSetup would stamp every capture with a nil version. | At `:45`: `# LOAD-BEARING: publishes NS.version, which core/PerfSetup.lua captures into the perf descriptor at file load.` |
| **AT-67** | `testing-§8` | MUST | Low | *Recurs, and wider.* There is no stub-surface parity case for **`LibKa0s-Perf-1.0`** or **`LibKa0s-Lifecycle-1.0`**. `tests/test_surface_parity.lua` covers Core, DebugLog, Options, Slash, Launcher, Bus and Schema. Its header says "seven LibKa0s seams" (`:3`). Perf's stub (`core/PerfSetup.lua:23-30`) and Lifecycle's hold-set stub (`core/Lifecycle.lua:155-177`) are real stub tables with real member sets, and the host calls `lifecycle:Set`, `:IsDown`, `:Reevaluate` and `:Holds`, and `Perf.on`, `.Note`, `.OnCommand` and `.suspended`. Both stubs are complete today, so what is missing is the gate, not a member. | Add two cases on the kit's by-name form. Take the member lists from the named greps: `grep -ohE '\bPerf[.:][A-Za-z_]+'` and `grep -ohE 'lifecycle[.:][A-Za-z_]+'` over `core/ modules/ settings/`. Take the degraded arm from `tests/degraded_env.lua`, register the live halves in `Kit.setSurfaceSource`, and change the header to "nine". |
| **AT-73** | `audit-review-history` (register rows whose cited rule has changed) · `documentation-§3` | MUST | Low | The **`events-frames-taint-§1` register row** (`docs/ARCHITECTURE.md:652`) records as a deviation behavior the standard now **permits by name**. The v2.64.0 carve-out allows a private `CreateFrame("Frame")` whose only job is `RegisterUnitEvent` plus one `OnEvent`, held on the module or `NS`, unregistered in the disable path, and reused. All of that holds: the frames are built with only `SetScript("OnEvent", …)` (`core/AbsorbTracker.lua:152-154`), held at `self.__unitEventFrames` (`:156`), unregistered in `StandDown` (`core/Lifecycle.lua:95`), and reused (`:140-157`). The row now reads as a live deviation that is not one. The same claim is repeated at `docs/ARCHITECTURE.md:507` and `core/AbsorbTracker.lua:84`. | Retire the row as compliant. Rewrite `docs/ARCHITECTURE.md:507` and the long-form section at `:676-697` to cite the carve-out as the permission. Change the comment at `core/AbsorbTracker.lua:84` from "deviation" to "the events-frames-taint-§1 unit-filter carve-out". |
| **AT-74** | `events-frames-taint-§1` (*An unknown event name raises*) | MUST | Low | **The registration blocks are bare calls, not isolated per event.** `RegisterLifecycleEvents` makes three bare `RegisterEvent` calls (`core/AbsorbTracker.lua:120-122`). `SyncUnitEventFrames` makes bare `RegisterUnitEvent` calls (`:164-165`) and `RegisterEvent` calls (`:176`, `:181`). There is no `pcall`ed helper, and **no record of rejected names** reachable through `/at debug` or the console. It is latent: every name is long-standing and a client knows all of them today. But one retired name would leave every later registration unbound, with no visible error. | Add one `pcall`ed registration helper in `core/AbsorbTracker.lua` and route all seven calls through it. Record rejected names on a list the debug console prints (a `[Events] rejected: …` line, plus a `/at debug` dump) and route `StandUp`'s rebuild through the same helper. Optionally front-gate with `C_EventUtils.IsEventValid` (a SHOULD). Add a case using the kit's `M.__badEvents`. |
| **AT-75** | `documentation-§3` (hub spill) | MUST (spill) · SHOULD (≈400 lines) | Low | **The hub has stopped spilling.** `docs/ARCHITECTURE.md` is 788 lines, up from 454. `## Settings Schema` runs **116 lines** (`:118-233`) and `## Message Bus` runs **73 lines** (`:234-306`). Both are past the ~60-line MUST, whose targets are `schema.md` and `message-bus.md`. The non-mandated sections `## The disabled state is total` (`:400-486`, 87 lines) and `## Launcher` (`:346-399`) add to the bulk. | Spill Settings Schema's runtime and named-state paragraphs into `docs/schema.md`, leaving a summary and one link. Reduce Message Bus to its table plus a link, and move the rest to `docs/data-flow.md`, or to a `message-bus.md` registered as Tier 3 if preferred (the Tier 2 trigger has not fired). Move the disabled-state essay to a Tier 3 `docs/lifecycle.md` and register it. |
| **AT-76** | `options-ui-§15` · `preview-mode` · anti-pattern #80 | MUST | Low | **`/at test` exists in an addon whose unlocked view is its preview** (`settings/Slash.lua:109-110`, body `:334-372`). §15: an addon whose unlocked view already is its test mode uses *Lock frame* as the switch, and "such an addon ships no `/<slash> test` verb either". The `preview-mode` exception repeats it ("no separate test mode, row or `test` verb"), and `AUDIT.md` step 4 names the `test` verb as the finding. The verb here is a one-shot value hold, a shape §15 only allows *beside* a test mode (see Info-7). | Remove `test` from `NS.COMMANDS` and fold the value-hold diagnostic into `/at debug` as a sub-verb such as `/at debug hold <value> [secs]`, or ask upstream to allow a one-shot value hold in the exempt shape. Update the README Usage and Troubleshooting paragraphs, `docs/slash-dispatch.md` and `tests/test_slashcmds.lua` in the same change. |
| **AT-77** | `compat` | MUST | Low | **There is no `core/Compat.lua`.** `compat` says "Every addon **MUST** ship a `core/Compat.lua`. It is the **only** file that calls deprecated APIs." The file was deleted at `bebb43f` when TOC metadata moved to `LibKa0s-Env-1.0`. The one deprecated call left, the bare `GetAddOnMetadata` rung, now lives in `core/EnvSetup.lua`'s fallback (`function NS.Meta`). There is no register row for the absence. library-stack-§7 records the fact ("AbsorbTracker and PrettyChat carry none") but rules nothing on it. | Either (a) restore a thin `core/Compat.lua` owning the deprecated-metadata rung (EnvSetup calls `NS.Compat.GetAddOnMetadata`), load it first, and annotate its TOC position; or (b) file a `## Documented deviations` row keyed `compat`, with a re-check trigger of "the first deprecated or version-variant client API this addon calls outside the Env seam". Raise upstream whether `compat` should carry an applicability condition. |
| **AT-78** | `events-frames-taint-§8` (pre-formatting, outside the trigger set) | SHOULD | Low | Three pre-formatting sites fall outside the register row's scope, which names only `settings/Slash.lua` and `settings/Schema.lua`. They are `core/DebugLogSetup.lua:47` (`"debug logging " .. …`), `core/Lifecycle.lua:173` (`("%s: %s"):format(...)`) and `settings/UnitPanel.lua:409` (`("Unit panel render failed: %s"):format(...)`). None formats a protected value. The row's own count re-measures at **17**, not the 18 it states. | Pass the parts to the printer (`NS.Print("debug logging", state)`, and so on), or widen the register row to name the three files and correct its count. |
| **AT-79** | `documentation-§6` (citations) | MUST (malformed) · SHOULD (form) | Low | **Malformed citations**, which do not parse as `filename-§N`: `localization-5` at `tests/prose_waivers.lua:3` and `:7`, `tests/test_docs.lua:194` and `docs/module-map.md:852`. **Non-canonical form** (SHOULD): `packaging.md:28` at `.pkgmeta:17`, `:20` and `:21`, and `lint.md` at `.luacheckrc:9`, `:14` and `:78`. Both `packaging` and `lint` are un-numbered and are cited by bare filename. The retired `§N.M` sweep returns 0, and no citation is out of range. | Replace each with `localization-§5`, `packaging` and `lint`. The kit's own case names (`localization-5`, `line-endings-5`, `layout-1` in `docs/test-cases.md`) come from the vendored kit and are fixed upstream. |
| **AT-80** | `documentation-§5` (docs kept in sync) | MUST | Low | **Doc and comment drift against code**, rolled up. The fix is one sweep. (1) `docs/ARCHITECTURE.md:30-34` says six files bind `addonName` and "the other twenty" open `local _, NS`. The tree has **nine and nineteen**. (2) `docs/ARCHITECTURE.md:74` and `core/PerfSetup.lua:11-12` say PerfSetup "loads immediately after `core/CoreSetup.lua`", but `core\Lifecycle.lua` sits between them. (3) `docs/module-map.md:756`'s Core load order omits `Lifecycle.lua` and `LauncherSetup.lua`. (4) `.luacheckrc:25-27` says "Seven files … CoreSetup", but CoreSetup opens `local _, NS`. (5) The `settings/General.lua:14-27` diagram and `:41-43` still draw a **Test mode** row and say "all nine rows". (6) `settings/Slash.lua:296-304` still says `enabled` "gates NS.ShouldShowBar's second rung and nothing else … no event registration changes", which describes the draw gate this addon has removed. (7) The register row says the refusal key left "at LibKa0s v1.41.0" (`docs/ARCHITECTURE.md:655`), while `:570` says v1.42.0. (8) The census's "1415 lines" (`docs/ARCHITECTURE.md:728`) re-measures at 1416. (9) The Master controls *Covers* cell in `docs/settings-panel.md:68` omits the Minimap button row. | One `/wow-addon:sync-docs` pass plus the comment edits. Correct each claim against the tree, and cite symbols rather than line counts where a count will move again. |
| **AT-81** | `slash-commands-§4` | MUST | Low | `settings/Schema.lua:237` hand-writes the chat tag, `"|cFF00FFFF[AT]|r " .. line`, in `chatPrint`'s fallback arm. §4: "**MUST NOT** hand-write `"|cff…" .. addonName .. "|r"` per call site". The arm cannot be reached, because `core/CoreSetup.lua` publishes `NS.Print` on both paths (`:67`, `:106`). So this is a dead second copy of the tag. | Delete the `elseif DEFAULT_CHAT_FRAME` arm. Call `NS.Print` directly, or fall back to `NS.PREFIX` if a guard is really wanted. |

## Dependents

| ID | Derived from | Section | Rule strength | Sev | Deviation |
|---|---|---|---|---|---|
| **AT-63** | `AT-62` | `options-ui-§1` | MUST | Low | *Recurs.* The suite pins schema **equality** across the two arms where §1 asks for both counts and the named gap. `tests/test_perf.lua:501` asserts `#NS2.Schema == #NS.Schema`. `tests/test_optionssetup.lua:233` carries the comment *"red under: a stub composer returning {}"*, and `:243` asserts that the border block is four rows. Both are written to fail against the hollow shape. It **does not graduate**: its grade is no higher than the root's, no user can reach it independently, and it moves in the same change as whatever `AT-62` resolves to. |

## Recorded deviations: accepted, not re-filed

| Rule | Register row | Decided | Status this run |
|---|---|---|---|
| `savedvariables-§1` | Per-profile `schemaVersion` beside the account-wide stamp | 2026-07-28 | **Accepted.** Rule text unchanged. The trigger has not fired: `NS.MigrateProfileToV3` is live (`core/Database.lua:59`). |
| `events-frames-taint-§8` (SHOULD half) | Pre-formatted chat lines in `settings/Slash.lua` / `settings/Schema.lua` | 2026-08-05 | **Accepted.** The trigger has not fired: the named-API grep over both files returns nothing. `AT-35` resolves in `docs/audits/2026-08-05/`. The count has drifted from 18 to 17, and three sites outside its scope are filed as `AT-78`. |
| `localization-§1` | English only | 2026-08-05 | **Accepted.** This is `localization-§3`'s terminal state 2. The trigger has not fired. `AT-30` and issue #24 resolve. |

The fourth row, `events-frames-taint-§1`, is **filed for retirement** as `AT-73`, because its cited
rule changed. Its trigger has not fired, and its evidence id `AT-31` resolves.

**The inverse rule was run and files nothing.** The `state:will-not-do` issues are #16, #21, #22,
#23, #26, #27, #28 and #31. Each declines a feature, a bundle edit, an investigation, a `RenderGrid`
conversion, or adoption of an optional LibKa0s major. None declines a rule of the standard, so none
owes a register row.

## Checked and compliant (no entry filed)

- **Vendored payload:** both `diff -r` checks against tag `v1.55.0` are empty (146 and 11 files).
  The provenance line is in `CLAUDE.md:43` only. `run-automated-tests.sh` is recorded `100755`.
- **Line endings:** the body is byte-identical to the canonical client-bound file (84 lines) with
  no appendix, (e) returns 0, and `test_eol` revision 25 is wired and green.
- **Packaging:** every root dot-entry is accounted for except `.git`. No false conditional line.
- **Disabled state (`slash-commands-§7`):** one latch with two holds. Every registration is
  unregistered and both timers are canceled. Hidden at the source. No SavedVariables write from a
  game event. The `test_disabled.lua` conformance suite asserts on the recording mock. The v2.57.0
  slash surface is restored (the bare `/at` opens the panel). The launcher left-click is refused and
  the right-click opens the panel.
- **Launcher:** one object, the `Ka0s Absorb Tracker` label, rung (b) matching `ADDONS.md`, and the
  minimap row at `global.minimap.hide`, exempt from both resets.
- **Bus:** a strict `Catalog`, PascalCase names, no call-site literals, and tracked receivers.
- **Options (a)–(i):** tab strips on General and Appearance, with About and Profiles exempt.
  `Master controls` comes first and is composed. Color companions come from `ColorPair` and the group
  composers. No `disabledIf`, no reorder arrows, no hand-written font, border or bar group. One
  unboxed chrome block. No host second lock and no host panel-open (`#88` grep).
- **Layout:** census present and correct, the gate is wired, nothing is over the cap, and there is no
  generator.
- **`IconTexture`:** the addon's own 128 TGA (type 2, 128×128, 32 bpp).
- **Lint:** the exclusion narrows to `tests/_kit/`, the harness global is in `files["tests/"]`, and
  there is no top-level `ignore`.
- **Kit suites:** `test_prose`, `test_eol` and `test_layout_cap` are declared with `dir`. The suite
  inventory is pinned by `Kit.assertSuiteInventory`.
- **Complexity:** 0 warnings and a maximum CCN of 14. The watch list carries no `Accepted` entry.
  Every manifest but one records `"release": null`, so #53's shelf life has not started.
- **Documentation map:** 16 files map to 16 rows, with four tables and the fourth exact. Tier 2
  statuses match the code.
- **Issue store:** labels only, no `[status]` prefix, and no LEDGER.

## Info

| ID | Note |
|---|---|
| **AT-Info-1** | **No close-button wrapper, and none needed.** `core/CoreSetup.lua` no longer defines `NS.MakeCloseButton`. The seam "comes out" at `f445da8`. The addon builds no close control: it has no host window, and the perf panel uses the library's own arm. The `MakeCloseButton(` grep outside `libs/` and `tests/` returns only a comment. Not filed. The `standalone-windows` "wrap exactly once" MUST is scoped to an addon's own windows, and the playbook files the wrapper only when close controls are built. |
| **AT-Info-2** | **Issue store housekeeping.** #25 is still `state:triaged` over five `libs/LibStub/` files, but `find libs/LibStub -type f` returns `LibStub.lua` alone. #26 declines Widgets, yet Widgets is now bound (`modules/Bar.lua` DragHandle). Neither is a standards deviation. |
| **AT-Info-3** | **The automated-test record trails the tree.** The newest bundle, `20260916-184524`, is at `1080857`, 37 commits behind HEAD. Tests went 635 → 710, NLOC 10555 → 11389 and functions 1479 → 1639. Its band table still lists `tests/test_slashcmds.lua` over the cap at 1745, though it is now 1304 after the peel, so the census and the watch list will re-agree at the next run. Its rows predate the commit and clean cells: kit revision 25 arrived with today's re-vendor, and no run has happened since. The checkpoint is release, not commit, so this is not filed. |
| **AT-Info-4** | **Library-side:** `libs/LibKa0s/DebugLog.lua:57` sets `lib.MAX_BUFFER = 1500`, while `debug-logging-§1` says 500. This belongs in LibKa0s's own audit, not here. |
| **AT-Info-5** | **A playbook inconsistency.** `AUDIT.md` step 4 grades an unrecorded re-vendor tag **High**, while step 5's impact table grades a doc-only failure Low. This run followed step 4's explicit grade for `AT-72`. Raise it with the documentation lane. |
| **AT-Info-6** | **A standard-level tension.** `options-ui-§1`'s hollow-composer ruling assumes host verbs never reach composed rows on a degraded load. `slash-commands-§1` and `§2` keep `enable` and `disable` live there, and those write the composed `enabled` row, so every addon that composes Master controls meets `AT-62`'s dilemma. Raise upstream. |
| **AT-Info-7** | **A standard-level tension.** `options-ui-§15` permits a one-shot test action (for example, a value held for a few seconds) *beside* a test mode, yet bars any `test` verb in the lock-is-preview shape. `/at test <value>` is exactly the permitted one-shot shape, in the one addon shape where it is barred (`AT-76`). |
| **AT-Info-8** | **Bootstrap spelling.** Nineteen files open `local _, NS = ...` rather than `local addonName, NS = ...`, which lint keeps honest. Seven files put a self-naming header above the bootstrap. `documentation-§9` grandfathers existing headers. Not filed. |
| **AT-Info-9** | **Documentation-map wording.** The out-of-scope sentence (`docs/ARCHITECTURE.md:592`) names `docs/automated-tests/` and `docs/perf-analysis/` as whole directories while registering their READMEs. The standard names the `<run>` subdirectories. The `RESULTS.md` row reads "generated, never hand-edited" and omits the `Disposition` exception. Both are cosmetic. |
| **AT-Info-10** | **Open `severity:high` bug #10** ("Border is acting funny"). It is a backlog item, not a standards deviation. It belongs to the code review. |
