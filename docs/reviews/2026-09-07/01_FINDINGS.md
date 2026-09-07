# AbsorbTracker — principal review, 2026-09-07

**Verdict: ship-ready — minor issues.** Zero Critical, zero High. Every out-of-game suite is green
today, the vendored payload is byte-identical to its tag, and the generated inventory and the README
badge both agree with a fresh run. What is left is a small set of *truth* defects — a perf
declaration the code does not honor, a regression ceiling that no longer bites, a write path that
skips the logged seam, three comments that no longer describe the code — plus one live upstream
defect in `LibKa0s-OptionsCompose` that this addon already works around on its own rows.

Standards cross-check: **performed**. Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)**, resolved
from the local checkout at `/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards`
(`03a9aa0`, same version string as the published index). The raw GitHub fetch was attempted first
and abandoned after it timed out mid-download; the local checkout is the same repo at the same
version and the index header was compared byte-for-byte before it was used.

---

## Measurement run (Step 0 — everything below was executed today, 2026-09-07)

All commands run from `/mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker`.

| Suite | Command | Result |
|---|---|---|
| luacheck | `luacheck .` | **pass** — `Total: 0 warnings / 0 errors in 27 files` |
| Headless tests | `lua5.1 tests/run.lua` | **pass** — `547 passed, 0 failed, 0 skipped, 547 total` |
| Test-case inventory | `lua5.1 tests/run.lua --list > <scratch>/list.md` | **pass** — 652 lines, `**Total** \| **547**` |
| Offline perf | `lua5.1 tests/perf.lua` | **pass** — 6 scenarios, 0 assertion failures, exit 0 |
| Complexity | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | **pass** — `No thresholds exceeded`; 8903 NLOC, 1253 funcs, avg CCN 1.7, **0 warnings**, max CCN **15** |
| `make test` | — | **skipped** — no `Makefile` at the repo root (`ls Makefile` → no such file). Not a gap; this repo's canonical entry points are the two commands above. |
| Vendor sync (LibKa0s) | `diff -rq --strip-trailing-cr libs/LibKa0s/ ../LibKa0s/LibKa0s/` | **pass** — no differences (CR stripped; this repo is CRLF-pinned, the library repo is LF) |
| Vendor sync (test kit) | `diff -rq --strip-trailing-cr tests/_kit/ ../LibKa0s/testkit/` | **pass** — no differences |

Tooling present: `luacheck 1.2.0` at `/usr/local/bin/luacheck`, `lua5.1` at `/usr/bin/lua5.1`,
`lizard` at `~/.local/bin/lizard`. `luajit` is absent — not used, `lua5.1` was found first.
Nothing was skipped for want of a tool.

**Scope of every count above:** `luacheck .` and `lizard` were run from the repo root over the whole
tree; `lizard`'s only exclusions are the two the standard's invocation specifies (`./libs/*`,
`./tests/_kit/*`), so its 8903 NLOC **includes** `tests/` and **excludes** vendored code and
`docs/`. The 547 test figure is the runner's own total over the 23 suites listed in `tests/run.lua`.

### Fresh run vs. committed artifact

| Artifact | Committed says | Fresh run says | Reading |
|---|---|---|---|
| `docs/test-cases.md` | `**Total** \| **547**` | 547 | **agrees, byte-identical** (`diff` of the fresh `--list` against the committed file returned no output) |
| `README.md` `[Tests]` badge (line 7) | `Tests-547%2F547_passing` | 547/547 | **agrees** |
| `docs/automated-tests/RESULTS.md` (newest row `20260825-103352`) | 508 tests, 7997 NLOC, 1126 funcs, max CCN 14 | 547 tests, 8903 NLOC, 1253 funcs, max CCN 15 | **stale** — see `ABSORBTRACKER-R-06` |
| `tests/perf.lua:231` comment | "312.0 bytes/pass is the measured figure with the brackets off" | `probeOverheadOff` = **48.0 bytes/iter** | **stale, and the ceiling with it** — see `ABSORBTRACKER-R-03` |
| `docs/performance.md:28-31` | "Two nestings exist here: `paintBar` inside `repaintPass` … `Perf.Note(key, ms, parentKey)` reports what the run actually saw" | `paintBar`'s `Note` passes no parent | **contradicted by the code** — see `ABSORBTRACKER-R-01` |

Today's offline perf figures, for citation below:

