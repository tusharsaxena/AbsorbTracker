# 03 — Evidence

Every command below was run on 2026-10-07 from the AbsorbTracker repo root at commit `4cedffa`, clean
tree, and the output shown is the output it printed. Every `file:line` cited in this bundle was re-read
before it was written, and the cited text is quoted beside it. Scope is stated with each count.

Standard source: `curl -fsSL https://raw.githubusercontent.com/tusharsaxena/WowAddonStandards/master/{AUDIT.md,standards/STANDARDS.md,standards/ADDONS.md,standards/standards/<27 files>}`;
`STANDARDS.md` line 1: `# Ka0s WoW Addon Standard (v2.76.1, 2026-10-07)`.

Kind detector: `dev-copilot-profile` →
```
profile=wow
kind=addon
repo=/mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker
name=AbsorbTracker
reason=toc:## Interface
```
`ADDONS.md:19`: `| Ka0s Absorb Tracker | [`../../AbsorbTracker/`](../../AbsorbTracker/) | https://github.com/tusharsaxena/AbsorbTracker | Enabled · Locked |`

---

## The gates

```sh
~/.claude/dev-copilot/bin/ka0s-bounded luacheck .
# Total: 0 warnings / 0 errors in 69 files        (exit 0)

~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua
# 876 passed, 0 failed, 1 skipped, 877 total       (exit 0)
#   SKIP  diagnostics contract: an addon that opts out lands the report and leaves logging off —
#         this addon keeps the default (Kit.diagnostics.enablesLogging is not false) ...

~/.claude/dev-copilot/bin/ka0s-bounded lua tests/run.lua --list > <tmp>; diff docs/test-cases.md <tmp>
# (no output — the committed inventory is current; its ## Totals row reads **877**)
```
Lint scope: `.luacheckrc:13` — `exclude_files = { "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/_kit/" }`;
`files["tests/"]` at `:67` carries `"_G.AT_TEST"` (`:69`); no top-level `ignore` (`:14` comment
"NO TOP-LEVEL `ignore`"). The 69 files linted equal the authored-Lua census below.

README badge `README.md:7`: `![Tests](https://img.shields.io/badge/Tests-876%2F876_passing-green)`.

## Complexity (sighted)

```sh
~/.claude/dev-copilot/bin/ka0s-bounded bash tests/_kit/run-automated-tests.sh --suite complexity --no-bundle
# AbsorbTracker 1.11.0 — automated tests — 20261007-154736
#   complexity  pass  — 0 warnings (fun rate 0.00), 14461 NLOC / 2219 funcs, avg NLOC 6.4, avg CCN 1.8 (max 14), avg tokens 49.0 (recorded, non-gating)
#   verdict: green
#   record:  newest bundle 20260927-030336 measured 9b5a369, 57 commit(s) behind HEAD — its figures describe a tree this one is no longer
```
- `tests/_kit/framework.lua:20` `Kit.VERSION = 37`; `tests/run.lua:176` `{ name = "test_lizard_sighted", dir = "tests/_kit/" },`.
- `docs/automated-tests/20260927-030336/manifest.json`: `"release": "1.11.0"`, `"git": { "sha": "9b5a369…", "dirty": false }`,
  `"complexity": { "status": "pass", … "maxCcn": 14, … "functions": 1919, … "bandFiles": 2, "overCapFiles": 0 … }` — no `blindFiles` key (pre-kit-35).
- `git rev-list --count 9b5a369..HEAD` → `57`.
- Watch list (`docs/automated-tests/RESULTS.md`): `tests/test_slashcmds.lua | 1321 | **Back under the cap — watch.**`;
  `tests/test_widgets.lua | 1073 | **Accepted — watch (second run in the band).** … That is its first release run carried as Accepted, one of three`.
  Today: 1079 and 1073 (census below). No warned function. No #53 entry.

## Layout census (`layout-§1`)

```sh
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | wc -l                       # 69
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | sort -n | tail -3
#   1073 tests/test_widgets.lua
#   1079 tests/test_slashcmds.lua
#  23483 total
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | xargs wc -l | awk '$1>=1000 && $2!="total"'
#   1079 tests/test_slashcmds.lua
#   1073 tests/test_widgets.lua
git ls-files '*.py' '*.sh' | grep -vE '^(libs/|tests/_kit/)'                           # (none)
```
Scope: every tracked authored `.lua`, `tests/` included; `libs/` and `tests/_kit/` excluded (vendored);
no generated-data exemption is declared. `docs/ARCHITECTURE.md:384` `### Files over the 1500-line cap`;
`:394` "Nothing is over the cap today. The largest authored file is `tests/test_slashcmds.lua` at 1079 lines". `tests/run.lua:173` `{ name = "test_layout_cap", dir = "tests/_kit/" },`.

