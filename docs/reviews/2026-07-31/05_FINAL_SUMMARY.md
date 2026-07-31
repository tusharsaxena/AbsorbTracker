# Final summary — 2026-07-31 review cycle

> **Status: written ahead of implementation.** This document is the "what shipped" record for the
> remediation described in `02_PROPOSED_CHANGES.md` and sequenced in `04_EXECUTION_PLAN.md`, written
> on the assumption that every case in `03_SMOKE_TESTS.md` passes. Fill in the perf numbers, the
> commit range and the sign-off pointer as the work lands; correct anything that changed in
> implementation.

---

## Headline

This cycle hardened the seam the LibKa0s extraction created. The extraction itself was sound — the
vendored copies match upstream byte for byte, the combat gate moved into the library where every
caller is covered by it, and the library-absent path is proven by loading the addon without the
library rather than by hand-stubbing it. What needed fixing was the thin layer the addon kept: a
`/at resetall` that could report success without resetting anything, a README row describing this
branch's own breaking change that CurseForge silently truncates, one data-protecting rule written
twice in opposite polarity, a settings page that could latch itself unrenderable for the rest of a
session, and three design comments — in files whose entire content is design rationale — that named
the wrong code. Two defects belong to the shared library and were fixed upstream and re-vendored,
never patched in place.

---

## Counts

| Severity | Found | Addressed | Deferred |
|---|---|---|---|
| Critical | 0 | 0 | — |
| High | 3 | 3 | — |
| Medium | 6 | 6 | — |
| Low | 9 | 9 | — |

Nothing deferred. Two Low findings (F-016, F-017) were resolved **upstream in the LibKa0s repo** and
reached this addon as a re-vendor commit; they are not local edits.

---

## Changes by theme

### T1 — Stop the seams from telling the user something untrue

**What changed.** `/at resetall` now prints its acknowledgement inside the same guard that does the
work, and names the failure when the settings helpers did not load — matching `/at resetposition`,
which had already been restructured that way and explains why in its own comment. The README's
`/at reset` row writes its argument bare instead of in angle brackets. A build with LibKa0s missing
now says the same sentence about the cause from all four seams, adding only a per-seam clause for
what is unavailable.

**Why it mattered.** A confident wrong answer costs more than an error: a user who runs `resetall`,
reads "All settings reset to defaults", and finds nothing changed has no way to tell whether the
addon or their memory is at fault. And the README row was worse than wrong — it renders perfectly on
GitHub, where it is reviewed, and reaches CurseForge as `/at reset` with the argument silently
deleted, on the one row documenting a behavior change this branch shipped.

**Findings covered:** F-001, F-003, F-013. **Changes implemented:** C-1, C-2, C-13.

**Files touched**
- `settings/Slash.lua`
- `README.md`
- `core/CoreSetup.lua`
- `core/DebugLogSetup.lua`
- `settings/OptionsSetup.lua`
- `tests/test_slashcmds.lua`

### T2 — One rule, one place

**What changed.** The "a global reset must never touch Profiles rows" rule is now a single named
predicate used by both the library descriptor and the degraded stub's own reset loop.
`FormatSchemaValue` resolves its library once at file load instead of on every call, and its
library-absent arm renders colors, formatted numbers and empty strings again instead of falling
through to `tostring`. New parity cases drive the same five inputs through both the live and the
degraded slash dispatchers and compare the outcome.

**Why it mattered.** The extraction exists to end drift between copies of shared code. Three
duplicates survived inside the addon's own half of the seam, and the worst of them guarded user
data: a future page added to the veto in one place and not the other would have made `/at resetall`
delete profiles in a library-absent build, with both test suites green.

**Findings covered:** F-004, F-006, F-007, F-015. **Changes implemented:** C-3, C-4, C-5, C-6.

**Files touched**
- `settings/OptionsSetup.lua`
- `settings/Schema.lua`
- `settings/Slash.lua` (comment)
- `tests/test_helpers.lua`
- `tests/test_schema.lua`
- `tests/test_slashcmds.lua`

### T3 — Make the comments load-bearing again

**What changed.** The `settings/OptionsSetup.lua` stub's rationale now correctly names `LSMValues`
as the sole member reached at **file load** — the one whose absence would half-load the schema — and
explains the other two as call-time-but-still-required. The three layout constants the stub copied
from the library are gone, since nothing reads them in a degraded build. `core/CoreSetup.lua`'s
capture count is correct, and the `NS.SlashCommands` alias no longer claims a reader it lost.

**Why it mattered.** These files hold wiring and rationale and nothing else — the implementations
went upstream. A rationale that names the wrong members is a defect in the file's one job, and the
member it would have led a maintainer to remove is the one that keeps a third of the schema from
vanishing silently.

**Findings covered:** F-005, F-011, F-014. **Changes implemented:** C-12.

**Files touched**
- `settings/OptionsSetup.lua`
- `core/CoreSetup.lua`
- `settings/Slash.lua`

