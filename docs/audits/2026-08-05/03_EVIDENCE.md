# 03 — Evidence

Every claim in `01_CURRENT_STATE.md` and `02_DEVIATIONS.md` is sourced here as `file:line` or as a
command and its real output. Nothing below is inferred from reading code that "looks right".

Run environment: WSL2 / Ubuntu, `/mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker`, HEAD
`e31b79d`, 2026-08-05. Working tree clean apart from the untracked `docs/reviews/2026-08-05/`.

---

## A. Mechanical checks — run, not reasoned about

### A1. Lint — `luacheck .`

```
$ luacheck .
Checking core/AbsorbTracker.lua                   OK
… (28 files)
Checking settings/UnitPanel.lua                   OK

Total: 0 warnings / 0 errors in 28 files
```

**Pass.** Matches `docs/automated-tests/20260804-233138/lint.txt` and the `RESULTS.md` row
(`0/0`, 28 files, `docs/automated-tests/RESULTS.md:15`).

Scope note, already recorded by the addon at `docs/automated-tests/RESULTS.md:42-46`: those 28 files
are the addon's own runtime source only — `.luacheckrc:6` excludes `libs/`, `docs/`, `_dev/` and
`tests/`, so this `0/0` says nothing about `tests/`. That blanket `tests/` entry is `lint`'s own
template; the `docs/` entry is the superset behind **AT-39**.

### A2. Headless harness — `lua5.1 tests/run.lua`

```
$ lua5.1 tests/run.lua
…
  PASS  libs/LibKa0s is the LibKa0s release the README says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release

470 passed, 0 failed, 470 total
```

**Pass**, exit 0. Agrees with `docs/test-cases.md`, with the README badge (`README.md:7`,
`Tests-470%2F470_passing-green`) and with the committed row
(`docs/automated-tests/RESULTS.md:15`, `470/470`). This is the evidence closing **AT-32**.

### A3. Complexity — the standard's verbatim invocation

Run from the repo root, exactly as `automated-tests-§1` / `performance-§10` specify — no extra flag,
no narrowed path, no re-tuned threshold:

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
================================================
  NLOC    CCN   token  PARAM  length  location
------------------------------------------------
       3      3     23      0       3 NS.NoteRepaint@33-35@./core/AbsorbTracker.lua
…
===============================================================================================
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
==========================================================================================
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
------------------------------------------------------------------------------------------
      7574       6.4     1.7       45.4     1063            0      0.00    0.00
```

**Pass** — 0 functions above CCN 15.

**Drift against the latest bundle** (`docs/automated-tests/20260804-233138/complexity.txt`,
stamped 2026-08-04 23:31:38 local):

| Figure | Committed run | Today | Drift |
|---|---|---|---|
| Total NLOC | 7574 | 7574 | none |
| Function count | 1063 | 1063 | none |
| Avg NLOC | 6.4 | 6.4 | none |
| Avg CCN | 1.7 | 1.7 | none |
| Warning count | 0 | 0 | none |

**No function crossed a `lizard` threshold and no file entered `layout-§1`'s 1000–1500 band since
that run.** The top of the list, for the record, is unchanged from what
`docs/automated-tests/RESULTS.md:78-85` describes:

```
      47     15    341      1      67 Helpers.BuildMainContent@38-104@./settings/About.lua
      36     14    244      0      38 NS.ValidateSchema@224-261@./settings/Schema.lua
      18     14    152      0      22 addon@164-185@./core/AbsorbTracker.lua
      31     12    247      1      51 build@16-66@./settings/Profiles.lua
