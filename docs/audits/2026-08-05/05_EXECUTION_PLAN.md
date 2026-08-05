# 05 — Execution Plan

Ordered remediation for `02_DEVIATIONS.md`, designed in `04_TECHNICAL_DESIGN.md`. This is the
hand-off to a separate remediation engagement; **the audit itself changed nothing**.

**Standing rules for every step below**

- Green gate before each commit: `luacheck .` → `0 warnings / 0 errors`, and
  `lua5.1 tests/run.lua` → all pass. Commit only on green (`testing-§4`, `versioning-git`).
- Trunk-based. Work on `master` unless the user asks for a branch. Never push unasked, never bump
  the version unasked.
- Where a step changes behavior, **write the characterization test first and run it against the
  unchanged code** to confirm it fails (`testing-§13`, `performance-§11`).
- Frozen artifacts are off limits: `docs/audits/*`, `docs/reviews/*`, `docs/automated-tests/<run>/*`
  and `docs/perf-runs/*.json` record what was believed and measured at the time.
- Do not edit `libs/LibKa0s/` or `tests/_kit/` content. Upstream fixes go to the LibKa0s repo and
  come back by re-vendoring.

---

## Sprint 1 — records and metadata (no Lua, no risk)

Everything here is a one-liner or a paragraph, and all of it can land in a single session. Doing it
first clears the noise so Sprint 3's behavior work reviews cleanly.

| # | Step | IDs | Done when |
|---|---|---|---|
| 1.1 | `git update-index --chmod=+x tests/_kit/run-automated-tests.sh` and commit the mode change | AT-43 | `git ls-files -s tests/_kit/run-automated-tests.sh` → `100755`; `./tests/_kit/run-automated-tests.sh --suite lint --suite tests --no-bundle` runs from a fresh clone |
| 1.2 | Add `chmod +x tests/_kit/run-automated-tests.sh` to the re-vendor procedure in `docs/testing.md:76-83`, beside the `diff -r` pair | AT-43 | the procedure names all three actions |
| 1.3 | Add a `tests/test_vendor_sync.lua` case asserting the runner's **index** mode is `100755` (read via `git ls-files -s`, never `ls -l` — drvfs reports `0777` for everything) | AT-43 | case fails if 1.1 is reverted |
| 1.4 | `CLAUDE.md:40` — `Four` → `Five` | AT-42 | the count matches the five names that follow it |
| 1.5 | Optional guard: a `tests/test_docs.lua` case asserting `CLAUDE.md` names exactly the five required topic-detail docs and that the count word agrees | AT-42 | case fails on a deliberate miscount |
| 1.6 | `docs/testing.md` — state the release gate at `:57-58`; scope `:22`, `:46-47` and `:49-52` to "never fail a **run**, never gate a **commit**" | AT-45 | the doc names all four suites at `pass` + `suites.complexity.warnings == 0` at the tag, `skip` = NOT EVALUATED, evaluated by `/wow-addon:bump-version` from `manifest.json`, runner exit code unchanged |
| 1.7 | `docs/automated-tests/README.md:19-33` — the same two edits | AT-45 | both docs say the same thing |
| 1.8 | Raise the `RESULTS.md` lead-in (`:9-11`) and the missing warned-functions header row **upstream in LibKa0s `testkit/`**; do not hand-edit the generated file | AT-45, AT-44 | an upstream issue/PR exists and is linked from this plan's follow-up note |
| 1.9 | `.pkgmeta` — add `- .superpowers` and `- .claude` to `ignore:` | AT-46 | neither folder appears in a packaged build |
| 1.10 | `AT-32-F`: add a `tests/test_docs.lua` case reading `docs/test-cases.md`'s `## Totals` row and asserting `README.md:7`'s badge shows the same `X/Y` | AT-32-F | case fails if the badge is edited to a wrong number |

**Exit criteria.** Both gate commands green; a fresh clone can execute the runner; no doc in the repo
claims complexity never gates anything without naming the checkpoint.

**Blocked-on-upstream note.** 1.8 leaves AT-44 and one third of AT-45 open until LibKa0s ships the
kit change and it is re-vendored here. That is the correct state — an interim local edit to
`RESULTS.md` would be a hand-edited record that reads as generated, which is worse than the gap
(`anti-pattern #51`). If the round trip stalls, an interim local edit is defensible **only** because
no number is being touched, and it must be reverted to generated form at the next run.