```
scenario                iters      ms/iter     api/iter   bytes/iter
absorbEvent              1000      0.00022          0.0          0.0
paintPass                1000      0.00957         12.0         48.0
appearancePass            200      0.03366         48.0        384.5
settingsRead            10000      0.00029          0.0          0.0
probeOverheadOff         1000      0.00952         12.0         48.0
probeOverheadOn          1000      0.01016         12.0         48.3
```

**In-client checks are deliberately absent from this block.** They are in `03_SMOKE_TESTS.md`.

---

## A note on this repo's evidence quality

Three things are worth saying before the findings, because they set the baseline the findings are
measured against and a reader should not mistake a short list for a shallow pass:

- **`tests/perf.lua` is a well-built runner.** It derives both load lists from the TOC and the
  vendored XML (`tests/perf.lua:59-61`), asserts nothing on wall clock, and ships the
  zero-overhead scenario `performance-§2` requires (`probeOverheadOff` / `probeOverheadOn`). None of
  the runner defects this review is told to hunt for are present.
- **The vendored-payload gate is honest.** `tests/test_vendor_sync.lua` reads the provenance line out
  of `CLAUDE.md` rather than hardcoding it, and reports a **skip carrying its reason** when the
  sibling checkout is missing rather than an early-return pass. Today it ran (`0 skipped`), so both
  `diff`s above are corroborated from inside the suite as well as from outside it.
- **46 test cases carry a `red under:` comment** naming the mutation that reddens them. Spot-checking
  the negative assertions in `tests/test_perf.lua` (`assertNil(b.appearance.observedWithin, …)` at
  line 82, `assertNil(b.visibility.observedWithin, …)` at line 102) found each of them paired with a
  positive twin that would fail if the mechanism were absent. No unfalsifiable case was found.

---

## Upstream findings (these do NOT land in this repo)

### `ABSORBTRACKER-R-08` — `[upstream]` composed media rows return a closure where a table is wanted

- **Owning repo:** `LibKa0s` (`https://github.com/tusharsaxena/LibKa0s`), file
  `LibKa0s/OptionsCompose.lua`, **OptionsCompose minor 2**, shipped in **v1.25.0** — the tag this
  addon vendors.
- **Problem.** `O.LSMValues(mediaType)` **returns a function** (`libs/LibKa0s/Options.lua:764-776`:
  `function O.LSMValues(mediaType) return function() … end end`). The composers wrap it a second
  time: `libs/LibKa0s/OptionsCompose.lua:231`, `:275` and `:304` all read
  `values = function() return O.LSMValues("font"|"border"|"statusbar") end`. The flow engine's
  `enumList` calls `row.values()` **once** (`libs/LibKa0s/OptionsWidgets.lua:78`:
  `local v = type(row.values) == "function" and row.values() or row.values`), receives a *function*,
  and its very next line `if type(v) ~= "table" then return {} end` yields an empty list.
- **Why it is silent.** The library's own empty-dropdown report is gated on `row.values == nil`
  (`libs/LibKa0s/OptionsWidgets.lua:1442`), and these rows *do* carry a `values`, so a consumer gets
  three dropdowns with nothing in them and no line saying why.
- **Reachability:** *For this addon, nobody.* `settings/Appearance.lua:130-136` (`fixMediaValues`)
  rewrites `row.values = H.LSMValues(kind)` on every composed media row before registration, and
  `tests/test_schema.lua` pins that every media row answers a populated list. For **any sibling
  addon that adopts `BarGroup`/`BorderGroup`/`FontGroup` without that workaround**, it is every
  player who opens the Bar, Border or Text tab.
- **Severity: medium** — high defect kind, floored to medium here because this repo does not reach it.
- **Fix direction: fix upstream, bump `OptionsCompose.lua`'s minor to 3, re-vendor the whole
  `LibKa0s/` folder into this addon and every other consumer as its own commit.** **Not** a local
  edit under `libs/`. Once it lands, `fixMediaValues` and its pinning cases are deleted in the
  re-vendor commit — the source comment at `settings/Appearance.lua:120-129` already says so.
- **It survived a minor bump.** The workaround's own comment says *"OptionsCompose minor 1 declares
  each media-backed row as …"* (`settings/Appearance.lua:120`), but the vendored copy is
  **minor 2** (`libs/LibKa0s/OptionsCompose.lua:29`, `local COMPOSE_MINOR = 2`), released in v1.25.0
  for an unrelated `MasterControls` change. The report reached this addon's source and did not
  reach the library, which is precisely the failure mode routing it upstream is meant to end.
