# 02 — Proposed changes (HLD + LLD)

Companion to `01_FINDINGS.md`. Findings say what is wrong; this says how to fix it.

**Standard resolved:** Ka0s WoW Addon Standard **v2.17.1 (2026-08-03)**, read from the
`WowAddonStandards` checkout at `master` after verifying it byte-identical to the `raw.githubusercontent.com`
copies. The standards cross-check was **performed**, not skipped. Every change below was checked against it;
where a rule shaped or vetoed an option it is cited as `filename-§N`.

**Scope note.** This is remediation for the review's findings, not a compliance sweep. No change here exists
to close a pre-existing standard deviation unrelated to a finding.

---

## HLD — themes

### T-1 — Make `/at profile` tell the truth about what it did

**Covers:** F-001, F-002, F-003, F-018.

`runProfile` (`settings/Slash.lua:298-368`) is the one verb that forwards raw user input straight into
AceDB's destructive API with no membership check. AceDB's contract is split across the four methods in a way
the handler does not account for: `CopyProfile` **raises** on a bad name, `DeleteProfile(name, true)`
**swallows** a bad name, `SetProfile` **creates** one. The result is three different wrong behaviors from the
same class of typo — a Lua error, a false success, and a silent new profile — plus one path
(`new` over an existing name) that destroys data and reports creation.

The fix is one small private helper (`profileExists`) plus four guards, all in the host's own verb handler.
Every other verb in the file already follows this shape — `runResetAll` and `runResetPosition` both moved
their acknowledgment *inside* the guard for exactly this reason (`settings/Slash.lua:166-174,180-188`); the
profile verb was simply never swept with them. Consistency with those two, not novelty, is what makes this
the right shape.

**Alternatives considered.**

- *`pcall` around each AceDB call.* Rejected: it converts a raise into silence, so `copy` would stop erroring
  and start doing nothing. It also does nothing for `delete` and `new`, which do not raise at all.
- *A `StaticPopup` confirmation on `new`/`delete`.* Rejected as the primary fix: a confirmation for a name
  that does not exist is the wrong question, and a modal on a CLI verb is friction the collection does not
  use anywhere else. A name check answers all four cases exactly; the popup stays where it already is, on
  *Reset All* (`settings/General.lua:126-139`), which is destructive for a name that *is* valid.
- *Pushing the validation into `LibKa0s-Slash-1.0`.* Rejected, and this one is a rule rather than a taste:
  slash-commands-§3 puts the host's own verbs in the host's `NS.COMMANDS`, and the library deliberately owns
  only the **schema** CLI. Profile management is AceDB-shaped and host-shaped; pushing it into a shared
  dispatcher would make the library depend on AceDB, which it does not today.

**Trade-off.** `use` becomes stricter — a name that is not in `GetProfiles()` is refused rather than created.
That is a small behavior change to a documented command, so it is called out in `05_FINAL_SUMMARY.md` and in
the README's command table.

### T-2 — Close two correctness gaps that only bite non-default configurations

**Covers:** F-004, F-005.

Both are single-unit assumptions surviving into a multi-unit, multi-class world. `showOnlyInCombat`'s
`onChange` asks about the player bar before repainting all bars; the background class color reads a frozen
copy of a palette the foreground reads live. Neither is visible on a default install, which is why neither
was caught.

**Alternative considered for F-004:** teaching the guard to ask *"does any unit want to show?"*. Rejected in
favor of dropping the guard: `NS.UpdateAbsorbBar` already early-outs on `ShouldShowBar` per bar
(`modules/Display.lua:181-183`), so the guard is a second copy of a test that is about to run three more
times anyway — and the ladder is the place the codebase has deliberately centralized that decision
(`modules/Display.lua:108-137`).

### T-3 — Put the hot repaint path on a plain loop

**Covers:** F-008.

`NS.ForEachUnit` is a good seam and stays. What changes is that the two callers that run at combat frequency
stop allocating a closure to use it. performance-§2's principle — the measured path pays only what it must —
applies to the work itself, not only to the instrumentation bracketing it, and `tests/perf.lua` already
asserts allocations as a deterministic quantity (performance-§9), so the change is verifiable offline
without a wall-clock assertion.

