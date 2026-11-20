Delta: LibKa0s v1.107.0 -> v1.108.0

Recorded before the commit. Payload taken from the tag, never the sibling tree: `git -C ../LibKa0s archive v1.108.0 LibKa0s testkit tools` (tag commit 56c20b7, a local tag, not yet on origin: `git -C ../LibKa0s ls-remote --tags origin v1.108.0` prints nothing; the tag sits on LibKa0s `feat/2026-11-20-libka0s-94-97-99-100`). Run under item SD-RV-AT of Ka0sAddonsCommonTasks `docs/2026-11-20-LIBKA0S_94_97_99_100/` (the copy, provenance, declaration and prune half of `/dev-copilot:wow-revendor-libka0s` 2.10.1; the run's adoption work is pre-decided in its `items.tsv`, so there is no interview and nothing is filed).

## 3a. Base

`grep -n '[Bb]undles' CLAUDE.md` -> `47:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.107.0 (MIT).` `diff -rq --strip-trailing-cr` of the v1.107.0 extract against `libs/LibKa0s` and `tests/_kit` is clean apart from the undeclared icons and the voice packs (no sounds line). Base v1.107.0. Base correction: none; the newest single-tag bundle, `2026-11-19-v1.107.0`, states base v1.106.0, which was the provenance before its re-vendor.

## 3b/3c. Minors

`diff -rq` of the two extracts: seventeen payload files and five kit files.

| File | Old | New |
|---|---|---|
| Core.lua | MINOR 18 | MINOR 19 |
| Widgets.lua | MINOR 29 | MINOR 30 |
| WidgetsBar.lua | BAR_MINOR 1 | BAR_MINOR 2 |
| WidgetsDragHandle.lua | DRAG_MINOR 15 | DRAG_MINOR 16 |
| WidgetsDragHandleTip.lua | DRAGTIP_MINOR 2 | DRAGTIP_MINOR 3 |
| WidgetsDropdown.lua | DROPDOWN_MINOR 2 | DROPDOWN_MINOR 3 |
| WidgetsLineChart.lua | CHART_MINOR 7 | CHART_MINOR 8 |
| Callout.lua | MINOR 4 | MINOR 5 |
| CalloutSettings.lua | SETTINGS_MINOR 5 | SETTINGS_MINOR 6 |
| WaypointArrow.lua | MINOR 2 | MINOR 3 |
| WaypointArrowSettings.lua | SETTINGS_MINOR 2 | SETTINGS_MINOR 3 |
| Charts.lua | MINOR 2 | MINOR 3 |
| ChartsRender.lua | RENDER_MINOR 1 | RENDER_MINOR 2 |
| SkinPaint.lua | PAINT_MINOR 19 | PAINT_MINOR 20 |
| SkinPaintControls.lua | CONTROLS_MINOR 18 | CONTROLS_MINOR 19 |
| SkinPaintHud.lua | HUD_MINOR 1 | HUD_MINOR 2 |
| OptionsCompose.lua | COMPOSE_MINOR 19 | COMPOSE_MINOR 20 |

Kit: `framework.lua`, `skin_switch.lua`, `skin_values.lua`, `test_skin_switch.lua`, `test_skin_values.lua`, `README.md`. Every other file's minor is unchanged. No skew, no file added or removed, no `NEEDS_*` floor rises.

## 3d. Diffs

After the copy, `diff -r --strip-trailing-cr` of the extract against both payloads: empty apart from the `Only in <extract>/LibKa0s/media/icons` and `media/sounds` lines for what the declaration leaves out. Bytes: the same (both sides CRLF). No `Only in libs/LibKa0s` line, so nothing was deleted by hand.

## 3e. Consumption

Core, Bus, Lifecycle, Launcher, Media, DebugLog, Env, Widgets (`core/WidgetsSetup.lua`; the DragHandle consumer is `modules/Bar.lua`, plus the HUD `TestStrip`), Skin (`core/SkinSetup.lua`, `core/Database.lua`), Perf, Sim (`modules/Sim.lua`), Options (`settings/OptionsSetup.lua`, the composers in `settings/Appearance.lua`), Slash, Schema. Not consumed: Callout, WaypointArrow, Charts. This addon builds no `W.Bar`, no Charts context, no `S.ApplyBarFill` call and no `W.ContextMenu`.

## 3f. Kit

`Kit.VERSION` 57 -> 58 (`SD-LK-GUARD`): the skin-switch test compares each setter family on its own, holds every StatusBar to drawing and moving its fill, and takes `expect`, `hold` and `clear` per surface; the typed-value scanner reads tables, keyed tables, triples and `RGBA` fallbacks and takes kit row categories. Both payloads move together by construction.

## 3g. Contract delta

- **OptionsCompose minor 20 (Batch A, R-2).** `settings/Appearance.lua` already calls `H.BarGroup` and `H.FontGroup` with `fromSkin = true`, `H.BorderGroup` with `fromSkin = "bar"`, `H.FontGroup` with `flagsFromSkin = true`, and hands every color and shadow companion in `extra` at the composer's own path (`<key>FromSkin`), so the composer emits none of them a second time: a dump of the player's rows after the copy shows 28 paths, no duplicate, the same as before. One row moves: Font shadow (`units.<unit>.fontShadow`) now carries `disabledIf = "units.<unit>.fontShadowFromSkin"`, the composer's new rule that the shadow checkbox is not live while its companion is on. `core/Data.lua` already ignores the stored shadow then (unless Ignore fonts is on), so this is the library agreeing with the draw. `tests/test_skin_flip.lua` re-pinned; swatches still carry no `disabledIf` (options-ui-§17).
- **WidgetsDragHandleTip minor 3 (LibKa0s#99, R-3).** A strip whose rect reads secret now opens its tooltip above its nearest readable ancestor (here the bar), by an absolute point on UIParent, and hides it when nothing up the tree reads, never writing a relative point into the strip. `tests/test_draghandle.lua`'s two fallback cases re-pinned: a secret top places above the bar; no readable rect shows no tooltip.
- **WidgetsBar minor 2, Charts minor 3, SkinPaintControls minor 19, WidgetsDropdown minor 3, Callout minor 5, WaypointArrow minor 3.** Not consumed here (3e).
- **Widgets minor 30.** The footer lays out only shown marks (this addon builds no footer); `W.OwnerWarnings(owner, sink)` is new and optional.
- **Kit revision 58.** `test_skin_switch` and `test_skin_values` pass unchanged on this addon's declarations at the copy. The surface fields are SD-SK-AT's work.

Blockers: none. The two re-pins land in this commit.

## 3h. Unrecorded tags

None: every tag this addon vendored since v1.94.0 has a bundle.

## 3i. Icon declaration

`grep -n 'LibKa0s icons:' CLAUDE.md` -> line 48, directly under the provenance line: `chevron-down, chevron-up, clear, close, confirm, copy, eye, help, info, move, reset, settings, volume-high.` Kept as written. No sounds line: no voice pack ships.

## 3j. Whole-folder icon tests

`grep -rn "media/icons\|lib.ICONS\|\.ICONS)" tests --include='*.lua' | grep -v '/_kit/'`: nothing assumes the whole folder.
