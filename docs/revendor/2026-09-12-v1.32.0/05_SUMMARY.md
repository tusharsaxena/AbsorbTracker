# 05 — Summary: LibKa0s v1.31.0 → v1.32.0

## The move

| | |
|---|---|
| From | v1.31.0 |
| To | **v1.32.0** (tag commit `e18dd12`) |
| Files that moved in `libs/LibKa0s/` | `Options.lua` (`MINOR` 15 → 16), `Slash.lua` (`MINOR` 7 → 8) |
| Kit revision | 17, unchanged |
| Files removed upstream | none |
| Cross-major skew found | none |

## What was adopted

The Options bulk bracket, together with the rest of the debug-logging-§10 rollout for this addon.
Here is what each act now logs, with debug on:

| Act | Lines logged |
|---|---|
| Appearance page **Defaults** | `[Set] reset appearance: N rows` (N = rows whose value changed; up to 59) |
| General page **Defaults** | `[Set] reset general: N rows` (up to 9) |
| Either Defaults, page already at defaults | `[Set] reset <page>: 0 rows` |
| **Reset all settings** (popup) / `/at resetall`, live or degraded | `[Set] reset profile 'Default' to defaults (68 rows)`, the only line |
| Degraded Reset All with no AceDB | `[Set] reset all: N rows` |
| Profiles page / `/at profile reset` | `[Set] reset profile '<name>' to defaults (68 rows)` |
| Profiles page / `/at profile copy <src>` | `[Set] copied profile '<src>' → '<name>'` |
| Profile switch | `[Profile] changed → <name>`, unchanged |
| **Copy styling from Player** | `[Set] copy player→<unit>: N rows` (N = keys whose value changed, mirror clear included; up to 20) |
| `/at reset <path>` | `[Set] <path> = <value>`, unchanged (#30) |

No act emits a per-row `[Set]` line. Reactor lines such as `[Bar] …` stay, as §10 allows.

## What was declined

The Slash bracket, because `/at resetall` never reaches `CliResetAll`. No issue was filed.

## Gates

| When | `lua tests/run.lua` | `luacheck .` | lizard `-C 15` |
|---|---|---|---|
| Baseline, `8eeb11a` | 565 passed, 0 failed, 0 skipped | 0 / 0 in 54 files | clean |
| Re-vendor, `291ee44` | 565 passed, 0 failed, 0 skipped | 0 / 0 in 54 files | clean |
| Tests only, before the code | 567 passed, **14 failed** | — | — |
| Adoption, `aebd427` | **581** passed, 0 failed, 0 skipped | 0 / 0 in 54 files | clean |

`tests/test_vendor_sync.lua` compared both payloads against the tag CLAUDE.md names and skipped
none. Every changed file is CRLF, with CR equal to LF. Nothing was pushed.
