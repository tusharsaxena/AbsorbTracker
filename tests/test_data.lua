local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- core/Data.lua — the AceDB read/write seam, the LibSharedMedia fetchers and the
-- class-color-aware color resolvers. LSM is absent headlessly (the addon treats it as a soft
-- optional), so the fallback branch is what runs by default; `withLSM` swaps a stub in through
-- the mock LibStub so the resolved branch is exercised too.

local C = NS.Constants

-- A SECOND, freshly-loaded addon environment. Used by exactly one case below, which needs
-- core/Data.lua's class-color cache to be empty -- see the note there.
local loadDegraded = dofile("tests/degraded_env.lua")

local function approx(got, want, msg)
  assertTrue(math.abs(got - want) < 1e-6,
    (msg or "approx") .. string.format(" (expected %s, got %s)", tostring(want), tostring(got)))
end

-- Run `body` with a LibSharedMedia-3.0 stub serving `media` ([mediaType][key] = path). Delegates
-- every other LibStub lookup to the real mock so Ace libs keep resolving, and clears NS's cached
-- LSM reference on both edges (the cache is why NS.ClearLSMCache exists).
local function withLSM(media, body)
  local savedLibStub = T.mocks.LibStub
  local lsm = {
    Fetch     = function(_, mtype, key) return (media[mtype] or {})[key] end,
    HashTable = function(_, mtype) return media[mtype] or {} end,
    Register  = function() return true end,
  }
  T.mocks.LibStub = setmetatable({}, {
    __call = function(_, name, silent)
      if name == "LibSharedMedia-3.0" then return lsm end
      return savedLibStub(name, silent)
    end,
  })
  NS.ClearLSMCache()
  local ok, err = pcall(body, lsm)
  T.mocks.LibStub = savedLibStub
  NS.ClearLSMCache()
  if not ok then error(err) end
end

-- Run `body` with a setting forced to `value`, then restore whatever was there.
local function withSetting(key, value, body)
  local saved = NS.GetSetting(key)
  NS.SetSetting(key, value)
  local ok, err = pcall(body)
  NS.SetSetting(key, saved)
  if not ok then error(err) end
end

-- ── GetSetting / SetSetting ────────────────────────────────────────────────────────

test("GetSetting reads the value out of the active profile", function()
  NS.db.profile.barWidth = 321
  assertEqual(NS.GetSetting("barWidth"), 321)
  NS.db.profile.barWidth = 200
end)

test("GetSetting falls back to flatDefaults when the key is missing from the profile", function()
  local saved = NS.db.profile.barHeight
  NS.db.profile.barHeight = nil
  assertEqual(NS.GetSetting("barHeight"), NS.flatDefaults.barHeight)
  NS.db.profile.barHeight = saved
end)

test("GetSetting falls back to flatDefaults when the DB is absent entirely", function()
  local savedDB = NS.db
  NS.db = nil
  local ok, err = pcall(function()
    assertEqual(NS.GetSetting("barWidth"), NS.flatDefaults.barWidth)
    assertEqual(NS.GetSetting("fontFlags"), NS.flatDefaults.fontFlags)
  end)
  NS.db = savedDB
  if not ok then error(err) end
end)

test("GetSetting returns nil for a key that is neither in the profile nor the defaults", function()
  assertEqual(NS.GetSetting("noSuchSettingAnywhere"), nil)
end)

test("GetSetting returns a stored `false` rather than falling through to the default", function()
  -- Regression guard on the `val == nil` test in GetSetting: a plain truthiness check here would
  -- treat a user's explicit `false` as "unset" and hand back the default instead.
  local saved = NS.db.profile.hidden
  NS.db.profile.hidden = false
  assertFalse(NS.GetSetting("hidden"), "an explicitly stored false must survive the read")
  NS.db.profile.hidden = saved
end)

test("SetSetting writes through to the active profile", function()
  NS.SetSetting("barWidth", 275)
  assertEqual(NS.db.profile.barWidth, 275)
  NS.SetSetting("barWidth", 200)
end)

