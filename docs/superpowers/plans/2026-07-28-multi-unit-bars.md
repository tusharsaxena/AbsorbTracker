# Multi-Unit Absorb Bars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this
> plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Target and Focus absorb bars alongside the existing Player bar, with every appearance
setting per-unit behind a Unit dropdown, a live "mirror Player" link, and a one-shot "copy from
Player" snapshot.

**Architecture:** A new `core/Units.lua` owns unit identity and mirror resolution — it is the only
file that reads `db.profile.units` for appearance. `modules/Bar.lua` becomes a three-call factory;
every `modules/Display.lua` function takes a unit and the bus handlers drive all three via
`NS.ForEachUnit`. Schema rows for the three appearance pages are generated per unit with dotted
paths (`units.target.barWidth`), and `Helpers.RenderUnitPanel` draws the dropdown + mirror header.

**Tech Stack:** Lua 5.1 (WoW client), Ace3 (AceAddon/AceEvent/AceTimer/AceConsole/AceDB/AceGUI/
AceConfig), LibSharedMedia-3.0. Headless test harness in `tests/` run with `lua tests/run.lua`;
lint with `luacheck .`.

**Spec:** `docs/superpowers/specs/2026-07-28-multi-unit-bars-design.md`

**Branch:** `feature/multi-unit-bars` (already created).

## Global Constraints

- **Ka0s WoW Addon Standard compliance is mandatory.** If a change would deviate, STOP and flag it
  rather than silently deviating or silently "fixing" to match. See `CLAUDE.md`.
- **Green gate before every commit:** `lua tests/run.lua` (0 failed) and `luacheck .` (0 warnings,
  0 errors). Syntax-check a single file with `luac -p <file>`.
- **Committing is authorized for this branch only.** `CLAUDE.md` and `docs/agent-context.md`
  normally forbid auto-staging/committing; the user granted explicit authorization for
  `feature/multi-unit-bars` on 2026-07-28. So: **do** run each task's Commit step, staging only the
  files that task names. Still **never push**, never open a PR, and never commit on any other
  branch. Each task's Commit step is written "only on explicit instruction" — that instruction has
  been given; treat those steps as active.
- **Never bump the version.** The TOC `## Version: 1.9.0`, the README badges, and the changelog
  version rows stay untouched by this work.
- **Retail Midnight only** — Interface 120007, no game-flavor branching. English only; do not add
  new locale wrapping.
- **Secret-value discipline.** `UnitGetTotalAbsorbs` may return a secret. Pass it straight to
  `AbbreviateNumbers` / `StatusBar:SetValue`. Never `tonumber` it, never compare it, never
  boolean-test it.
- **No raw `print`.** Files that emit chat do `local print = NS.Print`.
- **Deep-copy every table default.** Two profiles must never share a nested table.
- **Unit order is always `NS.Units.LIST` = `{ "player", "target", "focus" }`.**
- **The fifteen appearance keys** (used verbatim throughout): `barWidth`, `barHeight`,
  `barTexture`, `barColor`, `useClassColorBar`, `bgTexture`, `bgColor`, `useClassColorBg`,
  `border`, `borderSize`, `borderColor`, `useClassColorBorder`, `font`, `fontSize`, `fontFlags`.
- **The four global keys:** `hidden`, `locked`, `showOnlyInCombat`, `throttleWindow`.

---

## File Structure

| File | Change | Responsibility after the change |
|---|---|---|
| `core/Units.lua` | **Create** | Unit identity, mirror resolution, per-unit config/position reads and writes, copy-from-player. |
| `defaults/Profile.lua` | Modify | Globals flat; the three units under `profile.units`. Publishes `NS.flatDefaults` (globals) and `NS.unitDefaults` (player's appearance block, for schema `default =` fields). |
| `core/Database.lua` | Modify | v2 → v3 migration; units-aware backfill. |
| `core/Data.lua` | Modify | Media/color getters take a unit and read through `Units.Get`. Class-color resolvers unchanged. |
| `settings/Schema.lua` | Modify | Dotted-path resolve/set, unit-filtered `SchemaForPage`, dotted-path validation, `PartitionUnitRows`. |
| `modules/Bar.lua` | Modify | `NS.CreateBar(unit, globalName)` factory; `NS.bars`; per-frame `backdropInfo`. |
| `modules/Display.lua` | Modify | Every function takes a unit; `NS.ForEachUnit`; the five-step visibility ladder; stacked default positions. |
| `core/AbsorbTracker.lua` | Modify | Two private unit-event frames; `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED`. |
| `settings/{Bar,Border,Font}.lua` | Modify | Per-unit row generation; builders call `RenderUnitPanel`. |
| `settings/Helpers.lua` | Modify | `RenderUnitPanel`, `ClearScroll`, `RerenderUnitPanel`; all-unit resets. |
| `settings/Slash.lua` | Modify | Dotted paths, unit-grouped `/at list`, all-unit resets, `/at test` across enabled bars. |
| `AbsorbTracker.toc` | Modify | Add `core\Units.lua`. |
| `tests/wow_mock.lua` | Modify | `UnitExists`, per-unit absorb/health. |
| `tests/test_units.lua` | **Create** | Mirror resolution, copy semantics, enable gating. |
| `tests/run.lua` | Modify | Register `core/Units.lua` and `test_units`. |
| `tests/test_{display,schema,database,slashcmds,helpers}.lua` | Modify | Per-unit coverage. |
| `docs/*`, `README.md` | Modify | Per §11 of the spec. |

---

### Task 1: Unit identity, defaults, and the v3 migration

**Files:**
- Create: `core/Units.lua`
- Create: `tests/test_units.lua`
- Modify: `defaults/Profile.lua` (whole file)
- Modify: `core/Database.lua:34-61` (`NS:RunMigrations`)
- Modify: `AbsorbTracker.toc` (Core block)
- Modify: `tests/run.lua:28-38` (source list), `tests/run.lua:73-86` (test list)
- Test: `tests/test_units.lua`, `tests/test_database.lua`

**Interfaces:**
- Consumes: nothing (first task).
- Produces:
  - `NS.Units.LIST` = `{ "player", "target", "focus" }` (array of string)
  - `NS.Units.LABEL` = `{ player = "Player", target = "Target", focus = "Focus" }`
  - `NS.Units.Config(unit) -> table|nil`
  - `NS.Units.IsEnabled(unit) -> boolean`
  - `NS.Units.IsMirrored(unit) -> boolean`
  - `NS.Units.SourceUnit(unit) -> string`
  - `NS.Units.Get(unit, key) -> any`
  - `NS.Units.Set(unit, key, value)`
  - `NS.Units.Position(unit) -> table|nil`
  - `NS.Units.SetPosition(unit, pos)`
  - `NS.Units.CopyFromPlayer(unit)`
  - `NS.Units.APPEARANCE_KEYS` (array of the fifteen key names)
  - `NS.unitDefaults` — alias for `NS.defaults.profile.units.player`
  - `NS.flatDefaults` — unchanged alias for `NS.defaults.profile` (now holds globals + `units`)

- [ ] **Step 1: Write the failing test**

Create `tests/test_units.lua`:

```lua
local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- core/Units.lua — unit identity and the mirror seam. Every appearance read in the addon goes
-- through Units.Get, so these tests pin the mirror resolution that the rest of the addon trusts.

local function withUnits(body)
  -- Snapshot and restore the whole units table so one test's mutation can't leak into the next.
  local saved = {}
  for _, u in ipairs(NS.Units.LIST) do
    local c, copy = NS.db.profile.units[u], {}
    for k, v in pairs(c) do
      if type(v) == "table" then
        local t = {}
        for kk, vv in pairs(v) do t[kk] = vv end
        copy[k] = t
      else
        copy[k] = v
      end
    end
    saved[u] = copy
  end
  local ok, err = pcall(body)
  for _, u in ipairs(NS.Units.LIST) do NS.db.profile.units[u] = saved[u] end
  if not ok then error(err) end
end

test("LIST is player, target, focus in render order", function()
  assertEqual(NS.Units.LIST[1], "player")
  assertEqual(NS.Units.LIST[2], "target")
  assertEqual(NS.Units.LIST[3], "focus")
  assertEqual(#NS.Units.LIST, 3)
end)

test("Get reads the unit's own value when it is not mirrored", function()
  withUnits(function()
    NS.db.profile.units.target.mirror = false
    NS.db.profile.units.target.barWidth = 321
    NS.db.profile.units.player.barWidth = 200
    assertEqual(NS.Units.Get("target", "barWidth"), 321)
  end)
end)

test("Get resolves to the player's value when the unit is mirrored", function()
  withUnits(function()
    NS.db.profile.units.focus.mirror = true
    NS.db.profile.units.focus.barWidth = 321
    NS.db.profile.units.player.barWidth = 200
    assertEqual(NS.Units.Get("focus", "barWidth"), 200,
      "a mirrored unit must ignore its own stored value")
  end)
end)

test("player is never mirrored even if a mirror key is force-written", function()
  withUnits(function()
    NS.db.profile.units.player.mirror = true
    assertEqual(NS.Units.IsMirrored("player"), false)
    assertEqual(NS.Units.SourceUnit("player"), "player")
  end)
end)

test("Position is never mirror-resolved", function()
  withUnits(function()
    NS.db.profile.units.focus.mirror = true
    NS.db.profile.units.player.position = { point = "TOP", relPoint = "TOP", x = 1, y = 2 }
    NS.db.profile.units.focus.position  = { point = "LEFT", relPoint = "LEFT", x = 3, y = 4 }
    assertEqual(NS.Units.Position("focus").point, "LEFT",
      "mirroring styling must not drag the position along")
  end)
end)

test("SetPosition writes the unit's own position while mirrored", function()
  withUnits(function()
    NS.db.profile.units.target.mirror = true
    NS.Units.SetPosition("target", { point = "BOTTOM", relPoint = "BOTTOM", x = 5, y = 6 })
    assertEqual(NS.db.profile.units.target.position.y, 6)
    assertEqual(NS.db.profile.units.player.position, nil)
  end)
end)

test("CopyFromPlayer snapshots every appearance key and clears the mirror", function()
  withUnits(function()
    NS.db.profile.units.player.barWidth = 275
    NS.db.profile.units.player.fontSize = 19
    NS.db.profile.units.focus.mirror = true
    NS.Units.CopyFromPlayer("focus")
    assertEqual(NS.db.profile.units.focus.mirror, false)
    assertEqual(NS.db.profile.units.focus.barWidth, 275)
    assertEqual(NS.db.profile.units.focus.fontSize, 19)
  end)
end)

test("a copied unit does not track later player changes", function()
  withUnits(function()
    NS.db.profile.units.player.barWidth = 275
    NS.db.profile.units.focus.mirror = true
    NS.Units.CopyFromPlayer("focus")
    NS.db.profile.units.player.barWidth = 400
    assertEqual(NS.Units.Get("focus", "barWidth"), 275, "copy is a snapshot, not a link")
  end)
end)

test("CopyFromPlayer deep-copies color tables rather than sharing them", function()
  withUnits(function()
    NS.Units.CopyFromPlayer("target")
    NS.db.profile.units.target.barColor.r = 0.11
    assertTrue(NS.db.profile.units.player.barColor.r ~= 0.11,
      "a shared table would let one unit's color picker repaint another bar")
  end)
end)

test("CopyFromPlayer leaves position and enabled alone", function()
  withUnits(function()
    NS.db.profile.units.target.enabled = true
    NS.db.profile.units.target.position = { point = "TOP", relPoint = "TOP", x = 7, y = 8 }
    NS.db.profile.units.player.position = { point = "LEFT", relPoint = "LEFT", x = 0, y = 0 }
    NS.Units.CopyFromPlayer("target")
    assertEqual(NS.db.profile.units.target.enabled, true)
    assertEqual(NS.db.profile.units.target.position.x, 7)
  end)
end)

test("CopyFromPlayer is a no-op for the player itself", function()
  withUnits(function()
    NS.db.profile.units.player.barWidth = 275
    NS.Units.CopyFromPlayer("player")
    assertEqual(NS.db.profile.units.player.barWidth, 275)
  end)
end)

test("IsEnabled reads the per-unit flag and ignores the global hidden toggle", function()
  withUnits(function()
    local savedHidden = NS.db.profile.hidden
    NS.db.profile.hidden = true
    NS.db.profile.units.target.enabled = true
    assertEqual(NS.Units.IsEnabled("target"), true,
      "the global master toggle is composed in ShouldShowBar, not here")
    NS.db.profile.units.target.enabled = false
    assertEqual(NS.Units.IsEnabled("target"), false)
    NS.db.profile.hidden = savedHidden
  end)
end)

test("target and focus ship disabled so an upgrade changes nothing on screen", function()
  assertEqual(NS.defaults.profile.units.player.enabled, true)
  assertEqual(NS.defaults.profile.units.target.enabled, false)
  assertEqual(NS.defaults.profile.units.focus.enabled, false)
end)

test("target and focus ship mirrored so a first enable looks like the player bar", function()
  assertEqual(NS.defaults.profile.units.target.mirror, true)
  assertEqual(NS.defaults.profile.units.focus.mirror, true)
  assertEqual(NS.defaults.profile.units.player.mirror, nil, "player is the mirror source")
end)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `lua tests/run.lua`
Expected: the run aborts or `test_units` fails — `NS.Units` is nil, so `NS.Units.LIST` raises
`attempt to index field 'Units' (a nil value)`.

- [ ] **Step 3: Rewrite `defaults/Profile.lua`**

Replace the whole file:

```lua
local addonName, NS = ...

-- AceDB defaults. Bar appearance is PER UNIT (player / target / focus) under `profile.units`;
-- the four master toggles stay flat at the profile root because they govern all three bars.
-- The persisted-DB schema-version stamp lives under `global` (account-wide) so NS:RunMigrations
-- has a single version to walk regardless of the active profile (Ka0s standard §5.1).
NS.defaults = NS.defaults or {}

-- The per-unit appearance block. Built by a factory so each unit gets its OWN tables — sharing
-- one literal across three units would make a color picker on the target bar repaint the player's.
local function appearance()
    return {
        barTexture = "Blizzard Raid Bar",
        bgTexture = "Blizzard Raid Bar",
        border = "Blizzard Tooltip",
        borderSize = 12,
        borderColor = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 },
        font = "Friz Quadrata TT",
        fontSize = 12,
        fontFlags = "OUTLINE",
        barWidth = 200,
        barHeight = 20,
        barColor = { r = 0.4, g = 0.7, b = 1.0, a = 0.8 },
        bgColor = { r = 0.2, g = 0.2, b = 0.2, a = 0.8 },
        useClassColorBar = false,
        useClassColorBg = false,
        useClassColorBorder = false,
        position = nil,
    }
