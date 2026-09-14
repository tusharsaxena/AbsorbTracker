# 02 — Candidates: LibKa0s v1.35.0

**Written after the fact** (see 01_DELTA). Sources: the v1.35.0 block of `CHANGELOG.md` at the tag,
`docs/api/Options/version-18.16.5.3-docs.md` ("What changed at this version", lines 25–146) and
`docs/api/testkit/version-20-docs.md` at the tag.

## Class A: delivered on the copy alone

| Item | What it does here |
|---|---|
| `OptionsWidgets` 16 without any new call | Per the API document's "What the host does" (line 132): a host that calls none of the six members, passes no `opts.disabled` and carries `disabledIf` only in the color picker's path form "renders as it did at 18.15.5.3". AbsorbTracker carries no `disabledIf` at all (01_DELTA §3e), so the panel is unchanged. |
| Kit 20 | `mock_ids.lua` and the three AceGUI-fake methods are opt-in or unused here. No case moves. |

## Class B: host change required

None of these has a use in AbsorbTracker. They are listed because the re-vendor brought them, not
because anything here asks for them.

### B1. `disabledIf` on every maker, as a path or a predicate

- **Evidence:** API document lines 48–67. From W16 the checkbox, slider, dropdown, edit box and
  color maker all read it, and re-evaluate it on every `RefreshScalars`.
- **Here:** no row has a subject that stops applying. The one place a dimming could fit, the
  class-color swatch, must never carry it (`options-ui-§17`, anti-pattern #74). That rule is pinned
  at `tests/test_schema.lua:324` and explained at `settings/Appearance.lua:78`–`:91`.

### B2. `RenderRows` `opts.disabled`

- **Evidence:** API document lines 69–89. It draws a whole call disabled, for a page whose subject
  does not apply.
- **Here:** every page applies. `settings/UnitPanel.lua:341` is the only `RenderRows` call with an
  `opts` (`noHeadings = true`).

### B3. `O.ChoiceGrid`

- **Evidence:** API document lines 91–104. It draws a matrix of radio cells over rows that share
  one value list.
- **Here:** no setting is a per-row choice from a shared column set.

### B4. `O.ResolveId`, `O.IdInput`, `O.IdList`, with `O.UnnamedCandidates` and `O.ID_NAME_HINT`

- **Evidence:** API document lines 106–128. They add an id by number, link or name, and the host
  owns storage.
- **Here:** AbsorbTracker takes no spell, item or currency ids from the player. The adopters the
  API document names (line 139) are AuraMaster, ConsumableMaster, BankLedger and LootHistory.

## Class C: whole-module adoption

None. No major was added.

## The stub question (not an adoption)

The six new instance members raised one question the copy forced: does the degraded Options stub
in `settings/OptionsSetup.lua` carry them? The addon's parity design says no, because a member with
no caller stays out of the stub and is exempted by name. The CHANGELOG says each consumer adds them
inert. 03_DECISIONS records how it was settled.
