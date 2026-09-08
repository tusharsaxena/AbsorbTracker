# 03 — Evidence

Every `file:line` below was **re-read at the commit audited** (`a5a68ba`) and the cited text is
quoted beside it. Every count is the output of a recorded command, printed with the **scope** it
covered and excluded. Nothing here is carried over from an earlier bundle; where an earlier bundle's
number differs, the difference is explained rather than left to sit beside it.

---

## 0. Resolving the standard

```
$ curl -fsSL https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/standards/STANDARDS.md -o STANDARDS.md
$ head -1 STANDARDS.md
# Ka0s WoW Addon Standard (v2.39.0, 2026-09-07)
```

The **Sections** list at `STANDARDS.md:50-84` was parsed and every linked file fetched from
`$RAW/standards/standards/<file>.md`. Twenty-six files, all 200 OK:

```
layout toc-file library-stack architecture savedvariables options-ui standalone-windows
preview-mode slash-commands localization events-frames-taint public-api compat debug-logging
packaging line-endings lint testing performance automated-tests documentation
audit-review-history versioning-git naming-cheatsheet anti-patterns open-evolutions
```

`AUDIT.md` and `standards/ADDONS.md` were fetched the same way. No section filename was hard-coded;
all were discovered by following the Sections links.

---

## 1. The gate commands

**`luacheck .`** — scope: the whole repo minus `.luacheckrc`'s `exclude_files = { "libs/",
"docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`. The **test tree is in scope**, which is
the v2.39.0 `lint` shape.

```
$ luacheck .
…
Total: 0 warnings / 0 errors in 54 files
```

**54**, not the 53 the newest run bundle records: `tests/test_lintconfig.lua` was added by `M4c-06`
after that run. Verified:

```
$ diff <(git ls-tree -r --name-only 697dc55 | grep '\.lua$') <(git ls-tree -r --name-only HEAD | grep '\.lua$')
99a100
> tests/test_lintconfig.lua
```

**`lua tests/run.lua`** — the whole headless suite.

```
$ lua tests/run.lua | tail -3
  PASS  lintconfig: no source file carries a bare inline luacheck ignore
  PASS  eol: every tracked file carries the terminator .gitattributes declares for it

562 passed, 0 failed, 0 skipped, 562 total
```

`0 skipped` matters twice: it is the field `AT-55` asked the kit for, and it means both
vendored-payload cases resolved the sibling checkout rather than skipping.

---

## 2. Vendored-payload drift (`library-stack-§7`, anti-patterns #45/#48)

Diffed against **the tag the addon names**, not the sibling's `HEAD`:

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.27.0 (MIT).

$ grep -n 'Bundles \[LibKa0s\]' README.md          # expect none
(no output)

$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md
(no output)

$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

The badge is the **bare** image form, not `[![Standard](…)](…)`. `README.md`'s intro prose was read
in full: it names no library.

```
$ git -C ../LibKa0s archive v1.27.0 | tar -x -C $TMP
$ diff -r $TMP/LibKa0s     ./libs/LibKa0s
$ diff -r $TMP/testkit     ./tests/_kit
```

**Both empty.** Scope: whole folders, every module and every file, not only the wired ones. The
harness lands under `tests/_kit/` and not `libs/`, as `library-stack-§7` requires.

Payload completeness:

```
$ grep -c '<Script' libs/LibKa0s/LibKa0s.xml   → 14
$ ls libs/LibKa0s/*.lua | wc -l                → 14
$ grep -n -i 'libka0s' AbsorbTracker.toc
27:libs\LibKa0s\LibKa0s.xml
```

One aggregate XML, listed once, after Ace3. No individual module `.lua` in the TOC.

---

## 3. Line-ending policy (`line-endings`) — five checks, run

```
$ test -f .gitattributes && echo present              → present
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes
26:* text=auto eol=crlf
$ grep -n '^\*\.sh text eol=lf$' .gitattributes
34:*.sh text eol=lf
$ grep -c ' binary$' .gitattributes                   → 20
$ wc -l .gitattributes                                → 81
```

