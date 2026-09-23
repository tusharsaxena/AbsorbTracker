# 03 — Evidence

Every command below was run from the repo root at `8f64eb6`, and each is followed by its real output
and the scope it covered. Lua, lint and complexity runs went through
`/home/tushar/.claude/wow-addon/bin/ka0s-bounded`, which exists on this machine, so the `timeout 900`
fallback was never used. Every `file:line` in this bundle was re-read before it was written, and the
cited text is quoted beside it.

## Standard resolution

```sh
RAW=https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master
curl -fsSL $RAW/AUDIT.md -o AUDIT.md                          # 990 lines
curl -fsSL $RAW/standards/STANDARDS.md -o standards/STANDARDS.md
head -1 standards/STANDARDS.md
# Ka0s WoW Addon Standard (v2.64.0, 2026-09-23)
sed -n '/^## Sections/,/^## /p' standards/STANDARDS.md | grep -oE '\(standards/[A-Za-z0-9_-]+\.md\)' | sort -u | wc -l
# 27      -> each fetched with curl -fsSL into standards/standards/, none missing
curl -fsSL $RAW/standards/ADDONS.md -o standards/ADDONS.md     # rung (b) lock / unlock
```

Section ranges come from `grep -c '^### [0-9]' <file>`. The only ones that bear on this bundle are
toc-file 5, options-ui 18, testing 15, documentation 9, events-frames-taint 8, slash-commands 8 and
localization 5.

## Gates

```sh
ka0s-bounded luacheck .
# Total: 0 warnings / 0 errors in 61 files        exit=0
```
Scope: `.luacheckrc:13` sets `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`.
The 61 files are exactly the default census, `git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | wc -l`,
which returns 61 (28 source + 33 test).

```sh
ka0s-bounded lua tests/run.lua
# 710 passed, 0 failed, 0 skipped, 710 total       exit=0
ka0s-bounded lua tests/run.lua --list > $TMP/list.md
diff <(tr -d '\r' < docs/test-cases.md) <(tr -d '\r' < $TMP/list.md)      # (no output)
```
- `README.md:7`: `![Tests](https://img.shields.io/badge/Tests-710%2F710_passing-green)`, which agrees.
- `test_vendor_sync` ran, and did not skip, because the sibling `../LibKa0s` is present.

## Vendored payload (library-stack-§7, testing-§11)

```sh
grep -n 'Bundles \[LibKa0s\]' CLAUDE.md   # CLAUDE.md:43: Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.55.0 (MIT).
grep -n 'Bundles \[LibKa0s\]' README.md   # (none)
grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md   # (none)
grep -n 'WoW_Addon_Standard' README.md    # README.md:6: ![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)   (bare)
git -C ../LibKa0s archive v1.55.0 LibKa0s testkit | tar -x -C $TMP/lk155
diff -r $TMP/lk155/LibKa0s libs/LibKa0s     # (empty) rc=0 ; 146 files each side
diff -r $TMP/lk155/testkit tests/_kit       # (empty) rc=0 ; 11 files each side
git ls-files -s tests/_kit/run-automated-tests.sh   # 100755 31ff9b3e... 0
```
Diffed against the tag the provenance line names, `v1.55.0`, and not against the sibling's `HEAD`.

## Line endings (line-endings)

```sh
test -f .gitattributes                                   # present
grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes # .gitattributes:26: * text=auto eol=crlf
grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes      # :36 *.sh text eol=lf ; :37 *.py text eol=lf
grep -c ' binary$' .gitattributes                        # 20
sed -n '166,249p' line-endings.md > canon_client.txt     # §5 client-bound body, 84 lines
diff <(head -n 84 .gitattributes | tr -d '\r') canon_client.txt   # (empty) -> BODY-IDENTICAL
tail -n +85 .gitattributes | tr -d '\r' | grep -m1 .     # (nothing) -> no appendix
wc -l .gitattributes                                     # 84
```
(e), run verbatim over the whole tracked set with no exclusions:
```sh
git ls-files -z | xargs -0 -I{} sh -c '...check-attr text eol...' 2>/dev/null | wc -l
# 0
```
`test_eol` (kit revision 25, both cases) is declared at `tests/run.lua:127` and passes.

## Packaging (packaging)

The checks were run under `bash` rather than `zsh`, because zsh does not word-split `$entries`, and
the first zsh attempt printed a false "NOT IGNORED" line for the whole list:
```
(a)   (nothing)
(b)   UNACCOUNTED — .git          # the one entry that never needs a row
(c)   (nothing)
```

