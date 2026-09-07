# 03 — Evidence

Every citation below was re-read at its stated line before being written here, and the cited text is
quoted beside it. Every count is produced by a recorded command whose **scope** is stated. Nothing is
re-typed from an earlier bundle or from memory.

**Scope of every sweep in this document unless a line says otherwise:** the repo root
`/mnt/d/.../AbsorbTracker`, at HEAD `686cae5`. `libs/` and `tests/_kit/` are vendored and are swept
only where a check is explicitly about them. Frozen bundles under `docs/audits/`, `docs/reviews/`,
`docs/automated-tests/<run>/`, `docs/revendor/` and `docs/perf-analysis/<run>/` are **not** counted as
live content; the live `docs/` pages **are**.

---

## 1. Gate commands

```
$ luacheck .
...
Checking settings/Schema.lua                      OK
Checking settings/Slash.lua                       OK
Checking settings/UnitPanel.lua                   OK

Total: 0 warnings / 0 errors in 27 files
```

```
$ lua tests/run.lua
...
  PASS  parity: the Core stub publishes everything core/CoreSetup.lua publishes live
  PASS  parity: the DebugLog stub carries the whole live surface
  PASS  parity: the Options stub carries every helper the degraded build can reach
  PASS  parity: the Slash stub carries every dispatcher member the addon calls
  PASS  libs/LibKa0s is the LibKa0s release CLAUDE.md says this addon bundles
  PASS  tests/_kit is the test kit that shipped with that release

547 passed, 0 failed, 0 skipped, 547 total
```

Scope: `luacheck` covers the 27 own-source runtime files (`.luacheckrc` excludes `libs/`, `tests/`,
`docs/audits/`, `docs/reviews/`, `_dev/`). The suite covers `tests/*.lua`, including both
vendored-payload gates, which **executed** rather than skipping.

`docs/test-cases.md` — the generated inventory — reports the same **547**, and `README.md:6-7`
carries `![Tests](https://img.shields.io/badge/Tests-547%2F547_passing-green)`. The three agree.

## 2. Vendored Ka0s-owned library — drift (compliance claim: no finding)

Provenance line, re-read:

```
$ grep -n 'Bundles \[LibKa0s\]' CLAUDE.md README.md
CLAUDE.md:69:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.25.0 (MIT).
```

One hit, in `CLAUDE.md`, naming `v1.25.0`. **No** hit in `README.md`. Two further greps:

```
$ grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md
(no output)
$ grep -n 'WoW_Addon_Standard' README.md
6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)
```

The badge is the **bare** `![Standard](…)` form, not wrapped in a link. The README intro prose was
read in full and carries no library roll-call, and there is no `## Credits` section.

