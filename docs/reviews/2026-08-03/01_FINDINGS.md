# 01 — Findings

**Review:** `wow-addon:review`, full-scope (design, structure, patterns, logic, performance, UX, naming) plus
the WoW-specific sweep (taint, events, frames, deprecated APIs, AceConfig, localization, project conventions).
**Repo:** `AbsorbTracker` (Ka0s Absorb Tracker) — whole repo.
**Date:** 2026-08-03.
**Head:** `9899026 docs+i18n: complete the v2.17.1 dialect sweep`.

**Verdict: minor issues.** The addon is architecturally sound, its green gate is genuinely green
(`lua tests/run.lua` → **469 passed, 0 failed**; `luacheck .` → **0 warnings / 0 errors in 28 files**), the
vendored `libs/LibKa0s/` and `tests/_kit/` are byte-identical to the LibKa0s ship folders (`diff -r` empty on
both), no deprecated API is called outside `core/Compat.lua`, and the combat-secret handling is the most
careful in the collection. Everything below is contained: two user-facing defects in the `/at profile` verb,
a handful of consistency and design issues, one upstream library defect, and nits.

## Standards cross-check

Remediation in `02_PROPOSED_CHANGES.md` was vetted against the **Ka0s WoW Addon Standard v2.17.1
(2026-08-03)**. The section files were read from the local `WowAddonStandards` checkout at `master`; that
checkout was verified byte-identical to the `raw.githubusercontent.com` copies of `STANDARDS.md`,
`layout.md`, `toc-file.md` and `library-stack.md` before being used (a full `curl` sweep timed out on this
network, so the verified-identical local copy stood in — the content is the same bytes, not a paraphrase).
The cross-check was **not** skipped.

This is **not** a compliance audit — no attempt is made to score the addon section-by-section
(`/wow-addon:standards-audit` owns that). Where a finding happens to coincide with a standard rule the rule
is cited, and every fix direction below is one the standard permits.

## Areas checked and found clean

Recorded so a later reader knows the absence of a finding is a result, not an omission.

- **Taint / combat lockdown.** No protected API is called anywhere in the addon's own code. The only frames
  it touches are its own three non-secure bars plus the private `RegisterUnitEvent` frames
  (`core/AbsorbTracker.lua:121`, `modules/Bar.lua:17,46`); no `SetAttribute`, no secure template, no
  `:Hook`. The panel-open combat gate lives inside `LibKa0s-Options-1.0` where options-ui-§2 requires it,
  and the addon wires no second un-gated open path (`settings/Slash.lua:65`).
- **Combat "secret" values.** `UnitGetTotalAbsorbs` results are never run through `tonumber`, never
  compared, and reach only C-side sinks (`AbbreviateNumbers`, `SetValue`, `SetMinMaxValues`) —
  `modules/Display.lua:192-198`. Every debug read is fenced behind `NS.IsConcatSafe`
  (`core/AbsorbTracker.lua:170,232`), which probes `table.concat` rather than `..` as anti-pattern #35
  requires.
- **Deprecated APIs.** Only `core/Compat.lua:12-19` touches one (`GetAddOnMetadata`), behind the
  `C_AddOns` presence check; its two callers both route through the shim
  (`settings/About.lua:25`, `settings/Slash.lua:109`).
- **Event registration.** Events register in `OnEnable`, not `OnInitialize` (`core/AbsorbTracker.lua:73-74`);
  the two per-unit floods use `RegisterUnitEvent` on private frames; the target/focus swap events are
  registered only while that unit is enabled and unregistered otherwise
  (`core/AbsorbTracker.lua:144-153`). No `OnUpdate` handler exists anywhere.
- **Bus discipline.** Three receivers, each on its own `NS.NewBusTarget()` target
  (`modules/Display.lua:214`, `modules/Timer.lua:68`, `core/AbsorbTracker.lua:270`) — anti-pattern #32 is
  respected, and the test mock keys by target.
- **Vendor sync.** `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and `diff -r ../LibKa0s/tests/_kit tests/_kit`
  are both empty (anti-pattern #45/#48 clear), and `tests/test_vendor_sync.lua` pins it.
- **TOC.** Field order, single `## Interface: 120007`, exactly two SavedVariables globals in order, MIT,
  `X-Standard`, `#@no-lib-strip@` bracketing, `libs\LibKa0s\LibKa0s.xml` after Ace3, `core\PerfSetup.lua`
  ahead of its consumers — all as toc-file-§1/§2/§4/§5 require.
