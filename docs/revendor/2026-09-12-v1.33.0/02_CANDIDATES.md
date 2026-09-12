# 02 — Candidates: LibKa0s v1.33.0

Sources: the v1.33.0 block of `CHANGELOG.md` at the tag; `docs/api/Options/version-17.15.4.3-docs.md`,
`docs/api/Slash/version-9-docs.md` and `docs/api/testkit/version-18-docs.md` at the tag.

## Class A: delivered on the copy alone

| Item | Evidence | What it does here |
|---|---|---|
| Options 17: every LSM font loaded on the first panel show | CHANGELOG v1.33.0: "No descriptor field and no instance member is added" | The descriptor already hands the library `getLSM` (`settings/OptionsSetup.lua:111`), and the Appearance page's font rows go through `H.FontGroup` (`settings/Appearance.lua:233`), which writes `LSM30_Font`. So the first open of a font dropdown now draws every row. Nothing to wire. |
| Slash 9 | Docstrings only | Nothing. |
| Kit 18: the AceDB fake's `OnProfileCopied` carries the source key | testkit version-18 doc, "Through the kit's `CopyProfile`" | This addon's harness runs on the kit's AceDB, so `tests/test_slashcmds.lua:521` and `:647` now exercise the real source name. Neither asserts it, and both stay green. The comment at `:638`–`:639` described the old key; it is corrected in the re-vendor commit. |

## Class B: host change required

None. v1.33.0 adds no descriptor field and no member.

## Class C: whole-module adoption

None. No major was added.
