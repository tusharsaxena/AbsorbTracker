# CCN elimination — AbsorbTracker

Branch `feat/fix-ccn`. Design: `LibKa0s/docs/superpowers/specs/2026-08-04-ccn-elimination-design.md`.

**2 functions** with `lizard` CCN > 15. Target: every one at CCN <= 15, behavior unchanged.

## Exit criteria

1. `luacheck . --quiet` — 0 warnings, 0 errors.
2. `lua5.1 tests/run.lua` — all pass, count >= baseline.
3. `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` — no CCN > 15.
4. No behavior change. No version bump, no CHANGELOG, no merge, no tag.

## Rules

- Preferred shapes, in order: table-driven dispatch; a named file-local helper for a
  self-contained block; a data table + loop replacing repeated defaulting; splitting a
  builder into N small builders.
- No dumping a body into one helper to game the metric. Every resulting function must be a
  unit a reader can name.
- Dispatch/defaults tables are **module-level**, built once at file load — never per call.
- `lizard` counts `and`/`or` as decisions. Prefer `== nil` over `or` wherever a stored
  `false` or `0` must survive.
- Hot paths must not gain a per-call allocation.
- Sixteen functions across the collection have no coverage; where this file says
  `Coverage: NONE`, write a characterization test pinning current behavior **before**
  refactoring.

## Functions

### `runProfile (lizard label: runProfile@298-368@./settings/Slash.lua)` — CCN 21 → target 8

`settings/Slash.lua:298-368` · pattern `elseif-dispatch` · risk **low**

**What it does.** Implements the `/at profile` sub-dispatcher. Guards that AceDB-3.0 is present, splits `rest` into a sub-verb plus its argument, prints the seven-row sub-help when the verb is empty, and otherwise runs one of list / current / use / new / copy / delete / reset — each name-taking verb printing its own `Usage:` line when the name is missing. An unrecognized verb is named and the sub-help reprinted (today via a recursive `runProfile("")`).

**Where the branches come from.** A seven-arm `if sub == ... elseif ...` chain, and inside four of the arms a nested `if subarg ~= "" then ... else print(Usage) end` guard — so the chain contributes roughly twice its arm count. Plus the two-term guard `if not db or not db.SetProfile`, two `x or ""` defaulting expressions on the parse, the `(name == current) and " (current)" or ""` marker in the list loop, and the extra nested `subarg == db:GetCurrentProfile()` check inside the delete arm.

**Fix.** Table-driven sub-verb dispatch, all built once at file load (no per-call allocation).

1. Module-level `local PROFILE_HELP = { {"list","List all profiles"}, {"current","Show current profile name"}, {"use <name>","Switch to profile"}, {"new <name>","Create new profile with defaults"}, {"copy <name>","Copy settings from another profile"}, {"delete <name>","Delete a profile"}, {"reset","Reset current profile to defaults"} }` — order preserved exactly.
2. `local function printProfileHelp()` -> prints `"Profile commands"` then `for _, r in ipairs(PROFILE_HELP) do PrintCmd("/at profile " .. r[1], r[2]) end`. CCN 2. (The source-level column padding in the current calls is whitespace between arguments only, never inside the literals, so the emitted rows are byte-identical.)
3. `local function needsName(verb, fn)` returns `function(db, arg) if arg == "" then return print("Usage: /at profile " .. verb .. " <name>") end return fn(db, arg) end`. One data-driven replacement for the four duplicated arg guards; CCN 2. The closures are created once at load, not per dispatch.
4. Module-level `local PROFILE_VERBS = { ... }` keyed by lowercase verb:
   - `list = function(db) print("Available profiles"); local current = db:GetCurrentProfile(); for _, name in ipairs(db:GetProfiles()) do print("  " .. name .. ((name == current) and " (current)" or "")) end end` (CCN 4)
   - `current = function(db) print("Current profile: " .. db:GetCurrentProfile()) end` (CCN 1)
   - `use = needsName("use", function(db, n) db:SetProfile(n); print("Switched to profile '" .. n .. "'") end)` (CCN 1)
   - `new = needsName("new", function(db, n) db:SetProfile(n); db:ResetProfile(); print("Created and switched to new profile '" .. n .. "'") end)` (CCN 1)
   - `copy = needsName("copy", function(db, n) db:CopyProfile(n); print("Copied settings from profile '" .. n .. "'") end)` (CCN 1)
   - `delete = needsName("delete", function(db, n) if n == db:GetCurrentProfile() then return print("Cannot delete the current profile") end db:DeleteProfile(n, true); print("Deleted profile '" .. n .. "'") end)` (CCN 2)
   - `reset = function(db) db:ResetProfile(); print("Profile reset to defaults") end` (CCN 1)
