-- core/MediaSetup.lua — the LibKa0s-Media-1.0 seam: where this addon's shared art
-- and its monospace face come from.
--
-- ---------------------------------------------------------------------------
-- THE FONT USED TO BE OURS, AND THAT WAS THE PROBLEM
-- ---------------------------------------------------------------------------
--
-- This addon shipped its own copy of JetBrains Mono under `media/fonts/`
-- (JetBrainsMono-Regular.ttf + OFL.txt) and registered it with LibSharedMedia by
-- hand in core/AbsorbTracker.lua's OnInitialize. Every other Ka0s addon shipped
-- the same face the same way, which is two copies of one binary, two licenses to
-- track, and — the part that actually bites — two LibSharedMedia registrations of
-- the key "JetBrains Mono" against two different SETS OF BYTES. Whichever addon
-- registered last won, and which one that was decided what the player's console
-- actually rendered in.
--
-- The bytes now ship inside the LibKa0s payload (`LibKa0s-Media-1.0`, under
-- libs/LibKa0s/media/) and arrive with the vendored library, and
-- `Media.RegisterLSM` below does the registering so no consumer has to spell the
-- path itself.
--
-- WHAT THAT DID AND DID NOT FIX, precisely, because the difference matters to
-- anyone reasoning from it. The PATH STRINGS still differ per consumer: a
-- vendored library has one copy per addon folder, so `lib.Font` builds
-- `…\AbsorbTracker\libs\LibKa0s\media\fonts\…` for us and
-- `…\MythicMeters\libs\LibKa0s\media\fonts\…` for the next addon — which is
-- exactly why `lib.Font` takes an addonName at all. Two Ka0s addons therefore
-- still register one key against two strings, and last-in still wins. What
-- changed is that the two strings now resolve to IDENTICAL BYTES under identical
-- licensing, so which registration wins no longer changes what the player sees.
-- Do not key anything on a registration being unique, and do not drop a
-- defensive re-register on the grounds that there is only one.
--
-- The icon catalog rides along with it. This addon draws no chrome of its own —
-- its three absorb bars have no title bars and no controls, and its settings
-- panel is LibKa0s-Options-1.0's — so nothing here calls `NS.Icon`; see the note
-- on it below.
--
-- ---------------------------------------------------------------------------
-- WHY THE LIBRARY HAS TO BE TOLD OUR NAME
-- ---------------------------------------------------------------------------
--
-- A texture path is absolute from `Interface\AddOns\`, and LibKa0s is VENDORED:
-- every consumer has its own copy at its own path, and a copy cannot know which
-- addon folder it was copied into. So the library asks, and this file is where
-- the answer lives — `addonName`, the first vararg every TOC-loaded file gets.
-- Never the frame-name prefix, never the `## Title`, never a hand-typed literal:
-- a wrong texture path draws nothing and raises nothing, so a typo here is a bug
-- nobody discovers.
--
-- ---------------------------------------------------------------------------
-- WHY THIS LOADS BEFORE core/Constants.lua
-- ---------------------------------------------------------------------------
--
-- `Constants.FONT_MONO` is resolved from `NS.MediaFont` at load, so the seam has
-- to be published first. A Constants that loaded ahead of this file would resolve
-- the console's face to its FRIZQT__.TTF fallback on a perfectly healthy install, and
-- nothing would say so — the console would simply stop being monospace. That is
-- why this file's TOC position is load-bearing rather than conventional, and the
-- TOC line says so beside it. tests/test_loadorder.lua pins the ordering.
--
-- ---------------------------------------------------------------------------
-- WHAT A DEGRADED INSTALL GETS
-- ---------------------------------------------------------------------------
--
-- No LibKa0s means no art and no face: both are inside the payload that is
-- missing. `NS.Icon` answers nil, which is the answer the library's own title-bar
-- controls already handle — they fall back to the multiplication sign and word
-- labels they drew before the art existed — and `NS.MediaFont` answers nil, which
-- core/Constants.lua turns into its own `C.FALLBACK_FONT` literal, FRIZQT__.TTF.
-- A literal rather than `_G.STANDARD_TEXT_FONT`, because the last rung of a
-- fallback ladder must not itself be able to be nil. Neither is an error: the
-- chrome degrades and every line of the log stays readable.
--
-- NIL IS NEVER ROUTED AROUND. Nothing here builds a path by concatenation to
-- paper over an absent library or an unknown name; a plausible path to a file
-- that is not there is strictly worse than nil, because nil is a value a caller
-- can branch on and a bad path is a control that is silently absent forever.