### T4 — Bring the addon's refresh contract in line with the library's

**What changed.** The unit panel's mirror refresher still re-syncs its checkbox in place on every
write, but a structural rebuild now happens only on the page that is actually on screen; the other
rendered pages are flagged dirty and rebuild once on their next open. The render's re-entrancy flag
now clears on the failure path too, and a failed render reports through the addon's tagged printer
instead of leaving the page frozen.

**Why it mattered.** After the extraction, every other refresh in the addon happens in place inside
the library — this was the last structural rebuild, and it rebuilt panels the user could not see.
The latched guard was the sharper problem: any raise inside a render made every subsequent render on
that page a silent no-op until `/reload`, with only the first error visible.

**Findings covered:** F-008, F-009. **Changes implemented:** C-7, C-8.

**Files touched**
- `settings/UnitPanel.lua`
- `settings/Bar.lua`
- `settings/Border.lua`
- `settings/Font.lua`
- `tests/test_helpers.lua`

### T5 — US English across authored text

**What changed.** Every `colour`/`Colours`/`colouring`/`coloured`/`honoured`/`generalise`/`grey`
introduced by this branch is now US-spelled, in the addon and — through an upstream commit and a
re-vendor — in the library.

**Why it mattered.** WoW's own API is US-spelled, so a British-spelled identifier or comment sits one
letter from the Blizzard symbol next to it, and a collection-wide `grep -r color` misses half its
call sites. No locale key moved: the addon ships English-only by design and wraps nothing in `NS.L`
yet, so this was a comment-and-prose edit with no migration.

**Findings covered:** F-002, F-017. **Changes implemented:** C-10, C-11.

**Files touched**
- `settings/OptionsSetup.lua`, `settings/Slash.lua`, `settings/UnitPanel.lua`, `settings/Schema.lua`
- `README.md`, `CLAUDE.md`
- `tests/*.lua`
- `libs/LibKa0s/Core.lua`, `libs/LibKa0s/OptionsWidgets.lua`, `libs/LibKa0s/Slash.lua` *(re-vendored
  from upstream — not edited locally)*

### T6 — Shared-library fixes, upstream

**What changed.** `RenderRows` no longer implements its "one-shot" hooks by deleting entries from the
`afterGroup` / `pairWith` tables the **host** owns and passed in; it tracks fired hooks in a local
set instead. Fixed in the LibKa0s repo, file minor bumped, changelog updated, then re-vendored here
in its own commit.

**Why it mattered.** Any host that stored its hook map at file scope, or reused one across renders,
would silently lose its inline buttons and paired widgets on the second render. AbsorbTracker was
safe only incidentally — its maps are literals inside a once-guarded `OnShow` — which is the kind of
safety that evaporates the first time someone hoists a table.

**Findings covered:** F-016. **Changes implemented:** C-9.

**Files touched**
- *(upstream)* `LibKa0s/LibKa0s/OptionsWidgets.lua`, its suite, `CHANGELOG.md`
- `libs/LibKa0s/` *(re-vendor copy only)*

### T7 — Cleanup

**What changed.** `NS.PARENT_TITLE` demoted to a file-scope local (its two cross-file readers went
into the library), the dead `CliVersion` member dropped from the degraded slash stub, and the
production-code test seam `Helpers.__lastUnitCtx` replaced by the library's own `__panelFor(pageKey)`
at all 15 call sites.

**Why it mattered.** A namespace export is a published surface; three of them had no reader left
after the extraction, and one of them existed purely for tests while the library already supplied
the equivalent seam.

**Findings covered:** F-010, F-012, F-018. **Changes implemented:** C-14.

**Files touched**
- `settings/OptionsSetup.lua`, `settings/Slash.lua`, `settings/UnitPanel.lua`
- `tests/test_helpers.lua`, `tests/test_widgets.lua`

---

## API / behavior changes

- **Slash surface:** no verb added, removed or renamed. `/at resetall`'s **failure** path now prints
  `Cannot reset settings — the settings helpers failed to load` instead of a false success line.
- **Namespace surface:** `NS.PARENT_TITLE` removed (was read only by files now inside the library).
  `NS.SlashCommands` retained as a compatibility alias with its comment corrected.
- **Degraded-build messages:** all "LibKa0s missing" lines now share one cause clause; the per-seam
  clauses are new text. `NS.LIBKA0S_MISSING` added as the shared constant on `core/CoreSetup.lua`.
- **Deprecated calls:** none. This cycle replaced no deprecated API — see the table below.
- **Locale keys:** none added, renamed or removed. The addon still ships English-only with the
  `NS.L` metatable seam unused, exactly as `locales/enUS.lua` documents.
- **Defaults:** unchanged.

## Saved-variable / migration notes