- **COMMANDS ↔ README.** Every one of the 17 `NS.COMMANDS` entries (`settings/Slash.lua:61-102`) appears in
  the README command table (`README.md:53-70`) and vice versa.
- **Perf buckets.** All five declared buckets (`core/PerfSetup.lua:42-48`) are reached by a live bracket
  (`core/AbsorbTracker.lua:184`, `modules/Timer.lua:41`, `modules/Display.lua:105,165,202`), and every
  bracket uses the gated `Perf.on and debugprofilestop()` form performance-§2 pins.
- **Degradation stubs.** `core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `core/PerfSetup.lua` and
  `settings/Slash.lua` each answer every member their call sites reach, and none of them re-implements a
  library formatter. `settings/OptionsSetup.lua`'s load-completing stub is the documented exception and
  carries the one load-time member (`LSMValues`) options-ui-§1 calls for.
- **Descriptor shapes.** Every descriptor field the addon passes is one the vendored library actually
  reads, with the call shape the library uses (plain function, not method): DebugLog's
  `isEnabled`/`setEnabled`/`print`/`safeToString`/`initSummary`/`onVisibilityChanged`
  (`libs/LibKa0s/DebugLog.lua:194,199,422,614,631,647`), Perf's `decorate`
  (`libs/LibKa0s/PerfPanel.lua:77,177`), Options' full field set (`libs/LibKa0s/Options.lua:96-121`).
  No addon descriptor passes `L` (the `L`-trap), and `tests/test_ltrap.lua` pins that.

---

## High

### F-001 — `/at profile copy` raises an unhandled Lua error on two ordinary inputs `[bug]` `[ux]`

`settings/Slash.lua:345` calls `db:CopyProfile(subarg)` with no guard and no `pcall`. AceDB-3.0 **raises**
when the name equals the active profile (`libs/AceDB-3.0/AceDB-3.0.lua:581-583`) and again when the named
profile does not exist, because the `silent` argument is not passed
(`libs/AceDB-3.0/AceDB-3.0.lua:585-587`).

**Impact:** a documented command (`README.md:70`) throws a red Lua error popup at the user for a typo or for
copying the profile they are already on — the two most likely things to type.

**Fix direction:** validate against `db:GetProfiles()` and `db:GetCurrentProfile()` before calling, and print
the same tagged, actionable line the rest of the verb uses. The compliant shape is a host-side guard in
`settings/Slash.lua`'s own verb handler — this is a *host verb*, not part of the schema CLI, so it stays here
rather than moving into `LibKa0s-Slash-1.0` (slash-commands-§3: the host owns its verbs).

### F-002 — `/at profile new <existing>` silently destroys the existing profile `[bug]` `[ux]`

`settings/Slash.lua:337-338` does `db:SetProfile(subarg)` then `db:ResetProfile()`. When `subarg` names a
profile that already exists, `SetProfile` switches to it and `ResetProfile` wipes every key in it back to
defaults (`libs/AceDB-3.0/AceDB-3.0.lua:625-635`) — then line 339 reports *"Created and switched to new
profile"*, which is not what happened.

**Impact:** irreversible loss of a saved profile's settings from a single mistyped word, with a success
message. No confirmation, no undo. This is the only destructive path in the addon that has neither a
`StaticPopup` (contrast `settings/General.lua:126-139`) nor a guard.

**Fix direction:** refuse when the name already exists and say so, pointing at `/at profile use` and
`/at profile reset`; keep the create-and-reset behavior for genuinely new names. A confirmation popup is the
alternative but is worse UX for a CLI verb and duplicates a rule that a name check enforces exactly.

---

## Medium

### F-003 — `/at profile delete` reports success for a profile that never existed `[bug]` `[ux]`

`settings/Slash.lua:355` passes `silent = true` to `DeleteProfile`, which is precisely the flag that
suppresses AceDB's *"does not exist"* raise (`libs/AceDB-3.0/AceDB-3.0.lua:535-537`). Line 356 then prints
`Deleted profile '<name>'` unconditionally.

**Impact:** a user who mistypes a profile name is told it was deleted. They then believe their cleanup
worked; the profile is still there. This is the same class of silent lie the codebase already fixed twice
(`settings/Slash.lua:166-174` and `:180-188` both moved their acknowledgment *inside* the guard for exactly
this reason) — the profile verb was not swept with them.

**Fix direction:** check membership of `db:GetProfiles()` first and print a not-found line; keep `silent`
so the check, not the raise, is what reports.

### F-004 — Toggling `showOnlyInCombat` skips the repaint whenever the player bar is off `[bug]`

`settings/General.lua:52` reads `if NS.ShouldShowBar() then …REPAINT end`. `NS.ShouldShowBar` defaults its
argument to `"player"` (`modules/Display.lua:131`), so the guard asks *"should the **player** bar show?"*
before repainting **all** bars.

**Impact:** on a target- or focus-only setup (a supported configuration since 1.9.0 — the player bar has its
own enable toggle and can be off), turning *Show only in combat* off while out of combat makes the target bar
appear via `VISIBILITY` but leaves it holding whatever value it last painted, or the untouched frame default
if it has never painted. It corrects itself on the next absorb or max-health event, so it reads as a
momentary wrong number rather than a hang.

**Fix direction:** publish `REPAINT` when **any** unit's bar should show, or unconditionally — a repaint of
hidden bars is already a no-op (`modules/Display.lua:181-183` early-outs on `ShouldShowBar`), so the guard is
buying almost nothing and costing correctness.

### F-005 — Background class colors are a hand-maintained copy of Blizzard's palette `[design]`

`core/Data.lua:112-127` hardcodes a 13-entry class-color table used only to derive the background tint,
while the foreground path six lines earlier reads the live API (`core/Data.lua:98`,
`C_ClassColor.GetClassColor`). The hardcoded values are the same colors the API returns.

**Impact:** two sources of truth for one fact. When Blizzard ships a fourteenth class (or retunes one), the
bar fill follows automatically and the background does not — the missing entry falls through to
`{1, 1, 1}` white (`core/Data.lua:140-141`), which on a dark UI reads as a rendering bug rather than a stale
table. Nothing in the suite or lint can see this.

**Fix direction:** derive the background tint from the same `C_ClassColor.GetClassColor` result the
foreground uses, multiplied by the existing `backgroundMultiplier` (`core/Data.lua:110`), and delete the
table. Keep the white fallback for a nil API result.

### F-006 — The README `[tests]` badge is stale `[docs]`

`README.md:7` reads `Tests-467%2F467_passing`. The generated inventory says **469**
(`docs/test-cases.md:566`), and a live run agrees (`lua tests/run.lua` → `469 passed, 0 failed, 469 total`).

**Impact:** the badge is one of the two static-text badges documentation-§1 item 2 names as going stale
silently, and it is the number a player or a reviewer reads first. Nothing gates it — `tests/test_docs.lua`
covers angle-bracket placeholders and US spelling but not the badge.

**Fix direction:** update the badge to `469%2F469` and add a case to `tests/test_docs.lua` that parses the
badge and compares it to `docs/test-cases.md`'s Totals row, so the keep-in-sync MUST is enforced rather than
remembered.

### F-007 — `## What's new in 1.9.0` and the 1.9.0 Version History row disagree `[docs]`

