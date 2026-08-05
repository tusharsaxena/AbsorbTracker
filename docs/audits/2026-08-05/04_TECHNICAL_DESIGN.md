# 04 — Technical Design

Remediation design for the deviations catalogued in `02_DEVIATIONS.md`. Keyed by deviation ID.
This document designs the change; `05_EXECUTION_PLAN.md` orders it. **Nothing here has been
applied** — the audit is read-only.

Grouping principle: the findings fall into four families with genuinely different risk profiles, and
mixing them in one change would make the risky ones unreviewable.

| Family | IDs | Touches | Risk |
|---|---|---|---|
| **A — records and metadata** | AT-43, AT-42, AT-45, AT-44, AT-46 | git index mode, `CLAUDE.md`, `docs/testing.md`, `docs/automated-tests/README.md`, `.pkgmeta` | none; no Lua changes |
| **B — measurement truth** | AT-47, AT-48 | `core/PerfSetup.lua`, `docs/performance.md` | low; changes what future captures *report*, not what they *measure* |
| **C — behavior** | AT-34, AT-35, AT-49, AT-38 | `settings/Profiles.lua`, `core/CoreSetup.lua` + call sites, `defaults/Profile.lua`, `modules/Display.lua` | real; each needs a test before the change |
| **D — prose sweeps** | AT-36, AT-37, AT-33, AT-40, AT-41, AT-39, AT-50 | comments and `docs/` | none, but AT-36 is 31 sites and should stand alone |

---

## Family A — records and metadata

### AT-43 — make the vendored runner executable

One index-mode change, no file content change:

```sh
git update-index --chmod=+x tests/_kit/run-automated-tests.sh
```

**Design note.** Do **not** re-vendor to fix this and do **not** edit the file — the content is
already byte-correct against the tag (`tests/test_vendor_sync.lua` passes). The bit is repo state,
not file state, so a re-vendor would reintroduce the same loss. The durable fix is to add
`chmod +x tests/_kit/run-automated-tests.sh` to the re-vendor procedure that `docs/testing.md:76-83`
already documents for the `diff -r` pair, so the next `2a50784`-shaped commit carries it.

**Verification.** `git ls-files -s tests/_kit/run-automated-tests.sh` reports `100755`. A stronger
check, and worth adding: `tests/test_vendor_sync.lua` already shells out to `git`, so a third case
asserting the mode is `100755` costs three lines and closes this permanently. Note the case must read
the **index**, not the filesystem — `ls -l` on drvfs reports `0777` for everything and would pass
against a broken repo.

### AT-42 — fix the doc-set count in `CLAUDE.md`

`CLAUDE.md:40` — `Four` → `Five`. One word.

**Design note.** The reason this is worth a deviation rather than a typo fix is the shape: a count
adjacent to its list, where the two disagree. Keep them adjacent when editing — the failure mode the
standard warns about is a bare count that outlives the list it summarizes, and this sentence is
already the mitigated form. `tests/test_docs.lua` is the natural home for a guard: it already reads
repo prose, so a case asserting "`CLAUDE.md` names exactly the five required topic-detail docs, and
the number word before the list matches" would make the next drift fail the suite. That is optional,
not required by the standard.

### AT-45 — state the release gate wherever the commit gate is stated

Three files, and the third is not ours.

**`docs/testing.md` — the primary edit.** Replace the `:57-58` paragraph with both halves:

- Commits are gated on `luacheck .` + `lua tests/run.lua`, unchanged (testing-§4).
- The **tag** is gated on all four suites at `pass` in the release run's `manifest.json`, plus
  `suites.complexity.warnings == 0` — zero functions above CCN 15.
- A `skip` blocks as **NOT EVALUATED**; it is never read as a pass. The one narrow exception is
  `perf` skipped because the addon ships no `tests/perf.lua`, which does not apply here — this addon
  ships one.
- The gate is evaluated by `/wow-addon:bump-version` from the manifest. The runner's exit code is
  deliberately unchanged, because the same script is the commit gate.
- Every failed gate is reported, not just the first.

Then change the `Gates?` column at `:46-47` from `no — recorded only` to
`not a commit gate; gates the release`, and soften `:22` and `:49-52` from "never gating" /
"never fail a run" to "never fail a **run**, and never gate a **commit**" — the scoping word is the
whole fix. `automated-tests-§3`'s own text is "MUST NOT fail a **run**, or block a **commit**", so
the addon's prose becomes a quote rather than a paraphrase.

