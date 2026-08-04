# 04 — Technical Design

Remediation design for the deviations in `02_DEVIATIONS.md`, keyed by ID. This document says **how**
to close each gap and what it risks; `05_EXECUTION_PLAN.md` says in what order.

Nothing here has been applied — the audit is read-only. Two of the nine items (AT-30, AT-31) are
decision items rather than work items and are designed only to the point of naming the two branches.

**Shape of the work.** Five of the nine touch documentation only and carry no runtime risk. One
(AT-34) is a ten-line move inside one file with a real in-game symptom. One (AT-35) is a mechanical
sweep over 17 call sites plus one new export. Nothing requires a schema migration, a version bump,
or a change under `libs/`.

---

## D-1 — README data that mirrors a source of truth (AT-32, AT-33)

**Files:** `README.md`. **Optionally:** `tests/test_docs.lua`.

Both deviations are the same failure in two places: a static README field that mirrors data living
elsewhere and went stale because nothing compares them.

**AT-32 — the badge.** `README.md:7` becomes
`![Tests](https://img.shields.io/badge/Tests-469%2F469_passing-green)`. Keep the `%2F`; keep the
`green` color; do not touch the standard badge's underscores (`documentation-§1` is explicit that
`%20` there is a transcription error, not a form to restore).

**The durable half.** The count already exists mechanically in two places — the runner's own total
and `docs/test-cases.md`'s `## Totals` row — and the badge is the only figure in the repo with no
check behind it. `tests/test_docs.lua` already reads `README.md` (it carries the angle-bracket
placeholder case), so the natural home for a new case is there:

> read `docs/test-cases.md`, extract the integer from the `| **Total** | **N** |` row; read
> `README.md`, extract `X` and `Y` from the `Tests-<X>%2F<Y>_passing` badge; assert `X == Y == N`.

Two properties make it worth adding rather than relying on discipline: it fails on the commit that
moves the count rather than at the next audit, and it costs nothing to run. Per `testing-§12`, prove
it can fail before committing it — flip the badge to 468 locally, watch the case go red, restore
from a `cp` backup (not `git checkout`).

**AT-33 — What's new vs Version History.** The two disagree about what 1.9.0 was. `## What's new` is
the fuller and more accurate account (it names the target/focus bars, the per-bar enable model and
the breaking slash-path change); the Version History row is the one that is wrong. So the edit is to
the **row**, not the section: rewrite `README.md:159`'s Highlights cell to carry the same beats as
the eight bullets, leading with the two a user most needs to see — the new bars and the breaking
path change — and keeping the existing four. Preserve the `<br>`-separated cell format the other
rows use (real HTML the standard permits, `documentation-§1`).

Do **not** shorten `## What's new` to match the row instead. `documentation-§1` item 5 describes the
section as "the top Version History row surfaced up front", and the row is the one missing content.

**Risk:** none at runtime. The one hazard is doing this piecemeal — the standard's roll-forward rule
exists because a deferred half is how they drifted. Both edits land in one commit.

---

## D-2 — Lazy-build the Profiles page body (AT-34)

**File:** `settings/Profiles.lua`. **Test:** extend the existing options-page suite.

**Current shape.** `build(mainCategory)` does registration work *and* body work: it resolves the four
optional libs, creates the panel via `H.CreatePanel`, then creates and anchors an AceGUI
`SimpleGroup` (lines 50–55) before installing an `OnShow` that calls `AceConfigDialog:Open`.

**Target shape.** The builder keeps everything up to `H.CreatePanel` and the subcategory return; the
container creation moves inside `OnShow`, created once:

