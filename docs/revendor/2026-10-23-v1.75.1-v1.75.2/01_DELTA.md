Delta: LibKa0s v1.75.1 -> v1.75.2 (span: v1.75.1 v1.75.2)

# 01 — Delta (span, AbsorbTracker)

Written 2026-10-23 by plan item AT-RV of the sim/preview/strips run, beside
`docs/revendor/2026-10-23-v1.76.0/`, because two tags this addon vendored have no bundle of their own.
Both were carried by standalone re-vendor commits after the v1.75.0 run.

The listing (`/dev-copilot:wow-revendor-libka0s` Step 3h): vendored tags walked from
`git log --since="2026-08-25 00:00" --format=%H -- libs/LibKa0s tests/_kit` plus the `CLAUDE.md`
commits that roll the provenance line, minus the tags the `docs/revendor/*/` bundles record, printed:

```
v1.75.1
v1.75.2
```

The carrying commits (`git log --format='%h %s' -- libs/LibKa0s tests/_kit | head -2`):

```
d8de275 Re-vendor LibKa0s v1.75.2 (SimPanel minor 4)
196511a Re-vendor LibKa0s v1.75.1 (SimPanel minor 3)
```

Each replaced `libs/LibKa0s/SimPanel.lua` only (SimPanel 2 -> 3 -> 4) and rolled the provenance line;
`tests/_kit/` stayed at revision 41.
