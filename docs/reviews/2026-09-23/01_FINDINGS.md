# Review findings — AbsorbTracker (2026-09-23)

**Verdict: minor issues.** Nothing blocking. The addon is in good shape: lint is clean, the suite is 710/710, the offline perf assertions pass, no function is over CCN 15, the vendored LibKa0s and test kit match their source, and the cross-addon pass is clean across all ten addons. The one High is a data-loss edge on a documented verb: `/at profile new <existing name>` wipes that profile without asking. The rest are UX lies on the host-owned slash verbs, a set of test cases that address keys and pages which no longer exist, one comment that describes the disabled state backwards, and some cleanup.

Reviewed at `8f64eb6` on `feat/2026-09-23-review-audit-remediation` (working tree clean apart from this bundle). Addon version 1.10.0, `## Interface: 120100`. Vendored LibKa0s v1.55.0 (per `CLAUDE.md:43`).

Standards cross-check: **performed** against Ka0s WoW Addon Standard **v2.64.0 (2026-09-23)**. The index and all 27 linked section files were fetched verbatim with `curl`.

---

## Measurement run (Step 0: everything in this block was executed today, 2026-09-23)

`ka0s-bounded` is not on `PATH` in this shell, but it is installed at `~/.claude/wow-addon/bin/ka0s-bounded`. Every run below used that full path, so the bounded runner was used, not the `timeout 900` fallback. All commands ran from the repo root. Fresh output went to a scratch directory outside the repo. No committed artifact was written or modified.

| Suite | Result | Command | Counts |
|---|---|---|---|
| luacheck | **pass** | `~/.claude/wow-addon/bin/ka0s-bounded luacheck .` | `0 warnings / 0 errors in 61 files` |
| Headless suite | **pass** | `~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua` | `710 passed, 0 failed, 0 skipped, 710 total` |
| `--list` inventory | **pass** (matches committed) | `~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/run.lua --list > <scratch>/list.md` | 710 cases. `diff <(tr -d '\r' < docs/test-cases.md) <(tr -d '\r' < <scratch>/list.md)` is empty, and the README badge reads `Tests-710%2F710_passing` (`README.md:7`) |
| Offline perf runner | **ran**, all assertions held (exit 0) | `~/.claude/wow-addon/bin/ka0s-bounded lua5.1 tests/perf.lua` | api/iter · bytes/iter: absorbEvent 0.0 · 0.0; paintPass 12.0 · 48.0; appearancePass 48.0 · 97.8; settingsRead 0.0 · 0.0; probeOverheadOff 12.0 · 48.0; probeOverheadOn 12.0 · 48.3 |
| lizard | **pass** (report-only) | `~/.claude/wow-addon/bin/ka0s-bounded lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .` | NLOC 11389, 1639 functions, avg CCN 1.7, **max CCN 14**, 0 warnings. At CCN 14: `S.Set@159-183@settings/Schema.lua` (the degradation stub), `OnAbsorbChanged@195-216@core/AbsorbTracker.lua`, `NS.ResolveColor@53-64@core/CoreSetup.lua` (the degradation stub). All three are dense `and`/`or` defaulting, not tangled control flow |
| `make test` | **skipped** | — | There is no root `Makefile` |
| Vendor sync | **pass** | `diff -r libs/LibKa0s ../LibKa0s/LibKa0s` and `diff -r tests/_kit ../LibKa0s/testkit` | Both empty. The sibling LibKa0s checkout is at `46ccaa6` |
| Cross-addon pass | **pass**, a measured non-finding | the four class commands from the review spec, run from `…/GIT/` over the **ten** roster addons (AbsorbTracker AuraMaster BankLedger ConsumableMaster KickCD LootHistory MultiMeters PanelMaster PrettyChat WhatGroup), scoped to each TOC-derived load list | See the table below |

**Cross-addon detail.** The 2026-09-07 baseline was measured over nine addons. Today's roster has ten, because AuraMaster was added. Every change from the baseline moves the whole collection forward together, so none of it is a collision:

| Class | Today | vs. baseline |
|---|---|---|
| Slash tokens | 20 roots across 10 addons (`am`/`auramaster` added). `cut -f1 roots.txt \| uniq -d` prints nothing. **0** raw `SLASH_*` assignments in loaded source | The same 18, plus AuraMaster's two |
| Vendored minors | One line shared by all 10: `Bus:1 Compat:1 Core:7 DebugLog:12 Env:1 Item:1 Launcher:1 Lifecycle:1 Media:3 Options:23 Perf:12 Pool:3 Schema:1 Slash:14 Widgets:9` | Five new majors, and higher minors on Options, Perf and Slash, identical in every repo |
| Payload bytes | `diff -rq AbsorbTracker/libs/LibKa0s <each>/libs/LibKa0s` is empty for all ten, with AbsorbTracker as the reference | PrettyChat's two known line-ending stragglers are gone |
| `## Interface:` | `120100` in all 10 | The baseline had `120007`; the bump was uniform |

**Committed artifacts that disagree with today's run:**

- `docs/automated-tests/RESULTS.md` is **stale**. It is not non-compliant, because it is regenerated at release. Its newest run is `20260916-184524` (manifest `git.sha` `1080857`, addonVersion 1.10.0), and it says tests `635/0/635`, NLOC 10555, 1479 functions. Today: 710, 11389, 1639. The watch list's over-cap entry, `tests/test_slashcmds.lua` at 1745 LOC, no longer holds: that file is now **1304** LOC and sits in the 1000–1500 band. `tests/test_helpers.lua` is 1416 (the report says 1415). Max CCN is 14 in both.
- `settings/General.lua:209-210` quotes `appearancePass` as "48 WoW API calls and 384.5 bytes per pass … measured 2026-09-08". Today's run measures 48.0 api and **97.8** bytes. The number in the comment is stale (see F-007).
- `docs/test-cases.md` and the README badge agree with today's run. `docs/performance.md` names its scenarios but commits no offline figures, so there is nothing for today's run to contradict.

**LOC census (`layout-§1`), default scope.** Command:

```sh
git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)' | tr '\n' '\0' | xargs -0 wc -l | awk '$2!="total" && $1>1000'
```

Scope: tracked, authored Lua. `tests/` is included; the vendored `libs/` and `tests/_kit/` are excluded. That is 61 files.

Output: `1416 tests/test_helpers.lua` and `1304 tests/test_slashcmds.lua`. **0 files are over 1500**, and 2 are in the on-notice band.

**In-game perf evidence, read but not re-run.** The newest capture is `docs/perf-analysis/20260909-013016/`. It measured the addon's bracketed Lua at **0.1421 ms per second of combat**. Its frame-time delta, +0.262 ms/frame, is unresolved, below the harness's spread. No finding in this bundle is a perf finding.

**In-client checks** are deliberately absent from this block. They are in `03_SMOKE_TESTS.md`.

---

## Conventions detected (the sweep)

