# AbsorbTracker — proposed changes (HLD + LLD), 2026-09-07

Derived from `01_FINDINGS.md`. Change IDs are `C-NN`; each names the finding IDs it covers.

**Standard resolved:** Ka0s WoW Addon Standard **v2.38.0 (2026-09-02)**, from the local checkout
`/mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards` at `03a9aa0`. The published raw fetch
timed out and was abandoned; the local copy's index header matches the published version string, and
every `filename-§N` citation below was read out of it. The cross-check was **performed**, not
skipped.

**No entry in this document targets a path under `libs/` or `tests/_kit/`.** The one upstream change
is in its own section and lands in the LibKa0s repo.

---

## HLD — themes

### Theme A — make the perf record say only what the run observed

`ABSORBTRACKER-R-01`. The addon's descriptor and `docs/performance.md` both promise that nesting is
*observed*, not merely declared, and both are wrong for the one nesting that matters. `paintBar`'s
total genuinely sits inside `repaintPass`'s, so a reader who sums them double-counts, and the report
sentence that would warn them says "declared" instead of "declared and observed".

The obvious shortcut — drop `within = "repaintPass"` from the declaration so the claim and the
evidence agree — is **rejected**. `performance-§3` wants both halves precisely so they can
contradict each other, and dropping the declaration trades a wrong-parent claim for a
disjoint-totals claim, which is strictly worse because *nothing* contradicts it. `core/PerfSetup.lua`
already reasons this way in writing for `visibility` (lines 68-71). So the fix supplies the parent.

The mechanical difficulty is that `openBucket` is a `modules/Display.lua` file-local
(`modules/Display.lua:16`) while `doRepaint` is in `modules/Timer.lua`. Two options were weighed:

- **Move the open-bucket upvalue to a shared seam** and have both modules read it. Rejected: it
  makes a cross-module mutable global out of what is currently a deliberately-scoped local, and the
  comment at `modules/Display.lua:10-15` argues for a plain upvalue over a stack precisely because
  the module nests exactly one level.
- **Chosen: have `doRepaint` pass its bucket down the call it already makes.** `NS.UpdateAbsorbBar`
  gains an optional second parameter, `parentBucket`, defaulted to nil; `doRepaint` passes
  `"repaintPass"` from inside its own bracket. Nothing else changes, the argument is nil on every
  other call path (the `/at test` path, the bus handlers), and the bracket stays Shape A — one
  upvalue read, one field read, one boolean test, no call (`performance-§2`; the shape is spelled
  out at `libs/LibKa0s/Perf.lua:437-446`).

### Theme B — one write path, and it is the logged one

`ABSORBTRACKER-R-02`. `Units.CopyFromPlayer` is the last place in the addon that writes a
schema-row path by assigning into the profile table. Everything else — the panel widgets, `/at set`,
`/at reset`, `/at toggle`, `ApplyDefault` — goes through `NS.SetByPath`, which is where
`debug-logging-§10`'s mandated `[Set] <path> = <value>` line is emitted and where each row's
`onChange` fires.

The tempting alternative — add a bespoke `NS.Debug("Copy", …)` line inside `CopyFromPlayer` —
is **rejected**: it is a second write path with its own logging, which is exactly what
`architecture-§5` (schema-as-single-source) and `debug-logging-§10` exist to prevent, and it would
still skip the `onChange` half.

### Theme C — adopt the library's render seam instead of three hand-rolled `OnShow`s

`ABSORBTRACKER-R-04`. `LibKa0s-Options-1.0` publishes `SetRenderer`, uses it for its own landing
page, and hangs two things off it that a bare `SetScript` does not get: the sidebar-path combat
guard (`options-ui-§2`, last bullet — a SHOULD) and the dirty re-render
(`options-ui-§11` — a MUST). This addon's three sub-pages hand-roll the trigger.

The tempting alternative — copy an `InCombatLockdown()` check into each page's `OnShow` — is
**rejected** as `anti-pattern #47` (hand-rolling what the options library provides), three times
over. Adopt the seam.

Note the interaction with `options-ui-§5`: the Defaults-button call **must** stay at the top of
every `OnShow`, outside the render guard. The library's `SetRenderer` already makes that call
(`libs/LibKa0s/Options.lua:698`), so the page files must *drop* their own or the button gets built
twice. This is the one place the change is not purely additive and needs verifying in-client.

