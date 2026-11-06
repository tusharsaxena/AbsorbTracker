# Decisions

No interview. Every decision below comes from Ka0sAddonsCommonTasks
`docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/SF1_SMOKE_FEEDBACK.md`, *The items*. Only the Skin Tester
takes the `keepScope` opt-out (`SF1-ST`), and no item names an adoption for AbsorbTracker, so this run
implements nothing beyond the re-vendor. No GitHub issue is filed.

| Candidate | Class | Decision | Source |
|---|---|---|---|
| `RegisterOwner` `keepScope` | B | not applicable: AbsorbTracker has no documented Scope deviation | SF1 item `SF1-ST` (the Skin Tester only) |
| Pixel edges, the copy's Scope guard | A | delivered on the copy | not a candidate |

Undecided candidates: none.

## The header ruling (SF1 item 5)

The owner ruled that a column-header row with a grey line above and below it is wrong, and that
LootHistory's `NS.Skin.SortHeaderBar` header, with no lines, is correct. AbsorbTracker draws no
column-header row in any window of its own. Its Skin facade's library-absent stub says "this addon
draws no window chrome of its own" (`core/SkinSetup.lua:401`), and `SortHeaderBar` and `Divider`
appear only in that stub's no-op name list (`core/SkinSetup.lua:408`, `:410`). No call site exists
in `core/`, `modules/` or `settings/`. Its windows are the bars (`modules/Bar.lua:229`) and the
library-built options panel, debug console and perf panel. **No `SF1-AT-HDR` change.**
