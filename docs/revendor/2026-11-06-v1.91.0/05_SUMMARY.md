# Summary, LibKa0s v1.90.0 -> v1.91.0

Item `FU-RV-AT` of Ka0sAddonsCommonTasks `docs/2026-11-06-FOLLOWUPS_V1_91/`.

- **Tag:** v1.90.0 -> v1.91.0 (tag object `4566d85`, commit `55bfbb4`). The tag is **local** and is
  pushed only at the run's finalize. The base came from the `CLAUDE.md` provenance line and agrees with
  the last payload commit (`f5fe3d2`). Step 0 was **skipped** (the installed skill's roster regex
  matches nothing; fixed upstream in `FU-DC1`), so it is not a pass. No base correction.
- **Per-file minors:** `Core.lua` 16 -> 17, `SkinPaintExtras.lua` 18 -> 19, `Widgets.lua` 25 -> 26,
  `WidgetsLineChart.lua` 6 -> 7; new `CorePixel.lua` 1, `SkinPaintHud.lua` 1, `SkinAceConfirm.lua` 1,
  `WidgetsDropdown.lua` 1. Every other file is unchanged. Kit revision 51 on both sides, and the kit
  payload is byte-identical. No cross-major skew, no `NEEDS_*` floor rise, and no file was removed
  upstream.
- **Span bundle:** none (3h printed nothing; run with `tag_at` rewritten to a named variable).
- **Delivered for free (class A):** the line chart's physical-pixel lines (this addon draws no chart),
  and the three band-file peels, which change no member or behavior.
- **Contract blockers:** none. Every library loader in the suite derives its list from the vendored
  `LibKa0s.xml`, so the four new files load in XML order with no edit; no test pins a moved minor; the
  degradation stubs' member names (`ContextMenu`, `BarGloss`, `HudFont`) did not move. The addon passes
  no `__Attach*` members.
- **Icons:** the `LibKa0s icons:` line was kept unchanged (13 names, all Open Iconic). The prune printed
  `13 icon(s) declared; kept 14 file(s), removed 5826`, the same subset as at v1.90.0 (git shows no
  change under `media/icons`). No provenance split was needed.
- **README credits:** unchanged (Open Iconic is still the only shipped set).
- **Dead stub mirrors:** none (no `__` member was removed in the range).
- **Adopted:** nothing. **Declined:** nothing filed. **Unreached or undecided:** none.
- **Gate:** `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` reports 0 warnings / 0 errors in 85
  files (`.luacheckrc` excludes `libs/` and `tests/_kit/`; the addon's own seams are inside the checked
  set). `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` reports 1062 passed, 0 failed,
  1 skipped, 1063 total; the vendor-sync and load-order cases pass at v1.91.0. The largest file the
  addon owns is `tests/test_schema.lua` at 1097 lines, under the 1500-line cap. The commit changes none
  of the addon's own Lua, so no function's CCN moves.
