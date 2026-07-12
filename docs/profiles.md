# Profiles

AceDB-3.0 integration, the `/at profile` subcommand surface, and the fallback shim used when AceDB-3.0 is missing.

## AceDB integration

AceDB is an optional dependency; the lib ships in-tree under `libs/Ace3/AceDB-3.0/`, so in practice it's always present. The bootstrap path lives in `Events.lua`'s PLAYER_LOGIN handler:

```lua
local AceDB = LibStub("AceDB-3.0", true)
if AceDB then
    NS.db = AceDB:New("AbsorbTrackerDB", NS.defaults, true)
    NS.db.RegisterCallback(NS, "OnProfileChanged", NS.OnProfileChanged)
    NS.db.RegisterCallback(NS, "OnProfileCopied",  NS.OnProfileChanged)
    NS.db.RegisterCallback(NS, "OnProfileReset",   NS.OnProfileChanged)
else
    -- fallback shim (see below)
end
```

The third arg to `AceDB:New` is `defaultProfile` — `true` means use the WoW-supplied `"Default"` shared across characters. Every character on the account starts on `Default`, so changes carry over to every other character out of the box. Opt into per-character / per-class / per-realm scope from the Profiles panel if a character should diverge.

## OnProfileChanged refresh chain

All three AceDB callbacks (`OnProfileChanged`, `OnProfileCopied`, `OnProfileReset`) wire into the same handler:

```
NS.OnProfileChanged()
    │
    ├─▶ RestoreBarPosition()              -- new profile may have a different saved position
    ├─▶ UpdateBarAppearance()             -- size, textures, colors, border, font
    ├─▶ UpdateAbsorbBar()                 -- repaint absorb value against new profile
    │
    ├─▶ ResetTickerInterval()             -- force the next call to rebuild
    ├─▶ RestartUpdateTicker(true)         -- new profile's interval takes effect
    │
    └─▶ RefreshOptionsPanel()             -- routes to Helpers.RefreshAllPanels
```

`ResetTickerInterval` matters because `RestartUpdateTicker` short-circuits when the tracked interval is unchanged — without the reset, switching from `1.0s` → `0.5s` and back to `1.0s` in one session wouldn't trigger a real ticker rebuild on the second switch. Clearing the tracked interval forces the next call to start from scratch.

`RefreshOptionsPanel` routes to `Helpers.RefreshAllPanels`, which walks every panel ctx and runs every refresher closure registered by the widget makers. Each refresher re-reads its row's value from the (newly active) `db.profile` and pushes it into its AceGUI widget. The Profiles sub-page itself uses `AceConfigDialog:Open(...)` and re-pulls on its own next show. See [settings-panel.md](./settings-panel.md#profile-change-refresh).

## `/at profile` subcommands

| Verb | Effect |
|------|--------|
| `/at profile list` | List all profiles in `AbsorbTrackerDB.profiles`, marking the active one. |
| `/at profile current` | Print the active profile name. |
| `/at profile use <name>` | Switch to `<name>`. Creates it (with default settings) if it doesn't exist. Fires `OnProfileChanged`. |
| `/at profile new <name>` | Create `<name>` with default settings AND switch to it. (`db:SetProfile(name)` then `db:ResetProfile()`.) |
| `/at profile copy <name>` | Copy `<name>`'s settings into the active profile. Fires `OnProfileCopied`. |
| `/at profile delete <name>` | Delete `<name>`. Refuses if `<name>` is the active profile. |
| `/at profile reset` | Reset the active profile to defaults. Fires `OnProfileReset`. |

All seven verbs delegate to AceDB's `NS.db:SetProfile / CopyProfile / DeleteProfile / ResetProfile / GetProfiles / GetCurrentProfile`. The Profiles sub-page (`settings/Profiles.lua`) wraps `AceDBOptions:GetOptionsTable(NS.db)`, which presents the same operations as a UI.

## Fallback shim (no AceDB)

If `LibStub("AceDB-3.0", true)` returns nil — only possible if `libs/Ace3/AceDB-3.0/` was tampered with — `Events.lua` builds a minimal stand-in:

```lua
NS.db = { profile = AbsorbTrackerDB or {} }
AbsorbTrackerDB = NS.db.profile

-- Seed missing keys from flatDefaults so GetSetting reads succeed.
for k, v in pairs(NS.flatDefaults) do
    if NS.db.profile[k] == nil then
        NS.db.profile[k] = v
    end
end
```

In this mode:

- `GetSetting` / `SetSetting` work normally — they read / write `db.profile` like in the AceDB case.
- **Profile management is disabled.** `/at profile` subcommands print an error; `settings/Profiles.lua`'s builder returns `nil` so the Profiles sub-page is skipped at registration.
- `OnProfileChanged` is never fired (no callbacks registered, no profile switching path).
- The single profile lives directly in `AbsorbTrackerDB`; the AceDB-shaped `profiles` / `profileKeys` / `char` keys don't exist.

The shim is documented for completeness; it is not exercised in practice because AceDB ships in-tree.

## Bar position is per-profile

The saved bar position lives at `db.profile.position = { point, relPoint, x, y }`. Switching profiles re-applies the new profile's `position` (or centers the bar via `RestoreBarPosition` if the new profile has none). The `/at resetposition` slash command and the Reset Position execute button on the General page both clear the active profile's `position` and re-center.

This is the entire reason `RestoreBarPosition` is in the OnProfileChanged refresh chain — without it, switching profiles would update colors / sizes / textures but leave the bar at the old position.

## See also

- [data-flow.md](./data-flow.md#profile-change-refresh) — the full refresh sequence.
- [settings-panel.md](./settings-panel.md#profile-change-refresh) — `AceConfigRegistry:NotifyChange` mechanics.
- [scope.md](./scope.md#resolved-decisions) — "position is per-profile" decision.
