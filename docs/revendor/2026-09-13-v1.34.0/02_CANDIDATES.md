# 02 — Candidates: LibKa0s v1.34.0

Sources: the v1.34.0 block of `CHANGELOG.md` at the tag; `docs/api/Options/version-18.15.5.3-docs.md`,
`docs/api/Slash/version-10-docs.md` and `docs/api/testkit/version-19-docs.md` at the tag.

## Class A: delivered on the copy alone

| Item | What it does here |
|---|---|
| Slash 10: a `string` row takes the whole value after the path, trimmed | Every string row this addon ships is an enum. The ones whose values carry a space start working from the CLI: the LSM font, border and statusbar rows composed in `settings/OptionsSetup.lua:247`–`:272` (`"Friz Quadrata TT"`, `"Blizzard Raid Bar"` …) and the font-flag row, whose `"OUTLINE, MONOCHROME"` entry was unsettable. Nothing to wire. |
| Options 18 / OptionsCompose 5, without the new field | The descriptor supplies `resetProfile` (`settings/OptionsSetup.lua:93`), so on the copy alone the Reset-all tooltip moves to *"Reset the current profile to its defaults. Your other profiles are not affected."* |
| Kit 19: the AceDB fake's `OnProfileReset` carries no key | The reset handler takes no parameters (`core/AbsorbTracker.lua:283`). No case moves. |

## Class B: host change required

### B1. `profilesPage = true` on the Options descriptor (O18)

- **Evidence:** `version-18.15.5.3-docs.md`, "What the host does": "A Profiles page and
  `resetProfile`: add `profilesPage = true` to the `lib:New` descriptor."
- **Here:** this addon ships an AceDBOptions Profiles sub-page and supplies `resetProfile`. With the
  field, the General page's Reset-all tooltip reads *"Reset the current profile to its defaults —
  the same thing Profiles → Reset Profile does. Your other profiles are not affected."*, which is
  `options-ui-§12`'s SHOULD.
- **Cost:** one descriptor line, one test, and the settings-panel and smoke-test lines that describe
  the tooltip.

## Class C: whole-module adoption

None. No major was added.
