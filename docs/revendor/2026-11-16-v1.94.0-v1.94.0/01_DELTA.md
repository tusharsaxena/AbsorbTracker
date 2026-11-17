Delta: LibKa0s v1.94.0 -> v1.94.0 (span: v1.94.0)

Written 2026-11-16 by RV-AT, beside `../2026-11-16-v1.105.0/`. A records-only back-fill: the one tag this addon vendored without a bundle. No code, library or kit file moved because of it.

## Listing

```sh
horizon=$(ls -1 docs/revendor | sort | head -1 | cut -c1-10)    # 2026-08-25
# the audit's walk over libs/LibKa0s and tests/_kit, plus the CLAUDE.md commits that roll the line
# -> vendored.txt ends ... v1.89.0 v1.90.0 v1.91.0 v1.92.0 v1.93.0 v1.94.0
grep -vxF -f recorded.txt vendored.txt
```

Output:

```
v1.94.0
```

v1.94.0 was vendored by `fb0963c` (W1-AT-02) and re-copied after its re-cut by `03998d9` (W1-AT-03), base v1.93.0, under the WoW Forever port wave 1, whose run kept no revendor bundle.
