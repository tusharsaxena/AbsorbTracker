# 03 — Evidence

Every deviation in `02_DEVIATIONS.md` and every compliance claim in `01_CURRENT_STATE.md` is sourced
here. Mechanical checks were **run**, not reasoned about; their real commands and real output are
reproduced verbatim. All commands were run from the repo root
`/mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker` on 2026-08-04.

---

## 0. Mechanical checks

### 0.1 Standard provenance

```
$ cd /mnt/d/Profile/Users/Tushar/Documents/GIT/WowAddonStandards && git status --porcelain && git log -1 --format='%H %s'
214122996c6c2db2e1c4a88a1f5d152dce2de928 v2.17.1 — finish the v2.17.0 rollout: no fourth slot, no drop-in imperative
```

(no `git status --porcelain` output — clean tree)

```
$ curl -fsSL --max-time 20 $RAW/AUDIT.md -o AUDIT.md              # 9165 bytes
$ curl -fsSL --max-time 20 $RAW/standards/STANDARDS.md            # 73255 bytes
$ for f in anti-patterns architecture audit-review-history compat debug-logging documentation \
           events-frames-taint layout library-stack lint localization naming-cheatsheet \
           open-evolutions options-ui packaging performance preview-mode public-api savedvariables \
           slash-commands standalone-windows testing toc-file versioning-git; do
      curl -fsSL --max-time 10 $RAW/standards/standards/$f.md -o std/$f.md || echo "FAIL $f"; done
   (no FAIL lines — all 24 retrieved)

$ diff -r <checkout>/standards/standards <fetched>/std
   (no output — byte-identical)
$ diff <checkout>/standards/STANDARDS.md <fetched>/STANDARDS.md
   (no output)
$ diff <checkout>/AUDIT.md <fetched>/AUDIT.md
   (no output)
```

The 24 files are exactly those linked from `STANDARDS.md`'s **Sections** list (`STANDARDS.md:53-77`);
`tiered-layout.md` appears in the changelog as historical narration only and is not a live section.

### 0.2 Lint

```
$ luacheck .
Checking core/AbsorbTracker.lua                   OK
Checking core/Bus.lua                             OK
... (28 files)
Checking settings/UnitPanel.lua                   OK

Total: 0 warnings / 0 errors in 28 files
```

Backs `lint`'s zero-error gate and `versioning-git`'s commit gate. `luacheck` resolved at
`/usr/local/bin/luacheck`.

### 0.3 Headless suite

```
$ lua tests/run.lua
... (all cases PASS)
469 passed, 0 failed, 469 total
```

`lua` resolved at `/usr/bin/lua`; `lua5.1` also present. Backs `testing-§4`'s green gate, and is the
**counter-evidence for AT-32**: the real count is 469, the README badge says 467.

### 0.4 Ka0s-owned vendored-library drift — both diffs, both empty

Source repo located as a sibling of the addon repo, confirmed to be the LibKa0s repo (it carries
`CHANGELOG.md`, `LICENSE`, `README.md`, the inner ship folder `LibKa0s/`, `docs/`, `tests/` and the
root-level `testkit/`).

```
$ ls /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/LibKa0s
Core.lua  DebugLog.lua  LICENSE  LibKa0s.xml  Options.lua  OptionsScroll.lua
OptionsWidgets.lua  Perf.lua  PerfPanel.lua  Slash.lua

$ diff -r /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/LibKa0s \
          /mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker/libs/LibKa0s
rc=0        (no output — EMPTY)

$ diff -r /mnt/d/Profile/Users/Tushar/Documents/GIT/LibKa0s/testkit \
          /mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker/tests/_kit
rc=0        (no output — EMPTY)
```

Both **MUST**-empty diffs are empty, over the **whole** folders — all 8 module files plus
`LibKa0s.xml` and `LICENSE`, and all four kit files including `README.md`. This is the evidence that
**anti-pattern #45** (drifted vendored copy) and **anti-pattern #48** (partial vendoring) are clear,
and it is evidence obtainable no other way: both repos' suites pass against their own copies whether
or not the copies agree.

The harness is under `tests/_kit/`, never `libs/` (`testing-§1`):

```
$ ls tests/_kit
README.md  framework.lua  loader.lua  mock_base.lua
```

