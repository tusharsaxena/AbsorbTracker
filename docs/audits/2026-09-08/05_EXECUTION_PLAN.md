# 05 — Execution Plan

Hand-off to the separate remediation engagement. Eight entries — **7 roots + 1 dependent** — every
one graded **Low**, six of them MUST failures. The figures here are the ones in `02_DEVIATIONS.md`;
the two documents are read as one and do not disagree.

**Gate on every step:** `luacheck .` at 0/0 and `lua tests/run.lua` all-green before the commit
(`testing-§4`). Today's baseline is **0/0 over 54 files** and **562 passed, 0 failed, 0 skipped**, so
any step that moves either number owes an explanation in its commit body.

**No release is implied.** None of this is user-visible, the TOC version stays at `1.9.0`, the README
`## What's new` does not roll, and neither badge moves.

---

## Sprint 1 — the one atomic change (1 commit)

### Step 1 · `AT-62` + `AT-63` — hollow the composers and re-pin the suite

- [ ] `settings/OptionsSetup.lua` — replace the five composer bodies (`:225`, `:236`, `:247`, `:261`,
      `:276`) with the hollow form; `MasterControls` keeps its second return.
- [ ] Delete `composeBlock` (`:194`) and `ORDER_STEP` (`:190`).
- [ ] Keep `LSMValues` (`:173`), `MASTER_GROUP` (`:274`) and `RestoreAllDefaults` (`:303`) untouched.
- [ ] Rewrite the block comment at `:175-189` to carry `options-ui-§1`'s ruling and this addon's
      fall-together evidence, not the argument against it.
- [ ] `tests/test_perf.lua` — replace the equality assertion at `:498` with the three figures §1 asks
      for: fully-loaded count, library-absent count, and the difference as a **named** figure
      attributed per composer. Invert the path-set half so the live-only set must be exactly the
      composed paths.
- [ ] `tests/test_optionssetup.lua` — keep the member-existence half at `:90-105`; drop the row-shape
      assertions at `:108-117`; invert the `-- red under:` comment at `:102`.
- [ ] Regenerate `docs/test-cases.md` if any case name changed, and update the README `[tests]` badge
      in the same commit (`testing-§5`).

**Done when:** the suite is green, the named gap figure appears in `tests/test_perf.lua`, and
`grep -n 'composeBlock' settings/OptionsSetup.lua` returns nothing.

**Must not be split.** Hollowing without the cases reddens the tree; the cases without hollowing
assert a shape that does not exist. One commit.

---

## Sprint 2 — mechanical, independent, parallelizable (4 commits)

### Step 2 · `AT-64` + `AT-65` — annotate the two load-bearing TOC positions

- [ ] `AbsorbTracker.toc` — add the LOAD-BEARING comment above `core\PerfSetup.lua` (`:47`) naming
      `NS.Perf` and its three file-scope consumers.
- [ ] Add the LOAD-BEARING comment above `core\Units.lua` (`:49`) naming `NS.Units.DeepCopy` and
      `core/Database.lua`.
- [ ] *(optional, not part of the MUST)* two `tests/test_loadorder.lua` cases mirroring the existing
      *"core/MediaSetup.lua loads before core/Constants.lua"*, so the constraints are checked and not
      only written.

**Done when:** every load-bearing position in the `# Core` block carries a comment naming what
resolves. Two positions, one commit — they are two rows because `toc-file-§5` grades per position,
not because they are two pieces of work.

### Step 3 · `AT-66` — adopt `localization-§5`'s published lists

- [ ] `tests/test_docs.lua` — delete the 244-entry map at `:192`; paste `BRITISH` (91) and `ALLOWED`
      (30) from `localization-§5`, whole, under a comment saying they were copied whole.
- [ ] Switch the scan at `:338` to the two-stage form: delimit on non-letters → drop `ALLOWED` as
      **whole words** → run `BRITISH` as **substrings**, case-insensitively.
- [ ] Name the four exclusion classes file-by-file / directory-by-directory in `ownFiles()` (`:308`)
      rather than leaving frozen bundles excluded by an unstated glob; add `docs/smoke-tests.md`'s
      quoted-external-text line to the exception handling, or exclude that document explicitly.
