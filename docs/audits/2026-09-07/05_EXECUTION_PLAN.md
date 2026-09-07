# 05 — Execution plan

Hand-off to the remediation engagement. Every step names its deviation ID and its design section in
`04_TECHNICAL_DESIGN.md`. The green gate (`lua tests/run.lua` + `luacheck .`, both 0/0) runs before
every commit; the counts to beat are **547/547** and **0 warnings / 0 errors in 27 files**, both
measured today (`03_EVIDENCE.md` §1).

Ten roots, one dependent. Nothing here is High or Medium, so nothing is urgent — the ordering is by
cheapness and by what unblocks what.

---

## Sprint 1 — the one-file, no-risk edits (half a day)

| # | Step | IDs | Design | Done when |
|---|---|---|---|---|
| 1.1 | Add `.claude` and `.superpowers` to `.pkgmeta`'s `ignore:` block, each with the one-line comment saying what it is. | `AT-51` | D-1 | The playbook's dot-entry sweep prints only `UNACCOUNTED — .git` and `UNACCOUNTED — .pkgmeta`. |
| 1.2 | Delete `libs/LibStub/tests/` and `libs/LibStub/LibStub.toc`. | `AT-58` | D-1 | `find libs/LibStub -type f` prints one line. Close issue #25 as `state:done`. |
| 1.3 | Correct the three register ID citations at `docs/ARCHITECTURE.md:354,356,357` against the real IDs in `docs/audits/2026-08-05/02_DEVIATIONS.md`. Do not edit the frozen bundle. | `AT-59` | D-7 | `grep -oE 'AT-[A-Z-]*[0-9]+' docs/ARCHITECTURE.md` yields only IDs that resolve inside `docs/audits/`. |
| 1.4 | Delete the `decorate` field from the perf descriptor (`core/PerfSetup.lua:149-159`); re-site its comment onto `addonName` at `:43`. Re-point `tests/test_perf.lua:388` and the note at `:486` at the library's branch, asserting the descriptor supplies `addonName` and carries **no** `decorate`. Add the `/at perf` close-control step to `docs/smoke-tests.md`. | `AT-56` | D-5 | Suite green; the new assertion reddens when the hook is re-added. |

**Commit boundary:** 1.1+1.2 together (packaging), 1.3 alone (docs), 1.4 alone (code + test + smoke
step).

## Sprint 2 — the working tree (one commit, on a clean tree, nothing else in flight)

| # | Step | IDs | Design | Done when |
|---|---|---|---|---|
| 2.1 | `git add --renormalize .`, review `git status`, commit the index change. | `AT-57` | D-6 | — |
| 2.2 | For each file the check still names: `rm <path> && git checkout -- <path>`. | `AT-57` | D-6 | The `03_EVIDENCE.md` §4 command prints **0**. |

Do this **after** sprint 1, so the renormalize commit contains only line-ending churn and stays
readable. Do not combine it with any other change.

## Sprint 3 — `docs/slash-dispatch.md` and the hub spill (one day)

| # | Step | IDs | Design | Done when |
|---|---|---|---|---|
| 3.1 | Write `docs/slash-dispatch.md`: the registration seam, the generated 17-verb table, the `/at profile` subtree (`PROFILE_HELP` `settings/Slash.lua:298`, `PROFILE_VERBS` `:327`, dispatch `:386`, unknown-`sub` fall-through), and the `list/get/set/reset` output format. | `AT-52` | D-2 | — |
| 3.2 | Reduce `docs/ARCHITECTURE.md`'s `## Slash Commands` (`:179-224`) to a summary plus exactly one link. | `AT-52` | D-2 | `wc -l docs/ARCHITECTURE.md` back under ~400, closing `AT-Info-1` as a side effect. |
| 3.3 | Flip the Tier 2 row at `:324` from `Not applicable` to `Present`, with the trigger restated as *"17 commands in `NS.COMMANDS`, plus the `/at profile` subcommand tree"*. | `AT-52` | D-2 | The row's assertion is checkable and true. |
| 3.4 | Extend `tests/test_docs.lua` with a case asserting `docs/slash-dispatch.md` names every `NS.COMMANDS` entry. | `AT-52` | D-2 | Case reddens when a verb is added without a doc row. |

