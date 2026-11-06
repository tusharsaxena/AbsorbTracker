# Summary, LibKa0s v1.89.0 -> v1.90.0

Item `SF1-RV-AT` of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/` (from
`SF1_SMOKE_FEEDBACK.md`).

- **Tag:** v1.89.0 -> v1.90.0 (tag object `b2fce60`, commit `4485b8f`). The tag is **local** and is
  pushed only at the owner's go-ahead. The base came from the `CLAUDE.md` provenance line and agrees
  with the last payload commit (`7e9785c`). Step 0: `ok`, no base correction.
- **Per-file minors:** `Core.lua` 15 -> 16, `Skin.lua` 16 -> 17, `SkinPaint.lua` 18 -> 19,
  `SkinPaintExtras.lua` 17 -> 18, `Widgets.lua` 23 -> 24, `WidgetsAutocomplete.lua` 7 -> 8,
  `OptionsAppearance.lua` 6 -> 7. Every other file is unchanged. Kit revision 51 on both sides, and
  the kit payload is byte-identical. No cross-major skew, no `NEEDS_*` floor rise, and no file was
  removed upstream.
- **Span bundle:** none (3h printed nothing).
- **Delivered for free (class A):** Widgets controls draw one-physical-pixel edges at any UI scale
  (Core 16's `__PixelBackdrop`). A skin copy from this addon leaves a `keepScope` owner's Scope alone.
- **Contract blockers:** none. Core 16 adds only internal `__` members, Widgets 24 has "What a host
  owes: nothing", and Skin 17's `keepScope` is an additive option. The addon passes no `__Attach*`
  members.
- **Icons:** the `LibKa0s icons:` line was kept unchanged (13 names, all Open Iconic). The prune
  printed `13 icon(s) declared; kept 14 file(s), removed 5826`: 211 Open Iconic files, all 1435
  Phosphor files and all 4180 Game-icons files, the same subset as at v1.89.0. No provenance split
  was needed.
- **README credits:** unchanged (Open Iconic is still the only shipped set).
- **Dead stub mirrors:** none (no `__` member was removed in the range).
- **Adopted:** nothing. `keepScope` is for the Skin Tester only (`SF1-ST`).
- **Declined:** nothing filed.
- **Unreached or undecided:** none.
- **Header ruling (SF1 item 5):** AbsorbTracker draws no column-header row of its own
  (`core/SkinSetup.lua:401`, `:408`), so it needs no `SF1-AT-HDR` change (03_DECISIONS).
- **Gate:** `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` reports 0 warnings / 0 errors in 85
  files. `.luacheckrc` excludes `libs/` and `tests/_kit/`, and the addon's own seams are inside the
  checked set. `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` reports 1062 passed,
  0 failed, 1 skipped and 1063 total. The skip is the kit's diagnostics opt-out case. The vendor-sync
  cases pass at v1.90.0. The largest file the addon owns is `tests/test_schema.lua` at 1097 lines,
  under the 1500-line cap. The commit changes none of the addon's own Lua, so no function's CCN moves.
