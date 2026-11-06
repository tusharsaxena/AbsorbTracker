# Summary, LibKa0s v1.85.0 -> v1.89.0

Item `V89-AT` of Ka0sAddonsCommonTasks `docs/2026-11-06-REVENDOR_LIBKA0S_V1_89/`.

- **Tag:** v1.85.0 -> v1.89.0 (tag object `0bd4839`, commit `df00e5f`, pushed). The base came from
  the `CLAUDE.md` provenance line and agrees with the last payload commit (`50847a2`). Step 0: `ok`,
  no base correction.
- **Per-file minors:** `Toast.lua` 3 -> 4, `Widgets.lua` 22 -> 23, `DebugLogDiagnostics.lua` 6 -> 7,
  and the new `LibKa0s-IconBrowser-1.0` major (`IconBrowserSources.lua` 1, `IconBrowserWindow.lua` 1,
  `IconBrowser.lua` 1). Every other file unchanged. Kit revision 50 -> 51. No cross-major skew, no
  `NEEDS_*` floor rise, no file removed upstream.
- **Span bundle:** none (3h printed nothing).
- **Delivered for free (class A):** kit 51's CallbackHandler unregister guard; the diagnostics
  report's `LibKa0s running:` line names IconBrowser; Widgets 23 leaves every flat menu as minor 22
  drew it.
- **Contract blockers:** none. Widgets 23 is additive and the addon opens no `W.ContextMenu`;
  DebugLog 22.7.1.4 has no member change; the addon passes no `__Attach*` members.
- **Icons:** the `LibKa0s icons:` line was kept unchanged (13 names, all Open Iconic). The prune
  printed `13 icon(s) declared; kept 14 file(s), removed 5826`: 211 Open Iconic files, all 1435
  Phosphor files and all 4180 Game-icons files. That is the same subset as at v1.85.0. No
  provenance split was needed.
- **README credits:** unchanged. The only shipped set is still Open Iconic, and its line stands.
- **Dead stub mirrors:** none (no `__` member removed in the range).
- **Adopted:** nothing in this item. The owner's plan names no adoption for AbsorbTracker.
- **Declined:** nothing filed. Cascading menus and the Toast stack are not applicable (no use
  site, no consumer), and IconBrowser is settled because the addon has no icon chooser (03_DECISIONS).
- **Unreached or undecided:** none.
- **Gate:** `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` gives 0 warnings / 0 errors in 85
  files (`.luacheckrc` excludes `libs/` and `tests/_kit/`; the addon's own seams are inside the
  checked set). `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua` gives 1062 passed, 0
  failed, 1 skipped, 1063 total. The skip is the kit's diagnostics opt-out case, which does not apply
  to an addon that keeps the default. The vendor-sync cases pass at v1.89.0. The largest own file
  is `tests/test_schema.lua` at 1097 lines, under the 1500-line cap.