Both diffs, against the tag `CLAUDE.md` names (not against the sibling's `HEAD`):

```
$ rm -rf /tmp/lk && mkdir -p /tmp/lk && git -C ../LibKa0s archive v1.25.0 | tar -x -C /tmp/lk
$ diff -r /tmp/lk/LibKa0s  ./libs/LibKa0s   && echo LIBKA0S_DIFF_EMPTY
LIBKA0S_DIFF_EMPTY
$ diff -r /tmp/lk/testkit  ./tests/_kit     && echo TESTKIT_DIFF_EMPTY
TESTKIT_DIFF_EMPTY
```

Sibling repo present at `/mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s`; `v1.25.0` is also its
newest tag (`git tag --list 'v*' --sort=-v:refname | head -3` → `v1.25.0 v1.24.0 v1.23.0`). Whole
ship folder, whole test kit, no drift, no partial vendoring. The kit sits under `tests/_kit/`, never
`libs/`.

## 3. `.pkgmeta` ignore list — AT-51

```
$ for e in .luacheckrc .gitignore .gitattributes .claude .superpowers docs tests _dev; do
    grep -q "^  - $e\b" .pkgmeta || echo "NOT IGNORED — $e"; done
NOT IGNORED — .claude
NOT IGNORED — .superpowers

$ for e in .[!.]*; do [ -e "$e" ] || continue;
    grep -q "^  - $e\b" .pkgmeta || echo "UNACCOUNTED — $e"; done
UNACCOUNTED — .claude
UNACCOUNTED — .git
UNACCOUNTED — .pkgmeta
UNACCOUNTED — .superpowers
```

`.git` is the entry the packager never sees. `.pkgmeta` naming itself is conventional. The two real
entries are `.claude` and `.superpowers`.

`.pkgmeta:5-8`, re-read verbatim:

```
ignore:
  - docs
  - tests
  - _dev
```

Size of what ships as a result (scope: repo root, excluding `.git`):

```
$ find .superpowers .claude -type f | wc -l
62
```

## 4. Line endings — AT-57

```
$ test -f .gitattributes && echo present
present
$ grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes
26:* text=auto eol=crlf
$ grep -n '^\*\.sh text eol=lf$' .gitattributes
34:*.sh text eol=lf
$ grep -c ' binary$' .gitattributes
20
```

The repo has a `.toc`, so it is client-bound and `eol=crlf` is the correct pin. The file body was
diffed by eye against `line-endings-§5`'s canonical client-bound file and matches, including the
renormalize note and the `tr -dc` byte-count instructions.

Working-tree agreement, the playbook's command **run as written**:

```
$ git ls-files -z | xargs -0 -I{} sh -c '
    set -- $(git check-attr text eol -- "{}" | sed "s/.*: //")
    [ "$1" = unset ] && exit
    cr=$(tr -dc "\r" < "{}" | wc -c); lf=$(tr -dc "\n" < "{}" | wc -c)
    case "$2" in crlf) [ "$lf" -gt 0 ] && [ "$cr" -ne "$lf" ] && echo "{}";;
                 lf)   [ "$cr" -gt 0 ] && echo "{}";; esac' 2>/dev/null | wc -l
2
```

Scope: every tracked file in the repo, binaries excluded by the `text unset` guard. **2** — reported
as one rolled-up finding, files deliberately not enumerated.

## 5. Complexity — measured, and the drift against the record (AT-53 / AT-61)

`lizard` is installed (`/home/tushar/.local/bin/lizard`). Standard invocation, verbatim:

```
$ lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
...
No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 or nloc > 1000000 or parameter_count > 100)
Total nloc   Avg.NLOC  AvgCCN  Avg.token   Fun Cnt  Warning cnt   Fun Rt   nloc Rt
      8903       6.5     1.7       46.3     1253            0      0.00    0.00
```

Functions at CCN ≥ 12 in own source today (same run, filtered):

```
      18     14    152      0      22 addon@164-185@./core/AbsorbTracker.lua
      10     14    154      3      12 NS.ResolveColor@53-64@./core/CoreSetup.lua
      26     12    179      1      56 build@16-71@./settings/Profiles.lua
      36     15    249      0      43 NS.ValidateSchema@257-299@./settings/Schema.lua
```

Latest committed bundle, `docs/automated-tests/20260825-103352/complexity.txt` (tail):

```
      7997       6.5     1.7       45.2     1126            0      0.00    0.00
```

and its `manifest.json`: `"run": "20260825-103352"`, `"startedAt": "2026-08-25T10:33:52+05:30"`,
`"release": null`, `"maxCcn": 14`, `"nloc": 7997`, `"functions": 1126`, `"bandFiles": 1`,
`"tests": { … "passed": 508, "failed": 0, "total": 508 … }`.

**Drift, 20260825-103352 → HEAD (13 days; `git log --oneline 16bc027..HEAD | wc -l` → **17** commits since, including the whole `feat/settings-revamp-v2` merge and the LibKa0s v1.25.0 carry):**
NLOC 7997 → 8903, functions 1126 → 1253, max CCN 14 → 15, warnings 0 → 0. No function crossed
`lizard`'s CCN-15 threshold. `NS.ValidateSchema` rose 14 → 15 (at the line, not over it);
`NS.ResolveColor` is new to the ≥ 12 set at 14. `tests/test_slashcmds.lua` measures **999** LOC in
today's run, down from the 1282 the band table records — it has left `layout-§1`'s 1000–1500 band, so
no file is in the band. The checkpoint is **release**, and no run in this repo is a release run
(`"release": null` in every manifest), so this drift is a fact about the *record's* currency, not a
failure to gate commits.

Watch-list dispositions and their shelf life:

```
$ git log --format='%h %ad %s' --date=short -- docs/automated-tests/RESULTS.md | head -3
16bc027 2026-08-25 automated-tests: record run 20260825-103352 — green on the fast gate
1064526 2026-08-07 docs(perf): replace the flat perf-runs store with dated capture bundles
2622af8 2026-08-07 automated-tests: record run 20260807-114413 — green
```

Three entries read **Accepted** (`addon:OnAbsorbChanged`, `NS.ValidateSchema`, `build`), one reads
*watch* (`Helpers.BuildMainContent`). `automated-tests-§4`'s clock counts **release** runs; there are
none, and the record says so explicitly. So no entry is stale under anti-pattern #53, and the list is
four rows — readable in one pass, not a backlog. Of the two figures reported above,
`NS.ResolveColor`'s CCN 14 is dense **defaulting** — `local r, g, b, a = stored.r or 1, stored.g or 1,
stored.b or 1, stored.a or 1` at `core/CoreSetup.lua:55`, four `or`s that `lizard` counts as four
decisions with no branching at all — not tangled control flow.

Also checked against `automated-tests`: `tests/_kit/run-automated-tests.sh` is present and executable
(`-rwxrwxrwx`); `docs/automated-tests/README.md` and `RESULTS.md` both exist; there is **no** retired
`docs/complexity.md` and **no** `docs/perf-runs/`.

## 6. `RESULTS.md` — AT-53, AT-55; bundle — AT-54

`docs/automated-tests/RESULTS.md:23`, re-read:

```
| [`20260825-103352`](20260825-103352/) | 1.9.0 | 0/0 | 29 | 508/508 | pass | 7997 | 1126 | 6.5 | 1.7 | 14 | 0 | **green** |
```

`docs/automated-tests/RESULTS.md:100`, re-read:

```
Current state as of [`20260807-114413`](20260807-114413/) — not that run's diff.
```

The `## Test suite`, `## Lint` and `## Perf` sections open the same way — "489 cases as of
[`20260807-114413`]", "Clean over 28 files as of [`20260807-114413`]", "Six scenarios as of
[`20260807-114413`]" — while the row above them reads 508 cases over 29 files.

The `tests` column carries `508/508`: passed and total, **no skipped figure**. The header is emitted
by the vendored kit, `tests/_kit/run-automated-tests.sh:391`, re-read:

```
    HEADER='| Run | Version | Lint w/e | Files | Tests | Perf | NLOC | Funcs | Avg NLOC | Avg CCN | Max CCN | CCN warn | Verdict |'
```

and the manifest writer at `:369` emits `", \"passed\": $TESTS_PASS, \"failed\": $TESTS_FAIL,
\"total\": $TESTS_TOTAL, $GATE_COMMIT"` — no `skipped`. `testing-§1` forbids editing the vendored
kit, so this is an upstream fix (AT-55).

Bundle contents (AT-54):

```
$ ls docs/automated-tests/20260825-103352/
complexity.txt  lint.txt  manifest.json  perf.json  perf.txt  test-cases.md  tests.txt
```

No `ANALYSIS.md`. Every one of the six earlier bundles has one.

## 7. Documentation shape

**(a) Tier 1 — all six present**, at exactly the canonical names:

```
$ ls docs/scope.md docs/module-map.md docs/schema.md docs/settings-panel.md docs/data-flow.md docs/common-tasks.md
docs/common-tasks.md  docs/data-flow.md  docs/module-map.md  docs/schema.md  docs/scope.md  docs/settings-panel.md
```

**(b) Tier 2 — triggers evaluated against the code.**

| Doc | Register row (`docs/ARCHITECTURE.md:320-331`) | Trigger measured in code | Verdict |
|---|---|---|---|
| `slash-dispatch.md` | *Not applicable* | 17 entries in `NS.COMMANDS`; `/at profile` subtree | **Row is false — AT-52** |
| `midnight-quirks.md` | Present | — | ok |
| `profiles.md` | Present | — | ok |
| `message-bus.md` | *Not applicable* — "Five messages; threshold is more than ten" | `core/Bus.lua:50-56` defines 5 (`REPAINT`, `APPEARANCE`, `VISIBILITY`, `POSITION`, `UNITS`) | ok |
| `compat-layer.md` | *Not applicable* — no compat layer; normalization moved to `LibKa0s-Env-1.0` | no `core/Compat.lua` in the tree | ok |
| `debug.md` | *Not applicable* — console is the library's | no debug surface of the addon's own | ok |
| `perf-analysis/README.md` | Present | `core/PerfSetup.lua` wires the harness | ok |

Command count, re-read at source:

```
$ grep -n 'NS.COMMANDS = {' settings/Slash.lua
60:NS.COMMANDS = {
$ grep -oE '^\s*\{ *"[a-z]+"' settings/Slash.lua
{"help  {"config  {"list  {"get  {"set  {"reset  {"resetall  {"resetposition  {"lock
{"unlock  {"toggle  {"debug  {"perf  {"update  {"version  {"test  {"profile
        { "list   { "current   { "reset      ← the PROFILE_VERBS subtree
```

17 top-level verbs (≥ 8), plus a subtree. `settings/Slash.lua:327` reads `local PROFILE_VERBS = {`
and `:386` reads `    local handler = PROFILE_VERBS[sub]` — a subcommand dispatch. Both halves of the
`slash-dispatch.md` trigger have fired; `docs/ARCHITECTURE.md:324` asserts neither has.

**(c) `## Documentation map`** present at `docs/ARCHITECTURE.md:304`. Cross-checked in both
directions against

```
$ find docs -name '*.md' -not -path 'docs/audits/*' -not -path 'docs/reviews/*' \
    -not -path 'docs/automated-tests/2*' -not -path 'docs/revendor/*' \
    -not -path 'docs/investigations/*' -not -path 'docs/superpowers/*'
```

Every live `.md` appears in exactly one of the map's three tables (`ARCHITECTURE.md` itself excepted,
as the hub the map lives in), and no row points at a missing file. Frozen/generated directories are
named once each, never enumerated — which is what the standard requires.

