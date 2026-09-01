# Profiles

AceDB-3.0 integration, the `/at profile` subcommand surface, and the fallback shim used when AceDB-3.0 is missing.

## AceDB integration

AceDB ships in-tree at `libs/AceDB-3.0/` (folder-per-lib, not `libs/Ace3/...`), so in practice it's always present. DB init lives in `NS:InitDB` (`core/Database.lua`), called once from the AceAddon `OnInitialize` (`core/AbsorbTracker.lua`, at `ADDON_LOADED` timing) and also reachable headlessly by the test harness:

```lua
function NS:InitDB()
    local AceDB = LibStub and LibStub("AceDB-3.0", true)
    if AceDB then
        NS.db = AceDB:New("AbsorbTrackerDB", NS.defaults, true)
        if NS.db.RegisterCallback then
            NS.db.RegisterCallback(NS, "OnProfileChanged", NS.OnProfileChanged)
            NS.db.RegisterCallback(NS, "OnProfileCopied", NS.OnProfileChanged)
            NS.db.RegisterCallback(NS, "OnProfileReset", NS.OnProfileChanged)
        end
    end
    if not NS.db then
        AbsorbTrackerDB = AbsorbTrackerDB or {}
        NS.db = { profile = AbsorbTrackerDB, global = {} }
    end
    NS:RunMigrations()
end
```

The third arg to `AceDB:New` is `defaultProfile` — `true` means use the WoW-supplied `"Default"` shared across characters. Every character on the account starts on `Default`, so changes carry over to every other character out of the box. Opt into per-character / per-class / per-realm scope from the Profiles panel if a character should diverge.

`RegisterCallback` is guarded (`if NS.db.RegisterCallback`) so the headless AceDB mock — which has no CallbackHandler — doesn't error during tests.

Defaults come from `defaults/Profile.lua`:

- `NS.defaults.profile` — the three flat globals (`locked`, `throttleWindow`, `showOnlyInCombat`), a per-profile `schemaVersion` stamp, and `units.<player|target|focus>` carrying that unit's eighteen appearance keys plus `enabled`, `mirror` and `position`.
- `NS.defaults.global.schemaVersion = 4` — the account-wide DB-version stamp.
- `NS.defaults.profile.schemaVersion = 1` — the **per-profile** stamp. Its default is `1` ("legacy — not yet lifted"), *not* the current `3`, and that is load-bearing; see [Migrations](#migrations-and-the-flatprofile-backfill) below.
- `NS.flatDefaults` — a flat alias of `NS.defaults.profile` used by the fallback read path; `NS.unitDefaults` — an alias of `NS.defaults.profile.units.player`, the one canonical default every unit's schema rows share.

## OnProfileChanged refresh chain

All three AceDB callbacks (`OnProfileChanged`, `OnProfileCopied`, `OnProfileReset`) wire into the same handler, `NS.OnProfileChanged`, defined in `core/AbsorbTracker.lua`:

```
NS.OnProfileChanged()
    │
    ├─▶ NS.MigrateProfileToV3(db.profile)   -- lift this profile if its own stamp predates v3
    │
    ├─▶ bus: MSG.POSITION      -- Display: RestoreBarPosition(unit) for every unit
    ├─▶ bus: MSG.APPEARANCE    -- Display: UpdateBarAppearance(unit) for every unit
    ├─▶ bus: MSG.REPAINT       -- Timer:   coalesced RequestRepaint -> UpdateAbsorbBar
    │
    └─▶ RefreshOptionsPanel()  -- push new values into an open settings panel
```

The three messages are payload-free; `modules/Display.lua` owns the sole subscription to each and fans it out over all three units via `NS.ForEachUnit`, and `modules/Timer.lua` owns the sole `REPAINT` subscription. Nothing here calls a Display function across the module boundary — see [data-flow.md](./data-flow.md).

The **migration call leads the chain on purpose.** A profile that only appears *after* the upgrade — copied in from another character, restored from a backup SavedVariables file, or reset back to the shipped defaults — never passed through `InitDB`'s sweep, so its own `schemaVersion` still reads pre-v3. Lifting it here, before anything reads its appearance, is what stops it rendering with factory defaults. It cannot double-apply: `MigrateProfileToV3` returns immediately once the profile carries the stamp.

`RefreshOptionsPanel` re-runs each rendered panel's refreshers, which re-read every row's value from the newly active `db.profile` and push it into its AceGUI widget. On the per-unit pages (Appearance) the last refresher is two-tier: it **always** re-syncs the mirror header checkbox in place, and re-renders the page outright **only when the new profile actually changed that unit's mirror state** — which is the only thing that can invalidate the mirrored/unmirrored row partition. An unconditional re-render would tear down a widget whose callback is still on the stack, so it was deliberately removed. The Profiles sub-page re-`Open()`s its AceConfigDialog tree on next show. See [settings-panel.md](./settings-panel.md).

## `/at profile` subcommands

Handled by `runProfile` in `settings/Slash.lua` (registered via AceConsole as part of the ordered `NS.COMMANDS` table — no `SLASH_*` globals). Bare `/at profile` prints the subcommand list, which is the file-local `PROFILE_HELP` table in the order it is written.

| Verb | Effect |
|------|--------|
| `/at profile list` | List all profiles from `db:GetProfiles()`, marking the current one. |
| `/at profile current` | Print the active profile name (`db:GetCurrentProfile()`). |
| `/at profile use <name>` | Switch to `<name>` via `db:SetProfile(name)` (AceDB creates it if absent). Fires `OnProfileChanged`. |
| `/at profile new <name>` | Create `<name>` with default settings AND switch to it (`db:SetProfile(name)` then `db:ResetProfile()`). |
| `/at profile copy <name>` | Copy `<name>`'s settings into the active profile (`db:CopyProfile`). Fires `OnProfileCopied`. |
| `/at profile delete <name>` | `db:DeleteProfile(name, true)`. Refuses if `<name>` is the active profile. |
| `/at profile reset` | Reset the active profile to defaults (`db:ResetProfile()`). Fires `OnProfileReset`. |

The whole subcommand delegates to AceDB's `SetProfile / CopyProfile / DeleteProfile / ResetProfile / GetProfiles / GetCurrentProfile`. `runProfile` first checks `if not db or not db.SetProfile` and prints `Profile system requires AceDB-3.0` when that method is absent (the fallback path), then dispatches through the file-local `PROFILE_VERBS` table — built once at load, keyed by the lowercased sub-verb, each value a `function(db, name)`. **Only the verb is lowercased**; the argument keeps its case, because AceDB profile names are case-sensitive. The four name-taking verbs (`use`, `new`, `copy`, `delete`) are wrapped in `needsName(verb, fn)`, which prints that verb's own `Usage:` line and does nothing when the name is empty — so the guard exists once, not four times. An unrecognized subcommand prints `Unknown profile subcommand '<sub>'` then re-prints the list. Adding a sub-verb is one `PROFILE_VERBS` entry plus one `PROFILE_HELP` row.

The Profiles sub-page (`settings/Profiles.lua`) wraps `AceDBOptions:GetOptionsTable(NS.db)` and renders it into a canvas panel via `AceConfigDialog:Open`, presenting the same create / switch / copy / reset / delete operations plus the scope dropdowns as a UI.

## Fallback shim (no AceDB)

If `LibStub("AceDB-3.0", true)` returns nil — only possible if `libs/AceDB-3.0/` was tampered with — `NS:InitDB` builds a minimal stand-in backed by the raw SavedVariables global:

```lua
AbsorbTrackerDB = AbsorbTrackerDB or {}
NS.db = { profile = AbsorbTrackerDB, global = {} }
```

`NS:RunMigrations` then runs the v3 lift and the flat→profile backfill (see below), so `db.profile` ends up carrying every default key, including a fully-populated `units` table. There is no `db.sv` on this path, so the multi-profile sweep simply finds nothing to walk — the single profile *is* the whole store. In this mode:

- `GetSetting` / `SetSetting` (`core/Data.lua`) work normally — they read / write `db.profile`, falling back to `NS.flatDefaults` for any still-missing key.
- **Profile management is disabled.** `/at profile` short-circuits on the missing `db.SetProfile` and prints `Profile system requires AceDB-3.0`. `settings/Profiles.lua`'s builder returns `nil` (its `LibStub("AceDBOptions-3.0", true)` / AceConfigDialog / AceGUI guards fail) so the Profiles sub-page is skipped at registration.
- `OnProfileChanged` is never fired — no callbacks are registered (the `RegisterCallback` block is inside the AceDB branch).
- The single profile lives directly in `AbsorbTrackerDB`; the AceDB-shaped `sv` / `profiles` / `profileKeys` / `char` keys don't exist. `db.global` is an ephemeral empty table, so the **account-wide** `schemaVersion` isn't persisted across sessions — the **per-profile** stamp, which lives in `AbsorbTrackerDB` itself, is.

The shim isn't exercised in-game (AceDB ships in-tree), but the migration/backfill path it feeds is covered by the headless harness (`tests/test_database.lua`).

## Migrations and the flat→profile backfill

`NS:RunMigrations` (`core/Database.lua`) is the single idempotent schema-upgrade seam, invoked once at the end of `InitDB`. It does three things, in order:

1. **Lift every profile to v3** (`migrateAllProfiles` → `NS.MigrateProfileToV3`). Logs one `[Migrate] lifted N profile(s) to v3` line, and only when a flat key was actually moved — a factory-fresh profile is unstamped and so passes the gate and gets stamped, but has nothing to lift, so a fresh install logs nothing.
2. **Backfill** any key still missing from the active profile — flat globals at the root, and every unit's keys under `units.<unit>` — from the defaults, deep-copying table values so a saved-variable mutation can never reach back into `NS.defaults`.
3. **Walk the account-wide ladder** — the file-local `SCHEMA_STEPS` array in `core/Database.lua`, an ordered list of `{ to = N, apply = fn }` rows the loop climbs one version at a time: the v2 step (retiring the dead `profile.updateInterval` key, orphaned when the poll ticker became event-driven), the stamp-only v3 step, then the v4 step (dropping the dead `hidden` master toggle from every profile in the store, replaced by the per-unit `enabled` flags), landing on `global.schemaVersion = 4`. Each step logs one `[Migrate]` debug line only when the bump actually happens, and the step's own output lands before its version line. **A new schema version is one new row in `SCHEMA_STEPS`.**

It is a safe no-op when the DB is absent (no `db.global` to touch).

### The v3 lift, and why the gate is per-profile

v3 moved bar appearance from flat `db.profile.<key>` to `db.profile.units.<unit>.<key>`. `NS.MigrateProfileToV3(profile)` seeds any missing unit table from the defaults, moves the pre-v3 flat appearance keys (and the saved `position`) onto the **player** unit, clears the flat originals, and stamps `profile.schemaVersion = 3`. A user upgrading sees an identical bar in an identical spot.

Three things about that function are deliberate and load-bearing:

- **It is gated on a version stamp, never on `profile.units == nil`.** Under real AceDB-3.0 the mere act of reading `db.profile` triggers the library's own `copyDefaults`, which fills every missing key — including the whole new `units` table — from `NS.defaults` before any migration code runs. `profile.units` is therefore *never* nil on an upgrading install, and a `units == nil` guard would make the lift permanently dead code: the user's saved `barWidth` / `barColor` / `position` would be silently orphaned.
- **The gate is the *per-profile* stamp, `profile.schemaVersion`.** The lift is a per-profile mutation, so the account-wide stamp cannot gate it: a user with "Default" and "Raid" both pre-v3 who upgrades while on Default would migrate Default, flip the account-wide stamp to 3, and strand Raid's flat keys forever. This is a recorded, deliberate deviation from Ka0s standard savedvariables-§1 (which puts the stamp account-wide) — see the **Documented deviations** register in [ARCHITECTURE.md](./ARCHITECTURE.md). The account-wide stamp still exists and still drives the v2 step.
- **The per-profile default is `1`, not `3`.** `copyDefaults` fills every absent key before `RunMigrations` reads the profile, so a default of `3` would stamp every pre-v3 profile as already-migrated on first touch — the exact failure mode the `units == nil` guard had. A default of `1` makes an unstamped profile read as what it is: pre-v3.

### Where the lift is applied

Two mechanisms, composing on the one stamp so they cannot double-apply:

| When | What it covers |
|------|----------------|
| `NS:InitDB` → `RunMigrations` → `migrateAllProfiles` | The active profile, **plus every profile in the raw saved store** (`db.sv.profiles`, AceDB's name → profile-table map), before the account-wide stamp flips to 3. The `db.sv` lookup is guarded, so the no-AceDB fallback — which has no such store — simply migrates its single profile. |
| `NS.OnProfileChanged` | Any profile that only *appears* after that sweep: copied in from another character, restored from a backup SavedVariables file, or reset back to defaults. Lifted the moment it becomes active. |

`MigrateProfileToV3` returns `false` immediately for a profile that already carries the stamp, so running both is a no-op on the second pass; it also returns `false` when it stamped a profile that had nothing to move, which is what keeps the `[Migrate]` count honest. `tests/test_database.lua` covers all three cases — two pre-v3 profiles both lifted at `InitDB`, a profile appearing after the upgrade lifted on profile change, and proof the two do not double-apply.

## Bar position is per-profile *and* per-unit

Each bar's saved position lives at `db.profile.units.<unit>.position = { point, relPoint, x, y }`, read and written only through `NS.Units.Position` / `NS.Units.SetPosition` (`core/Units.lua`). It is **not** a schema row — it is written by dragging — and it is **never mirrored**: a mirrored position would stack all three bars on one spot, so `position` (like `enabled`) stays per-unit even while a unit mirrors the player's appearance.

There is no flat `db.profile.position` any more; the v3 lift moves the pre-v3 key to `units.player.position` and deletes it.

Switching profiles re-applies each unit's new `position` — or centers that bar at its stacked default when the new profile has none — via the `MSG.POSITION` fan-out to `RestoreBarPosition(unit)`. That is the entire reason `POSITION` leads the `OnProfileChanged` refresh chain: without it, switching profiles would update colors / sizes / textures but leave every bar at the old position.

Clearing positions goes through **one** implementation, `Helpers.ResetAllPositions` (`settings/UnitPanel.lua`): it calls `NS.Units.SetPosition(unit, nil)` for every unit in `NS.Units.LIST` and republishes `MSG.POSITION`. All three entry points delegate to it — `/at resetposition` (`settings/Slash.lua`), the **Reset Position** button on the General page (`settings/General.lua`), and `Helpers.RestoreAllDefaults`, which backs both `/at resetall` and the Reset All Settings popup and reaches it through the descriptor's `afterRestoreAll` hook (`settings/OptionsSetup.lua`), fired after the rows are reset and before the panels refresh. That hook exists at all because `position` is written by dragging, not by a schema row, so `ApplyDefault` never touches it. They diverged here once: the panel button used to nil the pre-v3 flat `db.profile.position`, a key the v3 migration deletes, so it cleared an already-nil key and every bar re-anchored from its untouched `units.<unit>.position` — a silent no-op. Do not re-inline the loop at any call site.

## See also

- [data-flow.md](./data-flow.md) — the full bootstrap, absorb-update, and profile-change sequences.
- [settings-panel.md](./settings-panel.md) — the canvas panel shell and how `RefreshOptionsPanel` repaints widgets.
- [schema.md](./schema.md) — the schema registry that drives `/at list/get/set` and the panels.
- [scope.md](./scope.md) — the "position is per-profile" resolved decision.
