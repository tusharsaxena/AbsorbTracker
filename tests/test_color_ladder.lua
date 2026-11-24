-- tests/test_color_ladder.lua — the color ladder and the preview stand-in (FB-AT-01).
--
-- The owner, 2026-11-24 (Ka0sAddonsCommonTasks docs/2026-11-24-FEEDBACK_BATCH): "Do the same
-- validation for any element (text, bar, etc) where class color/skin color can be applied. This
-- may be systematically broken." For this addon it was: core/Data.lua skipped the skin whenever a
-- class toggle was on, so a target or focus bar whose class did not resolve (no target, an NPC,
-- the unlocked preview) drew the stored swatch instead of the skin. options-ui-§17 (v2.119.0) sets
-- the order: a class color that resolves, else the skin's color while its companion is on, else
-- the swatch; and a preview shows a class, the player's, while the unit it describes is absent.
--
-- After test_skin_flip; every case leaves the skin on Ka0s Default and the bars as it found them.

local T = _G.AT_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local Skin = mocks.LibStub("LibKa0s-Skin-1.0")
local OWNER = "AbsorbTracker"
local S = NS.Skin

local function rgba(...) return table.concat({ ... }, ",") end

local function withValue(tbl, key, value, body)
  local saved = tbl[key]
  tbl[key] = value
  local ok, err = pcall(body)
  tbl[key] = saved
  if not ok then error(err, 0) end
end

local function withUnit(unit, key, value, body)
  withValue(NS.db.profile.units[unit], key, value, body)
end

--- `body` on Obsidian with the bars locked (`locked`) or unlocked, and the target absent: no unit,
--- and so no class, exactly as the client answers `UnitClass("target")` with nothing targeted.
local function absentTarget(locked, body)
  return function()
    Skin:SetChoice(OWNER, "ka0s", "obsidian")
    local savedUnitClass = mocks.UnitClass
    local live = savedUnitClass
    mocks.UnitClass = function(unit)
      if unit ~= nil and unit ~= "player" and not mocks.__unitExists[unit] then return nil end
      return live(unit)
    end
    local ok, err = pcall(function()
      withValue(mocks.__unitExists, "target", false, function()
        withUnit("target", "mirror", false, function()
          withValue(NS.db.profile, "locked", locked, body)
        end)
      end)
    end)
    mocks.UnitClass = savedUnitClass
    Skin:SetChoice(OWNER, "ka0s", "ka0s")
    if not ok then error(err, 0) end
  end
end

local MAGE = mocks.RAID_CLASS_COLORS.MAGE

-- One row per surface: the getter, its class toggle, its companion, and the skin's own answer.
local SURFACES = {
  { "fill",   NS.GetBarColor,    "useClassColorBar",    "barColorFromSkin",    function() return S.Color("at.barFill") end },
  { "border", NS.GetBorderColor, "useClassColorBorder", "borderColorFromSkin", function() return S.Color("at.barBorder") end },
  { "text",   NS.GetFontColor,   "useClassColorText",   "fontColorFromSkin",   function() return S.HudTextColor() end },
}

local function first3(r, g, b) return rgba(r, g, b) end

-- red before FB-AT-01: skinColor answered nil whenever the class toggle was on, so the swatch drew.
test("an unresolved class falls to the skin while its companion is on (locked, no target)",
  absentTarget(true, function()
    for _, s in ipairs(SURFACES) do
      withUnit("target", s[3], true, function()
        withUnit("target", s[4], true, function()
          withUnit("target", s[1] == "text" and "fontColor" or (s[1] == "fill" and "barColor" or "borderColor"),
            { r = 0.11, g = 0.22, b = 0.33, a = 0.44 }, function()
              assertEqual(first3(s[2]("target")), first3(s[5]()), s[1] .. " draws the skin, not the swatch")
            end)
        end)
      end)
    end
    withUnit("target", "useClassColorBg", true, function()
      withUnit("target", "bgColorFromSkin", true, function()
        assertEqual(first3(NS.GetBgColor("target")), first3(S.Color("at.barBg")), "background draws the skin")
      end)
    end)
  end))

