# CLAUDE.md — Ka0s Absorb Tracker

**Tier 2 (modular)** WoW addon. Adheres to the **Ka0s WoW Addon Standard** —
https://github.com/tusharsaxena/WowAddonStandards

Start here, then read the docs:

- **`docs/agent-context.md`** — the full agent brief (stack, Tier-2 layout, hard rules,
  invariants, the `NS` bus, working environment, response style).
- **`docs/ARCHITECTURE.md`** — module map, settings schema, message bus, slash surface, event
  wiring, taint notes, known limitations.
- Topic detail in `docs/`: `schema.md`, `settings-panel.md`, `data-flow.md`, `profiles.md`,
  `midnight-quirks.md`, `common-tasks.md`, `scope.md`, `file-index.md`, `module-map.md`,
  `smoke-tests.md`.

Green gate before every commit: `lua tests/run.lua` (36 tests) and `luacheck .` (0/0). Syntax-check
one file with `luac -p <file>`. Never auto-stage/commit/push and never bump the version without an
explicit instruction — see `docs/agent-context.md`.
