# Proposed changes — HLD + LLD

**Review:** `docs/reviews/2026-07-31/01_FINDINGS.md`
**Branch under review:** `feature/libka0s-five-module-extraction` vs `master`
**Standard resolved:** Ka0s WoW Addon Standard **v2.14.0 (2026-07-30)** —
<https://github.com/tusharsaxena/WowAddonStandards>, `standards/STANDARDS.md` plus all 23 section
files linked from its Sections list. Every change below was checked against it; citations use the
`filename-§N` form.

> **Standards cross-check was performed.** No proposed change introduces a new deviation. Where a
> more obvious fix was rejected because the standard forbids it, the rejection and the rule are
> recorded on the change.

> **`libs/` is read-only here.** C-9 and C-10 are **upstream** changes in the LibKa0s repo followed
> by a re-vendor commit in this addon. They must not be applied as local edits to
> `AbsorbTracker/libs/` (library-stack-§5/§7, anti-patterns #45).

---

## HLD — themes

### T1. Stop the seams from telling the user something untrue

Two paths in the diff report an outcome they may not have produced, and one documentation row
reaches players stripped of half its content. These are the only findings with direct user impact,
they are independent of each other, and each is a few lines.

- `/at resetall` acknowledges success outside its guard (F-001) while the verb immediately below it
  was deliberately rewritten to do the opposite and explains why in its own comment.
- The README's `/at reset <path>` row is silently truncated to `/at reset` on CurseForge (F-003) —
  and it is the row describing this branch's own breaking change.
- A library-absent install hears one cause described in three different sentences (F-013).

**Rationale:** slash-commands-§4/§5 and documentation-§1 both exist because the chat line and the
README row are the addon's only contact with a user who cannot read the source. A confident wrong
answer is worse than an error.

**Alternatives considered.** *Make `runResetAll` unconditional by asserting `NS.Helpers` exists at
load* — rejected: the whole point of the setup-file pattern is that a missing library degrades
rather than raising at load (`architecture`, and the addon's own five stubs). *Leave the README row
and rely on the GitHub rendering* — rejected: documentation-§1 (v2.14.0) makes this a MUST precisely
because the surface that breaks is the one maintainers never check.

### T2. One rule, one place — collapse the duplicates the extraction left behind

The extraction's stated purpose is to end seven-way drift of shared code. Three duplicates survived
inside the addon's own half of the seam, and one of them guards user data.

- The Profiles reset veto is written twice, in opposite polarity, in one file (F-004).
- The degraded slash stub carries a second dispatcher with no parity coverage (F-006).
- `FormatSchemaValue`'s library-absent fallback lost three of its five branches (F-015).

**Rationale:** anti-patterns #45 is about a vendored lib drifting from upstream; this is the same
failure one level down — the addon's degraded path drifting from its live path, with both suites
green. testing-§8 permits (indeed requires) an integration suite over the wiring the addon owns; it
forbids duplicating the library's own coverage. Parity cases are integration cases, not duplicates.

**Trade-off accepted:** the degraded stub keeps its own `RestoreAllDefaults` loop. Losing the
settings panel is survivable, losing the ability to reset is not. The duplication is contained by
extracting the *predicate* rather than by deleting the loop.

**Alternatives considered.** *Delete the degraded reset entirely and print "unavailable"* —
rejected: `/at resetall` is a recovery verb, and a user whose panel will not open is exactly the
user who needs it. *Have the degraded stub call into the library through a soft lookup* — rejected:
there is no library in that build, by definition.

### T3. Make the comments load-bearing again

Three comments in the new files are the design rationale for non-obvious code, and each is wrong in
a way that would mislead the next maintainer into removing the part that matters.

- `settings/OptionsSetup.lua`'s "exactly three load-time members" list names two that are call-time
  and omits nothing — while the stub ships three constants nothing reads (F-005).
- `core/CoreSetup.lua` miscounts the `local print = NS.Print` captures its degradation argument
  rests on (F-014).
- `settings/Slash.lua`'s alias comment names a reader that no longer reads it (F-011).

**Rationale:** these files exist *only* to hold wiring and rationale; the implementations went
upstream. A wrong rationale in a file whose entire content is rationale is a defect in the file's
one job. documentation-§2 and the house comment style both treat the WHY as the deliverable.

### T4. Bring the addon's own half of the refresh contract in line with the library's

Everything the library refreshes now refreshes in place, per widget (options-ui-§11). The one
structural rebuild left in the addon rebuilds panels the user cannot see (F-008), and its
re-entrancy guard latches on error (F-009).

**Rationale:** options-ui-§11 and anti-patterns #39 are explicit: scope structural rebuilds to
`ctx.panel:IsShown()`, mark the rest dirty, rebuild lazily on next `OnShow`. F-008 is
**pre-existing** — carried verbatim from the deleted `settings/Helpers.lua` — but the branch made it
the only structural rebuild on the addon's side of the seam, so it is now cheap and legible to fix
in the same pass. F-009 is a genuine session-killer whenever anything inside the render raises.

**Alternatives considered.** *Make the re-render unconditional and rely on AceGUI's pool being
cheap* — rejected: anti-patterns #39 names this exact shape. *Drop the two-tier refresher and
re-render on every write* — rejected for the same reason, and because the file's own comment
correctly identifies the widget-released-mid-callback hazard that makes it worse than merely slow.

### T5. US English sweep of the lines this branch added

F-002 and F-017. Mechanical, but it must stop at the `libs/` boundary.

**Rationale:** localization-§5 / anti-patterns #46. None of the affected strings is a locale key —
they are comments and two prose lines — so no key migration is triggered and no `locales/*.lua` file
moves.

### T6. Cleanup — remove what nothing reads

F-010, F-012, F-018. Three small deletions/renames with no behavior change.

---

## LLD — change set

Change IDs are `C-n`. Every change names the findings it covers.

---

### C-1 — `/at resetall` acks inside its guard  *(F-001)*

**File:** `settings/Slash.lua`, `runResetAll` (~line 165).

```lua
-- before
    if NS.Helpers and NS.Helpers.RestoreAllDefaults then
        NS.Helpers.RestoreAllDefaults()
    end
    print("All settings reset to defaults")

-- after  (mirrors runResetPosition immediately below)
    if NS.Helpers and NS.Helpers.RestoreAllDefaults then
        NS.Helpers.RestoreAllDefaults()
        print("All settings reset to defaults")
    else
        print("Cannot reset settings \226\128\148 the settings helpers failed to load")
    end
```

**Risk:** none. The guard already existed; only the ack moves.
**Test:** extend `tests/test_slashcmds.lua` — with `NS.Helpers.RestoreAllDefaults` nil'd, the verb
must not print the success line.
**Standards conformance:** the line goes through the file-scope `print` bound to `NS.Print`, so it
keeps the cyan tag and the secret-safe path (slash-commands-§4, events-frames-taint-§8). No terminal
period, matching the neighbouring lines (slash-commands-§4). Em dash written as a byte escape, as
the rest of the file does.

---

### C-2 — README: bare argument in the `/at reset` row  *(F-003)*

**File:** `README.md:58`.

```
- | `/at reset <path>` | Reset one setting to its default — e.g. …
+ | `/at reset path`   | Reset one setting to its default — e.g. …
```

**Risk:** none.
**Standards conformance:** documentation-§1 (v2.14.0) — angle-bracket placeholders MUST NOT appear
in shipped README content; write the argument bare. Matches the `/at get name` / `/at set name
value` rows the same diff already corrected. **Explicitly out of scope:** the `<br>` tags in the
Version History table cells are deliberate HTML and MUST NOT be swept (same rule).
**Rejected alternative:** `` `/at reset [path]` `` — `[…]` is reserved for genuinely *optional*
arguments and the path is required, so it would trade a rendering bug for a factual one.

---

### C-3 — one predicate for the Profiles reset veto  *(F-004)*

**File:** `settings/OptionsSetup.lua`.

Add above the descriptor, and use it in both places:

```lua
-- The one rule about what a global reset must not touch. Profiles rows are AceDBOptions-supplied
-- and resetting them deletes user data, which is not what "restore defaults" means to anyone.
-- Named once because it is enforced twice: by the library (descriptor.skipRestoreAll) and by the
-- degraded stub's own reset loop, which has to keep working with no library at all.
local function vetoedFromResetAll(row) return row.page == "profiles" end
```

- descriptor: `skipRestoreAll = vetoedFromResetAll,`
- stub: `if not vetoedFromResetAll(row) then NS.ApplyDefault(row) end`

**Risk:** none — identical semantics, single definition.
**Test:** `tests/test_helpers.lua` — assert the degraded `RestoreAllDefaults` leaves a
`page = "profiles"` row untouched (it currently has no such case).
**Standards conformance:** savedvariables (profiles are user data) and testing-§8 (the addon's own
integration coverage over the wiring it owns). The tempting fix — deleting the stub's reset and
printing "unavailable" — was **rejected**: `performance-§1`'s degradation principle, applied
throughout this addon's five setup files, is that a missing lib costs the *feature*, not the
*recovery path*.

---

### C-4 — degraded/live dispatcher parity coverage  *(F-006)*

**Files:** `tests/test_slashcmds.lua` (new cases); `settings/Slash.lua` (comment only).

Add cases that drive the same inputs through the degraded environment (`loadDegraded()` already
exists in `tests/test_perf.lua`; lift it to `tests/_kit`-adjacent shared use or replicate the two
lines) and the live one, asserting **dispatch outcome**, not formatting:

| input | assertion |
|---|---|
| `"toggle target"` | same unit toggled in both builds |
| `"options"` | resolves to `config` in both (the `aliases` map) |
| `"TOGGLE Target"` | verb folded, `rest` case preserved, in both |
| `"nosuchverb"` | both print an unknown-verb line **and** the help block |
| `""` | both print help |

Then correct the block comment at `settings/Slash.lua:372-379` to say what is actually duplicated
(the dispatcher) and that the parity cases are what hold it honest.

**Risk:** none — tests plus a comment.
**Standards conformance:** testing-§8 — an addon consuming a shared harness keeps a **smaller
integration suite** over the wiring it owns and MUST NOT duplicate the library's unit coverage.
These cases assert the addon's own degraded dispatcher against its own live one; the library's
formatter/parser cases stay upstream. Asserting the *formatted strings* was **rejected** for exactly
that reason — the row colors and spacing are pinned in the LibKa0s suite (and the addon's own
`tests/test_slashcmds.lua:4201`-vicinity comment already says so).

---

### C-5 — resolve `LibKa0s-Slash-1.0` once at load  *(F-007)*

**File:** `settings/Schema.lua`.

```lua
-- before (inside NS.FormatSchemaValue, every call)
    local lib = LibStub and LibStub("LibKa0s-Slash-1.0", true)

-- after (file scope, once)
local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
...
function NS.FormatSchemaValue(row, v)
    if SlashLib then return SlashLib.FormatValue(row, v) end
    ...
end
```

**Risk:** none. `settings/Schema.lua` loads after `libs\LibKa0s\LibKa0s.xml` (toc-file-§5), so the
major is already registered or permanently absent — the per-call re-resolution could never have
found it later.
**Standards conformance:** library-stack-§4 — call `LibStub("X")` exactly once at load and stash;
SHOULD NOT call `LibStub` from per-frame code. Also removes the last per-call `LibStub` from the
addon's write seam (performance-§2's spirit: a dormant diagnostic path costs a field read).

---

### C-6 — restore the degraded value formatter's branches  *(F-015)*

**File:** `settings/Schema.lua`, the `if SlashLib then … end` fallback (after C-5).

Reinstate the three branches `master` had (`color` → `{%.2f, …}`, `number` + `row.fmt`, empty
`string` → `(none)`), or — if the team prefers the minimal fallback — replace the comment with an
explicit statement that the fallback is minimal *because* its only caller (the gated `[Set]` line)
is inert in a build with no `NS.DebugLog`.

**Recommendation:** restore the branches. They are eight lines, they were already written and
tested on `master`, and "unobservable today" is how a defect survives to the day it becomes
observable.
**Risk:** none — the live path is unchanged.
**Test:** `tests/test_schema.lua`'s `FormatSchemaValue formats by type` case, re-pointed at the
degraded environment for the fallback arm.

---

### C-7 — scope the unit-panel structural rebuild to the on-screen page  *(F-008)*

**File:** `settings/UnitPanel.lua`, the refresher registered at the foot of `RenderUnitPanel`, and
the `OnShow` guards in `settings/Bar.lua`, `settings/Border.lua`, `settings/Font.lua`.

```lua
-- refresher, after
    ctx.refreshers[#ctx.refreshers + 1] = function()
        local nowMirrored = NS.Units.IsMirrored(renderedUnit)
        if cb then cb:SetValue(nowMirrored) end          -- always: in place, cheap
        if nowMirrored == renderedMirrored then return end
        -- Structural: the mirrored/unmirrored row partition is invalid. Only the on-screen page
        -- rebuilds now; the others pick it up on their next OnShow (options-ui-§11).
        if ctx.panel and ctx.panel:IsShown() then
            Helpers.RenderUnitPanel(ctx, pageKey)
        else
            ctx.__dirty = true
        end
    end
```

and in each page's `OnShow`:

```lua
    if rendered and not ctx.__dirty then return end
    rendered, ctx.__dirty = true, nil
    H.RenderUnitPanel(ctx, pageKey)
```

**Risk:** low, but real — the three page files' first-show guards are `local rendered` closures and
each must be edited identically. A missed one leaves that page stale after a background mirror
change. Covered by test.
**Test:** `tests/test_helpers.lua` — with a page's `ctx.panel:IsShown()` false, a mirror write must
not re-render it but must set `__dirty`; a subsequent `OnShow` must render once.
**Standards conformance:** options-ui-§11 (in place for scalars, on-screen only for structural,
dirty-flag for the rest) and anti-patterns #39. The mock's `IsShown` must answer honestly for this
to be testable — `tests/_kit/mock_base.lua` is vendored, so if it does not, that is an upstream
item, not a local patch (anti-patterns #45).

---

### C-8 — make the re-entrancy flag exception-safe  *(F-009)*

**File:** `settings/UnitPanel.lua`.

Wrap the render body so the flag clears on both paths and the failure is reported rather than
swallowed:

```lua
    if ctx.__rendering then return end
    ctx.__rendering = true
    local ok, err = pcall(renderBody, ctx, pageKey)   -- body extracted, unchanged
    ctx.__rendering = false
    if not ok then NS.Print(("unit panel render failed: %s"):format(NS.SafeToString(err))) end
```

**Risk:** low. Extracting the body is mechanical; the `pcall` changes an error popup into a chat
line plus a recoverable panel.
**Test:** plant a raising widget maker and assert the flag is false afterwards and a second render
proceeds.
**Standards conformance:** matches the library's own choice to `pcall` each refresher for the same
reason (`libs/LibKa0s/Options.lua:305,330`). The report goes through `NS.Print` and
`NS.SafeToString`, never a raw `print` or a bare concat (events-frames-taint-§8, anti-patterns #35).
**Rejected alternative:** clearing the flag in the page's `OnShow` instead — it would leave the flag
latched for every non-`OnShow` caller (the dropdown, the refresher), which is most of them.

---

### C-9 — **UPSTREAM (LibKa0s)** — `RenderRows` must not mutate the host's hook tables  *(F-016)*

**File (upstream):** `LibKa0s/LibKa0s/OptionsWidgets.lua`, `O.RenderRows`.

Replace the two `= nil` writes with a local fired-set:

```lua
    local firedGroup, firedPair = {}, {}
    ...
    if pairWith and row.path and pairWith[row.path] and not firedPair[row.path]
       and pendingCount == 1 then
      pairWith[row.path](ctx, pendingRow); firedPair[row.path] = true
      pendingCount = pendingCount + 1
    end
```

**Process:** upstream commit → bump `OptionsWidgets`'s LibStub file minor (and its CHANGELOG entry)
→ separate **re-vendor commit** in this addon → `diff -r` clean.
**Risk:** the file minor bump is the step that actually ships it; a change without it does not reach
any host already carrying the old copy.
**Standards conformance:** library-stack-§7 (byte-identical vendored copy; re-vendor commit in every
consumer, ideally its own commit; a minor per file, never in lockstep) and anti-patterns #45. A
local patch to `AbsorbTracker/libs/` is **forbidden** and would break the `diff -r` evidence check.

---

### C-10 — **UPSTREAM (LibKa0s)** — US English sweep of the library's comments  *(F-017)*

**Files (upstream):** `Core.lua`, `OptionsWidgets.lua`, `Slash.lua` — `colour`/`colours` → `color`/
`colors` in comments only.
**Process:** as C-9 — upstream, minor bumps on the touched files, re-vendor commit here.
**Standards conformance:** localization-§5, anti-patterns #46. Sanctioned exceptions (Blizzard
symbols such as `SetTextColor`, `GRAY_FONT_COLOR`) must not be touched.

---

### C-11 — US English sweep of the addon's added lines  *(F-002)*

**Files:** `settings/OptionsSetup.lua`, `settings/Slash.lua`, `settings/UnitPanel.lua`,
`settings/Schema.lua`, `README.md`, `CLAUDE.md`, and the new `tests/` comments.

`colour → color`, `Colours → Colors`, `colouring → coloring`, `coloured → colored`,
`honoured → honored`, `generalise(s) → generalize(s)`, `grey → gray`.

**Risk:** none — no locale key moves, because the addon wraps no strings in `NS.L` yet
(`locales/enUS.lua` documents that deliberately). **Do not** extend the sweep into `libs/` (that is
C-10) or into `docs/audits/` and `docs/reviews/`, which are frozen historical bundles
(audit-review-history).
**Standards conformance:** localization-§5, anti-patterns #46.

---

### C-12 — correct the three load-bearing comments  *(F-005, F-011, F-014)*

**Files:** `settings/OptionsSetup.lua:104-131`, `core/CoreSetup.lua:20`, `settings/Slash.lua:104`.

1. **`settings/OptionsSetup.lua`** — rewrite the "verified to be exactly three" paragraph:
   `LSMValues` is the sole **load-time** member (the schema-row literals in `settings/Bar.lua`,
   `Border.lua`, `Font.lua`); `SECTION_HEADING_H` and `RestoreAllDefaults` are needed but reached at
   **call** time, from `Helpers.BuildMainContent` and the StaticPopup's `OnAccept` closure
   respectively. Then delete `SECTION_HEADING_H`/`ROW_VSPACER`/`BUTTON_PAIR_REL` from the stub — in
   a degraded build nothing reads them, and their values are copies of `lib.LAYOUT`
   (options-ui-§8), which is the drift this file's own comment forbids.
   **If** a reader is found for any of them, keep that one and say why in one line.
2. **`core/CoreSetup.lua:20`** — "four settings files" → "three settings files"
   (`Slash`, `General`, `OptionsSetup`; `Schema.lua`'s capture is function-scoped).
3. **`settings/Slash.lua:104`** — the alias's comment must stop naming About as its reader.

**Risk:** deleting the three stub constants is the only behavioral line here; C-12's test is
`tests/test_perf.lua`'s existing degraded-load case, which must stay green.
**Standards conformance:** options-ui-§8 pins those constants as the **library's** values; a second
copy in a host is the copy that goes stale. `tests/test_helpers.lua:244-247` asserts them on the
**live** instance and is unaffected.

---

### C-13 — one voice for the "library missing" message  *(F-013)*

**Files:** `core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`,
`settings/Slash.lua`.

Keep each seam's one-shot behavior, but make the cause clause identical across all four and let each
seam add only what *it* lost:

> `The LibKa0s library is missing from this installation of Absorb Tracker (expected in
> libs/LibKa0s).` + ` The settings panel is unavailable.` / ` The debug console window is
> unavailable.` / ` /at <verb> is unavailable.`

`core/CoreSetup.lua` cannot import a constant (it is the first seam to load and the others load
after), so the shared clause lives there as `NS.LIBKA0S_MISSING` and the later seams read it with a
fallback literal.

**Risk:** low; wording only.
**Standards conformance:** slash-commands-§4 — every line through the shared tagged printer, no
trailing colon, no hand-written tag, no pre-concatenation via `..`/`tostring` before the printer
(events-frames-taint-§8). Note `core/CoreSetup.lua`'s fallback branch legitimately writes to
`DEFAULT_CHAT_FRAME` directly — it *is* the printer at that point.

---

### C-14 — remove what nothing reads  *(F-010, F-012, F-018)*

**Files:** `settings/OptionsSetup.lua`, `settings/Slash.lua`, `settings/UnitPanel.lua`, plus the 15
test call sites for the last item.

- `NS.PARENT_TITLE` → demote to a file-scope `local PARENT_TITLE`; the descriptor is its only
  reader. (If any doc or sibling addon is documented as reading it, keep the export and note why.)
- Delete `stub.CliVersion` from the degraded slash stub.
- Replace `Helpers.__lastUnitCtx` with the library's existing `Helpers.__panelFor(pageKey)` at the
  15 test call sites, then delete the field.

**Risk:** the `__lastUnitCtx` swap touches `tests/test_helpers.lua` (14 sites) and
`tests/test_widgets.lua` (1). Mechanical but wide; do it as its own commit so a bisect is clean.
**Standards conformance:** naming-cheatsheet (namespace exports are a published surface) and
testing-§8 (the library already supplies the seam; a host-side duplicate is host code that exists
only for tests). `Helpers.__panelFor` is the library's own documented test seam
(`libs/LibKa0s/Options.lua:447-460`), so this moves *toward* the shared contract, not away.

---

## Change → finding map

| Change | Findings | Files |
|---|---|---|
| C-1 | F-001 | `settings/Slash.lua`, `tests/test_slashcmds.lua` |
| C-2 | F-003 | `README.md` |
| C-3 | F-004 | `settings/OptionsSetup.lua`, `tests/test_helpers.lua` |
| C-4 | F-006 | `tests/test_slashcmds.lua`, `settings/Slash.lua` (comment) |
| C-5 | F-007 | `settings/Schema.lua` |
| C-6 | F-015 | `settings/Schema.lua`, `tests/test_schema.lua` |
| C-7 | F-008 | `settings/UnitPanel.lua`, `settings/Bar.lua`, `settings/Border.lua`, `settings/Font.lua`, `tests/test_helpers.lua` |
| C-8 | F-009 | `settings/UnitPanel.lua`, `tests/test_helpers.lua` |
| C-9 | F-016 | **upstream** LibKa0s `OptionsWidgets.lua` → re-vendor `libs/LibKa0s/` |
| C-10 | F-017 | **upstream** LibKa0s `Core.lua`, `OptionsWidgets.lua`, `Slash.lua` → re-vendor |
| C-11 | F-002 | `settings/*.lua`, `README.md`, `CLAUDE.md`, `tests/*.lua` |
| C-12 | F-005, F-011, F-014 | `settings/OptionsSetup.lua`, `core/CoreSetup.lua`, `settings/Slash.lua` |
| C-13 | F-013 | `core/CoreSetup.lua`, `core/DebugLogSetup.lua`, `settings/OptionsSetup.lua`, `settings/Slash.lua` |
| C-14 | F-010, F-012, F-018 | `settings/OptionsSetup.lua`, `settings/Slash.lua`, `settings/UnitPanel.lua`, `tests/*` |

## Documentation roll-forward (applies to every change)

`docs/file-index.md`, `docs/module-map.md`, `docs/settings-panel.md`, `docs/schema.md` and
`docs/ARCHITECTURE.md` all describe the members and line counts touched above, and
`docs/test-cases.md` plus the README `[tests]` badge are the authoritative pass count — both **MUST**
be regenerated/updated in the same change that moves the suite (testing-§5, documentation-§1). The
`[wow]` badge and `## Interface:` are untouched by this work.
