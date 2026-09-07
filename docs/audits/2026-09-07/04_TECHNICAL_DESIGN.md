# 04 — Technical design

Remediation design for the ten roots and one dependent catalogued in `02_DEVIATIONS.md`. Keyed to
deviation IDs. Nothing here touches runtime behaviour except `AT-56`, which deletes a hook.

---

## D-1 — Packaging metadata (`AT-51`, `AT-58`)

**Files:** `.pkgmeta`; `libs/LibStub/`.

`.pkgmeta`'s ignore list is a hand-maintained enumeration, and the two entries it lacks are the two
that did not exist when it was written. Add them beside the existing dot-file rows, keeping the
comment style the file already uses for a non-obvious exclusion:

```yaml
ignore:
  - docs
  - tests
  - _dev
  - .luacheckrc
  - .gitattributes
  - .gitignore
  - .claude          # agent tooling: settings + scheduled-task lock, not addon content
  - .superpowers     # SDD briefs, reports and review diffs — 60 files, none loadable
  - "*.bak"
```

For `AT-58` the two options are not equivalent. **Delete** `libs/LibStub/tests/` and
`libs/LibStub/LibStub.toc`: the vendored copy should be exactly what `AbsorbTracker.toc` loads, and an
ignore-list entry leaves five files in the repo that will be re-ignored, re-reviewed and
re-questioned every cycle. `libs/LibStub/LibStub.lua` is untouched. The suite's load-order case
(`tests/test_loadorder.lua`) pins the TOC's library list and will confirm nothing regressed.

**Risk:** none. No file being removed is referenced by the TOC, `.pkgmeta`, the suite or `.luacheckrc`.
**Ordering:** independent of everything else.

## D-2 — `docs/slash-dispatch.md` and the hub spill (`AT-52`)

**Files:** new `docs/slash-dispatch.md`; `docs/ARCHITECTURE.md` (`## Slash Commands` at `:179-224`,
Tier 2 row at `:324`, `## Documentation map` at `:304`).

The trigger fired twice over, so the doc is owed. Its content is already written — it is the 46 lines
`ARCHITECTURE.md` currently holds — plus the part the hub has never carried: the `profile` subtree.
Design:

1. Create `docs/slash-dispatch.md` with (a) the registration seam (`settings/Slash.lua:445-451`,
   `SlashLib:New` with `commands = NS.COMMANDS` passed **in**), (b) the flat verb table generated from
   `NS.COMMANDS`, (c) a section on the one subcommand tree — `PROFILE_VERBS` (`:327`) and
   `PROFILE_HELP` (`:298`), the dispatch at `:386`, and the fall-through when `sub` is unknown, and
   (d) the settings read/write output format for `/at list|get|set|reset`.
2. Reduce `ARCHITECTURE.md`'s `## Slash Commands` to a summary paragraph plus **exactly one** link,
   per `documentation-§3`'s spill rule. This also brings the hub back under 400 lines, closing
   `AT-Info-1` as a side effect.
3. Change the Tier 2 row from `Not applicable` to `Present`, and move it out of the false-trigger
   shape: the Status column becomes `Present`, the Trigger column becomes
   *"17 commands in `NS.COMMANDS`, plus the `/at profile` subcommand tree"*.
4. Add the new file to the `## Documentation map`'s Conditional table — it is already the row that
   names it, so this is the same edit as (3).

**Risk:** the verb table can go stale. Mitigate by generating it the same way the README's
`### Slash commands` table is generated (`wow-addon:sync-docs`), and by extending
`tests/test_docs.lua` with a case asserting the doc names every `NS.COMMANDS` entry — the same shape
the README table already has coverage for.

## D-3 — The automated-test record (`AT-53`, `AT-54`, `AT-61`)

**Files:** `docs/automated-tests/RESULTS.md`; `docs/automated-tests/20260825-103352/ANALYSIS.md`.

`AT-61` is the visible symptom of `AT-53` and closes with it. The record's four standing narrative
sections (`## Test suite`, `## Lint`, `## Perf`, `## Complexity watch list`) are hand-written prose
around a generated table, and the last run recorded the row without refreshing them. Design:

1. **Run the four suites once** — `tests/_kit/run-automated-tests.sh` — so the refresh is written
   against a bundle rather than against the auditor's ad-hoc `lizard` invocation. That new bundle
   supersedes `20260825-103352` as the anchor and makes `AT-54` moot for the older one; write the
   older bundle's `ANALYSIS.md` anyway, briefly, so the series has no hole.
2. Re-anchor all four sections to the new run stamp, restating: case count, lint file count, perf
   scenario set, and the watch list's `Current state as of`.
3. Rebuild the watch-list tables from the new `complexity.txt`. Expected content on today's code:
   `NS.ValidateSchema` at 15 (a **watch**, at the line — the same disposition
   `Helpers.BuildMainContent` used to carry), `addon:OnAbsorbChanged` at 14 (Accepted, unchanged
   reasoning), `NS.ResolveColor` at 14 (**newly crossed** — say so, and say it is dense defaulting:
   four `or`s in one `local` at `core/CoreSetup.lua:55`, no branching), `build` at 12 (Accepted).
   Drop `Helpers.BuildMainContent` — `settings/About.lua` is 36 lines now and the function is off the
   list. The band table becomes an **empty table with its header row**: `tests/test_slashcmds.lua` at
   999 has left the band, and an empty table is the correct way to render "none" in a table-shaped
   record (the same fix `AT-44` took in the 2026-08-05 bundle).
