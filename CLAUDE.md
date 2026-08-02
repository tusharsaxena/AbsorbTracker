# CLAUDE.md — Ka0s Absorb Tracker

**Ka0s WoW addon.** Adheres to the **Ka0s WoW Addon Standard** —
https://github.com/tusharsaxena/WowAddonStandards

## Standards compliance (read first)

This repo is built to the **Ka0s WoW Addon Standard** (URL above). All development here — new
features, refactors, doc changes — MUST conform to it. The standard is the source of truth for
layout, TOC shape, the Ace substrate, schema-driven settings, slash/prefix conventions, locales,
Compat, tests/lint, and doc structure.

**If a change would deviate from the standard, STOP and flag the deviation explicitly.** Do not
silently deviate and do not silently "fix" to match. Surface it and let the user decide which of
two things it is:

1. **An accepted deviation** — this addon intentionally differs; record it as a documented
   deviation (e.g. in the TOC/README/`docs/` and in the `docs/audits/` bundle), with the reason.
2. **A change to the standard itself** — the standard's definition should evolve; the update
   belongs upstream in the WowAddonStandards repo, after which this addon conforms to the new rule.

When in doubt, treat standard conformance as a hard requirement and ask.

Start here, then read the docs:

- **`docs/ARCHITECTURE.md`** — what this addon is: module map, invariants, settings schema, message
  bus, slash surface, event wiring, taint notes, known limitations.
- **`docs/testing.md`** — how to verify: the headless harness, lint, the green gate.
- Topic detail in `docs/`: `schema.md`, `settings-panel.md`, `data-flow.md`, `profiles.md`,
  `midnight-quirks.md`, `common-tasks.md`, `scope.md`, `file-index.md`, `module-map.md`,
  `smoke-tests.md`, `test-cases.md`, `performance.md`, `complexity.md`.

## Working rules

Terse replies; cite code as `file_path:line`; no summary the diff already gives. Comment only the
non-obvious *why* (invariant, Blizzard quirk, constraint), never what well-named code does. Don't
create docs or planning files unless asked. This repo is **CRLF on disk** (enforced by
`.gitattributes`) and mirrored across two WSL paths
(`/mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker` and `/home/tushar/GIT/AbsorbTracker`) —
after a direct disk write that landed LF, convert with `sed -i 's/\r$//; s/$/\r/'`.

## LibKa0s is vendored — fix it upstream

`libs/LibKa0s/` is **vendored**; its upstream is the LibKa0s repo. Never edit it here — change it
upstream and re-vendor. `tests/_kit/` is vendored the same way (from LibKa0s/testkit), so a local
"fix" there forks a shared file. Both sit outside `luacheck .` via `exclude_files`.

`libs/LibKa0s/LibKa0s.xml` loads five modules across eight files — Core, DebugLog, Slash, Options
(`Options` + `OptionsWidgets` + `OptionsScroll`) and Perf (`Perf` + `PerfPanel`). This addon binds
them in five seams: **`core/CoreSetup.lua`**, **`core/DebugLogSetup.lua`**, **`core/PerfSetup.lua`**,
**`settings/OptionsSetup.lua`** and **`settings/Slash.lua`** — the last being the one major wired
without a separate setup file, because `NS.COMMANDS` has to stay host-owned anyway
(`settings/UnitPanel.lua` then decorates `NS.Helpers` with the two pieces that did not
generalize). Each seam MUST publish the same `NS` names whether the library
loaded or not — that symmetry is what the rest of the addon codes against.

`settings/OptionsSetup.lua`'s no-library stub is deliberately **load-completing, not
member-answering** — the one seam that breaks the honest-line-per-member pattern. `settings/Bar.lua`,
`Border.lua` and `Font.lua` call `NS.Helpers.LSMValues` inside schema-row literals at **file load**, so
a nil aborts the file, `NS.RegisterSchemaRows` never runs, and a third of `NS.Schema` vanishes
silently. `loadDegraded()` in `tests/test_perf.lua` loads the whole TOC without the library and
asserts `#NS.Schema` still matches — do not weaken it.

Green gate before every commit: `lua tests/run.lua` and `luacheck .` (0/0). Syntax-check one file
with `luac -p <file>`. The authoritative test-case count lives in the generated
`docs/test-cases.md` (testing-§5) — when the suite changes, regenerate it via `lua tests/run.lua
--list` and update the README `tests` badge in the same change. Never auto-stage/commit/push and
never bump the version without an explicit instruction — see `docs/testing.md`.