---

## Sprint 2 — measurement truth

Small, and it must land before the next perf capture or the capture inherits the wrong labels.

| # | Step | IDs | Done when |
|---|---|---|---|
| 2.1 | Add a `tests/test_perf.lua` case pinning the descriptor's nesting map: `paintBar` declares `within = "repaintPass"`; `appearance` and `visibility` declare **no** parent. Run it against the unchanged file and confirm it **fails** | AT-47 | the case is red before 2.2 |
| 2.2 | `core/PerfSetup.lua:46-47` — drop `within` from `appearance` and `visibility`; correct the descriptor comment at `:40-41` to name `paintBar` alone | AT-47 | 2.1's case is green; suite green |
| 2.3 | `docs/performance.md:239,273` — confirm both already say "repaintPass contains paintBar" and leave them; no edit expected | AT-47 | prose and descriptor agree |
| 2.4 | `docs/performance.md:242-249` — lead with the bucket totals as the addon's cost, present the delta as an environment measurement, and lift the ±0.3 ms/frame resolution floor from `:258` to sit with the first mention | AT-48 | the page reads the way `performance-§7` mandates; the worked example at `:245-249` is unchanged |

**Do not** regenerate `docs/perf-runs/*.json` or any bundle. They are frozen and correctly record
what the descriptor said when they were captured.

---

## Sprint 3 — behavior

Three independent changes plus one optional. Each is its own commit with its own test, in this
order — the order is by blast radius, smallest first.

| # | Step | IDs | Done when |
|---|---|---|---|
| 3.1 | `tests/test_database.lua` — characterization case for the current fresh-DB migration path (copyDefaults materializes `global`, `RunMigrations` runs, ladder observed). Run against unchanged code | AT-49 | the case documents today's behavior and passes |
| 3.2 | `defaults/Profile.lua:78` — `schemaVersion = 4` → `1`, with the load-bearing comment adapted from its per-profile sibling at `:50-55` | AT-49 | 3.1 still passes; a fresh install still ends at `4`; no `[Migrate]` line is emitted for a DB that needed nothing |
| 3.3 | `tests/test_widgets.lua` / the mock — let the existing "a page renders nothing until its first OnShow" case reach the Profiles page by satisfying the AceDBOptions/AceConfigDialog guard at `settings/Profiles.lua:25-27`. Run against unchanged code and confirm it **fails** | AT-34 | the case is red before 3.4 |
| 3.4 | `settings/Profiles.lua` — move the `AceGUI:Create("SimpleGroup")` and its anchoring (`:51-56`) into the `OnShow` handler (`:60-62`) behind a `built` flag. `AceConfig:RegisterOptionsTable` stays in `build` | AT-34 | 3.3's case is green; the Profiles page still renders on first open in game (`docs/smoke-tests.md`) |
| 3.5 | `core/CoreSetup.lua` — publish `NS.Format = printer.Format` at `:77` and a symmetric equivalent in the library-absent branch; one test asserting both paths exist and are secret-safe | AT-35 | the seam exists on both paths |
| 3.6 | Convert the 18 pre-formatted call sites (`settings/Slash.lua:33,97,242,246,282,321,334,339,344,352,357,365,389,414,427,428,439`; `settings/Schema.lua:214`). Comment the pure-indent exemptions rather than converting them | AT-35 | `tests/test_slashcmds.lua`'s verbatim line assertions pass **unchanged** — a moved line means the conversion was wrong, not the test |
| 3.7 | *(optional, SHOULD)* `modules/Display.lua` + `settings/Slash.lua` — paint the `/at test` placeholder through the live path whenever `locked` is false, clear on lock, and add `/at test off`; build the "clear and repaint" path once so expiry also repaints | AT-38 | unlocking shows a representative bar; `/at test off` clears immediately; the hold expires visibly |

**Ordering constraints.** 3.5 strictly before 3.6. 3.1 strictly before 3.2, 3.3 strictly before 3.4.
Everything else is independent. 3.7 is a user decision — it is two SHOULDs, and deferring it with the
reason recorded is a legitimate outcome.

**In-game verification required** for 3.4 and 3.7: `docs/smoke-tests.md` covers the settings panel
and bar positioning, and neither is reachable from the headless harness.

---

## Sprint 4 — prose sweeps

Last, because it is the largest diff and the least consequential; landing it earlier would bury the
Sprint 3 review.