## Re-vendor bundles (audit-review-history) → AT-72

This is the `AUDIT.md` step 4 script, run verbatim, with horizon `2026-08-25` (the store's first
bundle):
```
vendored (31): v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.25.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0
               v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.35.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0
               v1.39.0 v1.42.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.55.0
recorded (9):  v1.15.0 v1.25.0 v1.30.0 v1.31.0 v1.32.0 v1.33.0 v1.34.0 v1.35.0 v1.55.0
unrecorded:    24   (v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0
                     v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.44.0 v1.45.0
                     v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0)
git log --since=2026-08-25 --format=%H -- libs/LibKa0s | wc -l     # 32 commits
```
- Bare-dated bundles had their tag read from `01_DELTA.md` line 1, for example
  `docs/revendor/2026-09-14/: # 01 — Delta: LibKa0s v1.34.0 → v1.35.0`.
- `grep -n revendor docs/ARCHITECTURE.md` returns one hit, `:592`, the Documentation map's
  out-of-scope list. No register row covers the gap.

## TOC position annotations (toc-file-§5) → AT-64, AT-65, AT-69, AT-70, AT-71

The denominator comes from reading the `core/` files for file-scope reads of an earlier seam, per
`toc-file-§5`. The census command:
```sh
git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' 'defaults/*.lua' 'locales/*.lua' \
  | xargs grep -nE '^local [A-Za-z_, ]+= *NS\.[A-Za-z_.]+'
```
This finds each `local x = NS.y` capture. In-descriptor captures (`version = NS.version`) and
file-load calls were then found by reading each `core/` file whole.

| TOC line | File | Consumed at file load by (quoted) | Annotation | Row |
|---|---|---|---|---|
| `:41-43` | `core\MediaSetup.lua` | `core/Constants.lua:30` `C.FONT_MONO = NS.MediaFont and …` | present | compliant |
| `:44` | `core\Constants.lua` | `core/DebugLogSetup.lua:86` `font = NS.Constants.FONT_MONO`, `core/Data.lua:11` | none | **not filed**: `toc-file-§5`'s own worked example rules this line "compliant — pinned by the annotated line above it" |
| `:45` | `core\Namespace.lua` | `core/PerfSetup.lua:47` `version = NS.version,` | none | **AT-71** |
| `:47` | `core\Bus.lua` | `core/AbsorbTracker.lua:357` `if NS.NewBusTarget then` / `:358` `NS.Events.__ev = NS.NewBusTarget()` / `:362` `…RegisterMessage(NS.MSG.UNITS, function()` | none | **AT-69** |
| `:48` | `core\CoreSetup.lua` | `core/LauncherSetup.lua:60` `local print = NS.Print`; `core/AbsorbTracker.lua:25` `if NS.Util and NS.Util.print then NS.Print = NS.Util.print end`; `core/DebugLogSetup.lua:22` `local missing = NS.LIBKA0S_MISSING .. …`; `core/PerfSetup.lua:28` | none (the reason lives in the file itself, `core/CoreSetup.lua:12` "Sits in core/Util.lua's old TOC slot for two reasons…") | **AT-70** |
| `:49-52` | `core\Lifecycle.lua` | `core/PerfSetup.lua:88` `lifecycle = NS.lifecycle,` | `:49` "# The stand-down latch. BEFORE PerfSetup, and that is load-bearing rather than tidy: Perf 12" | compliant |
| `:53` | `core\PerfSetup.lua` | `core/AbsorbTracker.lua:7` `local Perf = NS.Perf` (also `modules/Display.lua:8`, `modules/Timer.lua:9`) | none | **AT-64** |
| `:55` | `core\Units.lua` | `core/Database.lua:32` `local deepcopy = NS.Units.DeepCopy` | none | **AT-65** |

## Disabled state (slash-commands-§7)

These are the three orientation greps from the playbook. Scope: `git ls-files '*.lua' ':!libs' ':!tests'`,
the shipped source.
- **Register:**
  - AceEvent: `core/AbsorbTracker.lua:120-122`, `:176`, `:181`.
  - Unit events: `:164-165`, for example `f:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit)`.
  - Messages: `:362`, `modules/Display.lua:454`, `:457`, `:460` and `modules/Timer.lua:81`.
- **Undo:**
  - `core/Lifecycle.lua:95` `for _, f in pairs(frames) do f:UnregisterAllEvents() end`;
  - `:98` `for _, event in ipairs(ADDON_EVENTS) do addon:UnregisterEvent(event) end`;
  - `:105` `if NS.BusStandDown then NS.BusStandDown() end`;
  - timers at `:83-84`, canceled through `modules/Timer.lua:68` and `modules/Display.lua:98`.