- Verified still open today against the sibling checkout: `grep -n "LSMValues" ../LibKa0s/LibKa0s/OptionsCompose.lua`
  returns the same three lines, so this has not been fixed upstream since the vendor.

---

## Medium

### `ABSORBTRACKER-R-01` — `paintBar` declares a parent the capture never observes `[perf]`

- **Where:** `core/PerfSetup.lua:63` (declaration) vs. `modules/Display.lua:375` (the bracket);
  the claim is at `core/PerfSetup.lua:51` and again at `docs/performance.md:28-31`.
- **Problem.** The descriptor declares `{ key = "paintBar", within = "repaintPass" }`
  (`core/PerfSetup.lua:63`) and the comment three lines above it states, verbatim, *"every nested
  bracket also SUPPLIES its parent to Perf.Note, so the capture reports containment it observed
  rather than one this table merely claims (performance-§3)"* (`core/PerfSetup.lua:51`). The
  `paintBar` bracket passes **two** arguments: `Perf.Note("paintBar", debugprofilestop() - t0)`
  (`modules/Display.lua:375`). Compare the two brackets that do it right —
  `Perf.Note("visibility", debugprofilestop() - t0, openBucket)` (`modules/Display.lua:320`) and
  `Perf.Note("appearance", debugprofilestop() - t0, openBucket)` (`modules/Display.lua:236`).
- **Impact.** `P.Note` only records `observedWithin` when a `parentKey` arrives
  (`libs/LibKa0s/Perf.lua:419-428`), so `paintBar.observedWithin` is permanently nil and the report's
  nesting sentence (`libs/LibKa0s/Perf.lua:262-273`) reports the **one nesting that genuinely
  exists and is genuinely load-bearing** as declared-but-unobserved. It is load-bearing because
  `paintBar`'s total really is inside `repaintPass`'s, so a reader who sums them double-counts.
  Corroborated by the committed capture: `docs/perf-analysis/20260807-125002/dump.json` carries
  `"paintBar": { "calls": 143, "totalMs": 2.4014, "within": "repaintPass" }` with **no**
  `observedWithin` key, beside `"repaintPass": { "calls": 72, "totalMs": 4.2879 }`.
- **Reachability:** anyone who runs `/at perf report` or reads a committed capture — the addon's own
  diagnostic surface, and the only surface either the source comment or `docs/performance.md`
  is speaking to. No effect on the bar the player sees.
- **Coverage gap under this finding.** `tests/test_perf.lua:68-88` covers exactly the nesting that
  works (*"the capture OBSERVES visibility inside appearance, it does not just declare it"*), and
  `tests/test_perf.lua:57` asserts only the **declaration** `P.BUCKET_WITHIN.paintBar ==
  "repaintPass"`. There is no case anywhere in the suite asserting `paintBar.observedWithin`. The
  suite tests the honest nesting and not the dishonest one — that is the more valuable half of this
  finding.
- **Fix direction:** publish the open bucket from `doRepaint` the same way `modules/Display.lua`
  already publishes `appearance`, and pass it as `Perf.Note`'s third argument at
  `modules/Display.lua:375`. `openBucket` is a `modules/Display.lua` local and `doRepaint` lives in
  `modules/Timer.lua`, so the seam has to be shared — see `02_PROPOSED_CHANGES.md`. Do **not** drop
  the declaration instead: `performance-§3` wants both halves, and dropping it trades a wrong claim
  for a disjoint-totals claim, which is worse.

### `ABSORBTRACKER-R-02` — `Units.CopyFromPlayer` writes 20 schema-row paths outside the logged seam `[design]`

- **Where:** `core/Units.lua:111-119`; reached from `settings/UnitPanel.lua:224-228`.
- **Problem.** `Units.CopyFromPlayer(unit)` assigns `dst[key] = deepcopy(src[key])` for all 19
  `APPEARANCE_KEYS` and then `dst.mirror = false`, directly into the profile table. Every one of
  those 20 paths **is a registered schema row** — the 19 come from `settings/Appearance.lua`'s
  composed blocks, and `units.<unit>.mirror` is declared at `settings/Appearance.lua:284-296`. The
  addon's single write seam is `NS.SetByPath` (`settings/Schema.lua:169-179`), which is where the
  `[Set] <path> = <value>` line is emitted.
