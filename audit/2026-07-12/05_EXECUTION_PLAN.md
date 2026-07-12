# 05 — Execution Plan

**Addon:** Ka0s Absorb Tracker · **Standard:** v1.0.0 (2026-07-12) · **Run:** 2026-07-12

Ordered, checkable remediation for the separate follow-up engagement. Each step lists its deviation IDs and a done-check. Sprints are ordered so the **safety net (tests + lint) lands before the high-churn structural moves**, and cosmetic/doc work lands last. Every commit must end green: `lua tests/run.lua` passing + `luacheck .` clean (§14A/§17) — which is why Sprint 0 builds that gate first.

Design detail for each item is in `04_TECHNICAL_DESIGN.md` (Themes A–H).

---

## Sprint 0 — Safety net & low-risk scaffolding (Themes F, C-partial)
Build the gate before changing behavior. All additive; zero runtime risk.

- [ ] **S0.1 — `.luacheckrc`** (AT-21). Add config; run `luacheck .` to 0 errors, fixing surfaced warnings. *Done:* `luacheck .` exits clean.
- [ ] **S0.2 — `.pkgmeta`** (AT-20). Add with ignore list, no `externals:`. *Done:* file present, no externals block.
- [ ] **S0.3 — Test harness** (AT-22). `tests/run.lua` + `loader.lua` + `wow_mock.lua`; suites `test_schema.lua` (parse/format/`SchemaForPage`), against **current** code. *Done:* `lua tests/run.lua` green, exercises `ParseSchemaValue`/`FormatSchemaValue`/`SchemaForPage`.

## Sprint 1 — SavedVariables correctness (Theme D)
Test-first against the new harness.

- [ ] **S1.1 — schemaVersion + Database.lua** (AT-07). Add `global.schemaVersion`; `RunMigrations` skeleton; migrate the inline flat→profile backfill into a versioned step. *Done:* `test_database.lua` asserts migration is idempotent (runs twice, same result).
- [ ] **S1.2 — Schema path validation** (AT-13). Extend `ValidateSchema` to resolve each `path` against defaults; expose counts. *Done:* test asserts a planted bad path is reported and count is exposed.

## Sprint 2 — Ace3 substrate re-seat (Theme A)
The keystone. Each sub-step covered by a failing-then-passing test before the runtime swap.

- [ ] **S2.1 — Vendor AceEvent/AceTimer/AceConsole** (AT-08) folder-per-lib; add to TOC libs section. *Done:* `LibStub("AceEvent-3.0")` resolves; addon loads.
- [ ] **S2.2 — AceAddon registration + init move** (AT-12). New `core/<Addon>.lua`; DB init + bar build + event wiring move into `OnInitialize`/`OnEnable`, reproducing current PLAYER_LOGIN sequencing. *Done:* smoke test — bar appears on login, panel opens, `/at` works.
- [ ] **S2.3 — Events onto AceEvent** (AT-17). Convert `Events.lua` + `LSMPatch.lua` frames. *Done:* absorb updates + LSM border fixup still fire; no raw event frames remain.
- [ ] **S2.4 — Timer onto AceTimer** (AT-08). Convert `Timer.lua`, keep interval-change guard. *Done:* `/at set updateInterval` still reschedules; test covers the guard.
- [ ] **S2.5 — Slash onto AceConsole** (AT-14). Replace `SLASH_*`/`SlashCmdList` with `:RegisterChatCommand`; dispatcher body unchanged. *Done:* `/at` and `/absorbtracker` work; `test_slash.lua` covers unknown-verb + help.

## Sprint 3 — Tier-2 layout & rename (Theme B)
Highest-diff; do only with Sprints 0–2 green so behavior is pinned.

- [ ] **S3.1 — Move to canonical tree** (AT-01, AT-02). Relocate files into `core/ defaults/ settings/ locales/ modules/`; fold `Options/*` + `Panel/*` into `settings/`. Update TOC paths (with S4.1). *Done:* addon loads from new paths; tests green; tier declared in CLAUDE stub.
- [ ] **S3.2 — Namespace rename** (AT-11). `AddonName, AddonTable` → `addonName, NS` repo-wide, isolated commit. *Done:* pure-rename diff; tests + lint green.