`README.md:15-24` lists eight highlights, including the three headline features of the release — the
Target/Focus bars, the removal of the single **Show Bar** master toggle, and the **breaking** slash-path
change. The top `## Version History` row (`README.md:159`) lists four items and mentions none of those three.
Its date (`2026-07-20`) also predates the multi-unit work, which landed under
`.superpowers/sdd/2026-07-28-multi-unit-bars/`.

**Impact:** the two are required to carry the same highlights (documentation-§1 item 5); a `## What's new`
whose bullets do not match the newest Version History row is named non-compliant outright by anti-pattern
#40. Concretely, a player who reads only the table never learns that their `/at set barWidth 250` macro
stopped working.

**Fix direction:** rewrite the 1.9.0 Version History row from the `## What's new` bullets (trimming to the
3-6 the standard asks for, breaking change included) and correct the date to the release date. Do not fix it
the other way round — the `## What's new` bullets are the accurate account.

### F-008 — The coalesced repaint path allocates a closure per pass `[perf]`

`modules/Timer.lua:33-35` calls `NS.ForEachUnit(function(unit) … end)` inside `doRepaint`, allocating a
fresh closure (it captures the `painted` upvalue, so it cannot be hoisted as written) on every throttled
pass — up to `1/throttleWindow` ≈ **10/s** in sustained combat. The three bus handlers do the same
(`modules/Display.lua:217,220,223`), one closure per published message.

