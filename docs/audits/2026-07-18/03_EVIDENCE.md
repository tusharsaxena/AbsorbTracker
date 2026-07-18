# 03 — Evidence

`file:line` citations backing every deviation in `02_DEVIATIONS.md` and the key compliance claims in
`01_CURRENT_STATE.md`. Line numbers are as of the 2026-07-18 tree.

## Deviations

### AT-26 — no `version` slash verb (`slash-commands-§3`, MUST)
- `settings/Slash.lua:31-77` — `NS.COMMANDS` table lists `help, config, list, get, set, reset,
  resetall, resetposition, lock, unlock, toggle, debug, update, test, profile`. **No `version`
  entry.**
- `settings/Slash.lua:92-102` — `getVersion()` / `printHelp()` show the version only in the help
  header; there is no standalone verb that prints `<tag> v<version>` on its own line.
- `settings/Slash.lua:346-364` — `Sl:OnSlash` dispatches strictly from `NS.COMMANDS`; `/at version`
  falls through to `"unknown command 'version'"`.
- Confirmation: `grep -rn '"version"' settings/Slash.lua` → no match.
- README parity gap: `README.md:34-52` slash table has no `version` row.

### AT-27 — paired action buttons at 0.5, not `BUTTON_PAIR_REL` 0.492 (`options-ui-§6/§8`, #31, MUST)
- `settings/Helpers.lua:283-297` — `Helpers.InlineButtonPair` → `makeBtn` sets
  `btn:SetRelativeWidth(0.5)` (line 287) for each cell-filling action button.
- `settings/General.lua:127-147` — this pair is exactly the standard's cited example
  (`Reset Position` \| `Reset All Settings`) rendered via `InlineButtonPair`.
- `settings/Helpers.lua:26-52` — the layout-constants block defines `PADDING_X, HEADER_TOP,
  HEADER_HEIGHT, DEFAULTS_W, ROW_VSPACER, SECTION_*` but **no `BUTTON_PAIR_REL`**.
- Confirmation: `grep -rn "BUTTON_PAIR_REL\|0.492" settings/` → no match.

### AT-28 — TOC `#` section order (`toc-file-§5`, #28, MUST)
- `AbsorbTracker.toc:15-29` `# Libraries`, then `:31-41` `# Core`, `:43-44` `# Defaults`,
  `:46-47` `# Locales`, `:49-52` `# Modules`, `:54-66` `# Settings`. Order is
  Libraries → Core → Defaults → **Locales** → Modules → Settings.
- Standard mandate: `standards/standards/toc-file.md` §5 — "MUST use `#` section headers, in the
  order **Libraries → Locales → Core → Defaults → Modules → Settings**." Locales must sit directly
  after Libraries.

### AT-05 — missing `X-Wago-ID` while published (`toc-file-§1`, MUST)
- `AbsorbTracker.toc:13` — `## X-Curse-Project-ID: 1450165` present (addon is published).
- `AbsorbTracker.toc:1-13` — metadata block ends at `X-Curse-Project-ID`; **no `## X-Wago-ID`** line.
- Standard: `standards/standards/toc-file.md` §1 — "MUST have `X-Curse-Project-ID` and `X-Wago-ID`
  once an addon is published anywhere."

### AT-29 — no closed message bus (`architecture-§4`, #19, MUST — accepted/documented)
- `grep -rn "SendMessage\|RegisterMessage\|NS.bus\|NewBusTarget" core/ modules/ settings/` → only a
  comment hit in `core/DebugLog.lua:127`; **no actual bus API use**.
- Cross-module direct calls, e.g. `core/AbsorbTracker.lua:44-47,100,106,111-113` call
  `NS.RestoreBarPosition/UpdateBarAppearance/UpdateAbsorbBar/RequestRepaint/ApplyVisibility`
  directly.
