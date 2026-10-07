# 02 — Deviations

**Audited against:** Ka0s WoW Addon Standard **v2.76.1 (2026-10-07)**, all 27 section files linked
from the index, fetched and read; `AUDIT.md` as of the same `master`. Repo kind **addon**. Commit
`4cedffa`. Every count below comes from a command recorded in `03_EVIDENCE.md` with its output and its
scope; none is copied from an earlier bundle.

**Verdict: minor deviations.** Nothing a player, their SavedVariables or their session can reach today
is wrong. The gates are green — `luacheck .` 0/0 over 69 files; `lua tests/run.lua` 876 passed, 0
failed, 1 skipped (877); sighted complexity pass, 0 warnings, max CCN 14, 0 blind files; both
vendored-payload diffs against tag `v1.70.0` empty; line-ending check (e) 0 of 637 tracked files;
`.gitattributes` byte-identical to the canonical client-bound body. The disabled state is a genuine
stand-down: every registration the addon owns is undone in `StandDown`, and `tests/test_disabled.lua`
asserts it on the recording mock.

What remains is record-keeping and annotation: two re-vendors of the last two days carried no bundle and
no doc sync, two settings-block TOC positions are load-bearing and unannotated, one register row is
stale since v2.65.0, one doc quotes raw `lizard`, the Widgets major has no seam, and two SHOULD-level
debug and printer habits.

## Counts, and what each count covers

- **Headline tally (roots only): 9.**
- **Total including `derived from` dependents: 9** (no dependents this run).
- **By impact, roots:** High **0** · Medium **0** · Low **9**. (Info entries are listed separately and
  are in neither tally: **8**.)
- **MUST failures, same basis: 7 roots** (`AT-80`, `AT-82`, `AT-83`, `AT-84`, `AT-85`, `AT-86`,
  `AT-88`), **0 dependents**. The other two roots (`AT-78`, `AT-87`) fail a SHOULD.
- **Recorded deviations accepted: 2** register rows (not counted). One further row is filed for
  retirement as `AT-86`.

**IDs.** Prefix `AT-`, continuing from `docs/audits/2026-09-23/` (highest `AT-81`). Recurring with new
evidence: `AT-78`, `AT-80`. New: `AT-82` – `AT-88`. Closed since 2026-09-23 (re-measured, see
`01_CURRENT_STATE.md`): `AT-60`, `AT-62`, `AT-63`, `AT-64`, `AT-65`, `AT-67`, `AT-69`, `AT-70`, `AT-71`,
`AT-72`, `AT-73`, `AT-74`, `AT-75`, `AT-76`, `AT-77`, `AT-79`, `AT-81`. `AT-82` is the same class as the
closed `AT-72` (an unrecorded re-vendor) but a new lapse over new tags, so it takes a new ID.

**Why every grade is Low.** Each root is a document, a comment, a register row, a record bundle, or a
code shape that changes no output a player sees. The MUST each fails is named in its row regardless —
a Low grade is not the rule being optional.

---

## Roots