The repo ships Lua to the client, so `crlf` is the correct kind. **§5 body diff** — three lines
exactly as §5 specifies, over the first 81 lines, CR-stripped for comparison:

```
$ diff <(head -n 81 .gitattributes | tr -d '\r') <canonical-client-bound>
(empty)
$ tail -n +82 .gitattributes | tr -d '\r' | grep -m1 .
(nothing)
```

Body is byte-canonical and there is **no appendix** — and none is owed: no extension-less binary is
vendored.

**(e), the working tree, run verbatim from `AUDIT.md`:**

```
$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
0
```

Scope: **every tracked file**, `libs/` and `docs/` included, binaries skipped by the `text=unset`
test as the command intends. `docs/audits/2026-09-07/` reported **2** here; that bundle is frozen and
is not edited — the two stragglers were renormalized by `M4-10`, and this run re-measured rather than
re-typed.

**The gate has an owner.** `line-endings-§7` MUSTs the vendored `tests/_kit/test_eol.lua` (kit
revision 15). It is present, and the suite prints `PASS  eol: every tracked file carries the
terminator .gitattributes declares for it`. Gate green **and** audit count 0 — no gate finding.

---

## 4. Packaging (`packaging`) — the enumeration, not the named list

```
$ for e in .luacheckrc .pkgmeta .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
(no output)

$ for e in .[!.]*; do [ -e "$e" ] || continue
    grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .git
```

`.git` is the one entry the packager never sees. Re-read, quoted:

- `.pkgmeta:20` — `  - .claude          # untracked; listed under packaging.md:28`
- `.pkgmeta:21` — `  - .superpowers     # untracked; listed under packaging.md:28`
- `.pkgmeta:26` — `  - media/screenshots`

`.pkgmeta:12` ignores `.pkgmeta` itself, which is the self-reference v2.39.0 added to the template.
**`AT-51` is closed.**

---

## 5. Complexity (`performance-§10`, `automated-tests`) — measured, verbatim invocation

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
…
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
      9247       6.6     1.7       46.9     1267            0      0.00    0.00
```

Highest CCN functions today:

```
      36     15    249      0      43 NS.ValidateSchema@243-285@./settings/Schema.lua
      18     14    152      0      22 addon@167-188@./core/AbsorbTracker.lua
      10     14    154      3      12 NS.ResolveColor@53-64@./core/CoreSetup.lua
      26     12    177      1      65 build@16-80@./settings/Profiles.lua
```

All three at 14–15 are dense **defaulting/guarding**, not tangled control flow: `NS.ResolveColor` is
a run of `stored.r or 1`-shaped defaults, each of which `lizard` counts as a decision
(`performance-§10`).

**Drift against the recorded run.** `docs/automated-tests/20260908-180922/complexity.txt` tail reads
`9043 … 1261 … 0` and `manifest.json` records `"maxCcn": 15, "warnings": 0, "bandFiles": 2,
"overCapFiles": 0`, at `"sha": "697dc55…"`. Against today: NLOC 9043 → 9247, functions 1261 → 1267,
max CCN 15 → 15, warned 0 → 0, band files 2 → 2. **Nothing crossed a threshold and no file entered
or left the LOC band since that run.** The run's stamp is `2026-09-08T18:09:22+05:30`, three hours
and four commits old — `automated-tests`' checkpoint is **release**, and no release has been cut.

The band figures reproduce exactly:

```
$ git ls-files '*.lua' | grep -v '^libs/' | grep -v '^tests/_kit/' | xargs wc -l | sort -rn | head -3
  1296 tests/test_slashcmds.lua
  1171 tests/test_helpers.lua
   904 tests/test_widgets.lua