test("SetSetting is a harmless no-op when the DB is absent", function()
  local savedDB = NS.db
  NS.db = nil
  local ok = pcall(NS.SetSetting, "barWidth", 999)
  NS.db = savedDB
  assertTrue(ok, "SetSetting must not raise without a DB")
  assertEqual(NS.GetSetting("barWidth"), 200, "and must not have written anywhere")
end)

-- ── LibSharedMedia fetchers ────────────────────────────────────────────────────────

test("media fetchers return the hardcoded fallbacks when LSM is absent", function()
  assertEqual(NS.GetBarTexture(), C.FALLBACK_TEXTURE)
  assertEqual(NS.GetBgTexture(),  C.FALLBACK_TEXTURE)
  assertEqual(NS.GetBorder(),     C.FALLBACK_BORDER)
  assertEqual(NS.GetFont(),       C.FALLBACK_FONT)
end)

test("media fetchers return the LSM path when LSM resolves the configured key", function()
  withLSM({
    statusbar = { ["Blizzard Raid Bar"] = "path/to/bar" },
    border    = { ["Blizzard Tooltip"]  = "path/to/border" },
    font      = { ["Friz Quadrata TT"]  = "path/to/font" },
  }, function()
    withSetting("units.player.barTexture", "Blizzard Raid Bar", function()
      assertEqual(NS.GetBarTexture(), "path/to/bar")
    end)
    withSetting("units.player.bgTexture", "Blizzard Raid Bar", function()
      assertEqual(NS.GetBgTexture(), "path/to/bar")
    end)
    withSetting("units.player.border", "Blizzard Tooltip", function()
      assertEqual(NS.GetBorder(), "path/to/border")
    end)
    withSetting("units.player.font", "Friz Quadrata TT", function()
      assertEqual(NS.GetFont(), "path/to/font")
    end)
  end)
end)

test("media fetchers fall back when LSM is present but the key does not resolve", function()
  -- The user's saved media key can outlive the addon that supplied it (uninstall a media pack and
  -- LSM stops knowing the name). Fetch returns nil and the bar must still get a valid path.
  withLSM({ statusbar = {}, border = {}, font = {} }, function()
    withSetting("units.player.barTexture", "Some Uninstalled Pack", function()
      assertEqual(NS.GetBarTexture(), C.FALLBACK_TEXTURE)
    end)
    withSetting("units.player.border", "Some Uninstalled Pack", function()
      assertEqual(NS.GetBorder(), C.FALLBACK_BORDER)
    end)
    withSetting("units.player.font", "Some Uninstalled Pack", function()
      assertEqual(NS.GetFont(), C.FALLBACK_FONT)
    end)
  end)
end)

test("ClearLSMCache lets a late-loading LSM be picked up", function()
  -- OnEnable calls ClearLSMCache for exactly this reason: GetLSM caches its lookup, and a first
  -- call made before LibSharedMedia loaded would otherwise pin nil for the session.
  assertEqual(NS.GetLSM(), nil, "no LSM headlessly to begin with")
  withLSM({ statusbar = { Late = "late/path" } }, function(lsm)
    assertEqual(NS.GetLSM(), lsm, "after ClearLSMCache the late lib resolves")
  end)
  assertEqual(NS.GetLSM(), nil, "and clearing again drops back to absent")
end)

test("LSMValues yields a self-keyed map of the live LSM hash table", function()
  local values = NS.Helpers.LSMValues("statusbar")
  assertEqual(type(values), "function", "LSMValues returns a deferred closure, not a table")
  -- A single `None` placeholder while LSM is absent, not an empty table. Empty made the row
  -- unusable rather than merely unpopulated: the dropdown cannot be opened, and the CLI's
  -- allowed-values check refuses every value including the one already stored. Changed in
  -- OptionsWidgets/Options minor 4.
  assertEqual(values().None, "None", "a placeholder while LSM is absent")
  withLSM({ statusbar = { Alpha = "a/path", Beta = "b/path" } }, function()
    local out = values()
    assertEqual(out.Alpha, "Alpha", "keys map to themselves for the dropdown")
    assertEqual(out.Beta,  "Beta")
    assertEqual(out["a/path"], nil, "paths are never surfaced as values")
  end)
end)

-- ── Color resolvers ───────────────────────────────────────────────────────────────