### Theme D — restore the two guards that have gone slack

`ABSORBTRACKER-R-03` (the perf ceiling that is now 6.7× the value it guards) and
`ABSORBTRACKER-R-05` (the one SavedVariables number that reaches a library comparison unvalidated).
Both are "a defence that was written correctly and has since stopped defending".

For `R-05` the alternative of inlining `tonumber(...) or 0.1` at `modules/Timer.lua:50` is
**rejected** on cohesion grounds: `core/Data.lua` already holds three clamped getters whose whole
value is that they are one recognisable pattern in one place (`core/Data.lua:236-283`), and a
fourth belongs beside them.

### Theme E — say true things

`ABSORBTRACKER-R-07`, `-09`, `-10`, `-11`, `-12`. Comment drift, one dead export, one duplicated
walk, two rows firing a restyle they have no stake in. Individually trivial; collectively they are
the difference between a codebase whose comments can be trusted and one where each has to be
re-verified.

---

## Upstream change-set (lands in LibKa0s, NOT here)

### `C-U1` — `OptionsCompose` media rows must yield a table, not a closure — covers `ABSORBTRACKER-R-08`

- **Repo:** `LibKa0s` (`https://github.com/tusharsaxena/LibKa0s`).
- **File:** `LibKa0s/OptionsCompose.lua`, lines 231, 275, 304.
- **Fix:** each media-backed row currently declares
  `values = function() return O.LSMValues(kind) end`. `O.LSMValues(kind)` **already returns the
  closure the flow engine wants**, so the correct declaration is `values = O.LSMValues(kind)` — drop
  the outer wrapper. Verify against `enumList` (`OptionsWidgets.lua:78`), which calls `row.values()`
  exactly once and requires a table back.
- **Consider additionally:** widening the empty-dropdown report at `OptionsWidgets.lua:1442` so it
  also fires when `row.values` is present but `enumList` yields nothing. That is what made this
  defect silent, and it is a second consumer-visible improvement, but it is a separate decision and
  should be a separate commit.
- **Minor bump:** `OptionsCompose.lua` `COMPOSE_MINOR` 2 → **3**, with the matching
  `lib.MODULES.OptionsCompose` entry and the `CHANGELOG.md` version block, which
  `tests/test_versioning.lua` in that repo enforces.
- **Re-vendor:** copy the **whole** `LibKa0s/` folder (and `testkit/` if its revision moved) into
  every consumer as its own commit, updating each consumer's `CLAUDE.md` provenance line in the same
  commit so `tests/test_vendor_sync.lua` stays green.
- **In this repo, in the re-vendor commit and not before:** delete `fixMediaValues` and its three
  call sites (`settings/Appearance.lua:120-136`, `:181`, `:237`, `:257`) and the
  `tests/test_schema.lua` cases that pin the workaround, then regenerate `docs/test-cases.md` and
  move the README badge. The source comment at `settings/Appearance.lua:126-129` already instructs
  exactly this.
- **Consumers to sweep:** every Ka0s addon adopting `BarGroup`, `BorderGroup` or `FontGroup`. This
  addon has the workaround; a sibling that does not is shipping three empty dropdowns today.

---

## LLD — the change-set

### `C-01` — supply `repaintPass` as `paintBar`'s observed parent — covers `ABSORBTRACKER-R-01`

**Files:** `modules/Display.lua`, `modules/Timer.lua`. Optionally `docs/performance.md` (no change
needed if the code is fixed — the doc becomes true).

`modules/Display.lua:331` — `NS.UpdateAbsorbBar` takes an optional parent bucket:

```lua
-- before
function NS.UpdateAbsorbBar(unit)
...
    if t0 then Perf.Note("paintBar", debugprofilestop() - t0) end

-- after
--- @param parentBucket string|nil  the bucket this paint is running inside, supplied by the caller
--- rather than declared here: doRepaint is the only caller that HAS a parent, and a hard-coded
--- "repaintPass" would be the same unverified declaration in a new place (performance-§3).
function NS.UpdateAbsorbBar(unit, parentBucket)
...
    if t0 then Perf.Note("paintBar", debugprofilestop() - t0, parentBucket) end
```

