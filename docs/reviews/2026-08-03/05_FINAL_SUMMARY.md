# 05 — Final summary

> **Status: written ahead of implementation.** This bundle was produced by a review run that applied **no
> code changes**. The document below is the shipping record as it will read once every change in
> `02_PROPOSED_CHANGES.md` has landed and every check in `03_SMOKE_TESTS.md` has passed.
>
> **It MUST be reconciled with what actually shipped before it is quoted anywhere.** The counts, the
> "deferred" list and the verification pointers are the parts that go wrong. This repo has been bitten by
> exactly this once already — `docs/pending/LEDGER.md`, row `DOC-01`, records a previous
> `05_FINAL_SUMMARY.md` left claiming *"18/18 addressed, nothing deferred"* with its placeholders unfilled,
> knowingly left as frozen history. Do not add a second one.

---

## Headline

This cycle hardened the parts of Ka0s Absorb Tracker that only misbehave once you leave the default
configuration. The `/at profile` command stopped being able to throw a Lua error, silently destroy a saved
profile, or report a deletion that never happened; the *Show only in combat* toggle now refreshes every bar
rather than only the player's; the background class color follows Blizzard's live palette instead of a
hand-copied one; the settings panel's Profiles page now builds itself lazily like its four siblings; and the
repaint path that runs ten times a second in combat stopped allocating a throwaway function on every pass.
Alongside that, two README numbers that were quietly wrong were corrected **and given tests**, so they cannot
drift again, and a small pile of dead code and comments describing call paths that no longer exist was
removed. One defect found during the review lives in the shared `LibKa0s` library rather than here; it was
routed upstream and arrives back as a re-vendor.

## Counts

- **Critical fixed:** 0 (none found)
- **High fixed:** 2 — F-001, F-002
- **Medium fixed:** 8 — F-003, F-004, F-005, F-006, F-007, F-008, F-009, and F-010 *(upstream; lands here as
  a re-vendor)*
- **Low fixed:** 7 — F-011, F-012, F-013, F-014, F-015, F-016, F-017, F-018

**Deliberately deferred:**

- **F-019** *(all user-facing strings hardcoded English)* — not reopened by this cycle. It is a recorded
  decision with a rationale on file: `docs/pending/LEDGER.md`, row `PLAN-02`, *"Localization decision not made
  this run"*. It stays under Known Limitations rather than becoming an accepted deviation.

*(Reconcile both lists against the commits before publishing.)*

---

## Changes by theme

### T-1 — `/at profile` tells the truth about what it did

**What changed.** Every `/at profile` sub-verb that takes a name now checks whether that name exists before
acting. `copy` refuses a name that is missing or is the profile you are already on, instead of throwing a Lua
error at you. `new` refuses a name that already exists, instead of switching to it and wiping it while
reporting a creation. `delete` says the profile was not found, instead of reporting a successful delete of
nothing. `use` refuses an unknown name and points at `/at profile new`, instead of quietly creating an empty
profile you are now sitting on.

**Why it mattered.** Four different wrong outcomes from one class of typo, one of them irreversible data loss
with a success message. AceDB's four methods disagree about what a bad name means — one raises, one swallows,
one creates — and the handler forwarded raw input into all of them.

**Findings covered:** F-001, F-002, F-003, F-018. **Change implemented:** C-1.

**Files touched:**
- `settings/Slash.lua`
- `tests/test_slashcmds.lua`

### T-2 — Two correctness gaps that only bite non-default setups

**What changed.** Turning *Show only in combat* off now refreshes every bar's value, not just the player's —
previously a target- or focus-only setup got its bar back holding a stale number. And the class-colored bar
background is now derived from the same live Blizzard class color the bar fill uses, rather than from a
13-entry copy of the palette kept in the addon.

**Why it mattered.** Both were single-bar, single-class assumptions left behind by the 1.9.0 multi-unit work.
The first showed a wrong number for a beat; the second would have rendered a plain white background for any
class Blizzard adds, which reads as a rendering bug rather than a stale table.

**Findings covered:** F-004, F-005. **Changes implemented:** C-2, C-3.

**Files touched:**
- `settings/General.lua`
- `core/Data.lua`
- `tests/test_visibility.lua`
- `tests/test_data.lua`

### T-3 — Nothing allocated on the hot repaint path

**What changed.** The coalesced repaint pass and the three display bus handlers now use plain loops and
file-scope functions instead of building a fresh closure each time they run. An offline scenario asserts the
pass allocates nothing per invocation.

**Why it mattered.** That path runs up to ten times a second in sustained combat. The addon ships a
measurement harness specifically to answer *"what does this cost?"*, and its offline runner already asserts
allocations as a deterministic quantity — so this was measurable rather than theoretical, and it was the one
place where a convenience wrapper cost more than the loop it wrapped.

**Findings covered:** F-008. **Change implemented:** C-4.

**Files touched:**
- `modules/Timer.lua`
- `modules/Display.lua`
- `tests/perf.lua`

