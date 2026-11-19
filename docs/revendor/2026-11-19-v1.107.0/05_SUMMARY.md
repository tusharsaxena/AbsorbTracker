# 05 Summary

- Tag moved v1.106.0 -> v1.107.0, base taken from the CLAUDE.md provenance line. Kit revision 57, unchanged. Minors: WidgetsDragHandle 14 -> 15, WidgetsDragHandleTip 1 -> 2.
- Span bundle: `2026-11-19-v1.106.0-v1.106.0` (one tag). Base correction: none.
- Delivered for free (class A): the strip's mark order [?][settings][close], the tighter mark spacing, the header tints at rest and on hover, and the strip tooltip always above the strip.
- Contract blockers: none. The host already passes `onClose` and the settings mark, and no `tooltipPlace`.
- LibKa0s icons: line kept as written. The prune kept the 13 declared icons and the Open Iconic license, and removed all 362 voice-pack files (no sounds line). Provenance split: none.
- README credits: unchanged (Open Iconic only ships). Dead stub mirrors: none.
- Adopted: nothing under this item. The strip wiring is AF-STRIP-AT, its own commit.
- Gate: `ka0s-bounded lua tests/run.lua` 1082 passed, 0 failed, 1 skipped (1083) under retail and under `KA0S_KIT_CLIENT=forever`; `ka0s-bounded luacheck .` 0 warnings / 0 errors in 86 files.