The addon additionally gates this itself — `tests/test_vendor_sync.lua` contributes the cases
"libs/LibKa0s is the LibKa0s release the README says this addon bundles" and "tests/_kit is the test
kit that shipped with that release", both PASS in 0.3.

---

## 1. Evidence for each deviation

### AT-32 — stale `[tests]` badge (MUST)

```
README.md:7:![Tests](https://img.shields.io/badge/Tests-467%2F467_passing-green)
docs/test-cases.md:566:| **Total** | **469** |
```

and the live count from §0.3 above: `469 passed, 0 failed, 469 total`.

`docs/test-cases.md:1-7` declares itself generated and authoritative:

```
docs/test-cases.md:4: lives in. The `## Totals` table below is the **authoritative pass count** — the README test
docs/test-cases.md:5: badge and any count quoted in the docs must agree with it.
docs/test-cases.md:7: **Generated — do not hand-edit.** Regenerate with `lua tests/run.lua --list > docs/test-cases.md`.
```

`docs/testing.md:177-190` restates the same-change rule the badge broke. The inventory itself is
**in sync** with the runner (both read 469); it is only the README badge that drifted, which is
precisely why the standard singles out the two static badges.

### AT-33 — `## What's new` disagrees with Version History (MUST)

`README.md:15-24` — the eight What's-new bullets:

```
README.md:15: ## What's new in 1.9.0
README.md:17: - **Target and Focus absorb bars.** …
README.md:18: - **Each bar is switched on independently.** …
README.md:19: - **Mirror or copy the Player bar's look.** …
README.md:20: - **Slash paths are now fully qualified.** …
README.md:21: - **Show the bar only in combat.** …
README.md:22: - **The bar now updates the instant a shield changes** …
README.md:23: - **A proper on-screen debug window.** …
README.md:24: - **A Debug console toggle on the General page** …
```

`README.md:159` — the 1.9.0 Version History row, which carries four highlights, all of them drawn
from bullets 21–24 and **none** from 17–20:

```
| 1.9.0 | 2026-07-20 | Added a **Show only in combat** option … <br>The bar now redraws the instant
a shield changes … <br>Added an on-screen debug window … <br>Added a **Debug console** toggle … |
```

The three headline features of the release — the target and focus bars, the per-bar enable model,
and the **breaking** fully-qualified slash paths (`README.md:26-28`) — are absent from the row the
standard says must agree with it.

### AT-34 — Profiles page builds an AceGUI widget at registration time (MUST)

```
settings/Profiles.lua:16: local function build(mainCategory)
settings/Profiles.lua:41:     local ctx = H.CreatePanel("AbsorbTrackerProfilesPanel", "Profiles", { … })
settings/Profiles.lua:50:     local container = AceGUI:Create("SimpleGroup")
settings/Profiles.lua:51:     container:SetLayout("Fill")
settings/Profiles.lua:52:     container.frame:SetParent(ctx.body)
settings/Profiles.lua:54:     container.frame:SetPoint("TOPLEFT",     ctx.body, "TOPLEFT",      8, -8)
settings/Profiles.lua:55:     container.frame:SetPoint("BOTTOMRIGHT", ctx.body, "BOTTOMRIGHT", -8, 8)
settings/Profiles.lua:60:     ctx.panel:SetScript("OnShow", function()
settings/Profiles.lua:61:         AceConfigDialog:Open(APPNAME, container)
settings/Profiles.lua:62:     end)
settings/Profiles.lua:68: if NS.RegisterOptionsPage then
settings/Profiles.lua:69:     NS.RegisterOptionsPage("profiles", "Profiles", build)
```

`build` is the page-registry builder, run by the library's `CreateOptionsPanel`, which the host calls
once at `OnEnable`:

```
core/AbsorbTracker.lua:77:     if NS.CreateOptionsPanel then NS.CreateOptionsPanel() end
settings/OptionsSetup.lua:194: NS.CreateOptionsPanel  = function() Helpers.CreateOptionsPanel() end
```