**`docs/automated-tests/README.md:19-33`** — the same two edits to the same two shapes.

**`docs/automated-tests/RESULTS.md:9-11`** — **do not edit here.** `documentation-§3` says this file
is generated and never hand-edited, and its lead-in comes from the vendored kit. The fix is an
upstream change in LibKa0s's `testkit/`, re-vendored, after which the next run regenerates the
correct text. Raise it there; track it here as blocked-on-upstream. Editing it locally would be the
worse of the two failures `anti-pattern #51` describes — a hand-edited record that reads as
generated.

**Risk.** None to runtime. The one thing to get right is not overcorrecting: the reason perf and
complexity do not gate commits is load-bearing and must survive the edit intact.

### AT-44 — give the warned-functions watch list its table

`docs/automated-tests/RESULTS.md:64-66` gains a header row above the existing prose:

```markdown
### Functions `lizard` warned on

| Function | CCN | Location | Disposition |
|---|---|---|---|
| _(none)_ | — | — | No function in this addon's own source exceeds CCN 15. |
```

then the existing narrative beneath it, unchanged.

**Design note.** Same generated-file question as AT-45, and the same answer with a different
outcome: the *table* is what the kit emits, so the shape fix belongs upstream; the *dispositions* are
per-addon and are legitimately maintained here (`automated-tests-§4` requires a disposition per
entry, which no runner can author). Practically: fix the emitted shape in LibKa0s's `testkit/`,
re-vendor, and let the next run produce it. If that upstream round-trip is slow, the interim local
edit is defensible because the numbers are not being touched — but it must be reverted to the
generated form at the next run, not carried.

### AT-46 — ignore the dev-only dot-folders in `.pkgmeta`

```yaml
ignore:
  - docs
  - tests
  - _dev
  - .superpowers      # SDD specs/plans/reports/diffs — dev-only
  - .claude           # agent session config — dev-only
  - .luacheckrc
  …
```

Zero risk: nothing at runtime reads either path, and neither is referenced from the TOC.

---

## Family B — measurement truth

### AT-47 — remove the two false `within` declarations

`core/PerfSetup.lua:46-47` become:

```lua
{ key = "appearance" },   -- NS.UpdateBarAppearance, per bar — driven by the APPEARANCE bus message
{ key = "visibility" },   -- NS.ApplyVisibility, per bar — driven by the VISIBILITY bus message
```

and the descriptor comment at `:40-41` is corrected: `repaintPass` contains **`paintBar`**, not "the
three per-bar buckets".

**Why this direction and not the other.** The alternative — making the declaration true by moving
appearance and visibility inside the repaint pass — would be a real architectural change to the bus
design for the sake of a label, and would make the coalescing throttle responsible for work it
deliberately does not own. The descriptor is what is wrong.

**Blast radius.** The `within` field is read only by the library's report renderer for the
"(buckets nest: X contains Y — do not sum)" line and by the record schema. Removing it changes the
printed note and the JSON field; it changes no measurement, no bucket key and no call site.

**Records.** Existing bundles and `docs/perf-runs/*.json` are **frozen** and stay exactly as
measured, including the wrong `within` — they record what was believed at the time
(`audit-review-history`). Do not regenerate them.

**Verification.** `tests/test_perf.lua` asserts the descriptor's bucket set; extend it with a case
pinning the nesting map — one parent (`repaintPass`), one child (`paintBar`), and `appearance` /
`visibility` declaring no parent. That case is what stops the next hand-edit re-introducing it.
Write and run it **against the current descriptor first**, confirm it fails, then change the
descriptor.

### AT-48 — reorder the emphasis in `docs/performance.md`

`:242-249` is rewritten so the bucket totals lead as the addon's own cost and the frame-time delta
is presented as the environment measurement it is, with the resolution-floor caveat lifted from
`:258` to sit with the first mention of the delta. The worked example (`:245-249`) is already
correct and is kept verbatim — only the sentence introducing it moves.

Prose only. No numbers change, no capture is invalidated.

---

## Family C — behavior

Each of these changes what the addon does. `performance-§11`'s rule generalizes: pin the behavior
first, then change it.

### AT-34 — make the Profiles page lazy

`settings/Profiles.lua`:

