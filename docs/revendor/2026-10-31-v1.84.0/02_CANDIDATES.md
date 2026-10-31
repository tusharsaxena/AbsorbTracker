# 02 — Candidates

Sources: `git -C ../LibKa0s log --oneline v1.83.0..v1.84.0`, the tag's `CHANGELOG.md` v1.84.0 block and
the `docs/api` documents of the majors that moved. All class B and C items are additive.

## Class A: delivered by the re-vendor

- WidgetsDragHandle minor 10: strips measure at their own effective scale, write the measured text
  fresh and repeat the last fit on show, out of combat. `modules/Bar.lua` and `modules/Display.lua` need
  no change. Minor 9: `ApplyLevel` allocates nothing.
- The peels: pure moves, same members on the same instance.
- WoW Default's Friz guard and DebugLogDiagnostics minor 6 (the identity header names Charts).

## Class B: host change required

| Candidate | Evidence | Would touch | Recommendation |
|---|---|---|---|
| `opts.beforeGroup`, `opts.afterSubgroup` | Options doc, LibKa0s#59 section | `settings/UnitPanel.lua` | Decline: no page needs a seam |
| `note` row | Options doc, Schema 3 | `settings/*.lua` | Decline: no page wants one |
| `O.PositionBlock` | Options doc line 56 | `settings/Appearance.lua` | Decline: the bars are placed by dragging; no X and Y rows exist |
| `O.PageBanner{ acts }` | Options doc, OptionsTabs minor 13 | `settings/UnitPanel.lua` | Decline: this addon draws `PageHeader`, and `PageBanner` has no call site |

## Class C: whole module

| Candidate | Evidence | Recommendation |
|---|---|---|
| `LibKa0s-Charts-1.0` | `docs/api/Charts/version-1.1-docs.md` | Decline: this addon draws no chart |