```

matching `docs/automated-tests/RESULTS.md:81` (`1171`) and `:82` (`1296`).

**Watch list read as a decision record.** `### Functions lizard warned on` reads *None.* Two band
rows, both `Accepted`, both dated and both carrying a peel threshold at 1400. Anti-pattern #53's
shelf life is three consecutive **release** runs:

```
$ git log --oneline -6 -- docs/automated-tests/RESULTS.md
e758433 M5-01: the record is regenerated, and the watch list has a producer at last
16bc027 automated-tests: record run 20260825-103352 — green on the fast gate
1064526 docs(perf): replace the flat perf-runs store with dated capture bundles
…
$ grep -o '"release": null' docs/automated-tests/*/manifest.json | wc -l   → 8 of 8
```

Every bundle in the store carries `"release": null`, so no entry has spent a release cycle as
accepted and the count has not started. No #53 finding.

`docs/complexity.md` does not exist (retired v2.19.0), `docs/perf-runs/` does not exist (retired
v2.29.0), `docs/automated-tests/{README.md,RESULTS.md}` both exist, and
`tests/_kit/run-automated-tests.sh` is vendored and executable.

---

## 6. The deviation register, read before anything was filed

`docs/ARCHITECTURE.md:323` — `## Documented deviations`. Header row at `:331`, four rows at
`:333-336`.

**Rule-still-says-what-the-row-claims.** v2.39.0's changelog names the fifteen amended sections;
`events-frames-taint`, `savedvariables` and `localization-§1`/`§3` are not among the edits that touch
these rows. Re-read of `localization-§3` in the fetched v2.39.0 text confirms both terminal compliant
states survive verbatim, English-only-recorded included.

**Every cited id resolves.**

```
$ sed -n '323,356p' docs/ARCHITECTURE.md | grep -oE 'AT-[A-Z0-9-]+' | sort -u
AT-30
AT-31
AT-35
$ for id in AT-30 AT-31 AT-35; do grep -c "\*\*$id\*\*" docs/audits/2026-08-05/02_DEVIATIONS.md; done
1
1
1
$ grep -rn 'AT-A-' docs/ARCHITECTURE.md      → (no output)
```

**`AT-59` is closed** — the three `AT-A-*` phantoms are gone, and `tests/test_docs.lua` now carries
`PASS  every deviation id the register cites is assigned by a bundle in docs/audits/`. Issue #24,
cited by the `localization-§1` row, resolves to a CLOSED `state:done` issue on this repo.

**Every trigger evaluated against the tree.**

- `events-frames-taint-§1` — *"A client build where `RegisterUnitEvent` accepts more than two unit
  tokens"*: not fired.
- `savedvariables-§1` — *"AceDB gaining a per-profile version stamp of its own, or the last
  per-profile migration being retired"*: not fired. `core/Database.lua:59` reads
  `if (profile.schemaVersion or 1) >= 3 then return false end` and `:87` writes
  `profile.schemaVersion = 3`, so the per-profile lift is live.
- `events-frames-taint-§8` — *"Any of these lines gaining an argument that … derives from a return
  value of one of §8's named APIs"*: not fired. Scope of the count — `settings/Slash.lua` and
  `settings/Schema.lua`, the two files the row names:

  ```
  $ grep -nE 'print\((\(|"[^"]*" *\.\.|.*\):format)' settings/Slash.lua settings/Schema.lua | wc -l
  18
  $ grep -nE 'UnitGetTotalAbsorbs|UnitHealth|GetThreat|AuraUtil' settings/Slash.lua settings/Schema.lua
  (no output)
  ```

  Still 18, and none of the 18 can reach a §8-named API.
- `localization-§1` — *"The first non-English locale file added to `locales/`"*: not fired.
  `ls locales/` → `enUS.lua`.

**The one thing the row's evidence gets wrong** — `AT-68`. Re-read, quoted:

```
$ sed -n '171p;234p' core/AbsorbTracker.lua
            local v = UnitGetTotalAbsorbs("player") or 0
            local v = UnitGetTotalAbsorbs("player") or 0
$ sed -n '168p;231p' core/AbsorbTracker.lua
function addon:OnAbsorbChanged(_, unit)
    NS.bus:SendMessage(NS.MSG.VISIBILITY)
```

The register at `:335` says `:168` and `:231`. When it broke:

```
$ for c in HEAD 55dad52 b55f9ec 7646029; do printf '%s: ' "$c"
    git show "$c":"core/AbsorbTracker.lua" | grep -n 'UnitGetTotalAbsorbs' | cut -d: -f1 | paste -sd, -; done
HEAD:     163,171,234
55dad52:  163,171,234
b55f9ec:  159,167,230
7646029:  160,168,231
```

Correct at `7646029`, off by one at `b55f9ec` (`M4-08`), off by three at `55dad52` — the `M5-05`
commit whose subject is *"the comments name symbols, and stop naming lines that moved."*

**The inverse rule.** Every closed `state:will-not-do` issue was read:

```
$ gh issue list --state all --limit 200 --json number,title,state,labels \
    --jq '.[] | "\(.number)\t\(.state)\t[\(.labels|map(.name)|join(","))]\t\(.title)"'
```