`modules/Timer.lua:33-35` — `doRepaint` passes it from inside its own bracket:

```lua
-- before
NS.ForEachUnit(function(unit)
    if NS.UpdateAbsorbBar(unit) then painted = true end
end)

-- after
-- The bucket this pass IS, handed down so paintBar's note records the containment the run observed
-- rather than the one core/PerfSetup.lua merely declares. Passed only when the bracket is open --
-- `t0` is nil with capture off, so a dormant pass hands down nil and allocates nothing extra.
local parent = t0 and "repaintPass" or nil
NS.ForEachUnit(function(unit)
    if NS.UpdateAbsorbBar(unit, parent) then painted = true end
end)
```

**Risk.** Low. The parameter is nil on every other call path — the bus `REPAINT` handler goes through
`doRepaint`, and `/at test` (`settings/Slash.lua:278-285`) paints the bars directly without calling
`UpdateAbsorbBar` at all. Two existing suites index `NS.UpdateAbsorbBar` and call it bare; both keep
working.

**Regression pressure.** This change **adds** at least two cases and therefore moves the pass count
(547 → 549+) and the README `[Tests]` badge, in the same change:
- `perf: the capture OBSERVES paintBar inside repaintPass, it does not just declare it` — the exact
  twin of the existing `tests/test_perf.lua:68-88`, mutation-checked by deleting the third argument.
- `perf: a standalone UpdateAbsorbBar claims no parent rather than inventing one` — the twin of
  `tests/test_perf.lua:90-104`, guarding against a hard-coded `"repaintPass"` sneaking back in.

**Standards conformance.** Shaped by `performance-§3` (declared *and* observed nesting) and
`performance-§2` (the bracket stays Shape A — the `and` is inside the existing `if t0`-gated region,
so a dormant pass evaluates one extra `and` against a nil and allocates nothing). The rejected
alternative — dropping `within = "repaintPass"` from `core/PerfSetup.lua:63` — would introduce a
**new** deviation from `performance-§3`, because nested totals that declare no containment are the
ones a reader sums.

---

### `C-02` — route `Units.CopyFromPlayer` through `NS.SetByPath` — covers `ABSORBTRACKER-R-02`

**Files:** `core/Units.lua`, `settings/UnitPanel.lua`.

`core/Units.lua:111-119`:

```lua
-- before
function Units.CopyFromPlayer(unit)
    if unit == "player" then return end
    local src, dst = Units.Config("player"), Units.Config(unit)
    if not (src and dst) then return end
    for _, key in ipairs(Units.APPEARANCE_KEYS) do
        dst[key] = deepcopy(src[key])
    end
    dst.mirror = false
end

-- after
-- THROUGH THE SINGLE WRITE SEAM, not into the table. Every one of these twenty paths is a
-- registered schema row, so debug-logging-§10 wants one `[Set] units.<unit>.<key> = <value>` line
-- per mutation and architecture-§5 wants each row's own onChange to fire. Writing into `dst`
-- directly did neither, and the button compensated with a manual APPEARANCE publish -- which held
-- only for as long as no copied row grew an onChange of its own.
--
-- The deep copy stays: a color default is a table, and two units must never share one.
function Units.CopyFromPlayer(unit)
    if unit == "player" then return end
    local src, dst = Units.Config("player"), Units.Config(unit)
    if not (src and dst) then return end
    local prefix = "units." .. unit .. "."
    for _, key in ipairs(Units.APPEARANCE_KEYS) do
        NS.SetByPath(prefix .. key, deepcopy(src[key]))
    end
    NS.SetByPath(prefix .. "mirror", false)
end
```