test("GetBarColor returns the stored color when useClassColorBar is off", function()
  withSetting("units.player.useClassColorBar", false, function()
    withSetting("units.player.barColor", { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, function()
      local r, g, b, a = NS.GetBarColor()
      approx(r, 0.1); approx(g, 0.2); approx(b, 0.3); approx(a, 0.4)
    end)
  end)
end)

test("GetBarColor substitutes the class color but KEEPS the stored alpha", function()
  -- The class-color toggles only override RGB; alpha stays user-controlled (the panel leaves the
  -- alpha slider live while the swatch is grayed out via `disabledIf`).
  withSetting("units.player.useClassColorBar", true, function()
    withSetting("units.player.barColor", { r = 0.1, g = 0.2, b = 0.3, a = 0.37 }, function()
      local r, g, b, a = NS.GetBarColor()
      local mock = T.mocks.C_ClassColor.GetClassColor("MAGE")
      approx(r, mock.r); approx(g, mock.g); approx(b, mock.b)
      approx(a, 0.37, "alpha is NOT overridden by the class color")
    end)
  end)
end)

test("GetBorderColor honors useClassColorBorder and keeps its own alpha", function()
  withSetting("units.player.useClassColorBorder", true, function()
    withSetting("units.player.borderColor", { r = 0, g = 0, b = 0, a = 0.55 }, function()
      local r, g, b, a = NS.GetBorderColor()
      local mock = T.mocks.C_ClassColor.GetClassColor("MAGE")
      approx(r, mock.r); approx(g, mock.g); approx(b, mock.b)
      approx(a, 0.55)
    end)
  end)
end)

test("GetBorderColor returns the stored color when the toggle is off", function()
  withSetting("units.player.useClassColorBorder", false, function()
    withSetting("units.player.borderColor", { r = 0.9, g = 0.8, b = 0.7, a = 0.6 }, function()
      local r, g, b, a = NS.GetBorderColor()
      approx(r, 0.9); approx(g, 0.8); approx(b, 0.7); approx(a, 0.6)
    end)
  end)
end)

test("GetBgColor uses the DIMMED class color, not the raw one", function()
  -- The background palette is its own table scaled by 0.2 so a class-colored backdrop reads as a
  -- dark tint behind the bar rather than a second bright fill. Player class is MAGE in the mock.
  withSetting("units.player.useClassColorBg", true, function()
    withSetting("units.player.bgColor", { r = 1, g = 1, b = 1, a = 0.8 }, function()
      local r, g, b, a = NS.GetBgColor()
      approx(r, 0.25 * 0.2); approx(g, 0.78 * 0.2); approx(b, 0.92 * 0.2)
      approx(a, 0.8, "alpha is preserved here too")
    end)
  end)
end)

test("GetBgColor returns the stored color when the toggle is off", function()
  withSetting("units.player.useClassColorBg", false, function()
    withSetting("units.player.bgColor", { r = 0.2, g = 0.2, b = 0.2, a = 0.8 }, function()
      local r, g, b, a = NS.GetBgColor()
      approx(r, 0.2); approx(g, 0.2); approx(b, 0.2); approx(a, 0.8)
    end)
  end)
end)

test("GetFontColor honors useClassColorText and keeps its own alpha", function()
  withSetting("units.player.useClassColorText", true, function()
    withSetting("units.player.fontColor", { r = 0.1, g = 0.2, b = 0.3, a = 0.42 }, function()
      local r, g, b, a = NS.GetFontColor()
      local mock = T.mocks.C_ClassColor.GetClassColor("MAGE")
      approx(r, mock.r); approx(g, mock.g); approx(b, mock.b)
      approx(a, 0.42, "alpha is NOT overridden by the class color")
    end)
  end)
  withSetting("units.player.useClassColorText", false, function()
    withSetting("units.player.fontColor", { r = 0.7, g = 0.6, b = 0.5, a = 0.4 }, function()
      local r, g, b, a = NS.GetFontColor()
      approx(r, 0.7); approx(g, 0.6); approx(b, 0.5); approx(a, 0.4)
    end)
  end)
end)

test("an unknown class keeps the CONFIGURED color, never a hue invented for the occasion",
  function()
  -- The reversal. All four getters used to substitute opaque white when the class could not be
  -- named -- a color the player never chose and could not have predicted, over the one they did.
  --
  -- Run in a FRESH environment rather than by stubbing the global here, and that is the case, not
  -- a convenience: core/Data.lua caches the class color, the cache fills only on SUCCESS, and this
  -- suite's own earlier cases have already filled it. Stubbing C_ClassColor in place would
  -- therefore never reach the miss path and the test would pass without executing the branch it
  -- names. A second load gets an empty cache; the class lookup is stubbed out before the first read
  -- reaches it. (That the cache only fills on success is the other half of the fix: a client that
  -- can name the class a moment later is still picked up.)
  -- The stub goes on that environment's OWN globals table (the loader runs each file against it),
  -- not on _G: a file loaded there never reads this process's globals.
  local NS2, mocks2 = loadDegraded()
  mocks2.UnitClass    = function() return nil, nil end
  mocks2.C_ClassColor = { GetClassColor = function() return nil end }

  local unit = NS2.defaults.profile.units.player
  unit.useClassColorBar = true
  unit.barColor = { r = 0.31, g = 0.32, b = 0.33, a = 0.6 }

  local r, g, b, a = NS2.GetBarColor("player")
  approx(r, 0.31); approx(g, 0.32); approx(b, 0.33)
  approx(a, 0.6, "and the alpha is still the swatch's")

  -- And the same for the background, whose class color comes from a different table.
  unit.useClassColorBg = true
  unit.bgColor = { r = 0.41, g = 0.42, b = 0.43, a = 0.7 }
  local br, bg2, bb, ba = NS2.GetBgColor("player")
  approx(br, 0.41); approx(bg2, 0.42); approx(bb, 0.43); approx(ba, 0.7)
end)

test("GetBarAlpha clamps a hand-edited SavedVariable to the slider's own range", function()
  -- The value comes out of SavedVariables, so the schema's min/max never sees it. An alpha of 0 is
  -- an invisible bar with no error and no way to tell it from the addon having stopped working.
  local saved = NS.db.profile.units.player.barAlpha
  local cases = { { 0, 0.1 }, { -5, 0.1 }, { 2, 1 }, { 0.5, 0.5 } }
  for _, c in ipairs(cases) do
    NS.db.profile.units.player.barAlpha = c[1]
    approx(NS.GetBarAlpha("player"), c[2], "stored " .. tostring(c[1]))
  end
  NS.db.profile.units.player.barAlpha = "not a number"
  approx(NS.GetBarAlpha("player"), NS.unitDefaults.barAlpha, "a non-number reads as the default")
  NS.db.profile.units.player.barAlpha = saved
end)

test("the four class-color toggles are independent of each other", function()
  withSetting("units.player.useClassColorBar", true, function()
    withSetting("units.player.useClassColorBg", false, function()
      withSetting("units.player.useClassColorBorder", false, function()
        withSetting("units.player.bgColor", { r = 0.11, g = 0.12, b = 0.13, a = 1 }, function()
          withSetting("units.player.borderColor", { r = 0.21, g = 0.22, b = 0.23, a = 1 }, function()
            local br = select(1, NS.GetBgColor())
            local dr = select(1, NS.GetBorderColor())
            local tr = select(1, NS.GetFontColor())
            approx(br, 0.11, "bar's toggle must not bleed into the background")
            approx(dr, 0.21, "bar's toggle must not bleed into the border")
            approx(tr, 1.0, "nor into the text, which is white by default")
          end)
        end)
      end)
    end)
  end)
end)

-- ── Multi-unit media/color getters ────────────────────────────────────────────────

test("media getters read through the unit's mirror resolution", function()
  local saved = NS.db.profile.units.target.mirror
  NS.db.profile.units.target.mirror = false
  NS.db.profile.units.target.barTexture = "Blizzard Raid Bar"
  NS.db.profile.units.target.mirror = saved
  -- With no LSM headless, every fetcher falls back to the constant. The point of this test is
  -- that passing a unit does not raise and does not read the player's key by accident.
  assertEqual(NS.GetBarTexture("target"), NS.Constants.FALLBACK_TEXTURE)
  assertEqual(NS.GetBorder("focus"), NS.Constants.FALLBACK_BORDER)
  assertEqual(NS.GetFont("target"), NS.Constants.FALLBACK_FONT)
end)

test("a media getter with no unit still resolves the player", function()
  assertEqual(NS.GetBarTexture(), NS.GetBarTexture("player"))
end)

test("with LSM present, the media getter resolves the REQUESTED unit's own key, not the player's",
  function()
    -- The fallback-constant tests above would pass even if every unit silently read the
    -- player's setting (LSM is absent headlessly, so every branch falls through to the same
    -- constant). Stub LSM in and give player/target genuinely different stored keys so this test
    -- can only pass if NS.GetBarTexture actually threads `unit` into NS.Units.Get.
    withLSM({ statusbar = { ["Player Texture"] = "PATH_PLAYER", ["Target Texture"] = "PATH_TARGET" } },
      function()
        local savedPlayer = NS.db.profile.units.player.barTexture
        local savedMirror = NS.db.profile.units.target.mirror
        local savedTarget = NS.db.profile.units.target.barTexture
        NS.db.profile.units.player.barTexture = "Player Texture"
        NS.db.profile.units.target.mirror = false
        NS.db.profile.units.target.barTexture = "Target Texture"

        assertEqual(NS.GetBarTexture("player"), "PATH_PLAYER")
        assertEqual(NS.GetBarTexture("target"), "PATH_TARGET")

        NS.db.profile.units.player.barTexture = savedPlayer
        NS.db.profile.units.target.barTexture = savedTarget
        NS.db.profile.units.target.mirror = savedMirror
      end)
  end)

