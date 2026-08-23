-- tests/test_mediasetup.lua — core/MediaSetup.lua, the LibKa0s-Media-1.0 seam.
--
-- THE CASE THAT EARNS THIS FILE is the catalog cross-check. Every mark this addon's windows draw is
-- named as a plain string — here, inside libs/LibKa0s/DebugLog.lua, on behalf of the folder name
-- core/DebugLogSetup.lua hands it — and resolved against a catalog that lives in ANOTHER REPO. If
-- the library renames a mark, or a re-vendor drops a file, the answer is nil, the control silently
-- goes back to a multiplication sign, and every suite stays green: a texture that does not load
-- draws nothing and raises nothing. That is the failure this file exists to catch out of game.
--
-- The other half is the font. It used to be a literal path into this addon's own media/fonts/; it is
-- now resolved through NS.MediaFont at load, and the two ways that can go wrong quietly are a name
-- the library does not carry (nil, and the console falls back to a proportional face) and a payload
-- that shipped without the file (a path to nothing, and the text does not draw at all).

local T = _G.AT_TEST
local NS = T.NS
local mocks = T.mocks
local test, assertEqual, assertTrue, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertNil

local loadDegraded = dofile("tests/degraded_env.lua")

-- The path the vendored payload sits at, spelled the way a WoW texture path is spelled. Built here
-- rather than read from lib.VENDOR_PATH so this case fails when the library changes where it keeps
-- its art, which is exactly the kind of change a consumer must notice.
local VENDORED = "Interface\\AddOns\\AbsorbTracker\\libs\\LibKa0s\\media\\"

local function media()
  local lib = mocks.LibStub("LibKa0s-Media-1.0", true)
  assertTrue(lib ~= nil, "libs/LibKa0s/Media.lua must have loaded and registered its major")
  return lib
end

-- ── the seam ───────────────────────────────────────────────────────────────────────────────────
--
-- WHAT THE NS.Icon CASES BELOW DO AND DO NOT PROVE. They prove the seam resolves: a path that is
-- extensionless, nil for a name the catalog does not carry, and the folder name going through to
-- the library. They prove NOTHING about the marks that actually reach the screen, because nothing
-- in this addon calls NS.Icon — every mark on the console, its Copy window and the perf panel is
-- built inside libs/LibKa0s from the folder name handed to the DebugLog descriptor and to
-- NS.MakeCloseButton. Those are covered by the descriptor spy in tests/test_debuglog.lua and the
-- MakeCloseButton spy in tests/test_coresetup.lua, and if NS.Icon were deleted tomorrow not one
-- pixel would move. See core/MediaSetup.lua's header for why it is published anyway.

test("MediaSetup: NS.Icon answers the vendored path, extensionless", function()
  -- Extensionless is not a preference. The collection's surviving note from a live client says a
  -- path carrying `.tga` is one of the two spellings that draws NOTHING; the client appends the
  -- extension itself, and the file on disk is still <name>.tga.
  -- red under: Media.Icon going back to the minor-1 spelling, or this addon concatenating one on.
  assertEqual(NS.Icon("close"), VENDORED .. "icons\\close")
end)

test("MediaSetup: an icon the library does not ship answers nil", function()
  -- nil is a value a caller can branch on. A plausible path to a texture that is not there is a
  -- control that is simply absent, forever, silently — which is the whole reason this seam exists.
  assertNil(NS.Icon("nosuchicon"))
  assertNil(NS.Icon("absorb-shield"))
end)

test("MediaSetup: NS.MediaFont answers the vendored face, and an unknown face answers nil", function()
  assertEqual(NS.MediaFont("JetBrains Mono"),
    VENDORED .. "fonts\\JetBrainsMono-Regular.ttf")
  assertNil(NS.MediaFont("Comic Sans"))
end)

test("MediaSetup: the font this addon names is the face the library registers", function()
  -- Two names for one thing, in two repos. C.FONT_MONO_NAME is the LSM key — what a profile could
  -- store and what the Font page's dropdown shows — and the library's FONTS is what actually gets
  -- registered. A key nobody registered renders silently in Blizzard's fallback face, which is the
  -- exact outcome shipping a monospace font was meant to prevent.
  local lib = media()
  local key = NS.Constants.FONT_MONO_NAME
  assertTrue(lib.FONTS[key] ~= nil,
    "FONT_MONO_NAME is '" .. tostring(key) .. "', which the library's FONTS does not carry")
  assertEqual(NS.Constants.FONT_MONO, NS.MediaFont(key),
    "FONT_MONO must be the path the seam resolves for FONT_MONO_NAME, not a second spelling of it")
end)

test("MediaSetup: FONT_MONO resolves into the payload, not into this addon's own media/", function()
  -- The migration's whole point, asserted as a path rather than as prose: media/fonts/ is gone from
  -- this repo, and a constant still naming it would be a path to a file that is not there — which
  -- SetFont accepts, fails to load, and then draws no text at all.
  -- red under: reverting C.FONT_MONO to the old literal.
  assertTrue(NS.Constants.FONT_MONO:find("libs\\LibKa0s\\media\\fonts\\", 1, true) ~= nil,
    "FONT_MONO must resolve through the seam to the vendored payload, got "
      .. tostring(NS.Constants.FONT_MONO))
  local stale = io.open("media/fonts/JetBrainsMono-Regular.ttf", "rb")
  if stale then stale:close() end
  assertNil(stale, "this addon no longer ships its own copy of the face; media/fonts/ must be gone")
end)

-- ── the catalog, against what this addon actually draws ────────────────────────────────────────