### T-4 — The Profiles page joins the lazy-body pattern

**What changed.** The Profiles page's container is now created the first time you open that page, not while
the addon is loading. The page still appears in the Blizzard settings tree immediately, as it must.

**Why it mattered.** Four of the five pages already did this. Widgets built during the load window keep
whatever look they had before other addons install their skinning hooks, which makes a control's appearance
depend on folder load order — the mechanism the house standard describes at length. The page was one widget
away from it.

**Findings covered:** F-009. **Change implemented:** C-5.

**Files touched:**
- `settings/Profiles.lua`
- `tests/test_optionssetup.lua`

### T-5 — Two README numbers that were wrong, now gated

**What changed.** The tests badge was corrected from 467 to the real count, and the 1.9.0 Version History row
was rewritten to carry the same highlights the *What's new* section does — including the breaking slash-path
change, which the table omitted entirely. Both facts, plus the version appearing identically in the TOC, the
code and the README, are now asserted by the test suite.

**Why it mattered.** Both are static text mirroring data that moves, and both were enforced by memory. The
badge is the first number a player or reviewer reads; the Version History row was the only place a player
would learn their `/at set barWidth 250` macro had stopped working, and it did not say so.

**Findings covered:** F-006, F-007, F-016. **Changes implemented:** C-6, C-7, C-8.

**Files touched:**
- `README.md`
- `docs/test-cases.md`
- `tests/test_docs.lua`

### T-6 — Dead code removed, lying comments corrected

**What changed.** Two exported helpers with no callers anywhere (`NS.Units.DeepCopy`, `NS.Units.Set`) were
deleted, two unreachable defensive branches in `/at debug` were removed, and four comments that described
files and call paths that no longer exist were corrected.

**Why it mattered.** The worst of them was `Units.Set`'s comment, which stated that the slash CLI reaches it —
the CLI has not for some time, and a future reader would have trusted it. A comment that documents a seam the
code does not have is more expensive than no comment.

**Findings covered:** F-011, F-012, F-013, F-014, F-015, F-017. **Change implemented:** C-9.

**Files touched:**
- `core/Units.lua`
- `modules/Bar.lua`
- `core/DebugLogSetup.lua`
- `modules/Timer.lua`
- `settings/Slash.lua`

### T-U — Upstream: LibKa0s US-English sweep (arrives as a re-vendor)

**What changed here.** `libs/LibKa0s/` was re-vendored whole from the new LibKa0s release, as its own commit
touching no addon source, and the README's LibKa0s version line moved with it.

**What changed there.** Twenty-three British spellings were corrected across six library files, three of them
in strings the user actually reads in a perf report (`CANCELLED` twice, `unlabelled` once). Each touched
file's LibStub minor was bumped individually, and the library gained a US-spelling case of its own so the
next one is caught by its gate rather than by a consumer's reviewer.

**Why it mattered.** US English is the collection's source dialect, and this addon's own spelling guard
correctly excludes `libs/` — so nothing on this side could ever have seen it. Patching the vendored copy here
would have been reverted, silently, by the next re-vendor.

**Findings covered:** F-010. **Change implemented:** U-1.

**Files touched (this repo only):**
- `libs/LibKa0s/` *(whole-folder copy — never hand-edited)*
- `README.md` *(Credits and libraries version line)*
- `docs/pending/LEDGER.md`

---

## API / behavior changes

| Change | Detail |
|---|---|
| `/at profile use name` | **Stricter.** Refuses a name that does not already exist rather than creating it. Use `/at profile new name` to create. |
| `/at profile new name` | **Stricter.** Refuses a name that already exists rather than switching to it and resetting it. |
| `/at profile copy name` | No longer raises a Lua error for an unknown name or for the current profile; prints a tagged refusal instead. |
| `/at profile delete name` | Reports *not found* for a name that does not exist, instead of a false success. |
| *Show only in combat* toggle | Now always publishes a repaint. No user-visible change on a default install; on a target/focus-only setup the bar comes back with a current value rather than a stale one. |
| Class-colored bar background | Now derived from `C_ClassColor.GetClassColor` × 0.2. Per-class values are unchanged; an unresolved class now renders dark gray rather than white. |
| Settings → Profiles page | Body built on first open. The tree entry is unchanged and still appears at load. |
| Slash verbs added/renamed | **None.** All 17 `NS.COMMANDS` entries are unchanged. |
| Locale keys | **None added or renamed.** |
| Deprecated calls replaced | **None** — the addon already routed its one deprecated call through `core/Compat.lua`. |

## Saved-variable / migration notes

**No schema change.** `schemaVersion` stays at **4** (`defaults/Profile.lua:78`); the per-profile v3 stamp
(`defaults/Profile.lua:56`) is untouched. No migration step was added, none is required, and existing
profiles need no `/at reset`.

The only saved-variable-adjacent behavior change is that `/at profile new` no longer overwrites an existing
profile — which is the removal of an unintended write, not a schema change.