local addonName, NS = ...

local Media = LibStub and LibStub("LibKa0s-Media-1.0", true)

--- The texture path for one shipped icon, or nil.
---
--- NO CALL SITE TODAY, AND THAT IS RECORDED HERE RATHER THAN LEFT TO BE
--- REDISCOVERED. `grep -rn "NS.Icon" core modules settings defaults locales`
--- finds this definition and nothing else. The two windows that DO draw this
--- collection's marks — the debug console with its Copy window, and the perf
--- step panel — never come through here: they are drawn entirely inside
--- libs/LibKa0s, which builds its own paths through `Media.Icon(addonName, …)`
--- once it is handed our folder name in core/DebugLogSetup.lua's descriptor and
--- by core/CoreSetup.lua's MakeCloseButton wrapper. Delete this function and not
--- one pixel moves.
---
--- It is published anyway, as the other half of a two-function seam whose font
--- half core/Constants.lua does call, and for the first control this addon draws
--- itself. If the collection's dead-export sweep reaches it and no such control
--- has arrived, deleting it is the right answer — tests/test_mediasetup.lua's
--- NS.Icon cases go with it, and the marks that reach the screen stay covered by
--- the addonName spies in tests/test_debuglog.lua and tests/test_coresetup.lua.
---
--- EXTENSIONLESS by contract: this answers `...\media\icons\close`, never
--- `close.tga`. The client appends the extension, and the collection has already
--- recorded that a path carrying `.tga` is one of the two spellings that draws
--- nothing at all.
---
--- THAT RULE IS ABOUT THIS CATALOG, NOT ABOUT EVERY TEXTURE PATH, and the
--- distinction is worth spelling out because the unscoped reading trims the wrong
--- path. `core/Constants.lua`'s `C.LOGO_PATH` names the About-page logo WITH its
--- `.tga`, has done since before this seam existed, and renders — smoke item `11a`
--- has walked it every release. It is this addon's own art, not one of the
--- library's names, and it is not governed here. What is recorded is narrower: for
--- a path the library BUILDS from `ICONS`, the extensionless spelling is the
--- contract, because the file on disk is `<name>.tga` while the catalog stores
--- `<name>` — appending `.tga` there produces a path nothing has ever written, and
--- the client draws nothing and raises nothing. Do not read it as a ban on
--- extensions in hand-written paths elsewhere in this addon.
---
--- NIL IS A REAL ANSWER, twice over: the library may be absent, and the name may
--- not be one the library ships. Both mean the same thing to a caller — draw
--- something else.
---
--- @param name string  an entry of the library's `ICONS` catalog, e.g. "close"
--- @return string|nil
function NS.Icon(name)
    if not Media then return nil end
    return Media.Icon(addonName, name)
end

--- The path of one shipped font face, or nil when the library is absent or the
--- name is not one it carries.
---
--- @param name string  a key of the library's `FONTS`, e.g. "JetBrains Mono"
--- @return string|nil
function NS.MediaFont(name)
    if not Media then return nil end
    return Media.Font(addonName, name)
end

-- REGISTERED AT FILE LOAD, not at PLAYER_LOGIN, and that is a change from what
-- this addon used to do. The hand-rolled `LSM:Register("font", "JetBrains Mono",
-- …)` lived in core/AbsorbTracker.lua's OnInitialize, which is late: LibSharedMedia
-- is vendored under libs/ and has therefore already run by the time the TOC reaches
-- core/, while defaults/Profile.lua names faces at load time. Deferring leaves a
-- window in which a shipped default names a face LSM has never heard of.
--
-- What registration buys over the bare path is the settings panel: a registered
-- face appears in the Font page's dropdown beside every other font the player has,
-- and a profile then stores the NAME — portable across installs — rather than a
-- path naming one addon's folder. The library's call is idempotent and points every
-- consumer at one set of bytes under one key, which is what makes two Ka0s addons
-- registering "JetBrains Mono" agree rather than collide. It registers the shared
-- statusbar textures under the same rule, so they appear in the Bar page's texture
-- dropdown too.
if Media then Media.RegisterLSM(addonName) end
