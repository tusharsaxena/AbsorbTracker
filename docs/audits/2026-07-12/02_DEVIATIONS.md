# 02 — Deviations

**Addon:** Ka0s Absorb Tracker · **Prefix:** `AT-` · **Standard:** v1.0.0 (2026-07-12) · **Run:** 2026-07-12 (first audit)

IDs are stable across runs — a deviation that recurs keeps its ID. Severity: **MUST** = non-negotiable bug; **SHOULD** = strongly preferred (partial/quality). Evidence for each is in `03_EVIDENCE.md`; remediation in `04_TECHNICAL_DESIGN.md` / `05_EXECUTION_PLAN.md`.

## Summary

| Severity | Count |
|---|---|
| MUST | 21 |
| SHOULD | 4 |
| **Total** | **25** |

## Deviations

| ID | § | Severity | Deviation | Fix direction |
|---|---|---|---|---|
| AT-01 | §1.2 | MUST | 20 source files (>8) but no Tier-2 canonical layout — flat root + ad-hoc subfolders; no tier declared. | Promote to Tier 2: `core/ defaults/ settings/ locales/ modules/`; declare tier in `CLAUDE.md`. |
| AT-02 | §1.3 | MUST | Subfolders `Options/` and `Panel/` are PascalCase and are not canonical folder names. | Rename/relocate into lowercase canonical folders (`settings/`, `core/`, `modules/`). |
| AT-03 | §1.4 | MUST | Media not in typed subfolders — runtime logo `.tga` + source art live under `media/screenshots/`; no `media/logos/`. | Move logo `.tga`/`.jpg` to `media/logos/`; keep screenshots in `media/screenshots/`; repoint loader. |
| AT-04 | §2.1 | MUST | TOC field errors: `## iconTexture` wrong case; missing `## X-Standard:`; OptionalDeps ordering. | Rewrite metadata block to exact §2.1 field order incl. `IconTexture`, `X-Standard`. |
| AT-05 | §2.1 | MUST | Published addon (CF 1450165, tagged releases) but TOC lacks `X-Curse-Project-ID` and `X-Wago-ID`. | Add both IDs to the TOC metadata block. |
| AT-06 | §2.5 | MUST | File listing is flat/unsectioned — no `# Libraries/Locales/Core/Defaults/Modules/Settings` headers in load order. | Reorder file listing under the required `#` section comments. |
| AT-07 | §2.2, §5.1 | MUST | No `schemaVersion` in defaults; no `Database.lua` migration runner. | Add `schemaVersion` to global defaults; ship `core/Database.lua` with a `RunMigrations` runner (empty body OK). |
| AT-08 | §3.1 | MUST | Mandatory AceEvent-3.0 / AceTimer-3.0 / AceConsole-3.0 not vendored or used. | Vendor the three libs and migrate events/timers/slash onto them. |
| AT-09 | §3.3 | MUST | Non-standard lib folder layout (`libs/LibStub-1.0/`, Ace3 nested under `libs/Ace3/`). | Re-vendor folder-per-lib at `libs/` root (`libs/LibStub/`, `libs/AceAddon-3.0/`, …); update TOC paths. |
| AT-10 | §3.4 | SHOULD | `LibStub("AceGUI-3.0")` re-fetched inside many builders instead of stashed once. | Stash `NS.AceGUI = LibStub("AceGUI-3.0")` at load; read the upvalue in builders. |
| AT-11 | §4.1 | MUST | Namespace header is `local AddonName, AddonTable = ...`, not the standard `local addonName, NS = ...` (private table is fine; naming deviates). | Rename to `addonName, NS` across files (cosmetic; low risk, high churn). |
| AT-12 | §4.2 | MUST | No AceAddon registration; AceDB created via bare `LibStub` in a raw event handler. | Promote NS to an AceAddon via `AceAddon:NewAddon(NS, addonName, "AceEvent-3.0","AceTimer-3.0","AceConsole-3.0")`; init DB in `OnInitialize`. |
| AT-13 | §4.5 | SHOULD | Boot schema validation checks row shape but not that each `path` resolves against defaults. | Extend `ValidateSchema` to walk each `path` against the defaults table and warn on miss; expose the count for the harness. |
| AT-14 | §7.1 | MUST | Slash registered via `SLASH_ABSORBTRACKER*` globals + `SlashCmdList` (anti-pattern #5). | Register via AceConsole `:RegisterChatCommand("at",…)` + full-name alias; keep the schema-driven dispatcher. |
| AT-15 | §7.4 | SHOULD | Chat tag is a `local PREFIX`, not a shared `NS.PREFIX` constant. | Expose `NS.PREFIX`; route `Print` through it; drop the local. |
| AT-16 | §8 | MUST | No locale module — no `NS.L` metatable fallback, no `locales/enUS.lua`; strings inline. | Add `locales/enUS.lua` with metatable-fallback `NS.L`; route user strings through `L[...]`. |
| AT-17 | §9.1 | MUST | Raw `CreateFrame` event frames (`Events.lua`, `LSMPatch.lua`) instead of AceEvent-3.0. | Move event subscription onto AceEvent (`self:RegisterEvent`) after AT-08/AT-12. |
| AT-18 | §11 | MUST | No `Compat.lua`; deprecated-API fallback duplicated inline in two files. | Add `core/Compat.lua`; route `GetAddOnMetadata` (and any future deprecated call) through one shim. |
| AT-19 | §12 | SHOULD | Debug output routes to chat via `DebugPrint`; no styled on-screen debug console. | Ship a `DebugLog` console per §12 (or keep chat fallback only if the addon stays a no-window Tier-1 utility). |
| AT-20 | §13 | MUST | No `.pkgmeta` at root. | Add `.pkgmeta` (`package-as`, ignore `audit/ docs/ tests/ _dev/`, no `externals:`). |
| AT-21 | §14 | MUST | No `.luacheckrc` at root. | Add `.luacheckrc` (std lua51, exclude `libs/ audit/ tests/`, declare `AbsorbTrackerDB`). |
| AT-22 | §14A | MUST | No `tests/` harness (anti-pattern #24); no TDD. | Add headless Lua 5.1 harness (`run.lua`, `loader.lua`, `wow_mock.lua`, `test_*.lua`) covering schema/parse/format/migration. |
| AT-23 | §15.2 | MUST | Root `CLAUDE.md` is a full agent brief, not a stub (anti-pattern #26). | Reduce root `CLAUDE.md` to a stub; move the brief to `docs/`. |
| AT-24 | §15 | MUST | `ARCHITECTURE.md` sits at repo root; root may ship only README + CLAUDE stub + LICENSE. | Move to `docs/ARCHITECTURE.md`; fix references. |
| AT-25 | §15.1 | MUST | README missing `## Testing`, missing X-Standard + Wago badges, and inserts non-canonical sections that break section order (anti-pattern #28). | Normalize to canonical §15.1 order; add `## Testing`, X-Standard badge/link, Wago badge; fold non-canonical prose into `## Usage`/`## FAQ`. |

## Notable compliant areas (no deviation)
- §4.5 schema-as-single-source (single write seam, boot validation present).
- §6 options UI (canvas landing + subcategories, eager register / lazy body, combat gate, raw AceGUI, always-show scrollbar, layout constants) — §4.5/§6 are this addon's strongest surfaces.
- §6B preview/test mode; §3.5 `RegisterWidgetType` extension; §2.1/§5.1 soft fallbacks; §12.5 session-only debug flag; §15.4 no `TODO.md`.
