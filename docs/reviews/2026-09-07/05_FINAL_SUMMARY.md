# AbsorbTracker — post-implementation summary, 2026-09-07

> **Written ahead of implementation.** This artifact assumes every change in
> `02_PROPOSED_CHANGES.md` has been applied and every test in `03_SMOKE_TESTS.md` has passed. Fill in
> the bracketed figures from the actual run before using it as a PR description; anything still
> bracketed has not been measured.

---

## Headline

AbsorbTracker came into this review green on every out-of-game suite, byte-identical to its vendored
LibKa0s tag, and with its generated test inventory and README badge already agreeing with a fresh
run. There were no crashes to fix and no taint to chase. What this cycle fixed instead is a class of
defect that is easy to miss precisely because nothing goes red for it: **places where the addon's own
records say something the code does not do.** The perf report claimed it had observed a bar-paint
nesting it had only declared. The *Copy styling from Player* button mutated twenty settings without a
single line in the debug log the standard requires. The offline runner's allocation ceiling had drifted
to nearly seven times the value it was guarding. Three sub-pages of the settings window rendered during
combat while the addon's own source asserted they refused. Alongside those, one live upstream defect in
the shared options library was confirmed still open and routed to the repo that owns it.

---

## Counts

- **Critical fixed: 0** (none were found)
- **High fixed: 0** (none were found)
- **Medium fixed: 5** — `ABSORBTRACKER-R-01`, `-02`, `-03`, `-04`, `-05`
- **Low fixed: 6** — `ABSORBTRACKER-R-07`, `-09`, `-10`, `-11`, `-12`, and `-06` recorded rather than fixed
- **Routed upstream: 1** — `ABSORBTRACKER-R-08` (LibKa0s `OptionsCompose.lua`)

**Deliberately not fixed here:**

| ID | Why |
|---|---|
| `ABSORBTRACKER-R-06` | `docs/automated-tests/RESULTS.md` is regenerated at **release** by `/wow-addon:bump-version`, never by a review or a fix commit. Its expected movement is written into `02_PROPOSED_CHANGES.md` `C-08` so the next regeneration can be checked against a prediction rather than merely accepted. |
| `ABSORBTRACKER-R-08` | Lands in the LibKa0s repo. A local patch under `libs/` is reverted by the next whole-folder re-vendor and comes back as a regression with no cause in this addon's history. |
| `ABSORBTRACKER-R-13` | One frozen doc bundle with mixed line endings. An audit matter (`line-endings-§2`), not a review one; recorded as an observation. |

---

## Changes by theme

### Theme A — the perf record says only what the run observed

**What changed.** A coalesced repaint pass now tells each bar-paint which bucket it is running
inside, so `/at perf report` and every JSON dump record `paintBar`'s containment in `repaintPass` as
something the capture *saw* rather than something the descriptor merely claimed.

**Why it mattered.** `paintBar`'s total genuinely sits inside `repaintPass`'s, so a reader who adds
them double-counts the paint cost. The report's "do not sum" warning is generated from the observed
nesting, and for the one nesting where the warning was load-bearing it was reporting a bare
declaration. Both `core/PerfSetup.lua:51` and `docs/performance.md:28-31` asserted the opposite in
writing, so the record was not just incomplete — it was contradicted by the source's own comments.
The suite had a case for the nesting that worked (`visibility` inside `appearance`) and none for the
one that did not.

- **Findings covered:** `ABSORBTRACKER-R-01`
- **Changes implemented:** `C-01`
- **Files touched:** `modules/Display.lua`, `modules/Timer.lua`, `tests/test_perf.lua`,
  `docs/test-cases.md`, `README.md`

### Theme B — one write path, and it is the logged one

**What changed.** *Copy styling from Player* now writes each of the nineteen appearance keys and the
mirror flag through `NS.SetByPath`, the same seam a panel widget and a `/at set` already use. The
button's hand-written `APPEARANCE` publish is gone, because each copied row now fires its own.

