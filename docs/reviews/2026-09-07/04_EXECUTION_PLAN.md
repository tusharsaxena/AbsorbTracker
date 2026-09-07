# AbsorbTracker — execution plan, 2026-09-07

Implements `02_PROPOSED_CHANGES.md`. Five milestones. **M0 is a cross-repo handoff and does not touch
this repo's source at all**; M1-M3 are local; M4 is the release checkpoint.

Nothing in this plan edits a path under `libs/` or `tests/_kit/`.

---

## Milestone M0 — the upstream defect

**Done when:** `OptionsCompose.lua` minor 3 is tagged in the LibKa0s repo, the whole `LibKa0s/`
folder has been re-vendored into this addon as its own commit, `CLAUDE.md`'s provenance line names
the new tag, and `lua tests/run.lua` is green — including
`tests/test_vendor_sync.lua`'s two byte-identity cases, which are what prove the re-vendor was whole
rather than partial.

| Task | Owner-agent | Implements | Files touched | Repo |
|---|---|---|---|---|
| M0-T1 | `libka0s-maintainer` | `ABSORBTRACKER-R-08` / `C-U1` | `LibKa0s/OptionsCompose.lua` (drop the outer closure at lines 231, 275, 304), `CHANGELOG.md`, the file's `COMPOSE_MINOR` and `lib.MODULES` entry | **LibKa0s** |
| M0-T2 | `libka0s-maintainer` | `C-U1` | LibKa0s' own suites — add a case that a composed media row's `values` yields a **table** | **LibKa0s** |
| M0-T3 | `wow-addon-vendor` | `C-U1` | `libs/LibKa0s/**` (whole-folder copy), `tests/_kit/**` if its revision moved, `CLAUDE.md` provenance line | **AbsorbTracker** |
| M0-T4 | `lua-refactorer` | `C-U1` cleanup | `settings/Appearance.lua` (delete `fixMediaValues` + its 3 call sites), `tests/test_schema.lua` (its pinning cases), `docs/test-cases.md`, `README.md` badge | **AbsorbTracker** |

**Sequencing note.** M0-T3 and M0-T4 are the *same* commit boundary as far as green-ness goes but
should be **two commits**: the re-vendor is a pure file copy with no addon logic in it, and mixing a
logic deletion into it is exactly what makes a future bisect over a re-vendor uninformative.

**M0 can be deferred entirely.** This addon works around the defect and its suite pins the
workaround, so M0 blocks nothing below. It is first only because leaving a known-open upstream
defect unrouted is how it gets rediscovered in the next sibling audit.

---

## Milestone M1 — truth: perf record and write path

**Done when:** `lua tests/run.lua` green with the new cases; `lua tests/perf.lua` green; an in-client
`/at perf dump` shows `observedWithin` on the `paintBar` bucket; the debug console shows twenty
`[Set]` lines on a *Copy styling from Player* click.

| Task | Owner-agent | Implements | Files touched | Parallel? |
|---|---|---|---|---|
| M1-T1 | `lua-refactorer` | `C-01` / `ABSORBTRACKER-R-01` | `modules/Display.lua`, `modules/Timer.lua` | **yes** (disjoint from M1-T2) |
| M1-T2 | `lua-refactorer` | `C-02` / `ABSORBTRACKER-R-02` | `core/Units.lua`, `settings/UnitPanel.lua` | **yes** |
| M1-T3 | `test-author` | cases for `C-01` | `tests/test_perf.lua` | after M1-T1 |
| M1-T4 | `test-author` | cases for `C-02` | `tests/test_helpers.lua` or `tests/test_data.lua`, plus a `copyStyling` **scenario** in `tests/perf.lua` | after M1-T2 |
| M1-T5 | `docs-sync` | inventory + badge | `docs/test-cases.md`, `README.md` | after M1-T3 and M1-T4 |

**M1-T3 must write a falsifiable case.** The existing `tests/test_perf.lua:68-88` is the template:
assert the positive (`observedWithin == "repaintPass"`) **and** carry a `-- red under:` comment
naming the mutation that reddens it (delete the third argument at `modules/Display.lua:375`). Add the
negative twin — a standalone `NS.UpdateAbsorbBar("player")` claims **no** parent — with its own
`-- red under:` naming the mutation (hard-code `"repaintPass"` at the `Note`).

**M1-T4's scenario is not a test case** (`testing-§7`). It must not be counted in
`docs/test-cases.md` or in the README badge. M1-T5 owns keeping that straight.

---

## Milestone M2 — the options render seam

**Done when:** all three sub-pages go through `Helpers.SetRenderer`; the in-client combat refusal in
`03_SMOKE_TESTS.md` C-04 passes on **all three** pages; the Defaults button appears exactly once per
page after six page switches (C-04b); C-04c shows no stale value and no stacked widget.

