# 04 — Technical Design

Remediation for the nine roots in `02_DEVIATIONS.md`. Every change is a document, a TOC comment, a
register edit, one record bundle, or a small code reshape that changes nothing a player sees. No stored
shape moves, so nothing here owes a migration or a `NS.SCHEMA_VERSION` bump. The green gate
(`lua tests/run.lua`, `luacheck .`) stays the acceptance for every code change, run through
`ka0s-bounded`.

Ordering constraint, one only: **`AT-82` before `AT-80`.** The span bundle records what v1.69.0 and
v1.70.0 brought, and the doc sync then counts the tree the bundle describes. Everything else is
independent.

---

## AT-82 — the missing re-vendor span bundle

**Shape.** `docs/revendor/<date>-v1.68.1-v1.70.0/` with the two stable members only
(audit-review-history's consolidated span shape):

- `01_DELTA.md`, line 1 exactly `Delta: LibKa0s v1.68.1 -> v1.70.0 (span: v1.68.1 v1.69.0 v1.70.0)`.
  Body: per tag, what moved — v1.69.0 adds `WidgetsLineChart.lua` (WidgetsLineChart minor 1) and kit
  revision 37; v1.70.0 adds `WidgetsAutocomplete.lua` and WidgetsLineChart minor 2. Read from
  `git -C ../LibKa0s diff v1.68.1 v1.70.0 --stat -- LibKa0s testkit` and the library's CHANGELOG, not
  from memory.
- `05_SUMMARY.md`, one line per tag: `v1.69.0 — carried, nothing adopted (5075fd5)`,
  `v1.70.0 — carried, nothing adopted (4c16982)`. Neither new member has a consumer here.

**Risk.** None to the addon. Re-run the playbook's check afterwards; it must print nothing under
*UNRECORDED*.

## AT-80 — one doc sync

One `/dev-copilot:sync-docs` pass, scoped to the seven items, each corrected **against the tree**:

| Item | File(s) | Correction | Source of truth |
|---|---|---|---|
| 1 | `docs/ARCHITECTURE.md:49`, `docs/module-map.md:786`, `:942`, `docs/performance.md:390` | *thirty-two* → *thirty-four* files | `grep -c '<Script file=' libs/LibKa0s/LibKa0s.xml` |
| 2 | `docs/module-map.md:786`, `:942` | insert `WidgetsLineChart.lua` → `WidgetsAutocomplete.lua` after `WidgetsDragHandle.lua` | `libs/LibKa0s/LibKa0s.xml` order |
| 3 | `docs/testing.md:170` | v1.68.1 → v1.70.0, or better, "the tag `CLAUDE.md` names" so it never needs rolling | `CLAUDE.md:43` |
| 4 | `docs/module-map.md:884` | 175 → 178 lines; *thirty-two* → *thirty-five* own suites | `wc -l`, `tests/run.lua` suite list |
| 5 | `docs/module-map.md:887` | describe three per-unit frames, one unit token each | `core/AbsorbTracker.lua:193-198` |
| 6 | `docs/module-map.md:916` | drop the "live here at …" minors, or re-read them (DebugLog 19, Slash 19, Perf 14) | `libs/LibKa0s/*.lua` `MINOR` |
| 7 | `docs/module-map.md:468`, `:817` | v1.41.0 → v1.42.0 | `docs/ARCHITECTURE.md:377`, `docs/slash-dispatch.md:52` |

**Prefer symbols to numbers** where a number will move at the next re-vendor (items 1, 3, 4, 6): a
sentence that cites the XML or `tests/run.lua` does not go stale. **Risk:** none; docs only. The prose
gate (`test_prose`) and the docs suite (`tests/test_docs.lua`) run in the green gate and cover the
spelling and link shape.

## AT-83 — the gate table's complexity command

`docs/automated-tests/README.md:29`: replace the command cell with
`bash tests/_kit/run-automated-tests.sh --suite complexity` and the same parenthetical
`docs/testing.md:99` uses (sighted shadow, function-count parity, kit revision 35+). Leave the two
checkpoint columns as they are; they are already correct. Docs only.

## AT-84, AT-85 — two settings-block TOC annotations

Comment lines only, directly above the two entries, in the house form (`# LOAD-BEARING: publishes …,
which … at file load`):

```
# Settings (last — depend on everything else being initialized)
# LOAD-BEARING: publishes NS.SchemaRuntime and NS.RegisterSchemaRows; settings/OptionsSetup.lua's
# descriptor reads the runtime's AllRows/BulkBegin/BulkEnd and the page files register rows at file load.
settings\Schema.lua
settings\Slash.lua
# LOAD-BEARING: publishes NS.Helpers, which UnitPanel, About, General and Appearance take as a
# file-scope upvalue and whose composers General and Appearance call at file load.
settings\OptionsSetup.lua
```

Optionally add one conventional note for `Slash.lua` / `Profiles.lua` (the toc-file-§5 SHOULD).
**Risk:** the TOC is load order; comment lines change none. `tests/test_loadorder.lua` derives the
runner's list from the TOC and skips comments (`loadorder: tocFiles skips libs, directives and
comments`), so it stays green and proves the order did not move.

## AT-86 — retire the stale `savedvariables-§1` row

1. Delete the row at `docs/ARCHITECTURE.md:375`.
2. Add an entry under `docs/recorded-decisions.md` → *Retired register rows*: date, the row's content
   in one sentence, and the reason — savedvariables-§1 (v2.65.0) names "idempotently from AceDB's
   `OnProfileChanged` (and `OnProfileCopied` / `OnProfileReset`) callbacks against a per-profile
   stamp" as a compliant route, which is what the v3 lift does; keep the link to
   `profiles.md#the-v3-lift-and-why-the-gate-is-per-profile`.
3. Touch `docs/schema.md` / `docs/profiles.md` only where they call the stamp "a deviation".

No code changes: the behavior is now the compliant one. **Risk:** none.

## AT-88 — give `LibKa0s-Widgets-1.0` a seam (or a row)

Two options; the first is preferred because it puts the major under the parity gate the other ten
majors already have.

**Option A — a seam.** New `core/WidgetsSetup.lua`, placed in the TOC before `modules\` (anywhere in
`# Core` after `core\CoreSetup.lua`, annotated conventional — nothing resolves from it in core):

```lua
local _, NS = ...
local lib = LibStub and LibStub("LibKa0s-Widgets-1.0", true)
if not lib then
    -- Library-absent: no drag strip, and the default stack reserves no room for one.
    NS.Widgets = { DragHandle = nil, DRAG_HANDLE = nil }
    return
end
NS.Widgets = lib
```

Then `modules/Bar.lua:15` and `modules/Display.lua:26` read `NS.Widgets` instead of calling LibStub.
Note `modules/Display.lua:27-28` reads `DRAG_HANDLE` at file load, so the new seam's TOC line is
load-bearing and carries the annotation for it. Add a `tests/test_surface_parity.lua` case on the
kit's by-name form for `LibKa0s-Widgets-1.0` with the members from
`grep -ohE 'Widgets[.:][A-Za-z_]+' modules/ settings/ core/` (today `DragHandle`, `DRAG_HANDLE`), and
an `ignore` list for the library's members the addon never reaches. Keep the stub's answers nil for both
(that is the behavior today), so the degraded load is unchanged.

**Option B — record it.** A `## Documented deviations` row keyed `library-stack-§7`: *Widgets is
resolved inline in the two modules that draw or lay out the strip, nil-tolerant, no stub*; Why: a stub
would answer nil for both members, which is what the inline guard already does; Re-check trigger: *a
third Widgets member reached, or a third file reaching it*.

In either case, comment on issue #26 that the decline is superseded by the drag-handle adoption (no
relabel needed — it is closed). **Risk (A):** a load-order mistake would leave `HANDLE_ROOM` at 0 on a
healthy install; `tests/test_draghandle.lua` and `tests/test_display.lua` cover the strip and the
stack, and the new annotation guards the position.