**Why it mattered.** `debug-logging-§10` is a MUST: every settings mutation is logged once, at the
single write seam, as `[Set] <path> = <value>`. A copy mutated twenty settings and logged none of
them, so a user debugging why their focus bar changed found a gap in the log exactly where the change
happened. Each row's `onChange` was skipped too; nothing was visibly broken only because the button
compensated by publishing the restyle by hand — a compensation that would have held right up until
the first copied row grew an `onChange` of its own.

- **Findings covered:** `ABSORBTRACKER-R-02`
- **Changes implemented:** `C-02`
- **Files touched:** `core/Units.lua`, `settings/UnitPanel.lua`, `tests/` (new case),
  `tests/perf.lua` (new `copyStyling` scenario), `docs/test-cases.md`, `README.md`

### Theme C — the settings pages use the library's render seam

**What changed.** The General, Appearance and Profiles sub-pages moved from private
`ctx.panel:SetScript("OnShow", …)` handlers onto `Helpers.SetRenderer`, the registry
`LibKa0s-Options-1.0` uses for its own landing page.

**Why it mattered.** Two things hang off that seam and nothing else. The first is the combat guard on
the path Blizzard's own AddOns sidebar takes, which bypasses the panel-open guard entirely — the
library's source says so in as many words. Before this change, `/at config` and the landing page
refused during combat while Esc → Options → *Appearance* rendered, which is two behaviors on one
window in one session, and the addon's own source at `core/AbsorbTracker.lua:211-213` asserted the
refusal was universal. The second is `options-ui-§11`'s dirty re-render, a MUST: without it a hidden
page has no way to be marked stale, and `RefreshAllPanels` fell back to running these pages'
refreshers even while they were off screen.

- **Findings covered:** `ABSORBTRACKER-R-04`
- **Changes implemented:** `C-04`
- **Files touched:** `settings/General.lua`, `settings/Appearance.lua`, `settings/Profiles.lua`,
  `settings/OptionsSetup.lua`, `tests/test_optionssetup.lua`, `tests/test_widgets.lua`,
  `docs/test-cases.md`, `README.md`

### Theme D — two guards that had gone slack

**What changed.** The offline runner's dormant-bracket allocation ceiling was re-baselined from 320
bytes to \[NEW\] against today's measured 48.0, with the comment carrying the new figure and the date.
And `throttleWindow` — the one number this addon reads out of SavedVariables without validating it —
gained `NS.GetThrottleWindow`, a clamped reader beside the three that already existed.

**Why it mattered.** The ceiling was written thin on purpose, so that one extra table per repaint
pass would redden it; the repaint path then got roughly 6.5× cheaper and the ceiling did not follow,
leaving 272 bytes of silent headroom in the addon's only automated evidence for
`performance-§2`. The throttle value reaches AceTimer's `if delay < 0.01` comparison, so a stored
string raised inside the repaint arm — once per absorb event, i.e. an error loop on the addon's
highest-frequency path — where every other stored number in the addon already degraded gracefully.

- **Findings covered:** `ABSORBTRACKER-R-03`, `ABSORBTRACKER-R-05`
- **Changes implemented:** `C-03`, `C-05`
- **Files touched:** `tests/perf.lua`, `core/Data.lua`, `modules/Timer.lua`, `tests/test_data.lua`

### Theme E — say true things

**What changed.** `core/Units.lua` stopped saying "fifteen appearance keys" in two places where the
list holds nineteen. `core/AbsorbTracker.lua:69` stopped citing a `CreateOptionsPanel` re-entrancy
hazard the library has since taken ownership of. `migrateAllProfiles` became the one-line call to
`forEachProfile` it always was, instead of a hand-copy of it down to the comment. The update-throttle
slider and the debug-console checkbox stopped firing a full three-bar restyle they have no stake in.
`NS.PartitionUnitRows` — a published function with no production caller, kept alive by one green
test — was deleted along with its case and its three doc entries.