test("an unresolved class with its companion off still draws the stored swatch",
  absentTarget(true, function()
    withUnit("target", "useClassColorBar", true, function()
      withUnit("target", "barColorFromSkin", false, function()
        withUnit("target", "barColor", { r = 0.11, g = 0.22, b = 0.33, a = 0.44 }, function()
          assertEqual(rgba(NS.GetBarColor("target")), rgba(0.11, 0.22, 0.33, 0.44))
        end)
      end)
    end)
  end))

-- red before FB-AT-01: the unlocked target bar is the preview, and it drew the gold swatch or the
-- skin; the owner expects the player's class ("on my hunter I expect it to be green").
test("the unlocked preview shows the player's class on a target bar with no target",
  absentTarget(false, function()
    for _, s in ipairs(SURFACES) do
      withUnit("target", s[3], true, function()
        withUnit("target", s[4], true, function()
          assertEqual(first3(s[2]("target")), first3(MAGE.r, MAGE.g, MAGE.b), s[1] .. " is the player's class")
        end)
      end)
    end
    withUnit("target", "useClassColorBg", true, function()
      local r, g, b = NS.GetBgColor("target")
      local pr, pg, pb = NS.GetBgColor("player")
      withUnit("player", "useClassColorBg", true, function()
        pr, pg, pb = NS.GetBgColor("player")
      end)
      assertEqual(first3(r, g, b), first3(pr, pg, pb), "the background takes the player's dimmed class")
    end)
  end))

test("the sim is a preview too: it shows the player's class while the target is absent",
  absentTarget(true, function()
    local saved = NS.IsSimOn
    NS.IsSimOn = function() return true end
    local ok, err = pcall(function()
      withUnit("target", "useClassColorBar", true, function()
        assertEqual(first3(NS.GetBarColor("target")), first3(MAGE.r, MAGE.g, MAGE.b))
      end)
    end)
    NS.IsSimOn = saved
    if not ok then error(err, 0) end
  end))

test("a target that exists is never replaced by the stand-in", absentTarget(false, function()
  withValue(mocks.__unitExists, "target", true, function()
    withValue(mocks.__classByUnit, "target", "WARRIOR", function()
      withUnit("target", "useClassColorBar", true, function()
        local w = mocks.RAID_CLASS_COLORS.WARRIOR
        assertEqual(first3(NS.GetBarColor("target")), first3(w.r, w.g, w.b))
      end)
    end)
  end)
end))

test("a class that resolves wins over the skin, alpha kept from the swatch", absentTarget(true, function()
  withUnit("player", "useClassColorBar", true, function()
    withUnit("player", "barColorFromSkin", true, function()
      withUnit("player", "barColor", { r = 0.1, g = 0.1, b = 0.1, a = 0.37 }, function()
        assertEqual(rgba(NS.GetBarColor("player")), rgba(MAGE.r, MAGE.g, MAGE.b, 0.37))
      end)
    end)
  end)
end))

-- A target or focus swap repaints that bar's colors, so a class resolved for the last occupant
-- (or for nobody) does not stay on screen.
test("a target swap recolors the target bar", function()
  local bar = NS.bars and NS.bars.target
  assertTrue(bar ~= nil, "the target bar exists")
  local calls = 0
  local fill = bar.statusBar
  local real = fill.SetStatusBarColor
  fill.SetStatusBarColor = function(self, ...) calls = calls + 1; return real(self, ...) end
  local ok, err = pcall(function() NS.addon:OnUnitSwap("PLAYER_TARGET_CHANGED") end)
  fill.SetStatusBarColor = real
  if not ok then error(err, 0) end
  assertTrue(calls >= 1, "the fill color was set again on the swap")
end)
