# REVIEW_FINDINGS — Ka0s Absorb Tracker

**Verdict:** Ship-ready with minor issues. No blocking taint, no data-loss bugs, no broken core flow. The cluster of findings below is convention drift, dead/duplicated code, two latent correctness bugs in lesser-trodden paths (AceDB-missing fallback, `/at test`), and one near-future-deprecated-API ordering hazard.

Findings are grouped by severity. IDs are stable; later artifacts (`REVIEW_PROPOSED_CHANGES.md`, `REVIEW_EXECUTION_PLAN.md`) reference them.

---

## High

### F-001 — `getVersion()` prefers removed API `GetAddOnMetadata` over `C_AddOns.GetAddOnMetadata` `[deprecated-api]`
**Where:** `SlashCommands.lua:87-95` (the `getVersion` local).
**Problem:** The function checks `if GetAddOnMetadata then ... end` first and only falls back to `C_AddOns.GetAddOnMetadata`. On retail Midnight (Interface 12.0.x) the bare `GetAddOnMetadata` global has been removed; the addon currently happens to work because the second branch fires when the first is nil, but if Blizzard ever stubs the old name as a deprecated shim that returns nil/errors, `/at help` and `/at debug` will print "v?" instead of the actual version. The mirror function in `OptionsPanel.lua:759-766` (`getMetadata`) has the order correct (C_AddOns first).
**Impact:** Latent breakage of the version line in `/at help` on any client that still exposes a vestigial `GetAddOnMetadata`. Inconsistency with the sister helper one file over.

### F-002 — Fallback shim aliases default tables into saved variables `[bug][saved-vars]`
**Where:** `Events.lua:48-56`.
**Problem:** When `AceDB-3.0` is missing, the seed loop assigns `flatDefaults[key]` directly into `AbsorbTrackerDB`. For nested tables (`barColor`, `bgColor`, `borderColor`) the saved-variable global ends up holding *the same table identity* as `flatDefaults`. Any subsequent `SetSetting("barColor", { … })` (which always allocates a fresh table — see `Schema.ApplyDefault` and the ColorPicker `commit`) is fine, but any code that mutates `db.profile.barColor.r = …` in place would silently mutate `flatDefaults.barColor.r` and corrupt the in-memory defaults for the rest of the session.
**Impact:** Latent; only exercised when AceDB is missing (declared optional, ships in-tree). If a future contributor adds a `db.profile.color.r = x` mutation, the bug becomes real instantly. Listed High because the failure mode is silent and remote.

---

## Medium

### F-003 — Panel `set()` writes bypass the documented `SetByPath` seam `[design][convention-drift]`
**Where:** `OptionsPanel.lua:412-418` (the `set` local) and `OptionsPanel.lua:572-577` (the ColorPicker `commit` local).
**Problem:** `CLAUDE.md` and `docs/data-flow.md` state that "the slash and panel paths converge on `SetByPath`." They don't. The slash path uses `AddonTable.SetByPath`; the panel path open-codes `SetSetting + FireSchemaOnChange`. The two compositions produce the same result today, but `SetByPath` is documented as the single dispatch path, so any future side effect added there (validation, telemetry, change-notify) would silently miss every panel write.
**Impact:** Hidden split write-path. Convention violation against the doc-stated invariant.

### F-004 — `/at test` value is overwritten by the next ticker tick `[ux][bug]`
**Where:** `SlashCommands.lua:234-242`.
**Problem:** `runTest` writes a fake value into the StatusBar, but the periodic `C_Timer.NewTicker` (default 1.0 s, range 0.1–10 s) calls `UpdateAbsorbBar` next, which reads the real `UnitGetTotalAbsorbs` and replaces the test value. The test paint persists for at most `updateInterval` seconds — at 0.1 s it's effectively invisible. README ("Paint the bar with a fake value … for visual tweaking") implies the paint persists.
**Impact:** Documented feature does not work as the README says. Users who try `/at test 999999` to size-check the bar see a flicker, not a sustained paint.

### F-005 — `OptionsPanel.lua` is 958 lines and mixes four concerns `[organization]`
**Where:** `OptionsPanel.lua` (whole file).
**Problem:** One file holds: (a) layout constants and the canvas-frame/header builder; (b) widget-makers (`makeCheckbox` / `makeSlider` / `makeDropdown` / `makeColorPicker`); (c) `RenderSchema` + `RenderField` schema-driven layout engine; (d) the AceGUI ScrollFrame `FixScroll` patch; (e) the about-page builder; (f) registration shell (`RegisterOptionsPage` / `CreateOptionsPanel` / `OpenOptionsPanel`); (g) `expandMainCategory` private-API tree expansion. Cross-cutting boundaries that should be separately addressable (e.g. swap a widget maker, replace the about page) all live in one file.
**Impact:** Maintainability. Future widget additions or the next time someone has to revisit the FixScroll patch require navigating a 958-line file.

