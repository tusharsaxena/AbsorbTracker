Delta: LibKa0s v1.106.0 -> v1.107.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.107.0 LibKa0s testkit tools` (tag commit 5e96365, a local tag, not yet on origin: `git -C ../LibKa0s ls-remote --tags origin v1.107.0` prints nothing). Run under item AF-RV-AT of Ka0sAddonsCommonTasks `docs/2026-11-19-ADOPTION_FEEDBACK/` (the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s` 2.9.0; the run's adoption items are pre-decided in its `items.tsv`, so there is no interview).

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` -> `47:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.106.0 (MIT).` The last payload commit, `c911d6c`, leaves the same line. `diff -rq` of the v1.106.0 extract against `libs/LibKa0s` and `tests/_kit` is clean apart from the undeclared voice packs (`media/sounds/callout`, no sounds line). Base v1.106.0.

`git -C ../LibKa0s log --oneline v1.106.0..v1.107.0`: 5e96365, 72653ec, 24b9cea, f468fe7, efbed58, cbf3577 (AF-LK-01, AF-LK-02, AF-DR-LK, AF-LK-03).

Base correction: none. Step 0 for this addon: the newest single-tag bundle `2026-11-16-v1.105.0` states base v1.94.0, and the provenance before its re-vendor was v1.94.0.

## 3b/3c. Minors

`git -C ../LibKa0s diff --stat v1.106.0 v1.107.0 -- LibKa0s testkit`: two files.

| File | Old | New |
|---|---|---|
| WidgetsDragHandle.lua | DRAG_MINOR 14 | DRAG_MINOR 15 |
| WidgetsDragHandleTip.lua | DRAGTIP_MINOR 1 | DRAGTIP_MINOR 2 |

Every other file's minor is unchanged. No skew.

## 3d. Diffs

Before the prune, `diff -rq --strip-trailing-cr` of the extract against both payloads: empty. Bytes: empty (both sides CRLF).

## 3e. Consumption

Widgets-1.0 through `core/WidgetsSetup.lua`; the DragHandle consumer is `modules/Bar.lua` (`buildHandle`).

## 3f. Kit

`Kit.VERSION = 57` on both sides. The kit does not move in this range.

## 3g. Contract delta

- WidgetsDragHandle minor 15: marks read [?][settings][close] left to right; the settings mark is built unless `spec.settings == false`; the X still needs `spec.onClose`; the marks' tints are the window header's. This addon already passes `onClose`, `settings = true` and its own `settingsTooltip`/`closeTooltip`, so nothing is wrong on landing. The comment in `modules/Bar.lua` naming the old order is corrected under AF-STRIP-AT.
- WidgetsDragHandleTip minor 2: `spec.tooltipPlace` retired, accepted unread. This addon passes none (retired at AD-92-AT).

Blockers: none.

## 3h. Unrecorded tags

The audit's listing (walk of `libs/LibKa0s`, `tests/_kit` and the CLAUDE.md rolls since 2026-08-25, against the bundles' tags) prints `v1.106.0`, vendored by `c911d6c` without a bundle. Back-filled in `../2026-11-19-v1.106.0-v1.106.0/`.

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> line 48, directly under the provenance line: `chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.` Kept as written. `settings` is already declared (the strip's settings mark). No sounds line: no voice pack ships.

## 3j. Whole-folder icon tests

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: nothing assumes the whole folder (fixed at v1.75.0).
