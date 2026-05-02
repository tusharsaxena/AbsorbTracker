# Settings panel

How the addon registers its multi-page Blizzard Settings UI. The schema-driven content of each page is documented in [schema.md](./schema.md); this doc is about the *registration shell* — `OptionsPanel.lua` plus the per-page `Options/<page>.lua` declarations.

## Five pages under one parent

```
┌─ Ka0s Absorb Tracker (empty title-only parent) ┐
│   ├─ General  (default — /at config opens here)│
│   ├─ Bar                                       │
│   ├─ Border                                    │
│   ├─ Font                                      │
│   └─ Profiles  (only if AceDBOptions is present)│
└────────────────────────────────────────────────┘
```

The parent uses `appName = "AbsorbTracker"` and is registered against an options table with `args = {}` — AceConfigDialog still needs *some* table to attach the canvas frame to, but a zero-args group renders as just the title bar with an empty body, which is the desired look. Every `Options/*.lua` file becomes a sub-page; **the parent never holds settings of its own.**

Each sub-page uses `appName = "AbsorbTracker-<key>"` so each page has its own AceConfig namespace. This matters for `AceConfigRegistry:NotifyChange` — see [profile change refresh](#profile-change-refresh) below.

## File-load registration vs. PLAYER_LOGIN registration

`OptionsPanel.lua` runs at file-load time (early), but `AddonTable.db` doesn't exist until PLAYER_LOGIN. The shell separates the two phases:

1. **File-load.** Each `Options/<page>.lua` calls `RegisterOptionsPage(key, name, builder, opts?)` to enqueue itself. The builder is a closure that will run later. The page is *queued*, not registered.
2. **PLAYER_LOGIN.** `Events.lua` calls `AddonTable.CreateOptionsPanel()`, which:
   - Registers the empty title-only "Ka0s Absorb Tracker" parent category.
   - Walks the queue, calling `builder()` on each entry (which now sees a live `db` because PLAYER_LOGIN has run).
   - For each page: `AceConfig:RegisterOptionsTable("AbsorbTracker-<key>", optionsTable)` followed by `AceConfigDialog:AddToBlizOptions("AbsorbTracker-<key>", name, "Ka0s Absorb Tracker")`.
   - Captures the parent's category ID (the second return value of the parent's `AddToBlizOptions`) and each sub-page's category ID for `OpenOptionsPanel`.

If a builder returns `nil` (e.g. `Options/Profiles.lua` when AceDBOptions is missing), `registerPage` skips that page silently.

## `RegisterOptionsPage(key, name, builder, opts)`

```lua
AddonTable.RegisterOptionsPage("bar", "Bar", function()
    return AddonTable.BuildPageOptions("bar", "Bar")
end)

-- or, with an isDefault flag
AddonTable.RegisterOptionsPage("general", "General", buildGeneral, { isDefault = true })
```

- `key` — short identifier used in the per-page `appName` (`"AbsorbTracker-<key>"`) and in error logging.
- `name` — display name shown in the Blizzard Settings tree.
- `builder` — `() -> AceConfig options table`. Called once at PLAYER_LOGIN. Must return `nil` to skip registration.
- `opts.isDefault = true` — flags the page that `/at config` should open. Typically `General`. If no page is flagged, `OpenOptionsPanel` falls back to the empty parent.

## `BuildPageOptions(pageKey, pageName)`

Each page's typical builder is one line:

```lua
local function build()
    return AddonTable.BuildPageOptions("bar", "Bar")
end
```

`Schema.BuildPageOptions` walks `AddonTable.Schema`, filters to rows where `row.page == pageKey`, groups rows by `row.group` (rows with the same `group` cluster into an inline AceConfig group), sorts within each group by `row.order`, and returns a ready-to-register AceConfig options table. The widget's `get` callback reads via `AddonTable.GetSetting`; the `set` callback writes via `SetSetting` and then fires the row's `onChange`. Slash `/at set` follows the same write path through `AddonTable.SetByPath`, so panel-driven and slash-driven writes converge.

For pages that need a non-schema element (e.g. Reset Position is an action button, not a schema row), the builder closure can append it manually:

```lua
local function build()
    local opts = AddonTable.BuildPageOptions("general", "General")
    opts.args.position = {
        type = "group", inline = true, name = "Position", order = 99,
        args = {
            reset = { type = "execute", name = "Reset Position",
                      func = AddonTable.RestoreBarPosition },
        },
    }
    return opts
end
```

## Profile change refresh

When AceDB fires `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset`, the active profile flips. Closure-based widget `get` / `set` callbacks already read live from `db.profile`, so the underlying values are correct as soon as `db.profile` flips — but the on-screen widgets show stale values until `AceConfigDialog` is told to re-pull.

`RefreshOptionsPanel` does that:

```lua
function AddonTable.RefreshOptionsPanel()
    for _, key in ipairs(REGISTERED_KEYS) do
        AceConfigRegistry:NotifyChange("AbsorbTracker-" .. key)
    end
end
```

This is called from `OnProfileChanged` (after `RestoreBarPosition` + `UpdateBarAppearance` + `UpdateAbsorbBar` + `ResetTickerInterval` + `RestartUpdateTicker(true)`). Per-page `appName` matters: `NotifyChange` is per-namespace, so calling it on the parent appName wouldn't refresh sub-pages.

## `OpenOptionsPanel` and the combat-lockdown gate

```lua
function AddonTable.OpenOptionsPanel()
    if InCombatLockdown() then
        AddonTable.Print("settings panel is unavailable during combat")
        return
    end
    Settings.OpenToCategory(defaultCategoryID or parentCategoryID)
end
```

`Settings.OpenToCategory` is part of Blizzard's protected Settings API. Calling it during combat would taint the panel — even after combat ends, the tainted panel can refuse to open or break unrelated UI. The combat-lockdown early-return is mandatory; don't try to clever-defer the call.

`defaultCategoryID` is the sub-page flagged `isDefault = true` (typically General). If no default was registered, falls back to `parentCategoryID` — but that's the empty title-only parent, so the user lands on a blank canvas. Always flag *some* page as the default.

## LSM swatch dropdowns

Texture / border / font select fields use `dialogControl = "LSM30_Statusbar"` (or `_Border` / `_Font`) on their schema row. AceConfigDialog routes those to a custom in-tree AceGUI widget at `libs/Ace3/AceGUI-3.0-SharedMediaWidgets/widget.lua`, which renders each entry with an inline preview swatch:

- `LSM30_Statusbar` — fill texture preview.
- `LSM30_Border` — border style preview.
- `LSM30_Font` — font face preview.

The widget builds a Blizzard-frame button + popup list and renders the swatch beside each entry. The widget type names match the upstream `AceGUI-3.0-SharedMediaWidgets` lib so dropping in the real lib later is a clean swap. Dropdowns with 10 or more items show a scrollbar; opening a dropdown auto-scrolls to the currently selected value.

## See also

- [schema.md](./schema.md) — what the per-page builders return.
- [profiles.md](./profiles.md) — how profile changes drive `RefreshOptionsPanel`.
- [midnight-quirks.md](./midnight-quirks.md#aceconfigdialogaddtoblizoptions-returns-frame-categoryid) — the two-return-value contract on `AceConfigDialog:AddToBlizOptions`.