end

local function unit(enabled, mirror)
    local t = appearance()
    t.enabled = enabled
    t.mirror = mirror
    return t
end

NS.defaults.profile = {
    -- Globals: one value shared by all three bars.
    locked = false,
    hidden = false,
    throttleWindow = 0.1,
    showOnlyInCombat = false,

    -- Per-unit. Player has no `mirror` key — it is the mirror SOURCE, so a player mirror row
    -- would be circular. Target and Focus ship disabled (an upgrade changes nothing on screen)
    -- but mirrored (a first enable looks like the player bar, not raw factory defaults).
    units = {
        player = unit(true, nil),
        target = unit(false, true),
        focus  = unit(false, true),
    },
}

NS.defaults.global = {
    -- Persisted-DB schema version. NS:RunMigrations (core/Database.lua) reads/writes this once
    -- at init — the idempotent seam future schema changes hook into. v3 introduced profile.units.
    schemaVersion = 3,
}

-- Flat alias for the no-AceDB fallback path: GetSetting reads this when NS.db is absent. It now
-- carries the four globals plus the `units` table.
NS.flatDefaults = NS.defaults.profile

-- Per-unit default alias. settings/{Bar,Border,Font}.lua read each row's `default =` from here,
-- so every unit's rows share one canonical default regardless of which unit generated them.
NS.unitDefaults = NS.defaults.profile.units.player
```

- [ ] **Step 4: Create `core/Units.lua`**

```lua
local addonName, NS = ...

-- Single source of unit identity + per-unit config resolution for the player/target/focus
-- tracking feature. modules/Bar.lua, modules/Display.lua and core/Data.lua never reach
-- db.profile.units directly for appearance — they call NS.Units.Get(unit, key), so the "mirror
-- the player bar" behavior lives in exactly one place.
--
-- Mirror semantics (spec §2/§3): when units.<unit>.mirror == true, that unit renders with the
-- player's appearance values. `enabled` and `position` stay per-unit even while mirrored — a
-- mirrored position would stack every bar on one spot, and a mirrored enable would make the
-- per-unit toggle meaningless. Player is never mirrored; it is the source.

local Units = {}
NS.Units = Units

Units.LIST  = { "player", "target", "focus" }
Units.LABEL = { player = "Player", target = "Target", focus = "Focus" }

-- The fifteen appearance keys, in profile order. Mirror resolution and CopyFromPlayer both walk
-- this list, so adding a per-unit setting means adding its key here as well as to the defaults.
Units.APPEARANCE_KEYS = {
    "barTexture", "bgTexture", "border", "borderSize", "borderColor",
    "font", "fontSize", "fontFlags", "barWidth", "barHeight",
    "barColor", "bgColor", "useClassColorBar", "useClassColorBg", "useClassColorBorder",
}

local function profile()
    return NS.db and NS.db.profile
end

local function defaultsFor(unit)
    local d = NS.defaults and NS.defaults.profile and NS.defaults.profile.units
    return (d and d[unit]) or (d and d.player) or {}
end

local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, vv in pairs(v) do out[k] = deepcopy(vv) end
    return out
end
Units.DeepCopy = deepcopy

function Units.Config(unit)
    local p = profile()
    if not (p and p.units) then return nil end
    return p.units[unit]
end

function Units.IsEnabled(unit)
    local c = Units.Config(unit)
    if c == nil then return defaultsFor(unit).enabled == true end
    return c.enabled == true
end

-- Player is the mirror source and can never itself be mirrored, regardless of what a
-- hand-edited SavedVariables might contain.
function Units.IsMirrored(unit)
    if unit == "player" then return false end
    local c = Units.Config(unit)
    return c ~= nil and c.mirror == true
end

function Units.SourceUnit(unit)
    return Units.IsMirrored(unit) and "player" or unit
end

--- Mirror-resolved appearance read. THE read path for all fifteen appearance keys.
function Units.Get(unit, key)
    local src = Units.SourceUnit(unit)
    local c = Units.Config(src)
    if c ~= nil and c[key] ~= nil then return c[key] end
    local d = defaultsFor(src)
    if d[key] ~= nil then return d[key] end
    return defaultsFor("player")[key]
end

--- Write an appearance key onto the unit's OWN config. Deliberately not mirror-resolved: a
--- write while mirrored would silently edit the player's bar, which is not what the user
--- clicked. The panel hides the appearance widgets while mirrored, so this path is only
--- reachable from the slash CLI.
function Units.Set(unit, key, value)
    local c = Units.Config(unit)
    if c then c[key] = value end
end

function Units.Position(unit)
    local c = Units.Config(unit)
    return c and c.position
end

function Units.SetPosition(unit, pos)
    local c = Units.Config(unit)
    if c then c.position = pos end
end

--- One-shot snapshot: deep-copy the player's fifteen appearance keys onto `unit`, then clear
--- the mirror so the unit becomes independently editable. `position` and `enabled` are
--- deliberately NOT copied — both stay per-unit by design.
function Units.CopyFromPlayer(unit)
    if unit == "player" then return end
    local src, dst = Units.Config("player"), Units.Config(unit)
    if not (src and dst) then return end
    for _, key in ipairs(Units.APPEARANCE_KEYS) do
        dst[key] = deepcopy(src[key])
    end
    dst.mirror = false