1. In `build`, keep everything up to and including `H.CreatePanel` (`:41-44`). Delete the
   `AceGUI:Create("SimpleGroup")` block (`:51-56`).
2. Capture `AceGUI`, `AceConfigDialog` and `APPNAME` as upvalues (they already are) and add a
   file-local `container` plus a `built` flag.
3. In the existing `OnShow` (`:60-62`): if not `built`, create and anchor the `SimpleGroup` against
   `ctx.body` exactly as today, set `built = true`; then `AceConfigDialog:Open(APPNAME, container)`
   as now.

**Why it is safe.** `AceConfigDialog:Open` already re-runs on every show and reuses the existing
widget tree, so the only behavioral difference is *when* the container is created — which is the
point. `AceConfig:RegisterOptionsTable` stays in `build`: it is a registration, not a widget, and
moving it would change when AceDBOptions snapshots `NS.db`.

**Ordering constraint.** `ctx.body` must exist before the anchor, which it does — `H.CreatePanel`
returns it in `build`, and `OnShow` runs strictly later.

**Test.** `tests/test_widgets.lua` already carries "a page renders nothing until its first OnShow"
and cannot currently reach the Profiles page (the AceDBOptions/AceConfigDialog guard at `:25-27`
returns `nil` under the mock). Extend the mock to satisfy that guard, then let the existing case
cover the page. Run it against the **unmodified** file first and confirm it fails.

### AT-35 — publish `NS.Format`, then convert the call sites

Two steps, and they must be separate commits.

**Step 1 — the seam.** `core/CoreSetup.lua:77` gains `NS.Format = printer.Format`, and the
library-absent branch gains an equivalent that formats then routes through the same fallback
`NS.Print`, so the two paths stay symmetric (which is the property `CLAUDE.md:79-81` says the rest
of the addon codes against). One test asserting `NS.Format` exists and is secret-safe on both paths.

**Step 2 — the call sites.** Mechanical, 18 sites:

- `print(("…%s…"):format(x))` → `NS.Format("…%s…", x)`
- `print("a" .. b)` → `print("a", b)` — `printer.Print` is varargs and stringifies each argument
  through `SafeToString`.
- The pure-indent concatenations (`"  " .. row` at `settings/Slash.lua:33,428`,
  `"  " .. name .. marker` at `:334`) may stay if preferred, **with a comment saying why** — the
  indent is a literal and can never carry a secret. Recording the exemption is what keeps the next
  sweep from re-flagging it.

**Risk.** The output strings are the user-visible contract (`performance-§11` names chat output
explicitly). `tests/test_slashcmds.lua` already asserts many of these lines verbatim — that is the
characterization test, and it must pass **unchanged** across step 2. If a line moves, the conversion
was wrong, not the test.

### AT-49 — default the account-wide stamp to 1

`defaults/Profile.lua:78` — `schemaVersion = 4` → `schemaVersion = 1`, carrying the same
load-bearing comment its per-profile sibling has at `:50-55`, adapted.

**Why this is safe.** The ladder is idempotent by construction: v2 nils a key that is already nil,
v3 is stamp-only (`core/Database.lua:172-174`), and v4's `dropKeyEverywhere("hidden")` returns 0 on a
DB with no `hidden` keys and logs nothing. So a replay from 1 against an already-current database is
a no-op that writes the stamp back to 4.

**What to verify before changing it.** `tests/test_database.lua` must first grow a characterization
case for the current behavior on a **fresh** DB (global materialized by copyDefaults, migrations
run, ladder observed) so the change is measured rather than reasoned about; then a second case that
a fresh install still ends at `schemaVersion == 4` and that no `[Migrate]` line is emitted for a
database that needed nothing. The second case is the one that proves the replay is silent.

**Ordering.** Independent of every other item. Do it in its own commit — a SavedVariables change
buried in a larger diff is exactly the unreviewable shape `performance-§11` forbids.

### AT-38 — preview while unlocked, and an explicit off

Design, not a required change (both are SHOULDs and the user may accept them):

- `modules/Display.lua` — when `locked` is false and no live absorb value is present, paint the
  existing `/at test` placeholder through the same path rather than showing only the unit label
  (`:93-98`). `NS.ShouldShowBar` and `NS.UpdateAbsorbBar` already carry the `testHoldUntil` seam, so
  this is a condition change, not new render code.