### F-006 — `lsmValues` helper is duplicated verbatim in three Options pages `[design][duplication]`
**Where:** `Options/Bar.lua:18-25`, `Options/Border.lua:13-20`, `Options/Font.lua:13-20`.
**Problem:** Identical 8-line closure factory in three files. If LSM's `:HashTable` ever changes shape, all three must change in lockstep.
**Impact:** Low-grade duplication. Right home is `AddonTable.Helpers.LSMValues(mediaType)` exposed alongside the rest of the Helpers toolkit.

### F-007 — Timer.lua has DebugPrint string concatenation work even when DEBUG is off `[perf]`
**Where:** `Timer.lua:14`, `Timer.lua:31`. Less hot in `Settings.lua:50` and `Display.lua:92`.
**Problem:** `DebugPrint` early-returns if `AddonTable.DEBUG` is false, but Lua evaluates every argument before the call. `tostring(forceRestart)`, `tostring(newInterval)`, `tostring(updateTicker ~= nil)`, and `AddonTable.format("%.3f", GetTime())` all run on every ticker restart and every settings write, even with debug off. The format-time call hits each ticker rebuild (cheap, but unnecessary). Pattern is worse if DEBUG is added to a true hot path later (`Display.lua:92` already runs every ticker tick).
**Impact:** Sub-millisecond wasted work per call. Becomes meaningful if DebugPrint is added to the per-ticker path. The idiomatic fix is `if AddonTable.DEBUG then DebugPrint(...) end` at call sites that build expensive arguments, or change `DebugPrint` to accept a format-string + args.

---

## Low

### F-008 — Dead local `UpdateAbsorbBar` in `Timer.lua` `[dead-code][naming]`
**Where:** `Timer.lua:6`.
**Problem:** `local UpdateAbsorbBar = AddonTable.UpdateAbsorbBar` is captured at file load, then never referenced. The actual call site (`Timer.lua:30`) uses `AddonTable.UpdateAbsorbBar` directly.
**Impact:** Misleading reader cue (suggests the local is used) and harmless redundancy.

### F-009 — Dead cached global `AddonTable.min` `[dead-code]`
**Where:** `Core.lua:7`.
**Problem:** `AddonTable.min = math.min` is set but no file reads it. `floor` and `max` are read in `Display.lua`; `format` in three files; `min` is unused.
**Impact:** Tiny — one global lookup avoided at load time, but no reader.

### F-010 — Redundant intra-function locals in `UpdateAbsorbBar` `[naming]`
**Where:** `Display.lua:80-81`.
**Problem:** `local GetSetting = AddonTable.GetSetting` and `local DebugPrint = AddonTable.DebugPrint` are declared inside the function body, shadowing the file-scope locals declared on lines 6-13. Identical values, no behavioral effect.
**Impact:** Minor noise. Intent-of-code is muddier ("why is this re-declared?").

### F-011 — `GetTime() and GetTime() or 0` calls `GetTime` twice `[perf][naming]`
**Where:** `OptionsPanel.lua:582`, `OptionsPanel.lua:593`.
**Problem:** `local now = GetTime() and GetTime() or 0` evaluates `GetTime()` twice on every call. Should be `local now = GetTime() or 0`.
**Impact:** Trivial perf, but the construct also reads as defensive against `GetTime` returning nil — which it doesn't on retail. Either drop the guard entirely (`local now = GetTime()`) or cache the first call.

### F-012 — Color picker throttle leaks closures and tables under sustained drag `[perf]`
**Where:** `OptionsPanel.lua:579-598`.
**Problem:** Every `OnValueChanged` outside the 50 ms window allocates a closure for `C_Timer.After` and a fresh `pendingArgs` 4-element array. For a sustained drag at 60 Hz that's ~60 closures and arrays per second. Each scheduled callback wakes up 50 ms later regardless of whether `pendingArgs` was overwritten in the meantime. The "first arrival wins; later ones see nil and no-op" pattern works but produces a lot of one-shot garbage. A `C_Timer.NewTicker` or single re-armed timer would be cleaner.
**Impact:** Sub-perceptible GC pressure during a color-picker drag. Real cost is code complexity for a feature (drag throttling) that could be a single ticker.

### F-013 — `runTest` ignores the `hidden` setting `[ux]`
**Where:** `SlashCommands.lua:234-242`.
**Problem:** If the bar is hidden (`/at toggle` set it off), `/at test 50000` writes to `valueText` and `statusBar` but the bar frame is `:Hide()`'d, so nothing is visible. No chat-side hint that "hidden" is the cause.
**Impact:** User confusion in a niche case. Cheap fix — print "Bar is hidden; run /at toggle to show it."