**Alternative considered:** hoisting `doRepaint`'s closure to module scope with a module-level `painted`
flag. Rejected: a mutable module-scope flag shared with a re-entrant scheduler is a worse hazard than the
allocation it saves, and the plain `for` loop needs neither.

### T-4 — Bring the Profiles page onto the same lazy-body pattern as the other four

**Covers:** F-009.

options-ui-§5 makes the lazy body a MUST for two independent reasons (zero container width at registration;
AceGUI skin hooks installed after load). Four of five pages already comply. This is a five-line move that
makes the fifth match, and removes the only place in the addon where an AceGUI widget is constructed inside
the load window — the mechanism anti-pattern #42 exists to describe.

**Alternative considered:** wrapping the build in `C_Timer.After(0, …)` per options-ui-§9's body rule.
Rejected: `OnShow` is strictly better here (it is also *after* every addon has loaded, and it is what the
other four pages do), and a second deferral idiom in one settings folder is exactly the drift this codebase
keeps eliminating.

### T-5 — Make the two README numbers that go stale silently fail loudly instead

**Covers:** F-006, F-007, F-016.

documentation-§1 item 2 names the `[tests]` badge as *"dynamic data, static badge"* and makes updating it in
the same change a MUST; anti-pattern #40 does the same for `## What's new` against the top Version History
row. Both are currently enforced by memory. The fix is the correction plus a test case, because this repo's
own history says a rule with no gate is a rule that drifts (`docs/pending/LEDGER.md`, row `DOC-01`).

**Alternative considered:** a `sync-docs` run instead of a test. Rejected as insufficient on its own —
`/wow-addon:sync-docs` is a command someone has to remember to run, whereas `tests/run.lua` is the commit
gate (testing).

### T-6 — Delete what is dead and correct what lies

**Covers:** F-011, F-012, F-013, F-014, F-015, F-017.

Six small items, all in the same category: code or prose that describes a call path the code no longer has.
They are grouped because they carry no behavioral risk and are cheapest as one sweep. `F-019` is
deliberately **not** included — it is a recorded, deferred decision (`docs/pending/LEDGER.md`, `PLAN-02`),
not a defect this review reopens.

---

## Upstream change-set (lands in another repo)

**No entry in this document targets a path under `libs/` or `tests/_kit/` in this addon.** If one appears to,
it is the wrong change regardless of size: the next whole-folder re-vendor reverts it silently, and the
regression that follows has no cause anywhere in this repo's git history.

### U-1 — LibKa0s: sweep British spellings, including three user-facing strings

**Covers:** F-010.
**Owning repo:** `https://github.com/tusharsaxena/LibKa0s`.

| Library file (in LibKa0s) | What changes | Minor bump |
|---|---|---|
| `Perf.lua` | `CANCELLED` → `CANCELED` (two user-facing lines), `unlabelled` → `unlabeled` (rendered into every unlabeled capture's report), plus comment occurrences | `LibKa0s-Perf-1.0` file minor 5 → 6 |
| `Core.lua` | comments only (5 occurrences) | `LibKa0s-Core-1.0` minor 3 → 4 |
| `DebugLog.lua` | comments only (6) | `LibKa0s-DebugLog-1.0` minor 7 → 8 |
| `Options.lua` | comment (1) | `LibKa0s-Options-1.0` minor 5 → 6 |
| `OptionsWidgets.lua` | comments (6) | `OptionsWidgets` file minor 5 → 6 |
| `Slash.lua` | comments (6) | `LibKa0s-Slash-1.0` minor 5 → 6 |

Minors are bumped **per file**, never in lockstep (library-stack-§7). The three `Perf.lua` string changes are
user-visible and belong in the library's changelog as such.

**Recommended alongside:** add the US-spelling case to LibKa0s's own suite (the same `BRITISH` table
`tests/test_docs.lua:150-187` here carries), so the library's gate catches the next one rather than a
consumer's reviewer.

**Handoff into this addon.** After the library releases, **re-vendor the whole `LibKa0s/` folder** —
`diff -r ../LibKa0s/LibKa0s libs/LibKa0s` empty — as **its own commit** in this repo, and in every other
consumer. Update the README's *Credits and libraries* LibKa0s version line in the same commit (this repo has
no `CHANGELOG.md`, so that line is the whole provenance record), and re-run
`tests/test_vendor_sync.lua`, which pins the vendored payload to the tag the README names.