So lines 50–55 execute during the load window. The lazy `OnShow` at line 60 covers only the
`AceConfigDialog:Open`, not the widget creation. This is the only such site in the addon — a grep of
`settings/` for `AceGUI:Create` puts every other call inside a render body reached from first
`OnShow` (`settings/About.lua:30,47,63,80,94`, `settings/UnitPanel.lua:86,106,120,135`), and the
suite's case "a page renders nothing until its first OnShow" PASSes because it cannot reach the
Profiles builder (the page self-skips headlessly — see the PASSing case "the Profiles page
self-skips when AceDBOptions is unavailable").

Rule text: `options-ui-§5` — "MUST build every **body** lazily in the panel's first `OnShow`,
guarded by a `rendered` flag. AceGUI lays children out against the container's **current** width,
which is zero at registration time." And anti-pattern #42 on *when* a shared-library widget is
created deciding how it looks.

### AT-35 — pre-concatenation at the chat seam (MUST)

The seam itself is correct — `NS.Print` is `LibKa0s-Core-1.0`'s printer, which stringifies **each
argument** through the secret-safe stringifier before joining:

```
core/CoreSetup.lua:69: local printer = lib:New({ prefix = function() return NS.PREFIX end, })
core/CoreSetup.lua:77: NS.Print = printer.Print
libs/LibKa0s/Core.lua:242: function printer.Print(...)
libs/LibKa0s/Core.lua:245:   for i = 1, n do parts[i] = lib.SafeToString((select(i, ...))) end
libs/LibKa0s/Core.lua:246:   emit(table.concat(parts, " "))
```

The call sites bypass that per-argument guard by building the line first:

```
settings/Slash.lua:33:   print("  " .. SlashLib.FormatRow(cmd, desc))
settings/Slash.lua:97:   print(("v%s"):format(getVersion()))
settings/Slash.lua:242:  return print(("unknown unit '%s' … %s"):format(token, names))
settings/Slash.lua:246:  return print(("%s bar %s"):format(NS.Units.LABEL[token], on and "shown" or "hidden"))
settings/Slash.lua:282:  print(("Testing display with value: %s for %d s"):format(AbbreviateNumbers(n), hold))
settings/Slash.lua:324:  print("  " .. name .. marker)
settings/Slash.lua:327:  print("Current profile: " .. db:GetCurrentProfile())
settings/Slash.lua:331:  print("Switched to profile '" .. subarg .. "'")
settings/Slash.lua:339:  print("Created and switched to new profile '" .. subarg .. "'")
settings/Slash.lua:346:  print("Copied settings from profile '" .. subarg .. "'")
settings/Slash.lua:356:  print("Deleted profile '" .. subarg .. "'")
settings/Slash.lua:365:  print("Unknown profile subcommand '" .. sub .. "'")
settings/Slash.lua:389:  return function() print("/at " .. verb .. missing) end
settings/Slash.lua:402:  print(("v%s … slash commands"):format(d.version()))
settings/Slash.lua:403:  for _, row in ipairs(stub.LandingRows()) do print("  " .. row) end
settings/Slash.lua:414:  print("unknown command '" .. cmd .. "'")
settings/Schema.lua:214: print("|cffff0000schema error|r: " .. prefix .. ": " .. msg)
```

In each of these `print` is the shared printer (`settings/Slash.lua:21`, `settings/Schema.lua:212`),
so the tag is correct — it is the per-argument secret-stringification that is skipped.

Rule text: `events-frames-taint-§8` — call sites "**MUST NOT** … hand-roll secret handling, or feed
chat/debug args through `..` / `tostring` / `table.concat` before the shared printer … A file that
calls the global `print()`, or pre-concatenates args before the printer, is **non-compliant even if
it is never handed a secret today**."

**Scope note, so the finding is not overstated.** No value at these sites is combat-protected today:
they are AceDB profile names, `NS.Units.LABEL` constants, `tonumber`-parsed user input and library
format strings. The genuinely secret path — `UnitGetTotalAbsorbs` — is handled correctly everywhere
it appears (`modules/Display.lua:192-198` hands the raw value only to C-side sinks;
`core/AbsorbTracker.lua:170` and `:232` fence every debug read behind `NS.IsConcatSafe`). The finding
is that the discipline is applied at the value rather than at the seam.

The remedy already exists in the vendored library and is simply not published by the host:

```
libs/LibKa0s/Core.lua:251: function printer.Format(fmt, ...)
libs/LibKa0s/Core.lua:255:   for i = 1, n do parts[i] = lib.SafeToString((select(i, ...))) end
libs/LibKa0s/Core.lua:256:   emit(lib.SafeToString(fmt):format(unpack(parts)))
```

`core/CoreSetup.lua` publishes `printer.Print` (line 77) and not `printer.Format`.

### AT-36 — retired `§N.M` cross-references (SHOULD)

Full list, from `grep -rnE '§[0-9]+\.[0-9]+|§[0-9]+ ' core modules settings locales defaults docs/ARCHITECTURE.md`
with the already-correct `filename-§N` hits filtered out:

```
core/Namespace.lua:4:         … NS is the addon's single private table (Ka0s standard §4.1);
core/Namespace.lua:9:         Cyan [AT] chat tag — one shared constant … (§7.4).
core/State.lua:4:             … resets on every /reload and fresh login (Ka0s standard §12.5).
core/Constants.lua:11:        Vendored monospace font … used by the debug console (§12.2).
core/Constants.lua:15:        About-page logo. Moved to media/logos/ per §1.4 (typed media subfolders).
core/LSMPatch.lua:3:          … (Ka0s standard §3.5 — extend AceGUI via RegisterWidgetType …)
core/DebugLogSetup.lua:107:   The global gated sink (Ka0s debug-logging §4) …        << half-converted
core/Database.lua:33:         v3 (§2.2/§5.1): bar appearance moved from flat profile keys …
core/Compat.lua:7:            … by reading a game-flavor project id (Ka0s standard §11).
core/AbsorbTracker.lua:9:     AceAddon promotion (Ka0s standard §4.2). …
core/AbsorbTracker.lua:27:    Debug coalescing (§9): per-combat counters …
core/AbsorbTracker.lua:38:    Register the vendored monospace font with LSM … (§12.2).
core/AbsorbTracker.lua:63:    §9.1 deviation (see docs/ARCHITECTURE.md): register them on private frames …
core/AbsorbTracker.lua:79:    … Per debug-logging §5 the session summary …           << half-converted
core/AbsorbTracker.lua:163:   … Gate the debug read so it costs nothing when debug is off (§12.4).
modules/Timer.lua:3:          Coalescing repaint scheduler (Ka0s standard §3.1 …)
settings/Slash.lua:5:         … via AceConsole (Ka0s standard §7.1 — no hand-rolled SLASH_* globals)
settings/Slash.lua:196:       /at debug on|off enables / disables session logging (§12.5).
settings/Slash.lua:199:       … (slash-commands-§: every verb goes through this table …)  << malformed
settings/Schema.lua:200:      … and (Ka0s standard §4.5) any row whose `path` does NOT resolve …
settings/Schema.lua:248:      §4.5: the path must resolve against the defaults profile. …
settings/OptionsSetup.lua:73: AceTimer through the addon object (Ka0s standard §3.1) …
settings/OptionsSetup.lua:81: Ka0s standard §3.4: resolve AceGUI once and read the upvalue. …
settings/About.lua:23:        Deprecated-API access routes through the single Compat shim (… §11).
locales/enUS.lua:4:           … a missing key never errors (Ka0s standard §8). …
locales/enUS.lua:11:          … Keys are the English source strings (§8.2). …
defaults/Profile.lua:5:       … The account-wide one under `global` (Ka0s standard §5.1) …
defaults/Profile.lua:8:       … a deliberate, recorded §5.1 deviation: see the …
defaults/Profile.lua:43:      … a deliberate, documented deviation from Ka0s standard §5.1, which …
docs/ARCHITECTURE.md:316:     - **§9.1 — private `CreateFrame` event frames …**
docs/ARCHITECTURE.md:337:     - **§5.1 — a PER-PROFILE `schemaVersion` stamp …**
docs/ARCHITECTURE.md:380:     … monospace face is required for column-aligned debug output (§12.2).
docs/ARCHITECTURE.md:391:     … Stored under a typed media subfolder per §1.4.
```

(`core/Units.lua:8` also carries `spec §2/§3`, but that references the addon's own multi-unit spec,
not the standard, so it is out of scope for this finding.)

The repo is **mixed**, which is what makes the stale half misleading rather than merely dated — the
same files already use the current form:

```
core/Bus.lua:3,42:             architecture-§4
core/AbsorbTracker.lua:20:     slash-commands-§4
core/AbsorbTracker.lua:211:    options-ui-§2
core/AbsorbTracker.lua:264:    architecture-§4
modules/Timer.lua:62:          architecture-§4
modules/Display.lua:206:       architecture-§4
core/DebugLogSetup.lua:32:     testing-§8
settings/OptionsSetup.lua:139: testing-§8
settings/Schema.lua:177:       library-stack-§4
settings/Schema.lua:188:       testing-§8
settings/Slash.lua:47:         slash-commands-§5
```

Rule text: `STANDARDS.md:40-42` — "`<filename>-§<n>` … This is the **only** cross-reference form —
the old global `§N.M` numbering is retired."

### AT-37 — three sanctioned behaviors listed as open deviations (SHOULD)

```
docs/ARCHITECTURE.md:271: ## Standards Deviations
docs/ARCHITECTURE.md:284: - **A second top-level SavedVariables global — `AbsorbTrackerPerfDB`.** …
docs/ARCHITECTURE.md:291:   **Pending promotion:** … proposes lifting this pattern into WowAddonStandards v2.12.0 …
docs/ARCHITECTURE.md:296: - **`lizard` as an optional dev dependency (complexity reporting).** …
docs/ARCHITECTURE.md:301:   **Pending promotion:** … proposes promoting this into WowAddonStandards v2.12.0 …
docs/ARCHITECTURE.md:306: - **Instrumentation hooks in hot paths.** … `local t0 = Perf.on and debugprofilestop()` …
docs/ARCHITECTURE.md:311:   **Pending promotion:** … proposes promoting this frozen bracket idiom …
```

All three landed. The standard as fetched today:

- `savedvariables-§4` — "savedvariables-§1's 'one global namespace `<Addon>DB`' has exactly **one**
  carve-out: the performance capture ring `<Addon>PerfDB`"; `toc-file-§2` requires exactly the two
  globals the addon declares.
- `performance-§2` — "The mandated form is `local t0 = Perf.on and debugprofilestop()` … `if t0 then
  Perf.Note(key, debugprofilestop() - t0) end`" — the addon's shape, verbatim.
- `performance-§10` — "**SHOULD** run `lizard` … and commit the report as **`docs/complexity.md`**".

Also stale in the same section: the `X-Wago-ID` entry (`docs/ARCHITECTURE.md:277-282`) is written as
though the standard still required an ID for every platform; `toc-file-§1` now makes Wago and WoWI
**MAY**.

### AT-38 — preview mode (SHOULD)

The preview exists as a timed fill:

```
settings/Slash.lua:98:   {"test", "Test display with a fake value — `/at test [value] [hold-secs]`", …}
settings/Slash.lua:265:  function runTest(rest)
settings/Slash.lua:282:      print(("Testing display with value: %s for %d s"):format(AbbreviateNumbers(n), hold))
settings/Slash.lua:291:      NS.testHoldUntil = GetTime() + hold
modules/Display.lua:185:  -- /at test paints a fake value and sets testHoldUntil so this doesn't immediately overwrite it.
modules/Display.lua:186:  if (NS.testHoldUntil or 0) > GetTime() then return false end
```

There is no `locked`-driven preview. Unlocking changes only the unit label and the drag flags:

```
modules/Display.lua:88:  local locked = NS.GetSetting("locked")
modules/Display.lua:89:  bar:SetMovable(not locked)
modules/Display.lua:90:  bar:EnableMouse(not locked)
modules/Display.lua:98:  if locked then unitLabel:Hide() else unitLabel:Show() end
```

Rule text: `preview-mode` — "**SHOULD** trigger the preview automatically while the display is
**unlocked** (drag/reposition mode), and/or via an explicit `/<slash> preview` … **MUST** clear the
preview and return to live data when the display is re-locked or the preview verb is toggled off."
The MUST is satisfied by expiry (`modules/Display.lua:186` stops suppressing once the hold lapses);
the two SHOULDs are not.

### AT-30 — localization seam unused (SHOULD, recurring)

```
locales/enUS.lua:6:  NS.L = setmetatable(NS.L or {}, { __index = function(_, k) return k end })
locales/enUS.lua:8:  -- v1.8.0 ships English-only: user-facing strings (labels, tooltips, slash output, the
locales/enUS.lua:9:  -- reset-confirm popup) are still hardcoded English. The NS.L seam is in place so a future
locales/enUS.lua:10: -- localization pass can wrap them … and drop enUS overrides here
```

Both MUSTs in `localization-§1` (metatable-fallback `NS.L`) and `localization-§3` (ship `enUS.lua`)
are met; no key is populated and no call site wraps. Recorded as deferred at
`docs/pending/LEDGER.md:33` (PLAN-02) and under Known Limitations in `docs/ARCHITECTURE.md`.

### AT-31 — private per-unit event frames (SHOULD, recurring)

```
core/AbsorbTracker.lua:108: function addon:SyncUnitEventFrames()
core/AbsorbTracker.lua:121:     local f = CreateFrame("Frame")
core/AbsorbTracker.lua:133:     f:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", unit)
core/AbsorbTracker.lua:134:     f:RegisterUnitEvent("UNIT_MAXHEALTH", unit)
```

Justification in-code at `core/AbsorbTracker.lua:57-72` and at length in
`docs/ARCHITECTURE.md:316-336`. Rule text: `events-frames-taint-§1` — "**MUST NOT** create
per-module frames just for events (boss-mod-scale hand-rolling is overkill below 1000 events/min)",
whose parenthetical is the exemption the addon claims. Everything else stays on AceEvent
(`core/AbsorbTracker.lua:88-92,145,150`).

### AT-39 / AT-40 / AT-41 — advisory

```
.luacheckrc:7:  exclude_files = { "libs/", "docs/", "_dev/", "tests/" }
                (template names "libs/", "docs/audits/", "docs/reviews/", "_dev/", "tests/")
modules/Bar.lua:6:  -- … as player aliases for the call sites that predate multi-unit
                    -- (core/DebugLog.lua, settings/Slash.lua, the tests).   << file no longer exists
README.md:141: ## Credits and libraries      << not one of documentation-§1's twelve
```

---

## 2. Evidence for the compliance claims

Recorded so the absence of a finding reads as a result rather than an omission.

**LibKa0s consumption — five majors, five seams, all descriptor-plus-stub, none hand-rolled.**
The addon owns no console, no widget maker, no flow engine, no dispatcher, no test framework — there
is no `modules/DebugLog.lua`, no `settings/Widgets.lua`, no `settings/ScrollPatch.lua`. What it owns
is the wiring:

| Module | Seam | Lookup | Descriptor | Stub |
|---|---|---|---|---|
| `LibKa0s-Core-1.0` | `core/CoreSetup.lua` | `:25` | `:69-71` | `:27-59` (the sanctioned second copy of the stringifier — `events-frames-taint-§8` names this the one place it may exist) |
| `LibKa0s-DebugLog-1.0` | `core/DebugLogSetup.lua` | `:14` | `:72-105` | `:16-69` |
| `LibKa0s-Perf-1.0` | `core/PerfSetup.lua` | `:14` | `:33-130` | `:15-31` |
| `LibKa0s-Options-1.0` | `settings/OptionsSetup.lua` | `:36` | `:42-100` | `:140-179` (load-completing — the documented exception) |
| `LibKa0s-Slash-1.0` | `settings/Slash.lua` | `:24` | `:424-452` | `:382-419` |

**Stub coverage, checked against the call sites rather than by reading.**

- *DebugLog.* Members the addon reaches: `Add`, `ConsoleCheckbox`, `Debug`, `IsShown`,
  `MakeCloseButton`, `SetEnabled`, `Show`, `Toggle`. The stub
  (`core/DebugLogSetup.lua:33-67`) answers all eight, plus `Clear`, `Hide`, `IsEnabled`,
  `RefreshHeader`, `ShowCopy`, `UpdateScrollBar`, `UpdateStatus`, `BufferSize`, `LastLine`,
  `FindLine` and a `buffer`. **No gap.** The formatters are deliberately absent with the reason
  written down (`core/DebugLogSetup.lua:30-32`) — a decision, not a gap.
- *Perf.* Members reached from addon code: `on` (`core/AbsorbTracker.lua:165`,
  `modules/Timer.lua:22`, `modules/Display.lua:59,158,190`), `Note` (same files), `suspended`
  (`modules/Timer.lua:48`, `modules/Display.lua:132,144`), `OnCommand`
  (`settings/Slash.lua:202`). The stub (`core/PerfSetup.lua:22-29`) answers all four. `EncodeJSON`
  and `SCHEMA` are reached **only** from `tests/perf.lua:274,297`, which loads the real library, so
  their absence from the stub is correct. **No gap.**
- *Slash.* The stub carries `OnSlash`, `PrintHelp`, `LandingRows`, `SetRowAnnotator` and
  `CliList/Get/Set/Reset/ResetAll` (`settings/Slash.lua:386-418`) — every member
  `settings/Slash.lua` and `settings/About.lua` call — and re-implements none of the library's
  rendering. **No gap.**
- *Options.* Load-completing by design and correct: the measured load-time member set is exactly
  `LSMValues` (`settings/OptionsSetup.lua:147`, with the measurement written up at `:105-139`), and
  `RestoreAllDefaults` is kept as a deliberate recovery path. Not a finding — `AUDIT.md` and
  `options-ui-§1` both name this the documented exception.
- *Core.* The library-absent branch supplies real `IsConcatSafe` / `SafeToString` / `Print`
  implementations rather than no-ops, which `events-frames-taint-§8` explicitly sanctions: "that
  branch is the **only** sanctioned place a second copy may exist, because a printer that answered
  'not installed' instead of printing would silence every line the addon emits."

**AceConsole `:Print` clobber (architecture-§2 / anti-pattern #36) — handled.**

```
core/AbsorbTracker.lua:13: local addon = AceAddon:NewAddon(NS, addonName, "AceEvent-3.0", "AceTimer-3.0", "AceConsole-3.0")
core/AbsorbTracker.lua:25: if NS.Util and NS.Util.print then NS.Print = NS.Util.print end
core/CoreSetup.lua:77-78:  NS.Print = printer.Print ; Util.print = NS.Print   -- same function object
```

The identity is asserted by the suite (`tests/test_slash.lua`, per the comment at
`core/CoreSetup.lua:73-76`).

**Bus receiver clobber (architecture-§4 / anti-pattern #32) — avoided.**

```
core/Bus.lua:43:  function NS.NewBusTarget()  -- fresh AceEvent embed per receiver
modules/Display.lua:214:   local ev = NS.NewBusTarget()
modules/Timer.lua:68:      (receiver on its own target)
core/AbsorbTracker.lua:270: NS.Events.__ev = NS.NewBusTarget()
```

Five messages, one sender each, catalogued at `core/Bus.lua:16-31` and in `docs/ARCHITECTURE.md`
(`## Message Bus`, line 102).

**Combat-secret discipline (events-frames-taint-§8 / anti-pattern #35).**

```
modules/Display.lua:192:  local totalAbsorb = UnitGetTotalAbsorbs(unit) or 0
modules/Display.lua:197:  bar.statusBar:SetValue(totalAbsorb)          -- C-side sink, never tonumber'd
modules/Display.lua:198:  bar.valueText:SetText(AbbreviateNumbers(totalAbsorb))
core/AbsorbTracker.lua:170: if NS.IsConcatSafe(v) then                -- table.concat probe, not `..`
core/AbsorbTracker.lua:232: if NS.IsConcatSafe(v) then
```

**Combat gate — the right function (events-frames-taint-§2).**

```
modules/Display.lua:134: if NS.GetSetting("showOnlyInCombat") and not UnitAffectingCombat("player") then return false end
modules/Display.lua:122-125: (the comment recording the live bug that gating on InCombatLockdown caused)
```

No `InCombatLockdown()` call exists in the addon's own code at all — the panel-open gate lives inside
`LibKa0s-Options-1.0` where `options-ui-§2` requires it, and the addon wires no second open path
(`settings/Slash.lua:65` is the only `config` route).

**Compat firewall (compat).**

```
core/Compat.lua:12-20:  function Compat.GetAddOnMetadata(name, field)  -- the only deprecated-API call
settings/About.lua:25:  return NS.Compat.GetAddOnMetadata(NS.name, field)
settings/Slash.lua:109: return NS.Compat.GetAddOnMetadata(NS.name, "Version") or NS.version or "?"
```

No `WOW_PROJECT_ID` anywhere (`grep` returns nothing outside `libs/`).

**Localized-string matching (localization-§4) — clean.** The only game-entity lookups are
`core/Data.lua:96` and `:131`, both `local _, classFilename = UnitClass("player")` — the
non-localized `classFile` token, which is the *correct* form the section calls out.

**Schema-as-single-source (architecture-§5).**

```
settings/Schema.lua:142: function NS.SetByPath(path, value)   -- the single write seam
settings/Schema.lua:149:   NS.Debug("Set", "%s = %s", …)      -- debug-logging-§10: logged once, here
settings/Schema.lua:224: function NS.ValidateSchema()        -- boot validation, counts exposed for tests
settings/OptionsSetup.lua:51-53: get/set/applyDefault route through it
settings/Slash.lua:435-444:      so do the CLI's get/set/applyDefault
```

**Perf wiring (performance-§1/§2/§3/§5/§6).**

```
core/PerfSetup.lua:42-48:  five buckets, report order, `within = "repaintPass"` nesting declared
core/PerfSetup.lua:55-73:  suspend — unregisters unit frames + lifecycle events, cancels queued work
core/PerfSetup.lua:77-88:  resume — rebuilds from the CURRENT enabled set, not a snapshot
modules/Display.lua:132:   suspend enforced at the source, step 0 of the show-decision ladder
core/PerfSetup.lua:38:     sv = "AbsorbTrackerPerfDB"
.luacheckrc:29:            "AbsorbTrackerPerfDB", -- second SavedVariables global: the perf capture ring
```

Every declared bucket is reached by a live bracket: `absorbEvent` (`core/AbsorbTracker.lua:165,184`),
`repaintPass` (`modules/Timer.lua:22,41`), `paintBar` (`modules/Display.lua:190,202`), `appearance`
(`:59,105`), `visibility` (`:158,165`).

**Testing wiring (testing-§1/§9).**

```
tests/run.lua:21-28:  the 8 vendored LibKa0s files, explicit, in XML order
tests/run.lua:33:     local ADDON_FILES = Loader.tocFiles("AbsorbTracker.toc")
tests/perf.lua:61-65: the same derivation for the ungated runner
tests/test_loadorder.lua:29,38,47,56,64,74,82: the seven cases pinning the derivation itself
tests/perf.lua:220,224: probeOverheadOff / probeOverheadOn — the required zero-overhead scenario
```

**Documentation set (documentation-§2/§3/§6).**

```
CLAUDE.md:1:   # CLAUDE.md — Ka0s Absorb Tracker
CLAUDE.md:3-4: adherence line + repo URL
CLAUDE.md:6-22: ## Standards compliance (read first), verbatim in substance
CLAUDE.md:26-31: the docs pointer list
CLAUDE.md:81:  the green-gate line
CLAUDE.md:39:  "`docs/agent-context.md` does not exist in this repo and MUST NOT be created."
AbsorbTracker.toc:12: ## X-Standard: https://github.com/tusharsaxena/WowAddonStandards
README.md:6:   [![Standard](…)](https://github.com/tusharsaxena/WowAddonStandards)
```

`ls docs/` confirms the trio (`ARCHITECTURE.md`, `testing.md`, `smoke-tests.md`) and the three
required topic docs (`test-cases.md`, `performance.md`, `perf-runs/README.md`). No `agent-context.md`
and no `TODO.md` exist anywhere (`find` returns nothing).

**Packaging / TOC.**

```
.pkgmeta:1:  package-as: AbsorbTracker
.pkgmeta:5-12: ignore: docs, tests, _dev, .luacheckrc, .gitattributes, .gitignore, "*.bak"
             (no externals: block; no enable-toc-creation)
AbsorbTracker.toc:1-13: metadata block, exact field order, single Interface 120007
AbsorbTracker.toc:7:  ## SavedVariables: AbsorbTrackerDB, AbsorbTrackerPerfDB
AbsorbTracker.toc:25: libs\LibKa0s\LibKa0s.xml           -- once, after Ace3, never per-module files
```

TOC final bytes are `…Profiles.lua\r\n` — a single trailing newline (`toc-file-§5`).

**File sizes (layout-§1).** Largest own file `settings/Slash.lua` at 471 LOC; total 3,630 LOC across
28 files. Nothing in the 1000–1500 band.

---

## 3. Not verified

- **`testing-§12` (a test that cannot fail).** Not mechanically auditable — mutation leaves no
  artifact — and the standard explicitly says an audit "**MUST NOT** record its absence as a
  deviation; it records it as *unverified*." Recorded here as **unverified**. The suite does carry
  the practice in places (`tests/test_perf.lua`'s degraded-path load is a real scenario rather than a
  hand-built stub, and several cases name their tripwire), which is a good sign but not proof.
- **In-game behavior.** Nothing in this bundle was observed in a live client. `docs/smoke-tests.md`
  is the complement; AT-34's visual symptom in particular (an unskinned Profiles container) is only
  confirmable in-game.
