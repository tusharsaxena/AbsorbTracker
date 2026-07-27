local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- core/Data.lua — the AceDB read/write seam, the LibSharedMedia fetchers and the
-- class-colour-aware colour resolvers. LSM is absent headlessly (the addon treats it as a soft
-- optional), so the fallback branch is what runs by default; `withLSM` swaps a stub in through
-- the mock LibStub so the resolved branch is exercised too.

local C = NS.Constants

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
    withSetting("barTexture", "Blizzard Raid Bar", function()
      assertEqual(NS.GetBarTexture(), "path/to/bar")
    end)
    withSetting("bgTexture", "Blizzard Raid Bar", function()
      assertEqual(NS.GetBgTexture(), "path/to/bar")
    end)
    withSetting("border", "Blizzard Tooltip", function()
      assertEqual(NS.GetBorder(), "path/to/border")
    end)
    withSetting("font", "Friz Quadrata TT", function()
      assertEqual(NS.GetFont(), "path/to/font")
    end)
  end)
end)

test("media fetchers fall back when LSM is present but the key does not resolve", function()
  -- The user's saved media key can outlive the addon that supplied it (uninstall a media pack and
  -- LSM stops knowing the name). Fetch returns nil and the bar must still get a valid path.
  withLSM({ statusbar = {}, border = {}, font = {} }, function()
    withSetting("barTexture", "Some Uninstalled Pack", function()
      assertEqual(NS.GetBarTexture(), C.FALLBACK_TEXTURE)
    end)
    withSetting("border", "Some Uninstalled Pack", function()
      assertEqual(NS.GetBorder(), C.FALLBACK_BORDER)
    end)
    withSetting("font", "Some Uninstalled Pack", function()
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
  assertEqual(next(values()), nil, "empty while LSM is absent")
  withLSM({ statusbar = { Alpha = "a/path", Beta = "b/path" } }, function()
    local out = values()
    assertEqual(out.Alpha, "Alpha", "keys map to themselves for the dropdown")
    assertEqual(out.Beta,  "Beta")
    assertEqual(out["a/path"], nil, "paths are never surfaced as values")
  end)
end)

-- ── Colour resolvers ───────────────────────────────────────────────────────────────

test("GetBarColor returns the stored colour when useClassColorBar is off", function()
  withSetting("useClassColorBar", false, function()
    withSetting("barColor", { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, function()
      local r, g, b, a = NS.GetBarColor()
      approx(r, 0.1); approx(g, 0.2); approx(b, 0.3); approx(a, 0.4)
    end)
  end)
end)

test("GetBarColor substitutes the class colour but KEEPS the stored alpha", function()
  -- The class-colour toggles only override RGB; alpha stays user-controlled (the panel leaves the
  -- alpha slider live while the swatch is greyed out via `disabledIf`).
  withSetting("useClassColorBar", true, function()
    withSetting("barColor", { r = 0.1, g = 0.2, b = 0.3, a = 0.37 }, function()
      local r, g, b, a = NS.GetBarColor()
      local mock = T.mocks.C_ClassColor.GetClassColor("MAGE")
      approx(r, mock.r); approx(g, mock.g); approx(b, mock.b)
      approx(a, 0.37, "alpha is NOT overridden by the class colour")
    end)
  end)
end)

test("GetBorderColor honours useClassColorBorder and keeps its own alpha", function()
  withSetting("useClassColorBorder", true, function()
    withSetting("borderColor", { r = 0, g = 0, b = 0, a = 0.55 }, function()
      local r, g, b, a = NS.GetBorderColor()
      local mock = T.mocks.C_ClassColor.GetClassColor("MAGE")
      approx(r, mock.r); approx(g, mock.g); approx(b, mock.b)
      approx(a, 0.55)
    end)
  end)
end)

test("GetBorderColor returns the stored colour when the toggle is off", function()
  withSetting("useClassColorBorder", false, function()
    withSetting("borderColor", { r = 0.9, g = 0.8, b = 0.7, a = 0.6 }, function()
      local r, g, b, a = NS.GetBorderColor()
      approx(r, 0.9); approx(g, 0.8); approx(b, 0.7); approx(a, 0.6)
    end)
  end)
end)

test("GetBgColor uses the DIMMED class colour, not the raw one", function()
  -- The background palette is its own table scaled by 0.2 so a class-coloured backdrop reads as a
  -- dark tint behind the bar rather than a second bright fill. Player class is MAGE in the mock.
  withSetting("useClassColorBg", true, function()
    withSetting("bgColor", { r = 1, g = 1, b = 1, a = 0.8 }, function()
      local r, g, b, a = NS.GetBgColor()
      approx(r, 0.25 * 0.2); approx(g, 0.78 * 0.2); approx(b, 0.92 * 0.2)
      approx(a, 0.8, "alpha is preserved here too")
    end)
  end)
end)

test("GetBgColor returns the stored colour when the toggle is off", function()
  withSetting("useClassColorBg", false, function()
    withSetting("bgColor", { r = 0.2, g = 0.2, b = 0.2, a = 0.8 }, function()
      local r, g, b, a = NS.GetBgColor()
      approx(r, 0.2); approx(g, 0.2); approx(b, 0.2); approx(a, 0.8)
    end)
  end)
end)

test("the three class-colour toggles are independent of each other", function()
  withSetting("useClassColorBar", true, function()
    withSetting("useClassColorBg", false, function()
      withSetting("useClassColorBorder", false, function()
        withSetting("bgColor", { r = 0.11, g = 0.12, b = 0.13, a = 1 }, function()
          withSetting("borderColor", { r = 0.21, g = 0.22, b = 0.23, a = 1 }, function()
            local br = select(1, NS.GetBgColor())
            local dr = select(1, NS.GetBorderColor())
            approx(br, 0.11, "bar's toggle must not bleed into the background")
            approx(dr, 0.21, "bar's toggle must not bleed into the border")
          end)
        end)
      end)
    end)
  end)
end)
