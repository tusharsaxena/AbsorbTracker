# Code review — `feature/libka0s-five-module-extraction` vs `master`

**Date:** 2026-07-31
**Scope:** `git diff master...HEAD` — the extraction of five LibKa0s majors (Core, DebugLog, Slash,
Options, Perf) out of AbsorbTracker and the addon's re-adoption of them as a consumer. Deleted:
`core/Util.lua`, `core/DebugLog.lua`, `settings/Panel.lua`, `settings/Helpers.lua`,
`settings/ScrollPatch.lua`, `settings/Widgets.lua`. Added: `core/CoreSetup.lua`,
`core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`, `settings/UnitPanel.lua`.
**Baseline state:** 434 passed / 0 failed, `luacheck .` 0 warnings / 0 errors in 28 files.

> **Standards cross-check performed.** The Ka0s WoW Addon Standard was fetched successfully
> (`STANDARDS.md` v2.14.0, 2026-07-30, plus all 23 linked section files). Every fix direction below
> was checked against it; where a rule shaped or vetoed a direction it is cited as `filename-§N`.

> **`libs/` is vendored and read-only.** Two findings (F-016, F-017) are library defects. They are
> reported as **upstream** work in the LibKa0s repo and **must not** be patched in
> `AbsorbTracker/libs/` — a hand-patched vendored copy is a fork nobody knows about
> (library-stack-§5, anti-patterns #45).

---

## Verdict

**Minor issues.** The extraction is structurally sound and the hard parts are right: the vendored
copies are byte-identical to their upstream (`diff -r` empty for both `libs/LibKa0s` and
`tests/_kit`), the combat refusal sits inside the library's `OpenOptionsPanel` so every caller is
gated, the `NS.Print` / `NS.Util.print` identity invariant survives the AceConsole embed and is
asserted, and the library-absent path is proven by **actually loading the whole TOC without the
library** rather than by hand-stubbing (testing-§8). No taint leak, no secret-value leak, no data
loss, no deprecated API. What remains is one silent-lie chat path, one newly introduced
standards deviation in authored text, one README placeholder regression, and a cluster of
consistency/comment-accuracy problems concentrated in the degradation stubs.

**Counts:** Critical 0 · High 3 · Medium 6 · Low 9

---

## High

### F-001 — `/at resetall` acknowledges success outside its own guard `[logic][ux]`
**Where:** `settings/Slash.lua:165-173`.
**Problem:** `runResetAll` prints `"All settings reset to defaults"` unconditionally, outside the
`if NS.Helpers and NS.Helpers.RestoreAllDefaults` guard that wraps the actual work.
**Impact:** If `settings/OptionsSetup.lua` failed to load, the verb does nothing and reports
success — the exact "silent lie" shape that `runResetPosition`, eight lines below, was deliberately
restructured to avoid and documents at length in its own comment. The two neighbouring verbs now
disagree about the same rule.
**Direction:** Move the ack inside the guard and add an else-branch naming the failure, mirroring
`runResetPosition` verbatim. Route it through the captured `NS.Print` — never a raw `print(...)`
(events-frames-taint-§8).

### F-002 — British spellings introduced in newly authored text `[locale]`
**Where:** `settings/OptionsSetup.lua:14,102,109` (`colour`, `colour`, `Colours`);
`settings/Slash.lua:31,47,456,460` (`colouring`, `honoured`, `coloured`, `colouring`);
`settings/UnitPanel.lua:12` (`generalises`); `settings/Schema.lua:174,252` (`colour`);
`README.md:122` (`grey`); `CLAUDE.md:46` (`generalise`); plus several new `tests/` comments.
**Problem:** US English is the collection's source dialect for every authored string, comment and
identifier (localization-§5, anti-patterns #46). These are all lines **added by this branch**, so
this is a new deviation, not pre-existing drift.
**Impact:** A `grep -r color` across the collection now misses half its call sites in this addon's
newest files, and the collection is no longer sweepable with one pattern. None of these are locale
**keys**, so the fix is a comment/prose edit only — no key migration.
**Direction:** Mechanical substitution to `color`/`colors`/`coloring`/`colored`/`honored`/
`generalize`/`gray` across the added lines only. Do **not** touch `libs/` (F-017) and do not
"correct" Blizzard symbols such as `SetTextColor` (localization-§5 exceptions).

### F-003 — README reintroduces an angle-bracket placeholder in the same change that swept them out `[docs][ux]`
**Where:** `README.md:58` — `` `/at reset <path>` ``.
**Problem:** The branch correctly removed `<setting>`/`<value>`/`<name>` placeholders from six other
README rows, then added a new one describing this branch's own `/at reset` semantics change.
Angle-bracket placeholders are forbidden in shipped README content (documentation-§1, standard
v2.14.0; anti-patterns #28).
**Impact:** CurseForge strips `<path>` as an unknown HTML tag **even inside backticks**, so the row
players actually read on the distribution page says `` `/at reset ` `` — and it is the one row
documenting a user-visible breaking change shipped by this very branch. It renders perfectly on
GitHub, so the review loop never sees it.
**Direction:** Write the argument bare (`/at reset path`), matching the neighbouring `/at get name`
and `/at set name value` rows the same diff already fixed. `[…]` stays legal for genuinely optional
arguments; deliberate HTML such as `<br>` in the Version History cells must not be swept.

---

## Medium

### F-004 — the Profiles reset veto is encoded twice `[design]`
**Where:** `settings/OptionsSetup.lua:60` (`skipRestoreAll = function(row) return row.page ==
"profiles" end`) and `settings/OptionsSetup.lua:134` (the degraded stub's `if row.page ~=
"profiles" then NS.ApplyDefault(row) end`).
**Problem:** One rule — "a global reset must not touch AceDBOptions-supplied rows, because that
deletes user data" — expressed as two independent predicates in one file, in opposite polarity.
**Impact:** A future page whose rows must also be vetoed gets added to one and not the other, and
the degraded build then destroys profile data on `/at resetall`. This is precisely the divergence
class the extraction exists to end.
**Direction:** Hoist one named local predicate at the top of the file and have both the descriptor
field and the stub call it. Keep the stub's reset — losing the panel is survivable, losing the reset
is not — but stop it re-deriving the rule.

### F-005 — the degradation stub's load-time analysis is wrong in both directions `[design][comment]`
**Where:** `settings/OptionsSetup.lua:104-112` (the comment) and `:126-131` (the members).
**Problem:** The comment asserts the load-time member set is "verified to be exactly three:
`LSMValues`, `SECTION_HEADING_H` (`settings/About.lua`) and `RestoreAllDefaults` (the StaticPopup
body in `settings/General.lua`)". Only `LSMValues` is actually reached at file load.
`Helpers.SECTION_HEADING_H` is read inside `Helpers.BuildMainContent` (`settings/About.lua:82`), a
call-time body; `RestoreAllDefaults` is read inside the popup's `OnAccept` **closure**
(`settings/General.lua:134`), not while the table literal is evaluated. Conversely the stub
hardcodes three layout constants (`26`, `8`, `0.492`) that duplicate `lib.LAYOUT`'s values and that
nothing reads in a degraded build at all.
**Impact:** The comment is the sole design rationale for this stub being shaped differently from the
addon's four other stubs. A maintainer trimming it against that list removes the wrong members —
and the one that matters (`LSMValues`) is the one whose absence half-loads the schema silently. The
duplicated constants are also a small copy of library values that can drift, in a file whose own
comment forbids exactly that.
**Direction:** Correct the comment to name `LSMValues` as the sole load-time member and explain the
others as call-time-but-still-needed; drop the three constants, or state why a degraded build keeps
them. Do **not** delete the stub's `RestoreAllDefaults` (see F-004).

### F-006 — the degraded slash stub re-implements the library's dispatcher, untested for parity `[design]`
**Where:** `settings/Slash.lua:380-419`.
**Problem:** The block's own comment says "note what is NOT here: no copy of the row formatter, no
copy of the parser, no copy of the key/value shape" — but it does carry a second copy of the
**dispatcher**: verb lookup, alias mapping, trimmed-message parsing, verb lowercasing with
case-preserved `rest`, the unknown-verb message, and the help header shape. Roughly 35 lines that
mirror `libs/LibKa0s/Slash.lua:366-383` and `:233-259`.
**Impact:** The two dispatchers can diverge with nothing to notice: the library's suite covers the
library, the addon's covers the live path, and the degraded suite only asserts "does not raise" and
"mentions LibKa0s". A new alias or a changed unknown-verb string lands in one and not the other.
**Direction:** Keep the stub (the verbs must answer), but add degraded/live **parity** cases driving
the same inputs through both and comparing the dispatch outcome — not the formatted strings, which
are legitimately different. Do not solve this by having the stub call into the library
(there is none) or by hand-copying more of it (testing-§8).

### F-007 — `LibStub` resolved per call in `FormatSchemaValue` `[perf][convention]`
**Where:** `settings/Schema.lua:178`.
**Problem:** `local lib = LibStub and LibStub("LibKa0s-Slash-1.0", true)` runs on every invocation.
library-stack-§4: resolve `LibStub("X")` **once at addon load** and stash it on the namespace.
**Impact:** Small today — the only caller is the `[Set]` debug line at `settings/Schema.lua:149`,
which is correctly gated behind `NS.State.debug`, so a color-picker drag pays nothing with debug
off. But it is the addon's only per-call `LibStub`, and it sits on the write seam every panel widget
and every `/at set` goes through, so the ceiling is a sustained drag with the console open.
**Direction:** Resolve once at file load into a file-scope local and branch on that. Keep the
library-absent fallback branch.

### F-008 — the mirror refresher rebuilds off-screen panels `[perf][ux]`
**Where:** `settings/UnitPanel.lua:463-471`.
**Problem:** The registered refresher calls `Helpers.RenderUnitPanel(ctx, pageKey)` — a full
`ClearScroll` + rebuild — whenever the unit's mirror state changed since the last render, with no
`ctx.panel:IsShown()` check. options-ui-§11 requires structural rebuilds to be scoped to the
on-screen subcategory, with off-screen panels flagged dirty for a lazy rebuild on next `OnShow`
(anti-patterns #39).
**Impact:** One `/at set units.focus.mirror true`, one Defaults click, or one profile switch tears
down and rebuilds every rendered Bar/Border/Font panel, including the two the user cannot see. Three
pages is not the ~15 that produced the half-second stall the rule was written from, so this is a
latency and widget-churn concern rather than a visible freeze.
**Note:** This code is carried over **verbatim** from the deleted `settings/Helpers.lua`; the branch
did not introduce it. It is raised because the branch made it the addon's *only* remaining
structural rebuild — everything else now refreshes in place inside the library — so it now sits
alone on the seam under review.
**Direction:** Gate the re-render on `ctx.panel and ctx.panel:IsShown()`; otherwise set
`ctx.__dirty = true` and extend each page's first-show guard to re-render when dirty. The in-place
checkbox re-sync above it stays unconditional — that half is already compliant.

### F-009 — the re-entrancy flag is not exception-safe `[logic]`
**Where:** `settings/UnitPanel.lua:71-72` and `:472`.
**Problem:** `ctx.__rendering` is set `true` at the top and cleared only on the normal exit path.
Any raise between the two — an AceGUI widget error, a malformed schema row, a nil `NS.Units.LABEL`
entry — leaves it latched.
**Impact:** The page becomes permanently unrenderable for the session: every subsequent
`RenderUnitPanel` (dropdown change, mirror toggle, refresher, re-`OnShow`) returns silently at the
guard, so the panel looks frozen with no error after the first one. Recovery needs `/reload`.
**Direction:** Clear the flag on both paths. The compliant shape is a `pcall`ed inner render (the
library already pcalls each refresher for the same reason, `Options.lua:305,330`), with the failure
reported through the addon's shared printer rather than swallowed.

---

## Low

### F-010 — `NS.PARENT_TITLE` is an export with no external reader `[naming][dead-code]`
**Where:** `settings/OptionsSetup.lua:23`. On `master` it was read by `settings/Panel.lua` and
`settings/Helpers.lua`; both readers are now inside the library, which receives the value through
`descriptor.parentTitle` three lines below. Publishing it on `NS` now advertises a seam nothing
uses.

### F-011 — `NS.SlashCommands`'s stated reason for existing is stale `[dead-code][comment]`
**Where:** `settings/Slash.lua:104-105` — "Alias kept for the About page, which renders the same
list". `settings/About.lua:93` now renders `NS.Slash:LandingRows()`. The only remaining readers are
`tests/test_slashcmds.lua:74` and the docs. Either drop the alias and its test, or correct the
comment to say it is a compatibility alias with no in-addon reader.

### F-012 — dead member on the degraded slash stub `[dead-code]`
**Where:** `settings/Slash.lua:393` — `stub.CliVersion`. The `version` verb formats its line inline
(`settings/Slash.lua:96-97`) and never reaches `cli:CliVersion()`, on either path.

### F-013 — a degraded install emits three differently worded "library missing" lines `[ux]`
**Where:** `core/CoreSetup.lua:30-33`, `settings/OptionsSetup.lua:114-115`,
`core/DebugLogSetup.lua:20-21`. All three are individually honest and correctly one-shot, but they
share no wording and no constant, and two of them fire at login (`CoreSetup`'s preamble rides the
first printed line; `OnEnable` calls `NS.CreateOptionsPanel`, which prints the settings line). A
user reading chat sees one cause described three ways.
**Direction:** One shared sentence for the cause plus a per-seam clause for what is lost.

### F-014 — miscount in `core/CoreSetup.lua`'s degradation rationale `[comment]`
**Where:** `core/CoreSetup.lua:20` — "four settings files do `local print = NS.Print` at load".
Three do (`settings/Slash.lua:21`, `settings/General.lua:12`, `settings/OptionsSetup.lua:20`);
`settings/Schema.lua:201` is function-scoped and therefore not part of the load-order argument the
sentence is making.

### F-015 — the library-absent `FormatSchemaValue` fallback silently lost three branches `[degraded-behavior]`
**Where:** `settings/Schema.lua:177-184`. `master`'s implementation handled `color` (a `{r,g,b,a}`
render), `number` with `row.fmt`, and the empty-string `"(none)"` case. The fallback kept only
`nil` and `tostring(v)`, so a degraded build renders a color as `table: 0x…`.
**Impact:** Currently unobservable — the only caller is the gated `[Set]` line, which the degraded
`NS.DebugLog` stub swallows — which is exactly why it will rot unnoticed. Either restore the three
branches or state in the comment that the fallback is deliberately minimal because its sole caller
is inert in that build.

### F-016 — **upstream** — `RenderRows` mutates the caller's hook tables `[design][upstream]`
**Where:** `libs/LibKa0s/OptionsWidgets.lua:463` and `:475` — `pairWith[row.path] = nil` and
`afterGroup[row.group] = nil` implement "one-shot" by destroying entries in the table the **host**
owns and passed in.
**Impact:** A host that stores its `afterGroup`/`pairWith` map at file scope, or reuses one across
renders, silently loses its inline buttons and paired widgets on the second render. AbsorbTracker is
safe today only incidentally: `settings/General.lua:166-192` builds fresh literals inside a
once-guarded `OnShow`.
**Direction:** **Fix upstream in the LibKa0s repo** (a local `fired` set inside `RenderRows` rather
than mutating the argument), bump `OptionsWidgets`'s file minor, then re-vendor here in its own
commit (library-stack-§7). Do **not** patch `libs/` locally (anti-patterns #45).

### F-017 — **upstream** — British spellings in the vendored library's comments `[locale][upstream]`
**Where:** `libs/LibKa0s/Core.lua:78,160`; `libs/LibKa0s/OptionsWidgets.lua:28,66,332`;
`libs/LibKa0s/Slash.lua:371`. `colour`/`colours` in authored comments (localization-§5,
anti-patterns #46).
**Direction:** **Fix upstream**, bump the affected file minors, re-vendor. Flagged here only so the
sweep for F-002 does not stop at the addon boundary and think it is done — and so nobody "fixes" it
in `libs/`, which would break `diff -r` and make this addon a silent fork.

### F-018 — production test seam duplicating an existing library seam `[naming]`
**Where:** `settings/UnitPanel.lua:64` — `Helpers.__lastUnitCtx = ctx`. The library already exposes
`O.__panelFor(pageKey)` (`libs/LibKa0s/Options.lua:456`) for exactly this purpose, and every unit
page has a stable `pageKey`. The extra field also pins one `ctx` alive for the session. Fifteen test
call sites depend on it, so this is a cleanup, not a bug.

---

## Verified good (recorded so a later reviewer does not re-litigate)

- **Vendor sync (library-stack-§7, anti-patterns #45).** `diff -r LibKa0s/LibKa0s
  AbsorbTracker/libs/LibKa0s` and `diff -r LibKa0s/testkit AbsorbTracker/tests/_kit` are both empty.
- **Taint / combat.** The combat refusal lives inside `O.OpenOptionsPanel`
  (`libs/LibKa0s/Options.lua:434-445`), so `/at config`, a `/run` script and any future internal
  caller are all gated; it refuses with the canonical gray notice and does **not** defer-and-replay
  (options-ui-§2). Category registration stays eager and taint-free (options-ui-§1/§9). No protected
  API is called from a tainted path anywhere in the diff.
- **Secret values.** Both the live printer and `core/CoreSetup.lua`'s fallback probe `table.concat`,
  never `..` (events-frames-taint-§8, anti-patterns #35). `NS.Debug`'s formatting stays behind the
  enable gate; `settings/Schema.lua:148` gates the `[Set]` line including its value formatting.
- **AceConsole embed.** `NS.Print` and `NS.Util.print` are the same function object and
  `core/AbsorbTracker.lua:25` reclaims it after `NewAddon`; `tests/test_slash.lua` asserts the
  identity (architecture-§2, anti-patterns #36).
- **Degraded-path testing.** `tests/test_perf.lua:288` loads the **whole TOC** with no LibKa0s files
  and asserts `#NS.Schema` against the fully-loaded environment — the load-completing stub's real
  guard, and the form testing-§8 requires (a load, not a hand-stub).
- **`core/PerfSetup.lua`** correctly gained a nil-guard on `MakeCloseButton` and keeps its
  `NS.DebugLog` lookups lazy, which is what lets it sit ahead of `core/DebugLogSetup.lua` in the TOC.
- **TOC / load order.** `libs\LibKa0s\LibKa0s.xml` sits after Ace3, `core\PerfSetup.lua` ahead of
  its upvalue consumers, `settings\OptionsSetup.lua` ahead of every page file
  (toc-file-§5, performance-§1). `tests/test_loadorder.lua` derives the list from the TOC and pins
  the XML's order in both runners.
- **`.luacheckrc`.** The five pruned `read_globals` (`date`, `SettingsPanel`, `UISpecialFrames`,
  `GameTooltip`, `wipe`) have no remaining call site outside `libs/`, verified by grep.
