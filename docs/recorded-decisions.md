# Recorded decisions

Two sets of entries that sit next to the deviation register without being deviations: the rows the
register retired when the standard changed under them, and four choices that cite no rule or meet
the one they cite. Both are here because an audit or a media sweep would otherwise surface them
cold. Ratified deviations themselves live only in
[ARCHITECTURE.md → Documented deviations](./ARCHITECTURE.md#documented-deviations); this page was
that section's tail until the hub was brought back under documentation-§3's spill rule.

## Retired register rows

**Retired on 2026-08-05** — four entries this register carried whose cited rule the standard has since
changed, so the behavior is now permitted outright and a row for it reads as a deviation that is not
one (`documentation-§3`: the register must not become a graveyard):

- **No `## X-Wago-ID` in the TOC.** `toc-file-§1` marks the distribution IDs as mandatory only for a
  platform the addon actually ships on. Absorb Tracker is CurseForge-only, so there is nothing to
  declare and nothing to deviate from.
- **`AbsorbTrackerPerfDB`, a second top-level SavedVariables global.** `savedvariables-§4` now names
  the diagnostics global as the one sanctioned non-AceDB SV, which is exactly what this is.
- **`lizard` as an optional dev dependency.** `performance-§10` mandates the complexity measurement
  and names the tool; `automated-tests-§3` places it outside the commit gate. Both are what this repo
  already does.
- **Instrumentation brackets in hot paths.** `performance-§2` now specifies the bracket idiom itself,
  including the inline `local t0 = Perf.on and debugprofilestop()` shape these files use.

The perf capture ring, the complexity tooling and the bracket idiom are all still described — in
[performance.md](./performance.md) and the hub's `## Performance & Profiler Attribution`, where they
belong as design, not as departures.

## Recorded, but not deviations

The first two entries below cite no rule; the last two cite one and meet it. All four are kept on
this page because an audit or a media sweep would otherwise surface them cold, and the reason
they exist is not obvious from the code.

- **A production test seam: `Helpers.__lastUnitCtx` (`settings/UnitPanel.lua`).**
  `Helpers.RenderUnitPanel` stashes the ctx it just rendered on `NS.Helpers.__lastUnitCtx`.
  **Why, now that the library has its own seams:** `LibKa0s-Options-1.0` does expose `O.__panels()`
  and `O.__panelFor(pageKey)`, so the panel registry is no longer unreachable. What those do not
  answer is *which unit was rendered* — `RenderUnitPanel` is the only renderer that sets `ctx.unit`,
  and a page key alone cannot distinguish the ctx of an Appearance page showing `target` from the
  same page showing `player`. `__lastUnitCtx` hands the harness the live ctx of the last unit render,
  `ctx.unit` and `ctx.activeTab` included, which is what makes the per-unit path (the chrome block's
  picker and mirror controls, the tab strip, the row partition) assertable headlessly instead of only through in-game smoke tests. It is a single dunder-prefixed
  field, written on every render and read by nothing in production — no behavior depends on it.
  Recorded here rather than removed because the coverage it buys is worth more than the purity; if
  the library ever grows a unit-aware panel accessor, this should collapse into it.

- **Non-Blizzard media that is intentionally fixed (no LSM selector).** The bar-appearance media —
  `barTexture`, `bgTexture` (both default `"Blizzard Raid Bar"`), `border` (`"Blizzard Tooltip"`) and
  `font` (`"Friz Quadrata TT"`) — is 100% Blizzard-stock by default and fully user-configurable
  through LSM (`LSM30_Statusbar`/`LSM30_Border`/`LSM30_Font` dropdowns in `settings/Appearance.lua`,
  resolved via `lsm:Fetch` in `core/Data.lua` with Blizzard-stock fallbacks in `core/Constants.lua`).
  Two assets sit outside that model — non-Blizzard *and* deliberately not exposed as a user setting.
  Both are standard-sanctioned; they are recorded here only so a font/texture audit (or a fresh
  `/standards-audit`) re-surfaces them with their justification rather than flagging them:
  - **Debug-console font — JetBrains Mono (OFL), shipped by LibKa0s, not by this addon.** The
    console is `libs/LibKa0s/DebugLog.lua` and renders in whatever face its descriptor's `font`
    names; `core/DebugLogSetup.lua` hands it `C.FONT_MONO`, so the choice of face is still this
    addon's — but the bytes are `libs/LibKa0s/media/fonts/JetBrainsMono-Regular.ttf`, resolved at
    load through `NS.MediaFont` (`core/MediaSetup.lua`) and falling back to `C.FALLBACK_FONT`
    (`Fonts\FRIZQT__.TTF`, a literal in `core/Constants.lua`) when the payload is missing — a
    literal rather than `_G.STANDARD_TEXT_FONT` so the last rung of the ladder cannot itself be nil. `Media.RegisterLSM` registers it with LSM as
    `"JetBrains Mono"` at FILE LOAD (this addon used to register its own copy at init), but the
    console does not read a user font setting. **Why:** a fixed
    monospace face is required for column-aligned debug output (debug-logging-§2). The console's backdrop is
    Blizzard-stock too, but it is no longer the tooltip frame: `WHITE8x8` for both the fill and
    the edge, the edge tinted flat black at `edgeSize = 1`, with a 1px gray highlight synthesized
    just inside it, a gold title and a gray divider. That edge is the **shared Ka0s window edge**,
    not this addon's — it is `LibKa0s-Core-1.0`'s `SKIN` + `ApplySkin` (`libs/LibKa0s/Core.lua`),
    and `core/DebugLogSetup.lua` takes it as-is (it passes neither `skin` nor `applySkin`), so the
    console and the perf panel wear whatever every other Ka0s window wears. The Ka0s WoW Addon
    Standard specifies those values normatively (standalone-windows); the 12px
    `UI-Tooltip-Border` is what the same seam drew before LibKa0s v1.3.0.
  - **About-page logo — `media/logos/absorbtracker.logo.tga`.** `settings/About.lua` draws the
    addon's branding logo via `C.LOGO_PATH`. **Why:** addon branding, not bar appearance; a
    user-swappable logo would be meaningless. Stored under a typed media subfolder per layout-§3.

- **No host window, and so no close-button wrapper (`standalone-windows`).** The section's "wrap
  `MakeCloseButton` exactly once" rule binds the close controls an addon builds on its own windows,
  and this addon builds none: it has no host window, and every window it shows is a library's. The
  debug console and its copy window are `LibKa0s-DebugLog-1.0`'s and `LibKa0s-Widgets-1.0`'s, and
  the perf panel's close control is `LibKa0s-Perf-1.0`'s own arm — `core/PerfSetup.lua:113-126`
  records why the descriptor carries no `decorate` hook. The old `NS.MakeCloseButton` seam came out
  at `f445da8`; the only surviving name is the degraded stub's field in `core/DebugLogSetup.lua`.
  Re-check if the addon ever grows a window of its own.

- **Bootstrap spelling and file headers (`documentation-§9`).** Nineteen authored files open
  `local _, NS = ...` (the nine that read the folder name bind `addonName`, see
  [module-map.md → The `NS` bus](./module-map.md#the-ns-bus)), and luacheck keeps that spelling honest. Seven of the nineteen carry a self-naming
  header comment (`-- AbsorbTracker: settings/General.lua` or `-- core/CoreSetup.lua — …`); the
  section grandfathers the headers already in place, so they stay where they are, and a file
  authored from here follows the section's placement rule.