```lua
local container   -- created on first OnShow, reused thereafter

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

`AceConfig:RegisterOptionsTable` stays in the builder — it registers a data table, creates no widget,
and re-registering it per show would be pointless work.

**Why the move fixes two things at once, which is why it must not be "simplified" later.**
`options-ui-§5` gives one reason (AceGUI lays children out against a container whose width is zero
at registration) and anti-pattern #42 gives an entirely different one (a widget created during the
load window misses the skinning hooks that later-loading UI addons install, so it renders in stock
art for the session while every sibling comes out skinned — from identical code, decided by folder
sort order). The comment on the change should record both, because someone reading only the first
would conclude a `SetWidth` call would do.

**Risk.** Low but not zero. `AceConfigDialog:Open` currently receives a container that has already
been parented and anchored at the time the panel first shows; after the move it receives one created
microseconds earlier in the same call, which is the ordering every other Ka0s page already uses. The
`ctx.body` frame exists from `CreatePanel`, so the anchor targets are valid. The in-game check is
the one that matters: open Settings → Ka0s Absorb Tracker → Profiles and confirm the AceDBOptions
controls fill the page as before — add it to `docs/smoke-tests.md`.

**Test.** The existing case "a page renders nothing until its first OnShow" cannot reach this page,
because the Profiles builder returns nil headlessly when AceDBOptions is absent (which is correct
behavior — `options-ui-§5` calls a nil-returning builder a legitimate opt-out). To cover it, the
mock needs `AceDBOptions-3.0`, `AceConfig-3.0` and `AceConfigDialog-3.0` registered through
`M.__libs` (`testing-§1` names that seam precisely so a fake can be added without reaching through
LibStub's closure). Then assert: after `build`, no `AceGUI:Create` was recorded; after the first
`OnShow`, exactly one `SimpleGroup` exists; after a second `OnShow`, still one.

---

## D-3 — Publish `Format` and sweep the pre-concatenated call sites (AT-35)

**Files:** `core/CoreSetup.lua`, `settings/Slash.lua`, `settings/Schema.lua`.

**Step 1 — publish the missing export.** `LibKa0s-Core-1.0`'s printer factory returns both `Print`
(varargs, each argument stringified) and `Format` (a `string.format` over pre-stringified
arguments). The addon publishes only the first, which is why every formatted line had to be built by
the caller. Add beside it:

```lua
NS.Print  = printer.Print
NS.Format = printer.Format
Util.print = NS.Print
```

and give the library-absent branch (`core/CoreSetup.lua:27-59`) a matching `NS.Format` built on the
same fallback stringifier — that branch is the one place `events-frames-taint-§8` sanctions a second
copy, and leaving `NS.Format` nil there would move the crash to the degraded install.

**Step 2 — convert the call sites.** Two mechanical rewrites:

- `print(("… %s …"):format(a, b))` → `NS.Format("… %s …", a, b)`
- `print("literal " .. a .. " more")` → `print("literal", a, "more")` — `printer.Print` joins with a
  single space, so re-check any site where the spacing matters (`"'" .. name .. "'"` needs
  `NS.Format("'%s'", name)` rather than the varargs form, or the quotes end up spaced).

The 17 sites are listed with line numbers in `03_EVIDENCE.md` §AT-35. `settings/Slash.lua:33` and
`:403` are pure two-space indents on an already-formatted library row — those may stay as
concatenation, but say so in a comment so the next sweep does not "finish the job" and change the
help block's indentation.

**Step 3 — keep it from coming back.** `luacheck` cannot see this. A cheap gate in
`tests/test_slash.lua`: grep the addon's own `.lua` sources for `print%(.*%.%.` and
`print%(%(".*"%):format`, allow-listing the two indent sites by line content. That is a real
tripwire rather than a comment, and it is the same shape as the existing US-spelling source scan
which already proves the pattern works in this repo.

**Risk.** Low. The change is at output sites only; the values are the same values. The one thing to
watch is spacing in quoted-name messages, which is why the conversion should be read line by line
rather than done with `sed`. Every affected verb has a smoke-test line in `docs/smoke-tests.md`
already (`/at profile list`, `use`, `new`, `copy`, `delete`, `/at toggle`, `/at test`).

**Why it is worth doing at all, given nothing is secret today.** The whole design of the seam is
that no call site has to know whether its value can be secret. `runProfile` is a plausible future
home for a line that reports something read from a unit; the guarantee is only worth having if it is
unconditional.

---

## D-4 — Cross-reference sweep (AT-36)

**Files:** 15 source files, `docs/ARCHITECTURE.md`. Comments and prose only — no executable line
changes.

`grep -rnE '§[0-9]+\.[0-9]+|Ka0s standard §[0-9]+' core modules settings locales defaults docs` gives
the full list (reproduced in `03_EVIDENCE.md`). The mapping from the retired global numbering to the
current scheme, derived from the standard's own v1.5.0 and v2.0.0 changelog entries:

| Retired | Current |
|---|---|
| §1.4 | `layout-§3` |
| §2.2 | `toc-file-§2` |
| §3.1 / §3.4 / §3.5 | `library-stack-§1` / `library-stack-§4` / `library-stack-§5` |
| §4.1 / §4.2 / §4.5 | `architecture-§1` / `architecture-§2` / `architecture-§5` |
| §5.1 | `savedvariables-§1` |
| §7.1 / §7.4 | `slash-commands-§1` / `slash-commands-§4` |
| §8 / §8.2 | `localization` / `localization-§2` |
| §9 / §9.1 | `events-frames-taint` / `events-frames-taint-§1` |
| §11 | `compat` |
| §12.2 / §12.4 / §12.5 | `debug-logging-§2` / `debug-logging-§4` / `debug-logging-§5` |

Three specifics:

- `settings/Slash.lua:199` is malformed (`slash-commands-§:`) — it means `slash-commands-§3`.
- `core/DebugLogSetup.lua:107` and `core/AbsorbTracker.lua:79` are half-converted
  (`debug-logging §4`, `debug-logging §5`) — close the gap to `debug-logging-§4` / `-§5`.
- `core/Units.lua:8`'s `spec §2/§3` refers to the addon's own multi-unit spec, not the standard.
  Leave it, and consider rewording so a future sweep does not mistake it.

**Frozen history is out of scope.** `docs/audits/2026-07-12/`, `docs/audits/2026-07-18/` and
`docs/reviews/2026-08-03/` keep their original wording — `audit-review-history` makes prior runs
frozen, and the standard's own changelog keeps its retired references for the same reason.

**Risk:** none. Verify with the same grep returning only `core/Units.lua:8` afterwards, plus a green
gate to catch a fat-fingered comment delimiter.

---

## D-5 — Refresh the accepted-deviation register (AT-37)

**File:** `docs/ARCHITECTURE.md`, `## Standards Deviations` (line 271 onward).

Four entries have been overtaken by the standard:

| Entry | Now | Action |
|---|---|---|
| `X-Wago-ID` omission (`:277`) | `toc-file-§1` makes Wago/WoWI **MAY** | Delete. Closes AT-05 for good. |
| `AbsorbTrackerPerfDB` (`:284`) | `savedvariables-§4` / `toc-file-§2` mandate it | Delete or convert to a one-line "adopted in v2.12.0" note |
| `lizard` / `docs/complexity.md` (`:296`) | `performance-§10` SHOULDs it | Same |
| Gated bracket idiom (`:306`) | `performance-§2` mandates the exact shape | Same |

Keep the four that are still live decisions: the per-profile `schemaVersion` stamp, the per-unit
event frames (AT-31), the `__lastUnitCtx` test seam, and the fixed non-Blizzard media (which the
standard sanctions but which is worth keeping recorded, since `debug-logging-§2` and
`standalone-windows` both say an audit must *not* flag it — a note that says why is how the next
reader knows that was checked rather than missed).

**Prefer conversion to deletion for the three "pending promotion" entries.** They record that the
addon prototyped a pattern the standard then adopted, which is institutional memory worth two lines.
Delete the "Pending promotion" paragraphs — they point at a spec whose rollout has happened.

**Risk:** none. The section is prose; nothing reads it programmatically.

---

## D-6 — Preview while unlocked (AT-38)

**Files:** `modules/Display.lua`, `settings/Slash.lua`.

Two SHOULDs, and the second is a much smaller change than the first, so they can be taken
independently.

**The verb's off switch (small).** `runTest` currently sets `NS.testHoldUntil = GetTime() + hold`
and has no way back except waiting. Accept `off` / `0` as the first argument and set
`NS.testHoldUntil = nil`, then publish `REPAINT` so live values return immediately. Update the
`NS.COMMANDS` description and the README row in the same change (`documentation-§1` item 7 requires
the table to track `NS.COMMANDS`).

**Auto-preview while unlocked (larger).** The seam already exists: `NS.UpdateAbsorbBar` early-outs
while `testHoldUntil` is in the future, leaving whatever was painted. The design that keeps a single
render path — which `preview-mode` requires — is not to reuse that hold, but to feed a placeholder
value *through* the normal paint:

```lua
-- in NS.UpdateAbsorbBar, replacing the raw read
local totalAbsorb
if NS.PreviewActive() then
    totalAbsorb = NS.PreviewValue(unit)      -- e.g. 40% of maxHealth
else
    totalAbsorb = UnitGetTotalAbsorbs(unit) or 0
end
```

with `NS.PreviewActive()` returning true while `not NS.GetSetting("locked")` or while an explicit
`/at test` hold is running. Locking republishes `REPAINT`, so live data returns with no extra
plumbing — which satisfies the section's MUST by construction rather than by a timer.

Two things to be careful of. The placeholder must be derived from `UnitHealthMax` rather than a
constant, or the bar reads full on a low-health unit and empty on a tank. And `ShouldShowBar` must
not be relaxed: a target bar with no target should still be hidden while unlocked, or unlocking
spawns bars for units the user does not have.

**Risk.** Medium by the standards of this list, because it touches the paint path that the perf
buckets measure. Keep the preview branch out of the bracket's hot arm — it costs one function call
per paint, and `paintBar` is a declared bucket, so a regression here shows up in a capture. If that
is unwelcome, gate on a module-local upvalue refreshed from the `locked` setter, the
`events-frames-taint-§7` pattern the addon does not currently use but which exists for exactly this.

---

## D-7 — Advisory items (AT-39, AT-40, AT-41)

- **AT-39.** Narrow `.luacheckrc:7` to `{ "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/" }`
  and re-run `luacheck .` — expect 0/0 unchanged, since no `.lua` lives under `docs/`. Or leave it
  and extend the existing comment to say the widening is deliberate.
- **AT-40.** `modules/Bar.lua:6` — replace `core/DebugLog.lua` with the real readers.
- **AT-41.** No change. Recorded so the judgment is not re-derived next run.

---

## D-8 — The two decision items (AT-30, AT-31)

Neither is designed further, because both need the user's call first and the design differs
completely by branch.

**AT-30 (localization).** Branch A: record it as an accepted deviation with the reason
(single-maintainer addon, no translator pipeline) and stop re-raising it. Branch B: a mechanical
wrap of user-facing strings in `NS.L["…"]`, English-string keys, no `enUS` values needed since the
metatable returns the key. Branch B is non-breaking but touches every settings page and the slash
surface, so it is its own milestone, not a step in this plan. Deferred twice already
(`docs/pending/LEDGER.md` PLAN-02).

**AT-31 (per-unit event frames).** The engineering is settled and correct; what is unsettled is
whether it stays a per-addon accepted deviation or becomes a sanctioned exception in
`events-frames-taint-§1`. The second is the better outcome — the justification is general (AceEvent
structurally cannot unit-filter, and `RegisterUnitEvent` is the established pattern) and any Ka0s
addon watching `UNIT_*` events will hit it. That change belongs upstream in `WowAddonStandards`, not
here; until it lands, the entry stays in `docs/ARCHITECTURE.md` and re-surfaces each audit with its
reason, which is the system working as designed.

---

## Ordering constraints

Only two exist.

1. **D-3 step 1 before D-3 step 2.** `NS.Format` has to exist before a call site uses it.
2. **D-1's badge fix last among any change that moves the test count.** D-2 and D-3 both propose new
   cases; each one moves the total, and the badge must be updated *in the same change* that moves it
   (`testing-§5`). So either add the cases first and set the badge once at the end, or update the
   badge with each. `05_EXECUTION_PLAN.md` takes the first route and says so explicitly.

Everything else is independent and could be done in any order or in parallel.
