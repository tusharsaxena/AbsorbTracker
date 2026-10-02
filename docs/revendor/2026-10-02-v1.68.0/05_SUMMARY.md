# 05 — Summary: LibKa0s v1.67.0 -> v1.68.0

Plan item TP-AT-01 of the 2026-10-02 LibKa0s tooltip-place bundle, run 2026-10-02 on branch
`feat/2026-10-02-drag-attach`. Nothing was pushed, no issue was filed, and the addon version was not
bumped. `libs/` and `tests/_kit/` were not touched after the copy.

## The move

The vendored LibKa0s moved from **v1.67.0** to **v1.68.0** (tag object `6d83731`, commit `cc9f5eb`).
The base came from the `CLAUDE.md` provenance line. One file moves a minor: WidgetsDragHandle 3 -> 4
(Widgets key 12.1.3 -> 12.1.4). No file is added or deleted. The kit stays at revision 35 and is
byte-identical to v1.67.0's. There is no span bundle and no base correction.

## Delivered for free (class A)

The drag handle's tooltip is now evaluated and drawn as two steps. This addon sets no hook, so its
three strips, `?` marks and X marks get minor 3's calls in minor 3's order (`02_CANDIDATES.md` A).

## Contract blockers (3g)

None. `modules/Bar.lua` passes no `tooltipPlace`, `place`, `tooltipOwner` or `owner`, and there is no
`__Attach*` site.

## Also in the copy commit

- The `CLAUDE.md` provenance line and `docs/testing.md:170` move to v1.68.0.
- `docs/test-cases.md` is in sync (`diff <(lua tests/run.lua --list) docs/test-cases.md` is empty;
  868 cases). The README badge stays at 867/867.

## Adopted, declined, unreached

- **Adopted**: none.
- **Declined (not filed)**: B1, `tooltipPlace`. The strip already owns its tooltip by the strip
  (frame owner, `ANCHOR_TOP`), so it does not sit at the cursor, which is what the owner's
  beside-the-strip request fixes. The client clamps a frame-owned tooltip to the screen. A hook
  would also take over the `?` and X tooltips. This is not a real gap, so no issue was filed. The
  reasoning is in `03_DECISIONS.md`.
- **Unreached**: none.

## Gates on the copy commit

All run through `/home/tushar/.claude/wow-addon/bin/ka0s-bounded`.

| Gate | Result |
|---|---|
| `lua tests/run.lua` | 867 passed, 0 failed, 1 skipped, 868 total (before the copy: 867 / 0 / 1, 868) |
| `luacheck .` | 0 warnings / 0 errors in 68 files |
| `bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle` | pass, sighted: 0 warnings, max CCN 14, 2181 functions |
| vendor parity | `diff -r` against the tag is empty for both payloads, and `tests/test_vendor_sync.lua` is green |

In-game smoke: none is new. BAR-12 (d) already covers the strip and `?` tooltips, and their placement
does not change.