**Do not** edit `libs/LibKa0s/*.lua` in this repo for any part of this.

---

## LLD — change-set

### C-1 — `runProfile`: one existence helper, four guards `[F-001, F-002, F-003, F-018]`

**File:** `settings/Slash.lua` (function `runProfile`, lines 298-368).

Add a private helper above `runProfile`:

```lua
-- AceDB's four profile methods disagree about what a bad name means: CopyProfile RAISES,
-- DeleteProfile(name, true) SWALLOWS, SetProfile CREATES. One membership check ahead of all
-- of them is what makes the verb answer the same way for the same mistake.
local function profileExists(db, name)
    for _, p in ipairs(db:GetProfiles()) do
        if p == name then return true end
    end
    return false
end
```

Then, per sub-verb:

```lua
-- use  (F-018)
elseif sub == "use" then
    if subarg == "" then return print("Usage: /at profile use name") end
    if not profileExists(db, subarg) then
        return print(("No profile named '%s' \226\128\148 try /at profile list, or /at profile new %s")
            :format(subarg, subarg))
    end
    db:SetProfile(subarg)
    print("Switched to profile '" .. subarg .. "'")

-- new  (F-002)  — refuse rather than wipe
elseif sub == "new" then
    if subarg == "" then return print("Usage: /at profile new name") end
    if profileExists(db, subarg) then
        return print(("Profile '%s' already exists \226\128\148 use /at profile use %s, or "
            .. "/at profile reset to restore its defaults"):format(subarg, subarg))
    end
    db:SetProfile(subarg)
    db:ResetProfile()
    print("Created and switched to new profile '" .. subarg .. "'")

-- copy  (F-001)  — never let AceDB raise at the user
elseif sub == "copy" then
    if subarg == "" then return print("Usage: /at profile copy name") end
    if subarg == db:GetCurrentProfile() then
        return print("Cannot copy a profile onto itself")
    end
    if not profileExists(db, subarg) then
        return print(("No profile named '%s' \226\128\148 try /at profile list"):format(subarg))
    end
    db:CopyProfile(subarg)
    print("Copied settings from profile '" .. subarg .. "'")

-- delete  (F-003)  — the `silent` flag stays; the CHECK reports, not the raise
else -- sub == "delete"
    ...
    if not profileExists(db, subarg) then
        return print(("No profile named '%s' \226\128\148 try /at profile list"):format(subarg))
    end
    db:DeleteProfile(subarg, true)
    print("Deleted profile '" .. subarg .. "'")
```

**Risk:** low. Pure guards ahead of unchanged calls; `list`, `current` and `reset` are untouched. `use`
becomes stricter — a documented behavior change, see the README note in C-8.

**Standards conformance:** stays inside slash-commands-§3 (host verbs in the host's `NS.COMMANDS`, dispatched
through `LibKa0s-Slash-1.0`) and slash-commands-§4/§5 (every line goes through `local print = NS.Print`, so it
carries the cyan `[AT]` tag; no bare `print(`). Pushing this into the library was **rejected** for
slash-commands-§3 — the schema CLI is the library's, the host's verbs are the host's. No `pcall`-swallow, per
the same reasoning that put the acknowledgments inside the guards at `settings/Slash.lua:166-188`.

**Tests:** extend `tests/test_slashcmds.lua` with one case per guard (copy-onto-self, copy-unknown,
new-existing, delete-unknown, use-unknown), asserting the printed line and that the destructive AceDB method
was **not** called. The mock DB already records calls.

### C-2 — `showOnlyInCombat`: repaint unconditionally `[F-004]`

**File:** `settings/General.lua:50-53`.

```lua
-- before
onChange = function()
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
    if NS.ShouldShowBar() then NS.bus:SendMessage(NS.MSG.REPAINT) end
end,

-- after
onChange = function()
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
    -- Unconditional: the guard used to ask ShouldShowBar() with no argument, which defaults to
    -- "player" (modules/Display.lua:131) and therefore skipped the repaint on a target- or
    -- focus-only setup. A repaint of hidden bars is already free — NS.UpdateAbsorbBar early-outs
    -- on ShouldShowBar per bar — so there is nothing left for a guard to save.
    NS.bus:SendMessage(NS.MSG.REPAINT)
end,
```

