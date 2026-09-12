-- Ka0s Absorb Tracker's WoW-API mock: the shared base (tests/_kit/mock_base.lua) plus the handful
-- of APIs that are genuinely this addon's own.
--
-- Returns a builder so each run gets a fresh, isolated environment. Everything universal — frames,
-- timers, the Settings canvas API, LibStub, the four Ace fakes, the capture-context lookups — lives
-- in the kit and is documented there, including its fidelity rules. Only absorb-shaped APIs belong
-- here: a base that stubbed every addon's APIs for everyone would hide a missing stub behind a
-- neighbor's.

local base = dofile("tests/_kit/mock_base.lua")

return function()
  local M = base()

  -- AceGUI:Release is the kit's (kit revision 16, LibKa0s v1.30.0): settings/UnitPanel.lua's
  -- chrome block releases its widgets, and tests/test_helpers.lua reads the kit's `w.__released`.

  -- Absorb and health, the two values this addon exists to read. Unit-taking so a test can vary
  -- target/focus independently of the player.
  M.__absorbs = {}
  M.UnitGetTotalAbsorbs = function(unit) return M.__absorbs[unit] or 0 end
  M.__maxHealth = {}
  M.UnitHealthMax = function(unit) return M.__maxHealth[unit] or 100 end

  -- Bar text formatting.
  M.AbbreviateNumbers = function(n) return tostring(n) end

  -- The class-color table, and it is RAID_CLASS_COLORS rather than the C_ClassColor stub that used
  -- to sit here. That is not a preference: LibKa0s-Core-1.0's ClassColor reads RAID_CLASS_COLORS --
  -- the table every other unit frame on the player's screen is already reading -- and this addon's
  -- private C_ClassColor resolver is gone with the adoption. A mock that kept answering the old
  -- source would leave every class-color case green against a function nothing calls.
  --
  -- Three entries, not thirteen: the suite needs the player's class (MAGE, the shared base's
  -- capture-context default) plus two others, to tell "the tracked unit's class" from "the player's".
  M.RAID_CLASS_COLORS = {
    MAGE    = { r = 0.25, g = 0.78, b = 0.92 },
    PRIEST  = { r = 1.00, g = 1.00, b = 1.00 },
    WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
  }

  -- UnitClass, made UNIT-AWARE. The shared kit's answers the capture context's class for every
  -- token, which was fine while every class color in this addon resolved to the player -- and is
  -- exactly wrong now that a target bar takes the TARGET's class (options-ui-§17). A case that
  -- could not give the target a different class from the player could not fail if the scoping
  -- regressed.
  --
  -- Overrides are TOKENS, and the localized name is answered as the token: nothing in this addon
  -- reads that name, and inventing a second string per class would be two things to keep in step.
  M.__classByUnit = {}
  M.UnitClass = function(unit)
    local token = M.__classByUnit[unit or "player"]
    if token then return token, token end
    return M.__context.class, M.__context.classToken
  end

  return M
end
