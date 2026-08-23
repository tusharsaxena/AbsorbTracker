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
- **`docs/testing.md`** — how to verify: the headless harness, lint, the green gate, and the
  release-time complexity checkpoint.
- **`DEPENDENCIES.md`** (root) — what to install to build, run, test or release this addon, with
  WSL2/Ubuntu commands and evidence per entry (documentation-§7).
- Topic detail in `docs/` — **Tier 1 is always present**: `scope.md`, `module-map.md`, `schema.md`, `settings-panel.md`, `data-flow.md`, `common-tasks.md`. Conditional and addon-specific docs vary; `docs/ARCHITECTURE.md` → `## Documentation map` lists every page under `docs/` and says which conditional ones do not apply here (`documentation-§3`).

## The `docs/` set — there is no `agent-context.md`

The canonical `docs/` set is exactly three files: **`ARCHITECTURE.md`** (what this addon is),
**`testing.md`** (how to verify) and **`smoke-tests.md`** (in-game checks) — plus the generated
`test-cases.md` and the topic-detail docs. **Five verification-and-record docs are required** on top
of the six Tier 1 topic-detail docs named above, and these are the five (documentation-§3):
`test-cases.md`, `performance.md`, `perf-analysis/README.md`, `automated-tests/README.md`,
`automated-tests/RESULTS.md`.

The repo **root** ships exactly three docs plus `LICENSE`, and never a fourth: the full
**`README.md`** (player-facing), this **`CLAUDE.md`** stub, and **`DEPENDENCIES.md`** (the toolchain
contract). Everything else lives under `docs/`.

**`docs/agent-context.md` does not exist in this repo and MUST NOT be created.** The standard
deleted it in **v2.17.0**; shipping it is **anti-pattern #49**. It held `NEW_ADDON_CONTEXT.md` —
the scaffolding pack — which is fetched at runtime and never stored: a copy in the repo describes
the addon on the day it was born, forever, and because it loads as *working context* a stale copy
does not go quiet, it gets **followed** (documentation-§3). This root `CLAUDE.md` is the repo's
only agent brief.

Older audit bundles, review bundles and plans under `docs/` predate v2.17.0 and still
name the file, and some describe a four-file or a pre-v2.3.0 `agent-context.md`-based set. Those
are **frozen history** — never treat them as a live requirement, and never "restore" the file.

## Working rules

Terse replies; cite code as `file_path:line`; no summary the diff already gives. Comment only the
non-obvious *why* (invariant, Blizzard quirk, constraint), never what well-named code does. Don't
create docs or planning files unless asked. This repo is **CRLF on disk** (enforced by
`.gitattributes`) and mirrored across two WSL paths
(`/mnt/d/Profile/Users/Tushar/Documents/GIT/AbsorbTracker` and `/home/tushar/GIT/AbsorbTracker`) —
after a direct disk write that landed LF, convert with `sed -i 's/\r$//; s/$/\r/'`.

## LibKa0s is vendored — fix it upstream

Bundles [LibKa0s](https://github.com/tusharsaxena/LibKa0s) v1.10.1 (MIT).

That line is the **provenance record** for both vendored payloads, and it is an input rather than a
note: `tests/test_vendor_sync.lua` greps it out of *this* file and compares `libs/LibKa0s/` and
`tests/_kit/` byte-for-byte against what LibKa0s published at that tag. So it moves in the same
commit as the bytes do — bump one without the other and the gate goes red, which is the whole point.
It lived in `README.md` until testkit revision 9; the README is player-facing and a vendored-library
inventory was never something a player needed.

`libs/LibKa0s/` is **vendored**; its upstream is the LibKa0s repo. Never edit it here — change it
upstream and re-vendor. `tests/_kit/` is vendored the same way (from LibKa0s/testkit), so a local
"fix" there forks a shared file. Both sit outside `luacheck .` via `exclude_files`.

`libs/LibKa0s/LibKa0s.xml` loads six modules across nine files — Core, Media, DebugLog, Slash,
Options (`Options` + `OptionsWidgets` + `OptionsScroll`) and Perf (`Perf` + `PerfPanel`). Five of
them take a descriptor; `LibKa0s-Media-1.0` does not — it is a path resolver, and its seam
(`core/MediaSetup.lua`) only has to tell it this addon's FOLDER name, which a vendored library
cannot work out for itself. This addon binds them in six seams: **`core/MediaSetup.lua`**, **`core/CoreSetup.lua`**, **`core/DebugLogSetup.lua`**, **`core/PerfSetup.lua`**,
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