**(d) Non-canonical filenames** — none. `docs/performance.md` and `docs/test-cases.md` are Tier 3 /
verification-record docs and are filed as such in the map; neither holds Tier 1/2 content. No
`data-model.md`, `saved-variables.md`, `pipeline.md`, `settings-system.md`, `wow-quirks.md`,
`slash-commands.md` or `debug-console.md` exists.

**(e) Retired docs** — no `file-index.md`, `conventions.md`, `complexity.md`, `docs/perf-runs/` or
`docs/pending/`. The perf store is `docs/perf-analysis/20260807-125002/` carrying `report.md`,
`dump.json` and `ANALYSIS.md`.

**(f) Hub shape** — `wc -l docs/ARCHITECTURE.md` → **475**. Mandated-section spans, from
`grep -n '^## ' docs/ARCHITECTURE.md`: Overview 7-30, Module Map 31-80 (**50**), Invariants 81-98,
Settings Schema 99-132 (**34**), Message Bus 133-178 (**46**), Slash Commands 179-224 (**46**), Event
Subscriptions 225-274, Taint Notes 275-294, Known Limitations 295-303, Documentation map 304-343,
Documented deviations 344-467 (**124**), Performance 468-475. All four spillable sections are well
under 60. Recorded as Info, not a deviation.

