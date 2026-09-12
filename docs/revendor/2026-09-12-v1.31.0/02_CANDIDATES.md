# 02 — Candidates: LibKa0s v1.31.0 (kit revision 17)

Sources, in order: `git -C ../LibKa0s log --oneline v1.30.0..v1.31.0` (01_DELTA); the v1.31.0 block
of `CHANGELOG.md` at the tag; `docs/api/Options/version-15.15.4.3-docs.md` and
`docs/api/testkit/version-17-docs.md` at the tag.

## Class A: delivered on the copy alone

| Item | Evidence | What it does here |
|---|---|---|
| `OptionsWidgets` minor 15: a row with no `path` reads and writes through its own `get` / `set` | `CHANGELOG.md` v1.31.0, "OptionsWidgets.lua minor 15" | Nothing. Every one of this addon's 69 rows carries a `path`, and the gate is `path == nil`, so each maker reads and writes through the descriptor exactly as before. |
| `OptionsCompose` minor 4: path-keyed composer output | `CHANGELOG.md` v1.31.0: "Path-keyed callers are byte-for-byte unaffected", pinned upstream by `tests/fixture_compose_golden.lua` | `H.MasterControls`, `H.BarGroup`, `H.BorderGroup`, `H.FontGroup` and `H.ColorPair` emit the same rows. `tests/test_schema.lua`'s page/tab/count partition and every row-shape case stay green. |
| Kit 17: `NewAddon` honors its mixin list, and the lifecycle runs from `AceAddon.frame` | `version-17-docs.md:281` (AbsorbTracker 563 / 2 / 565 in all three runs) and `:295` (AbsorbTracker reaches the named `NewAddon` path directly) | This harness calls the kit's `NewAddon` with a name, so the addon object is now built the way the client builds it: exactly the named mixins, through `LibStub`. Production lists AceEvent, AceTimer and AceConsole, so the object keeps every mixin it had. The suite stays at 565, all green, with the sibling present, so the vendor-sync cases ran rather than skipped. |
| Kit 17: a real AceTimer, CallbackHandler-backed AceEvent, AceConsole, `WidgetVersions`, `RegisterLayout` | `CHANGELOG.md` v1.31.0, "Kit revision 17" | Nothing in this suite moved. `M.__fireTimers()` keeps its name and now also answers a count, which no case here reads. |

## Class B: host change required

### B1. `spec.bind`, the record-backed composer arm

- **What:** a composer takes `spec.bind = { get/record, set }`, and its rows carry `field` plus
  closures instead of a `path`.
- **Evidence:** `CHANGELOG.md` v1.31.0, "OptionsCompose.lua minor 4". `version-15.15.4.3-docs.md`
  carries PanelMaster's three blocks as the worked example.
- **Fit:** none. The arm exists for pages that edit **registry records**. This addon holds no
  structural registry (`docs/ARCHITECTURE.md` → Settings Schema). Its three tracked units are a
  fixed list, and every row addresses a fixed path through `NS.SetByPath`. Binding a composer here
  would route writes around the single seam.
- **Blast radius:** would replace path-keyed rows. Not additive.
- **Recommendation:** not a candidate. Recorded for completeness, not offered.

### B2. Retire a local mock layer onto kit 17

- **What:** the orchestrator's instruction was to adopt any kit-17 surface that retires a local
  mock layer, but only if the suite stays green.
- **Finding:** there is no such layer. `tests/wow_mock.lua` (58 lines) builds on
  `tests/_kit/mock_base.lua` and replaces none of its Ace fakes. What it adds is this addon's own:
  - `UnitGetTotalAbsorbs` and `UnitHealthMax`;
  - `AbbreviateNumbers`;
  - three `RAID_CLASS_COLORS` entries;
  - a unit-aware `UnitClass`.

  The kit-17 diff does not touch `UnitClass` or any of the others. It adds AceAddon, AceEvent,
  AceTimer, AceConsole and AceGUI surfaces, which this harness already took from the kit. No test
  file defines a timer, message or chat-command fake of its own (a
  `grep -nE 'ScheduleTimer|RegisterMessage *=|NewAddon *=|RegisterChatCommand *=' tests/*.lua`
  finds only `M.__fireTimers()` callers).
- **Recommendation:** nothing to adopt. Kit 17's layering section names six other consumers, and
  AbsorbTracker is not one of them (`version-17-docs.md:309`).

## Class C: whole-module adoption

None new. `Item`, `Pool` and `Widgets` are not looked up directly (01_DELTA 3e), and none of them
moved in this release, so the premise of any earlier decision about them is unchanged.
