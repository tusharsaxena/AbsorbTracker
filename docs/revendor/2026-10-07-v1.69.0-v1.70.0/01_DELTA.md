Delta: LibKa0s v1.69.0 -> v1.70.0 (span: v1.69.0 v1.70.0)

# 01 — Delta (consolidated span)

Written 2026-10-07 by plan item RV-AT of the 2026-10-07 review and standards-audit remediation
(`Ka0sAddonsCommonTasks/docs/2026-10-07-REVIEW_AND_STANDARDS_AUDIT_REMEDIATION/`), beside this run's
own bundle `docs/revendor/2026-10-07-v1.71.0/`. Two tags this addon vendored were never given a bundle
of their own; this span records them (the revendor command's step 3h). It resolves the 2026-10-07
standards audit's AT-82 (remediation finding `AT-A-01`). The audit proposed a `v1.68.1 -> v1.70.0`
span; the command spec names only the unrecorded tags, first included, so the span starts at v1.69.0.

## The listing

Run from the repo root before this run's copy. The commits that moved either payload:

```sh
git log --format='%h %ad %s' --date=short -- libs/LibKa0s tests/_kit
```

```
4c16982 2026-10-07 chore: re-vendor LibKa0s v1.70.0
5075fd5 2026-10-06 chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)
8030ac1 2026-10-04 DC-REV-01: re-vendor LibKa0s v1.68.1 (kit 36; library bytes unchanged)
```

The bundles on record:

```sh
ls -1 docs/revendor | tail -3
```

```
2026-10-02-v1.67.0
2026-10-02-v1.68.0
2026-10-04-v1.68.1
```

The newest recorded bundle, `docs/revendor/2026-10-04-v1.68.1/`, names base v1.68.0 and new v1.68.1,
which is the payload `8030ac1` carried. `5075fd5` and `4c16982` each roll the `CLAUDE.md` provenance
line (to v1.69.0 and v1.70.0) and no bundle names either tag. Vendored and unrecorded: **v1.69.0 and
v1.70.0**. Base of the span: **v1.68.1**.

Both payloads were correct when carried: `git archive <commit> libs/LibKa0s tests/_kit` compared with
`git -C ../LibKa0s archive <tag> LibKa0s testkit` by `diff -r --strip-trailing-cr` is empty for
`5075fd5` against v1.69.0 (commit `5949f4c`) and for `4c16982` against v1.70.0 (commit `162a7fd`).

## Per-file minors, by tag

**v1.68.1 -> v1.69.0** (`git -C ../LibKa0s diff --stat v1.68.1 v1.69.0 -- LibKa0s testkit`: 6 files,
554 insertions, 2 deletions):

- `WidgetsLineChart.lua` **added at minor 1** (`LibKa0s-Widgets-1.0` key 12.1.4.1), and one row in
  `LibKa0s.xml`. The library goes from 32 files to 33. Every other file keeps its v1.68.1 minor.
- Kit revision **36 -> 37**: `framework.lua` (the version line), `README.md`, `mock_base.lua` (loads
  the new file) and `mock_lines.lua` (new, 85 lines: the Line-region mock the chart's cases use).

**v1.69.0 -> v1.70.0** (`git -C ../LibKa0s diff --stat v1.69.0 v1.70.0 -- LibKa0s testkit`: 3 files,
382 insertions, 4 deletions):

- `WidgetsAutocomplete.lua` **added at minor 1**, and one row in `LibKa0s.xml`; the library goes to
  34 files.
- `WidgetsLineChart.lua` **1 -> 2** (`opts.pxPerPoint`); Widgets key 12.1.4.2.1.
- The kit is unchanged at revision 37.

No `NEEDS_*` floor rose and no major was added in either tag. Neither moved a major AbsorbTracker
consumes in a way it uses: the addon draws no chart and has no autocomplete box (no `LineChart` or
`Autocomplete` call outside `libs/` and `tests/_kit/`), so neither tag had an adoption candidate.
