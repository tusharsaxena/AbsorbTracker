# Decisions

No interview: the owner decided upfront, and every decision below takes Ka0sAddonsCommonTasks
`docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/00_PLAN.md`, *Decisions (owner, 2026-11-06, asked upfront)*,
as its source. The plan names no adoption for AbsorbTracker, so this run implements nothing beyond
the re-vendor. No GitHub issue is filed (the owner's ruling: issues only for real not-now candidates).

| Candidate | Class | Decision | Source |
|---|---|---|---|
| Widgets 23 cascading `W.ContextMenu` rows | B | not applicable: no `W.ContextMenu` use site (`core/WidgetsSetup.lua:35` is the stub only) | plan row "Cascading-menu fields, addons with no `W.ContextMenu` use site" |
| Toast 4 stack | B | not applicable: Toast not consumed, no Toast stub | plan scope (the Toast stub is owed only by a host with one; DpsRace is the one named) |
| `LibKa0s-IconBrowser-1.0` | C | settled, no adoption: the addon has no icon chooser | plan row "IconBrowser, every addon without an icon chooser" |
| Kit 51, DebugLogDiagnostics 7, Widgets 23 flat menus | A | delivered on the copy | not a candidate |

Undecided candidates: none.
