# 06 — Execution Outcome (remediation build)

**Addon:** Ka0s Absorb Tracker · **Standard:** v1.0.0 (2026-07-12) · **Run:** 2026-07-12

Outcome of executing `04_TECHNICAL_DESIGN.md` (Themes A–H) and `05_EXECUTION_PLAN.md`
(Sprints 0–7). The addon was migrated from a flat `AddonTable` / raw-frame / `PLAYER_LOGIN`
design onto the Ka0s standard's Tier-2 Ace substrate **without changing runtime behavior**. The
schema-as-single-source and options-UI surfaces (the addon's strongest areas, §4.5/§6) were
preserved and re-seated, not rewritten.

## Result at a glance

| Metric | Before | After |
|---|---|---|
| Deviations (MUST / SHOULD) | 21 / 4 | **all 25 addressed** (24 fully closed; AT-05 Curse-only by decision) |
| Test harness | none | `tests/` — **36 tests, all green** |
| Lint | none | `luacheck .` — **0 warnings / 0 errors** (27 files) |
| Syntax check | — | `luac -p` — **all 35 source files parse** |
| Layout | flat root + `Options/` `Panel/` | Tier-2 `core/ defaults/ locales/ modules/ settings/` |
| Namespace | `AddonName, AddonTable` | `addonName, NS` (AceAddon) |
| Root docs | README + CLAUDE(brief) + ARCHITECTURE | README + **CLAUDE stub** + LICENSE (ARCHITECTURE → `docs/`) |

**Deviation closure (independently re-audited):** all 25 addressed — 24 fully CLOSED and **AT-10**
subsequently closed (`NS.AceGUI` stashed once, builders read the upvalue). AT-05 is satisfied for
the published platform (CurseForge) with the Wago line intentionally omitted (not published there).
**A separate adversarial correctness review found no BLOCKERs and no RISKs** — the re-seat is
behavior-preserving.

> **No version bump, no git staging/commit.** Per project rules, `## Version:` stays `1.8.0` and
> the git index was not touched. Files are changed on disk only; staging/commit/push is your call.

---

## What was built, by sprint

- **Sprint 0 — Safety net (AT-20/21/22).** `.pkgmeta` (no `externals:`), `.luacheckrc`
  (std lua51, libs/audit/tests excluded, addon WoW-API `read_globals`, `AbsorbTrackerDB` +
  `StaticPopupDialogs` write-globals), and a headless Lua 5.1 harness: `tests/run.lua` +
  `loader.lua` + `wow_mock.lua` + five suites.
- **Sprint 1 — SavedVariables correctness (AT-07/13).** `defaults/Profile.lua` adds
  `NS.defaults.global.schemaVersion = 1`; `core/Database.lua` ships `NS:RunMigrations` (idempotent
  version seam; v1 folds the old inline flat→profile backfill into a versioned, twice-safe step).
  `NS.ValidateSchema` now resolves every row `path` against `defaults.profile` and returns
  `errors, resolved, missing` for the harness to assert.
- **Sprint 2 — Ace3 substrate re-seat (AT-08/12/17/14/10).** Vendored `AceEvent-3.0`,
  `AceTimer-3.0`, `AceConsole-3.0`. `core/AbsorbTracker.lua` promotes `NS` via
  `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0","AceTimer-3.0","AceConsole-3.0")`. DB init →
  `OnInitialize`; the old `PLAYER_LOGIN` body → `OnEnable` (identical order). Events →
  `self:RegisterEvent`; ticker → `NS.addon:ScheduleRepeatingTimer`/`CancelTimer` (interval guard
  kept); slash → `AceConsole:RegisterChatCommand("at"/"absorbtracker")` with the schema-driven
  dispatcher body unchanged.
- **Sprint 3 — Tier-2 layout & rename (AT-01/02/11).** Files relocated into
  `core/ defaults/ locales/ modules/ settings/`; `Options/` + `Panel/` folded into `settings/`;
  `AddonName, AddonTable` → `addonName, NS` repo-wide (0 residual `AddonTable`).
- **Sprint 4 — TOC finalize (AT-04/05/06/09).** `IconTexture` case fixed; added `X-Standard`
  and `X-Curse-Project-ID: 1450165` (no `X-Wago-ID` — not published there); `OptionalDeps`
  reordered; libs re-vendored **folder-per-lib** at `libs/` root (no `libs/Ace3/`); file listing
  sectioned `# Libraries / # Core / # Defaults / # Locales / # Modules / # Settings`, single
  trailing newline.
- **Sprint 5 — Locales / Compat / prefix (AT-16/18/15).** `locales/enUS.lua` metatable-fallback
  `NS.L`; `core/Compat.lua` single `GetAddOnMetadata` shim (both inline copies removed); shared
  `NS.PREFIX` in `core/Namespace.lua` (no `local PREFIX`).
- **Sprint 6 — Media & debug console (AT-03/19).** Logo moved to `media/logos/`, LOGO_PATH
  repointed via `NS.Constants`; `core/DebugLog.lua` on-screen console (ScrollingMessageFrame,
  session-only `NS.State.debug`, `FormatPlain`/`FormatColored`, Copy/Clear, ESC-closes) using the
  vendored `media/fonts/JetBrainsMono-Regular.ttf` (+ `OFL.txt`).
- **Sprint 7 — Docs (AT-23/24/25).** Root `CLAUDE.md` reduced to a tier-declaring stub; the full
  brief moved to `docs/agent-context.md`; `ARCHITECTURE.md` → `docs/ARCHITECTURE.md` in §15.3
  section order; README normalized to §15.1 with an X-Standard badge and a new `## Testing`
  section; `docs/` topic files refreshed to the new layout.

## New file tree (source)

```
core/     Compat  Constants  Namespace  State  Util  Data  Database  LSMPatch  DebugLog  AbsorbTracker
defaults/ Profile
locales/  enUS
modules/  Bar (frame build)  Display (paint)  Timer (AceTimer ticker)
settings/ Schema  Slash  Panel  Helpers  ScrollPatch  Widgets  About  General  Bar  Border  Font  Profiles
tests/    run  loader  wow_mock  test_schema  test_database  test_compat  test_debuglog  test_slash
libs/     LibStub CallbackHandler-1.0 AceAddon/Event/Timer/Console/DB/DBOptions/Config/GUI-3.0 LibSharedMedia-3.0 AceGUI-3.0-SharedMediaWidgets
```

## Deviation notes

- **AT-10 (SHOULD) — closed.** `NS.AceGUI` is stashed once in `CreateOptionsPanel`
  (`settings/Panel.lua`), set before any builder runs; the 12 panel-toolkit / widget / about-page
  builders read the upvalue instead of re-`LibStub`-ing AceGUI per call.
- **AT-05 (MUST) — Curse-only, documented deviation.** `## X-Curse-Project-ID: 1450165` is present;
  `## X-Wago-ID` is intentionally omitted because the addon is not published on Wago (the standard
  requires the ID only *if published there*). This is your decision, recorded as an accepted
  deviation rather than a gap.

---

## Test harness

Headless, no WoW client required. Targets **Lua 5.1** (matches the in-game runtime).

**Files**

| File | Role |
|---|---|
| `tests/run.lua` | Runner + micro-framework (`test`, `assertEqual`, `assertTrue`, `assertFalse`). Loads every source in TOC order through the loader, calls `NS:InitDB()`, `dofile`s each suite, runs each under `pcall`, prints PASS/FAIL, exits non-zero on any failure. |
| `tests/loader.lua` | Loads each source with `loadfile` + `setfenv(chunk, env)` where WoW globals resolve to the mock set first, falling back to `_G`; calls each chunk as `chunk("AbsorbTracker", NS)` to reproduce `local addonName, NS = ...`. Writes (SavedVariables / StaticPopupDialogs registration) land in `_G`. |
| `tests/wow_mock.lua` | Fresh-per-run WoW-API mock builder: self-returning no-op frame stub, `CreateFrame`/`UIParent`/`Settings.*`/`DEFAULT_CHAT_FRAME`/`StaticPopupDialogs`, absorb/health/class APIs (`UnitGetTotalAbsorbs`, `UnitHealthMax`, `AbbreviateNumbers`, `UnitClass`, `C_ClassColor`), and `LibStub` with fakes for `AceDB-3.0` (returns `{global, profile}` deep copies) and `AceAddon-3.0` (`NewAddon` stamps `RegisterEvent`/`RegisterChatCommand`/`ScheduleTimer`/`ScheduleRepeatingTimer`/`CancelTimer`). |

**Suites (36 tests total)**

| Suite | Covers |
|---|---|
| `test_schema.lua` (9) | `ParseSchemaValue` bool/number-clamp/color(0-1 & 0-255)/string-allowlist; `FormatSchemaValue` per type; `SchemaForPage` group-registration ordering (Size→Bar→Background); `ValidateSchema` path-vs-defaults resolution (0 errors/0 missing on real schema; planted bad path reported; invalid page/type flagged). |
| `test_database.lua` (8) | `RunMigrations` stamps `schemaVersion`, is idempotent across repeated runs, backfills missing scalar & table keys (deep-copy, no shared ref), never overwrites a user value, no-ops safely with no DB; `InitDB` yields a profile carrying every default key. |
| `test_compat.lua` (4) | `Compat.GetAddOnMetadata` prefers `C_AddOns`, falls back to global, returns nil when neither present; single-accessor guarantee. |
| `test_debuglog.lua` (10) | `FONT_MONO` path shape; pure `FormatPlain`/`FormatColored`; `/at debug on|off` set session state; bare `/at debug` toggles the window (not state); header-toggle click flips state; `NS.Debug` is a no-op when off. |
| `test_slash.lua` (6) | Help index = header + one row per command; unknown verb → `unknown command '<verb>'` + help; `/at get` schema read; `/at set` write-through + path-case preservation; out-of-range clamp; `/at options`→`config` alias. |

**Commands** (run from the repo root; all must be clean before shipping):

```
lua tests/run.lua      # 36 passed, 0 failed
luacheck .             # 0 warnings / 0 errors (27 files; libs/ audit/ tests/ excluded)
luac -p <file>         # syntax-check one file (or loop over all non-lib .lua)
```

Run all three before tagging a release, and after bumping `## Interface:` or refreshing libs.
Toolchain: `sudo apt-get install -y lua5.1 luarocks && sudo luarocks install luacheck`.

---

## Manual in-game smoke tests

Run on a **live Retail (Midnight, 12.0.7) client** in order. Enable Lua errors first
(`/console scriptErrors 1`, or BugSack/BugGrabber). Watch chat for the cyan `[AT]` prefix and for
any red error frame. This suite also lives at `docs/smoke-tests.md`.

### A. Load & bootstrap
1. **Fresh login.** Delete `WTF/.../SavedVariables/AbsorbTrackerDB.lua`, log in → world reached, **zero Lua errors**.
2. **Bar appears.** A single absorb bar is visible at screen center (default look); shows the value / `0`.
3. **/reload clean.** `/reload` → no errors; bar reappears in the same spot.
4. **Value tracks reality.** Gain an absorb (e.g. Power Word: Shield) → fill + text update to the abbreviated amount; consume it → drops toward `0`.
5. **Secret-value safety.** With a big absorb, the number shows an abbreviated string (e.g. `1.2M`), never `nil`/error.

### B. Slash surface
6. `/at` alone → help block (version line + command list).
7. `/absorbtracker` → identical help block.
8. `/at help` → gold command + em-dash + white desc for all 15 verbs: help, config, list, get, set, reset, resetall, resetposition, lock, unlock, toggle, debug, update, test, profile.
9. `/at wibble` → `unknown command 'wibble'` then help.
10. `/at options` → opens the panel (back-compat alias for `config`).

### C. Settings panel & combat gate
11. `/at config` (out of combat) → Blizzard Settings opens to **Ka0s Absorb Tracker**, tree expanded to General/Bar/Border/Font/Profiles.
12. **Combat gate.** In combat, `/at config` → panel does **not** open; chat shows `[AT] Cannot open settings panel during combat…`.
13. Drop combat, `/at config` → opens normally, no taint warning.

### D. Sub-pages render & edit live
14. **General** — Show Bar / Lock Position, Reset Position + Reset All buttons, Update Interval slider. Toggle Show Bar → bar hides/shows; Lock Position → drag disabled; drag Update Interval → ticker cadence changes.
15. **Bar** — Width/Height, Bar Texture (LSM), Bar Color, Use Class Color; Background Texture/Color/Use Class Color. Drag Width → widens live; change Texture/Color → live.
16. **Border** — Style (LSM), Thickness, Use Class Color, Color. Change Style → edge changes; drag Thickness → grows/shrinks (inset recomputes, no glitch).
17. **Font** — Face (LSM), Size, Outline (solo dropdown, 6 flags). Change Face/Outline → text updates live.
18. **Profiles** — AceDBOptions UI renders **inside** the canvas panel (Current/New/Copy/Reset/Delete + scopes), no error.
19. **Page Defaults button** — change Bar values, click Defaults → only Bar reverts; panel refreshes.
20. **Reset All popup** — General → Reset All Settings → confirm popup → Yes → General/Bar/Border/Font revert, `[AT] All settings reset to defaults.`, Profiles untouched.

### E. LSM border-widget alignment fix
21. Border page, **Border Style** dropdown closed → left edge flush with neighbors, **no ~42px gap** (LSMPatch suppresses the displayButton tile).
22. Open the dropdown → per-row hover border previews still render; selecting applies.

### F. Slash verbs — read/write/reset
23. `/at list` → grouped `[general]/[bar]/[border]/[font]`, each `path = value` formatted.
24. `/at get barWidth` → `barWidth = <n> px`; `/at get bogus` → not found; `/at get` → usage.
25. `/at set barWidth 260` → `barWidth = 260 px`, bar widens, open panel refreshes; path case preserved.
26. `/at set barWidth abc` → `Invalid value for barWidth`; bar unchanged.
27. `/at reset bar` → `bar page reset to defaults`, reverts + repaints; `/at reset bogus` → unknown page.
28. `/at resetall` → all pages revert **and** bar returns to center (position cleared).
29. `/at resetposition` → bar snaps to center; other settings unchanged.
30. `/at lock` / `/at unlock` → locks/unlocks dragging; dragged position persists across `/reload`.
31. `/at toggle` → hides/shows the bar.
32. `/at update` → `Forced refresh`; repaints from live absorb.
33. `/at test` → shows `50K` for 5s then reverts; `/at test 250000 3` → `250K` for 3s.
34. `/at test` while hidden → `Bar is hidden; run /at toggle to show it…`.

### G. Profiles — switch repaints the bar
35. `/at profile list` / `current` → lists / prints current.
36. `/at profile new SmokeTest` → switches to a defaults profile; bar repaints to default, ticker restarts.
37. On SmokeTest `/at set barWidth 400`, then `/at profile use Default` → bar repaints to the original width (validates `OnProfileChanged`).
38. `/at profile copy SmokeTest` → copies + repaints.
39. `/at profile delete <current>` → refused; switch away, delete SmokeTest → deleted.
40. **Panel-driven switch** — Profiles page dropdown switch → bar repaints live.

### H. Debug console (§12)
41. `/at debug` → **Absorb Tracker — Debug** window appears (dark, draggable); `/at debug` again → hides.
42. Log lines render in a **monospace** font (JetBrains Mono).
43. `/at debug on` → `[AT] debug on`, header **Debug: ON** (green); trigger an absorb change → timestamped `[tag] msg` lines (steel-blue ts, tan tag).
44. `/at debug off` → `[AT] debug off`, header **Debug: OFF** (red); new changes no longer append.
45. Header **Debug** toggle button → flips state exactly like the slash verb.
46. **Copy** → opens a monospace EditBox with the plain-text log highlighted (Ctrl+C, then Esc).
47. **Clear** → empties the log view and the copy buffer.
48. **Esc** → closes the debug window (and the Copy window); both in `UISpecialFrames`.
49. `/at debug on`, then `/reload` → console hidden and logging OFF (session-only state resets).

### I. SavedVariables migration — no-op on existing profile
50. Customize a profile (e.g. `barWidth=260`, custom texture), `/reload` → all customized values **survive** (backfill only fills missing keys).
51. Logout to flush, inspect `AbsorbTrackerDB.lua` → `global.schemaVersion = 1`; `/reload` again → stays `1`, values unchanged.
52. *(Optional)* Hand-delete one profile key from the SV file, log in → that key restored to default, others untouched, no error.

### J. Class-color overrides
53. Bar page → Use Class Color (Bar) on → fill recolors to class color; Bar Color picker greys out.
54. Use Class Color (Background) on → background = darkened class color; picker greys out.
55. Border page → Use Class Color on → border = class color; picker greys out.
56. With all three on, `/reload` or profile switch → colors re-resolve with no manual refresh (getters read class color per-paint).
57. Turn each Use Class Color off → manual RGBA picker re-enables; bar reverts to the stored manual color.

**Pass criteria:** all 57 checks pass with **no Lua errors**, the `[AT]` prefix on every chat
line, and no combat-taint warning after step 12. On any failure, record the step number, observed
vs. expected, and any error text.

### Triage references (if a step fails)
- Bootstrap / events / profile repaint — `core/AbsorbTracker.lua` (`OnEnable`, `OnProfileChanged`)
- Slash dispatch + `NS.COMMANDS` — `settings/Slash.lua`
- Combat gate — `settings/Panel.lua` (`OpenOptionsPanel`)
- Bar paint / secret value / test-hold — `modules/Display.lua`
- Ticker interval guard — `modules/Timer.lua`
- DB init + idempotent migration — `core/Database.lua`
- Debug console — `core/DebugLog.lua`
- LSM border alignment fix — `core/LSMPatch.lua`
- Class-color-aware getters — `core/Data.lua` (`GetBarColor`/`GetBgColor`/`GetBorderColor`)

---

## How this build was verified

1. **Test-first gate.** `lua tests/run.lua` → 36/36 green; `luacheck .` → 0/0; `luac -p` → all 35
   source files parse. Re-run and confirmed green after the CRLF normalization pass.
2. **Independent closure re-audit** (read-only, adversarial): all 25 deviations addressed (24
   CLOSED at snapshot + AT-10 closed post-hoc; AT-05 Curse-only by decision); grep swept clean for
   `AddonTable`, `SLASH_*`, `SlashCmdList`, `C_Timer.NewTicker`.
3. **Adversarial correctness review** against the original behavioral map: **no BLOCKERs, no
   RISKs** — OnEnable reproduces the original PLAYER_LOGIN order, load-order/forward-refs are
   sound, the interval guard / SetBackdrop(nil)-first invariant / call-time color resolution are
   all preserved.

Remaining validation is the manual in-game suite above (requires a live client) — that is the one
thing a headless environment cannot exercise.