28 issues, 11 open and 17 closed; seven carry `state:will-not-do` (#16, #21, #22, #23, #26, #27,
#28). Bodies read individually. None declines a rule of this standard — #21 declines editing a
frozen bundle, which `audit-review-history` mandates; #23 declines `RenderGrid` on the landing page's
command list, which `options-ui-§5` mandates as one Label per `COMMANDS` row; #26/#27/#28 decline
three LibKa0s modules, and `library-stack-§7` states *"Adoption is per module, on the addon's own
schedule."* So no missing register row is owed. Every issue carries a `state:` label, none carries a
`[status]` title prefix, and `docs/pending/LEDGER.md` does not exist.

---

## 7. `AT-62` / `AT-63` — the Options stub's composers

Re-read, quoted:

- `settings/OptionsSetup.lua:45` — `local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)`
- `settings/OptionsSetup.lua:166` — `if not lib then`
- `settings/OptionsSetup.lua:194` — `    local function composeBlock(leaves, spec)`
- `settings/OptionsSetup.lua:225` — `    Helpers.ColorPair = function(spec)`
- `settings/OptionsSetup.lua:236` — `    Helpers.FontGroup = function(spec)`
- `settings/OptionsSetup.lua:247` — `    Helpers.BorderGroup = function(spec)`
- `settings/OptionsSetup.lua:261` — `    Helpers.BarGroup = function(spec)`
- `settings/OptionsSetup.lua:276` — `    Helpers.MasterControls = function(spec)`
- `settings/OptionsSetup.lua:404` — `NS.Helpers = lib:New(descriptor)` (the live arm)

Each stub composer returns a populated block: `BorderGroup` emits four leaves (`borderStyle`,
`borderSize`, `borderColor`, `useClassColorBorder`), `MasterControls` emits six
(`enabled`, `visibility`, `scale`, `alpha`, `locked`, `debugConsole`). The v2.39.0 rule, from the
fetched `standards/standards/options-ui.md`:

> The stub's composer members **MUST** exist and **MUST** answer an **empty row list**. … A **hollow**
> composer is compliant. A host copy of a composed block inside the stub is **anti-pattern #73** and
> is not, and no addon may close the gap locally by writing one.

The exemption's precondition — the fall-together property — **holds**, which is what makes the hollow
form available here rather than something the addon has to earn: `tests/test_perf.lua:521` is
`test("perf: /at perf explains itself instead of erroring with LibKa0s absent", …)` and the degraded
Slash arm answers every schema verb *"unavailable"*, so no composed row is addressable-but-missing.

The suite half (`AT-63`), re-read and quoted:

- `tests/test_perf.lua:498` — `  assertEqual(#NS2.Schema, #NS.Schema,`
- `tests/test_optionssetup.lua:112` — `  assertEqual(#rows, 4, "the canonical border block is four rows")`

and the comment two lines above the second, `tests/test_optionssetup.lua:102`: *"red under: a stub
composer returning `{}`, or one that stops honoring `keys`."* The case is written to fail on the
shape the standard now mandates, which is why the two must move together.

---

## 8. `AT-64` / `AT-65` — the TOC's load-bearing denominator

The denominator was established by reading the seam files, not by counting TOC lines. Publishers and
their **file-scope** consumers:

```
$ grep -rn '^local .*=.*NS\.' core/ modules/ settings/ defaults/
core/AbsorbTracker.lua:7:local Perf = NS.Perf
core/Database.lua:30:local deepcopy = NS.Units.DeepCopy
core/Data.lua:11:local C = NS.Constants
modules/Display.lua:8:local Perf = NS.Perf
modules/Timer.lua:9:local Perf = NS.Perf
modules/Bar.lua:9:local C = NS.Constants
…
$ grep -rn '^\s*NS\.\(Perf\|Units\|Constants\)\s*=' core/
core/PerfSetup.lua:33:NS.Perf = lib:New({
core/Units.lua:14:NS.Units = Units
core/Constants.lua:2:NS.Constants = NS.Constants or {}
```

Four load-bearing positions inside the `# Core` block. Re-read of the TOC, quoted:

- `AbsorbTracker.toc:41` — `core\MediaSetup.lua` — **annotated** at `:39-40`: *"Before Constants,
  deliberately: Constants.FONT_MONO is resolved from the NS.MediaFont seam this file publishes …"*
- `AbsorbTracker.toc:42` — `core\Constants.lua` — carries nothing, and `toc-file-§5` names this file
  in this TOC as **compliant**: *"its position is already pinned by the annotated line above it."*
  Not filed, on the standard's own ruling.
- `AbsorbTracker.toc:47` — `core\PerfSetup.lua` — **no comment**. `AT-64`.
- `AbsorbTracker.toc:49` — `core\Units.lua` — **no comment**. `AT-65`.

The constraints exist in the consumers instead. Quoted:

- `core/AbsorbTracker.lua:6` — *"PerfSetup loads earlier in the TOC, so this is never nil."*
- `modules/Display.lua:7` — *"PerfSetup loads before this file (see the TOC), so it is never nil."*
- `core/Database.lua:26-27` — *"There is exactly ONE implementation, `core/Units.lua`'s, which the
  TOC loads immediately before this file."*

`AbsorbTracker.toc:36-38` satisfies the **SHOULD** for the group by marking `core\EnvSetup.lua`
conventional with its reason, so no separate SHOULD row is filed.

---

## 9. `AT-66` — the US-spelling gate against `localization-§5`'s published lists

Scope: `tests/test_docs.lua`'s `BRITISH` table (`:192`, read at `:349`) against the `BRITISH` and
`ALLOWED` blocks published in the fetched `standards/standards/localization.md` §5. The comparison
asks two questions — is every canonical substring covered by some key, and does any key match no
canonical substring:

```
canonical BRITISH entries: 91
addon gate keys: 244

canonical substrings NO addon key covers (22):
  armour, flavour, labour, rumour, humour, endeavour, rigour, vigour, saviour,
  theatre, manoeuvre, emphasis, cancelled, cancellable, levelled, levelling,
  fuelled, fuelling, totalled, totalling, analogue, enquir

addon keys matching NO canonical substring (0):
  (none)

addon gate has an ALLOWED list: false
```

Re-read, quoted:

- `tests/test_docs.lua:192` — `local BRITISH = {`
- `tests/test_docs.lua:338` — `test("the addon's own files use US spellings", function()`
- `tests/test_docs.lua:349` — `        local us = BRITISH[word:lower()]` — whole-word map lookup,
  where §5 specifies `ALLOWED`-removal followed by a **substring** scan.

Is any of the 22 live in this tree? Scope of the sweep: the gate's own `ownFiles()` set — `*.md`,
`*.toc`, `docs/*.md`, `docs/perf-analysis/*.md`, and `core/ settings/ modules/ defaults/ locales/
tests/*.lua` — excluding `libs/`, `tests/_kit/`, `docs/test-cases.md`, `tests/test_docs.lua` and
every frozen dated bundle (`docs/audits/`, `docs/reviews/`, `docs/automated-tests/<run>/`,
`docs/superpowers/`, `docs/investigations/`, `docs/revendor/`).

```
HIT [cancelled]: docs/smoke-tests.md
```

One hit, and it is compliant. `docs/smoke-tests.md:247` reads: *"`CANCELLED` and three `unlabelled`
become `CANCELED` and `unlabeled` — and no single capture shows"* — quoted external text describing
the library's old strings, an explicit §5 exception. So the gap is **latent**, and `cancelled` is
precisely the word §5 records shipping green under a private list in another repo.

---

## 10. `AT-67` — the missing Perf parity case

`tests/test_surface_parity.lua:1-3`, quoted:

> `-- tests/test_surface_parity.lua — every degradation stub carries the whole live surface.`
> …
> `-- The addon adopts four LibKa0s seams — Core, DebugLog, Options and Slash — and each of the four`

It adopts seven:

```
$ grep -rn '^local .*LibStub("LibKa0s' core/ settings/
core/DebugLogSetup.lua:14:local lib = LibStub and LibStub("LibKa0s-DebugLog-1.0", true)
core/EnvSetup.lua:54:local Env = LibStub and LibStub("LibKa0s-Env-1.0", true)
core/CoreSetup.lua:25:local lib = LibStub and LibStub("LibKa0s-Core-1.0", true)
core/MediaSetup.lua:82:local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)
core/PerfSetup.lua:14:local lib = LibStub and LibStub("LibKa0s-Perf-1.0", true)
settings/OptionsSetup.lua:45:local lib = LibStub and LibStub("LibKa0s-Options-1.0", true)
settings/Schema.lua:198:local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
settings/Slash.lua:24:local SlashLib = LibStub and LibStub("LibKa0s-Slash-1.0", true)
```

Eight lines, **seven distinct majors** — `LibKa0s-Slash-1.0` is resolved twice. `settings/Slash.lua:24`
is the dispatcher's; `settings/Schema.lua:198` resolves the same major for one library-table member,
`settings/Schema.lua:206` — `    if SlashLib then return SlashLib.FormatValue(row, v) end` — behind an
inline guard whose fallback `tests/test_schema.lua` pins on both arms. That is not a second
degradation stub and needs no second parity case.

Parity cases, re-read: `:47` Core, `:71` DebugLog, `:97` Options, `:161` Slash. Four. `Perf` publishes
a real stub table — `core/PerfSetup.lua:22`, `    NS.Perf = {` — and has none.

**The stub is complete today**, so this is a missing gate rather than a live gap. Scope of the grep:
the addon's own shipped source, `libs/` and `tests/` excluded:

```
$ grep -rno 'Perf\.[A-Za-z_]*' core/ modules/ settings/ defaults/ locales/ | awk -F: '{print $3}' | sort | uniq -c
      7 Perf.Note
      5 Perf.on
      4 Perf.suspended
      1 Perf.OnCommand
      1 Perf.lua      ← core/PerfSetup.lua:5, a path inside a comment, not a member
```

Four members reached; `core/PerfSetup.lua:22-29`'s stub answers `on`, `suspended`, `Note` and
`OnCommand`. `Env` and `Media` are out of scope for this MUST: neither publishes a stub table — their
seams are the addon's own functions with an internal nil-guard (`core/EnvSetup.lua:65-74`,
`core/MediaSetup.lua`) — so there is no member set that can diverge from a live surface.