**No schema bump.** `AbsorbTrackerDB`'s account-wide `global.schemaVersion` and the per-profile v3
stamp are untouched, no key was added, moved or removed, and `NS:RunMigrations` is unchanged.
Existing profiles carry forward with no user action; **no `/at reset` is required**.
`AbsorbTrackerPerfDB` is likewise untouched.

## Deprecated-API migrations

| Old API | New API | Files |
|---|---|---|
| *(none)* | — | — |

No deprecated or removed API was found in the diff. `GetAddOnMetadata` continues to route through
the single `core/Compat.lua` shim, which prefers `C_AddOns.GetAddOnMetadata`.

## Performance impact

Fill in from `03_SMOKE_TESTS.md`'s spot-checks.

| Measurement | Before | After | Notes |
|---|---|---|---|
| GC bytes over a 10 s color drag, `/at debug on` | | | C-5 — `LibStub` no longer resolved per `FormatSchemaValue` call |
| GC bytes over the same drag, `/at debug off` | | | Control arm; expected unchanged |
| `GetAddOnCPUUsage` over 10 alternating mirror writes with 3 unit pages rendered | | | C-7 — three page rebuilds per write become one |
| `lua tests/perf.lua` probe overhead | | | Sanity only; outside the green gate (testing-§7) |

## Known follow-ups

- **`NS.SlashCommands` alias.** Kept rather than deleted, because nothing outside the test suite
  proves no external consumer reads it. Revisit at the next major bump, where removing a namespace
  export is cheap.
- **The degraded slash dispatcher.** Still a second implementation of the library's dispatch, now
  held honest by parity cases rather than by construction. Collapsing it further would mean the
  library shipping a dependency-free micro-dispatcher a host could carry without LibStub — a design
  question for the LibKa0s repo, not a defect here.
- **`locales/enUS.lua` is still an empty seam.** Every user-facing string in the addon (including
  the new per-unit page labels moved into `settings/UnitPanel.lua`) is a hardcoded English literal.
  Deliberate and documented in that file; unchanged by this cycle and out of scope for it — the
  localization pass is its own piece of work.
- **`Helpers.RenderUnitPanel`'s full-rebuild-per-dropdown-change.** Now correctly scoped to the
  on-screen page, but still a teardown rather than a re-value. The file explains why (the library's
  ScrollFrame anchors flush to `ctx.body`, leaving no room for a persistent header). Revisit only if
  a fourth tracked unit makes the rebuild visible.

## Verification evidence

- **Smoke tests:** `docs/reviews/2026-07-31/03_SMOKE_TESTS.md`, sign-off table completed.
- **Green gate:** `lua tests/run.lua` — _fill in_ passed / 0 failed; `luacheck .` — 0 warnings /
  0 errors. `docs/test-cases.md` regenerated and the README `[tests]` badge updated in the same
  commit.
- **Vendor sync:** `diff -r ../LibKa0s/LibKa0s libs/LibKa0s` and
  `diff -r ../LibKa0s/testkit tests/_kit` both empty.
- **Commit range:** _fill in_ (`git log --grep=F-0` reconstructs the review trail).
- **Upstream commits:** _fill in_ (LibKa0s repo — `OptionsWidgets` and `Core`/`Slash` minor bumps).

---

## Suggested commit message / PR description

```
fix(seams): harden the LibKa0s extraction seam (2026-07-31 review)

Remediates docs/reviews/2026-07-31 — 3 High, 6 Medium, 9 Low, 0 Critical.
The extraction itself held up: vendored copies byte-identical to upstream,
the combat refusal correctly inside the library's OpenOptionsPanel, and the
library-absent path proven by loading the whole TOC without LibKa0s. What
needed fixing was the addon's own thin wiring layer.

User-facing
- /at resetall no longer reports success outside its guard (F-001)
- README's /at reset row drops the angle-bracket placeholder CurseForge
  silently strips (F-003)
- one cause clause across all four missing-library seams (F-013)

Duplicates collapsed
- one predicate for the profiles reset veto, used by both the descriptor
  and the degraded stub (F-004)
- LibKa0s-Slash resolved once at load; the degraded value formatter's
  color / fmt / (none) branches restored (F-007, F-015)
- degraded-vs-live dispatcher parity cases (F-006)

Refresh + render
- unit-panel structural rebuild scoped to the on-screen page; the rest go
  dirty and rebuild on next OnShow (F-008, options-ui-§11)
- the render re-entrancy guard clears on the failure path (F-009)

Text, comments, cleanup
- US English across every line this branch added (F-002, anti-patterns #46)
- the degradation rationales now name the code they are about (F-005,
  F-011, F-014)
- PARENT_TITLE, CliVersion and __lastUnitCtx removed (F-010, F-012, F-018)

Upstream (LibKa0s, re-vendored here in its own commit)
- RenderRows no longer mutates the host's afterGroup/pairWith tables (F-016)
- US English in the library's comments (F-017)

No schema bump, no locale keys moved, no deprecated API replaced. Existing
profiles carry forward untouched.
```