- Already recorded accepted: `docs/ARCHITECTURE.md:153-154` ("No closed message bus — cross-module
  calls are direct `NS.X` references") and the "Standards Deviations" section (`:156-160`).

### AT-30 — output localization not wired (`localization-§1/§3`, SHOULD — accepted/documented)
- `locales/enUS.lua:6` — sets `NS.L` metatable fallback only; `:8-13` comment states strings are
  "still hardcoded English"; **no `L["…"]` keys defined.**
- Call sites use raw English literals, e.g. `settings/General.lua:36,41,88-89`,
  `settings/Slash.lua:32-77`, `settings/About.lua` labels — none routed through `NS.L`.
- Already recorded accepted: `docs/ARCHITECTURE.md:150` ("English only — `NS.L` seam exists but no
  strings are wrapped yet").
- (Compliant on `localization-§4`: `core/Data.lua:91` keys on `classFilename` token, not a localized
  name; no localized-string branches found.)

### AT-31 — private unit-event frame (`events-frames-taint-§1`, SHOULD — justified/documented)
- `core/AbsorbTracker.lua:57-69` — `CreateFrame("Frame")` +
  `f:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED","player")` /
  `RegisterUnitEvent("UNIT_MAXHEALTH","player")` instead of AceEvent.
- `core/AbsorbTracker.lua:49-56` + `docs/ARCHITECTURE.md:162-171` document the justification
  (AceEvent's shared frame cannot unit-filter; routing floods C→Lua per unit in combat). All other
  events stay on AceEvent (`core/AbsorbTracker.lua:71-73`).

## Key compliance evidence (claims in 01)

- **Green gate:** `lua tests/run.lua` → "73 passed, 0 failed, 73 total"; `luacheck .` → "0 warnings
  / 0 errors in 27 files". `docs/test-cases.md:114` Total = 73; `README.md:7` `[tests]` badge = 73/73.
- **Printer reclaim / secret-safe:** `core/AbsorbTracker.lua:17`
  (`if NS.Util and NS.Util.print then NS.Print = NS.Util.print end`); `core/Util.lua:19-47`
  (`IsConcatSafe` probes `table.concat`; `SafeToString`; `NS.Print`).
- **Schema single source + boot validation:** `settings/Schema.lua:93-103` (`NS.SetByPath` write
  seam), `:172-209` (`NS.ValidateSchema` walks each path against `defaults.profile`, returns
  resolved/missing counts).
- **AceAddon promotion, NS first arg:** `core/AbsorbTracker.lua:6-8`.
- **Compat sole caller:** `core/Compat.lua:12-20`; `grep` for direct
  `GetAddOnMetadata/GetSpecialization` outside Compat → none.
- **Migration runner + schemaVersion:** `defaults/Profile.lua:31-35`, `core/Database.lua:34-61`.
- **Options combat-refuse + AceGUI Defaults button:** `settings/Panel.lua:107-120`;
  `settings/Helpers.lua:144-158` (`AceGUI:Create("Button")`, reparented — not a raw template).
- **In-place refresh (options-ui-§11):** `settings/Helpers.lua:346-350` (`RefreshAllPanels` runs
  per-widget `refreshers`, no page rebuild); widget refreshers at `settings/Widgets.lua:54,82,108,206`.
- **Debug console conformance:** `core/DebugLog.lua:58-63` (700×344, DIALOG),
  `:114,207` (FONT_MONO 10pt), `:145-155` (Format Plain/Colored), `:245-269` (`SetEnabled` ack +
  `[Init]` summary), `:301-311` (gated zero-alloc sink).
- **Standards reference four places:** `AbsorbTracker.toc:12` (X-Standard), `README.md:6` (badge),
  root `CLAUDE.md` "Standards compliance (read first)", `docs/agent-context.md` Hard rules.
- **Sanctioned media (not flagged):** `core/Constants.lua:13` (FONT_MONO), `:16` (LOGO_PATH);
  `media/fonts/JetBrainsMono-Regular.ttf` + `OFL.txt`; `media/logos/absorbracker.logo.v2.tga`.