test("MediaSetup: every mark this addon's windows draw is one the library ships", function()
  -- This addon draws no chrome of its own — the three bars have no title bars, and the settings
  -- panel is LibKa0s-Options-1.0's — so the marks that reach the screen are the ones the DebugLog
  -- library builds on our behalf once core/DebugLogSetup.lua hands it `addonName`: the console's
  -- close, copy and clear, the Copy window's close, and the perf panel's close through
  -- NS.MakeCloseButton. Their names are strings inside another repo; a rename there answers nil here.
  local lib = media()
  local known = {}
  for _, name in ipairs(lib.ICONS) do known[name] = true end

  for _, name in ipairs({ "close", "copy", "clear" }) do
    assertTrue(known[name] == true,
      "this addon's windows draw '" .. name .. "', which LibKa0s-Media does not ship")
    assertTrue(NS.Icon(name) ~= nil, "NS.Icon answered nil for " .. name)
  end
end)

test("MediaSetup: every name the library ships has a file in the vendored copy", function()
  -- The library's own suite checks its catalog against its own directory. This checks THE COPY: a
  -- re-vendor that dropped a file, or a packaging step that filtered one out, leaves a catalog
  -- naming art this build does not carry — and the catalog is what every path is built from.
  local lib = media()
  local missing = {}
  for _, name in ipairs(lib.ICONS) do
    local fh = io.open("libs/LibKa0s/media/icons/" .. name .. ".tga", "rb")
    if fh then fh:close() else missing[#missing + 1] = name end
  end
  assertEqual(table.concat(missing, ", "), "",
    "the vendored payload is missing art its own catalog names")

  for name, entry in pairs(lib.FONTS) do
    local fh = io.open("libs/LibKa0s/media/fonts/" .. entry.file, "rb")
    if fh then fh:close() end
    assertTrue(fh ~= nil, "the vendored payload has no file for the face '" .. name .. "'")
  end
end)

test("MediaSetup: the seam is handed the FOLDER name, never a frame prefix or a literal", function()
  -- A wrong addon name builds a plausible path into nowhere, and nothing raises. Asserted by
  -- spying on the library rather than by reading the source, so a refactor that spells the call
  -- differently but passes the right string stays green.
  local lib = media()
  local realIcon, realFont = lib.Icon, lib.Font
  local seenIcon, seenFont
  lib.Icon = function(name) seenIcon = name; return nil end
  lib.Font = function(name) seenFont = name; return nil end
  NS.Icon("close")
  NS.MediaFont("JetBrains Mono")
  lib.Icon, lib.Font = realIcon, realFont

  assertEqual(seenIcon, "AbsorbTracker", "NS.Icon must pass this addon's folder name")
  assertEqual(seenFont, "AbsorbTracker", "NS.MediaFont must pass this addon's folder name")
end)

test("MediaSetup: the LSM registration happens at file load, not at OnInitialize", function()
  -- It used to sit in core/AbsorbTracker.lua's OnInitialize, which is late: LibSharedMedia is
  -- vendored under libs/ and has already run by the time the TOC reaches core/, while
  -- defaults/Profile.lua names faces at LOAD time. Deferring leaves a window in which a shipped
  -- default names a face LSM has never heard of.
  -- red under: moving Media.RegisterLSM into a handler, or leaving the hand-rolled Register behind.
  local f = io.open("core/MediaSetup.lua", "r")
  assertTrue(f ~= nil, "cannot open core/MediaSetup.lua (tests run from the repo root)")
  local src = f:read("*a")
  f:close()
  local body = src:gsub("%-%-[^\r\n]*", "")
  assertTrue(body:match("\nif Media then Media%.RegisterLSM%(addonName%) end") ~= nil,
    "RegisterLSM must be called at file scope, guarded on the library, with the folder name")

  local g = io.open("core/AbsorbTracker.lua", "r")
  local coreSrc = g and g:read("*a") or ""
  if g then g:close() end
  assertNil(coreSrc:gsub("%-%-[^\r\n]*", ""):find("LSM:Register", 1, true),
    "the hand-rolled LSM font registration must be gone — two registrations of one key against two "
      .. "paths is the collision LibKa0s-Media exists to end")
end)

-- ── degraded ───────────────────────────────────────────────────────────────────────────────────

test("MediaSetup: with no library there is no art, and that is not an error", function()
  -- The art and the face are INSIDE the payload that is missing, so a degraded install has neither.
  -- NS.Icon answering nil is what leaves the library's own controls on the multiplication sign and
  -- word labels they drew before the art existed; NS.MediaFont answering nil is what core/
  -- Constants.lua turns into the client's own font. Both are answers, not failures.
  local NS2 = loadDegraded()
  assertNil(NS2.Icon("close"))
  assertNil(NS2.MediaFont("JetBrains Mono"))

  -- THE TYPE ASSERTION COMES FIRST AND IS THE ONE THAT MATTERS. This case used to compare
  -- FONT_MONO against `_G.STANDARD_TEXT_FONT`, which nothing in tests/ or tests/_kit/ ever sets:
  -- both sides were nil and the case passed on nil == nil, so deleting the fallback rung from
  -- core/Constants.lua left the suite green while a nil font path went into `log:SetFont` on the
  -- one window that has to stay readable when everything else has failed.
  -- red under: deleting the `or C.FALLBACK_FONT` rung from core/Constants.lua.
  assertTrue(type(NS2.Constants.FONT_MONO) == "string",
    "a degraded install must land on a real client font, never on nil and never on a dead path")
  assertEqual(NS2.Constants.FONT_MONO, NS2.Constants.FALLBACK_FONT,
    "the last rung is the literal in core/Constants.lua, not a FrameXML global that may be unset "
      .. "at the moment that file loads")
  assertEqual(NS2.Constants.FALLBACK_FONT, "Fonts\\FRIZQT__.TTF",
    "and that literal must still name a face the client actually ships")
end)
