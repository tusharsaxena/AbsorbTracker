# 03 — Decisions

**Written after the fact** (see 01_DELTA). There was no interview for this re-vendor. The owner
re-vendored v1.35.0 into the six consumers that adopt none of its new surfaces, AbsorbTracker among
them, **without adoption**. This file records those calls.

| Candidate | Decision | Why |
|---|---|---|
| `OptionsWidgets` 16 on the copy (Class A) | **taken on the copy** | Nothing to wire. No row carries `disabledIf`, so nothing starts dimming. |
| Kit 20 (Class A) | **taken on the copy** | Opt-in. No case moves. |
| B1 `disabledIf` everywhere | **not adopted** | No row here has a subject that stops applying, and the color swatch must never carry one (`options-ui-§17`). |
| B2 `RenderRows` `opts.disabled` | **not adopted** | Every page applies. |
| B3 `O.ChoiceGrid` | **not adopted** | No per-row choice from a shared column set. |
| B4 `O.ResolveId` / `IdInput` / `IdList` / `UnnamedCandidates` / `ID_NAME_HINT` | **not adopted** | The addon takes no ids from the player. |

**The stub members.** The six new members are **on the degraded Options stub, inert**, by owner
decision (2026-09-14). They are not there because anything calls them. `46de577` first exempted
them by name on `tests/test_surface_parity.lua`'s ignore list, which is the addon's RefreshPanel
rule for a member with no caller. The owner then asked for the six on every consumer's stub, and
`8506cea` moved them there, test first: the case went red naming all six, then
`settings/OptionsSetup.lua:376`–`:379` gained `ChoiceGrid` / `IdInput` / `IdList` as no-ops,
`ResolveId` / `UnnamedCandidates` returning nil, and `ID_NAME_HINT = {}`. The reason is recorded in
the parity case's comment (`tests/test_surface_parity.lua:149`), in `docs/module-map.md` row 20 and
in `docs/settings-panel.md:58`.

This is not an entry in `docs/ARCHITECTURE.md` → `## Documented deviations`. The standard asks a
stub to carry what the degraded build can reach. Carrying more, inertly, does not break that rule,
and the parity case still compares by name.

**No issue was filed for the declines.** The non-adoption was the owner's own call for all six
non-adopting consumers, not a candidate someone turned down during an interview. Nothing here is
work left for later.
