Delta: LibKa0s v1.16.0 -> v1.54.2 (span: v1.16.0 v1.18.0 v1.18.1 v1.19.0 v1.23.0 v1.24.0 v1.26.0 v1.27.0 v1.28.0 v1.29.0 v1.36.0 v1.36.1 v1.36.2 v1.37.0 v1.38.0 v1.39.0 v1.42.0 v1.43.0 v1.44.0 v1.45.0 v1.46.1 v1.47.0 v1.50.0 v1.51.0 v1.52.0 v1.53.0 v1.54.2)

# 01 - Delta: the consolidated span bundle

Run: 2026-09-24, plan item AT-25 of the 2026-09-23 review and standards-audit remediation (the
folder carries the plan's date). It resolves audit finding AbsorbTracker-A-01. This is the
consolidated span bundle that `audit-review-history` sanctions for a lapsed span. It holds
`01_DELTA.md` and `05_SUMMARY.md` only. The middle three files record deliberation, and these tags
were carried by sweeps that had none. Nothing here was re-derived against the library. The bundle
records what the repository's own history shows.

## Where the tag list comes from

The `span:` list on line 1 was not typed by hand. It is what the step-4 re-vendor check in
WowAddonStandards `AUDIT.md` (as amended by WS-01) printed as unrecorded, run from this repo root
before this bundle existed:

- Horizon: `2026-08-25`, the store's first bundle, applied as `--since="2026-08-25 00:00"`.
- Vendored: 37 tags, read from the `CLAUDE.md` provenance line at each commit that touched
  `libs/LibKa0s` or `tests/_kit`.
- Recorded: 10 tags (v1.15.0, v1.25.0, v1.30.0 to v1.35.0, v1.55.0, v1.56.0).
- Unrecorded: the 27 tags on line 1.

With this bundle in place the same check prints nothing.

## Correction to the finding's count

The audit finding and the plan item named 24 tags, v1.18.0 to v1.53.0, ending at v1.55.0. The
amended check finds three more. This bundle records all 27, so it is named for the span's real
first and last tags:

- **v1.16.0** (`6c3af3d`, 2026-08-25 14:26). The pre-amendment check passed the bare date to
  `--since`, which git reads as "since this time of day". That dropped the horizon's own morning.
- **v1.43.0** (`6749258`) and **v1.54.2** (`7cfb347`). Both were kit-only re-vendors, and the
  pre-amendment check walked `libs/LibKa0s` alone.

The span ends at v1.54.2, not v1.55.0. v1.55.0 has its own bundle,
`docs/revendor/2026-09-23-v1.55.0/`, and its line 1 correctly names base v1.54.2.

No frozen bundle misstates its base. Each single-tag bundle's line 1 was checked against the
provenance history below: 2026-08-25 (v1.15.0), 2026-09-03 (v1.24.0 -> v1.25.0), 2026-09-12
(v1.29.0 -> v1.30.0), the v1.31.0 to v1.34.0 bundles, 2026-09-14 (v1.34.0 -> v1.35.0),
2026-09-23-v1.55.0 (v1.54.2 -> v1.55.0) and 2026-09-23-v1.56.0 (v1.55.0 -> v1.56.0). None was
edited.

## Tag to vendoring commit

Source: `git log --since="2026-08-25 00:00" --format='%h %ad %s' --date=short -- libs/LibKa0s tests/_kit`,
with each commit's tag read from `git show <sha>:CLAUDE.md` (`Bundles [LibKa0s](...) vX.Y.Z`),
cross-checked against `git log -p -- CLAUDE.md | grep -n 'LibKa0s v'`. "Payload" is what the commit
copied: L is `libs/LibKa0s/`, K is `tests/_kit/`.

| Tag | Commit | Date | Payload | Subject |
|---|---|---|---|---|
| v1.16.0 | `6c3af3d` | 2026-08-25 | L + K | Re-vendor LibKa0s v1.16.0 |
| v1.18.0 | `e4977c8` | 2026-08-26 | L | Re-vendor LibKa0s v1.18.0 and take the library's resetProfile field |
| v1.18.1 | `1ece01d` | 2026-08-26 | L | Re-vendor LibKa0s v1.18.1: the landing logo stops pooling its texture |
| v1.19.0 | `2829eb6` | 2026-08-27 | L | Carry LibKa0s v1.19.0 |
| v1.23.0 | `689d5c8` | 2026-09-01 | L + K | Re-vendor LibKa0s v1.23.0: the tabbed page and the page banner |
| v1.24.0 | `7646029` | 2026-09-02 | L | feat(settings): master controls, composed appearance groups, unit-scoped class colour |
| v1.26.0 | `6fb0a70` | 2026-09-08 | L | M3-03: adopt LibKa0s v1.26.0 and delete the media-values workaround |
| v1.27.0 | `40cb76e` | 2026-09-08 | L + K | M4-01: adopt LibKa0s v1.27.0, and wire the gate that came with it |
| v1.28.0 | `86df02a` | 2026-09-09 | L | re-vendor LibKa0s v1.28.0 - the perf usage block renders correctly |
| v1.29.0 | `5249065` | 2026-09-09 | L | re-vendor LibKa0s v1.29.0 - the JSON dump folds into the report step |
| v1.36.0 | `adfacc8` | 2026-09-15 | L + K | Re-vendor LibKa0s v1.36.0 |
| v1.36.1 | `ecbd850` | 2026-09-15 | L + K | Re-vendor LibKa0s v1.36.1: fix pooled CheckBox gold-fill leak |
| v1.36.2 | `add5c64` | 2026-09-15 | L | Re-vendor LibKa0s v1.36.2: drop grid-cell yellow fill, ASCII-only strings |
| v1.37.0 | `6755038` | 2026-09-16 | L | Re-vendor LibKa0s v1.37.0 |
| v1.38.0 | `fcc9ebc` | 2026-09-16 | L | Re-vendor LibKa0s v1.38.0: a bare /at opens the settings panel |
| v1.39.0 | `b75099d` | 2026-09-16 | L | Re-vendor LibKa0s v1.39.0: the Launcher major and the Options peel |
| v1.42.0 | `224a5df` | 2026-09-17 | L + K | Disabling the addon stands it down, and a perf run takes the same latch |
| v1.43.0 | `6749258` | 2026-09-17 | K | Re-vendor LibKa0s v1.43.0: kit revision 23 bounds every run and stops holding built instances |
| v1.44.0 | `ebb7bfa` | 2026-09-19 | L | Re-vendor LibKa0s v1.44.0 |
| v1.45.0 | `e2d5c7c` | 2026-09-19 | L | Re-vendor LibKa0s v1.45.0 |
| v1.46.1 | `e510db6` | 2026-09-19 | L | Re-vendor LibKa0s v1.46.1 |
| v1.47.0 | `9d9dfde` | 2026-09-20 | L | Re-vendor LibKa0s v1.47.0 |
| v1.50.0 | `5ce09cb` | 2026-09-21 | L | Re-vendor LibKa0s v1.50.0 |
| v1.51.0 | `ee09708` | 2026-09-22 | L | Re-vendor LibKa0s v1.51.0 |
| v1.52.0 | `a39a540` | 2026-09-22 | L | Re-vendor LibKa0s v1.52.0 |
| v1.53.0 | `ca833c4` | 2026-09-22 | L | Re-vendor LibKa0s v1.53.0 |
| v1.54.2 | `7cfb347` | 2026-09-22 | K | Adopt the kit's US-English gate, and delete the copy this repo was keeping |

Tags the addon never vendored (v1.17.0, v1.20.0 to v1.22.0, v1.40.0, v1.41.0, v1.46.0, v1.48.0,
v1.48.1, v1.49.0, v1.49.1, v1.54.0, v1.54.1) arrived folded into the next copy. The step-4 check
does not count them and this bundle does not record them. The recorded tags between the span's
ends (v1.25.0, v1.30.0 to v1.35.0) keep their own bundles.

## How adoption was read

For each tag, `05_SUMMARY.md` reads `git log --oneline <vendor-commit>..<next-vendor-commit> -- core settings modules`,
plus the vendoring commit's own authored-code diff. A commit counts as an adoption only when its
message says it takes up a surface that tag delivered. Stub-parity edits, test constants that
follow a library string, and commits that act on the standard rather than on the library are not
counted.