- **Impact.** `debug-logging-§10` is a **MUST**: *"Every settings mutation MUST be logged once, at
  the schema's single write seam … as `[Set] <path> = <value>`."* A "Copy styling from Player" click
  mutates twenty settings and the debug console shows none of them, so a user debugging why their
  focus bar changed sees a gap in the log exactly where the change happened. Each row's `onChange`
  is also skipped; the button compensates by publishing `APPEARANCE` itself
  (`settings/UnitPanel.lua:226`), which is why nothing is visibly broken **today** — but the moment
  a copied row grows a non-default `onChange`, the copy path silently stops firing it.
- **Reachability:** any player who clicks *Copy styling from Player* on the Appearance page for
  target or focus — a documented control in the page's chrome block, reachable in a default profile.
- **Fix direction:** route the copy through `NS.SetByPath` per key rather than assigning into the
  config table, and drop the now-redundant manual `APPEARANCE` publish at
  `settings/UnitPanel.lua:226`. Keep the deep copy of table-valued colors. Do **not** "fix" it by
  adding a bespoke debug line inside `CopyFromPlayer` — that is a second write path with its own
  logging, which is what `debug-logging-§10` and `architecture-§5` exist to prevent.

### `ABSORBTRACKER-R-03` — the dormant-bracket allocation ceiling is 6.7× the value it guards `[tests]` `[perf]`

- **Where:** `tests/perf.lua:229-238`.
- **Problem.** `PROBE_OFF_BYTES_CEILING = 320` (`tests/perf.lua:235`), justified by the comment four
  lines above it: *"312.0 bytes/pass is the measured figure with the brackets off (identical to
  paintPass, which is the point); the headroom below is deliberately thin, because one extra table
  per pass is exactly the regression this is here to catch"* (`tests/perf.lua:231-234`). Today's
  run measures `probeOverheadOff` at **48.0 bytes/iter** and `paintPass` at **48.0** — the repaint
  path got ~6.5× cheaper (the `ResolvePath` flat-key fast path at `settings/Schema.lua:123-130`
  is the likely cause, and its own comment cites the 312→840 figure from the same era). The
  ceiling was not lowered with it.
- **Impact.** The guard no longer guards. A regression could add **272 bytes per repaint pass** —
  several fresh tables at 10 Hz in combat — and the assertion would still pass. This is the addon's
  only automated evidence for `performance-§2`'s "a dormant bracket is free", so the claim is now
  **weakly** verified rather than unverified: the relational assertion
  (`probeOff <= probeOn + 1`, `tests/perf.lua:240-241`) still holds and still catches a wrong gating
  idiom, but the absolute arm that catches a growing repaint path does not.
- **Reachability:** the offline perf runner only. No shipped behavior. Graded medium on the strength
  of what it stops catching, not on player impact.
- **Fix direction:** re-baseline the ceiling to today's measured 48.0 with the same thin headroom the
  comment describes (a value in the 64–80 range keeps "one extra table is the regression"), and
  rewrite the comment to quote the new measurement and the date. Do **not** delete the assertion,
  and do not raise it. The comment already says *"Raise it only with a recorded reason — a rise IS
  the finding"*; it should say the same about a fall.

### `ABSORBTRACKER-R-04` — three settings sub-pages bypass `SetRenderer`, losing the combat guard and the dirty re-render `[design]` `[ux]`

- **Where:** `settings/General.lua:283-296`, `settings/Appearance.lua:320-323`,
  `settings/Profiles.lua:57-67`. The seam they bypass is `libs/LibKa0s/Options.lua:695-716`.
