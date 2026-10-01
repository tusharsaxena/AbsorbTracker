# 05 — Summary: LibKa0s v1.65.0 -> v1.66.0

Plan item GI-AT-RV of the 2026-10-01 GitHub issue pass, run 2026-10-01 on branch
`feat/2026-10-01-github-issue-pass`. Nothing was pushed, no issue was filed, and the addon version
was not bumped. `libs/` and `tests/_kit/` were not touched after the copy.

## The move

The vendored LibKa0s moved from **v1.65.0** to **v1.66.0** (tag object `178ee0b`, commit `e4c5ef7`),
base taken from the `CLAUDE.md` provenance line. Six files move a minor (Widgets 12, DebugLog 19,
Slash 19, OptionsWidgets 34, OptionsTabs 8, Perf 14) and four are added (`WidgetsReorder.lua`,
`SlashParse.lua`, `PerfSampler.lua`, `PerfCommands.lua`). The kit moves 34 -> 35. Nothing was deleted.
The tags v1.64.0 and v1.65.0, vendored without a bundle, are recorded in the span bundle
`docs/revendor/2026-10-01-v1.64.0-v1.65.0/` (two tags).

## Delivered for free (class A)

The sighted complexity suite with parity, Perf's zero-count declared parents, Slash's resolver, and
four file peels with no behavior change (`02_CANDIDATES.md` A).

## Contract blockers (3g)

None.

## Also in the copy commit

- `tests/run.lua` declares `{ name = "test_lizard_sighted", dir = "tests/_kit/" }`.
- `CLAUDE.md` provenance line and `docs/testing.md:170` move to v1.66.0.
- `docs/testing.md`'s suite table names the runner's complexity suite instead of the raw lizard
  command (kit 35 adoption step 3).
- `docs/performance.md` (thirty-two files, Perf's two new secondary files), `docs/scope.md` and
  `docs/module-map.md` (the kit's fifth suite, revision 35, line counts).
- `docs/test-cases.md` regenerated (853 cases); README badge 844/844 -> 852/852.

## Adopted, declined, unreached

- **Adopted later in this branch**: B1, the minor-8 `RenderTabbedSchema` opts (GI-AT-02).
- **Declined**: none.
- **Unreached** (not interviewed by plan): B2 Perf budgets, B3 `RenderGrid` opts, for GI-LK-13.

## Gates after the copy commit

All run through `/home/tushar/.claude/wow-addon/bin/ka0s-bounded`.

| Gate | Result |
|---|---|
| `luacheck .` | 0 warnings / 0 errors in 67 files |
| `lua tests/run.lua` | 852 passed, 0 failed, 1 skipped, 853 total (before: 844 / 0 / 1, 845) |
| `bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | pass, sighted: 0 warnings, max CCN 14, 2134 functions, blindFiles 0 |
| vendor parity | `diff -r` against the tag empty for both payloads |

The copy alone, before the provenance roll, ran 850 passed, 2 failed (the two vendor-sync cases, as
expected), 1 skipped.