5. `runProfile` shrinks to: the AceDB guard, the `^(%S*)%s*(.*)$` parse + `:lower()`, `if sub == "" then return printProfileHelp() end`, `local handler = PROFILE_VERBS[sub]`, `if not handler then print("Unknown profile subcommand '" .. sub .. "'") return printProfileHelp() end`, `handler(db, subarg or "")`. CCN 8.

Note the one structural change: the unknown-verb arm calls `printProfileHelp()` directly instead of recursing into `runProfile("")`. Output is identical because the AceDB guard has already passed at that point; the recursion only re-ran the guard.

**Must not change.** Chat output is the contract and is asserted verbatim by the headless suite: the header lines `Profile commands` / `Available profiles`, the seven help rows in exactly that order with the exact `/at profile <verb> <name>` spellings, `Current profile: <n>`, `Switched to profile '<n>'`, `Created and switched to new profile '<n>'`, `Copied settings from profile '<n>'`, `Cannot delete the current profile`, `Deleted profile '<n>'`, `Profile reset to defaults`, `Unknown profile subcommand '<sub>'`, the four `Usage: /at profile <verb> <name>` lines, and `Profile system requires AceDB-3.0`. Also: only the sub-verb is lowercased — `subarg` must keep its case because AceDB profile names are case-sensitive; the ` (current)` marker must attach only to the active profile; `delete` must pass `true` as the second argument to `DeleteProfile` (silent); and `new` must call `SetProfile` before `ResetProfile`, in that order. Not a hot path (chat-driven), but the verb tables must still be module-level so nothing is allocated per invocation.

**Coverage.** tests/test_slashcmds.lua:396-520+ — dedicated `/at profile` block covering sub-help contents, current, list-with-marker, use (with and without a name), new (defaults, and usage), copy (values pulled, and usage), delete (refuses current, deletes other, usage), reset, unknown sub-verb reprinting the sub-help, and case-insensitive sub-verbs. Coverage is strong enough to refactor without adding a characterization test first. The no-AceDB guard line (`Profile system requires AceDB-3.0`) appears uncovered — worth a test before touching that branch.

---

### `NS:RunMigrations (lizard label: NS@138-192@./core/Database.lua)` — CCN 19 → target 8

`core/Database.lua:138-192` · pattern `schema-migration-chain` · risk **medium**

**What it does.** The AceDB schema-migration seam, run from InitDB and on profile change. Ensures `db.global.schemaVersion` exists, lifts every stored profile to the v3 per-unit shape via `migrateAllProfiles()`, backfills any key missing from `NS.defaults.profile` (flat keys and the per-unit rows) with deep copies, then walks the account-wide version chain: v2 retires `updateInterval`, v3 is a stamp-only step, v4 sweeps the dead `hidden` key from every profile via `dropKeyEverywhere`. Each step logs a `[Migrate] vX -> vY` line.

**Where the branches come from.** Three independent sources stacked in one body. (a) A guard/defaulting head: `NS.db and NS.db.global`, `if not g then return end`, `g.schemaVersion or 1`. (b) A nested defaulting/backfill block — `if profile then`, an outer `pairs(defaults)` loop whose body is `if key ~= "units" and profile[key] == nil`, then `profile.units or {}`, an `ipairs(NS.Units.LIST)` loop with `profile.units[unit] or {}`, an inner `pairs` loop and an `== nil` test. That block alone is ~10. (c) A three-arm `if g.schemaVersion < N then ... end` version ladder, with an extra `if profile then` inside the v2 arm and an `if dropped > 0` inside the v4 arm.

**Fix.** Split into two named file-local backfill helpers plus a table-driven version ladder. All new tables are module-level; nothing is allocated per call.

