# 05 - Summary: LibKa0s v1.16.0 -> v1.54.2 (span)

Plan item AT-25 of the 2026-09-23 review and standards-audit remediation, run 2026-09-24 on branch
`feat/2026-09-23-review-audit-remediation`. It is a documentation-only record. No code, `libs/` or
`tests/_kit/` file changed, and nothing was pushed. `01_DELTA.md` names each tag's vendoring commit
and explains how adoption was read.

## Per tag

- v1.16.0: carried by sweep, nothing adopted
- v1.18.0: adopted in `e4977c8` Re-vendor LibKa0s v1.18.0 and take the library's resetProfile field
- v1.18.1: carried by sweep, nothing adopted
- v1.19.0: carried by sweep, nothing adopted
- v1.23.0: adopted in `156077c` The settings panel becomes three pages with tab strips
- v1.24.0: adopted in `7646029` feat(settings): master controls, composed appearance groups, unit-scoped class colour
- v1.26.0: adopted in `6fb0a70` M3-03: adopt LibKa0s v1.26.0 and delete the media-values workaround
- v1.27.0: adopted in `40cb76e` M4-01: adopt LibKa0s v1.27.0, and wire the gate that came with it; and `2fd2b8a` M4-02: the Border widget fixup becomes a library call
- v1.28.0: carried by sweep, nothing adopted
- v1.29.0: carried by sweep, nothing adopted
- v1.36.0: carried by sweep, nothing adopted
- v1.36.1: carried by sweep, nothing adopted
- v1.36.2: carried by sweep, nothing adopted
- v1.37.0: adopted in `86239b9` Add test mode: a session-only Test mode checkbox in Master controls (withdrawn by `ed20a1e`)
- v1.38.0: carried by sweep, nothing adopted
- v1.39.0: adopted in `a3a2c38` Adopt the launcher: the addon's own icon, and a minimap button
- v1.42.0: adopted in `224a5df` Disabling the addon stands it down, and a perf run takes the same latch
- v1.43.0: carried by sweep, nothing adopted
- v1.44.0: carried by sweep, nothing adopted
- v1.45.0: carried by sweep, nothing adopted
- v1.46.1: carried by sweep, nothing adopted
- v1.47.0: carried by sweep, nothing adopted
- v1.50.0: carried by sweep, nothing adopted
- v1.51.0: carried by sweep, nothing adopted
- v1.52.0: carried by sweep, nothing adopted
- v1.53.0: carried by sweep, nothing adopted
- v1.54.2: adopted in `7cfb347` Adopt the kit's US-English gate, and delete the copy this repo was keeping

## Notes on the calls

- v1.16.0: `9626299` in its window acts on standard v2.35.0 (options-ui-§12) through hooks the
  addon already had. It takes up no v1.16.0 surface.
- v1.27.0: `b55f9ec` (M4-08) finishes the move `2fd2b8a` started. It deletes the private
  `core/LSMPatch.lua` once the library call had taken its place.
- v1.29.0: `f445da8` in its window deletes a dead wrapper. It does not adopt anything.
- v1.36.0: `adfacc8` gives the degraded stub `SelectTab` for parity only. Its own message says this
  is not adoption.
- v1.36.2: `add5c64` updates a test constant to the library's new ASCII arrow. That is carriage.
- v1.37.0: `86239b9` passed `testModePath` to the v1.37.0 MasterControls composer. In the next
  window, `ed20a1e` removed the row when Lock frame became the only preview switch.
- v1.38.0: `fcc9ebc` makes the library-absent Slash stub mirror the bare-`/at` behaviour the bytes
  already delivered. That is stub parity, not adoption.
- v1.46.1: `e510db6` updates host tests to the new combat lock. The addon adopts nothing from it.

## Gates

The kit's prose gate skips `docs/revendor/` by design. The EOL gate reads these files through the
headless run. The results are in the AT-25 commit body.
