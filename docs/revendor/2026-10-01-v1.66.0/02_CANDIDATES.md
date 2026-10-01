# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.65.0..v1.66.0`, the `CHANGELOG.md` v1.66.0 block, and the
`Since` markers in `docs/api/Options/version-27.2.34.2.2.8.1.7.4.2-docs.md`,
`docs/api/Perf/version-14.1.1.6-docs.md`, `docs/api/Slash/version-19.1-docs.md`,
`docs/api/Widgets/version-12.1.3-docs.md` and `docs/api/testkit/version-35-docs.md` at the tag.

## A. Delivered on the copy

- Kit 35's sighted complexity suite with function-count parity, and lizard's `-L 1500`. The runner is
  vendored; the gate's wiring (`tests/run.lua`) is in the copy commit.
- Perf 14's zero-count declared parents in the record (`CHANGELOG` "a declared parent that never
  fired is in the record").
- Slash 19's resolver: this addon's Slash `L` carries none of the parse keys, so nothing changes on
  screen; it would reach them if they were added.
- The four file peels (`WidgetsReorder`, `SlashParse`, `PerfSampler`, `PerfCommands`) and the
  `lib:New` helper hoists: no behavior change.

## B. Host change required

| # | Candidate | Evidence | Would touch | Recommendation | Blast radius |
|---|---|---|---|---|---|
| B1 | `RenderTabbedSchema` opts `untabbedSkipRender`, `disabledReplaces` (+ `disabledNoticeFont`), `rerender` | CHANGELOG v1.66.0 "OptionsTabs minor 8"; Options doc at the tag | `settings/UnitPanel.lua`, `docs/settings-panel.md`, `docs/module-map.md` | **Adopt** — already planned as GI-AT-02 (AbsorbTracker#32) in this branch | Replaces host code (the partition and TabStrip composition) |
| B2 | Per-bucket Perf `budget = { msPerSec, maxMs }` | CHANGELOG v1.66.0 "report-only per-bucket budgets"; Perf doc at the tag | `core/PerfSetup.lua` | Not decided this cycle; ceilings would come from a committed capture | Additive, report-only |
| B3 | `RenderGrid(ctx, items, parent, opts)` with `opts.gap` | CHANGELOG v1.66.0 "OptionsWidgets minor 34" | `settings/UnitPanel.lua:272` | No need seen: the one call draws a single wide item on the page scroll | Additive |

## C. Whole-module adoption

None. No major is added, and every major this addon did not consume at v1.65.0 is unchanged.