## Vendored payloads (`library-stack-§7`, `testing-§11`)

```sh
grep -n 'Bundles \[LibKa0s\]' CLAUDE.md
# 43:Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.70.0 (MIT).
grep -n 'Bundles \[LibKa0s\]' README.md                                     # (none)
grep -nE '^## (Libraries|Bundled libraries|Libraries and credits|Credits and libraries|Credits and bundled libraries)' README.md   # (none)
grep -n 'WoW_Addon_Standard' README.md
# 6:![Standard](https://img.shields.io/badge/Ka0s-WoW_Addon_Standard-yellow)

git -C ../LibKa0s rev-parse v1.70.0                                       # 26f441a25ad7a808ca612eecec512808b9fa4c38
git -C ../LibKa0s archive v1.70.0 LibKa0s testkit | tar -x -C <private tmp>
diff -r <tmp>/LibKa0s libs/LibKa0s            # (empty, exit 0) — 159 files each side
diff -r <tmp>/testkit tests/_kit              # (empty, exit 0) — 22 files each side
git ls-files -s tests/_kit/run-automated-tests.sh   # 100755 685cbcc… 0  tests/_kit/run-automated-tests.sh
```
TOC: `AbsorbTracker.toc:29` `libs\LibKa0s\LibKa0s.xml`, once. `grep -c '<Script file=' libs/LibKa0s/LibKa0s.xml` → **34**.

## AT-82 — re-vendor bundles (`audit-review-history`)

The playbook's check, run verbatim into a private temp directory:
```
horizon=2026-08-25
vendored: 51  recorded: 50
UNRECORDED:
v1.69.0
v1.70.0
RECORDED-NOT-VENDORED:
v1.59.0
```
Scope: the 54 commits since `2026-08-25 00:00` touching `libs/LibKa0s` or `tests/_kit`
(`git log --since="2026-08-25 00:00" --format=%H -- libs/LibKa0s tests/_kit | wc -l` → 54), tag read
from each commit's `CLAUDE.md`; recorded side read per the playbook (span folders: every tag on
`01_DELTA.md` line 1; bare-dated: line 1's last tag).
```sh
git log --oneline -3 -- libs/LibKa0s tests/_kit
# 4c16982 chore: re-vendor LibKa0s v1.70.0
# 5075fd5 chore: re-vendor LibKa0s v1.69.0 (kit 37; adds the line chart widget)
# 8030ac1 DC-REV-01: re-vendor LibKa0s v1.68.1 (kit 36; library bytes unchanged)
git show --stat 4c16982 | grep -v '^ libs\|^ tests/_kit'    # only CLAUDE.md | 2 +- outside the payload
ls docs/revendor | tail -1                                   # 2026-10-04-v1.68.1
```

## AT-80 — doc drift (`documentation-§5`)

| Claim (quoted) | Location | Tree |
|---|---|---|
| "**Twelve majors bound by name** of the fifteen `libs/LibKa0s/` vendors (thirty-two files)" | `docs/ARCHITECTURE.md:49` | `grep -c '<Script file=' libs/LibKa0s/LibKa0s.xml` → 34 |
| "`LibKa0s` (**fifteen majors across thirty-two files**: …" | `docs/module-map.md:786` | 34 |
| "… — **fifteen majors across thirty-two files**." | `docs/module-map.md:942` | 34 |
| "The payload now ships **fifteen majors across thirty-two files**," | `docs/performance.md:390` | 34 |
| load-order chain "`WidgetsDragHandle.lua` → `DebugLog.lua`" | `docs/module-map.md:786`, `:942` | XML lists `WidgetsLineChart.lua`, `WidgetsAutocomplete.lua` between them |
| "`CLAUDE.md` names **v1.68.1**, the vendored payloads are that tag" | `docs/testing.md:169-170` | `CLAUDE.md:43` names v1.70.0 |
| "`| 30 | `tests/run.lua` | 175 |` … runs the thirty-two suites of its own plus the kit's five" | `docs/module-map.md:884` | `wc -l < tests/run.lua` → 178; `grep -nE '"test_[a-z_]+"' tests/run.lua \| grep -v 'dir =' \| wc -l` → 35, and the 35 match the 35 `tests/test_*.lua` on disk |
| "a test can assert the two-frame split (player+target on one frame, focus on the other)" | `docs/module-map.md:887` | `core/AbsorbTracker.lua:193-198` builds `frames[unit] = f` for each of `NS.Units.LIST` |
| "live here at DebugLog 6 / Slash 5 / Perf 5" | `docs/module-map.md:916` | `libs/LibKa0s/DebugLog.lua:37` `"LibKa0s-DebugLog-1.0", 19`; `Slash.lua:21` `… 19`; `Perf.lua:37` `… 14` |
| "it left the addon at LibKa0s v1.41.0" | `docs/module-map.md:468` | `docs/ARCHITECTURE.md:377` "left the addon at LibKa0s v1.42.0"; `docs/slash-dispatch.md:52` "minor 14 (LibKa0s v1.42.0)" |
| "became the library's wording at LibKa0s v1.41.0" | `docs/module-map.md:817` | same |