- `tests/test_disabled.lua` asserts on `M.__registrations()`. Its step 3 is at `:108-121`
  (`assertEqual(#after, 0, "survivors of the stand-down…")`), and it carries `red under:` comments at
  `:112`, `:174` and `:454`. All 15 of its cases pass.

## AT-62 / AT-63: the Options stub and the fall-together bound

- `settings/OptionsSetup.lua:213` `if not lib then`, then `:241` `local function composeBlock(leaves, spec)`,
  `:278` `Helpers.ColorPair = function(spec)` … `:329` `Helpers.MasterControls = function(spec)`.
  These are host copies of the composed leaf sets.
- A host path reaches composed rows with the Options major absent:
  - `settings/Slash.lua:540-541` `local e = find(cmd)` / `if e then return e[3](rest or "") end`:
    the degraded dispatcher routes host verbs.
  - `settings/Slash.lua:311` `NS.SetByPath("enabled", on)`; `:91` `NS.SetByPath("locked", true)`;
    `:96` `NS.SetByPath("locked", false)`.
  - `core/AbsorbTracker.lua:259` `NS.SetByPath("locked", true)`: the combat re-lock.
- The Schema stub refuses a missing row. `settings/Schema.lua:160` reads `local row = S.FindRow(path)`,
  and `:161` reads `if not row then return false, "AbsorbTracker: no setting " .. tostring(path) end`.
- Suite pins:
  - `tests/test_perf.lua:501` `assertEqual(#NS2.Schema, #NS.Schema,`;
  - `tests/test_optionssetup.lua:233` `-- red under: a stub composer returning {}, or one that stops honoring `keys`.`;
  - `:243` `assertEqual(#rows, 4, "the canonical border block is four rows")`.

## AT-60: the wrap-stability case

- `tests/test_widgets.lua:850` `assertTrue(ctx.chromeHeight > 0, "the strip reserves a band, so the first row clears it")`.
  This is the only `chromeHeight` assertion (`grep -n chromeHeight tests/*.lua`).
- `tests/_kit/mock_base.lua:102-109`:
  - `["Options_Tab_Left"] = { 12, 28 }` … `["Options_Tab_Active_Left"] = { 12, 33 }`.
  - The kit now answers different heights for selected and unselected art.

## AT-67: stub-surface parity

```sh
grep -n 'assertSurfaceParity' tests/*.lua
# test_surface_parity.lua:66 (Core) :78 (DebugLog) :103 (Options) :173 (Slash) :197 (Launcher)
#                          :210 (Bus) :222 (Schema lib) :230 (Schema instance)   -- no Perf, no Lifecycle
git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' | xargs grep -ohE '\bPerf[.:][A-Za-z_]+' | sort | uniq -c
#   7 Perf.Note   1 Perf.OnCommand   5 Perf.on   1 Perf.suspended   (+1 "Perf.lua" in a comment)
git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' | xargs grep -ohE 'lifecycle[.:][A-Za-z_]+' | sort | uniq -c
#   1 lifecycle:Holds   3 lifecycle:IsDown   1 lifecycle:Reevaluate   1 lifecycle:Set
```
- `tests/test_surface_parity.lua:3` reads `-- The addon adopts seven LibKa0s seams — Core, DebugLog, Options, Slash, Launcher, Bus and Schema —`.
- The stub tables are at `core/PerfSetup.lua:23-30` (`on`, `suspended`, `Note`, `OnCommand`) and
  `core/Lifecycle.lua:155-177`. Both are complete today.

## AT-73: the register row whose rule changed

- The row, at `docs/ARCHITECTURE.md:652`, reads:
  `| events-frames-taint-§1 | UNIT_ABSORB_AMOUNT_CHANGED and UNIT_MAXHEALTH are registered on a private CreateFrame per tracked unit …`.
- The v2.64.0 carve-out's conditions against the code:
  - Only job: `core/AbsorbTracker.lua:152` `local f = CreateFrame("Frame")`, `:153`
    `f:SetScript("OnEvent", onEvent)`, and nothing else on the frame.
  - Held on NS: `:156` `self.__unitEventFrames = frames`, where `self` is `addon`, which is `NS`.
  - Unregistered in the disable path: `core/Lifecycle.lua:95`.
  - Reused: `:140` `local frames = self.__unitEventFrames`, with `if not frames then` building them
    once.
