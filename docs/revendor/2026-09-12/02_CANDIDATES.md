# 02 — Candidates: LibKa0s v1.30.0 (kit revision 16)

Sources, in order: `git -C ../LibKa0s log --oneline v1.29.0..v1.30.0` (four commits, all kit 16);
the v1.30.0 block of `CHANGELOG.md` at the tag (`:13-149`); and
`docs/api/testkit/version-16-docs.md` at the tag. No library major moved its minor, so no
`docs/api/<Major>/` document changed and there is nothing to diff there.

## Class A: delivered on the copy alone

| Item | Evidence | What it does here |
|---|---|---|
| Runner-mode case (#28) | `CHANGELOG.md:99-125`; `version-16-docs.md:160` | `VendorSync.register` adds *the automated-test runner is recorded executable (100755)*. `tests/test_vendor_sync.lua:31` passes no opts, so it arrives with no edit. `git ls-files -s` records the runner `100755`, so it passes. Total 560 → 561. |
| AceEvent event half on an Embed (#29) | `CHANGELOG.md:59-81`; `version-16-docs.md:96-136` | No effect. This addon registers game events only on the `NewAddon` target (`core/AbsorbTracker.lua`, `core/PerfSetup.lua`), which already recorded them. Its Embed targets (`core/Bus.lua`) carry messages only. The new `RegisterEvent` validation passes every production registration (the suite stays green). |
| `Printf` beside `Print` (#30) | `CHANGELOG.md:83-97`; `version-16-docs.md:138-158` | No effect. Nothing in `core/`, `modules/`, `settings/` or `tests/` calls or defines `Printf`. |

## Class B: host change required

### B1. Delete the local `AceGUI:Release` shim (#27)

- **What:** the kit now models `AceGUI:Release` with the same `w.__released` / `AceGUI.__released`
  recorder, so the local copy in `tests/wow_mock.lua:15-38` is a duplicate fake.
- **Evidence:** `CHANGELOG.md:31-57` (contract); `CHANGELOG.md:148` names this exact deletion for
  AbsorbTracker ("Measured with it removed: 561 total, all green"); `version-16-docs.md:40-94`,
  recorder table at `:72-73`.
- **Files touched:** `tests/wow_mock.lua` (delete the block), `docs/module-map.md` row 32, which
  said `wow_mock.lua` holds `AceGUI:Release`.
- **Reader:** only `tests/test_helpers.lua:768-803`, which reads `w.__released` at `:788`, `:795`
  and `:798`. The kit sets that same field.
- **Production caller:** `settings/UnitPanel.lua:257-258` (`releaseStaleChromeWidgets`). It releases
  each stale widget once, and never passes nil, so the kit's stricter behavior (raise on nil,
  raise on double release) cannot trip it. The suite proves the second half: a double release
  would now raise and turn the case red.
- **Blast radius:** subtractive, test-only. Nothing ships. The kit's version is stricter than the
  shim (it raises where the shim returned quietly), so removing the shim can only make the suite
  catch more.
- **Recommendation:** adopt. The owner pre-answered this one as ADOPT.

## Class C: whole-module adoption

None new. `Item`, `Pool` and `Widgets` are not looked up directly (01_DELTA 3e), and none of them
moved in this release, so the premise of any earlier decision about them is unchanged.

## Declines

None. The one class-B candidate was adopted. No harness migration was needed: this addon's
`tests/wow_mock.lua` builds on `tests/_kit/mock_base.lua` and replaces none of the kit's
`NewAddon`, `AceEvent` or `LibStub`, so every kit fix reaches it.
