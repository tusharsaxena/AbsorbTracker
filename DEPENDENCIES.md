# Dependencies

Everything you need installed to build, run, test or release **Ka0s Absorb Tracker**, with commands
that work on **WSL2 / Ubuntu** — the collection's development environment. Per the Ka0s WoW Addon
Standard, `documentation-§7`.

Every entry below names **what needs it and how that is known** — a file and line, a script's call,
or a command this repo documents. Nothing here is listed because it seemed likely. If a tool is only
plausibly required, it says so in words.

Three groups, and most readers need exactly one:

| Group | Who needs it | Short answer |
|---|---|---|
| [Runtime (in-game)](#runtime-in-game) | Players | World of Warcraft (Retail). Nothing else. |
| [Development](#development) | Contributors | Lua **5.1**, `luacheck`, `lizard`, `git`, a POSIX shell. |
| [Release / assets](#release--assets) | Nobody, locally | No local packaging or asset toolchain exists in this repo. |

---

## Runtime (in-game)

**World of Warcraft (Retail)** at the interface the TOC declares — `## Interface: 120007`
(`AbsorbTracker.toc:1`). That is the whole runtime requirement.

The addon declares **no** `## Dependencies` line. Its `## OptionalDeps` (`AbsorbTracker.toc:8`) reads
`Ace3, LibStub, CallbackHandler-1.0, LibSharedMedia-3.0`, and **every one of those is vendored** under
`libs/` and listed in the TOC's `# Libraries` block (`AbsorbTracker.toc:16-30`), alongside `LibKa0s`
(`libs\LibKa0s\LibKa0s.xml`). `OptionalDeps` exists so the client loads a *standalone* copy first when
the user happens to have one; it is not an install instruction. **A player installs the addon and
nothing else** (`library-stack`).

---

## Development

### Lua 5.1 — a hard version requirement, not a preference

The headless harness loads every source file into a sandboxed environment with **`setfenv`**, which
was **removed in Lua 5.2**:

```
tests/_kit/loader.lua:31    setfenv(chunk, makeEnv(mocks))
tests/_kit/loader.lua:48    local chunk, err = loadstring(src, chunkname)
tests/_kit/loader.lua:50    setfenv(chunk, makeEnv(mocks))
```

`loadstring` went the same way in 5.2. So "5.2 will probably work" is **false**: `lua tests/run.lua`
fails at the first file it tries to load. WoW's own client is Lua 5.1 as well, which is why the
harness can run addon source unmodified in the first place. Install **5.1**, not "lua".

```sh
sudo apt install -y lua5.1
```

`luac` — used for the one-file syntax check `luac -p path/to/file.lua` documented in
`docs/testing.md` — arrives in that same package. There is nothing extra to install for it.

**Verify:**

```sh
lua -v      # -> Lua 5.1.x
luac -v     # -> Lua 5.1.x
```

On Ubuntu, `lua5.1` also installs `/usr/bin/lua` pointing at it. If `lua -v` reports 5.3 or 5.4, you
have a second interpreter ahead of it on `PATH`; run the suite as `lua5.1 tests/run.lua`.

### luacheck — the lint half of the green gate

Configured by `.luacheckrc` at the repo root, and one of the two gates `docs/testing.md` requires
green before every commit. Installed through LuaRocks, which needs the Lua 5.1 headers:

```sh
sudo apt install -y lua5.1 luarocks
sudo luarocks install luacheck
```

**Verify:**

```sh
luacheck --version    # -> Luacheck: 1.x
```

**Version: any recent.** Nothing in `.luacheckrc` uses a version-gated option, and pinning a number
here would be false precision.

### lizard — the complexity report

Drives the `complexity` suite of `tests/_kit/run-automated-tests.sh` with the exact invocation `performance-§10` fixes:

```sh
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .
```

That command, the tool version, and the date are stamped in the report's own generated header.

**Install it with `pipx`, not `pip`.** Ubuntu 24.04 marks its system Python `EXTERNALLY-MANAGED`
(PEP 668), so `pip install lizard` **fails** with `error: externally-managed-environment`. This is
the instruction that works:

```sh
sudo apt install -y pipx
pipx ensurepath
pipx install lizard
```

`pipx ensurepath` adds `~/.local/bin` to `PATH`; open a new shell afterwards, or `source ~/.profile`.

The documented alternative, if you would rather not have `pipx`, is to override PEP 668 explicitly:

```sh
pip3 install --user --break-system-packages lizard
```

It works, and it is a documented escape hatch rather than a recommendation — it installs into the
same user site-packages the system Python reads.

**Verify:**

```sh
lizard --version    # -> 1.x
```

**Version: any recent.** The report is compared release to release by the *same* invocation, not by a
pinned tool build; the header records which version produced each report, which is the part that
matters. **lizard is optional**: without it the complexity report simply goes stale, which is a
documented state, not a compliance failure (`performance-§10`). Do not hand-edit the report to
compensate.

### git — required by the test suite, not just by you

The vendor-sync gate shells out to `git` to prove the vendored `libs/LibKa0s/` and
`tests/_kit/` payloads are byte-identical to the LibKa0s release `CLAUDE.md` claims to bundle.
`tests/test_vendor_sync.lua` is one line of adoption; the comparator is part of the payload it
checks, at `tests/_kit/vendor_sync.lua`:

```
tests/_kit/vendor_sync.lua:154   io.popen(('git -C "%s" %s 2>/dev/null'):format(SIBLING, args), "r")
```

It runs `git show` and `git ls-tree` against a **sibling checkout at `../LibKa0s`**
(`tests/_kit/vendor_sync.lua:70`, resolved at `:145`).

```sh
sudo apt install -y git
```

**Verify:** `git --version`

### A sibling `../LibKa0s` checkout — optional, and its absence is sanctioned

The two vendor-sync cases compare against `../LibKa0s`. When that directory is not there, they
report a **skip carrying its reason** — deliberately, and named in the run rather than hidden
(`tests/_kit/vendor_sync.lua:193`, `T.skip("… the vendored payload was NOT compared")`). An
earlier copy returned early instead, which registered as PASS for a comparison that never ran.
Where the folder *is* present, a missing tag, a missing file, an extra file or any content difference
**fails**.

So this is not required to get a green suite, and it **is** required to get the answer those two
cases exist to give. Clone it beside this repo if you are touching `libs/` or re-vendoring:

```sh
git clone https://github.com/tusharsaxena/LibKa0s.git ../LibKa0s
```

**Verify:** `git -C ../LibKa0s rev-parse --short HEAD`

### A POSIX shell with `ls`

Lua 5.1 has no directory API and this repo deliberately does not depend on LuaFileSystem, so two
suites list directories by shelling out:

```
tests/test_docs.lua:41           io.popen("ls -1 " .. pattern .. " 2>/dev/null")
tests/_kit/vendor_sync.lua:114   io.popen(('ls -A "%s" 2>/dev/null'):format(dir))
```

`tests/_kit/vendor_sync.lua:116` falls back to `dir /b` for `cmd.exe`, so that suite survives a Windows
shell; `tests/test_docs.lua` does not, and needs a POSIX shell. Under WSL2 you already have one and
there is nothing to install.

**Verify:** `ls -1 docs/*.md | head -1`

### `diff` (diffutils)

`docs/testing.md` documents `diff -r --strip-trailing-cr ../LibKa0s/LibKa0s libs/LibKa0s` (and three
siblings) as the manual re-vendor check, and `diff <(lua tests/run.lua --list) docs/test-cases.md` as
the inventory sync check. Ships in Ubuntu's base install; listed so the set is complete, not because
you are likely to be missing it. The second command uses process substitution, so run it in `bash` or
`zsh` rather than `sh`.

**Verify:** `diff --version`

### Not dependencies of this repo

Recorded so nobody installs them by mistake:

- **LuaFileSystem** — *not* used. `tests/_kit/vendor_sync.lua:101-102` says so explicitly and shells out
  instead. `luacheck` pulls LFS in as its own dependency; that is LuaRocks' business, not this
  addon's.
- **A CI runner** — there is none. No GitHub Action, no dynamic badge; every gate is local and
  hand-run (`docs/testing.md`, `testing-§5`).
- **Ace3, LibStub, LibSharedMedia-3.0, LibKa0s** — vendored and committed under `libs/`. Listing them
  here does **not** license fetching them at build time (`library-stack`, `packaging`).

---

## Release / assets

**Nothing here is needed to build, run or test the addon.** If you are fixing a typo, stop reading at
the previous section.

And in this repo, the honest content of this section is short: **there is no local packaging or asset
toolchain at all.**

- **Packaging** is done by the **CurseForge packager**, remotely, driven by `.pkgmeta` (which sets
  `package-as: AbsorbTracker`, `enable-nolib-creation: no`, and the ignore list). No `Makefile`, no
  build script, no `*.sh`, no `*.py` exists anywhere in the repo — the addon folder *is* the
  deliverable, which is why libraries are vendored.
- **Assets are committed, not generated.** `media/fonts/JetBrainsMono-Regular.ttf` (with its
  `OFL.txt`), `media/logos/` and `media/screenshots/` are checked in as final files. No script in this
  repo reads, converts or regenerates any of them, so **no image or font tooling is a dependency**.
  Replacing a screenshot is a matter of committing a different PNG.
- **A `.tga` alongside the `.jpg` logo** (`media/logos/`) is the format WoW itself wants for in-game
  textures. Converting a new logo to `.tga` would need an image tool — but that is a one-off authoring
  step outside this repo, and no committed file or command depends on one. **Plausible, not
  evidenced**, and therefore not a dependency.

---

## Am I set up correctly?

Run these from the repo root. `docs/testing.md` is the doc that explains what they check and what to
do when one is red — this file only tells you what to install.

```sh
lua tests/run.lua                                       # the headless suite — all green
luacheck .                                              # 0 warnings / 0 errors
lizard -l lua -x "./libs/*" -x "./tests/_kit/*" .       # the `complexity` suite; recorded in each run bundle
```

The first two are the **green gate**: both must pass before every commit. The third is a **report**
read at release time and is explicitly **not** a commit gate (`performance-§10`).

---

## Keeping this file honest

This list is checked at release alongside the rest of the doc set (`documentation-§5`). A new script,
a new `io.popen` call, a new import, or a tool that stops being used changes this file **in the same
commit** — not in a follow-up. A dependency list that is wrong is worse than one that is missing,
because a reader who installs three unnecessary things stops trusting the fourth entry, which is the
one that mattered.