**Impact:** small in absolute terms, but it sits on the addon's hottest path, in an addon that ships a
measurement harness precisely to answer this question, and `tests/perf.lua` asserts **bytes allocated** as a
deterministic quantity (performance-§9) — so this is measurable, not speculative. It is also the one place
where the `ForEachUnit` abstraction costs more than the `for _, unit in ipairs(NS.Units.LIST)` it wraps.

**Fix direction:** in `doRepaint`, iterate `NS.Units.LIST` directly (three lines, no closure, no upvalue
capture); in `Display`'s three handlers, hoist the three per-message bodies to file-scope functions and pass
those to `ForEachUnit`. Keep `NS.ForEachUnit` — it is the right seam for the callers that are not hot.

### F-009 — The Profiles page builds its AceGUI body at category-registration time `[design]`

`settings/Profiles.lua:50-55` creates the `SimpleGroup` container and reparents it inside `build()`, which
runs from `NS.CreateOptionsPanel()` at `OnEnable`. Only the `AceConfigDialog:Open` call is deferred to
`OnShow` (`settings/Profiles.lua:60-62`). Every other page in the addon builds nothing until first `OnShow`
(`settings/General.lua:162-193`, `Bar.lua:172-175`, `Border.lua:93-96`, `Font.lua:97-100`).

**Impact:** options-ui-§5 makes the lazy body a **MUST**, for two independent reasons — AceGUI lays children
out against a container whose width is zero at registration, and a widget created inside the load window
keeps whatever art it had *before* later-loading skin addons install their `RegisterAsWidget` hooks (the
mechanism behind anti-pattern #42). A `SimpleGroup` is cheap and art-free so the visible symptom today is
mild, but the page is one widget away from the load-order-decides-how-it-looks failure the standard
describes, and it is the only page in the addon out of step with the pattern.

**Fix direction:** move the container creation and reparenting into the `OnShow` handler behind a
`local container` upvalue built once, exactly as the other four pages guard their bodies. `AceConfigDialog:Open`
already releases and rebuilds children on every call (`libs/AceConfig-3.0/…/AceConfigDialog-3.0.lua:1891-1893`),
so re-showing stays correct and no widget leaks.

---

## Upstream

These land in **another repo**. Fixing them here is forbidden: `libs/` is a copy, and the next whole-folder
re-vendor silently reverts a local patch — producing a regression whose cause is a file copy rather than any
commit in this addon's history.

### F-010 — `[upstream]` British spellings across LibKa0s, including two user-facing strings `[locale]`

**Owning library:** `LibKa0s-Perf-1.0`, `-Core-1.0`, `-DebugLog-1.0`, `-Options-1.0`, `-Slash-1.0` —
repo `https://github.com/tusharsaxena/LibKa0s`.

Twenty-three occurrences of British spelling in the vendored copy. Two of them are **strings the user
reads**, which is the case anti-pattern #46 weights heaviest:

- `libs/LibKa0s/Perf.lua:767` — `P.Log("run CANCELLED — measurements discarded, nothing saved")`
- `libs/LibKa0s/Perf.lua:882` — `"perf run |cffcc5252CANCELLED|r — nothing saved"`
- `libs/LibKa0s/Perf.lua:499` — `"unlabelled"`, rendered into every perf report whose capture has no label

The remainder are comments and doc lines: `Core.lua:76,77,78,79,100`; `DebugLog.lua:180,230,242,253,304,306`;
`Options.lua:508`; `OptionsWidgets.lua:32,56,306,401,403,479`; `Slash.lua:92,98,138,338,349,459`.

**Impact:** localization-§5 makes US English a **MUST** for every authored string, comment and identifier,
and names the sweepability of the whole collection as the reason. This addon's own guard cannot see it —
`tests/test_docs.lua:214` deliberately excludes `libs/` and `tests/_kit/`, correctly, because that code is
not this repo's to spell. So the drift is invisible from every consumer and will stay that way.

**Fix direction — NOT a local edit.** Fix in the LibKa0s repo, **bump each touched file's LibStub minor**
(`Perf.lua`, `Core.lua`, `DebugLog.lua`, `Options.lua`, `OptionsWidgets.lua`, `Slash.lua` — per-file, never
in lockstep, library-stack-§7), then **re-vendor the whole `LibKa0s/` folder** into this addon and every
other consumer as its own commit. `CANCELLED` → `CANCELED` and `unlabelled` → `unlabeled` are user-visible
output changes and belong in the library's changelog. Consider adding the US-spelling case to LibKa0s's own
suite so the library gate catches the next one.

---

## Low

### F-011 — `NS.Units.DeepCopy` is dead `[dead-code]`

`core/Units.lua:42` exports `Units.DeepCopy = deepcopy`. `grep` over `core/ modules/ settings/ defaults/
locales/ tests/` finds the definition and nothing else — no caller in the addon, none in the suite. The
private `deepcopy` it aliases *is* used, twice, inside the same file.

**Fix direction:** delete the export; keep the local.

### F-012 — `NS.Units.Set` is dead, and its comment asserts a call path that does not exist `[dead-code]` `[naming]`

`core/Units.lua:82` defines `Units.Set(unit, key, value)`; its doc comment (`core/Units.lua:78-81`) states
*"The panel hides the appearance widgets while mirrored, so this path is only reachable from the slash CLI."*
The slash CLI does not reach it: `/at set` goes `cli:CliSet` → descriptor `set`
(`settings/Slash.lua:436`) → `NS.SetByPath` (`settings/Schema.lua:142`) → `NS.SetSetting`
(`core/Data.lua:44`) → `NS.SetPath`, which writes the dotted path directly. `Units.Set` has zero callers.

**Impact:** worse than plain dead code — the comment documents a seam that a future reader will trust, and
`Units.Get`'s mirror-resolution asymmetry (which the comment is really explaining, and which *is* real) now
has no code to hang it on.

**Fix direction:** delete `Units.Set` and fold its genuinely useful paragraph — *reads are mirror-resolved,
writes are not, and that asymmetry is deliberate* — into `Units.Get`'s comment, where it still applies.

### F-013 — The player-alias comment names two readers that no longer read `[naming]`

`modules/Bar.lua:5-6` and `:86-87` justify keeping `NS.bar` / `NS.statusBar` / `NS.valueText` /
`NS.backdropInfo` because *"core/DebugLog.lua, settings/Slash.lua (`/at test`) and the test harness reach for
these"*. `core/DebugLog.lua` no longer exists (it became `core/DebugLogSetup.lua`, which does not touch
them), and `/at test` iterates `NS.bars[unit]` (`settings/Slash.lua:283-290`). The only surviving readers are
the suites (`tests/test_data.lua:334-336`, `tests/test_display.lua`).

