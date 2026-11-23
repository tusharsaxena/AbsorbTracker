# AbsorbTracker feedback batch, 2026-11-23: plan

Spec: [`../specs/2026-11-23-absorbtracker-feedback-design.md`](../specs/2026-11-23-absorbtracker-feedback-design.md).
Branch: `feat/2026-11-23-absorbtracker-feedback`. Git is the state: an item is done when a commit
whose subject starts `<ID>: ` is on the branch.

## Gate (every commit, run serially)

1. `~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
2. `KA0S_KIT_CLIENT=forever ~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua`
3. `~/.claude/dev-copilot/bin/ka0s-bounded luacheck .` reads 0 warnings / 0 errors
4. Every file under 1500 lines; no function above CCN 15.

Test first: each item's failing case is written and seen red before the change that turns it green.

## Items

| ID | What | Files | Done when |
|---|---|---|---|
| ATF-00 | Spec and this plan | `docs/superpowers/` | committed |
| ATF-01 | The Unit picker across profile events: the pooled-AceGUI suite, and the picker's line in the diagnostics `[UI]` section | `tests/test_profilepanel.lua`, `tests/run.lua`, `modules/Diagnostics.lua`, `tests/test_diagnostics.lua` | the suite and the new diagnostics case green |
| ATF-02 | New-profile defaults: three bars on, none linked; v11 keeps every existing profile's look; the v3 lift seeds the legacy flags; the stacked positions pinned | `defaults/Profile.lua`, `core/Database.lua`, `settings/Appearance.lua`, `tests/test_database.lua`, `tests/test_display.lua`, suites that assumed the old defaults | an existing profile keeps target and focus off and linked; a new one has all three on and unlinked |
| ATF-03 | Appearance > Bar > Position: X and Y offset and Reset position, per unit, live both ways | `settings/Appearance.lua`, `settings/UnitPanel.lua`, `modules/Bar.lua`, `tests/test_schema.lua`, `tests/test_layoutguard.lua`, a position suite | a slider moves the bar, a drag moves the slider, reset returns the stacked default |
| ATF-DOC | Smoke checks (empty Result lines), ARCHITECTURE, README, schema, settings-panel, profiles, scope; regenerate `docs/test-cases.md` and the Tests badge | `docs/`, `README.md` | `diff <(lua tests/run.lua --list) docs/test-cases.md` is empty |
| ATF-REV | One skeptical pass over `git diff master..HEAD`: existing-profile damage, a test that passes without its fix, a linked-unit regression, Forever against Retail | any | findings fixed |

## Checkpoints

- **CP-1** after ATF-02: both clients green, luacheck 0/0.
- **CP-2** after ATF-DOC: the full gate, the inventory in sync, the badge equal to its total.

No push, no merge, no version bump.