**Why it mattered.** None of these breaks anything. Collectively they are the difference between a
codebase whose comments can be trusted on sight and one where every claim has to be re-verified
against the code — which, in a repo whose comments carry this much design reasoning, is most of what
they are for.

- **Findings covered:** `ABSORBTRACKER-R-07`, `-09`, `-10`, `-11`, `-12`
- **Changes implemented:** `C-06`, `C-07`
- **Files touched:** `core/Units.lua`, `core/AbsorbTracker.lua`, `core/Database.lua`,
  `settings/General.lua`, `settings/Schema.lua`, `tests/test_schema.lua`, `docs/schema.md`,
  `docs/module-map.md`, `docs/ARCHITECTURE.md`, `docs/test-cases.md`, `README.md`

---

## API / behavior changes

| Change | Detail |
|---|---|
| **New internal function** | `NS.GetThrottleWindow()` in `core/Data.lua` — the fourth clamped SavedVariables reader, beside `GetMasterAlpha` / `GetMasterScale` / `GetBarAlpha`. |
| **Signature change** | `NS.UpdateAbsorbBar(unit)` → `NS.UpdateAbsorbBar(unit, parentBucket)`. The second parameter is optional and nil on every call path except `doRepaint`. Not a public API — `public-api` scope is unchanged. |
| **Removed** | `NS.PartitionUnitRows(rows)`. It had no production caller; `settings/UnitPanel.lua`'s local `partitionTabs` supersedes it on a different axis. |
| **Slash commands** | None added, renamed or removed. `NS.COMMANDS` and the README's `/at` verbs remain in exact bidirectional agreement — 17 each. |
| **Debug output** | New: twenty `[Set] units.<unit>.<key> = <value>` lines on a *Copy styling from Player* click, where there were none. Gone: nothing. |
| **Settings panel** | The General, Appearance and Profiles sub-pages now **refuse to render during combat**, matching `/at config` and the landing page. This is a user-visible behavior change and it is the intended one. |
| **Locale keys** | None added or renamed. The addon still ships English-only with strings hardcoded, per `locales/enUS.lua:8-12`. |
| **New defaults / removed defaults** | None. |

---

## Saved-variable / migration notes

**No schema bump.** The account-wide ladder stays at **v5** and the per-profile stamp at **v3**. No
stored key changed shape, moved, or was added. `NS.GetThrottleWindow`'s clamp is on the **read**
path only — a hand-edited out-of-range value stays on disk exactly as written and `/at get
throttleWindow` still echoes it, which is deliberate: the clamp exists to keep the addon working, not
to silently rewrite the player's file.

Existing profiles need nothing. No `/at reset` is required and none should be recommended.

The `migrateAllProfiles` → `forEachProfile` collapse is behavior-identical and was verified by
diffing the `[Migrate]` console output over a manufactured pre-v3 profile before and after
(`03_SMOKE_TESTS.md` C-06/C-07, step 2). A changed migration count there would have been a blocker,
not a nit.

---

## Deprecated-API migrations

**None.** The sweep found no deprecated or removed API anywhere in the addon's own files:
`C_AddOns.GetAddOnMetadata` is reached through the `LibKa0s-Env` seam with the deprecated global as a
documented fallback rung (`core/EnvSetup.lua:65-74`), `BackdropTemplate` is passed at
`modules/Bar.lua:88`, and the modern `Settings.RegisterCanvasLayout(Sub)category` path is used
throughout. Nothing to table.

---

## Performance impact

> Fill from the frozen bundle written by `03_SMOKE_TESTS.md`'s perf capture. Every number below must
> name the record it came from; delete any row that has no record behind it rather than estimating.

**Offline scenarios** — `lua tests/perf.lua`, before (2026-09-07 review baseline) and after:

| Scenario | Before (bytes/iter) | After | Before (api/iter) | After |
|---|---|---|---|---|
| `absorbEvent` | 0.0 | \[ \] | 0.0 | \[ \] |
| `paintPass` | 48.0 | \[ \] | 12.0 | \[ \] |
| `appearancePass` | 384.5 | \[ \] | 48.0 | \[ \] |
| `settingsRead` | 0.0 | \[ \] | 0.0 | \[ \] |
| `probeOverheadOff` | 48.0 | \[ \] | 12.0 | \[ \] |
| `probeOverheadOn` | 48.3 | \[ \] | 12.0 | \[ \] |
| `copyStyling` (new) | — | \[ \] | — | \[ \] |

`C-01` should move none of these: the third argument is evaluated inside the already-gated `if t0`
region, so a dormant pass allocates nothing extra. If `probeOverheadOff` moves at all, that is the
finding.

**In-game bucket figures** — from `docs/perf-analysis/<new stamp>/dump.json`, against
`docs/perf-analysis/20260807-125002/dump.json`:

| Bucket | 2026-08-07 | New capture | Note |
|---|---|---|---|
| `absorbEvent` | 86 calls / 4.5313 ms | \[ \] | unchanged path |
| `repaintPass` | 72 calls / 4.2879 ms | \[ \] | unchanged path |
| `paintBar` | 143 calls / 2.4014 ms, `within` only | \[ \] | **must now also carry `observedWithin`** |
| `visibility` | 21 calls / 0.2388 ms | \[ \] | unchanged path |
| `appearance` | absent | \[ \] | present, at ~20 calls, in the capture that clicks *Copy styling* |

**Do not quote the frame-time delta.** The 2026-08-07 capture records `deltaMsPerFrame: -0.1777`
against arms of 16.56 and 16.74 ms/frame — below the harness's own run-to-run spread and therefore
**unresolved**. It supports no claim in either direction.

---

## Test and complexity movement

- **Pass count before:** 547 (`lua5.1 tests/run.lua`, 2026-09-07 — `547 passed, 0 failed, 0 skipped`).
- **Pass count after:** \[ \] — expected around 552: `C-01` +2, `C-02` +1, `C-04` +3, `C-05` +3,
  `C-07` −1, plus whatever `C-U1`'s cleanup removes if M0 landed in the same cycle.
- **`docs/test-cases.md` and the README `[Tests]` badge moved in the same change as the count**, at
  the end of each milestone. They were verified to agree with the runner's own total at checkpoint 5.
- **`tests/perf.lua`'s `copyStyling` scenario is a measurement, not a test case.** It is **not**
  counted in the inventory or the badge (`testing-§7`).
- **Complexity movement to confirm at the next release regeneration** (`ABSORBTRACKER-R-06`, not
  regenerated here):
  - max CCN **14 → 15**, the new maximum being `NS.ValidateSchema` in `settings/Schema.lua`;
  - `NS.PartitionUnitRows` (CCN 11) leaves the report entirely, if `C-07` landed;
  - `./settings/Bar.lua`, `./settings/Border.lua`, `./settings/Font.lua` finally leave
    `complexity.txt` — they have not existed since the settings revamp and the newest committed
    bundle (`20260825-103352`, git `bebb43f`) still lists them;
  - NLOC **7997 → ~8900**, functions **1126 → ~1253**.
- `luacheck .` was 0/0 before and must stay 0/0.

---

## Known follow-ups