1. `local function backfillFlatKeys(profile, defaults)` — the outer `pairs(defaults)` loop with the `key ~= "units" and profile[key] == nil` test and the `deepcopy` write. CCN 4.
2. `local function backfillUnitKeys(profile, defaults)` — `profile.units = profile.units or {}`, the `ipairs(NS.Units.LIST)` loop, the per-unit `or {}` seed, the inner `pairs(defaults.units[unit])` loop and the `== nil` write. CCN 6.
   `RunMigrations` then calls `if profile then backfillFlatKeys(profile, defaults); backfillUnitKeys(profile, defaults) end` — one `if`, and the two halves each read as their own unit (flat profile keys vs. per-unit rows).
3. Replace the version ladder with a module-level ordered step table, declared after `dropKeyEverywhere` so it can close over it:
```lua
-- Ordered account-wide schema steps. `apply` runs BEFORE the version line is logged,
-- so a step's own [Migrate] output still precedes its "vX -> vY" stamp.
local SCHEMA_STEPS = {
    { to = 2, apply = function(profile)
        -- v2: the poll ticker became event-driven; the old poll-interval key is dead.
        if profile then profile.updateInterval = nil end
    end },
    { to = 3, apply = function() end },
    { to = 4, apply = function()
        -- v4: the global `hidden` master toggle is gone; sweep it from every profile.
        local dropped = dropKeyEverywhere("hidden")
        if dropped > 0 then
            NS.Debug("Migrate", "dropped `hidden` from %s profile(s)", dropped)
        end
    end },
}
```
   and drive it with:
```lua
for _, step in ipairs(SCHEMA_STEPS) do
    if g.schemaVersion < step.to then
        step.apply(profile)
        NS.Debug("Migrate", "v%s \226\134\146 v%s", g.schemaVersion, step.to)
        g.schemaVersion = step.to
    end
end
```
   The existing literals are `"v%s \226\134\146 v2"` etc. with the target hard-coded; `string.format("%s", 2)` yields `"2"`, so the single parametrized format string produces byte-identical output. `apply` is always a function (v3 gets an explicit no-op), so no `if apply` branch is needed.
4. `RunMigrations` retains: the `NS.db and NS.db.global` guard, `if not g then return end`, `g.schemaVersion = g.schemaVersion or 1`, the `migrateAllProfiles()` call and its `if lifted > 0` log, the `if profile then <two backfills> end`, and the step loop with its one `if`. CCN 8.

Adding a v5 later becomes one table row rather than another arm, which is the real win here — this ladder has grown three times already.

**Must not change.** Order is the whole contract and headless tests only partly pin it. `migrateAllProfiles()` must stay UNCONDITIONAL (it is gated on the per-profile `schemaVersion` stamp, never on `g.schemaVersion`) and must run before the backfill, or a pre-v3 profile's flat appearance keys get shadowed by freshly copied defaults. The backfill must run before the version ladder, so the v2 step still clears `updateInterval` after any backfill pass. Every write must be a `deepcopy`, never a reference into `NS.defaults` — an in-game in-place mutation of a saved variable would otherwise poison the defaults for the session. The `[Migrate]` log lines must keep their exact text, their exact count, and their relative order (a step's own message precedes its `vX -> vY` stamp), and `RunMigrations` must remain a silent no-op when `NS.db.global` is absent and idempotent across repeated calls (it is invoked from both InitDB and OnProfileChanged). Login-time only, not a hot path, but keep `SCHEMA_STEPS` module-level rather than rebuilding it per call.

**Coverage.** tests/test_database.lua:6-150+ — a dedicated RunMigrations block: fresh DB reaches v4, an already-v4 DB is unchanged, idempotent across three runs, v2 retires `updateInterval`, flat-key backfill (`throttleWindow`), per-unit scalar backfill, per-unit table defaults are deep-copied (no shared reference), existing user values are not overwritten, safe no-op with no db, `[Migrate]` logged only on an actual bump, the v3 per-profile lift across active and inactive profiles, and the v4 `hidden` sweep across every profile. This is good coverage of the ladder and the backfill. Gap worth closing before the refactor: nothing asserts the ORDERING of the emitted [Migrate] lines (only that they appear), so add a characterization test capturing the full ordered log for a v1 -> v4 upgrade before restructuring.

---
