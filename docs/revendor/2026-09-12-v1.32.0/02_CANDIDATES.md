# 02 — Candidates: LibKa0s v1.32.0

Sources: the v1.32.0 block of `CHANGELOG.md` at the tag; `docs/api/Options/version-16.15.4.3-docs.md`
and `docs/api/Slash/version-8-docs.md` at the tag; standard v2.44.0 `debug-logging-§10`
(WowAddonStandards `7883278`, branch `feat/2026-09-12-named-state`).

## Class A: delivered on the copy alone

| Item | Evidence | What it does here |
|---|---|---|
| Options 16 and Slash 8 with neither bracket field supplied | CHANGELOG v1.32.0: "A host that supplies neither new field runs the exact walk it ran at v1.31.0, with no `pcall` on the path" | Nothing. 565/565 on the copy alone (`291ee44`). |

## Class B: host change required

### B1. The Options bulk bracket (`bulkBegin` / `bulkEnd`)

- **What:** two optional descriptor fields, called around `RestoreDefaults(pageKey)` (`"reset"`,
  `pageKey`) and `RestoreAllDefaults()` (`"reset"`, `"all"`). `bulkEnd` gets
  `info.profileReset`, which is true when `resetProfile` ran and returned.
- **Fit:** direct. This addon's page Defaults buttons (Appearance, General) and Reset All (the
  popup and `/at resetall`) all go through them, and the seam `NS.SetByPath`
  (`settings/Schema.lua`) logged one `[Set]` per row: 59 lines for an Appearance press, and 9 for
  a General one. §10 makes a bulk reset one line.
- **Recommendation:** adopt, together with the rest of the §10 rollout for this addon (B3, B4).

### B2. The Slash bulk bracket around `CliResetAll`

- **Fit:** none. `/at resetall` is a host verb (`runResetAll`, `settings/Slash.lua:157`) that
  calls `NS.Helpers.RestoreAllDefaults`. It never reaches `cli:CliResetAll`, and no other path
  does. A bracket on the Slash descriptor would never be called.
- **Recommendation:** not adopted.

### B3. The profile handler worded by event (§10, no library surface)

`core/Database.lua` wired all three AceDB events to `NS.OnProfileChanged`, which logged
`[Profile] changed → X` for a reset and for a copy as well. §10 wants one line from the handler,
worded by the event.

### B4. `Units.CopyFromPlayer` (§10, no library surface)

It is a bulk copy that logged twenty `[Set]` lines (`core/Units.lua:115`), and
`tests/test_units.lua:132` asserted that it did. §10 wants one line.

## Class C: whole-module adoption

None. No major was added.