| Item | Rationale for deferring |
|---|---|
| `ABSORBTRACKER-R-08` — the `OptionsCompose` media-row defect | Lands in the LibKa0s repo, not here. This addon works around it on its own rows and its suite pins the workaround, so nothing here is broken while it waits. The workaround and its cases are deleted **in the re-vendor commit**, not before. |
| The sibling sweep for `R-08` | Any Ka0s addon adopting `BarGroup`/`BorderGroup`/`FontGroup` **without** a `fixMediaValues` equivalent is shipping three empty dropdowns today. Worth a one-line grep across the collection; out of scope for a single-repo review. |
| `ABSORBTRACKER-R-06` regeneration | Belongs to `/wow-addon:bump-version` at release. Predicted figures are recorded so the regeneration can be checked rather than merely accepted. |
| `ABSORBTRACKER-R-13` — one mixed-line-ending doc | Frozen bundle, not shipped to the client. The authoritative straggler count and its fix belong to `/wow-addon:standards-audit`. |
| Localization | `locales/enUS.lua` carries the `NS.L` seam with the key-returning metatable and states plainly that strings are still hardcoded English. That is a declared position, not drift, and wrapping them is a project of its own. |
| `NS.Icon` | Published with no call site, and `core/MediaSetup.lua:175-190` says so at length and invites the dead-export sweep to take it. Left alone this cycle because that file's own comment argues for keeping it as the other half of a two-function seam whose font half *is* used. Revisit when the addon draws its first control of its own. |

---

## Verification evidence

- Completed checklist with its sign-off table filled in:
  `docs/reviews/2026-09-07/03_SMOKE_TESTS.md`
- Frozen in-game perf capture: `docs/perf-analysis/<stamp>/` — `report.md`, `dump.json`,
  `ANALYSIS.md`
- Commit range / PR: \[ \]
- Review bundle this work derives from: `docs/reviews/2026-09-07/`

---

## Suggested commit message / PR description

```
fix(absorbtracker): make the records true — perf nesting, the write seam, the render gate

A review pass over a repo that was already green everywhere it could be measured. No
crashes, no taint, no deprecated APIs. What this fixes is the class of defect that never
goes red: places where the addon's own records said something the code did not do.

  * paintBar declared `within = "repaintPass"` and core/PerfSetup.lua promised every
    nested bracket supplies its parent to Perf.Note. It did not, so the report named the
    one genuinely load-bearing nesting as declared-only -- and a reader summing the two
    totals double-counts.                                     [ABSORBTRACKER-R-01]

  * `Copy styling from Player` wrote twenty schema-row paths straight into the profile
    table, so debug-logging-§10's mandated [Set] line was emitted for none of them and no
    row's onChange fired. It now goes through NS.SetByPath.   [ABSORBTRACKER-R-02]

  * The offline runner's dormant-bracket ceiling sat at 320 bytes against a path that now
    allocates 48 -- 272 bytes of silent headroom in the addon's only automated evidence
    that a dormant bracket is free.                           [ABSORBTRACKER-R-03]

  * The General, Appearance and Profiles sub-pages rendered during combat while /at config
    and the landing page refused, because a private OnShow gets neither the library's
    sidebar-path combat guard nor options-ui-§11's dirty re-render. All three now go
    through Helpers.SetRenderer.                              [ABSORBTRACKER-R-04]

  * throttleWindow was the one stored number reaching a library comparison unvalidated;
    a hand-edited string raised inside the repaint arm, once per absorb event.
                                                              [ABSORBTRACKER-R-05]

Plus a small-truths sweep: two comments naming the wrong key count, one citing a
re-entrancy hazard the library now owns, a hand-copied profile walk collapsed onto the
function it duplicates, two rows that fired a three-bar restyle they have no stake in,
and one dead export deleted with its test and its three doc entries.
                                       [ABSORBTRACKER-R-07, -09, -10, -11, -12]

Routed upstream, NOT patched here: LibKa0s OptionsCompose minor 2 declares every
media-backed composed row as a closure returning a closure, so the flow engine's enumList
gets a function where it needs a table and renders an empty dropdown with nothing saying
why. This addon corrects it on its own rows; the fix is an OptionsCompose minor bump and
a re-vendor.                                                  [ABSORBTRACKER-R-08]

Tests 547 -> [N]; docs/test-cases.md and the README badge move with them.
lint 0/0. Offline perf green. Review bundle: docs/reviews/2026-09-07/.
```