4. State explicitly, as the current record already does well, that the three-release-run shelf-life
   clock has not started because no manifest carries a non-null `"release"`.

**Risk:** the refresh is prose and can drift again. The durable fix is to make the four sections part
of the release checklist rather than the run checklist — the checkpoint is the tag, so anchoring them
to the release run is both cheaper and correct.

## D-4 — The skipped-tests column (`AT-55`)

**Files:** none in this repo. Upstream: `LibKa0s/testkit/run-automated-tests.sh`.

`testing-§1` forbids editing the vendored kit, and a local patch would be reverted by the next
re-vendor and would make `tests/test_vendor_sync.lua` red immediately. The change belongs in the kit:

- `HEADER` (`:391` as vendored) gains a `Tests` column rendered `passed/skipped/total`;
- the tests summary parser (`:190-195`) already matches
  `'[0-9]+ passed, [0-9]+ failed(, [0-9]+ total)?'` — extend it to capture the `N skipped` group this
  addon's runner already prints (`547 passed, 0 failed, 0 skipped, 547 total`);
- `suite_json tests` (`:369`) gains `"skipped": $TESTS_SKIP`;
- the header-change guard (`MUST NOT silently recreate the file when its column set has changed`)
  must be honoured: the kit has to append under the old header or refuse, never rewrite it.

Then re-vendor into this repo and every sibling. **Risk:** column-set change is exactly the case §4
says must not drop prior rows; the kit change must be written and tested against an existing
`RESULTS.md` before it ships.

## D-5 — Delete the perf-panel decoration hook (`AT-56`)

**File:** `core/PerfSetup.lua:149-159`.

Remove the `decorate` field from the descriptor. `libs/LibKa0s/PerfPanel.lua:185-196` then takes its
`else` branch and draws the identical control from `d.addonName` — which
`core/PerfSetup.lua:43` already supplies. Keep the historical comment at `:137-148` (it records why
the two-argument call was wrong) but re-site it on the `addonName` field, where it is now the reason
that field exists.

**Test impact:** `tests/test_perf.lua:486` currently asserts against the descriptor's own close-button
path and `:388` calls `D.MakeCloseButton`. Both need re-pointing at the library's branch — assert that
the descriptor supplies `addonName` and carries **no** `decorate`, which is the invariant that
actually matters and is falsifiable (re-add the hook and it reddens).

**Risk:** low, and it is a behaviour-preserving deletion — but it is a UI path with no headless
coverage of what is drawn, so `docs/smoke-tests.md` gets one step: open `/at perf`, confirm the close
control is the shared mark and closes the panel.

## D-6 — Renormalize the working tree (`AT-57`)

**Files:** the index, then two files on disk.

```sh
git add --renormalize .
git status                 # review — expect the two stragglers only
git commit
# then, per file the check still names:
rm <path> && git checkout -- <path>
```

Re-run the `03_EVIDENCE.md` §4 command afterwards; it must print `0`. **Risk:** `--renormalize` on a
repo with uncommitted work rewrites the index for everything, so do it on a clean tree, as its own
commit, with nothing else in flight.

## D-7 — Correct the register's deviation-ID citations (`AT-59`)

**File:** `docs/ARCHITECTURE.md:354`, `:356`, `:357`.

Replace `AT-A-10`, `AT-A-03` and `AT-A-09` with the IDs the 2026-08-05 bundle actually assigned
(`AT-35` for the `events-frames-taint-§8` row, `AT-30` for the `localization-§1` row; the per-unit
event-frame row's ID is whichever of `AT-30…AT-50` carried it — read the bundle, do not guess). If no
prior bundle carried a row for it, drop the ID clause and cite the bundle and the rule instead. The
frozen bundles are **not** edited.

**Risk:** none, but this is the class of error that recurs, so add a case to `tests/test_docs.lua`
asserting every `AT-<n>` cited by the register resolves to a heading or row in some bundle under
`docs/audits/`. That converts a prose convention into a gate.

## D-8 — A falsifiable tab-strip geometry case (`AT-60`)

**File:** `tests/test_widgets.lua`.

Add one case that, for each page with a strip, renders it once per tab selection and asserts
`ctx.chromeHeight` **and every rendered row's y offset** are identical across all selections. Two
things make the difference between a real case and a green-against-nothing one:

- the mock's `GetHeight`/atlas answers must vary per tab label, otherwise the harness answers one
  height for everything and the case cannot fail (`testing-§12`);
- the case carries a comment naming the mutation that reddens it — *"red under: pack the wrapped rows
  off the selected tab's metrics instead of the cached unselected pitch"*.

Neither page wraps today, so the case must construct a page with enough tabs to wrap rather than rely
on the addon's own two and five. That is legitimate: the invariant is the library's contract, and the
consumer-side case exists to catch the day a label pushes a real page over.

**Scope note:** this is almost certainly wanted identically in every sibling addon, and the mock
capability it needs may belong in `tests/_kit/mock_base.lua` upstream rather than here.