- **Problem.** All three pages install their own `ctx.panel:SetScript("OnShow", …)`. That is the
  pattern `options-ui-§5` itself shows (`options-ui.md:88-90`), so it is not wrong on its face — but
  the library also publishes `O.SetRenderer(ctx, fn)`, which the library uses for its **own** landing
  page (`libs/LibKa0s/Options.lua:828`) and which adds two things a raw `SetScript` does not get:
  1. **The combat guard.** `libs/LibKa0s/Options.lua:702-709` closes `SettingsPanel` and prints the
     gray refusal when `InCombatLockdown()` is true, and the comment beside it explains why it lives
     there: *"The Blizzard AddOns sidebar reaches a panel without going through OpenOptionsPanel, so
     its combat guard is bypassed on exactly the path a user is most likely to take mid-fight."*
     `options-ui-§2`'s last bullet is a **SHOULD**: *"apply the same `InCombatLockdown()` gate to any
     settings setter that creates or destroys frames"* — and `Helpers.RenderUnitPanel` creates and
     releases AceGUI widgets on **every** Appearance `OnShow` (`settings/UnitPanel.lua:296-307`,
     `:403`).
  2. **The dirty re-render.** `options-ui-§11` is a **MUST**: *"flag every other rendered panel dirty
     and rebuild it lazily on its next `OnShow` (extend the first-show guard to also re-render when
     dirty)"*. `settings/General.lua:285` is `if rendered then return end` with no dirty arm, and
     the library documents the consequence at `libs/LibKa0s/Options.lua:664-666`: *"A ctx that never
     went through SetRenderer has no renderer to re-run, so BOTH tiers fall back to running its
     refreshers ungated"* — i.e. `RefreshAllPanels` also runs these pages' refreshers while they are
     **hidden**, which `options-ui-§11` scopes to the on-screen page.
- **Impact today, stated honestly.** The `MUST` in §11 has no visible symptom yet, because General's
  schema rows never change shape and Appearance rebuilds itself completely on every show. The
  visible one is the guard: `/at config` refuses in combat (`libs/LibKa0s/Options.lua:899`) and the
  landing page refuses in combat, but Esc → Options → *Ka0s Absorb Tracker* → *Appearance* — which
  is where Blizzard lands you if that was your last-viewed category — renders. Two behaviors on one
  window in one session. The addon's own source asserts the opposite at
  `core/AbsorbTracker.lua:211-213`: *"per Ka0s standard options-ui-§2 the settings panel REFUSES to
  open in combat"*.
- **Reachability:** any player on a default profile who opens the settings window during combat and
  whose last-viewed category was a sub-page. No taint — these are insecure canvas frames — and no
  error; the cost is an inconsistent refusal and the widget churn §2 asks to be gated.
- **Fix direction:** move the three page bodies onto `Helpers.SetRenderer(ctx, fn)` and keep the
  `H.EnsureDefaultsButton(ctx.panel)` call outside it exactly as `options-ui-§5` requires (the
  library already makes that call itself at `libs/LibKa0s/Options.lua:698`, so verify it is not
  doubled). Add `SetRenderer` to the degradation stub's no-op list at
  `settings/OptionsSetup.lua:318-337`. Do **not** hand-roll an `InCombatLockdown()` check into each
  page's `OnShow` — that is three copies of a library guard, `anti-pattern #47`.

### `ABSORBTRACKER-R-05` — `throttleWindow` reaches AceTimer unvalidated, alone among the SavedVariables numbers `[design]`

- **Where:** `modules/Timer.lua:50`.
- **Problem.** `NS.addon:ScheduleTimer(doRepaint, NS.GetSetting("throttleWindow"))` passes the stored
  value straight through. Every other number this addon reads out of SavedVariables is `tonumber`'d
  and clamped, with an explicit written rationale — `NS.GetMasterAlpha` (`core/Data.lua:248-254`),
  `NS.GetMasterScale` (`:257-263`) and `NS.GetBarAlpha` (`:276-283`), whose docstring says *"This
  value comes out of SavedVariables, which a player can hand-edit"* (`core/Data.lua:267-268`).
  `throttleWindow` is the one that is not, and it is the one that reaches a library comparison:
  AceTimer's `new()` does `if delay < 0.01 then delay = 0.01 end`
  (`libs/AceTimer-3.0/AceTimer-3.0.lua:33`), which raises *"attempt to compare string with number"*
  for a non-numeric stored value.
- **Impact.** A hand-edited or backup-restored `throttleWindow` of `"0.1"` (string) raises inside
  `NS.RequestRepaint`, which is on the bus handler for `MSG.REPAINT` — i.e. once per absorb event.
  That is an error-spam loop on the addon's highest-frequency path. The schema's `min = 0.05,
  max = 1` (`settings/General.lua:228`) protects the `/at set` and slider paths only; the library's
  `ParseValue` clamps there, and nothing clamps here.
- **Reachability:** only a player who hand-edits `AbsorbTrackerDB.lua` or restores a mangled
  SavedVariables file. Not reachable from the UI or the CLI. That ceiling is why this is medium and
  not high, despite the error-loop shape.
