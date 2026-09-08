# 04 — Technical Design

Remediation design for the eight entries in `02_DEVIATIONS.md` (7 roots + 1 dependent). All are Low.
Nothing here changes runtime behavior on a healthy install; the only production-path edit in the set
is inside a branch that runs when `libs/LibKa0s/` is missing.

**One ordering constraint binds the whole set:** `AT-62` and `AT-63` are a single change. Hollowing
the composers without rewriting the two cases turns the suite red, and rewriting the cases first
asserts a shape the stub does not yet have. Everything else is independent.

---

## AT-62 + AT-63 — hollow the Options stub's composers, and re-pin the suite on the gap

**Files:** `settings/OptionsSetup.lua`, `tests/test_perf.lua`, `tests/test_optionssetup.lua`.

**Shape of the change.** Inside the `if not lib then` branch at `settings/OptionsSetup.lua:166`:

- Replace the bodies of `ColorPair` `:225`, `FontGroup` `:236`, `BorderGroup` `:247`, `BarGroup`
  `:261` and `MasterControls` `:276` with the hollow form. Four return a row list; `MasterControls`
  returns a row list **and** an `afterGroup` closure, so it keeps the second return:

  ```lua
  Helpers.FontGroup     = function() return {} end
  Helpers.MasterControls = function() return {}, function() end end
  ```

- Delete `composeBlock` `:194` and `ORDER_STEP` with it — nothing else calls either.
- Keep `Helpers.MASTER_GROUP` `:274`. It is a literal the page file uses as an `afterGroup` key, not a
  composed row, and `settings/General.lua` reads it on both arms.
- Keep `Helpers.LSMValues` `:173` exactly as it is: it is genuinely load-completing —
  `settings/Appearance.lua` calls it **inside a schema-row literal**, so a nil there aborts the page
  file and takes the whole appearance schema with it. That is the member the load-completing MUST was
  written for, and it is not a composer.
- Keep `Helpers.RestoreAllDefaults` `:303`. Call-time, and `options-ui-§1` SHOULDs keeping the global
  reset real in the stub.
- Rewrite the block comment at `:175-189`. Its *"WHAT THEY REPRODUCE / WHAT THEY DELIBERATELY DO
  NOT"* argument is now an argument against the rule; replace it with the ruling and its precondition
  — the fall-together property, which this addon can state concretely because its Slash stub answers
  every schema verb *"unavailable"*.

**The suite half.** `tests/test_perf.lua:498` currently asserts the two arms are equal. Replace with
three pinned figures, per `options-ui-§1`:

```lua
local FULL, DEGRADED = #NS.Schema, #NS2.Schema
assertEqual(FULL - DEGRADED, COMPOSED_ROWS,
  "the gap is the composers' rows and nothing else")
```

where `COMPOSED_ROWS` is a named local with a comment attributing it per composer (bar 4, background
4, border 4, font 6, master 6, per unit where the block is per-unit). The **path-set** half of that
case stays and gets inverted: every path in the degraded schema must exist in the live one, and the
live-only set must be exactly the composed paths. That is the assertion that goes red the day a page
file starts declaring rows a composer used to, which is the failure mode §1 names.

`tests/test_optionssetup.lua:90` keeps its member-existence half — the five composers **MUST** still
exist — and loses the row-shape half at `:108-117`. Its `-- red under:` comment at `:102` inverts:
red under a stub composer that returns rows.

**Risk.** Low, and bounded to the library-absent load. The one thing to check is that no page file
reads a field off a composed row at load time; it does not — `settings/General.lua:88` binds the
returned rows straight into `NS.RegisterSchemaRows`, and `settings/Appearance.lua` does the same.
`masterOnChange` at `settings/General.lua:117` is keyed **by path**, so an empty row list means no
handler is attached rather than a handler attached to the wrong row.

**What is deliberately not done.** No attempt to preserve schema completeness on the degraded arm by
another route. The standard has ruled that the gap is correct and that closing it locally is the
deviation; `options-ui-§1` says what ends the hollowness — the library shipping the composers from a
file that loads without the Options major — and that is a `LibKa0s` change, not this repo's.

---

## AT-64 + AT-65 — annotate the two load-bearing TOC positions

**File:** `AbsorbTracker.toc`.

Two comment lines, in the form `AbsorbTracker.toc:39-40` already uses — the constraint and its reason,
naming what resolves:

```
# LOAD-BEARING: publishes NS.Perf, which core/AbsorbTracker.lua, modules/Display.lua and
# modules/Timer.lua take as a file-scope upvalue (performance-§1).
core\PerfSetup.lua
...
# LOAD-BEARING: publishes NS.Units, whose DeepCopy core/Database.lua takes as a file-scope
# upvalue at load.
core\Units.lua
```

**Risk:** none. Comments only; `tests/test_loadorder.lua` already skips comment lines when it derives
the load list from the TOC, and its case *"tocFiles skips libs, directives and comments"* proves it.

**Worth considering while there:** `tests/test_loadorder.lua` already asserts
*"core/MediaSetup.lua loads before core/Constants.lua"*. Two sibling cases —
`PerfSetup` before `AbsorbTracker.lua`, `Units` before `Database.lua` — would make the constraints the
comments describe machine-checked rather than only written down. That is an addition, not part of the
MUST.