```

`Helpers.BuildMainContent` is *at* 15, not over. Its 15 decisions are dense **defaulting and
guarding** over the About page's content rows — `and`/`or` short-circuits, which `lizard` counts as
decisions (`performance-§10`) — not tangled control flow, so the risk it carries is low and the
watch list's "watch if the About page grows another block" is the right disposition.

**Staleness of the record.** `docs/automated-tests/20260804-233138/manifest.json` stamps
`"sha": "ab2603e05d9a747acb0a455acc919f39ce515ca0"`, `"branch": "feat/fix-ccn"`, `"dirty": true`;
HEAD is `e31b79d`, two commits later (`2a50784` re-vendor, `e31b79d` docs). Neither touched runtime
source, so the record is stale in **stamp** only. Per `automated-tests-§6` the checkpoint is
**release**, not commit — so this is a note about the release process, not a finding that the addon
failed to gate a commit on complexity.

**LOC band check**, independent of `lizard`:

```
$ wc -l core/*.lua defaults/*.lua modules/*.lua settings/*.lua locales/*.lua tests/*.lua | sort -n | tail -3
    893 tests/test_helpers.lua
   1256 tests/test_slashcmds.lua
  10980 total
```

One file in the 1000–1500 band, exactly as `docs/automated-tests/RESULTS.md:97` records. Largest
runtime file: `settings/Slash.lua`, 496 lines.

### A4. Vendored Ka0s-owned library drift — **NOT RUN**

`library-stack-§7` names `LibKa0s` as the collection's Ka0s-owned vendored library, so the two
required diffs are:

```
diff -r ../LibKa0s/LibKa0s libs/LibKa0s     # ship payload — MUST be empty
diff -r ../LibKa0s/testkit tests/_kit       # vendored harness — MUST be empty
```

**Neither was executed.** This run is scoped by explicit instruction to
`/mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker` alone, with the `WowAddonStandards` repo as
the only permitted external read; reading `../LibKa0s` is outside that scope. The sibling checkout
**is** present at `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s` (existence tested, contents not
read), so the check is **unverified**, not unavailable. It is reported as unverified and **not** as a
pass. It should be run in the next unrestricted audit or before the next release.

Partial substitute, and its limits: the addon's own suite carries two cases that compare the vendored
copy against the library repo's **tag**, file set first and then bytes —
`tests/test_vendor_sync.lua:118-137` (`assertVendorSync`) driven from `:139-147`. Both passed in A2.
That is a **stronger** check than `diff -r` for "did we vendor a released version" (it pins the tag
named by `README.md:143`, `v1.7.0`) and a **weaker** one for "has upstream moved since": a LibKa0s
commit landing after `v1.7.0` and never re-vendored here is invisible to it, which is precisely the
silent shape of anti-pattern #45. See **AT-50**.

Correct placement, verified: the harness is under `tests/_kit/`, never `libs/` — `tests/_kit/`
contains `README.md`, `framework.lua`, `loader.lua`, `mock_base.lua`, `run-automated-tests.sh`.

### A5. Perf scenarios — `lua5.1 tests/perf.lua`

Not re-run in this audit; the review that ran on the same tree hours earlier records
6 scenarios, 0 assertion failures, 1000 events → 1 repaint, matching
`docs/automated-tests/20260804-233138/perf.txt` and the `RESULTS.md` `perf | pass` column
(`docs/automated-tests/RESULTS.md:15`). The scenario **inventory** is what this audit uses it for,
and that is cited from the committed artifact rather than re-measured.

---

## B. Shared-subsystem wiring — descriptors and stubs, not implementations

The compliance claim for each subsystem is the **addon's** setup file. The library's own source is
not cited as if it were the addon's implementation, and is not re-audited here.

| Subsystem | Lookup | Descriptor | Library-absent branch |
|---|---|---|---|
| Core printer / secret guard | `core/CoreSetup.lua:25` `LibStub("LibKa0s-Core-1.0", true)` | `:69-71` (`prefix` passed as a **function**, with the reason at `:65-68`) | `:27-59` — `IsConcatSafe`, `SafeToString`, `Print`, `Util.print`; announce-once at `:46-55` |
| Perf | `core/PerfSetup.lua:14` `LibStub("LibKa0s-Perf-1.0", true)` | `:33-48` (`name`, `title`, `slash`, `version`, `sv`, `buckets`) | `:15-30` — `on`, `suspended`, `Note`, `OnCommand` |
| DebugLog | `core/DebugLogSetup.lua:16` | descriptor below the stub | `:16-60` — `buffer`, `Add`, `Debug`, `Clear`, `Show`, `Hide`, `Toggle`, `IsShown`, `IsEnabled`, `SetEnabled` |
| Options | `settings/OptionsSetup.lua` `LibStub("LibKa0s-Options-1.0", true)` | page/registration descriptor | **load-completing**, deliberately — see B2 |
| Slash | `settings/Slash.lua` | descriptor built in-file because `NS.COMMANDS` stays host-owned (`CLAUDE.md:76-79`) | degradation branch prints the shared cause clause |

### B1. Stub coverage — every member the addon reaches is answered

`NS.Perf` call sites across `core/`, `modules/`, `settings/`:

```
$ grep -rhno "NS\.Perf\.[A-Za-z]*\|Perf\.[A-Za-z]*" core modules settings | sed 's/.*://' | sort -u
NS.Perf.OnCommand
NS.Perf.suspended
Perf.Note
Perf.on
Perf.suspended
```

Four distinct members: `on`, `suspended`, `Note`, `OnCommand`. The stub at `core/PerfSetup.lua:23-29`
answers all four, and the comment at `:16-21` states why `OnCommand` in particular has to be there
("`/at perf` is registered unconditionally"). **No gap.**

`core/DebugLogSetup.lua:33-60` answers ten members, and `:30-32` records a **deliberate** omission
with its reason — the formatters, which nothing in the addon calls and whose "seven-way drift this
extraction exists to end" would be re-created by hand-copying them. Per the playbook that is a
decision, not a gap.

The shared cause clause is set **outside** the branch, at `core/CoreSetup.lua:22-23`, with the
reason at `:16-21`: five seams append their own "so `<what>` is unavailable", so a degraded install
says the same thing about *why* five times and a different thing about *what* each time.

### B2. The Options stub is load-completing on purpose — not a finding

`CLAUDE.md:83-88` records it: `settings/Bar.lua`, `Border.lua` and `Font.lua` call
`NS.Helpers.LSMValues` inside schema-row literals at **file load**, so a nil aborts the file,
`NS.RegisterSchemaRows` never runs, and a third of `NS.Schema` disappears silently.
`loadDegraded()` in `tests/test_perf.lua` loads the whole TOC without the library and asserts
`#NS.Schema` still matches. This is the standard's one documented exception; flagging it would be a
false positive and it is not flagged.

### B3. No hand-rolled subsystem exists — anti-pattern #47 does not apply

There is no `modules/DebugLog.lua`, no widget-maker or flow-engine file, no addon-local slash
dispatcher/parser, and no hand-written test framework. `tests/_kit/framework.lua` is the vendored
kit. `libs/LibKa0s/` is unpatched (A4's tag comparison passed). The absence of these files **is** the
evidence of compliance.

### B4. Vendoring is whole — anti-pattern #48 does not apply

```
libs/LibKa0s/  Core.lua  DebugLog.lua  LibKa0s.xml  LICENSE  Options.lua
               OptionsScroll.lua  OptionsWidgets.lua  Perf.lua  PerfPanel.lua  Slash.lua
```

Five majors across eight module files (`CLAUDE.md:74-75`), every shell paired with its attach file
(`Options` + `OptionsWidgets` + `OptionsScroll`; `Perf` + `PerfPanel`), `Core.lua` present.
`AbsorbTracker.toc:29` lists `libs\LibKa0s\LibKa0s.xml` **once**, in `# Libraries`, after the Ace3
entries. No individual `LibKa0s` `.lua` appears in the TOC.

---

## C. Evidence per deviation

### AT-33 — What's new vs Version History (`documentation-§1` item 5, #40) — MUST

- `README.md:15-24` — `## What's new in 1.9.0`, eight bullets, opening with target/focus bars,
  per-bar enable toggles, mirror/copy styling and the breaking slash paths.
- `README.md:159` — the top `## Version History` row for 1.9.0: four items (show-only-in-combat,
  event-driven repaint, debug window, Debug console toggle). None of the first four bullets appears.
- `README.md:26-28` — the breaking-change subsection exists and is linked from What's new, which
  makes its absence from the Version History row the more visible.

### AT-34 — Profiles page built eagerly (`options-ui-§5`, #42) — MUST

- `settings/Profiles.lua:15` — `local function build(mainCategory)`; the library runs this at
  category-registration time.
- `settings/Profiles.lua:51-56` — `AceGUI:Create("SimpleGroup")`, `SetLayout`, `SetParent(ctx.body)`
  and both `SetPoint` calls, all inside `build`.
- `settings/Profiles.lua:60-62` — the `OnShow` handler exists and does only `AceConfigDialog:Open`,
  so the lazy seam is already there and unused for the widget itself.
- Contrast: every other page defers its body; `tests/test_widgets.lua` asserts "a page renders
  nothing until its first OnShow" and structurally cannot reach this one.

### AT-35 — pre-formatted chat lines (`events-frames-taint-§8`, #35) — MUST

- `core/CoreSetup.lua:77` — `NS.Print = printer.Print` is published; **no** `NS.Format` beside it.
  ```
  $ grep -rn "NS.Format\|printer.Format" core settings modules
  settings/Schema.lua:149:        NS.Debug("Set", "%s = %s", …)
  settings/Schema.lua:189:function NS.FormatSchemaValue(row, v)
  ```
  Both hits are a different symbol (`FormatSchemaValue`); the library's `Format` seam is unbound.
- Call sites building the line first — **18** in total, 17 in `settings/Slash.lua` plus one in
  `settings/Schema.lua`:
  ```
  $ grep -cE 'print\(.*(\.\.|:format)' settings/Slash.lua settings/Schema.lua
  settings/Slash.lua:17
  settings/Schema.lua:1
  ```
  `settings/Slash.lua:33` (`PrintCmd`), `:97` (`version`), `:242,246` (`runToggle`), `:282`
  (`runTest`), `:321,334,339,344,352,357,365,389` (the `PROFILE_VERBS` block and its guard),
  `:414,427,428,439` (the degradation stub); `settings/Schema.lua:214`.
- Nothing here is fed a combat-protected value today — profile names, unit labels, user-typed
  numbers — which is why this is graded latent. `events-frames-taint-§8` forbids the shape regardless
  ("even if it is never handed a secret today").

### AT-42 — `CLAUDE.md` miscounts the required topic-detail docs — MUST

- `CLAUDE.md:40-41`:
  > "Four of those topic-detail docs are **required**, not optional: `test-cases.md`,
  > `performance.md`, `perf-runs/README.md`, `automated-tests/README.md` and
  > `automated-tests/RESULTS.md` (documentation-§3)."

  A count of **four** followed by a list of **five**.
- `documentation-§3`: "**Five** topic-detail docs are **required**, not optional — `test-cases.md`,
  `performance.md`, `perf-runs/README.md`, `automated-tests/README.md` and
  `automated-tests/RESULTS.md`."
- All five are present in the repo, so the shipped doc set is correct and only the sentence
  describing it is wrong: `docs/test-cases.md`, `docs/performance.md`, `docs/perf-runs/README.md`,
  `docs/automated-tests/README.md`, `docs/automated-tests/RESULTS.md`.
- The `docs/` canonical trio is likewise complete: `docs/ARCHITECTURE.md`, `docs/testing.md`,
  `docs/smoke-tests.md`. The root set is exactly three plus `LICENSE`: `README.md`, `CLAUDE.md`,
  `DEPENDENCIES.md`.

### AT-43 — the vendored runner is not executable in the index (`automated-tests-§2`) — MUST

```
$ git ls-files -s tests/_kit/run-automated-tests.sh
100644 30da7c0713a07740c7d91828f07fe0adb04205d4 0	tests/_kit/run-automated-tests.sh

$ ls -l tests/_kit/run-automated-tests.sh
-rwxrwxrwx 1 tushar tushar 23340 Aug  5 00:07 tests/_kit/run-automated-tests.sh
```

The `0777` on disk is the drvfs mount reporting, not a stored bit; the git index is authoritative and
records `100644`. `automated-tests-§2` ends its vendoring MUST with "`cp` also does not reliably
carry the executable bit, so re-vendoring ends with `chmod +x
tests/_kit/run-automated-tests.sh`" — this is that failure. Every documented invocation assumes
execute:

- `docs/testing.md:37-39` — three bare `tests/_kit/run-automated-tests.sh …` lines.
- `docs/automated-tests/README.md:10-12` — the same three.

The related `.gitattributes` requirement **is** met, with the reason written down:

```
$ tail -6 .gitattributes
# Shell scripts are LF, ALWAYS — even here, where everything else is CRLF.
# `#!/usr/bin/env bash` followed by CRLF makes the kernel look for an interpreter
# literally named "bash\r", and every `case`/`in` line becomes a syntax error.
# The vendored tests/_kit/run-automated-tests.sh is the file this protects
# (automated-tests-§2); without it the runner is broken on every checkout.
*.sh   text eol=lf
```

### AT-44 — the warned-functions watch list is prose, not a table (`automated-tests-§4`) — MUST

- `docs/automated-tests/RESULTS.md:64-66` — `### Functions lizard warned on` followed by "**None.**"
  and prose; no header row, no `| Function | CCN | Location | Disposition |`.
- `docs/automated-tests/RESULTS.md:93-97` — the sibling half **is** a table with the Band column, as
  required, so the two halves are inconsistent with each other as well as with the rule.
- `automated-tests-§4`: "**MUST** carry the current complexity **watch list** below the table, as
  **two tables with header rows**: warned functions (Function / CCN / Location / Disposition), and
  files by `layout-§1` band (**Band** / File / LOC / Disposition)."
- The prose is substantively good — `:19-28` documents the pre-rev-6 kit parser fault that made one
  row's Max CCN read `0`, and `:69-76` records what was peeled and why. Nothing there should be lost;
  the deviation is the missing shape.

### AT-45 — the release gate is undocumented, and its inverse is stated three times — MUST

The standard (`automated-tests-§3`, *The release gate*, v2.21.0): a release **MUST NOT** be cut
unless the release run's `manifest.json` shows **all four** suites at `pass` and
`suites.complexity.warnings` at **0**; a `skip` is a gate that did not pass; the gate is evaluated by
the release command from the manifest, and the runner's exit code is deliberately unchanged.
`automated-tests-§6`: "The two checkpoints are deliberately different: commits are gated on the two
deterministic suites, the tag is gated on all four plus zero CCN > 15."

What the repo says:

- `docs/testing.md:22` — "It is a **report**, not a verdict, and it is **recorded, never gating**".
- `docs/testing.md:46-47` — the `Gates?` column reads `no — recorded only` for both `perf` and
  `complexity`, unqualified.
- `docs/testing.md:49-52` — "**`perf` and `complexity` never fail a run.**" (true of a run; the
  sentence is not scoped in the surrounding prose).
- `docs/testing.md:57-58` — "**At release, not at commit.** A full bundle is produced as part of
  every version bump, before the tag, with an `ANALYSIS.md` write-up. Commits are gated on lint +
  tests only." This is the closest the repo comes, and it stops one sentence short: it says a bundle
  is *produced* at release, never that the release is *blocked* by it.
- `docs/automated-tests/README.md:25-30` — the same `Gates?` table and the same "never used to fail a
  run" paragraph.
- `docs/automated-tests/RESULTS.md:9-11` — "**`lint` and `tests` gate. `perf` and `complexity` are
  recorded and never fail a run**". This file is **generated**, so its lead-in is the kit's text and
  the fix for this line belongs upstream in LibKa0s, not in a local edit
  (`documentation-§3`: RESULTS.md "is **generated**, never hand-edited").
- `CLAUDE.md:28-29` gets closest of all — "the release-time complexity checkpoint" — but names a
  checkpoint without stating that it blocks.

Nothing in the repo mentions `suites.complexity.warnings == 0`, `manifest.json` as the gate's input,
or a `skip` blocking as NOT EVALUATED. Grep confirms:

```
$ grep -rn "release gate\|warnings == 0\|NOT EVALUATED" docs CLAUDE.md README.md
(no matches)
```

Materially, the addon would pass the gate today (`20260804-233138/manifest.json`: all four suites
`pass`, `"warnings": 0`) — so this is a **documentation** deviation about a gate the code already
satisfies, not a blocked release.

### AT-47 — two false `within` declarations (`performance-§3`) — MUST

- `core/PerfSetup.lua:42-48`:
  ```lua
  buckets = {
      { key = "absorbEvent" },
      { key = "repaintPass" },
      { key = "paintBar",    within = "repaintPass" },
      { key = "appearance",  within = "repaintPass" },
      { key = "visibility",  within = "repaintPass" },
  },
  ```
- `modules/Timer.lua:22-41` — `doRepaint`'s bracket. Between `local t0 = Perf.on and
  debugprofilestop()` (`:22`) and `Perf.Note("repaintPass", …)` (`:41`), the only call is
  `NS.ForEachUnit(function(unit) … NS.UpdateAbsorbBar(unit) … end)` (`:33-35`). Neither
  `NS.UpdateBarAppearance` nor `NS.ApplyVisibility` is reached from inside the pass; both are driven
  by the APPEARANCE and VISIBILITY bus messages.
- The committed in-game capture carries the arithmetic proof:
  `docs/perf-runs/2026-07-30-ingame-post-extraction.json` —
  `"visibility":{"calls":15,…,"within":"repaintPass"}` against `repaintPass`'s 24 calls, while the
  genuinely nested `paintBar` records 48 = 2 × 24. A child cannot be called fewer times than its
  parent and remain a child.
- The addon's own doc already has it right and disagrees with the descriptor:
  `docs/performance.md:239` — "(buckets nest: repaintPass contains paintBar — do not sum)".
- The comment above the descriptor is the third witness: `core/PerfSetup.lua:40-41` claims
  "repaintPass contains the three per-bar buckets".

### AT-48 — `delta is the headline` contradicts `performance-§7` — SHOULD

- `docs/performance.md:242` — "**`delta` is the headline.** It is the per-frame cost of having the
  addon active, measured with everything else held constant."
- `performance-§7` — "**MUST** read the **bucket figures** as the addon's cost, and treat the
  frame-time delta as **unresolved** below the harness's measured run-to-run spread. A per-frame
  delta is a difference of two noisy aggregates; the buckets measure the addon's own code directly."
- The page's own caveat, four paragraphs later at `docs/performance.md:258-261`: "**The delta has a
  resolution floor of roughly ±0.3 ms/frame** on a 60–80 s arm … measured across four captures, one
  of which came back negative."
- Mitigating, and why this is SHOULD not MUST: the worked example at `:245-249` reaches the correct
  conclusion (buckets ≈ 0.026 ms/frame against a 2.74 ms/frame delta ⇒ "the cost is not in our Lua"),
  so the page's *analysis* follows the rule even where its *emphasis* does not.

### AT-49 — the account-wide schema stamp defaults to current (`savedvariables-§1`) — SHOULD

- `defaults/Profile.lua:76-79`:
  ```lua
  NS.defaults.global = {
      -- Persisted-DB schema version. NS:RunMigrations (core/Database.lua) reads/writes this once …
      schemaVersion = 4,
  }
  ```
- `defaults/Profile.lua:50-56` — the **per-profile** stamp, and the reason it is the opposite:
  > "The default is 1 ('legacy — not yet lifted'), NOT the current 3, and that is load-bearing.
  > AceDB-3.0's copyDefaults fills every ABSENT key the first time a profile section is instantiated,
  > which happens BEFORE NS:RunMigrations ever reads it. A default of 3 would stamp every pre-v3
  > profile as already-migrated on first touch and make the gate permanently dead."
- `core/Database.lua:190` — `g.schemaVersion = g.schemaVersion or 1`, the `savedvariables-§1`
  idiom, which the `= 4` default makes unreachable: copyDefaults has already written `4`.
- `core/Database.lua:208-213` — the ladder gate `if g.schemaVersion < step.to then`, over
  `SCHEMA_STEPS` at `:166-186`.
- Impact today is nil — a real upgrade path has a `global` section carrying its true stamp. The
  exposure is any path that materializes `global` fresh against pre-v4 profile data.

### AT-30 / AT-31 / AT-36 / AT-37 / AT-38 — recurring, re-verified

- **AT-30**: `locales/enUS.lua` ships the key-returning metatable and no keys;
  `grep -rn 'NS\.L\[' core settings modules` returns no user-facing call site. Deferred in
  `docs/pending/LEDGER.md` (PLAN-02).
- **AT-31**: `core/AbsorbTracker.lua:63` and `docs/ARCHITECTURE.md:316-331` — accepted, documented,
  unchanged.
- **AT-36**: 31 retired `§N.M` references remain.
  ```
  $ grep -rnE '§[0-9]+\.[0-9]+' core settings modules defaults locales tests docs/ARCHITECTURE.md docs/testing.md docs/performance.md | wc -l
  31
  ```
  Sample: `core/Constants.lua:11,15`, `core/LSMPatch.lua:3`, `core/State.lua:4`,
  `core/Namespace.lua:4,9`, `core/AbsorbTracker.lua:9,38,63,163`, `core/Database.lua:33`,
  `settings/Slash.lua:5,196`, `settings/OptionsSetup.lua:73,81`, `settings/Schema.lua:200,248`,
  `modules/Timer.lua:3`, `defaults/Profile.lua:5,8`. Malformed reference:
  ```
  $ grep -rn 'slash-commands-§:' settings
  settings/Slash.lua:199:-- registers no slash command of its own (slash-commands-§: every verb goes through this table with
  ```
- **AT-37**: `docs/ARCHITECTURE.md:277-282` (Wago), `:284-294` (`AbsorbTrackerPerfDB`, "**Pending
  promotion**"), `:296-304` (`lizard`, "**Pending promotion**"), `:306-314` (bracket idiom,
  "**Pending promotion**"). All four are sanctioned outright by v2.21.0 — `toc-file-§1` (Wago a MAY),
  `savedvariables-§4` + `toc-file-§2`, `performance-§10`, `performance-§2`.
- **AT-38**: `modules/Display.lua:87-98` — unlocking shows only the unit label
  (`if locked then unitLabel:Hide() else unitLabel:Show() end`), no placeholder fill.
  `modules/Display.lua:185-186` — `if (NS.testHoldUntil or 0) > GetTime() then`, an expiry, with no
  off verb. `settings/Slash.lua:282-291` — `/at test` states a duration and sets the hold.

### AT-39 / AT-40 / AT-41 / AT-46 / AT-50 — advisory

- **AT-39**: `.luacheckrc:6` — `exclude_files = { "libs/", "docs/", "_dev/", "tests/" }` against the
  `lint` template's `{ "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }`.
- **AT-40**: `modules/Bar.lua:5-6` — "as player aliases for the call sites that predate multi-unit
  (core/DebugLog.lua, settings/Slash.lua, the tests)". `core/DebugLog.lua` does not exist; the
  console is `core/DebugLogSetup.lua` + the library.
- **AT-41**: `README.md:141-147`, `## Credits and libraries`, between `## Troubleshooting`
  (`:127`) and `## Issues and feature requests` (`:149`). All twelve required sections present in the
  required relative order (`README.md:1`, badges `:3-7`, logo `:9`, description `:11-13`, `:15`, `:30`, `:44`, `:96`, `:110`, `:127`, `:149`, `:155`).
- **AT-46**: `.pkgmeta` `ignore:` lists `docs`, `tests`, `_dev`, `.luacheckrc`, `.gitattributes`,
  `.gitignore`, `"*.bak"`. Not listed: `.superpowers/` (≈60 committed files under
  `.superpowers/sdd/`) and `.claude/`.
- **AT-50**: `tests/test_vendor_sync.lua:106-112` — `siblingTag()` returns `nil` when
  `gitShow("HEAD:LibKa0s/Core.lua")` is nil; `:139-141` and `:145-147` — both cases `if not tag then
  return end`, i.e. PASS. The header at `:107-109` claims the quiet case "is said in the case name
  rather than hidden"; the two names are "libs/LibKa0s is the LibKa0s release the README says this
  addon bundles" and "tests/_kit is the test kit that shipped with that release" — neither says it.
  `DEPENDENCIES.md:149` ("A sibling `../LibKa0s` checkout — optional, and its absence is sanctioned")
  documents the design, which is why this is advisory and not a MUST.

---

## D. Compliance claims, sourced

| Claim | Evidence |
|---|---|
| Modular layout, nothing loose at root | tree listing; `core/`, `defaults/`, `settings/`, `locales/`, `modules/` all populated |
| Media in typed subfolders | `media/fonts/JetBrainsMono-Regular.ttf`, `media/logos/absorbracker.logo.v2.{jpg,tga}`, `media/screenshots/*.png` |
| Runtime `.tga` beside editable `.jpg` | `media/logos/` holds both |
| TOC field order, single Interface, MIT, X-Standard, Curse ID | `AbsorbTracker.toc:1-15` |
| Exactly two SavedVariables globals, correct order | `AbsorbTracker.toc:7` |
| LibKa0s aggregate listed once, after Ace3 | `AbsorbTracker.toc:29` |
| TOC section comments in load order | `AbsorbTracker.toc:17,35,38,52,55,60` |
| Three-place standards reference | `AbsorbTracker.toc:14`; `README.md:6`; `CLAUDE.md:6-22` |
| `CLAUDE.md` is a stub with the stop-and-flag directive verbatim in substance | `CLAUDE.md:13-22` |
| No `docs/agent-context.md`, and the ban recorded | absent from tree; `CLAUDE.md:48-57` |
| Root doc set is exactly three plus LICENSE | `README.md`, `CLAUDE.md`, `DEPENDENCIES.md`, `LICENSE` |
| `docs/` canonical trio | `docs/ARCHITECTURE.md`, `docs/testing.md`, `docs/smoke-tests.md` |
| Five required topic-detail docs all present | `docs/test-cases.md`, `docs/performance.md`, `docs/perf-runs/README.md`, `docs/automated-tests/README.md`, `docs/automated-tests/RESULTS.md` |
| Retired `docs/complexity.md` absent | `ls docs/complexity.md` → No such file; retirement recorded at `docs/testing.md:65-66` |
| `DEPENDENCIES.md` splits runtime/dev/release with verification commands | `DEPENDENCIES.md:21,35,206,229` |
| `.gitattributes` carries `*.sh text eol=lf` with its reason | `.gitattributes:32-36` |
| Bundle shape: manifest + ANALYSIS + one file per suite | `docs/automated-tests/20260804-233138/` — `manifest.json`, `ANALYSIS.md`, `lint.txt`, `tests.txt`, `test-cases.md`, `perf.txt`, `perf.json`, `complexity.txt` |
| `RESULTS.md` is one file overwritten in place | `git log --oneline -- docs/automated-tests/RESULTS.md` → 9 commits on one path |
| `RESULTS.md` carries prose for all four suites | `:30` Test suite, `:39` Lint, `:48` Perf, `:58` Complexity watch list |
| Gated bracket idiom, with zero-overhead evidence | `modules/Timer.lua:22,41`; `tests/perf.lua` `probeOverheadOff`/`probeOverheadOn` |
| Complexity refactor follows `performance-§11` shapes | `settings/Slash.lua:299` (`PROFILE_HELP`), `:327` (`PROFILE_VERBS`), `:316` (`needsName`); `core/Database.lua:141,152,166` — all module level; `NS:RunMigrations` at `:187` |
| Refactored functions had pre-existing coverage | case count moved 469 → 470 across the peel (`docs/automated-tests/RESULTS.md:15-17`) |
| Bus receivers each own a target | `core/Bus.lua`, `NS.NewBusTarget()` per receiver |
| `NS.Print` reclaimed after `NewAddon` | `core/AbsorbTracker.lua:9`; `core/CoreSetup.lua:73-78`; asserted in `tests/test_slash.lua` |
| `.pkgmeta` has no `externals:` and ignores docs/tests/_dev | `.pkgmeta` |
| `core/Compat.lua` present, no `WOW_PROJECT_ID` branching | `core/Compat.lua`; grep for `WOW_PROJECT_ID` → no matches |
| US spelling enforced mechanically | `tests/test_docs.lua` — "the addon's own files use US spellings" (PASS in A2) |
| No public API exposed | no `_G[addonName] = NS.API`; `public-api` is N/A |