| ID | Section | Rule strength | Sev | Deviation | Fix direction |
|---|---|---|---|---|---|
| **AT-82** | `audit-review-history` (*A re-vendor commit implies a bundle*) | MUST | Low | **Two vendored LibKa0s tags have no `docs/revendor/` bundle and no register row: `v1.69.0` and `v1.70.0`.** The payload-side walk (commits touching `libs/LibKa0s` or `tests/_kit` since the store's horizon 2026-08-25, tag read off `CLAUDE.md` at each) yields 51 tags over 54 commits; the recorded side yields 50 (49 of the 51, plus `v1.59.0`, which the span bundle `2026-09-26-v1.58.0-v1.60.0` records though no commit's provenance line named it); vendored-but-unrecorded is exactly these two. Both were vendored by stand-alone commits, `5075fd5` (2026-10-06) and `4c16982` (2026-10-07), each touching only the payload and the provenance line. The payload itself is correct (both diffs empty). | One consolidated span bundle, `docs/revendor/2026-10-07-v1.68.1-v1.70.0/` (or the date it is written), with `01_DELTA.md` line 1 `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.68.1 v1.69.0 v1.70.0)` and a `05_SUMMARY.md` line per tag (*carried, nothing adopted* — `WidgetsLineChart` and `WidgetsAutocomplete` have no consumer here). Do not invent per-tag deliberation. |
| **AT-80** | `documentation-§5` (docs kept in sync) | MUST | Low | *Recurs, with new items.* **Doc and comment drift against the tree, rolled up; one sync pass fixes all of it.** (1) The library inventory reads *thirty-two files* in four places — `docs/ARCHITECTURE.md:49`, `docs/module-map.md:786`, `:942`, `docs/performance.md:390` — while `LibKa0s.xml` lists **34** (`WidgetsLineChart.lua`, `WidgetsAutocomplete.lua` arrived with v1.69.0/v1.70.0). (2) The `LibKa0s.xml` load-order chains at `docs/module-map.md:786` and `:942` go `WidgetsDragHandle.lua` → `DebugLog.lua`, omitting the same two files. (3) `docs/testing.md:170` says `CLAUDE.md` names **v1.68.1**; it names v1.70.0. (4) `docs/module-map.md:884` says `tests/run.lua` is 175 lines and runs "the thirty-two suites of its own"; it is 178 lines and declares **35** own suites plus the kit's five. (5) `docs/module-map.md:887` describes a mock asserting "the two-frame split (player+target on one frame, focus on the other)"; the code builds **one frame per unit** (`core/AbsorbTracker.lua:193-198`). (6) `docs/module-map.md:916` says the `rawget` hardening is "live here at DebugLog 6 / Slash 5 / Perf 5"; the vendored minors are DebugLog 19, Slash 19, Perf 14. (7) *Carried from 2026-09-23 item 7:* `docs/module-map.md:468` and `:817` say the disabled refusal left the addon at **v1.41.0**; the register row (`docs/ARCHITECTURE.md:377`) and `docs/slash-dispatch.md:52` say v1.42.0. | One `/dev-copilot:sync-docs` pass. Recount from the tree rather than incrementing (34 files; 35 + 5 suites; 178 lines), add the two files to both load-order chains, roll `docs/testing.md:170` to the provenance tag, rewrite the mock sentence for three per-unit frames, drop or re-derive the minors in `:916`, and settle v1.41.0 vs v1.42.0 on the tag where Slash minor 14 shipped (v1.42.0). Prefer citing the XML and `tests/run.lua` over restating counts that move each re-vendor. |
| **AT-83** | `performance-§10` (*the command a gate line or a reader quotes*) · `automated-tests-§3` (*The complexity gate is sighted*) · anti-pattern #92 | MUST | Low | **`docs/automated-tests/README.md:29` gives the `complexity` suite's command as raw `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .`** — no `-L 1500`, not the runner, and run over the tree, which v2.74.0 calls blind in Lua. `docs/testing.md:99` and `DEPENDENCIES.md:272` already quote the runner correctly, so the two pages contradict each other. Nothing is measured blind today (the runner is what runs), so this is a reader-facing record defect. | Replace the cell with `bash tests/_kit/run-automated-tests.sh --suite complexity` (the runner's sighted shadow, with function-count parity; kit revision 35+), matching `docs/testing.md:99`. |
| **AT-84** | `toc-file-§5` (*Every position in the listing is one of two things*) | MUST | Low | **`AbsorbTracker.toc:83`, `settings\Schema.lua`, is load-bearing and unannotated.** `settings/OptionsSetup.lua:98`, `:144` and `:145` read `NS.SchemaRuntime.AllRows`, `.BulkBegin` and `.BulkEnd` into the Options descriptor at file load, and `settings/General.lua:254` calls `NS.RegisterSchemaRows` at file load; both are published by this file (`settings/Schema.lua:400`, `:407`). Moved below `settings\OptionsSetup.lua`, the descriptor indexes a nil `NS.SchemaRuntime` at load. The only note is the section header (`:82`), which names no symbol. The 2026-09-23 audit read the Core block only, as `AUDIT.md`'s check is worded; toc-file-§5's rule covers the whole listing. | At `:83`: `# LOAD-BEARING: publishes NS.SchemaRuntime and NS.RegisterSchemaRows, which settings/OptionsSetup.lua's descriptor and the page files read at file load.` |
| **AT-85** | `toc-file-§5` | MUST | Low | **`AbsorbTracker.toc:85`, `settings\OptionsSetup.lua`, is load-bearing and unannotated.** It publishes `NS.Helpers` (`settings/OptionsSetup.lua:377`), which `settings/UnitPanel.lua:17`, `settings/About.lua:19`, `settings/General.lua:12` and `settings/Appearance.lua:74` capture as file-scope upvalues, and whose composers General and Appearance call inside `NS.RegisterSchemaRows` at load. Moved below any of them, that file captures nil. | At `:85`: `# LOAD-BEARING: publishes NS.Helpers, which UnitPanel, About, General and Appearance take as a file-scope upvalue and call into at load.` Optionally one conventional note for `Slash`/`Profiles` (the SHOULD). |
| **AT-86** | `audit-review-history` (register rows whose cited rule has changed) · `documentation-§3` (*MUST NOT be a graveyard*) | MUST | Low | **The `savedvariables-§1` register row (`docs/ARCHITECTURE.md:375`) records as a deviation a shape the standard now sanctions by name.** Since v2.65.0, savedvariables-§1 says a profile-scoped step **MUST** run for every stored profile "either by walking the raw SavedVariables `profiles` table … or idempotently from AceDB's `OnProfileChanged` (and `OnProfileCopied` / `OnProfileReset`) callbacks against a **per-profile** stamp". The row's per-profile `schemaVersion` gating the v3 lift, re-run from all three callbacks (`core/AbsorbTracker.lua:359-417`) and swept over every profile at load (`core/Database.lua` `migrateAllProfiles`), is that second route, and the account-wide stamp defaults to 0 and is runner-owned as §1 now requires. The row's trigger has not fired, but its cited rule changed under it, so it reads as a live deviation that is not one. | Retire the row as compliant: move it to `docs/recorded-decisions.md` → *Retired register rows* with the date and "savedvariables-§1 (v2.65.0) names the per-profile-stamp route", and keep the reasoning link to `profiles.md`. |
| **AT-88** | `library-stack-§7` (*Ship payload vs adoption*: "one setup file per module, each resolving its major with `LibStub(major, true)` and degrading to a stub") · `testing-§8` (stub-surface parity per adopted module) | MUST | Low | **`LibKa0s-Widgets-1.0` is adopted with no seam.** The major is resolved twice, at `modules/Bar.lua:15` and `modules/Display.lua:26`, each with inline nil-guards (`modules/Bar.lua:126`, `modules/Display.lua:27-28`) rather than one setup file publishing an `NS.*` surface with a stub. The hub records the shape (`docs/ARCHITECTURE.md:49-51`) but no register row ratifies it, and no parity case covers the members the addon reaches (`DragHandle`, `DRAG_HANDLE`). The degraded path is honest today — no widget, no strip, `HANDLE_ROOM = 0` — so this is structural. Separately, issue #26 (`state:will-not-do`, "Widgets declined") is now contradicted by the adoption (Info-3). | Either add `core/WidgetsSetup.lua` (or fold into an existing seam) resolving the major once and publishing `NS.Widgets` with a stub answering `DragHandle` (nil) and `DRAG_HANDLE` (nil), point both modules at it, and add a by-name parity case; or file a `## Documented deviations` row keyed `library-stack-§7` stating why two nil-guarded lookups stand, with a re-check trigger (a third Widgets member reached, or a second file). |
| **AT-78** | `events-frames-taint-§8` (pre-formatting, outside the trigger set) | SHOULD | Low | *Recurs, with new evidence.* The three sites filed on 2026-09-23 are fixed. **One new site formats outside the register row's scope:** `core/Database.lua:234-235`, `NS.Print("Settings upgrade stopped at v" .. from .. " -> v" .. step.to .. "; saved settings were left as they were")`. It formats two integers the addon owns, so it is outside §8's trigger set and the SHOULD NOT applies. (`core/Lifecycle.lua:186`'s `addonName .. ":"` sits in the library-absent stub and concatenates the folder name; `modules/Bar.lua:36` formats a localized one-sentence string with placeholders, which localization-§2 requires; neither is filed.) The register row's own count re-measures at 17 and its trigger has not fired. | Hand the parts to the printer: `NS.Print("Settings upgrade stopped at", "v" .. from, "->", "v" .. step.to, "; saved settings were left as they were")`, or widen the register row to name `core/Database.lua`. |
| **AT-87** | `debug-logging-§9` (*Use the console's gates*, SHOULD) | SHOULD | Low | **Two hand-rolled log-on-change memos, and the DebugLog descriptor carries no `onClear`.** `core/AbsorbTracker.lua:244` compares `secret ~= dbgAbsorbSecret` before writing the readable/secret edge line, and `modules/Display.lua:381-382` compares `show ~= dbgLastShown[unit]` before writing the `[Bar]` transition line. Neither memo is re-armed by the console's `Clear()` or by turning logging on, so after a Clear the current state is never restated over the empty console. `core/DebugLogSetup.lua:123-185` passes no `onClear`. The same files already use the library's gates elsewhere (`DebugOnce` at `core/AbsorbTracker.lua:139`, `DebugChanged` at `settings/UnitPanel.lua:365`). Both memos are dense guards, not tangled logic; `dbgLastShown` is also read by the diagnostics seam (`NS.LastAppliedVisibility`). | Route both lines through `NS.DebugLog.DebugChanged(key, tag, fmt, …)` (keys `absorb:secret` and `bar:<unit>`), keeping `dbgLastShown` as diagnostics data only; or keep the memos and pass `onClear = function() dbgAbsorbSecret = nil; wipe(dbgLastShownLog) end` in the descriptor. |

## Dependents

None this run.

## Recorded deviations: accepted, not re-filed

| Rule | Register row | Decided | Status this run |
|---|---|---|---|
| `events-frames-taint-§8` (SHOULD half) | 17 pre-formatted chat lines in `settings/Slash.lua` (`docs/ARCHITECTURE.md:376`) | 2026-08-05 | **Accepted.** Rule text unchanged since the row's re-grade. Trigger not fired: the named-API grep over `settings/Slash.lua` and `settings/Schema.lua` returns nothing. Count re-measures at **17**, as stated. Evidence id `AT-35` resolves in `docs/audits/2026-08-05/02_DEVIATIONS.md`. |
| `localization-§1` | English only (`docs/ARCHITECTURE.md:377`) | 2026-08-05 | **Accepted** — localization-§3's terminal state 2. Trigger not fired: `locales/` holds `enUS.lua` alone. `AT-30` resolves; issue #24 exists (closed, `state:done`). |

The third row, `savedvariables-§1` (2026-07-28), is **filed for retirement** as `AT-86`: its cited rule
changed at v2.65.0. Its trigger has not fired and its argument link (`profiles.md`) resolves.

**The inverse rule was run and files nothing.** The `state:will-not-do` issues are #16, #21, #22, #23,
#26, #27, #28 and #31. Each declines a feature, a bundle edit, an investigation, a render-loop rewrite or
adoption of an optional LibKa0s major; none declines a rule of the standard, so none owes a register row.
No `docs/pending/LEDGER.md`, no `[status]` title prefix.

## Checked and compliant (no entry filed)

- **Vendored payload:** both `diff -r` against `v1.70.0` empty (159 / 22 files); provenance only in
  `CLAUDE.md:43`; README badge bare; runner `100755`; TOC lists `LibKa0s.xml` once.
- **Line endings:** canonical 84-line body, no appendix, (e) = 0; `test_eol` wired.
- **Packaging:** every root dot-entry accounted for except `.git`; no false conditional line.
- **Layout:** census present and agrees with the tree; gate wired; nothing over the cap; no generator.
- **TOC:** field order, own-logo `IconTexture` (type 2, 128×128, 32 bpp), real Curse id, Core block
  fully annotated.
- **Disabled state (`slash-commands-§7`, `-§2`):** one latch, two holds; every registration undone;
  both timers cancelled; hidden at the source; the combat-entry write unreachable while disabled; every
  reserved verb live; feature verbs refused on the library's line; conformance suite asserts on the
  registration set and dispatches both diagnostics forms.
- **Launcher:** one object, brand label, left-click settings, right-click menu with Enabled · Locked
  routed to the verbs' handlers, library tooltip, minimap row at `global.minimap.shown` exempt from both
  resets.
- **Diagnostics (`debug-logging-§14`):** one row, tested first, no alias, live while disabled, library
  enable (no host `SetEnabled`), stub's library-absent line, README section verbatim.
- **Library debug lines (`debug-logging-§4`):** `debug` passed to Slash, Options, Launcher and
  Lifecycle; `debugAtEnable` passed; no duplicate edge or refusal line.
- **Events:** SafeRegister helpers everywhere, rejected list readable via `/at debug events`; per-unit
  frames meet the unit-filter carve-out.
- **Options (a)–(i):** strips on General and Appearance; `Master controls` first and composed; no Test
  mode (lock-is-preview); color companions from the composers; no `disabledIf` on color; no arrows; no
  hand-written groups; one unboxed chrome block; wrap pin left to the library; no second combat lock; no
  host `OpenToCategory`; `addonName` on the descriptor.
- **Stubs:** Core, DebugLog (gates included), Perf, Lifecycle, Launcher, Slash, Bus, Schema each covered
  by a parity case; Options is load-completing with hollow composers and `writeThrough` for host verbs.
- **Bus:** constants only, PascalCase.
- **Lint:** scope narrowed to `tests/_kit/`, harness global in `files["tests/"]`, no top-level ignore.
- **Complexity:** kit 37, `test_lizard_sighted` wired, sighted run 0 warnings / max 14 / 0 blind files;
  no gate line in `CLAUDE.md`, `docs/testing.md` or `DEPENDENCIES.md` quotes raw `lizard` (only the
  `docs/automated-tests/README.md` table does, `AT-83`); watch list has no #53 entry.
- **Documentation map:** 22 files, 21 rows plus the unregistered hub (a MAY), four tables, the fourth
  exact; Tier 2 statuses match the code; no non-canonical or retired filename; hub 406 lines with every
  mandated section under ~60 (not filed).
- **README:** structure, badges, no logo, no numbered list, no library inventory, Credits external only.
- **Citations:** no `§N.M`, no malformed `filename-N`, no out-of-range `filename-§N` in the live tree.

## Info

| ID | Note |
|---|---|
| **AT-Info-1** | **The newest automated-test bundle is unsighted and 57 commits behind.** `20260927-030336` (release 1.11.0) measured `9b5a369` before kit revision 35 existed; its `manifest.json` has no `suites.complexity.blindFiles`. Today's sighted run counts 2219 functions against the bundle's 1919 (growth plus functions the blind reader dropped) and still finds none above CCN 15. The checkpoint is release, so this is not filed; the next release run is the first sighted record. `tests/test_slashcmds.lua` left the band's upper half (1321 → 1079); no file newly entered the band. |
| **AT-Info-2** | **`docs/automated-tests/RESULTS.md:15` names `/wow-addon:bump-version`** (the pre-v2.76.0 plugin name). The file is regenerated whole by the runner, and kit 37's runner emits no `wow-addon` string, so the next run fixes it; not hand-edited here. |
| **AT-Info-3** | **Issue #26 is stale.** It is `state:will-not-do` "LibKa0s-Widgets-1.0: declined — no control in this addon wants it", but `modules/Bar.lua` now builds each bar's drag handle from that major. Housekeeping on the issue, not a standards deviation; it travels with `AT-88`. |
| **AT-Info-4** | **`docs/test-cases.md`'s `## Totals` reads 877 while the README badge reads 876/876.** testing-§5 keeps a skip out of both figures, which the badge does; the generated Totals row counts the one skipped case. The renderer is the vendored kit's (`--list`), so this is a LibKa0s kit item, not an addon edit. |
| **AT-Info-5** | **Standard-side (documentation lane):** toc-file-§5's worked example cites `AbsorbTracker.toc:35-42`; the quoted block now sits at `:37-43`. |
| **AT-Info-6** | **Standard-side (documentation lane):** `AUDIT.md` step 4's TOC check says "In the `# Core` block", while toc-file-§5 applies the load-bearing MUST to every position in the listing. This run followed the standard (`AT-84`, `AT-85`); the playbook wording is why the 2026-09-23 run did not see them. |
| **AT-Info-7** | **Unreachable fallback arms.** `settings/Slash.lua`'s `runDiagnostics` and `runDebug` print "Debug console unavailable" when `NS.DebugLog` lacks a member, but `core/DebugLogSetup.lua` always publishes one (live or stub). Harmless dead code; not filed. |
| **AT-Info-8** | **Open feature backlog.** Eight `state:triaged` enhancement issues (#2–#6, #8, #9, #15); none is a standards item. |