- **Fix direction:** add a `NS.GetThrottleWindow()` beside the other three clamped getters in
  `core/Data.lua`, reading the same `min`/`max` the schema row declares, and call it from
  `modules/Timer.lua:50`. Keep it in `core/Data.lua` with its siblings rather than inlining a
  `tonumber` at the call site — the point of the existing three is that they are one recognisable
  pattern in one place.

---

## Low

### `ABSORBTRACKER-R-06` — the automated-test record is two source-moving commits stale `[tests]`

- **Where:** `docs/automated-tests/RESULTS.md`, newest row `20260825-103352`.
- **Evidence.** That bundle's `manifest.json` stamps `"startedAt": "2026-08-25T10:33:52+05:30"`,
  `"git": { "sha": "bebb43f2caa9e47a5a7299e7456473edaefb2530" }`, and records
  `tests 508/508`, `nloc 7997`, `functions 1126`, `maxCcn 14`. Today's fresh run: **547** tests,
  **8903** NLOC, **1253** functions, **max CCN 15**. The bundle's own `complexity.txt` still lists
  `./settings/Bar.lua` (35.0 avg NLOC), `./settings/Border.lua` and `./settings/Font.lua` — three
  files that no longer exist, having merged into `settings/Appearance.lua` in the settings revamp.
- **Drift against the watch list, named explicitly:**
  - `NS.ValidateSchema@257-299@./settings/Schema.lua` is now the maximum at **CCN 15**; the newest
    bundle records it at `NS.ValidateSchema@227-264` with **CCN 14**. It crossed since the report.
  - `addon@164-185@./core/AbsorbTracker.lua` (`OnAbsorbChanged`) holds at **CCN 14**, unchanged.
  - `NS.ResolveColor@53-64@./core/CoreSetup.lua` at **CCN 14** is new to the top three and appears
    on no committed watch list.
  - Nothing the newest bundle flags is un-flagged today; `lizard` reports **0 warnings** in both.
- **Impact.** None on the shipped addon. `RESULTS.md`'s prose section also still narrates "489 cases
  as of `20260807-114413`" as the current state, which is now two counts behind.
- **Reachability:** a maintainer reading the record. **Stale, not non-compliant** — regeneration
  belongs to `/wow-addon:bump-version` at release, not to this review and not to a fix commit.
- **Fix direction:** none now. Note in the release checklist that the next regeneration should show
  `ValidateSchema` at 15 and pick up the three deleted `settings/` files.

### `ABSORBTRACKER-R-07` — `core/Units.lua` says "fifteen appearance keys" twice; there are nineteen `[naming]`

- **Where:** `core/Units.lua:74` (*"THE read path for all fifteen appearance keys"*) and
  `core/Units.lua:108` (*"deep-copy the player's fifteen appearance keys onto `unit`"*).
- **Evidence.** `Units.APPEARANCE_KEYS` (`core/Units.lua:25-31`, the list beginning
  `"barTexture", "bgTexture", …`) holds **19** string entries — counted mechanically, not by eye.
  The header comment above the list gets it right: *"The nineteen appearance keys, in profile order"*
  (`core/Units.lua:19`). The same file therefore says both numbers.
- **Impact.** A reader auditing the mirror or the v3 lift against the wrong count. `settings/Appearance.lua:35`
  compounds it slightly by describing the composers as having *"added"* `fontShadow` without the
  count moving anywhere.
- **Reachability:** a maintainer reading the file; no runtime effect.
- **Fix direction:** make both read "nineteen", or — better — stop stating a count in prose that a
  `#Units.APPEARANCE_KEYS` already answers and that a fourth row will invalidate again.

### `ABSORBTRACKER-R-09` — `CreateOptionsPanel is not safely re-callable` is no longer true `[naming]`

- **Where:** `core/AbsorbTracker.lua:69`.
- **Problem.** The comment justifies extracting `SyncUnitEventFrames` from `OnEnable` on the grounds
  that *"CreateOptionsPanel is not safely re-callable"*. It is: `libs/LibKa0s/Options.lua` opens
  `O.CreateOptionsPanel` with *"Idempotent: a second call is a no-op … re-running it would register
  a SECOND Blizzard category"* and the guard `if mainCategory then return end`
  (`libs/LibKa0s/Options.lua:838-844`). The library took ownership of that hazard; the addon's
  comment still records the pre-library state as a live constraint.
- **Impact.** A future maintainer avoids an `OnEnable` restructure for a reason that no longer holds,
  or worse, adds a second guard of their own.
