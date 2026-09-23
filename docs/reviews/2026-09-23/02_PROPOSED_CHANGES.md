# Proposed changes — AbsorbTracker (2026-09-23)

Standard resolved: **Ka0s WoW Addon Standard v2.64.0 (2026-09-23)**, fetched verbatim from `tusharsaxena/WowAddonStandards@master`, with the index plus all 27 section files. Every change below was checked against it and introduces no new deviation. This is a guardrail on these changes, not a compliance audit.

No change in this document targets a path under `libs/` or `tests/_kit/`.

---

## HLD

### Theme A — Make the host-owned slash verbs tell the truth (F-001, F-002, F-003, F-011)

**What.** The profile sub-verbs and `lock`/`unlock` are the addon's own handlers, not the library's. They currently call AceDB or the write seam without checking the preconditions AceDB enforces, and they print fixed success lines. The fix has three parts:

- Check names before acting on them.
- Echo what was **stored**, in the `slash-commands-§5` `set` shape.
- Refresh an open panel after a write, as the other verbs already do.

**Why.** One verb destroys data without warning. Two others raise or lie on a typo. `lock`/`unlock` contradict the refusal printed just before them.

**Alternatives rejected:**
- Wrapping each AceDB call in `pcall` and printing the error. This hides *why*, and it is a second error format beside the dispatcher's.
- Asking for confirmation on `/at profile new <existing>` with a StaticPopup. That adds a modal to a CLI verb; refusing and naming the right verbs (`use`, `reset`) is simpler and just as safe.
- Moving the profile verbs into LibKa0s-Slash. That would be an additive upstream feature, but these verbs read host-specific AceDB and are not duplicated across the collection in this shape. Per anti-pattern #55 there is not yet a proven second consumer with the same semantics.

**Trade-off.** `/at profile new Raid` changes behavior for anyone who relied on it resetting an existing profile. That use is undocumented, and the docs promise "create".

### Theme B — Make the tests test live keys and fail when they should (F-004, and F-006 upstream)

**What.** Point the stale cases at `units.player.*` and at the `appearance` page. Add red-first cases for Theme A, and route the kit fake's fidelity gap upstream.

**Why.** These are `testing-§12` negative/vacuous assertions. The kit fake is also why F-002 is invisible.

**Alternative rejected:** a local stricter AceDB fake under `tests/`. That duplicates the kit and forks it (`testing-§1`, `testing-§8`). The fix belongs in the kit.

### Theme C — Comments and config that describe the code as it is (F-005, F-007, F-008, F-009, F-012, F-013)

**What.** Correct or move the stale comments. Delete the dead lint allowlist entries and the dead printer branch. Make the Options title read `C.BRAND`. Move the test-only aliases out of production.

**Why.** F-005 in particular inverts the §7 invariant at its entry point.

### Theme D — Remove the redundant profile-adopt pass (F-010)

**What.** Drop the no-op `Reevaluate()`, and skip the adopt-path publishes when the latch just stood the addon up, since `StandUp` already published them.

**Why.** It is a double appearance pass on a cold path. It is Low and optional, but the change is also a clarity gain.

---

## LLD

### C-01 — Refuse `/at profile new` on an existing name (F-001)

**Target:** `settings/Slash.lua`, `PROFILE_VERBS.new` (`:431-435`), plus a small helper next to `needsName`.

```lua
-- after needsName(...)
local function profileExists(db, name)
    for _, n in ipairs(db:GetProfiles()) do
        if n == name then return true end
    end
    return false
end

new = needsName("new", function(db, name)
    if profileExists(db, name) then
        return print(("Profile '%s' already exists \226\128\148 /at profile use %s switches to it, /at profile reset resets the current one")
            :format(name, name))
    end
    db:SetProfile(name)
    NS.ResetProfileCounted(db)
    print("Created and switched to new profile '" .. name .. "'")
end),
```

**Also update:**
- The comment at `:427-430`, since its "resets an existing profile" rationale goes away.
- `docs/profiles.md:79`.
- `docs/smoke-tests.md`, with a step for the refusal.

