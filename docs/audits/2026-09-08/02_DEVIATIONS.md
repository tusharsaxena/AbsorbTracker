# 02 — Deviations

**Audited against:** Ka0s WoW Addon Standard **v2.39.0 (2026-09-07)**. Every section file linked from
the index was fetched and read; none is unassessed. Every count below was produced by a command whose
invocation, real output and **scope** are recorded in `03_EVIDENCE.md`. No number here is re-typed
from an earlier bundle.

**Verdict: minor deviations.** Nothing a player, their SavedVariables or their session can hit today.
Both gate commands are green (`luacheck .` 0/0 over 54 files; `lua tests/run.lua` 562/562, 0 skipped),
`lizard` warns on nothing, both vendored-payload diffs against LibKa0s `v1.27.0` are empty, the
line-ending working-tree check returns **0** and its vendored gate is present and green, `.pkgmeta`
accounts for every root dot-entry, and the deviation register's four rows all survive their three
checks. What remains is one settings-stub shape the standard settled this cycle, two TOC comments,
one test-gate list, one missing parity case and one stale citation.

**Counts, with their basis stated.**

- **Headline tally (roots only): 7.**
- **Total including `derived from` dependents: 8.**
- By impact, roots: High **0** · Medium **0** · Low **7**. The one dependent is Low.
- **MUST failures, same basis: 6 roots** (`AT-60`, `AT-62`, `AT-64`, `AT-65`, `AT-66`, `AT-67`) and
  **1 dependent** (`AT-63`, derived from `AT-62`). `AT-68` is a SHOULD.
- **Info: 3**, listed separately and not in either tally.

Every entry is graded **Low** because none is reachable by a user in the current code: three are
test- or config-only, two are TOC comments, one is a register citation, and one is a code path that
exists only on a load where `libs/LibKa0s/` is missing. The grade is impact; the MUST is named in
every row that fails one.

**IDs.** Prefix `AT-`, continuing from `docs/audits/2026-09-07/` (highest prior `AT-61`). `AT-60`
**recurs and keeps its ID**. New this run: `AT-62` … `AT-68`.

**Amendment provenance.** Four of the eight entries are visible only against v2.39.0's amended text
and would not have been filable a cycle ago: `AT-62`/`AT-63` (`options-ui-§1`'s hollow-composer
ruling), `AT-64`/`AT-65` (`toc-file-§5`'s stated denominator) and `AT-66` (`localization-§5`'s
published lists). That is the amendments doing their job, and it is the point of this run.

---

## Roots

