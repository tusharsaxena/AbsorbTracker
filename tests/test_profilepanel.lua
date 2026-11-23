local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The Appearance page's Unit picker across every AceDB profile event (ATF-01, owner report
-- 2026-11-23: "The unit selector disappears some times - this is immediately after setting up a
-- new profiel"). New, copy, reset and delete, with the page on screen and with it hidden and shown
-- again, on Player and on an unlinked Target.
--
-- UNDER A POOLED AceGUI, and that is the point of the file. The kit's fake never reuses a widget,
-- so a page that drew a widget AceGUI had already taken back would pass against it; AceGUI-3.0
-- hands a released widget to the very next Create of its type. `pooled` below models that for the
-- length of one case: Release parks the widget, Create hands the last one parked back out.
--
-- These cases do NOT reproduce the owner's report: every one passed before the batch that added
-- them (docs/superpowers/specs/2026-11-23-absorbtracker-feedback-design.md, ATF-01). They pin the
-- three suspects that were ruled out (a render mid-release, a render without the unit, a widget
-- hidden for good) so none can arrive later unseen. The diagnostics report's [UI] unit picker line
-- (tests/test_diagnostics.lua) is what records the in-client state when it happens.

local function panel() return T.mocks.__subcategories["Appearance"] end

local function pooled(fn)
  local A = T.mocks.LibStub("AceGUI-3.0")
  local create, release = A.Create, A.Release
  local free, doubled = {}, {}
  A.Create = function(self, wtype)
    local list = free[wtype]
    if list and #list > 0 then
      local w = table.remove(list)
      w.__released = nil
      return w
    end
    return create(self, wtype)
  end
  A.Release = function(self, w)
    if w.__released then doubled[#doubled + 1] = w.type end
    release(self, w)
    free[w.type] = free[w.type] or {}
    table.insert(free[w.type], w)
  end
  local ok, err = pcall(fn, doubled)
  A.Create, A.Release = create, release
  if not ok then error(err, 0) end
end

--- Assert the page's chrome block holds one live, shown Unit picker showing `ctx.unit`.
local function assertPicker(ctx, when)
  local pickers, released = {}, {}
  for _, w in ipairs(ctx.__chromeWidgets or {}) do
    if w.type == "Dropdown" then pickers[#pickers + 1] = w end
    if w.__released then released[#released + 1] = w.type end
  end
  assertEqual(#pickers, 1, when .. ": one Unit picker in the chrome block")
  assertEqual(#released, 0, when .. ": no chrome widget is back in the pool")
  local dd = pickers[1]
  assertEqual(dd, ctx.__bannerWidget, when .. ": the picker is the page's")
  assertEqual(dd.labelText, "Unit", when .. ": labeled Unit")
  assertTrue(dd.frame:IsShown(), when .. ": shown")
  assertEqual(dd.value, ctx.unit, when .. ": showing the picked unit")
  for _, unit in ipairs(NS.Units.LIST) do
    assertEqual(dd.list and dd.list[unit], NS.Units.LABEL[unit], when .. ": lists " .. unit)
  end
  assertTrue(NS.UnitPickerState().live, when .. ": still marked as the page's")
end

local scratch = { "ATFNewShown", "ATFNewHidden", "ATFSlashNew", "ATFDelete" }

-- The Default profile's target link as the case found it, put back by `cleanup`.
local savedMirror

local function cleanup(ctx)
  if NS.db:GetCurrentProfile() ~= "Default" then NS.db:SetProfile("Default") end
  for _, name in ipairs(scratch) do
    if NS.db.sv.profiles[name] then NS.db:DeleteProfile(name, true) end
  end
  NS.HideSkinPicker()
  ctx.unit = "player"
  NS.db.profile.units.target.mirror = savedMirror
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  panel():Hide()
end

local function open(unit)
  local p = panel()
  p:Show(); p:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  ctx.unit = unit
  savedMirror = NS.db.profile.units.target.mirror
  if unit ~= "player" then NS.db.profile.units[unit].mirror = false end
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  return ctx
end

-- Hide the page, run `event`, show it again: the dirty page's next OnShow draws it.
local function hiddenThen(event)
  local p = panel()
  p:Hide()
  event()
  p:Show(); p:__fire("OnShow")
end

for _, unit in ipairs({ "player", "target" }) do
  test("profile events: the Unit picker survives a new, copied and reset profile on " .. unit, function()
    pooled(function(doubled)
      local ctx = open(unit)
      assertPicker(ctx, "opened")
      NS.db:SetProfile("ATFNewShown")
      assertPicker(ctx, "new profile, page shown")
      hiddenThen(function() NS.db:SetProfile("ATFNewHidden") end)
      assertPicker(ctx, "new profile, page hidden then shown")
      NS.db:CopyProfile("Default")
      assertPicker(ctx, "copy, page shown")
      hiddenThen(function() NS.db:CopyProfile("ATFNewShown") end)
      assertPicker(ctx, "copy, page hidden then shown")
      NS.db:ResetProfile()
      assertPicker(ctx, "reset, page shown")
      hiddenThen(function() NS.db:ResetProfile() end)
      assertPicker(ctx, "reset, page hidden then shown")
      NS.Slash:OnSlash("profile new ATFSlashNew")
      assertPicker(ctx, "/at profile new, page shown")
      assertEqual(#doubled, 0, "no widget released twice: " .. table.concat(doubled, ", "))
      cleanup(ctx)
    end)
  end)
end

test("profile events: deleting another profile leaves the Unit picker as it was", function()
  pooled(function()
    local ctx = open("player")
    NS.db:SetProfile("ATFDelete")
    NS.db:SetProfile("Default")
    assertPicker(ctx, "back on Default")
    NS.db:DeleteProfile("ATFDelete")
    assertPicker(ctx, "delete, page shown")
    hiddenThen(function() end)
    assertPicker(ctx, "delete, page hidden then shown")
    cleanup(ctx)
  end)
end)

test("profile events: the picked unit survives a profile switch", function()
  -- The second suspect: a re-render that runs without the unit context.
  pooled(function()
    local ctx = open("target")
    hiddenThen(function() NS.db:SetProfile("ATFNewHidden") end)
    assertEqual(ctx.unit, "target", "the page still edits the target")
    assertPicker(ctx, "after the switch")
    cleanup(ctx)
  end)
end)

test("profile events: the page draws one render per event, never a nested one", function()
  -- The first suspect: a render reached while another is still releasing its widgets.
  pooled(function()
    local ctx = open("player")
    local H, orig = NS.Helpers, NS.Helpers.RenderUnitPanel
    local renders, nested = 0, 0
    H.RenderUnitPanel = function(c, key)
      if c.__rendering then nested = nested + 1 else renders = renders + 1 end
      return orig(c, key)
    end
    local ok, err = pcall(NS.db.SetProfile, NS.db, "ATFNewShown")
    H.RenderUnitPanel = orig
    if not ok then error(err, 0) end
    assertEqual(nested, 0, "no render reached inside another")
    assertTrue(renders >= 1, "the shown page was redrawn")
    assertFalse(ctx.__rendering, "the guard is down after the event")
    cleanup(ctx)
  end)
end)