## 8. Register and issue store — read before filing (AT-59)

`docs/ARCHITECTURE.md:344` reads `## Documented deviations`, and its table holds four rows plus a
"Retired on 2026-08-05" list of four. The three ID citations, re-read verbatim:

- `:354` — "… Argument in full below; filed as `AT-A-10` in `docs/audits/2026-08-05/`"
- `:356` — "… Filed as `AT-A-03` in `docs/audits/2026-08-05/` against the pre-scoping text"
- `:357` — "… Filed as `AT-A-09` in `docs/audits/2026-08-05/`; deferred twice before as PLAN-02"

```
$ grep -rl 'AT-A-03\|AT-A-09\|AT-A-10' docs/audits/
(no output)
$ grep -oE 'AT-[0-9]+' docs/audits/2026-08-05/02_DEVIATIONS.md | sort -u | tr '\n' ' '
AT-30 AT-31 AT-32 AT-33 AT-34 AT-35 AT-36 AT-37 AT-38 AT-39 AT-40 AT-41 AT-42 AT-43 AT-44 AT-45 AT-46 AT-47 AT-48 AT-49 AT-50
```

The bundle's own header confirms the scheme: "**IDs.** Prefix `AT-`, continuing from
`docs/audits/2026-08-04/` (highest prior `AT-41`)". `AT-35` is the `events-frames-taint-§8` row and
`AT-30` the `localization` row; there is no `AT-A-*` anywhere. Scope of the grep: all of
`docs/audits/`, including frozen bundles, since the citation claims to point into one.