## Sprint 4 — TOC finalize (Theme C-remainder)
- [ ] **S4.1 — TOC metadata + listing** (AT-04, AT-05, AT-06, AT-09). Fix `IconTexture` case; add `X-Standard`, `X-Curse-Project-ID: 1450165`, `X-Wago-ID`; reorder `OptionalDeps`; re-vendor lib folders to `libs/` root (`libs/LibStub/`, `libs/AceAddon-3.0/`…); sectioned file listing (`# Libraries/Locales/Core/Defaults/Modules/Settings`); single trailing newline. *Done:* TOC matches §2.1/§2.5; addon loads.

## Sprint 5 — Locales, Compat, prefix (Theme E)
- [ ] **S5.1 — `locales/enUS.lua`** (AT-16). Metatable-fallback `NS.L`; wrap user strings incrementally. *Done:* `NS.L` present; strings routed; enUS-only ships.
- [ ] **S5.2 — `core/Compat.lua`** (AT-18). Single `GetAddOnMetadata` shim; replace both inline copies. *Done:* no deprecated call outside Compat.
- [ ] **S5.3 — Shared `NS.PREFIX`** (AT-15). Expose constant; `Print` reads it. *Done:* no `local PREFIX`.

## Sprint 6 — Media & optional console (Theme H)
- [ ] **S6.1 — `media/logos/`** (AT-03). Move logo `.tga`/`.jpg`; repoint `LOGO_PATH`. *Done:* logo renders from `media/logos/`.
- [ ] **S6.2 — Debug console** (AT-19). Either ship `core/DebugLog.lua` per §12 (recommended, now Tier 2) or formally document the chat fallback. *Done:* console renders + monospace font vendored, **or** deviation documented as accepted §12.7 fallback.

## Sprint 7 — Docs normalization (Theme G)
- [ ] **S7.1 — CLAUDE stub** (AT-23). Reduce root `CLAUDE.md` to a stub; move brief to `docs/`. *Done:* root CLAUDE ≤ ~25 lines, points to docs.
- [ ] **S7.2 — ARCHITECTURE to docs/** (AT-24). `git mv`; align sections to §15.3; fix links. *Done:* root holds only README + CLAUDE stub + LICENSE (+ dotfiles).
- [ ] **S7.3 — README normalize** (AT-25). Canonical §15.1 order; add `## Testing`, X-Standard + Wago badges; fold non-canonical sections into Usage/FAQ. *Done:* section order matches §15.1; Testing present.

---

## Suggested grouping for delivery
- **Milestone 1 (invisible-to-users infra):** Sprint 0 + Sprint 1 — gate + SV correctness.
- **Milestone 2 (substrate):** Sprint 2 — Ace re-seat; the riskiest, gated by Milestone 1's tests.
- **Milestone 3 (structure):** Sprint 3 + Sprint 4 — layout, rename, TOC.
- **Milestone 4 (polish):** Sprints 5–7 — locales, Compat, media, console, docs.

## Coverage check — every deviation is scheduled
AT-01 S3.1 · AT-02 S3.1 · AT-03 S6.1 · AT-04 S4.1 · AT-05 S4.1 · AT-06 S4.1 · AT-07 S1.1 · AT-08 S2.1/S2.4 · AT-09 S4.1 · AT-10 (fold into S2.2 — stash `NS.AceGUI` during re-seat) · AT-11 S3.2 · AT-12 S2.2 · AT-13 S1.2 · AT-14 S2.5 · AT-15 S5.3 · AT-16 S5.1 · AT-17 S2.3 · AT-18 S5.2 · AT-19 S6.2 · AT-20 S0.2 · AT-21 S0.1 · AT-22 S0.3 · AT-23 S7.1 · AT-24 S7.2 · AT-25 S7.3.

> **AT-10** has no dedicated step; close it opportunistically in S2.2 by stashing `NS.AceGUI = LibStub("AceGUI-3.0")` at load and reading the upvalue in the (relocated) panel builders.