**Fix direction:** correct the comment to say the aliases exist for the test harness alone — or retire them
and update the ~10 test references, which is the honest end state but is churn this review does not push for.

### F-014 — `NS.Debug` call-site count disagrees between two comments `[naming]`

`core/DebugLogSetup.lua:107` says *"sixteen call sites across five files"*; `docs/file-index.md:32` says
*"fifteen"*. There are **15** real calls across five files — the sixteenth `NS.Debug(` match is the example
inside that same comment.

**Fix direction:** change the code comment to fifteen. Better still, drop the number: a count in prose is a
thing that goes stale, and nothing here needs it to be exact.

### F-015 — `RequestRepaint` and `CancelPendingRepaint` guard `NS.addon` asymmetrically `[design]`

`modules/Timer.lua:50` calls `NS.addon:ScheduleTimer(…)` unguarded; `modules/Timer.lua:57`, four lines later,
guards `if NS.addon and NS.addon.CancelTimer then`. Both reach the same object on the same path.

**Impact:** no live failure — the bus cannot publish `REPAINT` before `core/AbsorbTracker.lua` has created
the AceAddon object — but two adjacent lines making opposite assumptions is exactly what a later reader
copies the wrong half of.

**Fix direction:** pick one. The honest one is unguarded on both, with a one-line comment saying the AceAddon
object is a load-time invariant; the defensive one is guarded on both. Do not leave it split.

### F-016 — The version string has two sources of truth and nothing gates them `[design]`

`AbsorbTracker.toc:5` (`## Version: 1.9.0`) and `core/Namespace.lua:7` (`NS.version = "1.9.0"`). They agree
today. `getVersion` (`settings/Slash.lua:109`) prefers the TOC metadata, so in game a drift would be
invisible, while the headless suite resolves to `NS.version` because the metadata API is absent
(`tests/test_slash.lua:57-66`) — meaning a drift makes the tests and the client disagree, quietly, and no
case pins the two files together.