Sweep used to find the inventory claims (scope: tracked `.md` outside the frozen stores):
`git ls-files 'docs/*.md' CLAUDE.md DEPENDENCIES.md README.md | grep -vE '^docs/(audits|reviews|revendor|superpowers|investigations)/|^docs/automated-tests/2|^docs/perf-analysis/2' | xargs grep -noE 'thirty-two( library)? files|fifteen majors across thirty-two|thirty-two suites'`
→ `docs/ARCHITECTURE.md:49`, `docs/module-map.md:786`, `:884`, `:942`, `docs/performance.md:390` (five hits, four of them the library inventory).

The 2026-09-23 items 1–6, 8 and 9 were re-checked and are fixed (e.g. no "immediately after
`core/CoreSetup.lua`" remains; `settings/General.lua:21` now reads "`[Minimap button] <- alone: no Test mode row`";
the `addonName` sentence at `docs/ARCHITECTURE.md:29-31` reads "ten … the other nineteen", and the tree has 10 and 19:
`grep -l '^local addonName, NS = \.\.\.'` → 10, `grep -l '^local _, NS = \.\.\.'` → 19 over the 29 core/defaults/modules/settings/locales files).

## AT-83 — raw `lizard` in a gate table

- `docs/automated-tests/README.md:29`: `| `complexity` | `lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | no — recorded | **gates** — `pass`, zero functions above CCN 15 |`
- `docs/testing.md:99`: `| `complexity` | `bash tests/_kit/run-automated-tests.sh --suite complexity` (lizard over the kit's sighted shadow, …`
- `DEPENDENCIES.md:272`: `bash tests/_kit/run-automated-tests.sh --suite complexity   # the `complexity` suite (sighted, kit 35)`
- performance-§10: "so the command a gate line or a reader quotes is `bash tests/_kit/run-automated-tests.sh --suite complexity`".
- `grep -n 'lizard' CLAUDE.md` → none.

## AT-84, AT-85 — settings-block TOC positions (`toc-file-§5`)

- `AbsorbTracker.toc:82` `# Settings (last — depend on everything else being initialized)`; `:83` `settings\Schema.lua`; `:84` `settings\Slash.lua`; `:85` `settings\OptionsSetup.lua`; `:86-90` `UnitPanel`, `About`, `General`, `Appearance`, `Profiles` — no line comment on any.
- Published by `settings\Schema.lua`: `settings/Schema.lua:400` `NS.SchemaRuntime = S`; `:407` `NS.RegisterSchemaRows = S.AddRows`.
- Read at file load by later files: `settings/OptionsSetup.lua:98` `    allRows      = NS.SchemaRuntime.AllRows,`; `:144` `    bulkBegin = NS.SchemaRuntime.BulkBegin,`; `:145` `    bulkEnd   = NS.SchemaRuntime.BulkEnd,` (inside the file-scope `local descriptor = {` at `:77`); `settings/General.lua:254` `NS.RegisterSchemaRows(masterRows)` (file scope).
- Published by `settings\OptionsSetup.lua`: `:377` `NS.Helpers = lib:New(descriptor)`.
- Captured at file load: `settings/UnitPanel.lua:17` `local Helpers = NS.Helpers`; `settings/About.lua:19` `local Helpers = NS.Helpers`; `settings/General.lua:12` `local H = NS.Helpers`; `settings/Appearance.lua:74` `local H = NS.Helpers`.
- Census command (scope: every addon `core/ defaults/ modules/ settings/` file, file-scope lines only):
  `for f in core/*.lua defaults/*.lua modules/*.lua settings/*.lua; do grep -nE '^local [A-Za-z_, ]+ = NS\.[A-Za-z_.]+|^[A-Za-z_.]+ = NS\.[A-Za-z]+\.' $f; done` — the remaining hits are cross-section (defaults/core before modules/settings, fixed by the mandated section order) or already-annotated core positions.

## AT-86 — stale register row

- `docs/ARCHITECTURE.md:375`: `| `savedvariables-§1` | A **per-profile** `schemaVersion` stamp at `db.profile.schemaVersion` (default `1`), alongside the account-wide stamp in `db.global` (default `0`, owned by the runner as §1 r…` — Decided `2026-07-28`, trigger "AceDB gaining a per-profile version stamp of its own, or the last per-profile migration being retired".
- savedvariables-§1 (fetched, v2.65.0 ruling): "**MUST** run a **profile-scoped** step for **every stored profile**, either by walking the raw SavedVariables `profiles` table as above, or idempotently from AceDB's `OnProfileChanged` (and `OnProfileCopied` / `OnProfileReset`) callbacks against a **per-profile** stamp."
- `core/Database.lua` (code): `function NS.MigrateProfileToV3(profile)` … `if (profile.schemaVersion or 1) >= 3 then return false end` … `profile.schemaVersion = 3`; `local function migrateAllProfiles() return forEachProfile(NS.MigrateProfileToV3) end`; `NS:RunMigrations` sets `g.schemaVersion = g.schemaVersion or 0` and advances it only after a step returns.
- `core/AbsorbTracker.lua:367-368` `    if NS.MigrateProfileToV3 and NS.db then` / `        NS.MigrateProfileToV3(NS.db.profile)` inside `adoptProfile`, reached from `NS.OnProfileChanged` (`:395`), `NS.OnProfileReset` (`:404`) and `NS.OnProfileCopied` (`:414`), registered at `core/Database.lua` `NS.db.RegisterCallback(NS, "OnProfileChanged", …)` ×3.
- `defaults/Profile.lua` global `schemaVersion = 0`.

## AT-88 — Widgets with no seam

- `modules/Bar.lua:15` `local Widgets = LibStub and LibStub("LibKa0s-Widgets-1.0", true)`; `:126` `    if not (Widgets and Widgets.DragHandle) then return nil end`.
- `modules/Display.lua:26` `local Widgets = LibStub and LibStub("LibKa0s-Widgets-1.0", true)`; `:27` `local DRAG = Widgets and Widgets.DRAG_HANDLE`; `:28` `local HANDLE_ROOM = DRAG and (DRAG.HEIGHT + DRAG.GAP) or 0`.
- `docs/ARCHITECTURE.md:50` "`LibKa0s-Widgets-1.0` is bound with no setup seam:" — no register row (`:375-377` are the only rows).
- `grep -n 'Widgets' tests/test_surface_parity.lua` — no Widgets parity case (cases at `:48`, `:72`, `:98`, `:171`, `:190`, `:208`, `:221`, `:231`, `:241`, `:273` cover Core, DebugLog, Options, Slash, Launcher, Bus, Schema ×2, Perf, Lifecycle).
- library-stack-§7 (fetched): "An addon wires only the modules it actually uses — one setup file per module, each resolving its major with `LibStub(major, true)` and degrading to a stub when it is absent".
- Issue #26: `CLOSED  state:will-not-do,severity:low  LibKa0s-Widgets-1.0: declined — no control in this addon wants it`.

## AT-78 — pre-formatting outside the register row

```sh
grep -nE 'print\((\(|"[^"]*" *\.\.|.*\):format)' settings/Slash.lua settings/Schema.lua | wc -l     # 17 (row says 17)
git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' 'defaults/*.lua' 'locales/*.lua' \
  | xargs grep -nE '[pP]rint\((\(|"[^"]*" *\.\.|.*\):format)' | grep -vE '^[^:]+:[0-9]+:\s*--' | cut -d: -f1 | sort | uniq -c
#   1 core/Database.lua
#  17 settings/Slash.lua
git ls-files 'core/*.lua' 'modules/*.lua' 'settings/*.lua' | xargs grep -nE '[pP]rint\((string\.)?format\(|[pP]rint\([a-zA-Z_.]+ *\.\.' | grep -vE '^[^:]+:[0-9]+:\s*--'
# core/CoreSetup.lua:104:    function NS.Print(...)            (the stub printer's definition, not a call)
# core/Lifecycle.lua:186:            NS.Print(addonName .. ":",   (library-absent stub; not filed)
# modules/Bar.lua:36:    NS.Print(format(L["%s bar hidden. …"], …   (localized one-sentence format; not filed)
grep -nE 'UnitGetTotalAbsorbs|UnitHealth|GetThreat|AuraUtil' settings/Slash.lua settings/Schema.lua   # (none — trigger not fired)
```
`core/Database.lua:234` `                NS.Print("Settings upgrade stopped at v" .. from .. " -> v" .. step.to`; `from`/`step.to` are the runner's integers.

## AT-87 — hand-rolled change gates

- `core/AbsorbTracker.lua:34` `local dbgAbsorbSecret`; `:244` `    if secret ~= dbgAbsorbSecret then`; `:246` `            NS.Debug("Absorb", "reads secret: shield transitions not traced until readable")`.
- `modules/Display.lua:367` `local dbgLastShown = {}   -- module-local: last applied visibility per unit, for transition logging`; `:381` `    if NS.State and NS.State.debug and show ~= dbgLastShown[unit] then`; `:382` `        NS.Debug("Bar", "%s: %s (%s)", unit, show and "shown" or "hidden", visibilityReason(unit))`.
- `grep -n 'onClear' core/DebugLogSetup.lua` → (none).
- Library gates already used: `core/AbsorbTracker.lua:139` `    if not ok then NS.DebugLog.DebugOnce("rejected:" .. event, "Events", "rejected %s", event) end`; `settings/UnitPanel.lua:365` `        NS.DebugLog.DebugChanged(RENDER_ERROR_KEY, "Cfg", "unit panel render failed (%s): %s",`.

---

## Compliance evidence for the checked-and-compliant list

### Line endings (`line-endings`)
```sh
test -f .gitattributes && echo present                         # present
grep -n '^\* text=auto eol=\(crlf\|lf\)$' .gitattributes       # 26:* text=auto eol=crlf
grep -nE '^\*\.(sh|py) text eol=lf$' .gitattributes            # 36:*.sh text eol=lf / 37:*.py text eol=lf
grep -c ' binary$' .gitattributes                              # 20
<(e) one-liner from AUDIT.md, verbatim> | wc -l                # 0
git ls-files | wc -l                                           # 637 (the (e) scope: whole tracked set)
diff <(head -84 .gitattributes | tr -d '\r') <canonical client-bound body from line-endings-§5>   # identical
tail -n +85 .gitattributes | wc -l                             # 0 (no appendix)
```
`tests/run.lua:169` `{ name = "test_eol", dir = "tests/_kit/" },`.

### Packaging (`packaging`)
Run under `bash` (zsh does not word-split `$entries`): (a) prints nothing; (b) prints `UNACCOUNTED — .git`
only; (c) prints nothing (`.claude` and `.superpowers` both exist; `.pkgmeta:20-21` ignore them).

### Citations (`documentation-§6`)
Scope: 100 tracked text files outside `libs/`, `tests/_kit/` and the frozen stores. `§N.M` hits 0;
malformed `filename-N` hits 0; 806 `filename-§N` citations over 79 distinct references, every one
inside its section's numbered range (ranges from `grep -cE '^### [0-9]+\.'` per fetched section file).

### Disabled state (`slash-commands-§7`)
```sh
git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -nE 'Register(Unit)?Event|RegisterMessage|RegisterBucketEvent' | grep -vE '^[^:]+:[0-9]+:\s*--'
# core/AbsorbTracker.lua:144  safeRegister → NS.SafeRegisterEvent        (3 lifecycle + 2 swap events)
# core/AbsorbTracker.lua:148  safeRegisterUnit → NS.SafeRegisterUnitEvent (per-unit frames)
# core/AbsorbTracker.lua:429  NS.Events.__ev:RegisterMessage(NS.MSG.UNITS, …)
# modules/Display.lua:476/479/482  ev:RegisterMessage(APPEARANCE / VISIBILITY / POSITION)
# modules/Timer.lua:87       NS.Timer.__ev:RegisterMessage(NS.MSG.REPAINT, …)
# core/CoreSetup.lua:83-141   the helper definitions / library bindings (not registrations)
git ls-files '*.lua' ':!libs' ':!tests' | xargs grep -nE 'Unregister(All)?Events?|UnregisterMessage|CancelTimer|…' | grep -vE '^[^:]+:[0-9]+:\s*--'
# core/Lifecycle.lua:104  for _, f in pairs(frames) do f:UnregisterAllEvents() end
# core/Lifecycle.lua:107  for _, event in ipairs(ADDON_EVENTS) do addon:UnregisterEvent(event) end
# modules/Display.lua:98  NS.addon:CancelTimer(previewTimer)   (via NS.ClearPreview, called by StandDown)
# modules/Timer.lua:74    NS.addon:CancelTimer(pending)        (via NS.CancelPendingRepaint, called by StandDown)
# core/AbsorbTracker.lua:210/221/226  per-unit / swap unregisters when a unit's bar is off
```
The bus messages are tracked targets torn down by `core/Lifecycle.lua:114` `    if NS.BusStandDown then NS.BusStandDown() end`.
`core/Lifecycle.lua:69-72` (`local ADDON_EVENTS = {` … `}`) names the five AceEvent events (`"PLAYER_ENTERING_WORLD", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",` / `"PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED",`).
No `OnUpdate`, ticker or hook in the addon's own Lua. `settings/Slash.lua:759-761` builds `liveVerbs` from `SlashLib.LIVE_VERBS`.
`tests/test_disabled.lua`: 18 cases, `:108` "disabled 3: writing the enable path leaves NOTHING registered", `:320` "disabled 7: both diagnostics forms reach RunDiagnostics, each once, with no refusal".

### Bus naming (`architecture-§4`)
`grep -nE '(Send|Register)Message\("Ka0s_'` over the addon's Lua (vendored excluded) → none;
`core/Bus.lua:116-120` declare `"Ka0s_AbsorbTracker_RepaintRequested"`, `…_AppearanceChanged`, `…_VisibilityChanged`, `…_PositionChanged`, `…_UnitsChanged`.

### Diagnostics (`debug-logging-§14`)
`grep -n '"diagnostics"' settings/*.lua core/*.lua` → `settings/Slash.lua:119` (`COMMANDS` row), `:377` (`if sub == "diagnostics" then return runDiagnostics() end`), `core/DebugLogSetup.lua:85` (stub's `DebugVerb`);
`grep -rniE '"(diag|dump|dx)"' settings core modules` → none; `grep -n 'diagnosticsEnablesLogging' core/*.lua` → none;
`grep -n 'SetEnabled' settings/*.lua core/*.lua modules/*.lua` → `settings/Slash.lua:261-262` (`setDebugLogging`, the `on`/`off` words — not around `RunDiagnostics`) and the stub. `README.md:110-116` is the fixed section with `/at`.

### Library debug lines (`debug-logging-§4`)
`settings/Slash.lua:722` `    debug   = function(tag, message) NS.Debug(tag, "%s", message) end,`;
`settings/OptionsSetup.lua:85` `    debug = function(tag, fmt, ...) NS.Debug(tag, fmt, ...) end,` (the library calls it with the message alone, which `D.Debug` writes verbatim when no vararg follows);
`core/LauncherSetup.lua` `debug = function(tag, message) NS.Debug(tag, "%s", message) end,` and `debugAtEnable = function(tag, message) NS.DebugLog.DebugAtEnable(tag, "%s", message) end,`;
`core/Lifecycle.lua:201` `        debug     = function(tag, message) NS.Debug(tag, "%s", message) end,`.

### Options descriptor (`options-ui-§1`, v2.75.0)
`settings/OptionsSetup.lua:82` `    addonName     = addonName,`; hollow composers `:246-249`; minimap veto `:61-69`.

### TOC and media
`AbsorbTracker.toc:6` `## IconTexture: Interface\AddOns\AbsorbTracker\media\logos\absorbtracker.logo.128.tga`;
`od -A d -t u1 -N 18 media/logos/absorbtracker.logo.128.tga` → `0 0 2 0 0 0 0 0 0 0 0 0 128 0 128 0 32 8`.

### Register and issue store
`gh issue list --state all --limit 200 --json number,title,state,labels` → 33 issues; every one carries one `state:` and one `severity:` label; open: #2, #3, #4, #5, #6, #8, #9, #15 (all `state:triaged`); `state:will-not-do`: #16, #21, #22, #23, #26, #27, #28, #31. No title carries a `[status]` prefix. `ls docs/pending` → absent.
`grep -c 'AT-30\b' docs/audits/2026-08-05/02_DEVIATIONS.md` → 2; `grep -c 'AT-35\b' …` → 1; `ls locales` → `enUS.lua`.
