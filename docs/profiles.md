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

Defaults come from `defaults/Profile.lua`: `NS.defaults.profile` (per-bar appearance + `position`), `NS.defaults.global.schemaVersion = 1` (account-wide DB-version stamp), and `NS.flatDefaults` as a flat alias of `NS.defaults.profile` used by the fallback read path and the Options pages.

## OnProfileChanged refresh chain

All three AceDB callbacks (`OnProfileChanged`, `OnProfileCopied`, `OnProfileReset`) wire into the same handler, `NS.OnProfileChanged`, defined in `core/AbsorbTracker.lua`:

```
NS.OnProfileChanged()
    │
    ├─▶ RestoreBarPosition()       -- new profile may have a different saved position
    ├─▶ UpdateBarAppearance()      -- size, textures, colors, border, font
    ├─▶ UpdateAbsorbBar()          -- repaint absorb value against new profile
    │
    ├─▶ ResetTickerInterval()      -- force the next call to rebuild
    ├─▶ RestartUpdateTicker(true)  -- new profile's interval takes effect
    │
    └─▶ RefreshOptionsPanel()      -- push new values into an open settings panel
```

`ResetTickerInterval` matters because `RestartUpdateTicker` short-circuits when the tracked interval is unchanged — without the reset, switching from `1.0s` → `0.5s` and back to `1.0s` in one session wouldn't trigger a real ticker rebuild on the second switch. Clearing the tracked interval forces the next call to start from scratch. (The ticker is an AceTimer repeating timer; see [data-flow.md](./data-flow.md).)

`RefreshOptionsPanel` re-reads each row's value from the newly active `db.profile` and pushes it into its AceGUI widget. The Profiles sub-page itself re-`Open()`s its AceConfigDialog tree on next show, so it reflects the current profile after a switch. See [settings-panel.md](./settings-panel.md).

## `/at profile` subcommands

Handled by `runProfile` in `settings/Slash.lua` (registered via AceConsole as part of the ordered `NS.COMMANDS` table — no `SLASH_*` globals). Bare `/at profile` prints the subcommand list.

| Verb | Effect |
|------|--------|
| `/at profile list` | List all profiles from `db:GetProfiles()`, marking the current one. |
| `/at profile current` | Print the active profile name (`db:GetCurrentProfile()`). |
| `/at profile use <name>` | Switch to `<name>` via `db:SetProfile(name)` (AceDB creates it if absent). Fires `OnProfileChanged`. |
| `/at profile new <name>` | Create `<name>` with default settings AND switch to it (`db:SetProfile(name)` then `db:ResetProfile()`). |
| `/at profile copy <name>` | Copy `<name>`'s settings into the active profile (`db:CopyProfile`). Fires `OnProfileCopied`. |
| `/at profile delete <name>` | `db:DeleteProfile(name, true)`. Refuses if `<name>` is the active profile. |
| `/at profile reset` | Reset the active profile to defaults (`db:ResetProfile()`). Fires `OnProfileReset`. |

The whole subcommand delegates to AceDB's `SetProfile / CopyProfile / DeleteProfile / ResetProfile / GetProfiles / GetCurrentProfile`. `runProfile` first checks `if not db or not db.SetProfile` and prints `Profile system requires AceDB-3.0` when that method is absent (the fallback path). An unrecognized subcommand prints `Unknown profile subcommand '<sub>'` then re-prints the list.

The Profiles sub-page (`settings/Profiles.lua`) wraps `AceDBOptions:GetOptionsTable(NS.db)` and renders it into a canvas panel via `AceConfigDialog:Open`, presenting the same create / switch / copy / reset / delete operations plus the scope dropdowns as a UI.

## Fallback shim (no AceDB)

If `LibStub("AceDB-3.0", true)` returns nil — only possible if `libs/AceDB-3.0/` was tampered with — `NS:InitDB` builds a minimal stand-in backed by the raw SavedVariables global:

```lua
AbsorbTrackerDB = AbsorbTrackerDB or {}
NS.db = { profile = AbsorbTrackerDB, global = {} }
```

`NS:RunMigrations` then does the flat→profile backfill (see below), so `db.profile` ends up carrying every default key. In this mode:

- `GetSetting` / `SetSetting` (`core/Data.lua`) work normally — they read / write `db.profile`, falling back to `NS.flatDefaults` for any still-missing key.
- **Profile management is disabled.** `/at profile` short-circuits on the missing `db.SetProfile` and prints `Profile system requires AceDB-3.0`. `settings/Profiles.lua`'s builder returns `nil` (its `LibStub("AceDBOptions-3.0", true)` / AceConfigDialog / AceGUI guards fail) so the Profiles sub-page is skipped at registration.
- `OnProfileChanged` is never fired — no callbacks are registered (the `RegisterCallback` block is inside the AceDB branch).
- The single profile lives directly in `AbsorbTrackerDB`; the AceDB-shaped `profiles` / `profileKeys` / `char` keys don't exist. `db.global` is an ephemeral empty table, so `schemaVersion` isn't persisted across sessions.

The shim isn't exercised in-game (AceDB ships in-tree), but the migration/backfill path it feeds is covered by the headless harness (`tests/test_database.lua`).

## Migrations and the flat→profile backfill

`NS:RunMigrations` (`core/Database.lua`) is the single idempotent schema-upgrade seam, invoked once at the end of `InitDB`:

```lua
function NS:RunMigrations()
    local g = NS.db and NS.db.global
    if not g then return end
    g.schemaVersion = g.schemaVersion or 1

    local profile = NS.db.profile
    if profile then
        for key, defaultVal in pairs(NS.flatDefaults) do
            if profile[key] == nil then
                -- table defaults deep-copied so a saved-var mutation can't corrupt flatDefaults
                ...
                profile[key] = <copy or value>
            end
        end
    end
end
```

The v1 step stamps `db.global.schemaVersion = 1` and backfills any missing `profile` key from `NS.flatDefaults`. This one versioned step absorbs both the legacy pre-AceDB flat-SavedVariables shape (the old inline migration) and the no-AceDB fallback: keys already present are left untouched, so running it twice is a no-op. Table defaults (e.g. `barColor`) are shallow-copied into a fresh table so an in-place mutation of a saved variable can't reach back and corrupt `flatDefaults`. It is a safe no-op when the DB is absent (no `db.global` to touch).

Future schema changes hook the same function: `if g.schemaVersion < 2 then ...; g.schemaVersion = 2 end`.

## Bar position is per-profile

The saved bar position lives at `db.profile.position = { point, relPoint, x, y }`. Switching profiles re-applies the new profile's `position` (or centers the bar via `RestoreBarPosition` if the new profile has none). The `/at resetposition` slash command (`runResetPosition`) and `/at resetall` (`runResetAll`) both clear the active profile's `position` and re-center; the Reset Position execute button on the General page does the same.

This is the entire reason `RestoreBarPosition` leads the `OnProfileChanged` refresh chain — without it, switching profiles would update colors / sizes / textures but leave the bar at the old position.

## See also

- [data-flow.md](./data-flow.md) — the full bootstrap, absorb-update, and profile-change sequences.
- [settings-panel.md](./settings-panel.md) — the canvas panel shell and how `RefreshOptionsPanel` repaints widgets.
- [schema.md](./schema.md) — the schema registry that drives `/at list/get/set` and the panels.
- [scope.md](./scope.md) — the "position is per-profile" resolved decision.