test("GetBarColor reads the requested unit's color", function()
  local saved = NS.db.profile.units.target.mirror
  NS.db.profile.units.target.mirror = false
  NS.db.profile.units.target.barColor = { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }
  NS.db.profile.units.target.useClassColorBar = false
  local r, g, b, a = NS.GetBarColor("target")
  NS.db.profile.units.target.mirror = saved
  assertEqual(r, 0.1); assertEqual(g, 0.2); assertEqual(b, 0.3); assertEqual(a, 0.4)
end)

test("class color on a target bar is still the PLAYER's class color", function()
  -- Spec decision: resolving the tracked unit's class would need a PLAYER_TARGET_CHANGED recolor
  -- for a cosmetic gain. All three bars use your own class color.
  -- Note: the brief's test compares straight to NS.GetBarColor("player"), which only reflects the
  -- class color when the PLAYER row's own toggle is also on — its default is false. Flip it here
  -- too so both sides genuinely take the class-color branch; otherwise the assertion would
  -- compare a resolved class color against an unrelated stored RGB and fail for the wrong reason.
  local savedMirror = NS.db.profile.units.target.mirror
  local savedPlayerToggle = NS.db.profile.units.player.useClassColorBar
  NS.db.profile.units.target.mirror = false
  NS.db.profile.units.target.useClassColorBar = true
  NS.db.profile.units.player.useClassColorBar = true
  local r, g, b = NS.GetBarColor("target")
  local pr, pg, pb = NS.GetBarColor("player")
  NS.db.profile.units.target.useClassColorBar = false
  NS.db.profile.units.player.useClassColorBar = savedPlayerToggle
  NS.db.profile.units.target.mirror = savedMirror
  assertEqual(r, pr); assertEqual(g, pg); assertEqual(b, pb)
end)

test("three bar frames exist and the player alias points at the player frame", function()
  assertTrue(NS.bars.player ~= nil)
  assertTrue(NS.bars.target ~= nil)
  assertTrue(NS.bars.focus ~= nil)
  assertEqual(NS.bar, NS.bars.player)
  assertEqual(NS.statusBar, NS.bars.player.statusBar)
  assertEqual(NS.valueText, NS.bars.player.valueText)
end)

test("each bar carries its own unit tag and its own backdrop table", function()
  assertEqual(NS.bars.target.unit, "target")
  assertTrue(NS.bars.target.backdropInfo ~= NS.bars.player.backdropInfo,
    "a shared backdrop table cannot hold three different border sizes")
end)