| Task | Owner-agent | Implements | Files touched | Parallel? |
|---|---|---|---|---|
| M2-T1 | `options-ui-migrator` | `C-04` / `ABSORBTRACKER-R-04` | `settings/General.lua`, `settings/Appearance.lua`, `settings/Profiles.lua` | no — one task, three files that change identically |
| M2-T2 | `options-ui-migrator` | `C-04` stub | `settings/OptionsSetup.lua` (add `SetRenderer` to the no-op list at :318-337) | serialize behind M2-T1 |
| M2-T3 | `test-author` | `C-04` | `tests/test_optionssetup.lua` (the stub's member set is **pinned** there — adding a member changes what that case asserts), `tests/test_widgets.lua` | after M2-T2 |
| M2-T4 | `docs-sync` | inventory + badge | `docs/test-cases.md`, `README.md` | after M2-T3 |

**This is the milestone to be careful in.** Three reasons, all in `02_PROPOSED_CHANGES.md` `C-04`'s
risk note: the Defaults-button double-build, Blizzard sidebar paths the headless mock does not model,
and `Profiles.lua`'s self-skip that `tests/run.lua` depends on. Nothing here is provable headless
beyond "it still loads and still renders" — the guard itself needs a client.

**Concurrency callout.** M2-T2 touches `settings/OptionsSetup.lua`, whose degradation stub member set
is asserted by `tests/test_optionssetup.lua`. That file is also read by
`tests/test_surface_parity.lua`'s Options-stub parity case. Both suites must be re-run after M2-T2,
not just the one that looks related.

---

## Milestone M3 — guards, dead code and small truths

**Done when:** `lua tests/perf.lua` green three runs in a row with the new ceiling; a junk
`throttleWindow` produces no Lua error in-client; `NS.PartitionUnitRows` is gone from source, test,
three docs and the inventory; `lua tests/run.lua` green and the count **down** by one from `C-07`
net of the additions.

| Task | Owner-agent | Implements | Files touched | Parallel? |
|---|---|---|---|---|
| M3-T1 | `perf-baseline` | `C-03` / `ABSORBTRACKER-R-03` | `tests/perf.lua` | **yes** |
| M3-T2 | `lua-refactorer` | `C-05` / `ABSORBTRACKER-R-05` | `core/Data.lua`, `modules/Timer.lua` | **serialize behind M1-T1** — both touch `modules/Timer.lua` |
| M3-T3 | `lua-refactorer` | `C-06` / `-07`, `-09`, `-11`, `-12` | `core/Units.lua`, `core/AbsorbTracker.lua`, `core/Database.lua`, `settings/General.lua` | **serialize behind M1-T2** (`core/Units.lua`) and **behind M2-T1** (`settings/General.lua`) |
| M3-T4 | `lua-refactorer` | `C-07` / `ABSORBTRACKER-R-10` | `settings/Schema.lua`, `tests/test_schema.lua`, `docs/schema.md`, `docs/module-map.md`, `docs/ARCHITECTURE.md` | **yes** — disjoint from everything above |
| M3-T5 | `test-author` | `C-05` | `tests/test_data.lua` | after M3-T2 |
| M3-T6 | `docs-sync` | inventory + badge | `docs/test-cases.md`, `README.md` | last in M3 |

**M3-T1 has an acceptance rule, not just a diff:** run `lua tests/perf.lua` **three times** and record
all three `probeOverheadOff` figures in the commit message. The new ceiling must sit above the
highest of the three with the thin headroom the comment promises, and the comment must carry the
date and the reason for the fall. A ceiling re-baselined from a single sample is the same defect in a
new place.

---

## Milestone M4 — release checkpoint

**Done when:** `/wow-addon:bump-version` has regenerated `docs/automated-tests/` into a new dated
bundle and `RESULTS.md`, and its numbers match `01_FINDINGS.md`'s predicted drift.

| Task | Owner-agent | Implements | Files touched |
|---|---|---|---|
| M4-T1 | `release` | `C-08` / `ABSORBTRACKER-R-06` | `docs/automated-tests/**` — **generated, never hand-written** |

**Verify against the prediction in `02_PROPOSED_CHANGES.md` `C-08`:** tests ~552, NLOC ~8900,
functions ~1253, max CCN 15 at `NS.ValidateSchema`, the three deleted `settings/` files gone from
`complexity.txt`, and `NS.PartitionUnitRows` gone if `C-07` landed. A number that misses the
prediction is worth a look before the tag, not after.

**Do not** run `lizard` into the repo before this point, do not hand-edit any figure, and do not gate
a commit on complexity — `performance-§10` names that as an anti-pattern rather than a remedy.

---

## Critical path and concurrency map

```
M0 (upstream) ──────────── independent of everything; may run last
                             │
M1-T1 ─┐                     │
M1-T2 ─┼─ parallel ─→ M1-T3/T4 ─→ M1-T5
       │
       └─→ M3-T2 (modules/Timer.lua conflict with M1-T1)
       └─→ M3-T3 (core/Units.lua conflict with M1-T2)

M2-T1 ─→ M2-T2 ─→ M2-T3 ─→ M2-T4
   └────────────────────────→ M3-T3 (settings/General.lua conflict with M2-T1)

M3-T1 ── parallel with everything (tests/perf.lua alone)
M3-T4 ── parallel with everything (settings/Schema.lua alone)
```

**Files touched by more than one task — these MUST serialize:**

| File | Tasks | Order |
|---|---|---|
| `modules/Timer.lua` | M1-T1, M3-T2 | M1-T1 first |
| `core/Units.lua` | M1-T2, M3-T3 | M1-T2 first |
| `settings/General.lua` | M2-T1, M3-T3 | M2-T1 first |
| `docs/test-cases.md`, `README.md` | M0-T4, M1-T5, M2-T4, M3-T6 | one at the end of each milestone; **never two open at once** |
| `tests/perf.lua` | M1-T4 (scenario), M3-T1 (ceiling) | either order, but not concurrently |

**Genuinely parallelizable:** M1-T1 ∥ M1-T2; M3-T1 ∥ M3-T4 ∥ anything.

---

## Checkpoints (a human looks before the next milestone opens)

1. **After M0-T3, before M0-T4.** Confirm `tests/test_vendor_sync.lua` is green and `0 skipped`
   before deleting the workaround. A red or skipped vendor-sync case means the re-vendor was partial,
   and deleting the workaround on top of a partial copy ships three empty dropdowns.
2. **After M1, before M2.** Run `03_SMOKE_TESTS.md` C-01 and C-02 in-client. `C-02`'s twenty-publish
   cost is the decision point for mitigation (2) — take it here, with a number, not later by feel.
3. **After M2-T1, before M2-T2.** Run C-04b (Defaults button) **first**, before anything else in M2.
   It is the one failure mode that is invisible in a suite and obvious in a screenshot, and it is
   cheaper to catch with one page converted than with three.
4. **After M2, before M3.** Full `03_SMOKE_TESTS.md` regression suite R1-R13. M2 is the milestone
   that can break the settings window; everything after it assumes the window works.
5. **After M3, before M4.** Three runs of `lua tests/perf.lua`, `luacheck .`, `lua tests/run.lua`,
   and a confirmation that `docs/test-cases.md`, the README badge and the runner's own total all
   report the same number.
6. **Before M4.** The in-client perf capture from `03_SMOKE_TESTS.md`, frozen as its own
   `docs/perf-analysis/<stamp>/` bundle. It is the evidence for `C-01`'s and `C-02`'s claims, and
   `05_FINAL_SUMMARY.md`'s performance section stays empty without it.

---

## Commit strategy

One commit per task, except where noted. Suggested messages:

```
fix(perf): paintBar reports the containment the run observed, not just the declared one

The descriptor declares `within = "repaintPass"` and core/PerfSetup.lua:51 promises
every nested bracket supplies its parent to Perf.Note. paintBar did not: the bracket
at modules/Display.lua:375 passed two arguments, so observedWithin stayed nil and the
report named the one genuinely load-bearing nesting as declared-only. doRepaint now
hands its bucket down, the same way UpdateBarAppearance already hands one to
ApplyVisibility.

Covers ABSORBTRACKER-R-01. Adds 2 cases (547 -> 549); inventory and badge move with it.
```

```
fix(settings): Copy styling from Player writes through the single seam

Twenty schema-row paths were assigned straight into the profile table, so
debug-logging-§10's mandated [Set] line was never emitted for any of them and no row's
onChange fired -- the button published APPEARANCE by hand to compensate, which held
only for as long as no copied row grew an onChange of its own.

Covers ABSORBTRACKER-R-02.
```

```
refactor(settings): the three sub-pages render through Helpers.SetRenderer

A private OnShow gets neither the combat guard on the Blizzard-sidebar path
(options-ui-§2) nor the dirty re-render (options-ui-§11). The library publishes the
seam and uses it for its own landing page; three hand-rolled copies of a library guard
would be anti-pattern #47.

Covers ABSORBTRACKER-R-04.
```

```
test(perf): re-baseline the dormant-bracket ceiling from 320 to 72 bytes/pass

probeOverheadOff measures 48.0 bytes/iter today; the 320 ceiling was set against a
312.0 baseline that ResolvePath's flat-key fast path has since retired. At 6.7x
headroom the assertion could no longer catch the one extra table per pass it exists
to catch. Three runs: <a>, <b>, <c>.

Covers ABSORBTRACKER-R-03.
```

The `libs/LibKa0s/**` re-vendor is **always its own commit**, with the provenance line, and never
carries an addon logic change.