- **Prefixed printer:** yes. `NS.PREFIX` (`core/Namespace.lua:10`) goes through LibKa0s-Core's printer (`core/CoreSetup.lua:98-107`), and AceConsole's `:Print` is reclaimed (`core/AbsorbTracker.lua:25`). No raw `print(` bypasses it; every file-local `print` is `NS.Print`.
- **COMMANDS table:** yes. `NS.COMMANDS` (`settings/Slash.lua:61-113`) is dispatched by LibKa0s-Slash-1.0. The README's verbs all exist in the table.
- **Single write path:** yes. `NS.SetByPath` is `LibKa0s-Schema-1.0`'s `S.Set` (`settings/Schema.lua:291`). `units.<unit>.position` is the one named non-setting write (`core/Units.lua:89-92`).
- **Schema:** yes. `settings/Schema.lua` defines flat rows, filled by the page files.
- **Secret-value doc:** `docs/midnight-quirks.md` (there is no `CLAUDE_SECRET_VALUES.md`). The hot paths follow it: the raw value goes straight to `SetValue`/`AbbreviateNumbers`, and the debug path is guarded by `IsConcatSafe`.
- **`.gitattributes`:** `* text=auto eol=crlf`, `*.sh text eol=lf`, and the binaries are marked. `git ls-files --eol` shows 386 files `i/lf w/crlf`, 130 `-text`, and 1 `i/lf w/lf` (`tests/_kit/run-automated-tests.sh`, which is correct). The working tree agrees with the pins. This is an observation only; the authoritative check belongs to `/wow-addon:standards-audit`.
- **Library media:** the one self-drawn mark is the drag handle's help `?`, which comes from `NS.Icon("help")` (`modules/Bar.lua:53`). No second copy of a shipped asset exists under `media/`.
- **LibKa0s majors wired**, as setup file → descriptor/stub:
  - Env → `core/EnvSetup.lua`
  - Media → `core/MediaSetup.lua`
  - Bus → `core/Bus.lua`
  - Core → `core/CoreSetup.lua`
  - Lifecycle → `core/Lifecycle.lua`
  - Perf → `core/PerfSetup.lua`
  - DebugLog → `core/DebugLogSetup.lua`
  - Launcher → `core/LauncherSetup.lua`
  - Schema → `settings/Schema.lua`
  - Slash → `settings/Slash.lua`
  - Options → `settings/OptionsSetup.lua`
  - Widgets is read directly in `modules/Bar.lua:17` and `modules/Display.lua:26`, with no setup file.
- **Stub completeness, checked against call sites.** Every seam member the addon calls was grepped:
  - Perf: `on`, `Note`, `OnCommand`
  - DebugLog: `Add`, `Show`, `IsShown`, `Toggle`, `SetEnabled`, `ConsoleCheckbox`, `Debug`
  - Launcher: `Register`, `SetShown`
  - lifecycle: `Set`, `IsDown`, `Holds`, `Reevaluate`
  - bus record: `NewTarget`, `StandDown`, `StandUp`
  - Slash cli: `CliList`, `CliGet`, `CliSet`, `CliReset`, `DisabledLine`, `LandingRows`, `OnSlash`, `PrintHelp`, `SetRowAnnotator`

  Every degradation stub answers every member called on it. **No gap was found.**
- **Test kit:** `tests/_kit/` is vendored. The runner derives the load list from the TOC (`Loader.tocFiles`), and `Kit.run{dir=…}` asserts the suite inventory.
- **Evidence present:** `tests/run.lua` plus 28 suites (three of them from the kit); `docs/test-cases.md`; `tests/perf.lua`; `docs/performance.md`; `docs/perf-analysis/` (2 bundles plus `README.md`); `docs/automated-tests/` (11 bundles plus `RESULTS.md`).

---

## High

### F-001 — `/at profile new <name>` silently wipes an existing profile of that name `[ux]` `[data-loss]`

- **Where:** `settings/Slash.lua:431-435`
  ```lua
  new = needsName("new", function(db, name)
      db:SetProfile(name)
      NS.ResetProfileCounted(db)
      print("Created and switched to new profile '" .. name .. "'")
  ```
  The help row says `{ "new <name>", "Create new profile with defaults" }` (`settings/Slash.lua:383`). `docs/profiles.md:79` says the same.