**Risk:** very low. Worst case is one extra coalesced pass that early-outs on every bar.

**Standards conformance:** the write still goes through the schema row's `onChange`, reached from the single
write seam `NS.SetByPath` (architecture-§5, options-ui-§1's single-write-seam MUST); no new path is added.

**Tests:** a case in `tests/test_visibility.lua` — player disabled, target enabled, flip
`showOnlyInCombat` — asserting `REPAINT` is published.

### C-3 — Background class color from the live API `[F-005]`

**File:** `core/Data.lua:110-144`.

Delete the `bgClassColors` table (`:112-127`) and rewrite `GetBgClassColor` to reuse the resolved foreground
color:

```lua
local backgroundMultiplier = 0.2

local playerBgClassColor
local function GetBgClassColor()
    if not playerBgClassColor then
        -- Derived from the SAME C_ClassColor result the bar fill uses, rather than a second
        -- hardcoded palette: a class Blizzard adds or retunes then carries the background with it
        -- instead of falling through to white.
        local cc = GetPlayerClassColor()
        playerBgClassColor = {
            r = cc.r * backgroundMultiplier,
            g = cc.g * backgroundMultiplier,
            b = cc.b * backgroundMultiplier,
        }
    end
    return playerBgClassColor
end
```

**Risk:** low, but **user-visible**: `GetPlayerClassColor` already falls back to `{1,1,1}` when the API
answers nil, so an unknown class now yields a dark gray background instead of white — a better default, and
the only rendered difference. Verify the per-class values against the old table for two or three classes in
the smoke tests; they are the same source data.

**Standards conformance:** localization-§4 / anti-pattern #37 — the code keys off `UnitClass`'s **second**
return (`classFilename`, the non-localized token), which is already what both functions do and stays that
way. No localized display string is matched.

**Tests:** `tests/test_data.lua` — assert `GetBgColor` returns the foreground class color times
`backgroundMultiplier` for a mocked class, and the gray fallback for an unknown one.

### C-4 — Plain loops on the repaint path `[F-008]`

**Files:** `modules/Timer.lua:32-36`, `modules/Display.lua:213-224`.

```lua
-- modules/Timer.lua, inside doRepaint
-- before
local painted = false
NS.ForEachUnit(function(unit)
    if NS.UpdateAbsorbBar(unit) then painted = true end
end)

-- after — a plain loop: ForEachUnit is the right seam for cold callers, but this one runs up to
-- 1/throttleWindow times a second and the closure it needs captures `painted`, so it cannot be
-- hoisted. Three lines, zero allocation.
local painted = false
for _, unit in ipairs(NS.Units.LIST) do
    if NS.UpdateAbsorbBar(unit) then painted = true end
end
```

```lua
-- modules/Display.lua — hoist the three handler bodies to file scope, allocate once at load
local function paintAppearance(unit) NS.UpdateBarAppearance(unit) end
local function paintVisibility(unit) NS.ApplyVisibility(unit) end
local function paintPosition(unit)   NS.RestoreBarPosition(unit) end
...
ev:RegisterMessage(NS.MSG.APPEARANCE, function() NS.ForEachUnit(paintAppearance) end)
ev:RegisterMessage(NS.MSG.VISIBILITY, function() NS.ForEachUnit(paintVisibility) end)
ev:RegisterMessage(NS.MSG.POSITION,   function() NS.ForEachUnit(paintPosition) end)
```

The three named wrappers are kept (rather than passing `NS.UpdateBarAppearance` directly) so the existing
test seam survives: the handlers deliberately look the functions up **on `NS` at dispatch time** so a suite
can stub them (`modules/Display.lua:210-211`), and a direct reference would freeze the pre-stub function.

**Risk:** low. Behavior is identical; the dispatch-time-lookup property is preserved by construction.

**Standards conformance:** consistent with performance-§2's discipline and performance-§9's
allocation-only offline assertions. `NS.ForEachUnit` is **not** removed — deleting a working seam to save an
allocation on two of its five callers would be the wrong trade.

**Tests:** add an allocation scenario to `tests/perf.lua` asserting bytes allocated across N repaint passes
is flat (a deterministic quantity; never a wall-clock assertion — performance-§9 forbids that). Existing
`tests/test_display.lua` stub-based cases must stay green unchanged; that is the regression proof for the
dispatch-time lookup.

### C-5 — Profiles page: build the body on first `OnShow` `[F-009]`

**File:** `settings/Profiles.lua:46-62`.

```lua
-- after
local container   -- built on first OnShow; see options-ui-§5
ctx.panel:SetScript("OnShow", function()
    if not container then
        container = AceGUI:Create("SimpleGroup")
        container:SetLayout("Fill")
        container.frame:SetParent(ctx.body)
        container.frame:ClearAllPoints()
        container.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      8, -8)
        container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8, 8)
    end
    AceConfigDialog:Open(APPNAME, container)
end)
```

`AceConfig:RegisterOptionsTable(APPNAME, opts)` and the `Settings.RegisterCanvasLayoutSubcategory` return
stay **eager** — that is category registration, which options-ui-§9 and anti-pattern #22 require at load.

**Risk:** low. `AceConfigDialog:Open` releases and rebuilds the container's children on every call
(`libs/AceConfig-3.0/AceConfig-3.0/AceConfigDialog-3.0/AceConfigDialog-3.0.lua:1891-1893`), so repeat shows
behave exactly as now.

**Standards conformance:** implements options-ui-§5's lazy-body MUST and removes the addon's only
load-window AceGUI construction (anti-pattern #42's mechanism). Deferring the **category** was rejected —
anti-pattern #22 and options-ui-§9 forbid it. `C_Timer.After(0, …)` was rejected in favor of `OnShow` for
pattern consistency with the other four pages.

**Tests:** `tests/test_optionssetup.lua` (or `test_widgets.lua`, wherever the page-show cases live) — assert
no AceGUI widget is created until the Profiles panel's first `OnShow`, and that a second `OnShow` does not
create a second container.

### C-6 — README `[tests]` badge → 469, gated by a test `[F-006]`

**Files:** `README.md:7`, `tests/test_docs.lua`.

```
-![Tests](https://img.shields.io/badge/Tests-467%2F467_passing-green)
+![Tests](https://img.shields.io/badge/Tests-469%2F469_passing-green)
```

New case in `tests/test_docs.lua`:

```lua
test("the README tests badge matches the generated inventory", function()
  local x, y = readFile("README.md"):match("Tests%-(%d+)%%2F(%d+)_passing")
  local total = readFile("docs/test-cases.md"):match("%*%*Total%*%*%s*|%s*%*%*(%d+)%*%*")
  assertEqual(x, total); assertEqual(y, total)
end)
```

Note the case is self-referential — adding it moves the total to 470, so the badge and
`docs/test-cases.md` are regenerated **after** all new cases from this bundle land. That ordering is a task
dependency in `04_EXECUTION_PLAN.md`, not an afterthought.

**Standards conformance:** implements documentation-§1 item 2's keep-in-sync MUST and testing-§5's
`docs/test-cases.md`-is-authoritative rule. `%2F` is preserved verbatim — the canonical badge template uses
it, and only the *standard* badge's spaces use `_` instead of `%20`; do not "normalize" the two.

### C-7 — Rewrite the 1.9.0 Version History row from `## What's new` `[F-007]`

**File:** `README.md:159`.

Replace the four-item row with 3-6 player-facing highlights drawn from `README.md:15-24`, leading with the
two the current row omits entirely:

```
| 1.9.0 | <release date> | **Target and Focus absorb bars** — two new bars, off by default …<br>**Each bar switches on independently** — the single Show Bar toggle is gone …<br>**Mirror or copy the Player bar's look** …<br>**Breaking: slash paths are now fully qualified** — `/at set units.player.barWidth 250` …<br>**Show only in combat** …<br>The bar now redraws the instant a shield changes … |
```

Correct the date to the actual release date (the current `2026-07-20` predates the multi-unit work under
`.superpowers/sdd/2026-07-28-multi-unit-bars/`).

**Standards conformance:** documentation-§1 item 5 (the two carry the same highlights, 3-6 bullets, players
not changelog) and anti-pattern #40. The **rejected** direction is trimming `## What's new` down to match the
table — the bullets are the accurate account, and #40 targets the mismatch, not the longer side.

**Tests:** optional but recommended — a `tests/test_docs.lua` case asserting the `## What's new` heading names
the TOC's `## Version:` and that a Version History row exists for it. Full bullet-for-bullet equality is not
machine-checkable and should not be faked.

### C-8 — Version-drift gate + README command-table note `[F-016, C-1 fallout]`

**Files:** `tests/test_docs.lua`, `README.md:70`.

```lua
test("the version is one number in three places", function()
  local toc = readFile("AbsorbTracker.toc"):match("##%s*Version:%s*([%d%.]+)")
  assertEqual(NS.version, toc)
  assertTrue(readFile("README.md"):find("## What's new in " .. toc, 1, true) ~= nil)
end)
```

And update the `/at profile` README row to name the stricter `use` and the refusing `new`:

> `/at profile subcommand` | Manage profiles: `list`, `current`, `use name` (must already exist), `new name`
> (refuses a name that exists), `copy name`, `delete name`, `reset`

**Standards conformance:** documentation-§1 item 7's slash-command table stays generated-from-`NS.COMMANDS`
in shape; only the description text changes. Neither `AbsorbTracker.toc:5` nor `core/Namespace.lua:7` is
deleted — `NS.version` is the headless and degraded-path fallback (`settings/Slash.lua:109`) and is
load-bearing.

### C-9 — Dead-code and comment sweep `[F-011, F-012, F-013, F-014, F-015, F-017]`

| Finding | File | Change |
|---|---|---|
| F-011 | `core/Units.lua:42` | Delete `Units.DeepCopy = deepcopy`; the local stays. |
| F-012 | `core/Units.lua:78-85` | Delete `Units.Set`; move the *reads are mirror-resolved, writes are not* paragraph into `Units.Get`'s comment, where it is still true. |
| F-013 | `modules/Bar.lua:5-6,86-87` | Correct the comment: the aliases exist for the test harness. Drop the two stale reader names. |
| F-014 | `core/DebugLogSetup.lua:107` | Drop the count from the sentence rather than correcting sixteen to fifteen — a number in prose is a thing that goes stale. |
| F-015 | `modules/Timer.lua:50` | Make it match line 57: guard, or drop line 57's guard and comment the load-time invariant. Pick one and apply to both. |
| F-017 | `settings/Slash.lua:211-212,218-220` | Delete both unreachable branches; `core/DebugLogSetup.lua` publishes `SetEnabled` and `Toggle` on both arms. |

**Risk:** the two deletions are verified zero-caller by `grep` across `core/ modules/ settings/ defaults/
locales/ tests/`. Re-run that grep before deleting — a caller added since this review would change the
answer.

**Standards conformance:** anti-pattern #47's spirit — the addon keeps consuming the library rather than
retaining local surface — and testing's rule that a logic change carries a test. These are deletions of
uncalled code and prose edits, so no new case is required beyond the suite staying green at its current
count.

---

## Change index

| ID | Findings | Files |
|---|---|---|
| C-1 | F-001, F-002, F-003, F-018 | `settings/Slash.lua`, `tests/test_slashcmds.lua` |
| C-2 | F-004 | `settings/General.lua`, `tests/test_visibility.lua` |
| C-3 | F-005 | `core/Data.lua`, `tests/test_data.lua` |
| C-4 | F-008 | `modules/Timer.lua`, `modules/Display.lua`, `tests/perf.lua` |
| C-5 | F-009 | `settings/Profiles.lua`, `tests/test_optionssetup.lua` |
| C-6 | F-006 | `README.md`, `tests/test_docs.lua`, `docs/test-cases.md` |
| C-7 | F-007 | `README.md` |
| C-8 | F-016 | `tests/test_docs.lua`, `README.md` |
| C-9 | F-011…F-015, F-017 | `core/Units.lua`, `modules/Bar.lua`, `core/DebugLogSetup.lua`, `modules/Timer.lua`, `settings/Slash.lua` |
| U-1 | F-010 | **LibKa0s repo** — then a re-vendor commit here |