- Stale mentions of the old deviation:
  - `core/AbsorbTracker.lua:84` `-- events-frames-taint-§1 deviation (see docs/ARCHITECTURE.md): register them on private frames via`;
  - `docs/ARCHITECTURE.md:507` `— a documented events-frames-taint-§1 deviation (see below).`
- The evidence id resolves: `grep -c AT-31 docs/audits/2026-08-05/02_DEVIATIONS.md` returns 3.

## AT-74: registration isolation

The shipped source has no `pcall` around any registration. The command
`git ls-files 'core/*.lua' 'modules/*.lua' | xargs grep -n 'pcall' | grep -i regist` returns
nothing. The bare calls are quoted above: `core/AbsorbTracker.lua:120`, `:164` and `:176`.

## AT-75: hub shape

```sh
wc -l docs/ARCHITECTURE.md                    # 788
grep -n '^## ' docs/ARCHITECTURE.md
# 118 ## Settings Schema -> next ## at 234   => 116 lines
# 234 ## Message Bus     -> next ## at 307   => 73 lines
# 307 ## Slash Commands (38) · 38 ## Module Map (55) · 487 ## Event Subscriptions (56)
```

## AT-76: the `test` verb

- `settings/Slash.lua:109` `{"test", "Hold a fake absorb value on the bars — `/at test <value> [secs]`",`
  and `:110` `function(rest) runTest(rest) end},`.