**Fix direction:** add a case to `tests/test_docs.lua` asserting `NS.version` equals the TOC's `## Version:`
and the newest `## Version History` row. Keep both declarations — `NS.version` is the headless and
degraded-path fallback and is load-bearing.

### F-017 — Two unreachable defensive branches in `/at debug` `[dead-code]`

`settings/Slash.lua:211-212` (`elseif NS.State then NS.State.debug = …`) and `:218-220`
(`else print("Debug console unavailable")`) can never run: `core/DebugLogSetup.lua` publishes `NS.DebugLog`
with both `SetEnabled` and `Toggle` on **both** arms — the live instance (`:72`) and the stub (`:33-67`).

**Impact:** dead branches read as *"the stub might not answer this"*, which is the opposite of the stub
contract the file above it spends twenty lines establishing.

**Fix direction:** delete both branches and let the stub be the single answer, which is what it is for. If a
belt-and-braces guard is wanted, guard `NS.DebugLog` itself once at the top of `runDebug` rather than
per-member.

### F-018 — `/at profile use <typo>` silently creates an empty profile `[ux]`

`settings/Slash.lua:330` calls `db:SetProfile(subarg)` for any string. AceDB creates the profile on demand,
so a typo yields a brand-new defaults-only profile that the user is now sitting on, reported as
*"Switched to profile 'raidd'"*.

**Impact:** milder than F-002 (nothing is destroyed, and it matches how the AceDBOptions UI behaves), but it
is the same missing membership check, and the user's real profile appears to have lost every setting.

**Fix direction:** fix alongside F-001/F-003 — one shared `profileExists(name)` helper used by `use`, `copy`
and `delete`. For `use`, either refuse unknown names or say plainly that a new profile was created;
refusing is more consistent with `new` existing as its own verb.

### F-019 — All user-facing strings are hardcoded English `[locale]` *(informational — already tracked)*

`locales/enUS.lua:6` establishes the metatable-fallback `NS.L` seam; nothing wraps a string in it, and every
label, tooltip, chat line and popup is an English literal (e.g. `settings/General.lua:127`,
`settings/Slash.lua:171`). `locales/enUS.lua:8-12` documents this deliberately.

**Impact / status:** recorded as a known limitation, deferred with a decision on record —
`docs/pending/LEDGER.md` row `PLAN-02` (*"Localization decision not made this run"*). **No action is
requested by this review**; it is listed only so the sweep is complete and a future reader does not read its
absence as an oversight.

---

## Finding index

| ID | Severity | Tag | Location |
|---|---|---|---|
| F-001 | High | `[bug]` `[ux]` | `settings/Slash.lua:345` |
| F-002 | High | `[bug]` `[ux]` | `settings/Slash.lua:337-339` |
| F-003 | Medium | `[bug]` `[ux]` | `settings/Slash.lua:355-356` |
| F-004 | Medium | `[bug]` | `settings/General.lua:52` |
| F-005 | Medium | `[design]` | `core/Data.lua:112-144` |
| F-006 | Medium | `[docs]` | `README.md:7` |
| F-007 | Medium | `[docs]` | `README.md:15-24`, `README.md:159` |
| F-008 | Medium | `[perf]` | `modules/Timer.lua:33-35`, `modules/Display.lua:217-223` |
| F-009 | Medium | `[design]` | `settings/Profiles.lua:50-55` |
| F-010 | Medium | `[upstream]` `[locale]` | `libs/LibKa0s/Perf.lua:499,767,882` (+5 files) |
| F-011 | Low | `[dead-code]` | `core/Units.lua:42` |
| F-012 | Low | `[dead-code]` `[naming]` | `core/Units.lua:78-85` |
| F-013 | Low | `[naming]` | `modules/Bar.lua:5-6,86-87` |
| F-014 | Low | `[naming]` | `core/DebugLogSetup.lua:107` |
| F-015 | Low | `[design]` | `modules/Timer.lua:50,57` |
| F-016 | Low | `[design]` | `AbsorbTracker.toc:5`, `core/Namespace.lua:7` |
| F-017 | Low | `[dead-code]` | `settings/Slash.lua:211-212,218-220` |
| F-018 | Low | `[ux]` | `settings/Slash.lua:330` |
| F-019 | Low | `[locale]` | `locales/enUS.lua:6` *(informational)* |