**Risk.** `tests/test_slashcmds.lua:661` ("new logs the switch line, then a (0 rows) reset line") uses the fresh name `FreshOne`, so it is unaffected. The call is `GetProfiles()` on a cold CLI path; no hot-path cost.

**Tests (red first, `testing-§4`), added to `tests/test_slashcmds.lua` (currently 1304 LOC, stays under the cap):**
- `/at profile new <existing> refuses and leaves that profile's values untouched`. Seed `units.player.barWidth = 333` on `Keep`, switch back, run `new Keep`, and assert that `Keep` still holds 333 and the current profile has not changed. `-- red under: removing the profileExists guard.`

**Standards:** `slash-commands-§3` (the handlers are the host's). The refusal is a plain tagged line through `NS.Print` (`slash-commands-§4`). The `events-frames-taint-§8` SHOULD-level pre-format register row already covers profile-name lines, and this adds one more such line with owned values only, so no new deviation is introduced.

### C-02 — Name-check `copy` and `delete` (F-002)

**Target:** `settings/Slash.lua:437-448`. Reuse `profileExists` from C-01.

```lua
copy = needsName("copy", function(db, name)
    if name == db:GetCurrentProfile() then
        return print("Cannot copy a profile onto itself")
    end
    if not profileExists(db, name) then
        return print(("Profile '%s' not found \226\128\148 /at profile list shows them"):format(name))
    end
    db:CopyProfile(name)
    print("Copied settings from profile '" .. name .. "'")
end),

delete = needsName("delete", function(db, name)
    if name == db:GetCurrentProfile() then
        return print("Cannot delete the current profile")
    end
    if not profileExists(db, name) then
        return print(("Profile '%s' not found \226\128\148 /at profile list shows them"):format(name))
    end
    db:DeleteProfile(name, true)
    print("Deleted profile '" .. name .. "'")
end),
```

**Rejected:** `pcall(db.CopyProfile, db, name)`. It swallows the reason and puts a raw AceDB message in chat.

**Tests (red first):**
- `copy <missing> prints not-found and changes nothing`
- `copy <current> refuses`
- `delete <missing> prints not-found and does not claim a deletion`

Against the **current** kit fake, the first two go red only on the *output* assertion, because the fake is silent. Once F-006 lands upstream they also cover the raise. Write the output assertion now. `-- red under: removing the profileExists check (prints "Copied…"/"Deleted…").`

### C-03 — `lock`/`unlock` echo the stored value and refresh the panel (F-003)

**Target:** `settings/Slash.lua:89-98`. Extract the echo `setEnabled` already has (`:313-316`) into one local and use it for all three verbs.

```lua
local function echoStored(path)
    if NS.RefreshOptionsPanel then NS.RefreshOptionsPanel() end
    local row    = NS.FindSchemaRow(path)
    local stored = NS.GetSetting(path)
    local value  = row and NS.FormatSchemaValue(row, stored) or tostring(stored)
    print(SlashLib.FormatKV and SlashLib.FormatKV(path, value) or (path .. " = " .. value))
end

{"lock",   "Lock the bars in place",
    function() NS.SetByPath("locked", true);  echoStored("locked") end},
{"unlock", "Unlock the bars so they can be dragged",
    function() NS.SetByPath("locked", false); echoStored("locked") end},
...
function setEnabled(on) NS.SetByPath("enabled", on); echoStored("enabled") end
```

In combat, `/at unlock` then prints the onChange's refusal followed by `locked = true`. The two lines agree.

**Watch the forward declaration.** `SlashLib` is resolved at `:24`. The degraded arm rebinds `SlashLib` at `:491`. `echoStored` reads `SlashLib.FormatKV` at call time through the upvalue, so it is safe on both arms.

**Update the test.** `tests/test_slashcmds.lua:98-106` currently asserts `contains(out, "Bar unlocked")`. Change it to assert `locked = false`. This is a changed expectation for a behavior change, not a weakened test. Add an in-combat case asserting the output does **not** contain `locked = false` and ends with `locked = true`. `-- red under: restoring the fixed "Bar unlocked" line.`

**Docs.** Update `README.md` and `docs/slash-dispatch.md` if they quote "Bar locked"/"Bar unlocked". Check with `git grep -n 'Bar unlocked\|Bar locked'`.

**Standards:** `slash-commands-§8` (the SHOULD to confirm in `§5`'s `set` shape; the verbs keep writing the one path through the one seam) and `slash-commands-§5` (the stored value is read back through the shared formatter). The color codes are not re-implemented (`testing-§8`).

### C-04 — Point the stale tests at live keys and pages (F-004)

**Target:** `tests/test_slashcmds.lua`.
- `:224-225`, `:371`, `:552`, `:574`: replace `NS.Helpers.RestoreDefaults("bar")` and `("border")` with `NS.Helpers.RestoreDefaults("appearance")`.
- `:545-548`: use `T.rawSet("units.player.barWidth", 456)` and assert `NS.GetSetting("units.player.barWidth") == NS.unitDefaults.barWidth`. Note: `-- red under: a 'new' that copies the previous profile instead of resetting.`
- `:604-606`: the same, with 478.

**Risk.** The leaked `units.target.barWidth = 300` state now gets cleaned up, so a later suite that implicitly depended on it could go red. That would be a real ordering dependency surfacing. Fix it there, not by keeping the leak.

**Inventory.** Case names are unchanged, so the count moves only by C-01, C-02 and C-03's additions.

### C-05 — Correct the §7 comment on the enable verbs (F-005)

**Target:** `settings/Slash.lua:292-309`. Rewrite the two statements. The row's onChange is `NS.SyncEnabledHold()`, which moves the `disabled` hold, and the latch's `StandDown` unregisters every registration (`core/Lifecycle.lua`). Keep the true part: the dispatcher, `config`, `help` and bare `/at` stay live (`slash-commands-§2`/`§7`).

### C-06 — Comment sweep (F-007)

Edit each site listed in F-007 to match the code:
- `settings/General.lua:14-27` (the diagram without `[Test mode]`, with the `[Minimap button]` row).
- `settings/General.lua:41-43`, with the nine-row claim replaced by the composer's actual output for `testModePath` absent.
- `settings/General.lua:73-80`: move the console-path comment down onto `DEBUG_CONSOLE_PATH`.
- `settings/General.lua:209-210`: drop the byte figure and point at `tests/perf.lua`'s `appearancePass` rather than copying a number that goes stale.
- `settings/General.lua:308-309`: `NS.GetThrottleWindow()`.
- `core/PerfSetup.lua:11-13` and `core/CoreSetup.lua:12-14`: the TOC order CoreSetup → Lifecycle → PerfSetup, and why.
- `core/AbsorbTracker.lua:114-117`: the latch's `StandUp`.
- `defaults/Profile.lua:145`: `settings/Appearance.lua`.
- `core/Constants.lua:56-77`: move the `MINIMAP_PATH` comment next to its constant.
- `docs/ARCHITECTURE.md:655`: v1.42.0.

These are comment and doc edits only. Pass criterion: `luacheck .` stays at 0/0 and the suite is unchanged.

### C-07 — Prune the dead `read_globals` (F-008)

**Target:** `.luacheckrc`. Remove `C_Timer`, `hooksecurefunc`, `CreateColor`, `PlaySound`, `strsplit`, `strtrim`, `tinsert` and `tremove`. Run `luacheck .` and expect 0/0. `tests/test_lintconfig.lua` asserts on `ignore` shape only, not this list, so it is unaffected. **Standard:** the `lint` section (a minimal, justified allowlist).

### C-08 — `PARENT_TITLE` reads `C.BRAND` (F-009)

**Target:** `settings/OptionsSetup.lua:26`: `local PARENT_TITLE = NS.Constants.BRAND`. Constants loads before settings (TOC). Keep the local name so the descriptor is unchanged.

### C-09 — Adopt-profile de-duplication (F-010)

**Target:** `core/AbsorbTracker.lua:317-323`.

```lua
local wasDown = NS.lifecycle:IsDown()
NS.SyncEnabledHold()                       -- Set already re-evaluates
local stoodUp = wasDown and not NS.lifecycle:IsDown()
NS.bus:SendMessage(NS.MSG.UNITS)
if not stoodUp then                        -- StandUp already published these three plus VISIBILITY
    NS.bus:SendMessage(NS.MSG.POSITION)
    NS.bus:SendMessage(NS.MSG.APPEARANCE)
    NS.bus:SendMessage(NS.MSG.REPAINT)
end
```

**Risk.** UNITS must still go out: `StandUp` calls `SyncUnitEventFrames` directly, so UNITS is redundant there too, but it is cheap and keeps the non-edge path unchanged.

**Characterization first (`testing-§13`).** Before editing, pin the current publish sequence for:
- a same-state switch, and
- an off→on switch,

counting APPEARANCE deliveries on `NS.Display.__ev`. Then assert that the off→on count drops from 2 to 1. `tests/test_disabled.lua` step 9 already drives an off→on edge, so extend the harness there, or add the pin to `tests/test_database.lua`.

### C-10 — Validate the `/at test` duration (F-011)

**Target:** `settings/Slash.lua:336-349`. Clamp `hold` to `0.5 .. 60` (or refuse a value ≤ 0 with the usage line), and announce with `%.1f s` or `%s`. Add a test that `/at test 1000 -3` prints the usage line or the clamped value.

### C-11 — Remove the dead printer branch (F-012)

**Target:** `settings/Schema.lua:233-239`. Replace it with `local function chatPrint(line) NS.Print(line) end`, resolved at call time and kept as a function so suites can still spy on it.

### C-12 — Move the player aliases out of production (F-013)

**Target:** delete `modules/Bar.lua:163-172`. In `tests/run.lua` (the shared-env setup, before the suites load), add:

```lua
NS.bar, NS.statusBar, NS.valueText, NS.backdropInfo =
  NS.bars.player, NS.bars.player.statusBar, NS.bars.player.valueText, NS.bars.player.backdropInfo
```

Or replace the reads in `tests/test_display.lua`, `test_data.lua` and `test_slashcmds.lua` with `NS.bars.player`. The second option is preferred, because it leaves no alias anywhere. **Risk:** mechanical, but many call sites. Run the full suite.

---

## Upstream change-set (lands in LibKa0s, not here)

### U-01 — The kit's AceDB fake raises where AceDB-3.0 raises (F-006)

- **Repo:** `tusharsaxena/LibKa0s`. **File:** `testkit/mock_record.lua`, the `db.CopyProfile` and `db.DeleteProfile` fakes.
- **Fix:** mirror AceDB-3.0's four `error(…, 2)` calls:
  - self-copy
  - missing copy source (unless `silent`)
  - deleting the active profile
  - deleting a missing profile (unless `silent`)

  Messages should be verbatim from `AceDB-3.0.lua:531-537` and `:581-587`.
- **Version:** bump the kit revision and add a changelog line under the kit's revision docs (`docs/api/testkit/`).
- **Re-vendor:** copy the whole `testkit/` folder into `tests/_kit/` in **every** consumer, as its own commit per consumer (for example, "Re-vendor LibKa0s testkit rev N"). Do not edit this repo's `tests/_kit/` by hand.
- **Consumer check after the re-vendor:** here, `tests/test_slashcmds.lua:560` and `:589` still pass (they use existing, non-current names). Any sibling whose tests self-copy or delete a missing profile will go red. That is the point.

---

## Test and badge movement

C-01 adds 1 case, C-02 adds 3, C-03 adds 1 and edits 1, and C-10 adds 1. The count is expected to move 710 → **716**. `docs/test-cases.md` (regenerated with `lua tests/run.lua --list`) and the README `[tests]` badge **must move in the same commit** as the cases (`testing-§5`). Never hand-edit either.

## Complexity note (for the next release's regeneration, not now)

- C-02 adds branches to two closures that are currently trivial. They should stay well under CCN 5.
- The three CCN-14 functions are untouched.
- `tests/test_slashcmds.lua` grows by roughly 40 lines, to about 1345, and stays in the 1000–1500 band. `RESULTS.md`'s over-cap entry for it is already obsolete (1304 today), and the next `/wow-addon:bump-version` regeneration will record that.