- The exemption is claimed at `settings/General.lua:167-172` ("This addon ships no Test mode row:
  unlocking already paints the placeholder").

## AT-77: no `core/Compat.lua`

- `git ls-files core/Compat.lua` returns nothing.
- `git log --oneline --diff-filter=D -- core/Compat.lua` returns
  `bebb43f refactor(env): read the TOC through LibKa0s-Env-1.0`.
- The deprecated rung is in `core/EnvSetup.lua`, `function NS.Meta`: `:70` reads
  `if GetAddOnMetadata then` and `:71` reads `return GetAddOnMetadata(addonName, field)`.

## AT-78: pre-formatting outside the register row's scope

```sh
grep -nE 'print\((\(|"[^"]*" *\.\.|.*\):format)' settings/Slash.lua settings/Schema.lua | wc -l    # 17  (row says 18)
git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' 'defaults/*.lua' 'locales/*.lua' \
  | xargs grep -nE '[pP]rint\((\(|"[^"]*" *\.\.|.*\):format)' | grep -vE '^[^:]+:[0-9]+:\s*--' | cut -d: -f1 | sort | uniq -c
#   1 core/DebugLogSetup.lua   1 core/Lifecycle.lua   17 settings/Slash.lua   1 settings/UnitPanel.lua
```
- `core/DebugLogSetup.lua:47` `NS.Print("debug logging " .. (on and "|cff40ff40ON|r" or "|cffff4040OFF|r"))`;
- `core/Lifecycle.lua:173` `NS.Print(("%s: %s"):format(addonName,`;
- `settings/UnitPanel.lua:409` `NS.Print(("Unit panel render failed: %s"):format(NS.SafeToString(err)))`.

The named-API grep, `grep -nE 'UnitGetTotalAbsorbs|UnitHealth|GetThreat|AuraUtil' settings/Slash.lua settings/Schema.lua`,
returns nothing.

## AT-79: citation forms (documentation-§6)

```sh
grep -rEn '§[0-9]+\.[0-9]' . --exclude-dir=libs --exclude-dir=_kit --exclude-dir=audits --exclude-dir=reviews \
  --exclude-dir=automated-tests --exclude-dir=revendor --exclude-dir=.git | wc -l          # 0
```
- An out-of-range sweep over every `filename-§N` in the authored tree, range-checked against
  `grep -c '^### [0-9]'`, found none.
- Malformed:
  - `tests/prose_waivers.lua:3` `-- Read by `tests/_kit/test_prose.lua` (localization-5). …`;
  - `:7` `… exactly as localization-5 spells them`;
  - `tests/test_docs.lua:194` `… (LibKa0s kit revision 24). localization-5 says`;
  - `docs/module-map.md:852` `… `test_prose.lua` (1499, the US-English gate, localization-5) …`.
- Non-canonical form:
  - `.pkgmeta:17` `# listed because packaging.md:28 MUSTs that every root dot-entry present in`
    (also `:20`, `:21`);
  - `.luacheckrc:9` `-- linted (lint.md).` (also `:14`, `:78`).

## AT-80: doc drift (re-derived from the tree)

```sh
git ls-files '*.lua' | grep -vE '^(libs/|tests/)' | xargs grep -n -m1 -E '^local [A-Za-z_]+, NS = \.\.\.' | grep -c 'addonName'   # 9
... | grep -c 'local _, NS'                                                                                                 # 19
```
- `docs/ARCHITECTURE.md:30` `name, and only six files read it, so only those six bind it: `core/Namespace.lua`,`.
- `core/PerfSetup.lua:12` `-- upvalue — this file sits immediately after core/CoreSetup.lua in the TOC for exactly that reason,`.
  The TOC has `core\CoreSetup.lua` at `:48` and `core\Lifecycle.lua` at `:52` before `core\PerfSetup.lua` at `:53`.
- `docs/module-map.md:756`: the Core list runs `… CoreSetup.lua …, PerfSetup.lua …, Data.lua, Units.lua …,
  Database.lua, DebugLogSetup.lua …, AbsorbTracker.lua`, with no `Lifecycle.lua` and no `LauncherSetup.lua`.
- `.luacheckrc:25` `-- now open `local _, NS = ...`. Seven files do read it -- Namespace, EnvSetup, CoreSetup,`,
  but `core/CoreSetup.lua:1` reads `local _, NS = ...`.
- `settings/General.lua:21` `--                      [Test mode]                                     <- own line, startsLine`;
  `:43` `-- Test mode: every addon with a positionable display ships one (preview-mode).`
- `settings/Slash.lua:300` `-- second rung and nothing else: no file unloads, no event registration changes, and the dispatcher`.
- `docs/ARCHITECTURE.md:570` `… left it at LibKa0s v1.42.0:`, but `:655`'s row says `… left the addon at LibKa0s v1.41.0 …`.
- `docs/ARCHITECTURE.md:728` `… `tests/test_helpers.lua` at 1415 lines,`, but `wc -l tests/test_helpers.lua` returns 1416.
- `docs/settings-panel.md:68`: the *Master controls* Covers cell names off switch, visibility, scale,
  alpha, lock, debug console and the resets, and does not mention the Minimap button row.

## AT-81: the hand-written tag

- `settings/Schema.lua:237` `DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[AT]|r " .. line)`.
- `NS.Print` always exists: `core/CoreSetup.lua:67` `function NS.Print(...)` on the stub path, and
  `:106` `NS.Print = printer.Print` on the live path.

## Complexity (performance-§10, automated-tests)

```sh
ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .      # lizard 1.24.0
# No thresholds exceeded (cyclomatic_complexity > 15 or length > 1000 …)
# Total nloc 11389  Avg.NLOC 6.4  AvgCCN 1.7  Fun Cnt 1639  Warning cnt 0
```

**Drift against the newest bundle, `docs/automated-tests/20260916-184524/`:**
- Its `complexity.txt` recorded NLOC 10555 and 1479 functions, with 0 warnings.
- `manifest.json` records `"git": { "sha": "10808576…", "dirty": false }`.
- `git rev-list --count 1080857..HEAD` returns 37.
- No function crossed a threshold. The band change is that `tests/test_slashcmds.lua` left the
  over-cap band, 1745 → 1304.
- The watch list holds 2 band rows and 0 `Accepted` dispositions.
- Only one manifest records a release: `20260910-234511`, `"release": "1.10.0"`, which has an
  `ANALYSIS.md`.

## Register and issue store

```sh
gh issue list --state all --limit 200 --json number,title,state,labels,url    # 31 issues; all carry state:+severity:
```
- The `AT-30`, `AT-31` and `AT-35` ids resolve in `docs/audits/2026-08-05/02_DEVIATIONS.md`
  (2, 3 and 1 hits respectively).
- The `savedvariables-§1` trigger: `core/Database.lua:59` `function NS.MigrateProfileToV3(profile)`
  is live.

## Miscellaneous compliance citations

- IconTexture: the TGA header read with `python3` reports `type 2 w 128 h 128 bpp 32`.
- `#88` grep outside `libs/` and `tests/_kit/`: no host hit. The only hits are in `libs/LibKa0s/Options.lua`,
  `libs/AceConfig-3.0` and `tests/test_widgets.lua`.
- The bus-literal greps (`(Send|Register)Message\("Ka0s_`) find no call-site literal. The only
  `"Ka0s_…"` strings are the catalog at `core/Bus.lua:115-119` and the tests.
- `MakeCloseButton(` outside `libs/` and `tests/` returns only the comment at `core/PerfSetup.lua:118`
  (AT-Info-1).
- `libs/LibKa0s/DebugLog.lua:57` reads `lib.MAX_BUFFER = 1500` (AT-Info-4).