| ID | Section | Rule strength | Sev | Deviation | Fix direction |
|---|---|---|---|---|---|
| **AT-60** | `options-ui-§13` | MUST | Low | *Recurs from 2026-09-07; deferred by design.* No suite case asserts that the tab strip's reserved band and every row's y offset are **identical for every value of the selection**. `tests/test_widgets.lua:810` asserts only `assertTrue(ctx.chromeHeight > 0, …)`. Neither page wraps today (two tabs on General, five on Appearance), so nothing is reachable — the defect appears the day a label pushes a strip onto a second row. The upstream half is the shared mock, which answers one height for every atlas, so a case written against it today would be green against nothing (`testing-§12`). | Unchanged from last run, and the blocker is upstream: the mock has to answer real heights before the case can fail. Then render each page once per tab selection and assert `chromeHeight` and each row's y offset are equal across all of them, recording in a comment the mutation that reddens it. |
| **AT-62** | `options-ui-§1` · anti-pattern #73 | MUST | Low | The `LibKa0s-Options-1.0` degradation stub carries a **host copy of every composed block**. `settings/OptionsSetup.lua:166` opens the library-absent branch and publishes five composers — `ColorPair` `:225`, `FontGroup` `:236`, `BorderGroup` `:247`, `BarGroup` `:261`, `MasterControls` `:276` — each emitting the full canonical leaf set through a local `composeBlock` at `:194`. v2.39.0's `options-ui-§1` settles this in the other direction: the stub's composer members **MUST** exist and **MUST** answer an **empty row list**, a hollow composer is the compliant answer, and *"no addon may close the gap locally by writing one."* The exemption's own precondition holds here — the Slash stub answers every schema verb *"unavailable"*, so no composed row is addressable-but-missing — which is exactly what makes the hollow form available. Not reachable by a user: the vendored library always ships, so this branch runs only on a broken install. | Replace each of the five composer bodies with `return {}, function() end` and delete `composeBlock` and `ORDER_STEP` with them. Keep `LSMValues` and `RestoreAllDefaults` as they are — those are genuinely load-completing and call-time respectively. Then rewrite the two cases (see `AT-63`) and delete the stub's *"WHAT THEY REPRODUCE"* rationale, which is now an argument against the rule. |
| **AT-64** | `toc-file-§5` | MUST | Low | `AbsorbTracker.toc:47` — `core\PerfSetup.lua` — is a **load-bearing** position carrying no comment. Three files take `NS.Perf` as a file-scope upvalue: `core/AbsorbTracker.lua:7`, `modules/Display.lua:8`, `modules/Timer.lua:9`, and the first of those is inside the same `# Core` block at `:52`. Each of the three says so **in its own source comment** — *"PerfSetup loads earlier in the TOC, so this is never nil"* — which is the reason recorded everywhere except the one place `toc-file-§5` requires it. The standard's own reference block shows this exact line annotated. Filed as its own row because §5's grading says one MUST row **per position**. | Add at the line: `# LOAD-BEARING: publishes NS.Perf, which core/AbsorbTracker.lua, modules/Display.lua and modules/Timer.lua take as a file-scope upvalue (performance-§1).` |
| **AT-65** | `toc-file-§5` | MUST | Low | `AbsorbTracker.toc:49` — `core\Units.lua` — is a **load-bearing** position carrying no comment. `core/Database.lua:30` resolves `local deepcopy = NS.Units.DeepCopy` at file scope, and `core/Units.lua:14` publishes `NS.Units`. Both files sit in the same `# Core` block, one line apart. As with `AT-64` the constraint is written down in the consumer — `core/Database.lua:26-27` says *"which the TOC loads immediately before this file"* — and not at the TOC line, which is where the next person moving a line will be looking. | Add at the line: `# LOAD-BEARING: publishes NS.Units, whose DeepCopy core/Database.lua takes as a file-scope upvalue at load.` |
| **AT-66** | `localization-§5` | MUST | Low | The US-spelling gate carries a **private list** where v2.39.0 publishes a canonical one. `tests/test_docs.lua:192` declares a 244-entry whole-word `BRITISH` map, read at `:349`, in place of `localization-§5`'s published `BRITISH` (91 lowercase substrings, matched case-insensitively) and `ALLOWED` (30 whole words removed before the scan). §5 names this repo's map by name and MUSTs that a gate use both lists **whole**. Measured: **22 of the 91** canonical substrings are covered by no key in the map — `armour, flavour, labour, rumour, humour, endeavour, rigour, vigour, saviour, theatre, manoeuvre, emphasis, cancelled, cancellable, levelled, levelling, fuelled, fuelling, totalled, totalling, analogue, enquir` — and there is **no `ALLOWED` list at all**. No unpublished entry is carried, which is the one half that is already right. Latent, not live: the one `cancelled` in this tree is quoted external text at `docs/smoke-tests.md:247`, an explicit §5 exception. But `cancelled` is precisely the word §5 records shipping green under a private list elsewhere. | Replace both tables with §5's published `BRITISH` and `ALLOWED`, copied whole, and switch the scan to §5's shape: delimit on non-letters, drop `ALLOWED` tokens as **whole words**, then run the `BRITISH` substrings over what remains. While there, name the four exclusions file-by-file in the gate rather than leaving frozen bundles excluded by an un-stated glob. |
| **AT-67** | `testing-§8` | MUST | Low | No **stub-surface parity case** for the `LibKa0s-Perf-1.0` stub. `testing-§8` MUSTs one *per adopted LibKa0s module*; `tests/test_surface_parity.lua` carries four (Core `:47`, DebugLog `:71`, Options `:97`, Slash `:161`) and its header states the addon adopts four seams. It adopts **seven**, and `core/PerfSetup.lua:22` publishes a real stub table with a real member set — `on`, `suspended`, `Note`, `OnCommand` — which is exactly the shape that drifts. It happens to be complete today (grep of the call sites returns those four and nothing else), so this is a missing gate rather than a live gap. `Env` and `Media` are **not** in scope: neither publishes a stub table, their seams are the addon's own nil-guarded functions, and there is no member set that can diverge. | Add a fifth case naming the grep that produces the list — `grep -rno "Perf\.[A-Za-z_]*" core/ modules/ settings/` — and assert it on both arms through `T.assertSurfaceParity`, with the degraded arm from `tests/degraded_env.lua` as the other four do. Correct the file header's *"four LibKa0s seams"* to five in the same change. |
| **AT-68** | `documentation-§3` · `audit-review-history` | SHOULD | Low | A register row's own evidence has gone stale, **inside this cycle**. `docs/ARCHITECTURE.md:335`'s `events-frames-taint-§8` row states *"The two sites that DO read `UnitGetTotalAbsorbs` (`core/AbsorbTracker.lua:168`, `:231`) …"*. Those sites are at `:171` and `:234` today; `:168` is a function header and `:231` is a `SendMessage`. The pair was correct at `7646029`, moved to `:167`/`:230` at `b55f9ec` (`M4-08`) and to `:171`/`:234` at `55dad52` — the commit titled *"M5-05: the comments name symbols, and stop naming lines that moved"*, which did that for source comments and not for the register. Graded SHOULD deliberately: `audit-review-history`'s resolve-every-citation MUST enumerates **ids** — audit, review, bundle date, issue number — and all of this row's ids resolve. A `file:line` is not in that enumeration, so the literal MUST is met and what fails is the purpose behind it. | Do to the register what `M5-05` did to the comments: name the two symbols (`addon:OnAbsorbChanged` and `addon:OnLeaveCombat`) instead of two line numbers. Line numbers in a register that outlives many refactors are a citation with a half-life. Worth a `test_docs.lua` case only if the symbols form proves insufficient. |