Depends on nothing; ordered here because it is the largest doc write.

## Sprint 4 — the automated-test record (half a day)

| # | Step | IDs | Design | Done when |
|---|---|---|---|---|
| 4.1 | Run `tests/_kit/run-automated-tests.sh` (all four suites) to produce a fresh bundle. | `AT-53` | D-3 | New `docs/automated-tests/<stamp>/` with a manifest. |
| 4.2 | Write `docs/automated-tests/20260825-103352/ANALYSIS.md` — briefly, so the series has no hole — reporting complexity with totals **and** averages and linking each figure to the artifact in that same directory. | `AT-54` | D-3 | — |
| 4.3 | Write the new run's `ANALYSIS.md` the same way. | `AT-54` | D-3 | — |
| 4.4 | Re-anchor `RESULTS.md`'s `## Test suite`, `## Lint`, `## Perf` and the watch list's `Current state as of` (`:100`) to the new stamp. | `AT-53` | D-3 | No section names a run older than the newest row. |
| 4.5 | Rebuild both watch-list tables from the new `complexity.txt`: `NS.ValidateSchema` 15 (**watch**, newly at the line), `addon:OnAbsorbChanged` 14 (Accepted), `NS.ResolveColor` 14 (**newly crossed**, dense defaulting — say which), `build` 12 (Accepted); drop `Helpers.BuildMainContent`. Band table becomes an empty table **with its header row** — `tests/test_slashcmds.lua` is at 999 and has left the band. | `AT-53`, `AT-61` | D-3 | Every figure in the tables matches the bundle beside them. |
| 4.6 | Restate that the three-release-run shelf-life clock has not started (`"release": null` in every manifest). | `AT-53` | D-3 | — |

`AT-61` closes with `AT-53`; it is not a separate step.

**Process fix, same sprint:** move the four narrative sections from the *run* checklist to the
*release* checklist. The checkpoint is the tag, so anchoring the prose to the release run is both
cheaper and the correct reading of `automated-tests-§6`.

## Sprint 5 — the falsifiable strip-geometry case (half a day)

| # | Step | IDs | Design | Done when |
|---|---|---|---|---|
| 5.1 | Give the mock per-label height answers so a one-height harness cannot pass the case; consider whether that belongs in `tests/_kit/mock_base.lua` upstream. | `AT-60` | D-8 | — |
| 5.2 | Add the case: construct a page with enough tabs to wrap, render once per selection, assert `chromeHeight` and every row's y offset are identical across all of them. Carry the reddening mutation in a comment. | `AT-60` | D-8 | Case is green, and reddens under the named mutation. |

## Upstream — not this repo (`AT-55`)

| # | Step | IDs | Design |
|---|---|---|---|
| U.1 | In `LibKa0s/testkit/run-automated-tests.sh`: capture the `N skipped` group in the tests summary parser, render the `Tests` column as `passed/skipped/total`, add `"skipped"` to `suite_json tests`, and honour the "never rewrite a changed header" rule. | `AT-55` | D-4 |
| U.2 | Tag LibKa0s, re-vendor here and in the siblings, confirm `tests/test_vendor_sync.lua` stays green and `diff -r` stays empty on both payloads. | `AT-55` | D-4 |

Nothing in this repo changes for `AT-55` until U.2 lands. Do **not** patch the vendored kit locally —
`testing-§1` forbids it and `tests/test_vendor_sync.lua` would go red on the next run.

---

## Verification at the end of the engagement

Re-run, and expect:

1. `luacheck .` → 0 warnings / 0 errors.
2. `lua tests/run.lua` → all green, count **above** 547 (sprints 3.4 and 5.2 each add cases), 0 skipped.
3. `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` → no thresholds exceeded.
4. The `03_EVIDENCE.md` §4 line-ending command → **0**.
5. The playbook's two `.pkgmeta` sweeps → only `.git` and `.pkgmeta` unaccounted.
6. `diff -r` on both LibKa0s payloads → empty, against whatever tag `CLAUDE.md` then names.
7. `docs/ARCHITECTURE.md` → under ~400 lines, every Tier 2 row's trigger true against the code, every
   cited deviation ID resolving inside `docs/audits/`.