Issue store, read with the sanctioned CLI (no `gh api graphql`):

```
$ gh issue list --state all --limit 200 --json number,title,state,labels
```

28 issues. Status is carried as a `state:` label and severity as a `severity:` label on every one;
no `[status]` title prefix survives. Open: #15, #20, #25 (`state:triaged`). Closed
`state:will-not-do`: #16, #21, #22, #23, #26, #27, #28. Closed `state:done`: the remainder.

Bodies of all seven `state:will-not-do` issues were read. **None records a ratified departure from a
standards rule**, so none owes a register row: #26/#27/#28 decline `LibKa0s-Widgets/Item/Pool-1.0` on
**applicability** ("a fixed three-frame set has nothing to recycle", "this addon has no item domain"),
which is the compliant state rather than a deviation; #16 declines a feature; #21/#22 decline
follow-up work. The inverse check therefore produces no finding. Issue #25 is `state:triaged` and
**open**, which is a working-queue entry, not ratification — it is filed here as **AT-58**.

## 9. Options panel content — the nine checks (compliance claims)

- **(a) Tab strips.** `settings/General.lua:295` — `H.RenderTabbedSchema(ctx, "general", { [H.MASTER_GROUP] = masterTail })`; groups `Master controls`, `Bars`. `settings/Appearance.lua:322` — `H.RenderUnitPanel(ctx, PAGE)`; groups `Size`, `Bar`, `Background`, `Border`, `Text` (plus `Link`, deliberately `skipRender` and excluded from the strip, `settings/Appearance.lua:283-295`). Exempt: `settings/Profiles.lua` (AceConfig, `:39` `AceConfig:RegisterOptionsTable`) and the landing page `settings/About.lua:34` `function Helpers.BuildMainContent(ctx)`. `settings/UnitPanel.lua:76-80` documents that the strip is drawn **always**, "including" the degenerate states — no fallback to an untabbed form and no early return.
- **(b) `Master controls`.** `settings/General.lua:88` — `local masterRows, masterTail = H.MasterControls({` — composed, never typed out, with `frameless = false` stated at `:94` and the reason given ("the bars are movable"). `grep -rn 'SetMovable'` over own source returns `modules/Bar.lua:35` `bar:SetMovable(true)` and `modules/Display.lua:209` `bar:SetMovable(not locked)`, so the frame-dependent four rows are correctly *not* omitted. The migration the row change owes exists: `core/Database.lua:194` `-- v5: the \`showOnlyInCombat\` BOOLEAN became the \`visibility\` DROPDOWN (options-ui-§15).` with the map at `:206` `p.visibility = p.showOnlyInCombat and "inCombat" or "always"`, run by the `SCHEMA_STEPS` ladder at `:239-243`.
- **(c) Class-color companions.** Four color rows, each followed in declaration order by its `Use class color` partner — `settings/Appearance.lua:18,20,22,24` document the pairs and `settings/OptionsSetup.lua:231,240,252,265` declare them. `classColorSource` is a declared field (`settings/Schema.lua:32`). The resolver is one function, `NS.ResolveColor` (`core/CoreSetup.lua:53`), whose fallback is the **stored** swatch (`stored.r or 1, …` at `:55`), not a literal gray.
- **(d) No `disabledIf` on a color row.** `grep -n 'disabledIf' settings/*.lua` returns only prose: `settings/Appearance.lua:78` "NO `disabledIf` ON ANY COLOR ROW, and that is a reversal worth stating.", `:91`, and `settings/Schema.lua:44` "NO ROW CARRIES `disabledIf`, and no color row ever may (options-ui-§17, anti-pattern #74)". Zero declarations.
- **(e) Ordering.** `grep -rn 'ScrollUp-Up\|ScrollDown-Up' --include='*.lua' settings/` → no output. No `MoveUp`/`MoveDown` handler and no numeric position field; the addon has no reorderable stored array.
- **(f) Media groups.** `grep -rn 'LSM30_Font\|LSM30_Border\|LSM30_Statusbar' settings/` returns `settings/Appearance.lua:115-117` (the composer's control→media-type map) and `:211`, plus the schema comment at `settings/Schema.lua:30` — every live use is a composer call site. `subgroup` headings are declared where a tab mixes kinds (`settings/General.lua:186,222`).
- **(g) One chrome block.** `settings/UnitPanel.lua:49` — "THE CHROME BLOCK (chrome, options-ui-§14) -- always, and there is exactly ONE of it", carrying the unit picker and the mirror controls; no `InlineGroup` or backdropped `SimpleGroup` wraps the band.
- **(h) Wrapped-strip geometry.** `tests/test_widgets.lua:770` — `assertTrue(ctx.chromeHeight > 0, "the strip reserves a band, so the first row clears it")` — is the only assertion on the band. There is **no** case asserting the band and every row's y offset are identical across selections. **AT-60.**
- **(i) Secondary strips.** None exist; no third level to check.

## 10. Close button and shared media (compliance claims)

```
$ grep -rn 'MakeCloseButton(' --include='*.lua' . | grep -v '/libs/' | grep -v '/tests/'
core/PerfSetup.lua:142:    -- IT USED TO BE `NS.DebugLog.MakeCloseButton(frame, api.Hide)` — a two-argument call onto a
core/PerfSetup.lua:151:            local close = NS.MakeCloseButton(frame, api.Hide)
core/CoreSetup.lua:100:-- `lib.MakeCloseButton(parent, onClick, addonName)` takes THREE arguments, and the third is what lets
core/CoreSetup.lua:111:    return lib.MakeCloseButton(parent, onClick, addonName)
```

Two of the four hits are comments. `core/CoreSetup.lua:110-112`, re-read:

```lua
NS.MakeCloseButton = function(parent, onClick)
    return lib.MakeCloseButton(parent, onClick, addonName)
end
```

— the **one** wrapper. `core/PerfSetup.lua:151` is a call **to that wrapper**. No bypass anywhere.

Descriptors carry `addonName`: `core/DebugLogSetup.lua:84` `addonName = addonName,` and
`core/PerfSetup.lua:43` `addonName = addonName,`.

Private media copies:

```
$ ls -R media
media: logos  screenshots
media/logos: absorbtracker.logo.jpg  absorbtracker.logo.png  absorbtracker.logo.tga
media/screenshots: absorbtracker.screenshot.01.png … 04.png
$ ls libs/LibKa0s/media
fonts  icons  textures
```

No overlap — the logo and the screenshots are what legitimately remains. One-off marks:
`grep -rn 'SetAtlas\|Interface\\\\' core/ modules/ settings/` returns only
`core/Constants.lua:7-8` (the two Blizzard-stock LSM fallbacks) and `:38` (`C.LOGO_PATH`).
`core/MediaSetup.lua:82` takes `LibKa0s-Media-1.0` and is fed the file's own first vararg
(`local addonName, NS = ...` at `:1`), and it loads immediately before `core/Constants.lua` in the
TOC — the position the TOC annotates as load-bearing.

## 11. Perf decorate hook — AT-56

`core/PerfSetup.lua:149-159`, re-read:

```lua
    decorate = function(frame, api)
        if NS.MakeCloseButton then
            local close = NS.MakeCloseButton(frame, api.Hide)
            -- The factory answers nil where CreateFrame is unavailable — a close button is worth
            -- degrading over, not erroring over.
            if close then
                close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(api.TITLE_H - 18) / 2)
                frame.closeButton = close
            end
        end
    end,
```

`libs/LibKa0s/PerfPanel.lua:190-196`, re-read — the else-branch the hook displaces:

```lua
    else
      local close = core.MakeCloseButton(frame, P.HidePanel, d.addonName or d.name)
      if close then
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(TITLE_H - 18) / 2)
        frame.closeButton = close
      end
    end
```

Same anchor, same offsets, same field. The hook draws no chrome the library does not draw.

## 12. `libs/LibStub/` — AT-58

```
$ find libs/LibStub -type f
libs/LibStub/LibStub.lua
libs/LibStub/LibStub.toc
libs/LibStub/tests/test.lua
libs/LibStub/tests/test2.lua
libs/LibStub/tests/test3.lua
libs/LibStub/tests/test4.lua
```

`AbsorbTracker.toc` lists only `libs\LibStub\LibStub.lua` in its `# Libraries` block. `.pkgmeta`'s
`  - tests` entry is root-relative and does not reach `libs/LibStub/tests`. Tracked as open issue #25,
`state:triaged` / `severity:low`, with no register row.

## 13. Degradation stubs — every member answered (compliance claim)

`core/PerfSetup.lua:22-27` publishes `on`, `suspended`, `Note`, `OnCommand`. The members the addon
reaches on the instance, swept over `core/ modules/ settings/`:

```
$ grep -rhoE 'Perf[.:][A-Za-z_]+' core/ modules/ settings/ | sed 's/.*[.:]//' | sort -u
Note  OnCommand  on  suspended
```

Exact match. The Core, DebugLog, Options and Slash stubs are covered by
`tests/test_surface_parity.lua`, whose four cases passed in §1's run — including the Options one,
which is correctly asserted as **load-completing** rather than member-answering.

## 14. TOC position annotations (compliance claim)

`AbsorbTracker.toc`, `# Core` block, re-read verbatim:

```
# Core (the LibKa0s-Env seam loads first)
# The LibKa0s-Env seam: this addon reads its own TOC manifest through it. Nothing here is resolved
# at load, so this position is conventional rather than load-bearing.
core\EnvSetup.lua
# Before Constants, deliberately: Constants.FONT_MONO is resolved from the NS.MediaFont seam
# this file publishes, so a Constants that loaded first would resolve it to the fallback.
core\MediaSetup.lua
core\Constants.lua
```

Confirmed against the seam files rather than trusted: `core/MediaSetup.lua:82` takes
`LibKa0s-Media-1.0` and publishes `NS.MediaFont`; `core/Constants.lua` resolves `FONT_MONO` from it at
file load. `core/EnvSetup.lua:54` takes `LibKa0s-Env-1.0` but resolves nothing at load, which is what
the conventional annotation claims. The load-bearing position names what resolves; the conventional
one is marked as such.