## Dependents

| ID | Derived from | Section | Rule strength | Sev | Deviation |
|---|---|---|---|---|---|
| **AT-63** | `AT-62` | `options-ui-§1` | MUST | Low | The suite pins schema **equality** across the two arms where v2.39.0 requires it to pin the **gap**. `tests/test_perf.lua:498` asserts `assertEqual(#NS2.Schema, #NS.Schema, …)` over a library-absent load, and `tests/test_optionssetup.lua:112` asserts `assertEqual(#rows, 4, "the canonical border block is four rows")` under a comment reading *"red under: a stub composer returning `{}`"* — i.e. the case is written to fail on the shape the standard now mandates. §1 asks for three figures: the fully-loaded count, the library-absent count, and the difference as a **named figure attributed to the composers it belongs to**. Does **not** graduate: same Low grade, no independent user reach, and it disappears the moment `AT-62` is closed — the two must be one change or the tree goes red between them. |

## Recorded deviations — accepted, not re-filed

Four rows, all read before anything was filed, and each checked three ways per `audit-review-history`
(rule still says what the row claims · trigger not yet fired · every cited id resolves).

| Rule | Register row | Decided | Status this run |
|---|---|---|---|
| `events-frames-taint-§1` | Per-unit `CreateFrame` + `RegisterUnitEvent` instead of AceEvent | 2026-07-14 | **Accepted.** `events-frames-taint` was not amended in v2.39.0. Trigger — a client accepting more than two unit tokens — has not fired. `AT-31` resolves in `docs/audits/2026-08-05/`. |
| `savedvariables-§1` | Per-profile `schemaVersion` alongside the account-wide stamp | 2026-07-28 | **Accepted.** `savedvariables` not amended. Trigger has not fired: the per-profile lift is live at `core/Database.lua:59`/`:87`. |
| `events-frames-taint-§8` (SHOULD half) | 18 pre-formatted chat lines, none in the trigger set | 2026-08-05 | **Accepted.** Re-counted: still 18, and none reads a §8-named API. §8's trigger set is unchanged. `AT-35` resolves. Two `file:line` citations in the row's *Why* have gone stale — filed as `AT-68`, which is about the citation and not about the decision. |
| `localization-§1` | English only; `NS.L` seam exported, `locales/enUS.lua` ships | 2026-08-05 | **Accepted.** `localization-§3` still names this one of the routing SHOULD's two terminal compliant states in v2.39.0. Trigger has not fired: `locales/` holds `enUS.lua` alone. `AT-30` and issue #24 both resolve. |

**No register row cites a rule the standard has since changed**, and no row's trigger has fired.