## AT-78 — one pre-formatted line

`core/Database.lua:234-235`: hand the parts to `NS.Print` rather than concatenating:

```lua
NS.Print("Settings upgrade stopped at", "v" .. from, "->", "v" .. step.to
    .. "; saved settings were left as they were")
```

The printer joins with spaces, so the visible text is unchanged apart from spacing around the arrow;
the migration-failure test in `tests/test_database.lua` that pins this line (if any) is updated in the
same change. Alternative: widen the `events-frames-taint-§8` register row's scope to name
`core/Database.lua`. **Risk:** chat wording; pinned by test.

## AT-87 — use the console's gates

- `core/AbsorbTracker.lua:241-251`: replace the `dbgAbsorbSecret` comparison with
  `NS.DebugLog.DebugChanged("absorb:secret", "Absorb", secret and "reads secret: …" or "reads readable again")`.
  Keep the first-read behavior (no "readable again" line before any secret read) by passing the state
  as the gate's value rather than the message, per the library's `DebugChanged(key, tag, fmt, …)`
  contract — read `libs/LibKa0s/DebugLogGates.lua` for whether the change key is the formatted message
  or a separate value before writing it.
- `modules/Display.lua:381-383`: keep `dbgLastShown[unit] = show` (the diagnostics seam reads it), and
  write the `[Bar]` line through `DebugChanged("bar:" .. unit, "Bar", "%s: %s (%s)", …)`.
- Alternative with no behavior change to the lines: pass `onClear` in the DebugLog descriptor that
  resets `dbgAbsorbSecret` (and a log-only copy of `dbgLastShown`), so a Clear re-arms them.

**Characterization first** (testing-§13): pin today's lines with a case that toggles secret→readable
and shown→hidden and asserts the exact `[Absorb]` / `[Bar]` lines, then refactor, then add the
post-Clear case (Clear, same state again → line written once). `tests/test_debugcoverage.lua` is the
natural home. **Risk:** debug output only; nothing reaches chat or SavedVariables.

---

## What is deliberately not designed here

- **Info items** need no change in this repo (`AT-Info-1`, `-2` resolve at the next release run;
  `-4` is a LibKa0s kit item; `-5`, `-6` are standard/playbook items for the documentation lane;
  `-7`, `-8` are observations).
- **The two accepted register rows** stay as they are.
