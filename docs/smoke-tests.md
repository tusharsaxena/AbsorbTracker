# Ka0s Absorb Tracker — Manual In-Game Smoke-Test Suite

Run on a **live Retail (Midnight, 12.0.7 / Interface 120007) English client** in order — later
tests assume the addon loaded cleanly. Enable Lua errors first (`/console scriptErrors 1`, or
BugSack/BugGrabber). Watch chat for the cyan `[AT]` prefix and for any red error frame. The addon
also ships a headless gate (`lua tests/run.lua` → all suites green, `luacheck .` → 0/0, `luac -p <file>`)
that covers the pure logic; this suite covers everything that only runs against the live client.

### A. Load & bootstrap
1. **Fresh login.** Delete `WTF/.../SavedVariables/AbsorbTrackerDB.lua`, log in → world reached, **zero Lua errors**.
2. **Bar appears.** A single absorb bar is visible at screen center (default look); shows the value / `0`.
3. **/reload clean.** `/reload` → no errors; bar reappears in the same spot.
4. **Value tracks reality.** Gain an absorb (e.g. Power Word: Shield) → fill + text update to the abbreviated amount; consume it → drops toward `0`.
5. **Secret-value safety.** With a big absorb, the number shows an abbreviated string (e.g. `1.2M`), never `nil`/error.
5a. **Secret-in-combat + debug on (regression).** `/at debug on`, enter combat, gain/consume absorbs → **zero Lua errors** (no `invalid value (secret) … for 'concat'`). Per-event/per-repaint logging is coalesced (§9): no `[Absorb]`/repaint line fires per event in combat since the value is a secret there; leave combat → one `[Combat] left: N events, M repaints` rollup line appears, with `final=<value>` only if the post-combat read happens to be non-secret (otherwise counts only, no `final=`), and the **bar keeps updating** throughout. Leave combat, `/at debug off`, re-enter combat → bar still updates. (Pre-fix this froze the bar until `/reload`.)

### B. Slash surface
6. `/at` alone → help block (version line + command list).
7. `/absorbtracker` → identical help block.
8. `/at help` → gold command + em-dash + white desc for all 15 verbs: help, config, list, get, set, reset, resetall, resetposition, lock, unlock, toggle, debug, update, test, profile.
9. `/at wibble` → `unknown command 'wibble'` then help.
10. `/at options` → opens the panel (back-compat alias for `config`).

### C. Settings panel & combat gate
11. `/at config` (out of combat) → Blizzard Settings opens to **Ka0s Absorb Tracker**, tree expanded to General/Bar/Border/Font/Profiles.
12. **Combat gate (refuse, options-ui-§2).** In combat, `/at config` → panel does **not** open; chat shows the grey notice `[AT] cannot open settings during combat — Blizzard's category-switch is protected`. Spam `/at config` a few times → the same refusal each time, **no queue**, **no taint warning**.
13. **No auto-open on combat end.** Leave combat → the panel does **not** pop open by itself (nothing was queued). Then out of combat, `/at config` → opens immediately (tree expanded), **no taint warning**. *(`/run AbsorbTrackerNS and false` aside: the gate is inside `OpenOptionsPanel`, so a `/run`-triggered open in combat is refused too.)*

### D. Sub-pages render & edit live
14. **General** — Show Bar / Lock Position, Reset Position + Reset All buttons, Update throttle slider (Performance group). Toggle Show Bar → bar hides/shows; Lock Position → drag disabled; shield gain/loss repaints the bar within ~0.1s; sitting idle with no shield produces no repaints.
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
23. `/at list` → grouped `[general]/[bar]/[border]/[font]`, each `path = value` formatted. Colour scheme (slash-commands-§5): green `Available settings` header, azure `[page]` group headers, gold keys, white values; no trailing colon on any line.
24. `/at get barWidth` → `barWidth = <n> px` (gold key, white value); `/at get bogus` → not found; `/at get` → usage.
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
36. `/at profile new SmokeTest` → switches to a defaults profile; bar repaints to default immediately.
37. On SmokeTest `/at set barWidth 400`, then `/at profile use Default` → bar repaints to the original width (validates `OnProfileChanged`).
38. `/at profile copy SmokeTest` → copies + repaints.
39. `/at profile delete <current>` → refused; switch away, delete SmokeTest → deleted.
40. **Panel-driven switch** — Profiles page dropdown switch → bar repaints live.

### H. Debug console (§12)
41. `/at debug` → **Absorb Tracker — Debug** window appears (dark, draggable); `/at debug` again → hides.
42. Log lines render in a **monospace** font (JetBrains Mono).
43. `/at debug on` → chat ack `[AT] debug logging ON` with **ON in green** (`40ff40`), header **Debug: ON** (green); console logs a `[Debug] logging enabled` line **followed by an `[Init]` session summary** (`[Init] AbsorbTracker v<version>, schema v<n>, profile '<name>'`); trigger an absorb change → timestamped `[tag] msg` lines (steel-blue ts, tan tag).
44. `/at debug off` → chat ack `[AT] debug logging OFF` with **OFF in red** (`ff4040`), header **Debug: OFF** (red); console logs a `[Debug] logging disabled` line as the final entry (after the state flips off; no `[Init]` on disable); new changes no longer append.
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

**Pass criteria:** all 58 checks pass with **no Lua errors**, the `[AT]` prefix on every chat line,
and no combat-taint warning when the panel opens out of combat (step 13). On any failure, record the step number, observed vs.
expected, and any error text.

### Triage references (if a step fails)
- Bootstrap / events / profile repaint — `core/AbsorbTracker.lua` (`OnEnable`, `OnProfileChanged`)
- Slash dispatch + `NS.COMMANDS` — `settings/Slash.lua`
- Combat gate — `settings/Panel.lua` (`OpenOptionsPanel`)
- Bar paint / secret value / test-hold — `modules/Display.lua`
- Repaint throttle / coalescing — `modules/Timer.lua`
- DB init + idempotent migration — `core/Database.lua`
- Debug console — `core/DebugLog.lua`
- LSM border alignment fix — `core/LSMPatch.lua`
- Class-color-aware getters — `core/Data.lua` (`GetBarColor`/`GetBgColor`/`GetBorderColor`)
