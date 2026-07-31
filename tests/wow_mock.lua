-- Ka0s Absorb Tracker's WoW-API mock: the shared base (tests/_kit/mock_base.lua) plus the handful
-- of APIs that are genuinely this addon's own.
--
-- Returns a builder so each run gets a fresh, isolated environment. Everything universal — frames,
-- timers, the Settings canvas API, LibStub, the four Ace fakes, the capture-context lookups — lives
-- in the kit and is documented there, including its fidelity rules. Only absorb-shaped APIs belong
-- here: a base that stubbed every addon's APIs for everyone would hide a missing stub behind a
-- neighbour's.

local base = dofile("tests/_kit/mock_base.lua")

return function()
  local M = base()

  -- Absorb and health, the two values this addon exists to read. Unit-taking so a test can vary
  -- target/focus independently of the player.
  M.__absorbs = {}
  M.UnitGetTotalAbsorbs = function(unit) return M.__absorbs[unit] or 0 end
  M.__maxHealth = {}
  M.UnitHealthMax = function(unit) return M.__maxHealth[unit] or 100 end

  -- Bar text formatting and the class-colored bar option.
  M.AbbreviateNumbers = function(n) return tostring(n) end
  M.C_ClassColor = { GetClassColor = function() return { r = 1, g = 1, b = 1 } end }

  return M
end
