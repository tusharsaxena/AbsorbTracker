# CLAUDE.md — Ka0s Absorb Tracker

**Tier 2 (modular)** WoW addon. Adheres to the **Ka0s WoW Addon Standard** —
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

- **`docs/agent-context.md`** — the full agent brief (stack, Tier-2 layout, hard rules,
  invariants, the `NS` bus, working environment, response style).
- **`docs/ARCHITECTURE.md`** — module map, settings schema, message bus, slash surface, event
  wiring, taint notes, known limitations.
- Topic detail in `docs/`: `schema.md`, `settings-panel.md`, `data-flow.md`, `profiles.md`,
  `midnight-quirks.md`, `common-tasks.md`, `scope.md`, `file-index.md`, `module-map.md`,
  `smoke-tests.md`.

Green gate before every commit: `lua tests/run.lua` (53 tests) and `luacheck .` (0/0). Syntax-check
one file with `luac -p <file>`. Never auto-stage/commit/push and never bump the version without an
explicit instruction — see `docs/agent-context.md`.