| # | Step | IDs | Done when |
|---|---|---|---|
| 4.1 | Sweep the 31 retired `§N.M` references to `filename-§N` across `core/`, `defaults/`, `modules/`, `settings/`, `locales/`, `tests/` and the live `docs/` pages, using the map in `04_TECHNICAL_DESIGN.md`. Fix the malformed `slash-commands-§:` at `settings/Slash.lua:199` → `slash-commands-§3` | AT-36 | `grep -rnE '§[0-9]+\.[0-9]+' --exclude-dir=audits --exclude-dir=reviews` returns nothing; `luacheck .` and the suite unchanged |
| 4.2 | `docs/ARCHITECTURE.md:277-314` — retire the four entries the standard now sanctions (Wago omission, `AbsorbTrackerPerfDB`, `lizard`, the bracket idiom) into a short "was a deviation, now standard" note; delete the three "**Pending promotion**" paragraphs | AT-37 | the register lists only live decisions: per-profile `schemaVersion`, per-unit event frames (AT-31), `__lastUnitCtx`, fixed media |
| 4.3 | `README.md:159` — rewrite the 1.9.0 Version History Highlights to carry the same highlights as `## What's new in 1.9.0`, leading with the Target/Focus bars and the breaking slash paths | AT-33 | the two agree; `documentation-§1` item 5 satisfied |
| 4.4 | `modules/Bar.lua:5-6` — name the real readers of the player aliases instead of the deleted `core/DebugLog.lua`; or delete the aliases if only tests read them | AT-40 | no comment names a file that does not exist |
| 4.5 | `.luacheckrc:6` — narrow `docs/` to `docs/audits/` + `docs/reviews/`, or extend the comment at `:4-5` to record the broadening as deliberate | AT-39 | either way, the decision is written down |
| 4.6 | `tests/test_vendor_sync.lua` — make a sibling-absent run visibly a skip (rename the cases or report a skip), correct the header comment at `:107-109`, and optionally add a case asserting the sibling's `HEAD` is at the vendored tag | AT-50 | a sibling-absent run cannot be mistaken for a checked one |
| 4.7 | AT-41 — no change; the extra `## Credits and libraries` section is accepted | AT-41 | recorded, not edited |

**Sweep boundary.** 4.1 must not touch `docs/audits/*` or `docs/reviews/*`. Those bundles are frozen
history and their `§N.M` references are correct for the standard version they were written against.

---

## Not scheduled — decisions for the user

| ID | Why it is here |
|---|---|
| **AT-30** | Localization. The seam is in place and the fallback returns the key, so this is a scope decision, not a defect. Deferred in `docs/pending/LEDGER.md` (PLAN-02). |
| **AT-31** | Accepted deviation with its justification recorded in `docs/ARCHITECTURE.md:316-331`. The durable fix is upstream — `events-frames-taint-§1` naming unit-filtered registration as a sanctioned exception. |
| **AT-38** | Two SHOULDs. Scheduled as optional 3.7; deferring with the reason recorded is legitimate. |

---

## Follow-up owed to the next run

- **Run the two vendor-sync diffs.** `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and
  `diff -r ../LibKa0s/testkit tests/_kit` were **NOT RUN** in this audit — the run was scoped to this
  repo alone. Both **MUST** be empty. The suite's tag-based substitute cannot see upstream having
  moved past `v1.7.0`, which is the exact silent shape of anti-pattern #45. Run them before the next
  release regardless of when the next audit happens.
- **Produce a release bundle at the next tag.** All three committed bundles carry `"release": null`
  and `"dirty": true`, and the latest stamps `ab2603e` against a HEAD of `e31b79d`.
  `automated-tests-§6` wants a full four-suite bundle in the same change that bumps the version,
  before the tag, on a clean tree — and `automated-tests-§3`'s release gate reads that bundle's
  manifest.
- **Re-check anti-pattern #53 at the first release run.** The watch list's single entry
  (`tests/test_slashcmds.lua`, Accepted, "peel by verb group if it crosses 1400") starts its
  three-consecutive-release shelf life the first time a run is stamped as a release. It is 1256 lines
  today.
- **`Helpers.BuildMainContent` sits *at* CCN 15** (`settings/About.lua:38-104`). One more block on
  the About page puts it over and into the warned-functions table — and, as of v2.21.0, blocks the
  release gate. `performance-§11` shape 4 (split the builder) is the fix when it arrives.