---

## 11. `documentation-§3` — the tier model, measured as a listing

```
$ find docs -name '*.md' | grep -vE '^docs/(audits|reviews|superpowers|investigations|revendor)/' \
    | grep -vE '^docs/automated-tests/[0-9]{8}-[0-9]{6}/' \
    | grep -vE '^docs/perf-analysis/[0-9]{8}-[0-9]{6}/' | sort
docs/ARCHITECTURE.md
docs/automated-tests/README.md
docs/automated-tests/RESULTS.md
docs/common-tasks.md
docs/data-flow.md
docs/midnight-quirks.md
docs/module-map.md
docs/perf-analysis/README.md
docs/performance.md
docs/profiles.md
docs/schema.md
docs/scope.md
docs/settings-panel.md
docs/slash-dispatch.md
docs/smoke-tests.md
docs/test-cases.md
docs/testing.md
```

Sixteen files besides the hub; the map at `docs/ARCHITECTURE.md:283-322` carries **16 present rows**
plus three *Not applicable* rows (`message-bus.md`, `compat-layer.md`, `debug.md`). No orphan, no
dangling row.

**Tier 2 triggers evaluated against the code, not the row:**

- `slash-dispatch.md` — `settings/Slash.lua:60` is `NS.COMMANDS = {`; the table holds **17** verbs
  (`help config list get set reset resetall resetposition lock unlock toggle debug perf update
  version test profile`), and `profile` is a subtree — `settings/Slash.lua:327`
  `local PROFILE_VERBS = {`, dispatched at `:386` `    local handler = PROFILE_VERBS[sub]`. Trigger
  fired both ways; the doc exists; the row at `:303` says **Present**. **`AT-52` is closed.**
