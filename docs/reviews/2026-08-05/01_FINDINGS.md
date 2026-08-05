# AbsorbTracker — Review Findings (2026-08-05)

**Verdict: minor issues.** Nothing blocks a ship. The addon loads clean, lints clean, its 470-case
gate is green, and its taint / secret-value / deprecated-API surface is correct. What this review
found is one defect in the **perf descriptor** that makes every capture report a false containment
relation, two narrow **functional gaps** (`/at test` never restores; a player-only guard on a
multi-unit repaint), one **honesty gap** in a reset acknowledgment, and a handful of assertions and
comments that no longer describe the code.

Standards cross-check: **performed** against the Ka0s WoW Addon Standard **v2.21.0** (fetched
2026-08-05 from `tusharsaxena/WowAddonStandards@master`; index plus every section file linked from
its Sections map).

---

## Measurement run (Step 0 — everything below was run fresh, from the repo root, today)

| Suite | Command | Result |
|---|---|---|
| **luacheck** | `luacheck .` | **pass** — 0 warnings / 0 errors in 28 files |
| **Headless tests** | `lua5.1 tests/run.lua` | **pass** — 470 passed, 0 failed, 470 total (exit 0) |
| **Test-case inventory** | `lua5.1 tests/run.lua --list` → scratch | **pass** — 567 lines; **byte-identical** to committed `docs/test-cases.md` (no drift) |
| **Offline perf** | `lua5.1 tests/perf.lua` | **pass** — 6 scenarios, 0 assertion failures, 1000 events → 1 repaint (exit 0) |
| **Complexity** | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` → scratch | **pass** — 1063 functions, 7574 nloc, avg CCN 1.7, **0 functions with CCN > 15** |
| **`make test`** | — | **skipped** — no `Makefile` at the repo root; this repo has no canonical wrapper target |
| **Vendor sync** | `diff -r libs/LibKa0s/ ../LibKa0s/…` | **skipped** — this run is scoped to a single repo and may not read sibling checkouts. See **F-013**: the in-repo `tests/test_vendor_sync.lua` substitute went green, but that pair returns green *without looking* when the sibling checkout is absent, so its two PASS rows are **not** evidence of sync. |

**Fresh perf numbers (`lua5.1 tests/perf.lua`, 2026-08-05):**

```
scenario                iters      ms/iter     api/iter   bytes/iter
absorbEvent              1000      0.00023          0.0          0.0
paintPass                1000      0.00511         12.0        312.0
appearancePass            200      0.02042         33.0        893.7
settingsRead            10000      0.00025          0.0          0.0
probeOverheadOff         1000      0.00509         12.0        312.0
probeOverheadOn          1000      0.00599         12.0        312.3
```

**Committed artifacts vs. today's run — agreement/disagreement:**

- `docs/test-cases.md` — **agrees.** Identical to the fresh `--list` output.
- `README.md` `[Tests]` badge (`470/470`, `README.md:7`) — **agrees** with the fresh run.
- `docs/automated-tests/RESULTS.md` newest row `20260804-233138` (lint 0/0 over 28 files, tests
  470/470, nloc 7574, funcs 1063, avg CCN 1.7, max CCN 15, 0 CCN warnings) — **agrees** with every
  fresh measurement. Its watch list ("**None.** No function in this addon's own source exceeds
  CCN 15", one function *at* 15: `Helpers.BuildMainContent`) is **confirmed** by today's `lizard`
  run: no function flagged, no drift in either direction.
- `docs/automated-tests/20260804-233138/manifest.json` stamps git SHA `ab2603e` on branch
  `feat/fix-ccn`, `dirty: true`; HEAD is now `e31b79d`. The two intervening commits touched
  `README.md`, `docs/`, `libs/LibKa0s/**` and `tests/_kit/**` and **no** addon runtime source, which
  is why every number still reproduces. The bundle is **current in substance, stale in stamp** —
  worth knowing, not a finding.
- `docs/performance.md` — its **sample** report is illustrative (a 2026-07-29 in-client capture), not
  a claim about today's offline numbers, so there is no numeric disagreement to report. Its *reading
  guidance* is a separate matter — see **F-007**.
- `docs/perf-runs/2026-07-30-ingame-post-extraction.json` — the committed in-client record is used as
  evidence under **F-001**; its bucket figures are quoted there.

In-client checks (taint under real combat, the `/<addon> perf` two-arm capture protocol, locale
rendering, saved-variable migration across a real `/reload`) are deliberately **not** in this block.
They are written up for a human in `03_SMOKE_TESTS.md`.

---

## High

### F-001 — the perf descriptor declares two buckets as nested that are never nested `[perf]` `[design]`

**Where:** `core/PerfSetup.lua:46-47`

```lua
{ key = "paintBar",    within = "repaintPass" },  -- true
{ key = "appearance",  within = "repaintPass" },  -- FALSE
{ key = "visibility",  within = "repaintPass" },  -- FALSE
```

**Problem.** `repaintPass` is opened in `doRepaint` (`modules/Timer.lua:22-41`), whose entire body is
`NS.ForEachUnit(function(unit) NS.UpdateAbsorbBar(unit) end)`. `NS.UpdateAbsorbBar` opens `paintBar`
(`modules/Display.lua:190-202`) — genuinely nested. `NS.UpdateBarAppearance` (`appearance`,
`modules/Display.lua:59-105`) and `NS.ApplyVisibility` (`visibility`,
`modules/Display.lua:158-165`) are reached from the `APPEARANCE` / `VISIBILITY` bus messages
(`modules/Display.lua:216-221`) and from `UpdateBarAppearance` itself — **never** from `doRepaint`.

**Impact.** The library renders `within` as report indentation *and* as an explicit containment note
plus a "do not sum" instruction (`libs/LibKa0s/Perf.lua:212-244`). Every capture this addon produces
therefore asserts "repaintPass contains appearance" and "repaintPass contains visibility", both
false, and tells the reader to exclude two buckets of **real, non-nested** cost from the addon's
total. This is a defect in the addon's primary performance evidence, which is the thing every future
perf decision is made from.

**Measured.** The committed in-client capture
`docs/perf-runs/2026-07-30-ingame-post-extraction.json` carries `"within": "repaintPass"` on
`visibility` — 15 calls, 0.0779 ms total — alongside `repaintPass` (24 calls, 1.4522 ms) and
`paintBar` (48 calls = 2 bars × 24 passes, 0.8098 ms). 48 = 2×24 is the arithmetic signature of a
genuinely nested bucket; 15 against 24 is not, and cannot be, because `doRepaint` never calls
`ApplyVisibility`. The addon's own write-up already states the true relation and only the true one:
`docs/performance.md:239` and `docs/performance.md:273` both say "`repaintPass` contains `paintBar`"
with no mention of the other two — so the doc and the descriptor already disagree.

**Fix direction.** Drop `within` from the `appearance` and `visibility` bucket declarations so they
render as the top-level totals they are. This is the addon's own descriptor, not library code —
`performance-§2`'s bucket rules are satisfied by declaring nesting that matches the call graph, not
by declaring more of it.

**Coverage note.** `docs/test-cases.md:170` claims a case over the descriptor ("perf: the addon holds
a real LibKa0s-Perf instance"), and `tests/test_perf.lua` asserts bucket keys and order — but nothing
asserts that a bucket declared `within X` is actually reached from inside X's bracket. That is the
case that would have caught this.

---

## Medium

### F-002 — `/at test` promises a timed preview and never restores `[ux]` `[bug]`

**Where:** `settings/Slash.lua:282-291`, guard at `modules/Display.lua:186-188`

`runTest` prints `"Testing display with value: %s for %d s"`, paints the fake value, and sets
`NS.testHoldUntil = GetTime() + hold`. `NS.UpdateAbsorbBar` then returns `false` while the hold is
live. **Nothing schedules a repaint at expiry.** The real value returns only when the next
`UNIT_ABSORB_AMOUNT_CHANGED` / `UNIT_MAXHEALTH` / world / combat / target-swap event happens to
arrive. Standing out of combat with no shield ticking — the exact situation in which a user runs
`/at test` to preview styling — that is indefinite: the bar keeps showing `50.0K` long after the
stated 5 seconds, with no command short of `/at update` to clear it.

**Impact.** The message states a duration the code does not honor. Low severity of harm, but it is a
promise in user-facing text that the implementation does not keep.

**Coverage note (the more valuable half).** `docs/test-cases.md:280` reads
"UpdateAbsorbBar paints again once the hold window has expired", which *sounds* like the restore is
covered. `tests/test_display.lua:293-299` sets `NS.testHoldUntil` into the past and calls
`NS.UpdateAbsorbBar` **directly** — it proves the guard opens again, and cannot prove that anything
in the addon ever calls it. The case is asleep with respect to this defect.

**Fix direction.** Arm a one-shot `NS.addon:ScheduleTimer` for `hold` seconds that publishes
`NS.MSG.REPAINT` — the same AceTimer path `modules/Timer.lua:50` already uses (Ace3 timer, not a raw
`C_Timer`), and the same payload-free bus publish every other transition uses (`architecture-§4`).

### F-003 — the show-only-in-combat repaint guard is player-only in a three-unit addon `[bug]`

**Where:** `settings/General.lua:50-53`

```lua
onChange = function()
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
    if NS.ShouldShowBar() then NS.bus:SendMessage(NS.MSG.REPAINT) end
end,
```

`NS.ShouldShowBar()` with no argument defaults `unit` to `"player"` (`modules/Display.lua:130-131`).
`showOnlyInCombat` is a **global** that governs all three bars. With the player bar disabled and the
target or focus bar enabled — a supported configuration, since `units.<unit>.enabled` is the only
visibility switch since schema v4 — toggling this option makes bars appear via the `VISIBILITY`
publish while the `REPAINT` is suppressed, so a freshly-shown bar renders whatever it last held.

**Impact.** A stale absorb value on a newly-shown target/focus bar until an unrelated event lands.
Self-corrects quickly in combat; can persist out of combat.

**Fix direction.** Publish `REPAINT` unconditionally (the repaint is already coalesced by
`modules/Timer.lua` and `UpdateAbsorbBar` early-outs per bar), or evaluate the guard across
`NS.Units.LIST` rather than the implicit player default.

### F-004 — the Reset All popup claims success it did not verify `[ux]` `[design]`

**Where:** `settings/General.lua:133-138` vs. `settings/Slash.lua:169-175`

The popup's `OnAccept` guards the *call* but prints the acknowledgment **outside** the guard:

```lua
OnAccept = function()
    if NS.Helpers and NS.Helpers.RestoreAllDefaults then
        NS.Helpers.RestoreAllDefaults()
    end
    print("All settings reset to defaults.")   -- prints even when nothing ran
end,
```

`runResetAll` does the opposite, deliberately, and says so in a comment written for exactly this
case: *"The acknowledgment lives INSIDE the guard … printing the ack anyway would claim success for
work that did not happen."* The two paths that the file headers repeatedly promise "can never
diverge" have diverged on the one thing that matters when the settings library is absent.

Secondary: the two acknowledgments differ in wording (`"All settings reset to defaults."` vs.
`"All settings reset to defaults"`), so the same action reads differently depending on which surface
triggered it.

**Fix direction.** Move the print inside the guard and add the same `else` branch `runResetAll`
carries; make the two strings identical.

### F-005 — the runner's suite list is hand-maintained and a missing suite is silently skipped `[tests]`

**Where:** `tests/run.lua:57-82`; skip behavior at `tests/_kit/framework.lua:98-113`

`tests/test_loadorder.lua:1-12` enumerates "FOUR places that name the addon's files in load order"
and pins all four — the TOC, `tests/run.lua`'s addon list, `tests/perf.lua`'s, and the LibKa0s XML
order. It does **not** pin the fifth: the `suites = { … }` list. The vendored kit skips a listed
suite whose file is missing rather than failing (documented behavior, `framework.lua:98-100`), and
nothing asserts the converse — that every `tests/test_*.lua` on disk is listed.

**Impact.** Both failure directions are silent. A renamed suite stops contributing cases and the run
stays green; a newly written suite that is never added to the list contributes nothing while
`docs/test-cases.md` and the `[Tests]` badge both move to the *lower* count with no signal. Today the
two sets happen to match exactly (21 files, 21 entries — verified by inspection this run), which is
precisely when the guard is cheapest to add.

**Fix direction.** A case in `tests/test_loadorder.lua` that enumerates `tests/test_*.lua` and
asserts set equality with the runner's `suites` list. This is the addon's own harness and its own
list; the kit's skip semantics stay untouched.

### F-006 — the zero-overhead perf assertion cannot fail for the defect it exists to catch `[perf]` `[tests]`

**Where:** `tests/perf.lua:218-231`

```lua
assert_(probeOff.bytesPerIter <= probeOn.bytesPerIter + 1,
  "a dormant bracket allocated more than an armed one — the gating idiom is wrong")
```

The claim the scenario exists to defend is `performance-§2`'s *a dormant bracket is free*. The
assertion written is *a dormant bracket allocates no more than an armed one* — which is satisfied by
a dormant bracket allocating 300 bytes per pass, as long as the armed one allocates at least as much.
It cannot go red for a regression that makes the **off** path allocate, because any such regression
lands on the on path too. The message even states the weaker claim as though it were the stronger one.

**Measured (today).** `probeOverheadOff` 312.0 B/iter, `probeOverheadOn` 312.3 B/iter, both 12
api/iter — the numbers are healthy; it is the *assertion* that is not load-bearing. So
`performance-§2`'s zero-overhead property is currently **unverified by any case that can go red**.

**Fix direction.** Assert the dormant arm against a bracket-identical dormant baseline that already
exists in the same run — `probeOff.bytesPerIter == paintPass.bytesPerIter` (both capture-off runs of
the same path, so any drift is instrumentation) — and add an **absolute** ceiling on the armed
delta, e.g. `probeOn.bytesPerIter - probeOff.bytesPerIter < 8`. State plainly in the comment that a
true "instrumentation absent" arm cannot be produced in-process, so the property is pinned by
constancy rather than by absence. No wall-clock assertion is to be added (`performance-§9`).

### F-007 — the perf write-up tells the reader to headline the frame-time delta `[perf]` `[docs]`

**Where:** `docs/performance.md:242` and `docs/performance.md:247`

> **`delta` is the headline.** It is the per-frame cost of having the addon active…
> … against a measured delta of **2.74 ms/frame**. That gap — two orders of magnitude — is the
> finding

`performance-§` is explicit in the other direction: *"**MUST** read the **bucket figures** as the
addon's cost, and treat the frame-time delta as **unresolved** below the harness's measured
run-to-run spread. A per-frame delta is a difference of two noisy aggregates; the buckets measure the
addon's own code directly."*

The doc does carry the caveat later (`docs/performance.md:258`, "a resolution floor of roughly
±0.3 ms/frame"), so this is framing rather than error — but "the headline" is what a reader takes
away, and it is the framing under which a future reviewer would build a perf finding on a number the
standard says is unresolved. It also sits badly beside **F-001**, which is the other half of the same
problem: the report's bucket section is currently mis-nested *and* the doc points the reader away
from it.

**Fix direction.** Re-headline the bucket table as the addon's cost; keep the delta as corroboration
with its resolution floor stated at the point of use, not four paragraphs down.

---

## Low

### F-008 — the account-wide schema stamp defaults to the current version, deadening the ladder `[savedvariables]`

**Where:** `defaults/Profile.lua:74-79`; consequence at `core/Database.lua:187-215`

`NS.defaults.global.schemaVersion = 4`. AceDB's `copyDefaults` fills every absent key on first access
to `db.global`, which happens **before** `NS:RunMigrations` reads it — so any DB whose `global`
section first materializes on this version is stamped `4` and every `SCHEMA_STEPS` entry is skipped.
That is the identical failure mode the sibling comment at `defaults/Profile.lua:50-55` documents in
detail and defaults the *per-profile* stamp to `1` to avoid ("A default of 3 would stamp every pre-v3
profile as already-migrated on first touch and make the gate permanently dead").

It also makes `core/Database.lua:190`'s `g.schemaVersion = g.schemaVersion or 1` unreachable under
real AceDB — it fires only on the no-AceDB fallback path (`core/Database.lua:18-21`), where `global`
is a bare `{}`.

**Impact today: none observable.** The only steps such a user would miss are v2 (`updateInterval`)
and v4 (`hidden`), both of which delete keys nothing reads. The exposure is prospective: the next
ladder step that does real work would silently never run for that population, and the ladder is
explicitly designed to be extended one row at a time (`core/Database.lua:166`).

**Fix direction.** Default `global.schemaVersion` to `1` and let the (idempotent) ladder run once on a
fresh install, matching the per-profile stamp's already-reasoned choice — `savedvariables-§`'s
migration seam is meant to be reached, and each step here is a no-op on fresh data.

### F-009 — three table-copy implementations, one of them exported with no callers `[design]`

**Where:** `core/Units.lua:36-42`, `core/Database.lua:26-31`, `settings/Schema.lua:158-164`

`core/Units.lua`'s `deepcopy` and `core/Database.lua`'s are byte-identical recursive copies; `Units`
even publishes its as `Units.DeepCopy` (`core/Units.lua:42`), which has **zero** callers anywhere in
the addon's own source (only `tests/test_units.lua` reaches it — verified by grep across
`core/ modules/ settings/ defaults/ locales/`). `core/Units.lua` loads before `core/Database.lua` in
the TOC, so the second copy has no ordering excuse.

`settings/Schema.lua:158`'s comment reads "DeepCopy color tables so two profiles can't end up sharing
the same nested table" above a **shallow** one-level loop that calls nothing named DeepCopy. Correct
for a flat `{r,g,b,a}`, but the comment names an operation the code does not perform.

**Fix direction.** Point `core/Database.lua` at `NS.Units.DeepCopy` (giving the export its caller) and
reword the `Schema.lua` comment to say what the loop does and why one level is sufficient here.

### F-010 — `Units.Set`'s doc comment names a caller that does not exist `[naming]`

**Where:** `core/Units.lua:78-85`

> *"The panel hides the appearance widgets while mirrored, so this path is only reachable from the
> slash CLI."*

The slash CLI writes through `NS.SetByPath` → `NS.SetSetting` → `NS.SetPath`
(`settings/Schema.lua:142-152`, `core/Data.lua:44-49`), walking the dotted profile path directly. It
never calls `Units.Set`. The function has **zero** production callers; only `tests/test_units.lua`
exercises it.

**Impact.** A reader trusts the comment and believes the slash path is mirror-unaware *via this
function*, which sends them to the wrong file when reasoning about the mirror. The behavior the
comment describes is real — it just lives elsewhere.

**Fix direction.** Either correct the comment to say the function is a namespace API with no current
caller, or delete it and let `NS.SetByPath` be the single documented write path.

### F-011 — `modules/Bar.lua` justifies its player aliases with a file deleted two releases ago `[naming]`

**Where:** `modules/Bar.lua:5-6` and `modules/Bar.lua:86-87`

> *"as player aliases for the call sites that predate multi-unit (core/DebugLog.lua,
> settings/Slash.lua, the tests)"*

`core/DebugLog.lua` no longer exists — its TOC slot is `core/DebugLogSetup.lua` and the console is
library code. `settings/Slash.lua`'s `/at test` reads `NS.bars[unit]`
(`settings/Slash.lua:283-289`), not the aliases. The only remaining readers of `NS.bar`,
`NS.statusBar`, `NS.valueText`, `NS.backdropInfo` are `tests/test_data.lua:334-336` and
`tests/test_display.lua`.

**Impact.** Four exported namespace members are held alive by a rationale that named two callers, one
of which is gone and the other of which never used them. Not dead code — the tests are real callers —
but the comment misstates why it is there.

**Fix direction.** Reword to say the aliases are a test-facing convenience.

### F-012 — the class-color comment says the code does not cache; it does `[naming]`

**Where:** `core/Data.lua:6-9` vs. `core/Data.lua:93-108` and `core/Data.lua:128-144`

> *"Color getters re-read the useClassColor* toggles on every call so a class change / respec /
> profile switch 'just works' without explicit refresh wiring — do NOT cache the resolved color on a
> frame."*

The **toggles** are re-read every call, as stated. The **resolved class colors** are memoized into
module-locals (`playerClassColor`, `playerBgClassColor`) with no invalidation path — no
`ClearLSMCache`-style reset, nothing hooked to profile change. Benign in practice, because a
character's class cannot change within a session, but the header reads as "nothing here is cached".

**Fix direction.** Extend the comment: toggles are live, the class color itself is memoized once
because class is immutable for the session.

### F-013 — the vendor-sync pair goes green without looking, and its case names do not say so `[tests]`

**Where:** `tests/test_vendor_sync.lua:105-116` and `:138-151`; comment at `:106-109`

`siblingTag()` returns `nil` when `../LibKa0s` is not a checkout, and both cases then `return`
immediately — **PASS**, with no note. The file's own comment claims this is disclosed:

> *"A missing sibling is the ONE case where this pair may go quiet, and it is said in the case name
> rather than hidden."*

The case names are *"libs/LibKa0s is the LibKa0s release the README says this addon bundles"* and
*"tests/\_kit is the test kit that shipped with that release"*. Neither names the condition. In
`docs/test-cases.md` — which the standard treats as the authoritative inventory — an unlooked-at
provenance check is indistinguishable from a verified one.

**This is why the vendor-sync row in the measurement block above is a skip and not a pass.** This run
could not read the sibling repo, so it cannot tell which of the two happened, and neither can any
reader of the committed inventory.

**Fix direction.** Name the cases so the condition is visible (e.g. *"…, when the LibKa0s checkout is
beside this repo"*), or register a distinct case that reports "sibling checkout absent — provenance
unverified" so the inventory carries the distinction. Do **not** make a missing sibling fail: the
file's reasoning for the quiet path is sound; only its disclosure is missing.

---

## Not findings — checked and clean

Recorded so a later reader knows these were looked at rather than skipped.

- **Taint / protected APIs.** No protected call on a non-secure path; no `SecureActionButtonTemplate`
  attribute writes; no `:Hook` where `hooksecurefunc` is required. The settings panel refuses to open
  in combat inside the library (`libs/LibKa0s/Options.lua:463`, `:637`), which is `options-ui-§2`'s
  required shape.
- **Secret values.** `UnitGetTotalAbsorbs` results flow straight to `SetValue` / `AbbreviateNumbers`
  (`modules/Display.lua:192-198`) with no `tonumber`, no `tostring`, no `:format`. The debug paths
  gate on `NS.IsConcatSafe` before comparing or formatting (`core/AbsorbTracker.lua:170`,
  `:232`).
- **Deprecated APIs.** None present. `GetAddOnMetadata` is reached only through the single
  `NS.Compat` shim with a `C_AddOns` preference (`core/Compat.lua:12-19`), and
  `tests/test_compat.lua:31` pins that no inline call leaks.
- **Event registration.** Events register in `OnEnable`, not `OnInitialize`
  (`core/AbsorbTracker.lua:49-81`); the two high-frequency unit events use per-unit
  `RegisterUnitEvent` frames (`:108-138`); the swap events are registered only while their unit is
  enabled (`:144-153`).
- **Single write path.** No direct `db.profile.x = y` write exists outside `NS.SetSetting`. Position
  writes route through `NS.Units.SetPosition`, which is not a schema row and correctly bypasses
  `onChange`.
- **COMMANDS ↔ README.** All 17 entries in `NS.COMMANDS` (`settings/Slash.lua:61-102`) appear in the
  README table (`README.md:53-68`) and vice versa.
- **Degradation stubs.** Every member the addon calls on `NS.Perf`, `NS.DebugLog`, `NS.Helpers` and
  the slash `cli` is answered by the corresponding stub (verified by grepping call sites against each
  stub's member set). No stub re-implements a library formatter, line format or layout constant.
- **Load lists.** Both runners derive the addon's own files from the TOC
  (`tests/run.lua:33`, `tests/perf.lua:65`) and spell the LibKa0s files out in XML order, with
  `tests/test_loadorder.lua:82-105` pinning both.
- **Complexity.** Zero functions over CCN 15 in today's run; the one file in `layout-§1`'s 1000–1500
  on-notice band (`tests/test_slashcmds.lua`, 1256 LOC) carries an explicit accepted disposition in
  `RESULTS.md`.

## Upstream findings

**None.** No defect in this review lands under `libs/` or `tests/_kit/`. Every finding above is in the
addon's own source, docs or harness.