`settings/UnitPanel.lua:224-228` — the manual publish becomes redundant, because the copied rows'
own `onChange` (the schema's `defaultOnChange`, `settings/Schema.lua:158-160`) publishes
`APPEARANCE`:

```lua
btn:SetCallback("OnClick", function()
    NS.Units.CopyFromPlayer(ctx.unit)
    -- No manual APPEARANCE publish: every copied row now fires its own onChange through
    -- NS.SetByPath, and the mirror row's is the schema default, which publishes it.
    Helpers.RenderUnitPanel(ctx, pageKey)
end)
```

**Risk — the real one, and it is a perf risk, not a correctness one.** Twenty `SetByPath` calls each
fire `defaultOnChange`, i.e. **twenty** `APPEARANCE` publishes where there was one. Each publish is
a full three-bar restyle: today's `appearancePass` measures **0.034 ms and 384.5 bytes per pass**
(`tests/perf.lua`, run 2026-09-07), so twenty is ~0.7 ms and ~7.7 KB on one button click. That is
acceptable for a once-in-a-while click and it is *not* acceptable to leave unremarked. Two
mitigations, in preference order:

1. Keep it simple and accept 0.7 ms on a manual click. Measure it: add a `copyStyling` scenario to
   `tests/perf.lua` so the cost is recorded rather than assumed, and re-check it after the change.
2. If (1) measures worse than expected in-client, gate the fan-out: publish once at the end and have
   the copy loop use a `NS.SetByPath` variant that suppresses `onChange`. **Only if measured** —
   introducing a second write path to avoid a cost nobody has observed would undo this change's
   entire point.

**Regression pressure.** Adds at least one case (`copy styling logs one [Set] line per copied key`)
and one perf scenario. Scenarios must **not** be counted in `docs/test-cases.md` or the README badge
(`testing-§7`); the new test case must.

**Standards conformance.** Required by `debug-logging-§10` (MUST — log once at the single write
seam) and `architecture-§5`. The rejected alternative — a bespoke `[Copy]` debug line inside
`CopyFromPlayer` — would leave a second write path in place, which is the deviation this change
removes.

---

### `C-03` — re-baseline the dormant-bracket ceiling — covers `ABSORBTRACKER-R-03`

**File:** `tests/perf.lua:229-238`.

```lua
-- before
-- ... 312.0 bytes/pass is the measured figure with the brackets off ...
local PROBE_OFF_BYTES_CEILING = 320

-- after
-- ... 48.0 bytes/pass is the measured figure with the brackets off, re-baselined 2026-09-07 (it was
-- 312.0 before settings/Schema.lua's ResolvePath grew its flat-key fast path). The headroom below is
-- deliberately thin, because one extra table per pass is exactly the regression this is here to
-- catch. Move it in EITHER direction only with a recorded reason and the date: a rise is the
-- finding, and a fall left unrecorded is a guard that has quietly stopped guarding.
local PROBE_OFF_BYTES_CEILING = 72
```

**Risk.** The new value must be verified on the reviewer's machine *and* be robust to interpreter
differences — the figure is a `collectgarbage("count")` delta and is not perfectly stable. 72 gives
50% headroom over today's 48.0 while still refusing a second table. **Do not** land this without
running `tests/perf.lua` three times and confirming `probeOverheadOff` does not vary above 56.

**Standards conformance.** `performance-§2` (a dormant bracket is free) and `performance-§9`
(the offline runner stays outside the green gate — this changes an assertion inside it, not its
gating status). No new deviation.

---

### `C-04` — adopt `Helpers.SetRenderer` on the three sub-pages — covers `ABSORBTRACKER-R-04`

**Files:** `settings/General.lua`, `settings/Appearance.lua`, `settings/Profiles.lua`,
`settings/OptionsSetup.lua`.

`settings/General.lua:283-296`:

```lua
-- before
local rendered = false
ctx.panel:SetScript("OnShow", function()
    H.EnsureDefaultsButton(ctx.panel)
    if rendered then return end
    rendered = true
    H.RenderTabbedSchema(ctx, "general", { [H.MASTER_GROUP] = masterTail })
end)

-- after
-- Through the library's renderer registry rather than a private OnShow. That is what buys the
-- combat guard on the Blizzard-sidebar path (the panel-open guard is bypassed there --
-- options-ui-§2), the dirty re-render options-ui-§11 mandates, and the on-screen-only scoping of
-- RefreshAllPanels. The `rendered` latch is gone: the library owns first-show and re-show.
-- EnsureDefaultsButton is gone too -- SetRenderer already calls it at the top of every OnShow, and
-- a second call would build the button twice.
H.SetRenderer(ctx, function()
    H.RenderTabbedSchema(ctx, "general", { [H.MASTER_GROUP] = masterTail })
end)
```

`settings/Appearance.lua:320-323` and `settings/Profiles.lua:57-67` take the same shape. Profiles is
the most delicate: its body creates the AceGUI `SimpleGroup` on first show and calls
`AceConfigDialog:Open` on **every** show, so its renderer must keep both behaviors — the
`if not container then … end` guard stays inside the renderer, and the `Open` call stays outside it.

`settings/OptionsSetup.lua:318-337` — `SetRenderer` joins the degradation stub's no-op list, with a
line saying why (it is reached from a page builder, so a no-op is the honest answer; and without it
a library-absent load raises out of three page files at build time).

**Risk — the highest of any change here, and it is in-client only.**
- The Defaults button could be built twice or not at all. `options-ui-§5` is emphatic that *when* the
  button is created decides how it looks (the AceGUI-skinning race), so this needs eyes on the
  actual button art, not just a green suite.
- Blizzard's Settings window reaches sub-pages through paths the headless mock does not model. The
  combat refusal in particular is unverifiable headless.
- `Profiles.lua` returns `nil` from its builder without AceDBOptions, and the headless runner relies
  on that self-skip (`tests/run.lua`'s comment says so). Confirm it still does.

**Regression pressure.** Existing cases in `tests/test_widgets.lua` and `tests/test_optionssetup.lua`
drive `ctx.panel:Show()` and assert on what renders; they should keep passing unchanged, and if any
does not, that is the finding. Add one case per page asserting the ctx went through the registry
(`ctx._renderFn` is a function) — three cases, so the count moves 547 → 550 with `C-01`'s two
making 552. `docs/test-cases.md` and the badge move in the same change.

**Standards conformance.** `options-ui-§11` (MUST — dirty re-render, on-screen-only rebuild),
`options-ui-§2` (SHOULD — gate settings work that creates or destroys frames), `options-ui-§5` (the
Defaults button call at the top of every `OnShow`, which the library now owns), and
`anti-pattern #47` (do not hand-roll what the options library provides), which is what rules out
the three-copies-of-a-combat-check alternative.

---

### `C-05` — clamp `throttleWindow` like every other stored number — covers `ABSORBTRACKER-R-05`

**Files:** `core/Data.lua`, `modules/Timer.lua`.

New getter in `core/Data.lua`, immediately after `NS.GetMasterScale` (`core/Data.lua:263`) so the
four clamped readers sit together:

```lua
--- The repaint throttle, clamped to the schema row's own 0.05 .. 1 (settings/General.lua).
---
--- The fourth of these, and for the same reason as the three above it: the number comes out of
--- SavedVariables, which a player can hand-edit and an older profile can be holding anything in.
--- This one is the only one that leaves the addon -- it reaches AceTimer, whose `new()` does
--- `if delay < 0.01` (libs/AceTimer-3.0/AceTimer-3.0.lua:33), so a stored string raises INSIDE the
--- repaint arm, once per absorb event. A non-number reads as the default rather than as the addon
--- having stopped working mid-combat.
function NS.GetThrottleWindow()
    local v = tonumber(NS.GetSetting("throttleWindow"))
    if not v then return NS.flatDefaults.throttleWindow end
    if v < 0.05 then return 0.05 end
    if v > 1 then return 1 end
    return v
end
```

`modules/Timer.lua:50` becomes
`pending = NS.addon:ScheduleTimer(doRepaint, NS.GetThrottleWindow())`.

**Risk.** Very low. The clamp bounds duplicate the schema row's `min`/`max`
(`settings/General.lua:228`) — the same duplication `GetMasterAlpha`/`GetMasterScale` already carry,
and the existing `tests/test_schema.lua` invariant *"number rows declare a sane min/max bracketing
their default"* covers one half of it. Consider adding a case that the getter's bounds and the row's
agree, so the copy cannot drift.

**Regression pressure.** Adds ~3 cases (junk string falls back, below-min clamps, above-max clamps);
count moves accordingly.

**Standards conformance.** `savedvariables-§1` (a stored value is untrusted input) and
`architecture-§5`. No new deviation. Rejected: inlining `tonumber` at the call site — it would put a
fourth spelling of a pattern that exists three times in one file.

---

### `C-06` — the small-truths sweep — covers `ABSORBTRACKER-R-07`, `-09`, `-11`, `-12`

**Files:** `core/Units.lua`, `core/AbsorbTracker.lua`, `core/Database.lua`, `settings/General.lua`.

- `core/Units.lua:74` and `:108` — "fifteen appearance keys" → "nineteen", or better, drop the count
  and let `Units.APPEARANCE_KEYS` be the answer. The header at `core/Units.lua:19` already says
  nineteen, so at minimum the file must stop saying both.
- `core/AbsorbTracker.lua:69` — replace *"(CreateOptionsPanel is not safely re-callable)"* with the
  current truth: the extraction is for test isolation, and `LibKa0s-Options-1.0` owns the
  idempotence (`libs/LibKa0s/Options.lua:838-844`).
- `core/Database.lua:95-112` — move `forEachProfile` above `migrateAllProfiles` and reduce the latter
  to `local function migrateAllProfiles() return forEachProfile(NS.MigrateProfileToV3) end`. Delete
  the duplicated five-line comment block, keeping the one on `forEachProfile`.
- `settings/General.lua:210-230` — give the `throttleWindow` row an explicit
  `onChange = function() end` with a one-line reason (*the next repaint reads the value fresh at
  modules/Timer.lua:50; a restyle publishes nothing this row affects*). Do the same for the composed
  `state.debugConsole` row by adding its path to the `masterOnChange` table at
  `settings/General.lua:117-158`, which is already keyed by path for exactly this purpose.

**Risk.** The `migrateAllProfiles` collapse is the only one with behavior on the line. It is
behavior-identical by inspection; run `tests/test_database.lua`'s multi-profile v3 cases before and
after and diff the output.

**Standards conformance.** No rule shapes these beyond the general one that a comment stating a fact
must state a true one. `anti-pattern #55` was checked against the `forEachProfile` collapse: this is
**not** a premature abstraction — the abstraction already exists, has two consumers with identical
semantics, and the collapse merely stops the second from being a hand-copy.

---

### `C-07` — delete `NS.PartitionUnitRows` — covers `ABSORBTRACKER-R-10`

**Files:** `settings/Schema.lua`, `tests/test_schema.lua`, `docs/schema.md`,
`docs/module-map.md`, `docs/ARCHITECTURE.md`, `docs/test-cases.md`, `README.md`.

Delete `settings/Schema.lua:99-111`, its case at `tests/test_schema.lua:524-530`, and the three doc
entries that already describe it as caller-less. Regenerate `docs/test-cases.md` with
`lua tests/run.lua --list > docs/test-cases.md` and move the README `[Tests]` badge **in the same
commit** — this change moves the count **down** by one, which is the direction reviewers forget.

**Risk.** None functionally. The only judgment call is whether the function is worth keeping as a
documented seam for a future consumer. It is not: `settings/UnitPanel.lua:110-124` already replaced
it with `partitionTabs`, which partitions on a different axis, so a future per-unit renderer would
more likely extend *that* than resurrect this.

**Standards conformance.** Dead-export rule. `testing-§7` (the badge and inventory are one
authoritative count) governs the regeneration.

---

### `C-08` — no change: record the automated-test drift for the next release — covers `ABSORBTRACKER-R-06`

**Files touched: none.** `docs/automated-tests/RESULTS.md` and its bundles are **regenerated at
release** by `/wow-addon:bump-version` (`automated-tests-§1`), never hand-edited and never
regenerated by a review or a fix commit. What this entry does is name what the next regeneration
should show, so a reader can tell a stale report from a wrong one:

- test count **508 → 552-ish**, depending on how many of the cases above land;
- NLOC **7997 → ~8900**, functions **1126 → ~1253**;
- max CCN **14 → 15**, the new maximum being `NS.ValidateSchema` in `settings/Schema.lua`;
- `./settings/Bar.lua`, `./settings/Border.lua` and `./settings/Font.lua` disappearing from
  `complexity.txt`, and `./settings/Appearance.lua` appearing.

If `C-07` lands, `NS.PartitionUnitRows@…@./settings/Schema.lua` (CCN 11) leaves the report too.

**Standards conformance.** `automated-tests-§1` and `performance-§10` — a hand-edited report is worse
than an absent one, and a complexity gate on commits is a documented anti-pattern, not a remedy.