- `message-bus.md` — `core/Bus.lua:50` `NS.MSG = {` holds **5** messages against a threshold of more
  than ten. Row at `:306` — *Not applicable*, correct.
- `compat-layer.md` — v2.39.0 makes this a count: `grep -cE '^\s*function\s+[A-Za-z_][A-Za-z0-9_]*\.'
  core/Compat.lua`. The file does not exist, so the count is **0** against a threshold of 3. Row at
  `:307` — *Not applicable*, correct.
- `profiles.md`, `midnight-quirks.md`, `perf-analysis/README.md` — triggers fired, all three present.
- `debug.md` — the console is the library's and the addon ships no debug surface of its own.

**The fourth table.** `docs/ARCHITECTURE.md:311` is `### Verification and record`, placed after
`### Conditional`, holding exactly `testing.md`, `smoke-tests.md`, `test-cases.md`, `performance.md`,
`automated-tests/README.md`, `automated-tests/RESULTS.md` — six rows.
`grep -n 'three tables\|three-table\|fourth table' docs/ARCHITECTURE.md` returns nothing, so there is
no retired justification note to delete. `### Addon-specific` is absent and no Tier 3 doc exists.

**Hub shape.** 454 lines. Mandated section spans, from the heading line numbers: Overview 31, Module
Map 49, Invariants 18, Settings Schema 34, Message Bus 48, Slash Commands 17, Event Subscriptions 50,
Taint Notes 20, Known Limitations 9, Documentation map 40, Documented deviations 124. Every spillable
mandated section is well under 60; the excess is the register. Reported as shape (`AT-Info-1`), not
filed.

No `file-index.md`, no `conventions.md`, no `complexity.md`, no `docs/perf-runs/`, no
`docs/agent-context.md`, no `TODO.md`, no `CHANGELOG.md` at the root or under `docs/`.

---

## 12. `options-ui` (a)–(i) — the schema-side checks

- **(a)** Tab strips. General declares `Master controls` (composed, `settings/OptionsSetup.lua:274`
  `Helpers.MASTER_GROUP = "Master controls"`) and `Bars` (`settings/General.lua:198`, `:234`);
  Appearance declares `Size`, `Bar`, `Background`, `Border`, `Text` (`settings/Appearance.lua:127`,
  `:160`, `:181`, `:216`, `:236`). The landing page and the AceConfig-drawn Profiles page are the two
  `options-ui-§13` exemptions and declare no `group`, correctly. `settings/Appearance.lua:266`'s
  `group = "Link"` is a `skipRender` row and draws no tab by design, which is what
  `docs/settings-panel.md:62-67`'s tree shows.