- [ ] Run it and read every new hit before suppressing any of them — the substring form is
      deliberately wider than the map it replaces.

**Done when:** the gate's two tables are byte-identical to §5's, and the case is green.

### Step 4 · `AT-67` — the fifth stub-surface parity case

- [ ] `tests/test_surface_parity.lua` — add the `Perf` case through `T.assertSurfaceParity`, degraded
      arm from `tests/degraded_env.lua`, with the grep named in the comment.
- [ ] `tests/run.lua` — extend the `Kit.setSurfaceSource` registration to the `Perf` instance.
- [ ] Correct the file header's *"four LibKa0s seams"* to five, and state in the case's comment why
      `Env` and `Media` are out of scope (no stub table, so no member set to diverge).
- [ ] Regenerate `docs/test-cases.md` and the README badge.

**Done when:** five parity cases, and the new one fails if a member is deleted from
`core/PerfSetup.lua:22-29`.

### Step 5 · `AT-68` — name symbols in the register

- [ ] `docs/ARCHITECTURE.md:335` — replace ``(`core/AbsorbTracker.lua:168`, `:231`)`` with
      `addon:OnAbsorbChanged` and `addon:OnLeaveCombat`.
- [ ] Re-read `:333-336` and confirm no other row cites a line number. (This run did; nothing else
      does.)

**Done when:** the register cites no line number anywhere.

---

## Sprint 3 — blocked upstream, not scheduled here

### Step 6 · `AT-60` — the wrapped-strip geometry case

- [ ] **Upstream first, in `LibKa0s`:** `testkit/mock_base.lua` answers a real per-atlas `GetHeight`
      instead of 0. Until then the case cannot fail and writing it is `testing-§12`'s failure mode.
- [ ] Then, here: render each page once per tab selection; assert `ctx.chromeHeight` and every row's
      y offset are identical across all selections; record the mutation it dies under.

This is `M1-LK-08` in the collection plan, deferred there deliberately. It wants writing once in the
kit's shape and copying to the siblings, not re-deriving nine times.

---

## Sequencing summary

| Order | Step | IDs | Files | Blocking? |
|---|---|---|---|---|
| 1 | Hollow composers + re-pin suite | `AT-62`, `AT-63` | `settings/OptionsSetup.lua`, `tests/test_perf.lua`, `tests/test_optionssetup.lua` | atomic — one commit |
| 2 | TOC annotations | `AT-64`, `AT-65` | `AbsorbTracker.toc` | independent |
| 3 | Spelling gate lists | `AT-66` | `tests/test_docs.lua` | independent |
| 4 | Perf parity case | `AT-67` | `tests/test_surface_parity.lua`, `tests/run.lua` | independent |
| 5 | Register symbols | `AT-68` | `docs/ARCHITECTURE.md` | independent |
| 6 | Strip geometry case | `AT-60` | `LibKa0s/testkit/`, then `tests/test_widgets.lua` | **blocked on kit 16** |

Steps 2–5 touch disjoint files and can run in any order or in parallel. Step 1 touches
`tests/test_perf.lua`, which no other step touches. Step 4 touches `tests/run.lua`, which no other
step touches.

---

## Not scheduled, deliberately

- **`AT-Info-1`** — `docs/ARCHITECTURE.md` at 454 lines. Every spillable mandated section is well
  under 60; the excess is the register, which the standard makes this file's single home. Nothing to
  do, and moving the register would break `documentation-§3`.
- **`AT-Info-2`** — issue #25 is open over five `libs/LibStub/` files that no longer exist. Closing it
  is issue-store housekeeping (`/wow-addon:issue-triage`), not a standards fix, and it is not this
  plan's to do.
- **`AT-Info-3`** — the newest run bundle trails HEAD by four commits. `automated-tests`' checkpoint
  is **release**, no release has been cut, and the next run regenerates it. Do **not** hand-edit
  `RESULTS.md` or a frozen bundle to close the gap; that is anti-pattern #51's worse half.
- **The four ratified register rows.** All four survive their three checks and are accepted, not
  re-filed. `AT-68` is about one row's citation, not its decision.
