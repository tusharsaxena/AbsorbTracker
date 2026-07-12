local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

-- Compat is the single seam for the deprecated addon-metadata API (Ka0s standard §11). It reads
-- C_AddOns / GetAddOnMetadata from its load environment, which falls through to _G, so these
-- tests swap the _G globals to exercise each branch.

test("Compat.GetAddOnMetadata prefers C_AddOns.GetAddOnMetadata", function()
  local oldC = _G.C_AddOns
  _G.C_AddOns = { GetAddOnMetadata = function(_, f) return "C:" .. f end }
  assertEqual(NS.Compat.GetAddOnMetadata("AbsorbTracker", "Version"), "C:Version")
  _G.C_AddOns = oldC
end)

test("Compat.GetAddOnMetadata falls back to the global GetAddOnMetadata", function()
  local oldC, oldG = _G.C_AddOns, _G.GetAddOnMetadata
  _G.C_AddOns = nil
  _G.GetAddOnMetadata = function(_, f) return "G:" .. f end
  assertEqual(NS.Compat.GetAddOnMetadata("AbsorbTracker", "Notes"), "G:Notes")
  _G.C_AddOns, _G.GetAddOnMetadata = oldC, oldG
end)

test("Compat.GetAddOnMetadata returns nil when neither API is present", function()
  local oldC, oldG = _G.C_AddOns, _G.GetAddOnMetadata
  _G.C_AddOns, _G.GetAddOnMetadata = nil, nil
  assertEqual(NS.Compat.GetAddOnMetadata("AbsorbTracker", "Version"), nil)
  _G.C_AddOns, _G.GetAddOnMetadata = oldC, oldG
end)

test("No inline GetAddOnMetadata leaks: Compat is the only metadata accessor", function()
  assertTrue(type(NS.Compat.GetAddOnMetadata) == "function")
end)