- **(b)** `settings/General.lua:88` — `local masterRows, masterTail = H.MasterControls({` — composed,
  not typed, with `frameless = false` stated explicitly at `:95` so the four frame rows are not
  silently dropped. `modules/Bar.lua:35` `bar:SetMovable(true)` proves the frame is positionable, so
  the four are owed and present.
- **(c)/(d)** Every color row carries its companion in the next declaration slot
  (`settings/Appearance.lua:167`, `:196`, `:201`, `:224`, `:239`, `:244`).
  `grep -rn 'disabledIf' settings/` returns only three **comments** forbidding it
  (`settings/Appearance.lua:78`, `:91`, `settings/Schema.lua:44`) and no declaration.
- **(e)** `grep -rn 'ScrollUp-Up\|ScrollDown-Up\|MoveUp\|MoveDown' --include='*.lua' settings/` →
  no output.
- **(f)** One `LSM30_Statusbar` at `settings/Appearance.lua:187`, inside a composed bar group; the
  font, border and bar groups all come from `H.FontGroup`/`H.BorderGroup`/`H.BarGroup`. No
  hand-written block, and no broadcast meta row to bound.
- **(g)** One chrome block per page; the Appearance picker and the two page-wide mirror controls sit
  inside it, unboxed.
- **(h)** `tests/test_widgets.lua:810` — `  assertTrue(ctx.chromeHeight > 0, "the strip reserves a
  band, so the first row clears it")`. That is the whole of it: no case asserts band height or row y
  offsets are invariant under selection. **`AT-60`.** The 2026-09-07 bundle cited `:770` for the same
  line; that bundle is frozen and the line moved with the file, so this run re-read it rather than
  re-typing the number.
- **(i)** No secondary strip and no third level.

**`library-stack-§9`.** `grep -rn 'RegisterWidgetType' core/ modules/ settings/` → no output.
`core/LSMPatch.lua` does not exist. `settings/OptionsSetup.lua:397` — `lib.__PatchLSM30Border()` —
the library's own idempotent member.

---

## 13. Close button, media, perf hook

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
core/PerfSetup.lua:143:    -- earned its place once: it began as `NS.DebugLog.MakeCloseButton(frame, api.Hide)`, a
core/CoreSetup.lua:100:-- `lib.MakeCloseButton(parent, onClick, addonName)` takes THREE arguments, and the third is what lets
core/CoreSetup.lua:123:    return lib.MakeCloseButton(parent, onClick, addonName)
```

One wrapper definition at `core/CoreSetup.lua:123`, quoted above; the other two hits are prose. No
direct `lib.MakeCloseButton(...)` call site, no `NS.DebugLog.MakeCloseButton(...)`. The addon draws
no window of its own, so `standalone-windows`' four decline conditions do not arise.

`core/PerfSetup.lua:137` — `    -- NO 'decorate'. The descriptor deliberately ends here:
LibKa0s-Perf-1.0's panel draws its own`. **`AT-56` is closed.**

```
$ find media -type d
media
media/logos
media/screenshots
```

No private `fonts/`, `icons/` or `textures/` shadowing `libs/LibKa0s/media/`.

---

## 14. `AT-58` and issue #25 — condition gone, issue open

```
$ find libs/LibStub -type f
libs/LibStub/LibStub.lua
$ grep -n -i 'libstub' AbsorbTracker.toc
8:## OptionalDeps: Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0
17:libs\LibStub\LibStub.lua
```

The vendored copy is now exactly what the TOC loads. Issue #25 remains OPEN at `state:triaged`
describing five files that no longer exist — recorded as `AT-Info-2`, not a standards deviation.
