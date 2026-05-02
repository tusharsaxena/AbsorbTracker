# Smoke tests

Manual QA recipe for **Ka0s Absorb Tracker**. There are no automated tests — every code path runs against the WoW client, the Blizzard Settings panel, AceDB, or LibSharedMedia, none of which run outside the game. Walk this end-to-end before any release; spot-check the affected sections after every non-trivial code change.

If you can only reason about a change from code and cannot run it in WoW, **say so explicitly**. Don't claim it works.

> Times below are wall-clock for a familiar tester on a logged-in character. First run is slower.

---

## 0. Setup (one-time)

1. Copy or symlink the addon folder into `<WoW>\_retail_\Interface\AddOns\AbsorbTracker\`.
2. Pick a character whose class can self-cast an absorb shield: **Priest** (Power Word: Shield), **Discipline / Holy Paladin** (Word of Glory + talents), **Death Knight** (Blood Shield), or any class wearing a trinket with an active absorb proc. Priest is easiest.
3. Launch WoW. Verify the addon is enabled in the AddOn list.
4. `/reload`. There should be no Lua errors. The bar paints at screen center on first load.

---

## 1. Boot smoke (~1 minute)

- [ ] `/reload` produces no Lua errors.
- [ ] The bar appears centered on the screen with the default appearance.
- [ ] `/at` and `/at help` print every command, each line prefixed with cyan `[AT]`, with the command name in yellow and the description in white.

---

## 2. Bar paint (~2 minutes)

The bar reads `UnitGetTotalAbsorbs("player")` against `UnitHealthMax("player")` on a periodic ticker (`Timer.lua` → `Display.UpdateAbsorbBar`).

- [ ] With no active absorb, the bar is empty (or shows `0`).
- [ ] Cast Power Word: Shield (or proc your trinket). The bar fills, and the value displayed matches the absorb overlay on the default Blizzard unit frame.
- [ ] Let the absorb expire or break. The bar drains back to `0` within one ticker tick.
- [ ] `/at test 50000` paints the bar with `50K` (formatted by `AbbreviateNumbers`).
- [ ] `/at test 1234567` displays as `1.2M` (or whatever Blizzard's `AbbreviateNumbers` produces — but it's not a raw 7-digit string).
- [ ] `/at update` triggers an immediate repaint with no error.

---

## 3. Bar interaction (~2 minutes)

The bar is created with `SetMovable(true) + EnableMouse(true)` (`UI.lua`). Drag is gated by the `locked` setting (`Display.lua`).

- [ ] `/at unlock` — drag the bar with left-click; it moves freely.
- [ ] `/reload` — bar position persists across reload.
- [ ] `/at lock` — left-click-drag is now ignored.
- [ ] `/at toggle` once — bar hides. `/at toggle` again — bar reappears.
- [ ] `/at resetposition` — bar snaps back to screen center.

---

## 4. Slash CLI surface (~5 minutes)

Every `/at` subcommand defined in `SlashCommands.lua` (the `AddonTable.SlashCommands` registry).

### Read / list
- [ ] `/at list` prints every schema row, grouped by panel (general / bar / border / font), with the current value next to each path.
- [ ] `/at get barWidth` — prints the numeric value.
- [ ] `/at get borderColor` — prints the `r,g,b,a` color tuple.
- [ ] `/at get bogusPath` — prints an "unknown setting" error and does not crash.

### Write
- [ ] `/at set barWidth 250` then `/at get barWidth` round-trips to `250`. Bar visibly widens.
- [ ] `/at set barColor 0.4 0.7 1.0 0.8` — bar fill turns light blue. `/at get barColor` echoes the tuple.
- [ ] `/at set useClassColorBar true` — bar fill switches to your class color. If the Settings panel is open, the **Bar Color** picker greys out.
- [ ] `/at set useClassColorBar false` — bar fill reverts to the configured RGB; **Bar Color** picker re-enables.
- [ ] `/at set barWidth abc` — error message ("expected a number" or similar), value unchanged.
- [ ] `/at set bogusPath 1` — unknown-setting error, no crash.

### Reset
- [ ] `/at reset bar` — every Bar setting back to defaults; non-Bar pages untouched.
- [ ] `/at resetall` — every setting back to defaults; saved bar position is cleared (bar centers).

### Visibility / lock helpers
- [ ] `/at lock` / `/at unlock` flip drag state (covered in §3).
- [ ] `/at toggle` flips visibility (covered in §3).
- [ ] `/at resetposition` centers the bar (covered in §3).
- [ ] `/at update` forces a repaint (covered in §2).

### Debug
- [ ] `/at debug` → cyan `[AT] Debug enabled` line. Cast PW:S — `[AT]` debug entries log to chat for the absorb update. `/at debug` again → debug off, no more lines.

### Aliases
- [ ] `/at options` opens the Settings panel (alias for `/at config`).
- [ ] `/absorbtracker config` works the same as `/at config`.

### Profile
Covered in §6.

---

## 5. Settings panel (~10 minutes)

Open via `/at config`. Tree shows **Ka0s Absorb Tracker** parent with five sub-pages (General, Bar, Border, Font, Profiles).

### 5a. Combat-lockdown gate
- [ ] Engage in combat (target dummy or any mob). With combat active, `/at config` prints a chat warning and does **not** open the panel. (`OptionsPanel.lua:OpenOptionsPanel` early-returns when `InCombatLockdown()`.)
- [ ] Drop combat, retry — panel opens normally.

### 5b. About page (parent)
- [ ] Click the **Ka0s Absorb Tracker** parent in the left tree. The page renders:
  - the addon logo (`Media\logo.tga` or equivalent),
  - the addon `Notes` text from the TOC,
  - a "Slash Commands" heading with every entry from `AddonTable.SlashCommands` rendered in the same yellow-name / white-description style as `/at help`.
- [ ] No settings widgets on this page.

### 5c. General sub-page
- [ ] **Show Bar** checkbox toggles bar visibility (matches `/at toggle`).
- [ ] **Lock Bar** checkbox toggles drag (matches `/at lock` / `/at unlock`).
- [ ] **Update Interval** slider (range 0.1–10s, step 0.1) — drop to `0.5`; the bar refreshes more often visibly. Restart the ticker test: trigger an absorb, watch the value update at the new cadence.
- [ ] **Reset Position** button — bar centers.
- [ ] **Reset All Settings** button — confirmation popup appears. Cancel: nothing changes. Confirm: every setting back to defaults, bar position cleared.
- [ ] Page-level **Defaults** button (header, top-right) — restores **only** General settings to defaults; other pages untouched.

### 5d. Bar sub-page
- [ ] **Bar Width** (50–500) and **Bar Height** (10–100) sliders — bar resizes live as you drag.
- [ ] **Bar Texture** LSM30_Statusbar dropdown — opens with the full LSM `statusbar` catalog. Each row has an inline preview swatch. Closed state shows the selected texture as a swatch on the right of the dropdown.
- [ ] **Bar Color** picker — open, drag inside the wheel, watch the bar repaint live. Click X / press Esc to cancel — bar reverts.
- [ ] **Use Class Color (Bar)** checkbox — toggling on greys out the **Bar Color** picker AND switches the bar fill to your class color.
- [ ] **Background Texture** / **Background Color** / **Use Class Color (BG)** — same three behaviors for the background layer.
- [ ] Page-level **Defaults** button — restores **only** Bar settings.

### 5e. Border sub-page
- [ ] **Border Style** LSM30_Border dropdown — opens. **There is NO 42×42 preview tile** to the left of the dropdown's text. The label and dropdown chrome should sit flush against the page's left edge. *(This is the regression guarded by `LSMPatch.lua` — if the tile reappears, the fix has broken.)*
- [ ] Hovering each row in the open list — the popup's outer border (its `edgeFile`) updates to preview that border style.
- [ ] **Border Thickness** (1–32 px) — border edge size changes live.
- [ ] **Use Class Color (Border)** — greys **Border Color** picker, border switches to class color.
- [ ] Page-level **Defaults** button — restores **only** Border settings.

### 5f. Font sub-page
- [ ] **Font Face** LSM30_Font dropdown — opens with full LSM `font` catalog; each row's swatch shows `Aa` rendered in that font. Closed state shows `Aa` in the selected font.
- [ ] **Font Size** slider (6–32) — value text on the bar resizes live.
- [ ] **Font Flags** dropdown (plain Dropdown, not LSM) — cycle through `None` / `OUTLINE` / `THICKOUTLINE` / `MONOCHROME`. Outline state on the value text updates live.
- [ ] Page-level **Defaults** button — restores **only** Font settings.

### 5g. Profiles sub-page
- [ ] AceDBOptions UI renders: **Choose Set**, **Copy From**, **Reset Profile**, **New** input + button, **Delete Profile**.
- [ ] **No** page-level Defaults button (Profiles is the one sub-page without one — AceDBOptions owns its own UI).

---

## 6. Profiles & profile callbacks (~3 minutes)

Profile management is wired via AceDB callbacks in `Events.lua` (`OnProfileChanged`, `OnProfileCopied`, `OnProfileReset` → `AddonTable.OnProfileChanged`).

### Via the Profiles sub-page
- [ ] Click **New**, enter `SmokeTest`, confirm. New profile is created and made active.
- [ ] Bar position resets to screen center (new profile has no saved position).
- [ ] All other settings carry over to the same starting defaults.
- [ ] Drag the bar to a new position. Switch back to **Default** via **Choose Set**. Bar snaps back to wherever Default's saved position was (or center if Default has none).
- [ ] Switch back to **SmokeTest** — bar position you set there is restored.
- [ ] **Copy From: Default** — Default's settings overwrite SmokeTest's. Bar position included.
- [ ] **Reset Profile** — every setting in the active profile back to defaults, position cleared.
- [ ] **Delete Profile: SmokeTest** — confirmation popup, then profile is gone. Active profile falls back to Default.

### Via `/at profile`
- [ ] `/at profile list` — every existing profile, current marked with a `*` or similar.
- [ ] `/at profile current` — prints the active profile name.
- [ ] `/at profile new SmokeCLI` — creates and switches.
- [ ] `/at profile use Default` — switches back.
- [ ] `/at profile copy SmokeCLI` — overlays SmokeCLI's settings onto the current profile.
- [ ] `/at profile reset` — resets the active profile.
- [ ] `/at profile delete SmokeCLI` — removes that profile.
- [ ] `/at profile use NonexistentName` — friendly error, no crash.

After every switch / copy / reset: the bar position and appearance immediately reflect the new state (no `/reload` required).

---

## 7. Class-color resolution (~2 minutes)

Class colors are resolved at every paint call (`GetBarColor` / `GetBgColor` / `GetBorderColor` in `Settings.lua` re-read `useClassColor*` per call — they never cache).

- [ ] On the test character, set `useClassColorBar true`. Bar matches your class color.
- [ ] Switch to a different character of a different class (or use `/run RAID_CLASS_COLORS` to confirm the color you expect). Reload. Bar fill matches the **new** class.
- [ ] In the Settings panel, with the picker open: toggling the matching `Use Class Color` checkbox should grey/un-grey the picker live without reopening it.

---

## 8. LSM dropdowns (~2 minutes)

Five LSM-backed widgets: `barTexture` / `bgTexture` (Statusbar), `border` (Border), `font` (Font). The `fontFlags` dropdown is plain.

- [ ] Each LSM dropdown shows the **full** SharedMedia catalog — many entries, not just Blizzard fallback constants like `Blizzard Raid Bar`, `Blizzard Tooltip`, `Friz Quadrata TT`.
- [ ] If only fallbacks appear, see [common-tasks.md → Troubleshoot the LSM dropdowns](./common-tasks.md#troubleshoot-the-lsm-dropdowns).
- [ ] Border specifically: confirm the displayButton suppression from `LSMPatch.lua` (covered in §5e).

---

## 9. Backdrop / appearance refresh (~1 minute)

`UpdateBarAppearance` (in `Settings.lua` / `Display.lua`) clears the backdrop with `SetBackdrop(nil)` before applying the new info table — Blizzard's API is a no-op when the table identity is unchanged, so changing edgeFile or bgFile silently fails without the clear.

- [ ] Change **Bar Texture** to a different LSM entry — bar repaints to the new texture immediately.
- [ ] Change **Border Style** to a different LSM entry — border repaints. If the previous border tile still shows, the clear-first pattern was bypassed somewhere upstream of `UpdateBarAppearance`.
- [ ] Change **Border Color** — border tints to the new color without reload.
- [ ] Change **Background Texture** — background fill repaints.

---

## 10. Multi-patch compatibility (post-patch only)

`AbsorbTracker.toc:1` lists supported retail patch numbers (`120000, 120001, 120005`). When a new compatible patch ships:

- [ ] On every supported patch number listed in the TOC, `/reload` produces no errors. Bar paints. `/at config` opens the panel.
- [ ] Before adding a new patch number, run §1–§9 on that patch first.

---

## 11. Failure-mode quick reference

When something is broken, this is the fastest path to a hypothesis:

| Symptom | Probable cause | Where to look |
|---------|---------------|---------------|
| Bar never paints | Events not wired | `Events.lua` — `PLAYER_LOGIN`, `PLAYER_ENTERING_WORLD`, ticker setup |
| Bar paints once then freezes | Ticker not restarted | `Timer.lua`, `RestartUpdateTicker`, `OnProfileChanged` flow |
| `/at config` does nothing | Combat lockdown gate | `OptionsPanel.lua:OpenOptionsPanel`, `InCombatLockdown()` check |
| `/at config` taints the panel | Combat-lockdown gate was removed or skipped | Same — must early-return during combat |
| LSM dropdowns show only Blizzard fallbacks | LSM not loaded, or `dialogControl` missing on the schema row | [common-tasks.md → Troubleshoot the LSM dropdowns](./common-tasks.md#troubleshoot-the-lsm-dropdowns) |
| Border dropdown shows a 42×42 tile to the left of the text | `LSMPatch.lua` PLAYER_LOGIN hook didn't fire | `LSMPatch.lua`, [midnight-quirks.md](./midnight-quirks.md) |
| Texture / border change is ignored visually | `SetBackdrop(nil)`-before-`SetBackdrop(info)` pattern was optimized away | `UpdateBarAppearance` |
| Class-color toggle has no visible effect | Color was cached on a frame | Color getters must re-read `useClassColor*` per paint |
| Profile switch doesn't update the bar | AceDB callbacks not registered | `Events.lua` — `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset` |
| `/at profile` errors / Profiles tab missing | AceDB-3.0 not loaded | `libs/Ace3/AceDB-3.0/` and TOC |
| Display value is a giant stale number | `UnitGetTotalAbsorbs` "secret value" run through `tonumber` | Pass the raw value to `AbbreviateNumbers` directly. See [midnight-quirks.md](./midnight-quirks.md#secret-values-from-unitgettotalabsorbs) |

---

## See also

- [common-tasks.md](./common-tasks.md) — recipes for routine modifications (add a setting, add a sub-page, troubleshoot LSM, bump the Interface line).
- [midnight-quirks.md](./midnight-quirks.md) — Midnight-era WoW gotchas this smoke is designed to catch.
- [data-flow.md](./data-flow.md) — bootstrap + event flow that §1–§3 walk through.
- [profiles.md](./profiles.md) — AceDB integration detail referenced by §6.