---

## AT-66 — adopt `localization-§5`'s published lists

**File:** `tests/test_docs.lua`.

**Shape of the change.** Delete the 244-entry whole-word `BRITISH` map at `:192` and paste
`localization-§5`'s two published tables verbatim — `BRITISH` (91 lowercase substrings) and `ALLOWED`
(30 whole words) — under the section's own header comment, so a reader can see at a glance that they
were copied whole rather than curated. Then change the scan at `:338-357` from a whole-word map
lookup to §5's two-stage form:

1. delimit the line on non-letters;
2. drop tokens present in `ALLOWED` as **whole words**;
3. run the `BRITISH` **substrings**, case-insensitively, over what remains.

The `-> us` suggestion column goes: the published list is substrings, not pairs, and a substring has
no single correct replacement. Report `path:line word` and let the author choose.

**Consequences to expect.** The substring form is strictly wider than the map it replaces —
`colour` now catches `colours`, `colourise` and `Colouring` from one entry, and 22 families become
reachable that were not. Run the case before shipping the change; the one currently-live hit is
`docs/smoke-tests.md:247`, which is quoted external text and belongs on the exclusion list.

**While there — the exclusions.** §5 requires the four exclusions to be *"named file by file or
directory by directory in the gate itself rather than inferred from a pattern."* `ownFiles()` at
`:308` excludes frozen bundles by **not globbing them**, which is inference. Name them: `docs/audits/`,
`docs/reviews/`, `docs/automated-tests/<run>/`, `docs/perf-analysis/<run>/`, `docs/superpowers/`,
`docs/investigations/`, `docs/revendor/`, plus `libs/`, `tests/_kit/`, `locales/enGB.lua` (absent, but
named so it stays named) and this file's own copy of the lists.

**Risk:** test-only, and the risk is a false positive rather than a miss — which is the direction that
gets noticed. Note the standard's own warning: *analyses* escapes by construction and is not on either
list.

---

## AT-67 — the fifth stub-surface parity case

**File:** `tests/test_surface_parity.lua`.

Add a `Perf` case in the shape the other four use, through the kit's `T.assertSurfaceParity`, with the
degraded arm from `tests/degraded_env.lua`. Name the grep in the comment, as `testing-§8` MUSTs:

```lua
-- members from: grep -rno 'Perf\.[A-Za-z_]*' core/ modules/ settings/ defaults/ locales/
--   → on, suspended, Note, OnCommand   (Perf.lua at core/PerfSetup.lua:5 is a path in a comment)
```

`Perf` is an **instance** (`core/PerfSetup.lua:33`, `lib:New({…})`), so it takes the by-name form the
three library-backed seams use, with `tests/run.lua`'s `Kit.setSurfaceSource` registration extended to
cover it. Correct the file header's *"four LibKa0s seams"* to five in the same change.

**Not in scope, and the case's comment should say why:** `Env` and `Media` publish no stub table.
Their seams are the addon's own functions with an internal nil-guard (`core/EnvSetup.lua:65-74`), so
there is no member set that can drift from a live surface, and a parity case there would be asserting
on a table the test wrote.

**Risk:** none to production. The case is expected to pass on the day it is written; its value is that
it fails on the day someone adds a fifth member.

---

## AT-68 — name symbols in the register, not lines

**File:** `docs/ARCHITECTURE.md:335`.

Replace ``(`core/AbsorbTracker.lua:168`, `:231`)`` with the two symbols — `addon:OnAbsorbChanged` and
`addon:OnLeaveCombat` — which is what `M5-05` did for the source comments in the same cycle that broke
these. A symbol survives every refactor that moves a line and dies loudly on the one that renames it,
which is the correct failure.

**Sweep the rest of the register while there.** The other three rows cite files without line numbers
already (`defaults/Profile.lua`, `core/AbsorbTracker.lua`), so this is the only occurrence — verified
by re-reading `:333-336` in full.

**A gate is optional here and probably not worth it.** `tests/test_docs.lua` could assert that every
`file:line` the register cites resolves to a line containing an expected token, but the register is
four rows and the symbols form removes the failure mode outright. Prefer the cheaper fix.

---

## AT-60 — the wrapped-strip geometry case (blocked upstream)

**Files:** `tests/test_widgets.lua`, and `LibKa0s`'s `testkit/mock_base.lua` first.

Unchanged in shape from `docs/audits/2026-09-07/04_TECHNICAL_DESIGN.md`, and still blocked for the
reason `docs/smoke-tests.md:242` records: the shared mock answers `GetHeight` with 0 for every
frame, so a case asserting band geometry is invariant under selection cannot fail. Writing it against
today's mock would produce exactly what `testing-§12` forbids — a case that reads as coverage and
provides none.

**Order:** kit change first (real heights per atlas), then the case here:

1. render each page once per tab selection;
2. assert `ctx.chromeHeight` is identical across all of them;
3. assert every row's y offset is identical across all of them;
4. record in a comment the mutation it dies under — packing the wrapped rows off the **selected**
   tab's metrics rather than the unselected state.

This is `M1-LK-08` in the collection plan and was deferred there deliberately. It belongs in every
sibling addon, so it should be written once in the kit's shape and copied, not re-derived nine times.