- **Reachability:** a maintainer reading the file; no runtime effect.
- **Fix direction:** rewrite the parenthetical to say the extraction is for test isolation, and note
  that the library owns the idempotence.

### `ABSORBTRACKER-R-10` — `NS.PartitionUnitRows` is a dead export kept alive by its own test `[design]` `[tests]`

- **Where:** `settings/Schema.lua:101-111`; its only caller anywhere is
  `tests/test_schema.lua:524-530`.
- **Evidence.** A grep across `core/ modules/ settings/ defaults/ locales/` finds the definition and
  nothing else. Three docs already say so in as many words —
  `docs/schema.md:265` (*"has no production caller left"*), `docs/ARCHITECTURE.md:74` (*"kept and
  unit-tested, but with no production caller since the mirrored state became a hint under the tab
  strip"*), `docs/module-map.md:530`. `settings/UnitPanel.lua` replaced it with the local
  `partitionTabs` (`settings/UnitPanel.lua:110-124`), which partitions by `group` and `skipRender`
  rather than by `alwaysPerUnit`.
- **Impact.** A published surface with no consumer, and one green test case that proves only that a
  function nobody calls behaves. It also carries CCN 11 into the complexity report
  (`docs/automated-tests/20260825-103352/complexity.txt:195`).
- **Reachability:** nobody at runtime; the test inventory only.
- **Fix direction:** delete the function, its case, and the three doc entries in one change — and
  move `docs/test-cases.md` and the README `[Tests]` badge in the **same** change (547 → 546). This
  is exactly the "dead export sweep" the file's own docs invite; the decision to keep it needs a
  consumer, not another green test.

### `ABSORBTRACKER-R-11` — `migrateAllProfiles` is a hand-copy of `forEachProfile` `[design]`

- **Where:** `core/Database.lua:95-112` vs. `core/Database.lua:118-135`.
- **Problem.** The two functions are the same walk — active profile first, then `db.sv.profiles`
  skipping the active one, counting truthy returns — down to a byte-identical five-line comment
  block (`core/Database.lua:99-101` and `:122-124`). `migrateAllProfiles` is
  `forEachProfile(NS.MigrateProfileToV3)`, and the only reason it is not is that it is defined
  seventeen lines earlier in the file.
- **Impact.** Two copies of a store walk; a change to how profiles are enumerated has to land twice,
  and the duplicated comment makes the copies look deliberate.
- **Reachability:** a maintainer editing the migration ladder; no runtime difference — both walks
  agree today.
- **Fix direction:** move `forEachProfile` above `migrateAllProfiles` and reduce the latter to
  `return forEachProfile(NS.MigrateProfileToV3)`. Behavior-identical; pin it with the existing
  multi-profile v3 cases in `tests/test_database.lua` before and after.

### `ABSORBTRACKER-R-12` — two settings fire a full three-bar restyle they have no stake in `[perf]`

- **Where:** `settings/General.lua:210-230` (`throttleWindow`, no `onChange`) and the composed
  `state.debugConsole` row (`settings/OptionsSetup.lua:290-291` in the stub; the live composer's
  equivalent). Both fall through to `defaultOnChange` (`settings/Schema.lua:158-160`), which
  publishes `MSG.APPEARANCE`.
- **Impact.** Toggling the debug console checkbox, or nudging the update-throttle slider, runs
  `NS.UpdateBarAppearance` over all three bars: today's `appearancePass` measures **0.034 ms/iter,
  48 API calls and 384.5 bytes per pass** — two `SetBackdrop` calls and four LibSharedMedia fetches
  per bar, for a timer value and a window's visibility. A slider drag does it once per step.
- **Reachability:** any player dragging the *Update throttle* slider or clicking *Debug console* on
  the General page. Harmless at this magnitude; it is waste, not a stall.
- **Fix direction:** give `throttleWindow` an explicit no-op `onChange` (the next repaint reads the
  value fresh at `modules/Timer.lua:50`, so nothing needs republishing) and give the console row one
  too. Do **not** change `defaultOnChange` — `APPEARANCE` is the right default for the appearance
  rows that are the overwhelming majority.

### `ABSORBTRACKER-R-13` — one committed file has mixed line endings in the working tree `[lint]`

- **Where:** `docs/revendor/2026-08-25/01_DELTA.md`.
- **Evidence.** `git ls-files --eol` reports
  `i/lf w/mixed attr/text=auto eol=crlf  docs/revendor/2026-08-25/01_DELTA.md` — the only text file
  in the repo whose working-tree state disagrees with the `.gitattributes` pin. Every other tracked
  text file is `w/crlf`, and the single `w/lf` is `tests/_kit/run-automated-tests.sh`, which is the
  `*.sh text eol=lf` carve-out working exactly as intended. `.gitattributes` itself carries the
  correct client-bound pin (`* text=auto eol=crlf`), the `.sh` carve-out and the binary markings.
- **Reachability:** nobody — a frozen doc bundle, not shipped to the client.
- **Fix direction:** none from this review. Recorded as an **observation**; the authoritative
  straggler count and its remediation belong to `/wow-addon:standards-audit` (`line-endings-§2`).

---

## Things checked and found clean

Recorded so a later reader does not re-derive them:

- **Taint / protected APIs.** No call to a protected API anywhere in the addon's own files. The bars
  are plain `Frame`/`StatusBar` on `UIParent` with no secure template
  (`modules/Bar.lua:88`, `:117`). No `setmetatable` on a widget. No `:Hook` on a secure function.
  `Settings.Register*` runs at `OnEnable`, which `options-ui-§1` and `§9` place outside the gate.
- **Secret values.** `UnitGetTotalAbsorbs` is read raw and handed straight to C-side sinks —
  `SetValue`, `AbbreviateNumbers` (`modules/Display.lua:365-371`) — never through `tonumber` and
  never compared. The two debug read sites gate on `NS.IsConcatSafe(v)` before any comparison
  (`core/AbsorbTracker.lua:170`, `:232`). `docs/scope.md` records why "hide when absorb is zero" is
  unimplementable, and `NS.ShouldShowBar` honors it (`modules/Display.lua:277-279`).
- **Events.** Registered in `OnEnable`, never `OnInitialize` (`core/AbsorbTracker.lua:73-74`).
  `UNIT_ABSORB_AMOUNT_CHANGED` and `UNIT_MAXHEALTH` go through `RegisterUnitEvent` on one private
  frame per unit (`core/AbsorbTracker.lua:108-138`) rather than through AceEvent's shared frame —
  the deviation is documented in the TOC comment and in `docs/ARCHITECTURE.md`. Re-registration is a
  documented no-op; disabled units unregister. No removed or renamed event is referenced.
- **Deprecated APIs.** None. `C_AddOns.GetAddOnMetadata` is reached through the `LibKa0s-Env` seam
  with the deprecated global as a documented fallback rung (`core/EnvSetup.lua:65-74`).
  `BackdropTemplate` is passed at `modules/Bar.lua:88`.
- **Frames.** `CreateFrame` runs at file load and once per unit, never per event or per update. There
  is no `OnUpdate` handler in the addon at all. `ClearAllPoints` precedes every re-anchor
  (`modules/Display.lua:129`, `settings/UnitPanel.lua:153`). AceGUI widgets built into the chrome
  band are released after the render, with a written explanation of why after and not before
  (`settings/UnitPanel.lua:245-257`).
- **Descriptors and stubs.** All five setup files were diffed against their call sites. The Perf stub
  (`core/PerfSetup.lua:22-30`) answers exactly the four members the addon calls — `on`, `suspended`,
  `Note`, `OnCommand`. The DebugLog stub answers all sixteen. The Slash stub answers every dispatcher
  member reached. No stub re-implements a library formatter, and `tests/test_surface_parity.lua`
  pins all four surfaces. Declared perf buckets and actual brackets match one-for-one (five and
  five) — the only defect is the missing observed parent in `ABSORBTRACKER-R-01`.
- **Conventions.** `NS.PREFIX` exists and every user-facing line goes through the shadowed
  `local print = NS.Print`; no raw `print(` bypasses it. `NS.COMMANDS` and the README's `/at` verbs
  are in exact bidirectional agreement — 17 verbs each, no orphan in either direction.
- **Localization.** `NS.L` exists with the key-returning metatable, and `locales/enUS.lua:8-12`
  states plainly that v1.8.0 ships English-only with strings still hardcoded. That is a declared
  position, not drift. `tests/test_docs.lua` additionally enforces US spelling and the CurseForge
  angle-bracket rule over the addon's own files.
- **The library's own strings.** `tests/test_surface_parity.lua` includes tripwires asserting that no
  LibKa0s descriptor in this addon is handed the key-returning locale table, and that DebugLog,
  Slash and Perf each resolve a fallback-only override to their own strings. Green today.