end
```

- [ ] **Step 5: Rewrite `NS:RunMigrations` in `core/Database.lua`**

Replace the function body (lines 34-61) with:

```lua
-- Deep-copy so an in-place mutation of a saved variable can never reach back into the defaults.
local function deepcopy(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, vv in pairs(v) do out[k] = deepcopy(vv) end
    return out
end

function NS:RunMigrations()
    local g = NS.db and NS.db.global
    if not g then return end
    g.schemaVersion = g.schemaVersion or 1

    local profile = NS.db.profile
    local defaults = NS.defaults.profile

    -- v3 (§2.2/§5.1): bar appearance moved from flat profile keys to profile.units.<unit>.
    -- Guarded on `units == nil` so re-running is a no-op. Runs BEFORE the backfill so the
    -- backfill sees the migrated shape.
    if profile and profile.units == nil then
        profile.units = {}
        for _, unit in ipairs(NS.Units.LIST) do
            profile.units[unit] = deepcopy(defaults.units[unit])
        end
        -- Lift the pre-v3 flat appearance keys (and the saved position) onto the player unit,
        -- then clear the originals. A user upgrading sees an identical bar in an identical spot.
        for _, key in ipairs(NS.Units.APPEARANCE_KEYS) do
            if profile[key] ~= nil then
                profile.units.player[key] = profile[key]
                profile[key] = nil
            end
        end
        if profile.position ~= nil then
            profile.units.player.position = profile.position
            profile.position = nil
        end
    end

    -- Backfill any missing key from the defaults. Absorbs the legacy pre-AceDB flat
    -- SavedVariables shape and the no-AceDB fallback into one versioned, idempotent step: keys
    -- already present are left untouched, so running it twice is a no-op.
    if profile then
        for key, defaultVal in pairs(defaults) do
            if key ~= "units" and profile[key] == nil then
                profile[key] = deepcopy(defaultVal)
            end
        end
        profile.units = profile.units or {}
        for _, unit in ipairs(NS.Units.LIST) do
            profile.units[unit] = profile.units[unit] or {}
            for key, defaultVal in pairs(defaults.units[unit]) do
                if profile.units[unit][key] == nil then
                    profile.units[unit][key] = deepcopy(defaultVal)
                end
            end
        end
    end

    -- v2: the poll ticker became event-driven; the old poll-interval key is dead.
    if g.schemaVersion < 2 then
        if profile then profile.updateInterval = nil end
        NS.Debug("Migrate", "v%s \226\134\146 v2", g.schemaVersion)
        g.schemaVersion = 2
    end
    if g.schemaVersion < 3 then
        NS.Debug("Migrate", "v%s \226\134\146 v3", g.schemaVersion)
        g.schemaVersion = 3
    end
end
```

- [ ] **Step 6: Register the new files**

In `AbsorbTracker.toc`, in the Core block, add `core\Units.lua` immediately after `core\Data.lua`:

```
core\Data.lua
core\Units.lua
core\Database.lua
```

In `tests/run.lua`, add `"core/Units.lua"` to the source list immediately after `"core/Data.lua"`,
and add `"test_units"` to the test list immediately after `"test_database"`.

- [ ] **Step 7: Add the migration tests to `tests/test_database.lua`**

Append:

```lua
test("v3 migration lifts flat appearance keys onto the player unit", function()
  local profile = { barWidth = 275, fontSize = 17, position = { point = "TOP", relPoint = "TOP", x = 1, y = 2 } }
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  NS.db = savedDB
  assertEqual(profile.units.player.barWidth, 275)
  assertEqual(profile.units.player.fontSize, 17)
  assertEqual(profile.units.player.position.x, 1)
  assertEqual(profile.barWidth, nil, "the flat original must be cleared, not duplicated")
  assertEqual(profile.position, nil)
end)

test("v3 migration seeds target and focus disabled and mirrored", function()
  local profile = { barWidth = 275 }
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  NS.db = savedDB
  assertEqual(profile.units.target.enabled, false)
  assertEqual(profile.units.target.mirror, true)
  assertEqual(profile.units.focus.enabled, false)
  assertEqual(profile.units.focus.mirror, true)
end)

test("v3 migration leaves the four global keys flat", function()
  local profile = { hidden = true, locked = true, showOnlyInCombat = true, throttleWindow = 0.25 }
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  NS.db = savedDB
  assertEqual(profile.hidden, true)
  assertEqual(profile.throttleWindow, 0.25)
  assertEqual(profile.units.player.hidden, nil, "globals must not be duplicated per unit")
end)

test("v3 migration is idempotent", function()
  local profile = { barWidth = 275 }
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  profile.units.player.barWidth = 400
  NS:RunMigrations()
  NS.db = savedDB
  assertEqual(profile.units.player.barWidth, 400, "a second run must not re-lift or reset")
  assertEqual(profile.barWidth, nil, "a second run must not resurrect the flat key")
end)

test("v3 migration does not share nested tables between units", function()
  local profile = {}
  local savedDB = NS.db
  NS.db = { profile = profile, global = { schemaVersion = 2 } }
  NS:RunMigrations()
  NS.db = savedDB
  profile.units.target.barColor.r = 0.11
  assertTrue(profile.units.player.barColor.r ~= 0.11)
  assertTrue(profile.units.focus.barColor.r ~= 0.11)
end)

test("the schema version lands on 3", function()
  local savedDB = NS.db
  NS.db = { profile = {}, global = { schemaVersion = 1 } }
  NS:RunMigrations()
  local v = NS.db.global.schemaVersion
  NS.db = savedDB
  assertEqual(v, 3)
end)
```

If `assertTrue` is not already a local in `tests/test_database.lua`, add it to that file's
`local test, assertEqual = T.test, T.assertEqual` line.

- [ ] **Step 8: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `test_units` and the new `test_database` cases PASS. **Other suites will fail at this
point** — `test_display`, `test_data`, `test_schema`, `test_slashcmds`, `test_widgets` and
`test_helpers` all read flat appearance keys that no longer exist. That is expected and is fixed
by Tasks 2-7. Record which suites fail so you can confirm the list shrinks to zero by Task 7.

- [ ] **Step 9: Commit — only on explicit instruction**

Do not stage or commit unless the user has told you to. When instructed:

```bash
git add core/Units.lua defaults/Profile.lua core/Database.lua AbsorbTracker.toc tests/test_units.lua tests/test_database.lua tests/run.lua
git commit -m "feat(units): add the per-unit config seam and the v3 profile migration"
```

---

### Task 2: Dotted paths in the schema layer

**Files:**
- Modify: `settings/Schema.lua:49-76` (lookup), `:82-118` (read/write), `:172-209` (`ValidateSchema`)
- Modify: `core/Data.lua:33-51` (`GetSetting` / `SetSetting`)
- Test: `tests/test_schema.lua`

**Interfaces:**
- Consumes: `NS.Units.LIST`, `NS.Units.APPEARANCE_KEYS` (Task 1).
- Produces:
  - `NS.ResolvePath(tbl, path) -> any` — reads `"units.target.barWidth"` out of a table.
  - `NS.SetPath(tbl, path, value)` — writes it, creating intermediate tables.
  - `NS.SchemaForPage(pageKey, unit) -> rows` — `unit == nil` returns every unit's rows; a unit
    returns that unit's rows plus rows carrying no `unit` field.
  - `NS.PartitionUnitRows(rows) -> perUnitRows, styledRows`
  - `NS.GetSetting(path)` / `NS.SetSetting(path, value)` accept dotted paths.

- [ ] **Step 1: Write the failing tests**

Append to `tests/test_schema.lua`:

```lua
test("ResolvePath walks a dotted path", function()
  local t = { units = { target = { barWidth = 275 } } }
  assertEqual(NS.ResolvePath(t, "units.target.barWidth"), 275)
end)

test("ResolvePath returns nil for a missing branch instead of raising", function()
  local t = { units = {} }
  assertEqual(NS.ResolvePath(t, "units.focus.barWidth"), nil)
  assertEqual(NS.ResolvePath(t, "nope.at.all"), nil)
end)

test("ResolvePath still handles a flat key", function()
  assertEqual(NS.ResolvePath({ hidden = true }, "hidden"), true)
end)

test("SetPath writes through a dotted path and creates intermediate tables", function()
  local t = {}
  NS.SetPath(t, "units.focus.barWidth", 321)
  assertEqual(t.units.focus.barWidth, 321)
end)

test("GetSetting and SetSetting round-trip a dotted path", function()
  local saved = NS.GetSetting("units.target.barWidth")
  NS.SetSetting("units.target.barWidth", 313)
  assertEqual(NS.GetSetting("units.target.barWidth"), 313)
  NS.SetSetting("units.target.barWidth", saved)
end)

test("ValidateSchema resolves nested paths against defaults.profile", function()
  local errors, resolved, missing = NS.ValidateSchema()
  assertEqual(errors, 0, "no malformed schema rows")
  assertEqual(missing, 0, "every schema path must resolve against the defaults profile")
  assertTrue(resolved > 0)
end)

test("SchemaForPage with no unit returns every unit's rows", function()
  local rows = NS.SchemaForPage("bar")
  local seen = {}
  for _, r in ipairs(rows) do if r.unit then seen[r.unit] = true end end
  assertTrue(seen.player and seen.target and seen.focus,
    "resets and /at list need every unit's rows")
end)

test("SchemaForPage filtered to a unit excludes the other units' rows", function()
  local rows = NS.SchemaForPage("bar", "focus")
  for _, r in ipairs(rows) do
    assertTrue(r.unit == nil or r.unit == "focus",
      "a unit-filtered page must not leak another unit's widgets")
  end
end)

test("PartitionUnitRows splits alwaysPerUnit rows from the mirrored appearance rows", function()
  local rows = {
    { path = "units.focus.enabled",  alwaysPerUnit = true },
    { path = "units.focus.barWidth" },
    { path = "units.focus.barColor" },
  }
  local perUnit, styled = NS.PartitionUnitRows(rows)
  assertEqual(#perUnit, 1)
  assertEqual(perUnit[1].path, "units.focus.enabled")
  assertEqual(#styled, 2)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `NS.ResolvePath` is nil (`attempt to call field 'ResolvePath' (a nil value)`).

- [ ] **Step 3: Add the path walkers to `settings/Schema.lua`**

Insert immediately above the `-- Read / write` banner:

```lua
-- ---------------------------------------------------------------------
-- Dotted-path walkers
-- ---------------------------------------------------------------------
--
-- Per-unit settings live at `units.<unit>.<key>`, so the single read/write seam has to walk a
-- path rather than index a flat table. Flat keys ("hidden") pass through unchanged, so the four
-- globals keep working without a special case at every call site.

function NS.ResolvePath(tbl, path)
    if type(tbl) ~= "table" or type(path) ~= "string" then return nil end
    local node = tbl
    for segment in path:gmatch("[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[segment]
        if node == nil then return nil end
    end
    return node
end

function NS.SetPath(tbl, path, value)
    if type(tbl) ~= "table" or type(path) ~= "string" then return end
    local segments = {}
    for segment in path:gmatch("[^%.]+") do segments[#segments + 1] = segment end
    if #segments == 0 then return end
    local node = tbl
    for i = 1, #segments - 1 do
        local key = segments[i]
        if type(node[key]) ~= "table" then node[key] = {} end
        node = node[key]
    end
    node[segments[#segments]] = value
end
```

- [ ] **Step 4: Make `GetSetting` / `SetSetting` path-aware in `core/Data.lua`**

Replace lines 33-51:

```lua
-- Generic setting getter with fallback to the defaults when a key or the DB is absent. Accepts
-- both a flat global key ("hidden") and a dotted per-unit path ("units.target.barWidth").
function NS.GetSetting(path)
    local db = NS.db
    if db and db.profile then
        local val = NS.ResolvePath(db.profile, path)
        if val ~= nil then return val end
    end
    return NS.ResolvePath(NS.flatDefaults, path)
end

-- Generic setting setter. Same path grammar as GetSetting.
function NS.SetSetting(path, value)
    local db = NS.db
    if db and db.profile then
        NS.SetPath(db.profile, path, value)
    end
end
```

`NS.ResolvePath` is defined in `settings/Schema.lua`, which loads *after* `core/Data.lua` — that
is fine, because both functions only run at call time, never at file-load time.

- [ ] **Step 5: Add the unit filter to `SchemaForPage`**

In `settings/Schema.lua`, change the signature and the match condition:

```lua
--- Rows for one page. `unit` (optional) filters to that unit's rows plus any unit-agnostic rows
--- (General's, which carry no `unit` field and always match). Omitting `unit` returns every
--- unit's rows — which is what RestoreDefaults / RestoreAllDefaults / `/at list` want.
function NS.SchemaForPage(pageKey, unit)
    local out = {}
    local groupIndex = {}
    for _, row in ipairs(NS.Schema) do
        if row.page == pageKey and (unit == nil or not row.unit or row.unit == unit) then
            out[#out + 1] = row
            local g = row.group or ""
            if groupIndex[g] == nil then
                groupIndex[g] = #out
            end
        end
    end
    table.sort(out, function(a, b)
        local ga, gb = groupIndex[a.group or ""], groupIndex[b.group or ""]
        if ga ~= gb then return ga < gb end
        return (a.order or 100) < (b.order or 100)
    end)
    return out
end

--- Split a unit page's rows into those that stay editable while mirrored (alwaysPerUnit — the
--- enable toggle) and the appearance rows the mirror hides. Pure; unit-tested.
function NS.PartitionUnitRows(rows)
    local perUnit, styled = {}, {}
    for _, row in ipairs(rows) do
        if row.alwaysPerUnit then
            perUnit[#perUnit + 1] = row
        else
            styled[#styled + 1] = row
        end
    end
    return perUnit, styled
end
```

- [ ] **Step 6: Make `ValidateSchema` resolve dotted paths**

In `NS.ValidateSchema`, replace the §4.5 block:

```lua
            -- §4.5: the path must resolve against the defaults profile. Profiles-page rows (if
            -- any) are AceDBOptions-supplied and exempt. Paths may be dotted (units.<unit>.<key>).
            if hasPath and row.page ~= "profiles" then
                if NS.ResolvePath(defaults, row.path) ~= nil then
                    resolved = resolved + 1
                else
                    _printSchemaError(where, "`path` does not resolve against defaults.profile")
                    missing = missing + 1
                end
            end
```

**Known consequence to accept, not work around:** a boolean row whose default is `false`
(`useClassColorBar`, `hidden`, `locked`, `showOnlyInCombat`, `units.*.enabled` on target/focus)
resolves to `false`, not `nil`, so `~= nil` still counts it as resolved. This matches the current
behavior, which used `defaults[row.path] ~= nil`.

- [ ] **Step 7: Run the gate**

Run: `lua tests/run.lua`
Expected: the new `test_schema` cases PASS. `test_display`, `test_data`, `test_widgets`,
`test_helpers`, `test_slashcmds` still fail — the per-unit rows don't exist yet.

- [ ] **Step 8: Commit — only on explicit instruction**

```bash
git add settings/Schema.lua core/Data.lua tests/test_schema.lua
git commit -m "feat(schema): resolve dotted per-unit paths and filter pages by unit"
```

---

### Task 3: Three bar frames

**Files:**
- Modify: `modules/Bar.lua` (whole file)
- Modify: `core/Data.lua:53-87` (media getters), `:142-167` (color getters)
- Test: `tests/test_data.lua`

**Interfaces:**
- Consumes: `NS.Units.Get` (Task 1).
- Produces:
  - `NS.CreateBar(unit, globalName) -> frame`, where `frame.unit`, `frame.statusBar`,
    `frame.valueText`, `frame.backdropInfo` are set.
  - `NS.bars` = `{ player = frame, target = frame, focus = frame }`
  - `NS.bar` / `NS.statusBar` / `NS.valueText` — aliases to the player frame's (back-compat).
  - `NS.GetBarTexture(unit)`, `NS.GetBgTexture(unit)`, `NS.GetBorder(unit)`, `NS.GetFont(unit)`,
    `NS.GetBarColor(unit)`, `NS.GetBgColor(unit)`, `NS.GetBorderColor(unit)` — each returns the
    same shape as today; `unit` defaults to `"player"` when omitted.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_data.lua`:

```lua
test("media getters read through the unit's mirror resolution", function()
  local saved = NS.db.profile.units.target.mirror
  NS.db.profile.units.target.mirror = false
  NS.db.profile.units.target.barTexture = "Blizzard Raid Bar"
  NS.db.profile.units.target.mirror = saved
  -- With no LSM headless, every fetcher falls back to the constant. The point of this test is
  -- that passing a unit does not raise and does not read the player's key by accident.
  assertEqual(NS.GetBarTexture("target"), NS.Constants.FALLBACK_TEXTURE)
  assertEqual(NS.GetBorder("focus"), NS.Constants.FALLBACK_BORDER)
  assertEqual(NS.GetFont("target"), NS.Constants.FALLBACK_FONT)
end)

test("a media getter with no unit still resolves the player", function()
  assertEqual(NS.GetBarTexture(), NS.GetBarTexture("player"))
end)

test("GetBarColor reads the requested unit's color", function()
  local saved = NS.db.profile.units.target.mirror
  NS.db.profile.units.target.mirror = false
  NS.db.profile.units.target.barColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }
  NS.db.profile.units.target.useClassColorBar = false
  local r, g, b, a = NS.GetBarColor("target")
  NS.db.profile.units.target.mirror = saved
  assertEqual(r, 0.1); assertEqual(g, 0.2); assertEqual(b, 0.3); assertEqual(a, 0.4)
end)

test("class color on a target bar is still the PLAYER's class color", function()
  -- Spec decision: resolving the tracked unit's class would need a PLAYER_TARGET_CHANGED recolor
  -- for a cosmetic gain. All three bars use your own class color.
  local saved = NS.db.profile.units.target.mirror
  NS.db.profile.units.target.mirror = false
  NS.db.profile.units.target.useClassColorBar = true
  local r, g, b = NS.GetBarColor("target")
  local pr, pg, pb = NS.GetBarColor("player")
  NS.db.profile.units.target.useClassColorBar = false
  NS.db.profile.units.target.mirror = saved
  assertEqual(r, pr); assertEqual(g, pg); assertEqual(b, pb)
end)

test("three bar frames exist and the player alias points at the player frame", function()
  assertTrue(NS.bars.player ~= nil)
  assertTrue(NS.bars.target ~= nil)
  assertTrue(NS.bars.focus ~= nil)
  assertEqual(NS.bar, NS.bars.player)
  assertEqual(NS.statusBar, NS.bars.player.statusBar)
  assertEqual(NS.valueText, NS.bars.player.valueText)
end)

test("each bar carries its own unit tag and its own backdrop table", function()
  assertEqual(NS.bars.target.unit, "target")
  assertTrue(NS.bars.target.backdropInfo ~= NS.bars.player.backdropInfo,
    "a shared backdrop table cannot hold three different border sizes")
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `NS.bars` is nil.

- [ ] **Step 3: Make the media/color getters unit-aware in `core/Data.lua`**

Replace lines 53-87 (the four media getters):

```lua
-- Media getters. `unit` defaults to "player" so existing single-bar call sites keep working;
-- every read routes through Units.Get, which applies the mirror.
local function unitSetting(unit, key)
    return NS.Units.Get(unit or "player", key)
end

function NS.GetBarTexture(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", unitSetting(unit, "barTexture"))
        if texture then return texture end
    end
    return C.FALLBACK_TEXTURE
end

function NS.GetBgTexture(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local texture = lsm:Fetch("statusbar", unitSetting(unit, "bgTexture"))
        if texture then return texture end
    end
    return C.FALLBACK_TEXTURE
end

function NS.GetBorder(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local border = lsm:Fetch("border", unitSetting(unit, "border"))
        if border then return border end
    end
    return C.FALLBACK_BORDER
end

function NS.GetFont(unit)
    local lsm = NS.GetLSM()
    if lsm then
        local font = lsm:Fetch("font", unitSetting(unit, "font"))
        if font then return font end
    end
    return C.FALLBACK_FONT
end
```

Replace lines 142-167 (the three color getters). `GetPlayerClassColor` / `GetBgClassColor` and
their caches are **unchanged** — every bar uses the player's class color:

```lua
function NS.GetBarColor(unit)
    local c = unitSetting(unit, "barColor")
    if unitSetting(unit, "useClassColorBar") then
        local cc = GetPlayerClassColor()
        return cc.r, cc.g, cc.b, c.a
    end
    return c.r, c.g, c.b, c.a
end

function NS.GetBgColor(unit)
    local c = unitSetting(unit, "bgColor")
    if unitSetting(unit, "useClassColorBg") then
        local cc = GetBgClassColor()
        return cc.r, cc.g, cc.b, c.a
    end
    return c.r, c.g, c.b, c.a
end

function NS.GetBorderColor(unit)
    local c = unitSetting(unit, "borderColor")
    if unitSetting(unit, "useClassColorBorder") then
        local cc = GetPlayerClassColor()
        return cc.r, cc.g, cc.b, c.a
    end
    return c.r, c.g, c.b, c.a
end
```

- [ ] **Step 4: Rewrite `modules/Bar.lua` as a factory**

```lua
local addonName, NS = ...

-- The absorb bar frames — one per unit (player / target / focus). Built at file-load time from
-- the per-unit defaults (no DB yet — appearance is re-applied from the active profile on enable).
-- Exports NS.bars keyed by unit, plus NS.bar / NS.statusBar / NS.valueText as player aliases for
-- the call sites that predate multi-unit (core/DebugLog.lua, settings/Slash.lua, the tests).

local C = NS.Constants
local unitDefaults = NS.unitDefaults

--- Build one bar. Each frame owns its OWN backdropInfo table: one shared table cannot hold three
--- different border sizes, and WoW's SetBackdrop keys off table identity.
function NS.CreateBar(unit, globalName)
    local bar = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
    bar.unit = unit

    bar.backdropInfo = {
        bgFile = C.FALLBACK_TEXTURE,
        edgeFile = NS.GetBorder(unit),
        tile = false,
        edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    }

    bar:SetSize(unitDefaults.barWidth, unitDefaults.barHeight)
    bar:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    bar:SetBackdrop(bar.backdropInfo)
    bar:SetBackdropColor(0.2, 0.2, 0.2, 0.8)
    bar:SetBackdropBorderColor(unitDefaults.borderColor.r, unitDefaults.borderColor.g,
        unitDefaults.borderColor.b, unitDefaults.borderColor.a)
    bar:SetMovable(true)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", bar.StartMoving)
    -- Position is per-unit and never mirrored, so the write always targets this frame's own unit.
    bar:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relPoint, x, y = self:GetPoint()
        NS.Units.SetPosition(self.unit, { point = point, relPoint = relPoint, x = x, y = y })
    end)
    bar:SetClampedToScreen(true)

    local statusBar = CreateFrame("StatusBar", nil, bar)
    statusBar:SetPoint("TOPLEFT", bar, "TOPLEFT", 3, -3)
    statusBar:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -3, 3)
    statusBar:SetStatusBarTexture(NS.GetBarTexture(unit))
    statusBar:SetMinMaxValues(0, 100)
    statusBar:SetValue(100)
    statusBar:SetStatusBarColor(0.4, 0.7, 1, 0.8)
    bar.statusBar = statusBar

    -- Absorb value text (on statusBar so it's above the bar texture).
    local valueText = statusBar:CreateFontString(nil, "OVERLAY", nil)
    valueText:SetFont(NS.GetFont(unit), unitDefaults.fontSize, unitDefaults.fontFlags or "")
    valueText:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar.valueText = valueText

    return bar
end

NS.bars = {
    player = NS.CreateBar("player", "AbsorbTrackerFrame"),
    target = NS.CreateBar("target", "AbsorbTrackerTargetFrame"),
    focus  = NS.CreateBar("focus",  "AbsorbTrackerFocusFrame"),
}

-- Player aliases. core/DebugLog.lua, settings/Slash.lua (`/at test`) and the test harness reach
-- for these; keeping them avoids a rename sweep across files this feature does not otherwise touch.
NS.bar          = NS.bars.player
NS.statusBar    = NS.bars.player.statusBar
NS.valueText    = NS.bars.player.valueText
NS.backdropInfo = NS.bars.player.backdropInfo
```

- [ ] **Step 5: Run the gate**

Run: `lua tests/run.lua`
Expected: the new `test_data` cases PASS. `test_display` still fails (Task 4), as do
`test_widgets` / `test_helpers` / `test_slashcmds` (Tasks 5-7).

- [ ] **Step 6: Commit — only on explicit instruction**

```bash
git add modules/Bar.lua core/Data.lua tests/test_data.lua
git commit -m "feat(bar): build one frame per unit and make the media getters unit-aware"
```

---

### Task 4: Per-unit display and the event layer

**Files:**
- Modify: `modules/Display.lua` (whole file)
- Modify: `core/AbsorbTracker.lua` (the unit-event frame block and `OnEnable`'s AceEvent block)
- Modify: `tests/wow_mock.lua:77-84` (unit API stubs)
- Test: `tests/test_display.lua`, `tests/test_visibility.lua`

**Interfaces:**
- Consumes: `NS.bars`, `NS.CreateBar` (Task 3); `NS.Units.*` (Task 1).
- Produces:
  - `NS.ForEachUnit(fn)` — calls `fn(unit)` for each of `NS.Units.LIST`, in order.
  - `NS.RestoreBarPosition(unit)`, `NS.UpdateBarAppearance(unit)`, `NS.ShouldShowBar(unit)`,
    `NS.ApplyVisibility(unit)`, `NS.UpdateAbsorbBar(unit)` — each defaults `unit` to `"player"`.
  - `NS.DefaultPosition(unit) -> point, relPoint, x, y`

- [ ] **Step 1: Add the unit API stubs to `tests/wow_mock.lua`**

Replace lines 78-84 with:

```lua
  -- player / absorb / world. The unit-taking stubs accept a unit token so a test can vary
  -- target/focus independently of the player.
  M.UnitClass = function() return "Mage", "MAGE", 8 end
  M.__unitExists = { player = true, target = false, focus = false }
  M.UnitExists = function(unit) return M.__unitExists[unit] == true end
  M.__absorbs = {}
  M.UnitGetTotalAbsorbs = function(unit) return M.__absorbs[unit] or 0 end
  M.__maxHealth = {}
  M.UnitHealthMax = function(unit) return M.__maxHealth[unit] or 100 end
  M.AbbreviateNumbers = function(n) return tostring(n) end
  M.C_ClassColor = { GetClassColor = function() return { r = 1, g = 1, b = 1 } end }
  M.InCombatLockdown = function() return false end
  M.UnitAffectingCombat = function() return false end
```

Existing `test_display` cases that override `T.mocks.UnitGetTotalAbsorbs` wholesale keep working —
they replace the function, not the table.

- [ ] **Step 2: Write the failing tests**

Append to `tests/test_display.lua`:

```lua
-- ── per-unit visibility ladder ─────────────────────────────────────────────────────

local function withUnitFlag(unit, key, value, body)
  local c = NS.db.profile.units[unit]
  local saved = c[key]
  c[key] = value
  local ok, err = pcall(body)
  c[key] = saved
  if not ok then error(err) end
end

test("the global hidden toggle hides every bar", function()
  withSetting("hidden", true, function()
    withUnitFlag("target", "enabled", true, function()
      T.mocks.__unitExists.target = true
      assertEqual(NS.ShouldShowBar("player"), false)
      assertEqual(NS.ShouldShowBar("target"), false)
      T.mocks.__unitExists.target = false
    end)
  end)
end)

test("a disabled unit stays hidden even with the master toggle on", function()
  withSetting("hidden", false, function()
    withUnitFlag("target", "enabled", false, function()
      T.mocks.__unitExists.target = true
      assertEqual(NS.ShouldShowBar("target"), false)
      T.mocks.__unitExists.target = false
    end)
  end)
end)

test("an enabled target bar hides when there is no target", function()
  withSetting("hidden", false, function()
    withUnitFlag("target", "enabled", true, function()
      T.mocks.__unitExists.target = false
      assertEqual(NS.ShouldShowBar("target"), false)
      T.mocks.__unitExists.target = true
      assertEqual(NS.ShouldShowBar("target"), true)
      T.mocks.__unitExists.target = false
    end)
  end)
end)

test("the player bar never consults UnitExists", function()
  -- The player always exists; gating on it would add a pointless call and a failure mode.
  withSetting("hidden", false, function()
    T.mocks.__unitExists.player = false
    assertEqual(NS.ShouldShowBar("player"), true)
    T.mocks.__unitExists.player = true
  end)
end)

test("showOnlyInCombat gates every bar on PLAYER combat", function()
  withSetting("hidden", false, function()
    withSetting("showOnlyInCombat", true, function()
      withUnitFlag("target", "enabled", true, function()
        T.mocks.__unitExists.target = true
        local savedCombat = T.mocks.UnitAffectingCombat
        T.mocks.UnitAffectingCombat = function() return false end
        assertEqual(NS.ShouldShowBar("target"), false)
        T.mocks.UnitAffectingCombat = function() return true end
        assertEqual(NS.ShouldShowBar("target"), true)
        T.mocks.UnitAffectingCombat = savedCombat
        T.mocks.__unitExists.target = false
      end)
    end)
  end)
end)

-- ── per-unit paint ─────────────────────────────────────────────────────────────────

test("UpdateAbsorbBar reads the absorb of the unit it is painting", function()
  local savedHold = NS.testHoldUntil
  NS.testHoldUntil = nil
  T.mocks.__absorbs.target = 9100
  T.mocks.__maxHealth.target = 300000
  T.mocks.__unitExists.target = true
  local value
  withSetting("hidden", false, function()
    withUnitFlag("target", "enabled", true, function()
      value = record(NS.bars.target.statusBar, "SetValue", function()
        NS.UpdateAbsorbBar("target")
      end)
    end)
  end)
  T.mocks.__absorbs.target, T.mocks.__maxHealth.target = nil, nil
  T.mocks.__unitExists.target = false
  NS.testHoldUntil = savedHold
  assertEqual(value[1][1], 9100, "the target bar must not paint the player's absorb")
end)

test("UpdateBarAppearance sizes the bar it is given, not always the player's", function()
  local calls
  local c = NS.db.profile.units.target
  local savedMirror, savedW = c.mirror, c.barWidth
  c.mirror, c.barWidth = false, 333
  calls = record(NS.bars.target, "SetSize", function() NS.UpdateBarAppearance("target") end)
  c.mirror, c.barWidth = savedMirror, savedW
  assertEqual(calls[1][1], 333)
end)

test("a mirrored unit paints with the player's size", function()
  local c = NS.db.profile.units.focus
  local savedMirror = c.mirror
  local savedPlayerW = NS.db.profile.units.player.barWidth
  c.mirror = true
  c.barWidth = 999
  NS.db.profile.units.player.barWidth = 210
  local calls = record(NS.bars.focus, "SetSize", function() NS.UpdateBarAppearance("focus") end)
  c.mirror = savedMirror
  NS.db.profile.units.player.barWidth = savedPlayerW
  assertEqual(calls[1][1], 210)
end)

-- ── default positions ──────────────────────────────────────────────────────────────

test("the player bar defaults to dead center", function()
  local point, relPoint, x, y = NS.DefaultPosition("player")
  assertEqual(point, "CENTER"); assertEqual(relPoint, "CENTER")
  assertEqual(x, 0); assertEqual(y, 0)
end)

test("target and focus default stacked above the player bar", function()
  local savedH = NS.db.profile.units.player.barHeight
  NS.db.profile.units.player.barHeight = 20
  local _, _, _, ty = NS.DefaultPosition("target")
  local _, _, _, fy = NS.DefaultPosition("focus")
  NS.db.profile.units.player.barHeight = savedH
  assertEqual(ty, 28, "one bar height + an 8px gap")
  assertEqual(fy, 56, "two bar heights + two gaps")
end)

test("ForEachUnit walks all three units in order", function()
  local seen = {}
  NS.ForEachUnit(function(unit) seen[#seen + 1] = unit end)
  assertEqual(#seen, 3)
  assertEqual(seen[1], "player"); assertEqual(seen[2], "target"); assertEqual(seen[3], "focus")
end)
```

- [ ] **Step 3: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `NS.DefaultPosition` and `NS.ForEachUnit` are nil, and `ShouldShowBar("target")`
ignores its argument.

- [ ] **Step 4: Rewrite `modules/Display.lua`**

```lua
local addonName, NS = ...

local floor, max = NS.floor, NS.max

-- Gap between stacked default bar positions, in pixels.
local STACK_GAP = 8

--- Run `fn(unit)` for every tracked unit, in NS.Units.LIST order. The bus handlers drive all
--- three bars through this, which is what keeps the bus messages payload-free.
function NS.ForEachUnit(fn)
    for _, unit in ipairs(NS.Units.LIST) do fn(unit) end
end

--- Where a bar sits before the user has ever dragged it. Player is dead center; target and focus
--- stack upward from it, one player-bar-height plus a gap apart, so a newly-enabled bar lands
--- somewhere visible and non-overlapping instead of on top of the player's.
function NS.DefaultPosition(unit)
    local index = 0
    for i, u in ipairs(NS.Units.LIST) do
        if u == unit then index = i - 1 break end
    end
    local step = NS.Units.Get("player", "barHeight") + STACK_GAP
    return "CENTER", "CENTER", 0, index * step
end

-- Restore a bar's position from the saved profile (or its stacked default if unset).
function NS.RestoreBarPosition(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return end
    local pos = NS.Units.Position(unit)
    bar:ClearAllPoints()
    if pos then
        bar:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
    else
        bar:SetPoint(NS.DefaultPosition(unit))
    end
end

-- Apply appearance: size, texture, colors, border/background, font, lock, visibility.
function NS.UpdateBarAppearance(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return end
    local statusBar = bar.statusBar
    local valueText = bar.valueText
    local backdropInfo = bar.backdropInfo

    bar:SetSize(NS.Units.Get(unit, "barWidth"), NS.Units.Get(unit, "barHeight"))
    statusBar:SetStatusBarTexture(NS.GetBarTexture(unit))
    statusBar:SetStatusBarColor(NS.GetBarColor(unit))

    local borderSize = NS.Units.Get(unit, "borderSize")
    local inset = max(1, floor(borderSize / 4))
    backdropInfo.bgFile = NS.GetBgTexture(unit)
    backdropInfo.edgeFile = NS.GetBorder(unit)
    backdropInfo.edgeSize = borderSize
    backdropInfo.insets.left = inset
    backdropInfo.insets.right = inset
    backdropInfo.insets.top = inset
    backdropInfo.insets.bottom = inset
    -- Clear first to force refresh: WoW's SetBackdrop is a no-op when the table identity is
    -- unchanged, even if its fields changed. Do not optimize this away.
    bar:SetBackdrop(nil)
    bar:SetBackdrop(backdropInfo)
    bar:SetBackdropColor(NS.GetBgColor(unit))
    bar:SetBackdropBorderColor(NS.GetBorderColor(unit))

    valueText:SetFont(NS.GetFont(unit), NS.Units.Get(unit, "fontSize"),
        NS.Units.Get(unit, "fontFlags") or "")

    -- `locked` is global: all three bars lock together.
    local locked = NS.GetSetting("locked")
    bar:SetMovable(not locked)
    bar:EnableMouse(not locked)

    NS.ApplyVisibility(unit)
end

-- Effective bar visibility, composed in order — the first false wins:
--   1. the global `hidden` master toggle
--   2. the per-unit `enabled` flag
--   3. the global `showOnlyInCombat` gate
--   4. for target/focus only, whether the unit exists
--
-- The combat gate keys off UnitAffectingCombat("player"), NOT InCombatLockdown(). At
-- PLAYER_REGEN_DISABLED the client fires the event while InCombatLockdown() is still false —
-- secure-frame lockdown lags actual combat by a fraction of a second — so gating on lockdown hid
-- the bar exactly when it should appear. See docs/midnight-quirks.md.
--
-- Step 4 uses UnitExists and nothing else. "Hide when the unit has no absorb" is NOT
-- implementable: UnitGetTotalAbsorbs returns a secret in restricted content and comparing it to
-- zero raises — the same constraint recorded in docs/scope.md for the audio-alert feature.
function NS.ShouldShowBar(unit)
    unit = unit or "player"
    if NS.GetSetting("hidden") then return false end
    if not NS.Units.IsEnabled(unit) then return false end
    if NS.GetSetting("showOnlyInCombat") and not UnitAffectingCombat("player") then return false end
    if unit ~= "player" and not UnitExists(unit) then return false end
    return true
end

local dbgLastShown = {}   -- module-local: last applied visibility per unit, for transition logging
function NS.ApplyVisibility(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return end
    local show = NS.ShouldShowBar(unit)
    if NS.State and NS.State.debug and show ~= dbgLastShown[unit] then
        local reason = NS.GetSetting("hidden") and "hidden toggle"
            or (not NS.Units.IsEnabled(unit) and "unit disabled")
            or (NS.GetSetting("showOnlyInCombat") and not UnitAffectingCombat("player")
                and "showOnlyInCombat")
            or (unit ~= "player" and not UnitExists(unit) and "no unit")
            or "always"
        NS.Debug("Bar", "%s: %s (%s)", unit, show and "shown" or "hidden", reason)
    end
    dbgLastShown[unit] = show
    if show then bar:Show() else bar:Hide() end
end

-- Repaint one bar's absorb value. Reads the raw (possibly "secret") UnitGetTotalAbsorbs value and
-- hands it straight to the C-side UI functions / AbbreviateNumbers — never through tonumber first.
function NS.UpdateAbsorbBar(unit)
    unit = unit or "player"
    local bar = NS.bars[unit]
    if not bar then return end

    if not NS.ShouldShowBar(unit) then
        return
    end

    -- /at test paints a fake value and sets testHoldUntil so this doesn't immediately overwrite it.
    if (NS.testHoldUntil or 0) > GetTime() then
        return
    end

    local totalAbsorb = UnitGetTotalAbsorbs(unit) or 0
    local maxHealth = UnitHealthMax(unit) or 1

    bar:SetAlpha(1)
    bar.statusBar:SetMinMaxValues(0, maxHealth)
    bar.statusBar:SetValue(totalAbsorb)
    bar.valueText:SetText(AbbreviateNumbers(totalAbsorb))

    if NS.NoteRepaint then NS.NoteRepaint() end
end

-- Bus subscriptions (architecture-§4). This module owns the SOLE subscription to each of the
-- appearance / visibility / position notifications; the settings, event, and lifecycle layers
-- publish them instead of calling these functions across the module boundary. All three register
-- on Display's own bus target, so no two receivers ever share a table (anti-pattern #32).
-- Handlers look the functions up on NS at dispatch time so a test can stub e.g. NS.ApplyVisibility,
-- and fan out over every unit so the messages stay payload-free.
NS.Display = NS.Display or {}
if NS.NewBusTarget then
    local ev = NS.NewBusTarget()
    NS.Display.__ev = ev
    ev:RegisterMessage(NS.MSG.APPEARANCE, function()
        NS.ForEachUnit(function(unit) NS.UpdateBarAppearance(unit) end)
    end)
    ev:RegisterMessage(NS.MSG.VISIBILITY, function()
        NS.ForEachUnit(function(unit) NS.ApplyVisibility(unit) end)
    end)
    ev:RegisterMessage(NS.MSG.POSITION, function()
        NS.ForEachUnit(function(unit) NS.RestoreBarPosition(unit) end)
    end)
end
```

- [ ] **Step 5: Fix the pre-existing `test_display` cases that assume one bar**

Three existing cases reference `NS.backdropInfo` and `NS.db.profile.position` directly. Update
them in place:

- `"RestoreBarPosition centers the bar when no position is saved"` — replace
  `NS.db.profile.position` with `NS.db.profile.units.player.position`.
- `"RestoreBarPosition restores the saved anchor verbatim"` — same substitution.
- The three `UpdateBarAppearance` backdrop cases — `NS.backdropInfo` still resolves (it is the
  player frame's table alias), so they pass unchanged. Verify rather than edit.
- The `withSetting` helper at the top of the file targets flat keys. Add a sibling for unit keys:

```lua
local function withUnitSetting(unit, key, value, body)
  local c = NS.db.profile.units[unit]
  local saved = c[key]
  c[key] = value
  local ok, err = pcall(body)
  c[key] = saved
  if not ok then error(err) end
end
```

Then update the cases that call `withSetting("barWidth", …)`, `withSetting("barHeight", …)`,
`withSetting("borderSize", …)`, `withSetting("fontSize", …)`, `withSetting("fontFlags", …)` to use
`withUnitSetting("player", …)`. `withSetting` stays correct for `hidden`, `locked` and
`showOnlyInCombat`, which are still flat globals.

The `"UpdateBarAppearance tolerates a nil fontFlags"` case reads `NS.flatDefaults.fontFlags` —
change that to `NS.unitDefaults.fontFlags` and `NS.db.profile.fontFlags` to
`NS.db.profile.units.player.fontFlags`.

- [ ] **Step 6: Wire the events in `core/AbsorbTracker.lua`**

Find the private unit-event frame block in `OnEnable`. Replace the single-frame creation with two
frames. Keep the existing create-once guard pattern and the existing handler method names
(`addon:OnAbsorbChanged`, `addon:OnMaxHealthChanged`):

```lua
    -- §9.1 deviation (see docs/ARCHITECTURE.md): the two UNIT_* events are registered on PRIVATE
    -- frames via RegisterUnitEvent rather than through AceEvent-3.0. Both events fire for every
    -- unit the client knows about (raid, pets, nameplates); AceEvent uses one shared frame with
    -- plain RegisterEvent and structurally cannot RegisterUnitEvent, so it would pay a full C→Lua
    -- dispatch per unit only to discard all but ours.
    --
    -- TWO frames, not one: RegisterUnitEvent filters at most two units per frame, and we now track
    -- three. Frame A takes player+target, frame B takes focus. Registration is unconditional (not
    -- gated on the per-unit `enabled` flag) — the C-side filter already limits dispatch to three
    -- units, so conditional registration would add lifecycle complexity for no measurable gain.
    if not self.__unitEventFrames then
        local function onEvent(_, event, unit)
            if event == "UNIT_ABSORB_AMOUNT_CHANGED" then
                self:OnAbsorbChanged(unit)
            elseif event == "UNIT_MAXHEALTH" then
                self:OnMaxHealthChanged(unit)
            end
        end

        local frameA = CreateFrame("Frame")
        frameA:SetScript("OnEvent", onEvent)
        frameA:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player", "target")
        frameA:RegisterUnitEvent("UNIT_MAXHEALTH", "player", "target")

        local frameB = CreateFrame("Frame")
        frameB:SetScript("OnEvent", onEvent)
        frameB:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "focus")
        frameB:RegisterUnitEvent("UNIT_MAXHEALTH", "focus")

        self.__unitEventFrames = { frameA, frameB }
    end
```

In the same `OnEnable`, alongside the existing `PLAYER_ENTERING_WORLD` / `PLAYER_REGEN_*`
registrations, add:

```lua
    -- Target / focus swaps change which bars should be visible and what they should read.
    -- Global, payload-free events with no unit to filter, so they stay on AceEvent (§9.1).
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "OnUnitSwap")
    self:RegisterEvent("PLAYER_FOCUS_CHANGED", "OnUnitSwap")
```

and add the handler next to the other handlers:

```lua
function addon:OnUnitSwap()
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
    NS.bus:SendMessage(NS.MSG.REPAINT)
end
```

If `OnAbsorbChanged` / `OnMaxHealthChanged` currently take no arguments, widen their signatures to
accept and ignore `unit` — the repaint stays a single coalesced all-bars pass, so neither handler
needs to branch on it. Keep the existing debug counter and the `[Absorb]` transition log exactly
as they are, and keep `NS.RequestRepaint()` called with no argument.

- [ ] **Step 7: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `test_display`, `test_visibility`, `test_timer`, `test_bus`, `test_data`, `test_units`,
`test_database`, `test_schema` all PASS. `test_widgets`, `test_helpers`, `test_slashcmds` still
fail — the per-unit rows and the panel/CLI changes land in Tasks 5-7.

- [ ] **Step 8: Commit — only on explicit instruction**

```bash
git add modules/Display.lua core/AbsorbTracker.lua tests/wow_mock.lua tests/test_display.lua
git commit -m "feat(display): drive three bars per unit and wire the target/focus events"
```

---

### Task 5: Per-unit schema rows

**Files:**
- Modify: `settings/Bar.lua:18-113` (row block)
- Modify: `settings/Border.lua` (row block)
- Modify: `settings/Font.lua` (row block)
- Test: `tests/test_schema.lua`

**Interfaces:**
- Consumes: `NS.Units.LIST` (Task 1), `NS.unitDefaults` (Task 1), `NS.SchemaForPage(page, unit)`
  and `NS.PartitionUnitRows` (Task 2).
- Produces: schema rows at `units.<unit>.<key>` for every appearance key on the `bar`, `border`
  and `font` pages, each tagged `unit = <unit>`; plus `units.<unit>.enabled` (tagged
  `alwaysPerUnit = true`) and `units.<unit>.mirror` (tagged `skipRender = true`, target/focus only)
  on the `bar` page.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_schema.lua`:

```lua
test("every appearance page carries a full row set for all three units", function()
  for _, page in ipairs({ "bar", "border", "font" }) do
    for _, unit in ipairs(NS.Units.LIST) do
      local rows = NS.SchemaForPage(page, unit)
      assertTrue(#rows > 0, page .. " page has no rows for " .. unit)
      for _, r in ipairs(rows) do
        assertTrue(r.path:match("^units%." .. unit .. "%."),
          "row " .. r.path .. " on " .. page .. "/" .. unit .. " is not unit-scoped")
      end
    end
  end
end)

test("each unit's row set for a page is the same size", function()
  for _, page in ipairs({ "bar", "border", "font" }) do
    local n = #NS.SchemaForPage(page, "target")
    assertEqual(#NS.SchemaForPage(page, "focus"), n,
      page .. ": target and focus must expose identical settings")
  end
end)

test("the enable row is per-unit and survives mirroring", function()
  for _, unit in ipairs(NS.Units.LIST) do
    local row = NS.FindSchemaRow("units." .. unit .. ".enabled")
    assertTrue(row ~= nil, unit .. " has no enable row")
    assertEqual(row.alwaysPerUnit, true)
    assertEqual(row.page, "bar")
  end
end)

test("the mirror row exists for target and focus but not the player", function()
  assertTrue(NS.FindSchemaRow("units.target.mirror") ~= nil)
  assertTrue(NS.FindSchemaRow("units.focus.mirror") ~= nil)
  assertEqual(NS.FindSchemaRow("units.player.mirror"), nil,
    "the player is the mirror source; a player mirror row would be circular")
end)

test("the mirror row is kept out of the auto-rendered body", function()
  -- The panel draws it bespoke in the header; it stays in the schema so /at set can reach it.
  assertEqual(NS.FindSchemaRow("units.focus.mirror").skipRender, true)
end)

test("General's rows stay flat globals with no unit tag", function()
  for _, r in ipairs(NS.SchemaForPage("general")) do
    assertEqual(r.unit, nil, r.path .. " must not be unit-scoped")
    assertTrue(not r.path:match("^units%."), r.path .. " must stay a flat global")
  end
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `SchemaForPage("bar", "target")` returns rows whose paths are flat (`barWidth`),
so the `^units%.target%.` assertion fails.

- [ ] **Step 3: Rewrite the row block in `settings/Bar.lua`**

Replace lines 18-113 with a per-unit generator. Note `flatDefaults` at line 16 becomes
`unitDefaults`:

```lua
local unitDefaults = NS.unitDefaults

-- Every row below is generated once per unit in NS.Units.LIST: the path is prefixed with
-- `units.<unit>.` and tagged `unit = unit`, so Helpers.RenderUnitPanel can filter the page to
-- the currently-selected unit (settings/Schema.lua: SchemaForPage). The `default =` values come
-- from NS.unitDefaults so all three units share one canonical default.
local function addUnitRows(unit)
    local p = "units." .. unit .. "."
    local rows = {
        {
            path    = p .. "enabled",
            page    = "bar",
            unit    = unit,
            alwaysPerUnit = true,   -- stays editable even while this unit mirrors the player
            group   = "This bar",
            order   = 10,
            type    = "bool",
            label   = "Enable this bar",
            desc    = "Track and display absorbs for this unit.",
            default = (unit == "player"),
            solo    = true,
            onChange = function()
                NS.bus:SendMessage(NS.MSG.APPEARANCE)
                NS.bus:SendMessage(NS.MSG.REPAINT)
            end,
        },
        {
            path    = p .. "barWidth",
            page    = "bar",
            unit    = unit,
            group   = "Size",
            order   = 10,
            type    = "number",
            label   = "Bar Width (in px)",
            desc    = "Width of the absorb bar in pixels.",
            default = unitDefaults.barWidth,
            min = 50, max = 500, step = 1, fmt = "%d px",
        },
        {
            path    = p .. "barHeight",
            page    = "bar",
            unit    = unit,
            group   = "Size",
            order   = 20,
            type    = "number",
            label   = "Bar Height (in px)",
            desc    = "Height of the absorb bar in pixels.",
            default = unitDefaults.barHeight,
            min = 10, max = 100, step = 1, fmt = "%d px",
        },
        {
            path    = p .. "barTexture",
            page    = "bar",
            unit    = unit,
            group   = "Bar",
            order   = 10,
            type    = "string",
            label   = "Bar Texture",
            desc    = "LibSharedMedia statusbar texture used for the bar fill.",
            default = unitDefaults.barTexture,
            dialogControl = "LSM30_Statusbar",
            values = NS.Helpers.LSMValues("statusbar"),
            solo   = true,
        },
        {
            path     = p .. "barColor",
            page     = "bar",
            unit     = unit,
            group    = "Bar",
            order    = 20,
            type     = "color",
            label    = "Bar Color",
            desc     = "RGBA fill color for the bar (only used when Use Class Color is off).",
            default  = unitDefaults.barColor,
            hasAlpha = true,
            disabledIf = p .. "useClassColorBar",
        },
        {
            path    = p .. "useClassColorBar",
            page    = "bar",
            unit    = unit,
            group   = "Bar",
            order   = 30,
            type    = "bool",
            label   = "Use Class Color",
            desc    = "Use your class color for the bar fill. Greys out the Bar Color picker.",
            default = unitDefaults.useClassColorBar,
        },
        {
            path    = p .. "bgTexture",
            page    = "bar",
            unit    = unit,
            group   = "Background",
            order   = 10,
            type    = "string",
            label   = "Background Texture",
            desc    = "LibSharedMedia statusbar texture drawn behind the bar fill.",
            default = unitDefaults.bgTexture,
            dialogControl = "LSM30_Statusbar",
            values = NS.Helpers.LSMValues("statusbar"),
            solo   = true,
        },
        {
            path     = p .. "bgColor",
            page     = "bar",
            unit     = unit,
            group    = "Background",
            order    = 20,
            type     = "color",
            label    = "Background Color",
            desc     = "RGBA color drawn behind the bar (only used when Use Class Color is off).",
            default  = unitDefaults.bgColor,
            hasAlpha = true,
            disabledIf = p .. "useClassColorBg",
        },
        {
            path    = p .. "useClassColorBg",
            page    = "bar",
            unit    = unit,
            group   = "Background",
            order   = 30,
            type    = "bool",
            label   = "Use Class Color",
            desc    = "Use a darkened class color for the background. Greys out the Background Color picker.",
            default = unitDefaults.useClassColorBg,
        },
    }

    -- The mirror flag. Not rendered in the page body — Helpers.RenderUnitPanel draws it as a
    -- header checkbox — but kept in the schema so `/at set units.focus.mirror false` works.
    -- The player is the mirror SOURCE and gets no row.
    if unit ~= "player" then
        rows[#rows + 1] = {
            path       = p .. "mirror",
            page       = "bar",
            unit       = unit,
            alwaysPerUnit = true,
            skipRender = true,
            group      = "This bar",
            order      = 20,
            type       = "bool",
            label      = "Use same styling as Player",
            desc       = "Mirror every Player bar appearance setting. Position and enable stay independent.",
            default    = true,
        }
    end

    NS.RegisterSchemaRows(rows)
end

for _, unit in ipairs(NS.Units.LIST) do addUnitRows(unit) end
```

Delete the now-unused `local flatDefaults = NS.flatDefaults` line at the top of the file.

- [ ] **Step 4: Apply the same transform to `settings/Border.lua` and `settings/Font.lua`**

Wrap each file's existing `NS.RegisterSchemaRows({...})` call in a
`local function addUnitRows(unit) … end` + `for _, unit in ipairs(NS.Units.LIST) do addUnitRows(unit) end`
loop, exactly as in Step 3. For each row:

- prefix `path` with `"units." .. unit .. "."`
- add `unit = unit`
- change `default = flatDefaults.<key>` to `default = unitDefaults.<key>`
- prefix any `disabledIf` value with `"units." .. unit .. "."` (Border's `borderColor` row has
  `disabledIf = "useClassColorBorder"` → `disabledIf = p .. "useClassColorBorder"`)

Do **not** add `enabled` or `mirror` rows here — they live on the `bar` page only.

- [ ] **Step 5: Run the gate, and clear the three forward-pinned tests from Task 2**

Run: `lua tests/run.lua && luacheck .`
Expected: the new `test_schema` cases PASS, and `ValidateSchema` reports 0 errors / 0 missing
(every generated path resolves against `defaults.profile.units.<unit>`). `test_widgets`,
`test_helpers` and `test_slashcmds` still fail.

**Task 2 left three tests forward-pinned on this task — verify all three explicitly and report on
each by name.** They were written in Task 2 against data that only exists once this task tags rows
with `unit` and converts their paths to dotted form:

1. `"ValidateSchema resolves nested paths against defaults.profile"` — was RED. Must now be green,
   with `missing == 0`.
2. `"SchemaForPage with no unit returns every unit's rows"` — was RED. Must now be green.
3. `"SchemaForPage filtered to a unit excludes the other units' rows"` — was passing **vacuously**
   (no row carried a `unit` field, so its `r.unit == nil or r.unit == "focus"` assertion was
   trivially true for every row). It must now pass *meaningfully*. Prove it: confirm the filtered
   set is strictly smaller than the unfiltered set for the same page, and that rows tagged with a
   different unit genuinely exist to be excluded. If it would still pass against a `SchemaForPage`
   that ignored its `unit` argument entirely, strengthen it until it would not.

The total failure count must drop by at least the two red ones. Report the count before and after.

- [ ] **Step 6: Commit — only on explicit instruction**

```bash
git add settings/Bar.lua settings/Border.lua settings/Font.lua tests/test_schema.lua
git commit -m "feat(settings): generate the appearance schema rows once per unit"
```

---

### Task 6: The Unit dropdown and mirror header

**Files:**
- Modify: `settings/Helpers.lua` (add `ClearScroll` / `RenderUnitPanel`; update `RestoreDefaults`
  and `RestoreAllDefaults`)
- Modify: `settings/Widgets.lua:26-37` (`get`/`set` helpers), `:183-248` (`makeColorPicker`'s
  `disabledIf` read)
- Modify: `settings/Bar.lua`, `settings/Border.lua`, `settings/Font.lua` (the `build` functions)
- Test: `tests/test_helpers.lua`, `tests/test_widgets.lua`

**Interfaces:**
- Consumes: `NS.SchemaForPage(page, unit)`, `NS.PartitionUnitRows` (Task 2); `NS.Units.*` (Task 1).
- Produces:
  - `Helpers.ClearScroll(ctx)`
  - `Helpers.RenderUnitPanel(ctx, pageKey)` — sets `ctx.unit` (defaulting to `"player"`), clears
    the scroll, draws the dropdown + mirror header + rows.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_helpers.lua`:

```lua
-- Reach the real Bar page canvas the harness built, then drive its OnShow.
local function barPanel()
  return T.mocks.__subcategories["Bar"]
end

test("the Bar page opens on the player unit with no mirror header", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  assertEqual(ctx.unit, "player")
end)

test("RenderUnitPanel draws a Unit dropdown listing all three units", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  local dd
  for _, child in ipairs(ctx.scroll.children) do
    if child.type == "Dropdown" and child.labelText == "Unit" then dd = child break end
  end
  assertTrue(dd ~= nil, "no Unit dropdown was rendered")
  assertEqual(#dd.order, 3)
  assertEqual(dd.order[1], "player")
  assertEqual(dd.value, "player")
end)

test("switching the dropdown to focus re-renders the page for that unit", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  local dd
  for _, child in ipairs(ctx.scroll.children) do
    if child.type == "Dropdown" and child.labelText == "Unit" then dd = child break end
  end
  dd:__fire("OnValueChanged", "focus")
  assertEqual(ctx.unit, "focus")
  NS.Helpers.RenderUnitPanel(ctx, "bar")   -- restore to a known state for later tests
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("a mirrored unit hides its appearance rows but keeps the enable toggle", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = true
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "bar")

  local labels = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText then labels[child.labelText] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)

  assertTrue(labels["Enable this bar"], "the enable toggle is per-unit and must stay visible")
  assertTrue(labels["Use same styling as Player"], "the mirror checkbox is the header")
  assertTrue(not labels["Bar Width (in px)"], "mirrored appearance rows must be hidden")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("unchecking the mirror reveals the appearance rows", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "bar")

  local labels = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText then labels[child.labelText] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertTrue(labels["Bar Width (in px)"], "an unlinked unit must expose its own appearance rows")

  NS.db.profile.units.focus.mirror = true
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("the copy button snapshots the player's styling and clears the mirror", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.player.barWidth = 288
  NS.db.profile.units.target.mirror = true
  ctx.unit = "target"
  NS.Helpers.RenderUnitPanel(ctx, "bar")

  local btn
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.type == "Button" and child.text == "Copy styling from Player" then btn = child end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertTrue(btn ~= nil, "no copy button was rendered")
  btn:__fire("OnClick")

  assertEqual(NS.db.profile.units.target.mirror, false)
  assertEqual(NS.db.profile.units.target.barWidth, 288)

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("a page Defaults button resets that page across every unit", function()
  NS.db.profile.units.player.barWidth = 111
  NS.db.profile.units.target.barWidth = 222
  NS.db.profile.units.focus.barWidth  = 333
  NS.Helpers.RestoreDefaults("bar")
  assertEqual(NS.db.profile.units.player.barWidth, NS.unitDefaults.barWidth)
  assertEqual(NS.db.profile.units.target.barWidth, NS.unitDefaults.barWidth)
  assertEqual(NS.db.profile.units.focus.barWidth,  NS.unitDefaults.barWidth)
end)

test("RestoreAllDefaults clears all three saved positions", function()
  for _, u in ipairs(NS.Units.LIST) do
    NS.db.profile.units[u].position = { point = "TOP", relPoint = "TOP", x = 1, y = 1 }
  end
  NS.Helpers.RestoreAllDefaults()
  for _, u in ipairs(NS.Units.LIST) do
    assertEqual(NS.db.profile.units[u].position, nil, u .. "'s position survived the reset")
  end
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `NS.Helpers.__lastUnitCtx` is nil.

- [ ] **Step 3: Confirm the widget layer needs no `disabledIf` change**

No edit required — this step is a verification. `settings/Widgets.lua` has
`local function get(path) return NS.GetSetting(path) end` at line 26, and `makeColorPicker`'s
`applyDisabled` reads its sibling toggle with `get(row.disabledIf)`:

```lua
    local function applyDisabled()
        if row.disabledIf then
            cp:SetDisabled(get(row.disabledIf) and true or false)
        end
    end
```

Since Task 5 writes `disabledIf` as a full dotted path and `NS.GetSetting` became path-aware in
Task 2, this already resolves `units.focus.useClassColorBar` correctly. Read the function to
confirm it still routes through `get` / `NS.GetSetting` rather than indexing `db.profile`, then
move on without editing.

- [ ] **Step 4: Add `ClearScroll` and `RenderUnitPanel` to `settings/Helpers.lua`**

Insert after `Helpers.Section`:

```lua
-- ---------------------------------------------------------------------
-- Per-unit panel rendering — Unit dropdown + mirror header
-- ---------------------------------------------------------------------

--- Release every AceGUI child out of ctx.scroll and reset the section-heading tracker, so the
--- next Helpers.Section call starts a fresh group instead of treating the first re-rendered row
--- as a continuation of whatever group was last drawn. Reuses the SAME ScrollFrame instance —
--- AceGUI's ReleaseChildren tears down children, not the container.
function Helpers.ClearScroll(ctx)
    if ctx.scroll and ctx.scroll.ReleaseChildren then
        ctx.scroll:ReleaseChildren()
    end
    ctx.lastGroup = nil
end

--- Render a per-unit appearance page (Bar / Border / Font): the Unit dropdown, the mirror header
--- for target/focus, then the schema rows filtered to the selected unit.
---
--- Full rebuild on every call rather than a persistent header widget: ensureScroll's ScrollFrame
--- anchors flush to ctx.body, so there is no free real estate above it to park a persistent
--- dropdown without surgery on that anchor. AceGUI's widget pool exists exactly to make
--- release-and-recreate cheap, so each call clears ctx.scroll and rebuilds from scratch.
function Helpers.RenderUnitPanel(ctx, pageKey)
    ctx.unit = ctx.unit or "player"
    Helpers.ClearScroll(ctx)
    local scroll = ensureScroll(ctx)
    Helpers.__lastUnitCtx = ctx   -- test seam: the harness has no other handle on a live ctx

    local AceGUI = NS.AceGUI
    if not AceGUI then return end

    -- Unit selector ---------------------------------------------------
    local dd = AceGUI:Create("Dropdown")
    dd:SetLabel("Unit")
    dd:SetFullWidth(true)
    local items, order = {}, {}
    for i, u in ipairs(NS.Units.LIST) do
        items[u] = NS.Units.LABEL[u]
        order[i] = u
    end
    dd:SetList(items, order)
    dd:SetValue(ctx.unit)
    dd:SetCallback("OnValueChanged", function(_, _, value)
        ctx.unit = value
        Helpers.RenderUnitPanel(ctx, pageKey)
    end)
    scroll:AddChild(dd)
    addSpacer(scroll, ROW_VSPACER)

    local rows = NS.SchemaForPage(pageKey, ctx.unit)
    local perUnitRows, styledRows = NS.PartitionUnitRows(rows)

    -- Mirror header (target / focus only) ------------------------------
    local mirrored = NS.Units.IsMirrored(ctx.unit)
    if ctx.unit ~= "player" then
        local row = AceGUI:Create("SimpleGroup")
        row:SetLayout("Flow")
        row:SetFullWidth(true)

        local cb = AceGUI:Create("CheckBox")
        cb:SetLabel("Use same styling as Player")
        cb:SetValue(mirrored)
        cb:SetRelativeWidth(0.5)
        cb:SetCallback("OnValueChanged", function(_, _, value)
            NS.SetByPath("units." .. ctx.unit .. ".mirror", value and true or false)
            Helpers.RenderUnitPanel(ctx, pageKey)
        end)
        attachTooltip(cb, "Use same styling as Player",
            "Mirror every Player bar appearance setting. Position and enable stay independent.")
        row:AddChild(cb)

        local btn = AceGUI:Create("Button")
        btn:SetText("Copy styling from Player")
        btn:SetRelativeWidth(0.5)
        btn:SetCallback("OnClick", function()
            NS.Units.CopyFromPlayer(ctx.unit)
            NS.bus:SendMessage(NS.MSG.APPEARANCE)
            Helpers.RenderUnitPanel(ctx, pageKey)
        end)
        attachTooltip(btn, "Copy styling from Player",
            "Take a one-time snapshot of the Player bar's appearance. Unlinks this unit so you can then edit it freely.")
        row:AddChild(btn)

        scroll:AddChild(row)
        addSpacer(scroll, ROW_VSPACER)

        if mirrored then
            local hint = AceGUI:Create("Label")
            hint:SetText("Linked to Player \226\128\147 uncheck to customize.")
            hint:SetFullWidth(true)
            scroll:AddChild(hint)
            addSpacer(scroll, ROW_VSPACER)
        end
    end

    -- Body: the per-unit rows always render; the appearance rows only when unlinked. The mirror
    -- row itself carries skipRender, so RenderRows leaves it to the header above.
    Helpers.RenderRows(ctx, perUnitRows)
    if not mirrored then
        Helpers.RenderRows(ctx, styledRows)
    end
    if scroll.DoLayout then scroll:DoLayout() end
end
```

`Helpers.RenderRows` does not exist yet — `settings/Widgets.lua` has
`Helpers.RenderSchema(ctx, pageKey, afterGroup, pairWith)` (line 272), which fetches its own rows.
Split it into a row-list renderer plus a thin page wrapper so `RenderUnitPanel` can render a
filtered subset. Replace `Helpers.RenderSchema` in `settings/Widgets.lua` with:

```lua
--- Render an EXPLICIT list of schema rows into ctx's scroll. This is the former RenderSchema
--- body, lifted so Helpers.RenderUnitPanel can render a filtered subset (the mirror partition).
--- Rows carrying `skipRender` stay in the schema (so /at get|set and the Defaults buttons still
--- see them) but are not drawn here — the panel renders them bespoke, e.g. the mirror checkbox
--- in the per-unit page header.
function Helpers.RenderRows(ctx, rows, afterGroup, pairWith)
    local AceGUI = NS.AceGUI
    local scroll = Helpers.EnsureScroll(ctx)
    local pendingRow, pendingCount = nil, 0

    local function flushRow()
        if pendingRow then
            scroll:AddChild(pendingRow)
            Helpers.AddSpacer(scroll, Helpers.ROW_VSPACER)
            pendingRow, pendingCount = nil, 0
        end
    end

    local function startRow()
        local r = AceGUI:Create("SimpleGroup")
        r:SetLayout("Flow")
        r:SetFullWidth(true)
        return r
    end

    for i, row in ipairs(rows) do
        if row.group and row.group ~= ctx.lastGroup then
            flushRow()                 -- previous group's tail row
            Helpers.Section(ctx, row.group)
            ctx.lastGroup = row.group
        end

        -- row.solo = true means "render this widget alone in the left
        -- half of its own row, leaving the right half empty." Used for
        -- visually-grouping pivots.
        if not row.skipRender then
            if row.solo and pendingCount > 0 then
                flushRow()
            end

            if not pendingRow then pendingRow = startRow() end
            Helpers.RenderField(ctx, row, pendingRow, 0.5)
            pendingCount = pendingCount + 1
            if pairWith and row.path and pairWith[row.path] and pendingCount == 1 then
                pairWith[row.path](ctx, pendingRow)
                pairWith[row.path] = nil       -- one-shot
                pendingCount = pendingCount + 1
            end
            if row.solo or pendingCount >= 2 then flushRow() end
        end

        local nextRow = rows[i + 1]
        if afterGroup and row.group
           and (not nextRow or nextRow.group ~= row.group)
           and afterGroup[row.group] then
            flushRow()                 -- afterGroup buttons start fresh
            afterGroup[row.group](ctx)
            afterGroup[row.group] = nil  -- one-shot
        end
    end
    flushRow()
    if scroll.DoLayout then scroll:DoLayout() end
end

function Helpers.RenderSchema(ctx, pageKey, afterGroup, pairWith)
    Helpers.RenderRows(ctx, NS.SchemaForPage(pageKey, ctx.unit), afterGroup, pairWith)
end
```

Keep the long explanatory comment block above `RenderSchema` (lines 259-271) in place — move it
so it sits above `RenderRows`, since that is where the 50/50 Flow layout and the `pairWith`
contract it describes now live.

`settings/General.lua` keeps calling `RenderSchema` and is unaffected: `ctx.unit` is nil on that
page, which `SchemaForPage` treats as "every unit", and General's rows carry no `unit` tag so they
all match.

`attachTooltip` and `addSpacer` are already file-locals in `settings/Helpers.lua`; `ensureScroll`
and `ROW_VSPACER` likewise. Confirm each is in scope at the insertion point.

- [ ] **Step 5: Make the resets cover every unit**

In `settings/Helpers.lua`, `RestoreDefaults` already calls `NS.SchemaForPage(pageKey)` with no
unit, which after Task 2 returns every unit's rows — **no change needed**. Verify it.

`RestoreAllDefaults` clears only `NS.db.profile.position`. Replace that block:

```lua
    -- Clear every unit's saved position and recenter. `position` is not a schema row (it's set by
    -- dragging), so ApplyDefault above never touches it — it must be cleared explicitly, once per
    -- unit, or a target bar dragged off-screen would survive a Reset All.
    for _, unit in ipairs(NS.Units.LIST) do
        NS.Units.SetPosition(unit, nil)
    end
```

- [ ] **Step 6: Switch the three page builders to `RenderUnitPanel`**

In `settings/Bar.lua`, `settings/Border.lua` and `settings/Font.lua`, replace the `OnShow` body's
`H.RenderSchema(ctx, "<page>")` call with `H.RenderUnitPanel(ctx, "<page>")`. Also drop the
`rendered` one-shot guard on these three pages — the panel must re-render on every unit switch,
and `RenderUnitPanel` clears the scroll itself, so re-entry is safe:

```lua
    ctx.panel:SetScript("OnShow", function()
        H.EnsureDefaultsButton(ctx.panel)
        H.RenderUnitPanel(ctx, "bar")
    end)
```

Leave `settings/General.lua` and `settings/About.lua` exactly as they are, including their
`rendered` guards.

- [ ] **Step 7: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: `test_helpers` and `test_widgets` PASS. Only `test_slashcmds` should still fail.

- [ ] **Step 8: Commit — only on explicit instruction**

```bash
git add settings/Helpers.lua settings/Widgets.lua settings/Bar.lua settings/Border.lua settings/Font.lua tests/test_helpers.lua
git commit -m "feat(panel): add the Unit dropdown and the mirror/copy header"
```

---

### Task 7: The slash surface

**Files:**
- Modify: `settings/Slash.lua:111-138` (`listSettings`), `:210-216` (`runResetPosition`),
  `:248-266` (`runTest`), `:43` (the `reset` help text)
- Test: `tests/test_slashcmds.lua`

**Interfaces:**
- Consumes: `NS.SchemaForPage` (Task 2), `NS.Units.*` (Task 1), `NS.bars` (Task 3).
- Produces: no new API. `/at get`, `/at set` accept dotted paths; unqualified appearance keys are
  rejected.

- [ ] **Step 1: Write the failing test**

Append to `tests/test_slashcmds.lua`:

The file already defines the capture seam these cases use: `slash(line)` runs a slash line and
returns its color-stripped output lines, and `contains(lines, needle)` does a plain-text find over
them. Use those — do not add a second capture mechanism.

```lua
test("set writes a dotted per-unit path", function()
  slash("set units.target.barWidth 275")
  assertEqual(NS.db.profile.units.target.barWidth, 275)
end)

test("set on one unit leaves the others alone", function()
  local before = NS.db.profile.units.player.barWidth
  slash("set units.focus.barWidth 315")
  assertEqual(NS.db.profile.units.player.barWidth, before)
  assertEqual(NS.db.profile.units.focus.barWidth, 315)
end)

test("an unqualified appearance key is rejected", function()
  -- Deliberate clean break (spec §9): paths are fully qualified, KickCD-style.
  local out = slash("set barWidth 250")
  assertTrue(contains(out, "Setting not found"),
    "expected an unknown-setting error, got: " .. joined(out))
end)

test("a global key still uses its flat path", function()
  slash("set showOnlyInCombat true")
  assertEqual(NS.db.profile.showOnlyInCombat, true)
  slash("set showOnlyInCombat false")
end)

test("get echoes a dotted path", function()
  NS.db.profile.units.target.barWidth = 275
  local out = slash("get units.target.barWidth")
  assertTrue(contains(out, "units.target.barWidth"), "got: " .. joined(out))
  assertTrue(contains(out, "275"), "got: " .. joined(out))
end)

test("list groups the appearance pages by unit", function()
  local out = slash("list")
  assertTrue(contains(out, "[bar / player]"), "no player group header; got: " .. joined(out))
  assertTrue(contains(out, "[bar / target]"), "no target group header")
  assertTrue(contains(out, "[bar / focus]"),  "no focus group header")
  assertTrue(contains(out, "[general]"), "globals must still list under a plain page header")
end)

test("reset bar resets every unit", function()
  NS.db.profile.units.player.barWidth = 111
  NS.db.profile.units.target.barWidth = 222
  NS.db.profile.units.focus.barWidth  = 333
  slash("reset bar")
  assertEqual(NS.db.profile.units.player.barWidth, NS.unitDefaults.barWidth)
  assertEqual(NS.db.profile.units.target.barWidth, NS.unitDefaults.barWidth)
  assertEqual(NS.db.profile.units.focus.barWidth,  NS.unitDefaults.barWidth)
end)

test("resetposition clears all three positions", function()
  for _, u in ipairs(NS.Units.LIST) do
    NS.db.profile.units[u].position = { point = "TOP", relPoint = "TOP", x = 1, y = 1 }
  end
  slash("resetposition")
  for _, u in ipairs(NS.Units.LIST) do
    assertEqual(NS.db.profile.units[u].position, nil, u .. " kept its position")
  end
end)

test("toggle still flips the global hidden master", function()
  local before = NS.GetSetting("hidden")
  slash("toggle")
  assertEqual(NS.GetSetting("hidden"), not before)
  slash("toggle")
  assertEqual(NS.GetSetting("hidden"), before)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lua tests/run.lua`
Expected: FAIL — `list` prints flat `[bar]` headers with no unit split, and `resetposition` clears
only `NS.db.profile.position`, which no longer exists.

- [ ] **Step 3: Group `/at list` by unit**

Replace `listSettings` in `settings/Slash.lua`:

```lua
-- Page order for /at list grouping. Profiles is omitted (its schema is supplied by AceDBOptions).
local PAGE_ORDER = { "general", "bar", "border", "font" }
-- Which pages carry per-unit rows and therefore list once per unit.
local PER_UNIT_PAGES = { general = false, bar = true, border = true, font = true }

function listSettings()
    if not NS.Schema or #NS.Schema == 0 then
        return print("No settings registered yet")
    end
    -- Color scheme (Ka0s standard, slash-commands-§5): header green (33ff99), group headers
    -- azure (3399ff), key/value via FormatKV. No trailing colons.
    print("|cff33ff99Available settings|r")

    local function printRows(header, rows)
        if #rows == 0 then return end
        print("  |cff3399ff[" .. header .. "]|r")
        for _, row in ipairs(rows) do
            local v = NS.GetSetting(row.path)
            print("    " .. FormatKV(row.path, NS.FormatSchemaValue(row, v)))
        end
    end

    for _, page in ipairs(PAGE_ORDER) do
        if PER_UNIT_PAGES[page] then
            for _, unit in ipairs(NS.Units.LIST) do
                printRows(page .. " / " .. unit, NS.SchemaForPage(page, unit))
            end
        else
            printRows(page, NS.SchemaForPage(page))
        end
    end
end
```

- [ ] **Step 4: Clear every position in `runResetPosition`**

```lua
function runResetPosition()
    for _, unit in ipairs(NS.Units.LIST) do
        NS.Units.SetPosition(unit, nil)
    end
    NS.bus:SendMessage(NS.MSG.POSITION)
    print("Bar positions reset")
end
```

- [ ] **Step 5: Make `/at test` paint every enabled bar**

Replace the paint block inside `runTest`:

```lua
    print(("Testing display with value: %s for %d s"):format(AbbreviateNumbers(n), hold))
    for _, unit in ipairs(NS.Units.LIST) do
        local bar = NS.bars[unit]
        if bar and NS.ShouldShowBar(unit) then
            bar.valueText:SetText(AbbreviateNumbers(n))
            bar.statusBar:SetMinMaxValues(0, math.max(n, 100000))
            bar.statusBar:SetValue(n)
        end
    end
    NS.testHoldUntil = GetTime() + hold
```

- [ ] **Step 6: Update the `reset` help text**

In `NS.COMMANDS`, change the `reset` description to note it spans units:

```lua
    {"reset",         "Reset a panel to defaults across every unit \226\128\148 `/at reset <general|bar|border|font>`",
        function(rest) runReset(rest) end},
```

and `resetposition`:

```lua
    {"resetposition", "Move every bar back to its default position",
        function() runResetPosition() end},
```

- [ ] **Step 7: Run the gate**

Run: `lua tests/run.lua && luacheck .`
Expected: **all suites PASS, 0 failed.** `luacheck .` reports 0 warnings / 0 errors. If any suite
from the Task 1 Step 8 failure list is still red, fix it before proceeding — the plan assumes a
fully green tree from here.

- [ ] **Step 8: Commit — only on explicit instruction**

```bash
git add settings/Slash.lua tests/test_slashcmds.lua
git commit -m "feat(slash): address settings by dotted per-unit path"
```

---

### Task 8: Documentation and the test-case regeneration

**Files:**
- Modify: `docs/scope.md`, `docs/ARCHITECTURE.md`, `docs/schema.md`, `docs/settings-panel.md`,
  `docs/data-flow.md`, `docs/module-map.md`, `docs/file-index.md`, `docs/common-tasks.md`,
  `docs/smoke-tests.md`, `docs/testing.md`, `README.md`
- Regenerate: `docs/test-cases.md`

**Interfaces:**
- Consumes: everything from Tasks 1-7.
- Produces: no code.

- [ ] **Step 1: Rewrite the scope boundaries**

In `docs/scope.md`:

**First, a correctness fix to an existing bullet — user-approved 2026-07-28.** The
*"Audible / text-to-speech alerts"* bullet currently reads *"tainted code may not compare or
boolean-test a secret"*. The **boolean-test half is wrong**, and it contradicts
[midnight-quirks.md](./midnight-quirks.md)-§1, which states only that *"Lua cannot compare a secret
value with a number (`tonumber()` returns nil; `>` / `<` against a number errors)"*. Truthiness is
on the safe side of the same line that lets `..` propagate a secret while `table.concat` raises: a
secret is neither `nil` nor `false`, so `x or 0` returns `x` without inspecting it and leaks
nothing about the value. The addon relies on this today — `modules/Display.lua`'s
`UnitGetTotalAbsorbs(unit) or 0` runs on every in-combat repaint, where the value *is* secret.

Change the phrase to *"may not compare a secret against a number, nor run it through
`tonumber`"*. **Do not change the bullet's conclusion** — audio alerts stay out of scope, because
that rests on `absorb == 0`, a genuine comparison that really does raise. Do not touch the `or 0`
code in `modules/Display.lua` or `core/AbsorbTracker.lua`.

Then the scope amendment proper:

- Under **In scope**, replace *"A single movable absorb status bar for the player"* with:
  *"Three movable absorb status bars — player, target, and focus — each displaying the total of
  all active absorb shields on that unit as one combined value. Target and focus ship disabled."*
- Add to **In scope**: *"Per-unit appearance and position, selected through a Unit dropdown on the
  Bar / Border / Font pages, with a live 'mirror the Player bar' link and a one-shot 'copy from
  Player' snapshot."*
- Under **Out of scope**, replace the *"Group / raid / target absorb tracking"* bullet with:
  *"**Group / raid / arena / boss / party absorb tracking.** Player, target, and focus only.
  Mirroring is Player-sourced — focus cannot mirror target."*
- Add to **Resolved decisions**:
  - *Mirroring is a live link; copying is a one-shot snapshot.* A mirrored unit re-reads the
    player's values on every paint; a copied unit stops tracking the player entirely.
  - *`position` and `enabled` are never mirrored.* A mirrored position would stack every bar on
    one spot; a mirrored enable would make the per-unit toggle meaningless.
  - *Class colors are always the player's, on all three bars.* Resolving the tracked unit's class
    would need a `PLAYER_TARGET_CHANGED`-driven recolor and a non-player fallback, for a purely
    cosmetic gain.
  - *Target/focus visibility uses `UnitExists`, never an absorb comparison.* Comparing
    `UnitGetTotalAbsorbs` to zero raises on a secret — the same constraint that rules out audio
    alerts.
  - *The four master toggles stay global.* `hidden`, `locked`, `showOnlyInCombat` and
    `throttleWindow` govern all three bars; only appearance and position are per-unit.
  - *Slash paths are fully qualified.* `/at set units.player.barWidth 250`. The pre-1.9 unqualified
    form is gone.

- [ ] **Step 2: Update `docs/ARCHITECTURE.md`**

- **Overview:** change *"A single movable absorb status bar for the player"* to describe three
  bars and the mirror model.
- **Module Map:** add a row —
  `| core/Units.lua | NS.Units — unit identity (LIST/LABEL), mirror resolution (IsMirrored / SourceUnit / Get), per-unit position read/write, and CopyFromPlayer. The only file that reads db.profile.units for appearance. |`
- Update the `modules/Bar.lua`, `modules/Display.lua`, `defaults/Profile.lua`, `core/Data.lua`,
  `settings/Schema.lua`, `settings/Helpers.lua` and `settings/{Bar,Border,Font}.lua` rows to
  describe their new per-unit responsibilities.
- **Event Subscriptions:** describe the two private unit-event frames (player+target, focus) and
  add `PLAYER_TARGET_CHANGED` / `PLAYER_FOCUS_CHANGED` → `OnUnitSwap`.
- **Known Limitations:** replace the *"Single bar"* bullet with
  *"Three bars — player, target, focus. Group / raid / arena / boss units are out of scope
  ([scope.md](./scope.md))."*
- **Standards Deviations:** rewrite the §9.1 entry to describe **two** private frames, adding the
  reason a second is required: `RegisterUnitEvent` filters at most two units per frame and the
  addon now tracks three.
- **Message Bus:** note that each Display handler fans out over `NS.ForEachUnit`, so the messages
  stay payload-free.

- [ ] **Step 3: Update the remaining topic docs**

- `docs/schema.md` — the dotted `units.<unit>.<key>` path grammar; the new row fields `unit`,
  `alwaysPerUnit`, `skipRender`; the per-unit generation loop; `SchemaForPage(page, unit)`.
- `docs/settings-panel.md` — the Unit dropdown, the mirror checkbox + copy button header, the hint
  line, and the hidden-while-mirrored rule. Note General and About have no dropdown.
- `docs/data-flow.md` — one coalesced repaint fanning out to three bars; the mirror resolution
  step between the schema read and the paint.
- `docs/module-map.md` and `docs/file-index.md` — add `core/Units.lua`.
- `docs/common-tasks.md` — add an "Add a per-unit setting" recipe: add the key to
  `defaults/Profile.lua`'s `appearance()`, add it to `NS.Units.APPEARANCE_KEYS`, add the row inside
  the relevant page's `addUnitRows`.
- `docs/smoke-tests.md` — add manual checks: enable the target bar, confirm it appears only with a
  target; toggle mirror on/off and confirm the rows hide/appear; click Copy and confirm the unit
  unlinks with the player's values; drag each bar independently; confirm the global Show Bar and
  Show-only-in-combat toggles govern all three; confirm `/at reset bar` resets all three.
- `docs/testing.md` — add `test_units` to the suite list.

- [ ] **Step 4: Update `README.md`**

- Describe the three bars and that target/focus ship disabled.
- Document the Unit dropdown, mirror, and copy.
- **Rewrite every `/at set` example to the qualified form** and call out the breaking change:
  *"Slash paths are now fully qualified — `/at set units.player.barWidth 250`. Macros using the
  old unqualified form need updating."*
- Update the `tests` badge count after Step 5.

- [ ] **Step 5: Regenerate the test-case inventory**

Run: `lua tests/run.lua --list`
Use the output to regenerate `docs/test-cases.md` (testing-§5), then update the README `tests`
badge to the new total. The count must match `lua tests/run.lua`'s final line exactly.

- [ ] **Step 6: Run the full gate one last time**

Run: `lua tests/run.lua && luacheck .`
Expected: 0 failed, 0 warnings, 0 errors. Confirm the README badge number equals the runner's
reported total.

- [ ] **Step 7: Commit — only on explicit instruction**

```bash
git add docs README.md
git commit -m "docs: document the per-unit bars and resync the scope boundary"
```

---

## Post-implementation

- The in-game smoke pass in `docs/smoke-tests.md` is the manual layer the headless harness cannot
  reach (real frames, protected APIs, the live absorb engine). Run it before any release.
- Do **not** bump the version or open a PR unless explicitly instructed.