### F-014 — `AddonTable.SlashCommands` array uses positional `entry[1]/[2]/[3]` access `[naming][maintainability]`
**Where:** `SlashCommands.lua:29-75` (table literal) and the call sites at lines 78, 100-101, 341.
**Problem:** Every entry is a 3-tuple `{name, desc, handler}`; readers must remember which slot is which. `entry[3]` for "handler" is harder to read than `entry.handler`. The table is explicitly "lifted from KickCD's commands table" per the comment; if that's the house-style anchor, fine, but a named-key shape is friendlier and the about-page renderer (`OptionsPanel.lua:834-843`) also uses positional access.
**Impact:** Naming nit. Not worth a refactor unless touching the file for another reason.

### F-015 — `AddonTable.Helpers.AttachTooltip` exposed but only used internally `[naming][api]`
**Where:** `OptionsPanel.lua:109` (the `Helpers.AttachTooltip = attachTooltip` export), no external callers.
**Problem:** Documented as a "panel-builder toolkit" public method (`docs/module-map.md`), but every call is in the same file (`buildHeader`, `makeCheckbox`, `makeSlider`, `makeDropdown`, `makeColorPicker`, `InlineButtonPair`). Either it's part of the helpers contract (in which case it's fine) or it should be a file-local.
**Impact:** Surface-area mismatch. Acceptable as-is given the docs explicitly list it; flagging only as a "verify intent" item.

### F-016 — `runProfile` "delete current" message uses period-terminated and other branches don't `[ux][naming]`
**Where:** `SlashCommands.lua:303-313`.
**Problem:** "Cannot delete the current profile." (period); "Deleted profile 'X'" (no period); same file, three lines apart. Same inconsistency throughout SlashCommands — some chat lines end with periods, most don't.
**Impact:** Cosmetic. Pick one and apply uniformly.

### F-017 — `/at profile` `new` and `create` aliases not documented `[ux][docs]`
**Where:** `SlashCommands.lua:285` (`if sub == "new" or sub == "create"`), `SlashCommands.lua:300` (`if sub == "delete" or sub == "remove"`), `SlashCommands.lua:278` (`if sub == "use" or sub == "set"`).
**Problem:** The handler accepts hidden aliases: `set` for `use`, `create` for `new`, `remove` for `delete`. Neither the help printout (`runProfile("")` block) nor the README mentions them. Either doc them or drop them.
**Impact:** Either undocumented surface (drift hazard for testing) or dead code paths (can't be reached without trying random words).

---

## Notes / not-bugs

- **`InCombatLockdown` gate at `OpenOptionsPanel`:** correct (`OptionsPanel.lua:942`). Required by the protected-Settings-API rule.
- **`SetBackdrop(nil)` clear-then-set workaround at `Display.lua:54-55`:** correct, matches `docs/midnight-quirks.md`.
- **Secret-value handling for `UnitGetTotalAbsorbs`:** correct — `Display.lua:89-103` passes the raw value to `AbbreviateNumbers` and `statusBar:SetValue` without `tonumber`. `Events.lua:74` and `SlashCommands.lua:236` likewise.
- **`Settings.RegisterAddOnCategory` runs at PLAYER_LOGIN inside `CreateOptionsPanel`:** correct — PLAYER_LOGIN cannot fire mid-combat.
- **`hooksecurefunc` use:** none needed; the addon does not hook secure functions.
- **CHAT_PREFIX convention:** consistently routed through `AddonTable.Print`. Every `.lua` file that emits chat shadows the global `print` with `local print = AddonTable.Print`. No raw-`print` violations found.
- **COMMANDS-style dispatcher:** `AddonTable.SlashCommands` is the table; the README and `docs/schema.md` list match the entries; the dispatcher iterates the same array. No drift.
- **`Settings.OpenToCategory` argument:** correct numeric ID (`mainCategoryID`, captured via `:GetID()` at `OptionsPanel.lua:893`).
- **Subcategory `appName` collision:** `Options/Profiles.lua` uses a unique `"AbsorbTracker-Profiles"` distinct from the parent.
- **TOC load order:** `Core` → `Utils` → `LSMPatch` → `Settings` → `Schema` → `UI` → `Display` → `Timer` → `Events` → `SlashCommands` → `OptionsPanel` → `Options/*`. Matches the documented dependency order.
- **`.gitattributes` CRLF policy:** present and correct.
- **Schema validator (`ValidateSchema`):** runs once at `CreateOptionsPanel` time. Good — catches misspelled rows in dev without refusing to register.
- **`Schema.ApplyDefault` deep-copies color tables:** correct (`Schema.lua:99-110`). This is the right write path; only the AceDB-missing seed loop (F-002) skips the copy.
