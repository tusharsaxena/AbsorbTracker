# 04 — Technical Design

Remediation design for the deviations in `02_DEVIATIONS.md`. Keyed by ID. This is a **plan only** —
no code is changed by the audit. Every change lands test-first and behind the green gate
(`lua tests/run.lua` + `luacheck .`, both clean) per `testing`/`versioning-git`. None of these bump
the addon version unless the user asks.

## AT-26 — add the `version` slash verb (MUST)
**Files:** `settings/Slash.lua`, `README.md`, `tests/test_slash.lua`, `docs/test-cases.md`.
**Shape:**
- Add a helper (reuse existing `getVersion()` at `settings/Slash.lua:92-94`, which already reads
  `NS.Compat.GetAddOnMetadata(NS.name,"Version")` with `NS.version` fallback).
- Add to `NS.COMMANDS` (near the end, before/after `test`):
  `{"version", "Print the addon version", function() print(("v%s"):format(getVersion())) end}`.
  `print` is the file-local `NS.Print`, so the line carries the cyan `[AT]` tag →
  `[AT] v1.9.0`. This also surfaces automatically in `/at help` and the About page (both iterate
  `NS.COMMANDS`), keeping them in lockstep.
- README: add a `| \`/at version\` | Show the addon version |` row to the `## Usage` slash table.
**Test:** assert `findCommand("version")` exists and its `fn` prints a line containing the version.
**Risk:** trivial. **Ordering:** independent.

## AT-27 — inset paired action buttons to `BUTTON_PAIR_REL` 0.492 (MUST)
**Files:** `settings/Helpers.lua`, optionally `tests/` (widget-width assertion if the harness models
`SetRelativeWidth`).
**Shape:**
- Add constant near the other layout constants: `local BUTTON_PAIR_REL = 0.492` and expose
  `Helpers.BUTTON_PAIR_REL = BUTTON_PAIR_REL` (mirrors how `ROW_VSPACER`/`SECTION_HEADING_H` are
  exposed).
- In `Helpers.InlineButtonPair` → `makeBtn`, change `btn:SetRelativeWidth(0.5)` →
  `btn:SetRelativeWidth(BUTTON_PAIR_REL)`.
- This is the single shared button-pair maker, so every current and future pair inherits the inset —
  no per-panel edits (only `settings/General.lua`'s Reset pair exists today).
**Risk:** cosmetic; the standard documents that 0.5 shaves the right button's border against the
scroll clip. **Ordering:** independent.

## AT-28 — reorder TOC `#` sections so Locales follows Libraries (MUST)
**Files:** `AbsorbTracker.toc`.
**Shape:** move the `# Locales` block (`locales\enUS.lua`) up to sit directly after the
`#@end-no-lib-strip@` line that closes `# Libraries`, before `# Core`. Resulting order:
Libraries → Locales → Core → Defaults → Modules → Settings. `locales/enUS.lua` only defines the
`NS.L` metatable and has no dependency on `core/*`, so loading it earlier is safe.
**Risk:** low; re-run the harness (which loads sources in TOC order via `tests/loader.lua`) to confirm
nothing depends on the old position. **Ordering:** independent.

## AT-05 — `X-Wago-ID` (MUST, decision-gated)
**Files:** `AbsorbTracker.toc` and/or `docs/ARCHITECTURE.md`.
**Two branches (user decides):**
1. **On Wago:** add `## X-Wago-ID: <id>` immediately after `## X-Curse-Project-ID:` (keeps the
   metadata field order of `toc-file-§1`). Also add the CurseForge/Wago published-version badge upkeep
   as already handled.
2. **Not distributed on Wago:** record an explicit accepted deviation in `docs/ARCHITECTURE.md`
   "Standards Deviations" ("published on CurseForge only; no Wago listing") so the gap is intentional
   and greppable rather than silent. A future audit then treats it as accepted.
**Risk:** none (metadata only). **Ordering:** independent.

## AT-29 — closed message bus (MUST, accepted-deviation decision)
**Files:** `docs/ARCHITECTURE.md` (if kept) or `core/State.lua` + all modules (if adopted).
**Recommendation:** **keep as an accepted deviation.** With three modules and a shared-`NS` function
facade, a named bus adds indirection without the decoupling payoff the rule targets (large
multi-module addons). It is already documented. If the user instead wants full conformance:
- Create `NS.bus` (an AceEvent-embedded table) in `core/State.lua`.
- Replace direct repaint/appearance/visibility calls with
  `NS.bus:SendMessage("Ka0s_AbsorbTracker_RepaintRequested")` etc.; each consumer owns a distinct
  target via `NS.NewBusTarget()` (architecture-§4, anti-pattern #32).
- Document each message (name/sender/payload/consumers) in `docs/ARCHITECTURE.md` "Message Bus";
  extend the bus test mock to key by target and fan out (anti-pattern #33).
**Risk (if adopted):** medium — touches the hot repaint path; needs covering tests. **Ordering:** do
not bundle with the mechanical fixes.

## AT-30 — output localization (SHOULD, accepted-deviation decision)
**Files:** `locales/enUS.lua` + every user-facing string site (if adopted).
**Recommendation:** **keep as an accepted deviation** unless a translation pass is planned. If
adopted: wrap user-facing strings in `NS.L["<English>"]` (English-string keys, `localization-§2`),
populate `locales/enUS.lua`, and add locale-gated files as translations arrive. The metatable seam
already exists, so wrapping is non-breaking and incremental (page by page).
**Risk (if adopted):** low but high-churn. **Ordering:** independent; do incrementally.

## AT-31 — private unit-event frame (SHOULD, keep)
**No change recommended.** The deviation is justified (AceEvent cannot `RegisterUnitEvent`; routing
these two flood events through it pays a per-unit C→Lua dispatch in combat) and already documented
with rationale. It remains in the ledger only so it re-surfaces with its reason on each audit.

## Cross-cutting
- No schema/SV shape changes → **no `schemaVersion` bump** for AT-26/27/28/05.
- Keep `docs/test-cases.md` and the README `[tests]` badge in lockstep with any new test (AT-26).
- Follow the repo rule: no auto-stage/commit/push, no version bump without explicit instruction.