## Deprecated-API migrations

**None.** The sweep found no deprecated call outside `core/Compat.lua:12-19`, which already prefers
`C_AddOns.GetAddOnMetadata` and falls back to the bare global only when `C_AddOns` is absent. Recorded here so
a future reviewer knows the sweep ran and came back empty:

| Old API | New API | Files |
|---|---|---|
| *(none found)* | — | — |

## Performance impact

*(Fill from `03_SMOKE_TESTS.md` §C-4 after the run.)*

| Measurement | Before | After |
|---|---|---|
| `tests/perf.lua` repaint-pass allocation scenario (bytes/pass) | _fill in_ | _fill in_ |
| In-client `collectgarbage("count")` delta over 60 s at a dummy, all three bars | _fill in_ | _fill in_ |

Wall-clock figures are deliberately not asserted anywhere — the offline runner forbids them, and the
in-client profiler misattributes shared-frame cost (see
`docs/investigations/2026-07-14-addon-profiler-attribution/analysis.md`).

## Known follow-ups

| Item | Why it was left |
|---|---|
| **F-019** — hardcoded English strings; `NS.L` declared but unused | A recorded, deferred decision (`docs/pending/LEDGER.md`, `PLAN-02`), not an oversight. Wrapping strings changes locale **keys**, which must move across every locale file and call site in one change — worth doing as its own pass, not folded into a bug-fix cycle. |
| **F-013 follow-on** — retire the `NS.bar` / `NS.statusBar` / `NS.valueText` / `NS.backdropInfo` player aliases | This cycle corrected the comment. Actually deleting them means touching ~10 test references for no behavior gain; the honest end state, but churn this review did not push for. |
| **Other LibKa0s consumers** | The U-1 re-vendor must reach every consumer, not just this addon. A partially re-vendored collection is the silent-drift anti-pattern in slow motion. Track it in the library repo. |
| **Open GitHub issues** | `#2, #3, #4, #5, #6, #8, #9, #10, #15` all remain deferred with rationales on record in `docs/pending/LEDGER.md`. This cycle touched none of them. |

## Verification evidence

- **Smoke tests:** `docs/reviews/2026-08-03/03_SMOKE_TESTS.md`, sign-off table filled in. *(Pending.)*
- **Headless gate:** `lua tests/run.lua` — green; `luacheck .` — 0 warnings / 0 errors. Baseline at review
  time was **469 passed / 0 failed** and a clean lint; the post-change count is whatever
  `docs/test-cases.md` reports, and the README badge is asserted equal to it.
- **Vendor gate:** `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and `diff -r ../LibKa0s/tests/_kit tests/_kit`
  both empty; `tests/test_vendor_sync.lua` green.
- **Commit range / PR:** _fill in_.

## Suggested commit message / PR description

```
fix: harden /at profile, close two multi-unit gaps, and gate the README numbers

Review bundle: docs/reviews/2026-08-03/ (19 findings, 0 critical, 2 high).

/at profile could throw a Lua error (copy onto self or onto a name that does not
exist), silently wipe an existing profile while reporting a creation (new over an
existing name), report a delete that never happened, and create a profile from a
typo. AceDB's four profile methods disagree about what a bad name means — one
raises, one swallows, one creates — and the handler forwarded raw input into all
of them. One membership check now sits ahead of each.        [F-001 F-002 F-003 F-018]

Two gaps that only appear once you leave the default single-bar setup: the
"Show only in combat" toggle asked whether the PLAYER bar should show before
repainting all of them, so a target-only setup got its bar back holding a stale
value; and the class-colored background read a hand-copied palette while the fill
read the live API, so a class Blizzard adds would render white.   [F-004 F-005]

The coalesced repaint pass and the three display bus handlers no longer allocate a
closure per invocation — ten times a second in combat, in an addon that ships a
harness to measure exactly this.                                       [F-008]

The Profiles page now builds its body on first show, like the other four pages;
the category registration stays eager.                                 [F-009]

The README tests badge was 467 against a real 469, and the 1.9.0 Version History
row omitted the multi-unit bars and the breaking slash-path change its own
"What's new" section describes. Both corrected, and both now asserted by
tests/test_docs.lua so they cannot drift again.                  [F-006 F-007 F-016]

Plus a dead-code sweep: two exported helpers with no callers, two unreachable
branches, and four comments naming files and call paths that no longer exist.
                                              [F-011 F-012 F-013 F-014 F-015 F-017]

Routed upstream, NOT patched here: 23 British spellings in libs/LibKa0s,
including three strings a user reads in a perf report. Fixed in the LibKa0s repo
with per-file minor bumps and re-vendored whole-folder as its own commit.  [F-010]

Deferred: F-019 (hardcoded English strings) — LEDGER row PLAN-02.

Tests: <X> passed, 0 failed. luacheck: 0 warnings / 0 errors.
Smoke: docs/reviews/2026-08-03/03_SMOKE_TESTS.md signed off.
```
