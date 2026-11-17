# 05 Summary

- Tag moved v1.94.0 -> v1.105.0, base taken from the CLAUDE.md provenance line. Kit revision 53 -> 57. Files that moved a minor: see 01_DELTA.md.
- Span bundle: `2026-11-16-v1.94.0-v1.94.0` (one tag). Base correction: none.
- Delivered for free (class A): the strip tooltip's attached fallback, the console's plain Copy, footer and header buttons, and the rest listed in 02_CANDIDATES.md.
- Contract blockers: two, fixed in the RV-AT commit. (1) WidgetsDragHandleTip minor 1 retired the cursor fallback of a `tooltipPlace` hook; the one test that pinned it is re-pinned on the attached placement. (2) Surface parity: the Options stub gains `SideTabs`, the DebugLog stub `Report` and `Serialize`.
- LibKa0s icons: line kept as written. The prune kept 14 of 5840 icon files (5826 undeclared Open Iconic, Phosphor and Game-icons files removed) and removed all 362 voice-pack files (no sounds line). Provenance split: none.
- README credits: unchanged (Open Iconic only ships). Dead stub mirrors: none.
- Adopted: nothing. Declined: nothing. Owed in phase [3]: #92, #88, #86, #79 (and #87 if the sim draws names).
- Gate: `ka0s-bounded lua tests/run.lua` 1065 passed, 0 failed, 1 skipped (1066) under retail and under `KA0S_KIT_CLIENT=forever`; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 85 files; largest addon Lua file 1097 lines (tests/test_schema.lua).
