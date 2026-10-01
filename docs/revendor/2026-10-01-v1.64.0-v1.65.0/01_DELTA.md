Delta: LibKa0s v1.64.0 -> v1.65.0 (span: v1.64.0 v1.65.0)

# 01 — Delta (consolidated span)

Written 2026-10-01 by plan item GI-AT-RV of the 2026-10-01 GitHub issue pass
(`Ka0sAddonsCommonTasks/docs/2026-10-01-GITHUB_ISSUE_PASS/`), beside this run's own bundle
`docs/revendor/2026-10-01-v1.66.0/`. Two tags this addon vendored were never given a bundle of their
own; this span records them (the revendor command's step 3h).

## The listing

The standards audit's re-vendor walk, run from the repo root before this run's copy:

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)      # 2026-08-25
tag_at() { git show "$1:CLAUDE.md" 2>/dev/null |
  grep -oE 'Bundles \[LibKa0s\]\([^)]*\) v[0-9]+\.[0-9]+\.[0-9]+' |
  grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1; }
{ git log --since="$horizon 00:00" --format=%H -- libs/LibKa0s tests/_kit
  git log --since="$horizon 00:00" --format=%H -- CLAUDE.md | while read -r c; do
    [ "$(tag_at "$c")" != "$(tag_at "$c^")" ] && echo "$c"; done
} | while read -r c; do tag_at "$c"; done | sed '/^$/d' | sort -uV > vendored.txt
# recorded.txt: every bundle folder's tag(s), span bundles by their line 1
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.64.0
v1.65.0
```

The commits that carried them (`git log --format='%h %ad %s' --date=short -- libs/LibKa0s tests/_kit`):

- `9cabbb5` 2026-09-30 DL-AT-01: re-vendor LibKa0s v1.64.0 (kit revision 33), resize smoke checks
- `39c86f9` 2026-09-30 DL-AT-03: re-vendor the final LibKa0s v1.64.0 (DebugLog 17, DebugLogDiagnostics 2, kit 34)
- `1469a8b` 2026-10-01 DG-AT-01: re-vendor LibKa0s v1.65.0 (Slash 18, DebugLog 18 + DebugLogGates 1, Options 27, Launcher 5, Lifecycle 3; kit 34)

The newest single-tag bundle before this one, `docs/revendor/2026-09-29-v1.63.0/`, names base v1.62.0
and new v1.63.0, which matches the provenance line before its re-vendor. The chain from v1.63.0 to
v1.65.0 is carried by the three commits above.