**The inverse rule was run, and it files nothing.** Seven issues are closed `state:will-not-do`
(#16, #21, #22, #23, #26, #27, #28) and none has a register row, correctly: none of them declines a
rule of this standard. #16 declines a feature request; #21 declines editing a frozen review bundle,
which `audit-review-history` **mandates** leaving alone; #22 declines an investigation into other
authors' addons; #23 declines `RenderGrid` on the landing page's command list, where
`options-ui-§5` **mandates** one Label per `COMMANDS` row; #26/#27/#28 decline three `LibKa0s`
modules, and `library-stack-§7` makes adoption per module and on the addon's own schedule. A row for
any of these would put compliance in the deviation register, which `documentation-§3` forbids.

## Checked and compliant (no entry filed)

- **Vendored-payload drift** — `diff -r` against the sibling checkout at tag `v1.27.0` is **empty**
  for both `LibKa0s/` (whole ship folder, 14 files) and `testkit/` → `tests/_kit/`.
- **Line endings** — `.gitattributes` body diffs empty against the canonical client-bound file and
  carries no appendix; the working-tree check returns **0**; the `line-endings-§7` gate
  `tests/_kit/test_eol.lua` is present at kit revision 15 and green. *`AT-57` closed.*
- **Packaging** — enumerating every root dot-entry against `.pkgmeta` leaves only `.git`, the one
  entry that never needs a row. *`AT-51` closed.*
- **`documentation-§3`'s fourth table** — `### Verification and record` is present at
  `docs/ARCHITECTURE.md:311` with exactly the mandated six rows, in the mandated position, and no
  note justifying it against the retired three-table MUST. `perf-analysis/README.md` registers in
  `### Conditional`, which is where the trigger puts it. `ARCHITECTURE.md`'s own self-row is absent,
  and `documentation-§3` makes that a **MAY** an audit MUST NOT file in either direction.
  `### Addon-specific` is absent because no Tier 3 doc exists; the MUST is that every `.md` sits in
  exactly one table, and 16 files map to 16 rows.
- **`library-stack-§9` / anti-pattern #76** — `core/LSMPatch.lua` is gone; the one process-global
  widget re-registration is the library's own `lib.__PatchLSM30Border()` at
  `settings/OptionsSetup.lua:397`.
- **`lint`** — `exclude_files` is byte-for-byte the v2.39.0 template's; the harness global sits in a
  `files["tests/"]` stanza and **not** in top-level `read_globals`; there is no top-level `ignore`,
  and the three per-file stanzas each name one file and one code/variable pair.
- **Close-button wrapper** — one wrapper at `core/CoreSetup.lua:123`; the playbook's grep finds no
  bypass. The addon draws no window of its own, so `standalone-windows`' decline conditions do not
  arise.
- **Perf panel `decorate` hook** — deleted, with the reason recorded at `core/PerfSetup.lua:137`.
  *`AT-56` closed.*
- **Shared media** — `media/` holds only `logos/` and `screenshots/`; no private `fonts/`, `icons/`
  or `textures/`; no one-off marks; `core/MediaSetup.lua` is fed the addon's own vararg.
- **`options-ui` (a)–(i)** — tab strips on both flow-rendered pages, the two exempt pages correctly
  exempt; `Master controls` first on General, composed not typed, `frameless = false` stated; every
  color row has its companion; no `disabledIf` on a color row; no reorder arrows; no hand-written
  font/border/bar group; one chrome block per page, unboxed. The one failure is the stub, `AT-62`.
- **`docs/settings-panel.md`** — its page → tab tree is what the schema produces, including the
  `skipRender` `Link` row that correctly draws no tab.
- **README/`CLAUDE.md`** — bare standard badge, no bundled-library inventory, provenance line in
  `CLAUDE.md` and not `README.md`, slash table in lockstep with all 17 verbs, `[tests]` badge at
  562/562 agreeing with `docs/test-cases.md`.
- **Complexity watch list** — two entries, both `Accepted`, both with dated reasoning and a stated
  peel threshold; `### Functions lizard warned on` reads *None.* Anti-pattern #53's shelf life is
  three consecutive **release** runs, and every `manifest.json` in the store carries
  `"release": null`, so the count has not started.
- **Issue store** — labels carry status and severity; no `[status]` title prefix; no issue without a
  `state:` label; no `docs/pending/LEDGER.md`.
- **`docs/` freshness gates** — `docs/test-cases.md` is current at HEAD (562) and the README badge
  agrees.

## Info

| ID | Note |
|---|---|
| **AT-Info-1** | *Recurs.* `docs/ARCHITECTURE.md` is **454 lines**, past `documentation-§3`'s *"SHOULD stay under roughly 400"*. Reported as shape, not arithmetic, and filing nothing: all four spillable mandated sections are well under 60 lines (Module Map 49, Settings Schema 34, Message Bus 48, Slash Commands 17), and the excess is the `## Documented deviations` register and its long-form arguments, which the standard makes this file's single home. |
| **AT-Info-2** | Issue [#25](https://github.com/tusharsaxena/AbsorbTracker/issues/25) is still open at `state:triaged` over five vendored `libs/LibStub/` files the TOC never loads. `find libs/LibStub -type f` now returns `libs/LibStub/LibStub.lua` alone — the condition the issue describes is gone. Not a standards deviation; the issue store is a working queue and closing a resolved item is housekeeping. *`AT-58` closed.* |
| **AT-Info-3** | The newest run bundle `docs/automated-tests/20260908-180922/` was taken at `697dc55`, four commits before HEAD, so its figures trail the tree: NLOC 9043 → 9247, functions 1261 → 1267, tests 557 → 562, lint files 53 → 54 (`tests/test_lintconfig.lua`, added by `M4c-06`). `automated-tests`' checkpoint is **release, not commit**, no release has been cut, and the collection's own execution record calls this out in eight repos. `RESULTS.md`'s narrative sections all match the run they name. Nothing to fix by hand. *`AT-53`, `AT-55` and `AT-61` closed.* |