- `settings/Slash.lua` — `/at test off` clears `NS.testHoldUntil` and requests a repaint, giving the
  verb the explicit off `preview-mode` asks for. Note the related bug the review raised
  independently: nothing currently repaints at *expiry* either, so idle out of combat the fake value
  persists. Both are the same missing "clear and repaint" path and should be built once.

---

## Family D — prose sweeps

### AT-36 — sweep the retired `§N.M` notation (31 sites)

Mechanical and greppable. Map:

| Retired | Current |
|---|---|
| `§1.4` | `layout-§3` |
| `§2.2` | `toc-file-§2` |
| `§3.1`, `§3.4`, `§3.5` | `library-stack` |
| `§4.1` / `§4.2` / `§4.5` | `architecture-§1` / `architecture-§2` / `architecture-§5` |
| `§5.1` | `savedvariables-§1` |
| `§7.1`, `§7.4` | `slash-commands-§1`, `slash-commands-§4` |
| `§8.x` | `localization-§x` |
| `§9.1` | `events-frames-taint-§1` |
| `§11` | `compat` |
| `§12.2`, `§12.4`, `§12.5` | `debug-logging-§2`, `§4`, `§5` |

Plus the malformed `slash-commands-§:` at `settings/Slash.lua:199` → `slash-commands-§3`.

**Scope boundary — important.** Frozen bundles under `docs/audits/` and `docs/reviews/` are history
and **MUST NOT** be swept. Restrict the sweep to `core/`, `defaults/`, `modules/`, `settings/`,
`locales/`, `tests/`, and the live docs (`docs/ARCHITECTURE.md`, `docs/testing.md`,
`docs/performance.md`, the other topic-detail pages). Verify with
`grep -rnE '§[0-9]+\.[0-9]+' --exclude-dir=audits --exclude-dir=reviews` returning nothing.

Comments only — no code changes — so `luacheck` and the suite are unaffected. Its size is why it
should be its own commit.

### AT-37 — retire four resolved entries from the deviation register

`docs/ARCHITECTURE.md:277-314`: delete or collapse the Wago omission, `AbsorbTrackerPerfDB`, the
`lizard` dependency and the bracket idiom into a short "was a deviation, now standard" note naming
the section that adopted each (`toc-file-§1`, `savedvariables-§4`, `performance-§10`,
`performance-§2`). Keep the still-live entries: per-profile `schemaVersion`, the per-unit event
frames (AT-31), `__lastUnitCtx`, the fixed media. Delete the three "**Pending promotion**"
paragraphs outright — the promotion happened.

### AT-33 — align the 1.9.0 Version History row with What's new

Rewrite `README.md:159`'s Highlights cell to carry the same user-facing highlights as
`README.md:15-24`, leading with the two the row omits entirely: the Target/Focus bars and the
breaking fully-qualified slash paths. Keep the row's player-facing register; it is a summary of
What's new, not a copy of it. Roll both forward together at the next bump — that is the rule that
was missed.

### AT-40 / AT-41 / AT-39 / AT-50 — small

- **AT-40**: `modules/Bar.lua:5-6` — replace `core/DebugLog.lua` with the real readers. If the tests
  are the only remaining consumers of `NS.bar` / `NS.statusBar` / `NS.valueText`, say so, or delete
  the aliases and update the tests.
- **AT-41**: no change. Recorded as an accepted addition.
- **AT-39**: narrow `.luacheckrc:6` to `docs/audits/`, `docs/reviews/`, or keep the superset and
  extend the comment at `:4-5` to say the broadening is deliberate.
- **AT-50**: rename the two `tests/test_vendor_sync.lua` cases (or route them through a skip report)
  so a sibling-absent run is visibly a skip, and correct the header comment at `:107-109`, which
  currently claims something the names do not do. Optionally add the third case asserting the
  sibling's `HEAD` is at the vendored tag, which is the only local way to see upstream having moved.

---

## Cross-cutting: AT-32-F, the badge guard

`AT-32` is closed (badge, inventory and live run all read 470), but it is closed by hand and the
badge remains the one figure in the repo with no mechanical check behind it. The durable fix, carried
forward from the prior run as a follow-up rather than a deviation:

`docs/test-cases.md` already carries a `## Totals` row. A case in `tests/test_docs.lua` — which
already reads repo prose — reads that row and asserts `README.md:7`'s badge shows the same `X/Y`.
Three lines, and the badge can never go stale silently again. Schedule it with Family A.