- **Problem:** When `<name>` is an existing profile, `SetProfile` switches to it and `ResetProfile` then empties it. The chat line still says "Created … new profile". The comment above the verb (`settings/Slash.lua:427-430`) admits this ("`new` on a name that already exists resets that profile"), but neither the help, the docs nor the output tells the player.
- **Impact:** Every setting in that profile is discarded, with no confirmation and a message that says the opposite of what happened. The panel's own profile reset asks for confirmation; this CLI path does not.
- **Reachability:** Any player who types the documented `/at profile new` with a name already in their list, for example re-typing `Raid` after forgetting it exists, on any install with AceDB.
- **Why High and not Critical:** The defect kind is data loss, but it takes an explicit player action naming that exact profile, the verb's own comment calls it intended, and only one profile is affected. It is graded as a broken UX flow with a destructive side effect.
- **Coverage:** `tests/test_slashcmds.lua:544` covers only a fresh name. No case covers `new` on an existing name.
- **Fix direction:** Refuse when the name is already in `db:GetProfiles()`. Print one line naming `/at profile use <name>` and `/at profile reset` instead. This is host code, not library code (`slash-commands-§3`: the COMMANDS table and its handlers are the host's).

---

## Medium

### F-002 — `/at profile copy` raises on a typo, and `/at profile delete` reports deleting a profile that does not exist `[ux]`

- **Where:** `settings/Slash.lua:437-448`. `copy` calls `db:CopyProfile(name)` bare, and `delete` calls `db:DeleteProfile(name, true)`, then `print("Deleted profile '" .. name .. "'")`.
- **Problem:** The real AceDB raises for a missing source and for self-copy. `libs/AceDB-3.0/AceDB-3.0.lua:581-587` has `error(("Cannot have the same source and destination profiles (%q)."):format(name), 2)` and `error(("Cannot copy profile %q as it does not exist."):format(name), 2)`. `DeleteProfile` with `silent = true` on a missing name does nothing (`:535`), yet the verb prints "Deleted profile".
- **Impact:** `/at profile copy Raidd` (typo) or `/at profile copy <current>` throws a Lua error out of the slash handler and prints nothing useful. `/at profile delete Raidd` tells the player a profile was deleted when none was. No data is lost: AceDB raises before its reset.
- **Reachability:** Any player who mistypes a profile name on either documented verb.
- **Coverage:** Asleep. `tests/test_slashcmds.lua:560` and `:589` pass against the kit's AceDB fake, which returns silently on both error paths (F-006). A probe run on a scratch copy of the tree printed `PROBE-COPY-MISSING: … [AT] Copied settings from profile 'NoSuchProfile'` and `PROBE-DELETE-MISSING: … [AT] Deleted profile 'NoSuchProfile'`. The suite cannot see this defect.
- **Fix direction:** Check the name against `db:GetProfiles()` (and against `GetCurrentProfile()` for `copy`) before calling AceDB, and print a `Profile '<name>' not found` line. Do not wrap the call in `pcall`: checking up front says why, where a `pcall` swallows the reason.

### F-003 — `/at lock` and `/at unlock` print a fixed acknowledgement that can contradict what was stored `[ux]`

- **Where:** `settings/Slash.lua:89-98`. The `lock` handler runs `NS.SetByPath("locked", true)` then `print("Bar locked")`. The `unlock` handler runs `NS.SetByPath("locked", false)` then `print("Bar unlocked")`.
- **Problem:** The `locked` row's onChange refuses an unlock in combat by writing `true` back (`settings/General.lua:180-188`), and the verb then prints its own success line anyway. The verbs also skip `NS.RefreshOptionsPanel()`. The other verbs that write through the seam call it: `setEnabled` (`:312`), the descriptor `set` (`:600-603`), and the launcher click (`core/LauncherSetup.lua:164`). Separately, the text says "Bar" when it covers three bars, while the combat line says "Bars locked" (`core/AbsorbTracker.lua:260`).
- **Impact:** In combat, `/at unlock` prints `[AT] Cannot unlock the bars during combat` followed by `[AT] Bar unlocked`, and the bars stay locked. This was confirmed on a scratch copy: `PROBE-UNLOCK: locked=true out=[AT] Cannot unlock the bars during combat | [AT] Bar unlocked`. With the panel open, the Lock frame checkbox shows the old value after either verb.
- **Reachability:** Any player who types `/at unlock` during a fight. The stale checkbox affects anyone who uses the verbs with the settings panel open.
- **Standard:** `slash-commands-§8` says the verbs **SHOULD** confirm on one line in `slash-commands-§5`'s `set` shape, read back from the store. `setEnabled` (`settings/Slash.lua:310-317`) already shows how.
- **Coverage:** `tests/test_slashcmds.lua:98-106` asserts `contains(out, "Bar unlocked")` outside combat only. `tests/test_display.lua:609` covers the refusal through `SetByPath`, not through the verb.

### F-004 — Several `/at` and profile tests address a flat key and page names removed three releases ago `[tests]`

- **Where:** `tests/test_slashcmds.lua`:
  - `:224-225`, `:371`, `:552`, `:574` call `NS.Helpers.RestoreDefaults("bar")` and `("border")`. `VALID_PAGES` is `{ general, appearance, profiles }` (`settings/Schema.lua:397`), so these calls reset nothing.
  - `:545-548` runs `T.rawSet("barWidth", 456)` and then `assertEqual(NS.GetSetting("barWidth"), NS.flatDefaults.barWidth, …)`.
  - `:604-606` does the same with 478.
- **Problem:** `barWidth` has been a per-unit key since schema v3 (`defaults/Profile.lua:32`, under `units.<unit>`), so `NS.flatDefaults.barWidth` is `nil`. The `profile new` case at `:548` therefore asserts `nil == nil` about a key no schema row owns. A `new` that carried over `units.player.barWidth` (the real setting) would still pass. The "cleanup" calls are no-ops, so the per-unit writes these cases make (for example `units.target.barWidth = 300` at `:218`) leak into later suites.
- **Impact:** Two cases read as coverage of "a new/reset profile starts from defaults" but test a dead key. The suites become order-dependent through the leaked state. This is the `testing-§12` class.
- **Reachability:** Test inventory only. The shipped code is not implicated. Capped at Medium.
- **Fix direction:** Assert on `units.player.barWidth` against `NS.unitDefaults.barWidth`. Replace the page-name cleanups with `RestoreDefaults("appearance")`. Each rewritten case needs a `-- red under:` note naming the mutation that reddens it.

### F-005 — The comment on `/at enable`/`disable` describes the draw gate this addon removed `[naming]`

- **Where:** `settings/Slash.lua:296-304`: "the row's `onChange` -- VISIBILITY then REPAINT (settings/General.lua)" and "`enabled` gates NS.ShouldShowBar's second rung and nothing else: no file unloads, no event registration changes".
- **Problem:** Both statements are the opposite of the code. The row's onChange is `NS.SyncEnabledHold()` (`settings/General.lua:145`), which moves the `disabled` hold on the lifecycle latch. `StandDown` (`core/Lifecycle.lua:79-106`) unregisters every event, frame and bus registration. The show ladder's rung 0 asks the latch, not the setting (`modules/Display.lua:327`).
- **Impact:** A maintainer who trusts this comment is being told the draw gate (`anti-patterns` #85, `slash-commands-§7`) is the design. It sits on the exact verbs that drive the stand-down.
- **Reachability:** A comment; no runtime effect. It is graded Medium rather than Low because it misstates the addon's most load-bearing invariant at its entry point.

---

## Upstream findings (these do NOT land in this repo)

### F-006 — `[upstream]` The kit's AceDB fake returns silently where real AceDB raises `[tests]`

- **Owning library:** LibKa0s, test kit. The file is `testkit/mock_record.lua`, vendored here as `tests/_kit/mock_record.lua:257-270`:
  ```lua
  db.CopyProfile = function(_, name)
    local src = sv.profiles[name]
    if not src or name == current then return end
  ...
  db.DeleteProfile = function(_, name)
    if name == current then return end
  ```
- **Problem:** Real AceDB-3.0 raises on a missing source, on self-copy (`AceDB-3.0.lua:581-587`), on deleting the active profile (`:531-533`), and on deleting a missing profile when not silent (`:535-537`). The fake silently no-ops every one of these. That breaks the kit's own fidelity rule 5, "model the awkward real behavior, not the convenient one" (`tests/_kit/mock_base.lua:26`).
- **Impact:** Any consumer's profile verbs look correct against the fake while raising in the client. That is exactly how F-002 stays green here.
- **Reachability:** Test inventory only, in every consumer that uses the fake. Capped at Medium.
- **Remediation:** Fix it in the LibKa0s repo: make the fake raise with AceDB's messages and levels, bump the kit revision, then re-vendor the whole `testkit/` folder into this addon and every other consumer, as its own commit. **This is not a local edit to `tests/_kit/`.** Local consequence: after the re-vendor, `tests/test_slashcmds.lua:560`/`:589` keep passing, and new red-first cases for F-002 go red for the right reason.

---

## Low

### F-007 — Stale or misplaced comments `[naming]`

Each line below was re-read today. All are comment-only, with no runtime effect.

- `settings/General.lua:21` draws `[Test mode]` in the page diagram, and `:41-43` says "this addon draws all nine rows … That includes Test mode". `:109-110` and `:168-172` say the addon declares no `testModePath` and ships no Test mode row, and the code agrees.
- `settings/General.lua:73-79`: the "console toggle's stored path" comment sits above `unlockGuard`, not above `DEBUG_CONSOLE_PATH` (`:80`).
- `settings/General.lua:209-210` quotes "384.5 bytes per pass (… `appearancePass`, measured 2026-09-08)". Today's run measures 97.8.
- `settings/General.lua:308-309` says the throttle is read as ``NS.GetSetting("throttleWindow")` at modules/Timer.lua's ScheduleTimer call``. The call is `NS.GetThrottleWindow()` (`modules/Timer.lua:61`), which clamps it.
- `core/PerfSetup.lua:11-13` says "this file sits immediately after core/CoreSetup.lua in the TOC", and `core/CoreSetup.lua:12-14` says "everything below it — core/PerfSetup.lua first". In the TOC, `core\Lifecycle.lua` sits between them (`AbsorbTracker.toc`, the Core block).
- `core/AbsorbTracker.lua:114-117` says the perf probe's `Resume()` restores what `Suspend()` tore down "(core/PerfSetup.lua)". Suspend and resume are now the latch's `StandDown`/`StandUp` (`core/Lifecycle.lua`), and `core/PerfSetup.lua:76-88` says so.
- `defaults/Profile.lua:145` names `settings/{Bar,Border,Font}.lua`, which were merged into `settings/Appearance.lua`.
- `core/Constants.lua:56-66`: the `MINIMAP_PATH` comment is split from its constant (`:77`) by the whole `BRAND` block (`:67-75`).
- `docs/ARCHITECTURE.md:655` (the localization register row) says the refusal left "at LibKa0s v1.41.0". `docs/ARCHITECTURE.md:570` and `locales/enUS.lua:16` say v1.42.0.

### F-008 — `.luacheckrc` allowlists eight globals no source reads `[lint]`

- **Where:** `.luacheckrc`, top-level `read_globals`: `C_Timer`, `hooksecurefunc`, `CreateColor`, `PlaySound`, `strsplit`, `strtrim`, `tinsert`, `tremove`.
- **Evidence:** Each name was grepped over tracked authored Lua (`git ls-files '*.lua' | grep -vE '^(libs/|tests/_kit/)'`). Seven have 0 hits. `C_Timer`'s one hit is a comment (`settings/OptionsSetup.lua:144`).
- **Impact:** A future stray `hooksecurefunc` or `C_Timer` call would lint clean. The second one bypasses `library-stack-§1`'s AceTimer rule unnoticed.
- **Reachability:** Lint configuration only.

### F-009 — A second literal of the brand string `[design]`

- **Where:** `settings/OptionsSetup.lua:26` has `local PARENT_TITLE = "Ka0s Absorb Tracker"`. `core/Constants.lua:67`/`:75` declare `C.BRAND = "Ka0s Absorb Tracker"` with the claim "there is exactly one of it".
- **Impact:** The Settings category title and the launcher/refusal brand can drift apart on the next rename.
- **Reachability:** No behavior today; the two strings are equal.

### F-010 — The profile-adopt path runs a redundant latch re-evaluation and double-publishes on an enable edge `[design]` `[perf]`

- **Where:** `core/AbsorbTracker.lua:317-323` runs `NS.SyncEnabledHold()` and then `NS.lifecycle:Reevaluate()`.
- **Problem:** `SyncEnabledHold` calls `lifecycle:Set`, which already re-evaluates, so the second call is always a no-op. When the switch crosses the enabled edge, `StandUp` (`core/Lifecycle.lua:123-131`) publishes POSITION, VISIBILITY, APPEARANCE and REPAINT, and `adoptProfile` then publishes UNITS, POSITION, APPEARANCE and REPAINT again. That is two full three-bar appearance passes, about 48 API calls each by today's `appearancePass` figure.
- **Reachability:** Any profile switch, copy or reset that changes `enabled`. It is rare and cold-path.

### F-011 — `/at test <value> [secs]` does not validate the duration `[ux]`

- **Where:** `settings/Slash.lua:336` reads `local hold = tonumber(args[2]) or 5`, and `:349` announces it with `"… for %d s"`.
- **Problem:** A negative or zero duration is accepted and announced as-is (`for -3 s`). A fractional one is announced truncated (`2.5` is announced as `2 s` but held for 2.5 s).
- **Reachability:** A player who types an odd second argument to a diagnostic verb.

### F-012 — Dead fallback in the schema runtime's printer, with a second copy of the prefix `[design]`

- **Where:** `settings/Schema.lua:233-239`, the `elseif DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cFF00FFFF[AT]|r " .. line)` branch.
- **Problem:** `NS.Print` is defined on both arms of `core/CoreSetup.lua` (`:67`, `:106`), which loads before this file, so the branch cannot run. It carries a hand copy of `NS.PREFIX` (`core/Namespace.lua:10`).
- **Reachability:** Unreachable in any configuration.

### F-013 — Test-only aliases published on the production namespace `[tests]`

- **Where:** `modules/Bar.lua:169-172`: `NS.bar`, `NS.statusBar`, `NS.valueText`, `NS.backdropInfo`. The file's own comment says no production caller remains and the tests are the only readers.
- **Impact:** Four exported names that production must never use. A production caller added by mistake would lint and test clean.
- **Reachability:** No runtime effect.

---

## Things checked and found clean

- **Disabled state (`slash-commands-§7`, anti-pattern #85):** one latch with two holds (`core/Lifecycle.lua`). `StandDown` unregisters the three per-unit frames, the five AceEvent registrations and the bus record, and cancels the repaint timer and the preview timer. The ladder's rung 0 asks the latch. The launcher's left click is refused with the dispatcher's line. `tests/test_disabled.lua` asserts on the mock's registration set. The kit mocks record `RegisterUnitEvent` and `UnregisterAllEvents` (`tests/_kit/mock_base.lua:206-227`), and the suite has a falsification half (`__fireUnconditional`).
- **Perf wiring:** five declared buckets, each reached by a bracket (`core/AbsorbTracker.lua:196/215`, `modules/Timer.lua:22/48`, `modules/Display.lua:167/268`, `:357/367`, `:419/437`). `within` matches the call graph. The dormant bracket is `Perf.on and debugprofilestop()` through a load-time upvalue. `probeOverheadOff` and `probeOverheadOn` agree (48.0 vs 48.3 bytes, 12 vs 12 api).
- **Taint:** no secure frames, no protected calls, no hooks. Unlock is refused in combat, and combat re-locks.
- **Events:** `RegisterUnitEvent` per unit (a ratified deviation); nothing is registered in `OnInitialize`; no deprecated events.
- **SavedVariables:** `AbsorbTrackerDB` and `AbsorbTrackerPerfDB`. The migration ladder is idempotent and sweeps every profile. The minimap row is exempt from resets.
- **Deprecated APIs:** none in authored code. `GetAddOnMetadata` appears only as the last rung behind `C_AddOns` (`core/EnvSetup.lua:67-72`).
