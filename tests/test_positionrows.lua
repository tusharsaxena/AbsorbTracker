local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue =
  T.test, T.assertEqual, T.assertTrue

-- Appearance > Bar > Position (ATF-03, owner 2026-11-23: "Add "psoition" settings in appearance >
-- bar just below size sub section - allows faine control of every bar").
--
-- The rows are H.PositionBlock's (OptionsCompose minor 15): X offset, Y offset and Reset position,
-- per unit, directly after Size. Each row keeps its path (`units.<unit>.position.x` / `.y`) and
-- reads and writes the bar's real position through its own get and set: the stored offset, or the
-- stacked default's while nothing is stored. A slider moves the bar live, a drag moves the slider,
-- and a reset puts the bar back in the stack.

local function panel() return T.mocks.__subcategories["Appearance"] end

--- Depth-first over the page's scroll: the first widget `pred` accepts.
local function find(ctx, pred)
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if pred(child) then return child end
      local hit = walk(child)
      if hit then return hit end
    end
  end
  return walk(ctx.scroll)
end

local function slider(ctx, label)
  return find(ctx, function(w) return w.type == "Slider" and w.labelText == label end)
end

local function button(ctx, text)
  return find(ctx, function(w) return w.type == "Button" and w.text == text end)
end

--- Open Appearance on `unit`, unlinked, on the Bar tab. Answers the ctx.
local function open(unit)
  local p = panel()
  p:Show(); p:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  ctx.unit, ctx.activeTab = unit, nil
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  return ctx
end

local saved
local function begin()
  saved = {}
  for _, unit in ipairs(NS.Units.LIST) do
    local c = NS.db.profile.units[unit]
    saved[unit] = { position = c.position, mirror = c.mirror }
    c.position = nil
    if unit ~= "player" then c.mirror = false end
  end
end

local function finish()
  for unit, s in pairs(saved) do
    local c = NS.db.profile.units[unit]
    c.position, c.mirror = s.position, s.mirror
  end
  NS.bus:SendMessage(NS.MSG.POSITION)
  local ctx = NS.Helpers.__lastUnitCtx
  ctx.unit, ctx.activeTab = "player", nil
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  panel():Hide()
end

local function guarded(fn)
  begin()
  local ok, err = pcall(fn)
  finish()
  if not ok then error(err, 0) end
end

-- red under: no Position rows, rows that sit anywhere but straight after Size, or rows of the
-- wrong kind (a stored number with no 1 px step, or one the mirror would answer for).
test("position rows: X and Y offset per unit, under Bar > Position, on a 1 px step", function()
  for _, unit in ipairs(NS.Units.LIST) do
    for _, axis in ipairs({ "x", "y" }) do
      local row = NS.FindSchemaRow("units." .. unit .. ".position." .. axis)
      assertTrue(row ~= nil, unit .. " has a " .. axis .. " row")
      assertEqual(row.type, "number", axis .. " is a number row")
      assertEqual(row.page, "appearance")
      assertEqual(row.group, "Bar")
      assertEqual(row.subgroup, "Position")
      assertEqual(row.unit, unit, "tagged with its unit, so the picker filters it")
      assertEqual(row.step, 1, "a 1 px step")
      assertEqual(row.label, axis == "x" and "X offset" or "Y offset")
      assertTrue(row.alwaysPerUnit, "position is never mirrored")
      assertTrue(type(row.get) == "function" and type(row.set) == "function",
        "it reads and writes the bar's position table")
      assertEqual(row.commitOn, "change", "a drag of the slider moves the bar while it drags")
    end
  end
end)

test("position rows: they read the stacked default while nothing is stored", function()
  guarded(function()
    for _, unit in ipairs(NS.Units.LIST) do
      local _, _, x, y = NS.DefaultPosition(unit)
      assertEqual(NS.GetSetting("units." .. unit .. ".position.x"), x, unit .. " x")
      assertEqual(NS.GetSetting("units." .. unit .. ".position.y"), y, unit .. " y")
    end
  end)
end)

-- red under: a set that stores only the one axis (the bar would anchor to nil), or one that
-- publishes no POSITION (the bar would not move until the next reload).
test("position rows: a write stores the whole position and moves the bar live", function()
  guarded(function()
    local moved = {}
    local orig = NS.RestoreBarPosition
    NS.RestoreBarPosition = function(unit) moved[unit] = true; return orig(unit) end
    local ok, err = pcall(NS.SetByPath, "units.target.position.x", 40)
    NS.RestoreBarPosition = orig
    if not ok then error(err, 0) end
    local _, _, _, y = NS.DefaultPosition("target")
    local pos = NS.Units.Position("target")
    assertEqual(pos.point, "CENTER")
    assertEqual(pos.relPoint, "CENTER")
    assertEqual(pos.x, 40, "the axis written")
    assertEqual(pos.y, y, "the other axis kept where the bar was")
    assertTrue(moved.target, "the bar re-anchored")
    assertEqual(NS.Units.Position("focus"), nil, "no other bar's position was written")
  end)
end)

test("position rows: a write keeps the anchor a drag stored", function()
  guarded(function()
    NS.Units.SetPosition("focus", { point = "TOPLEFT", relPoint = "TOPLEFT", x = 100, y = -50 })
    assertEqual(NS.GetSetting("units.focus.position.y"), -50, "reads the stored offset")
    NS.SetByPath("units.focus.position.y", -60)
    local pos = NS.Units.Position("focus")
    assertEqual(pos.point, "TOPLEFT")
    assertEqual(pos.relPoint, "TOPLEFT")
    assertEqual(pos.x, 100)
    assertEqual(pos.y, -60)
  end)
end)

test("position rows: the Bar tab draws them, and a slider writes the bar's position", function()
  guarded(function()
    local ctx = open("target")
    local sx = slider(ctx, "X offset")
    assertTrue(sx ~= nil, "an X offset slider on the Bar tab")
    assertTrue(slider(ctx, "Y offset") ~= nil, "and a Y offset slider")
    assertEqual(sx.value, 0, "the slider shows where the bar is")
    sx:__fire("OnMouseUp", -25)
    assertEqual(NS.Units.Position("target").x, -25, "the release committed the offset")
  end)
end)

-- red under: a drag that saves the position and leaves the open panel's sliders where they were.
test("position rows: dragging the bar moves its sliders", function()
  guarded(function()
    local ctx = open("target")
    local bar = NS.bars.target
    rawset(bar, "GetPoint", function() return "CENTER", UIParent, "CENTER", 12, 34 end)
    rawset(bar, "StopMovingOrSizing", function() end)
    local ok, err = pcall(bar.__fire, bar, "OnDragStop")
    rawset(bar, "GetPoint", nil)
    rawset(bar, "StopMovingOrSizing", nil)
    if not ok then error(err, 0) end
    assertEqual(slider(ctx, "X offset").value, 12, "X follows the drop")
    assertEqual(slider(ctx, "Y offset").value, 34, "Y follows the drop")
  end)
end)

test("position rows: Reset position puts this bar back in the stack, and only this one", function()
  guarded(function()
    NS.Units.SetPosition("player", { point = "CENTER", relPoint = "CENTER", x = 5, y = 5 })
    NS.Units.SetPosition("target", { point = "CENTER", relPoint = "CENTER", x = 7, y = 7 })
    local ctx = open("target")
    local btn = button(ctx, "Reset position")
    assertTrue(btn ~= nil, "a Reset position button under the block")
    btn:__fire("OnClick")
    assertEqual(NS.Units.Position("target"), nil, "the target is back on its stacked default")
    assertTrue(NS.Units.Position("player") ~= nil, "the player bar kept its place")
    local _, _, _, y = NS.DefaultPosition("target")
    assertEqual(slider(ctx, "Y offset").value, y, "the slider follows the reset")
  end)
end)

test("position rows: the page's Defaults puts every bar back in the stack", function()
  guarded(function()
    for _, unit in ipairs(NS.Units.LIST) do
      NS.Units.SetPosition(unit, { point = "CENTER", relPoint = "CENTER", x = 9, y = 9 })
    end
    local ctx = open("player")
    panel().defaultsOnClick()
    for _, unit in ipairs(NS.Units.LIST) do
      assertEqual(NS.Units.Position(unit), nil, unit .. " is back on its stacked default")
    end
    assertEqual(slider(ctx, "X offset").value, 0, "the slider follows")
  end)
end)

-- The page's existing behavior: a linked unit's tabs show the hint instead of their rows.
test("position rows: a linked unit's Bar tab shows the hint, Position rows included", function()
  guarded(function()
    NS.db.profile.units.focus.mirror = true
    local ctx = open("focus")
    assertEqual(slider(ctx, "X offset"), nil, "no Position rows on a linked unit")
    assertEqual(button(ctx, "Reset position"), nil, "and no reset button")
  end)
end)

test("position rows: /at set moves a bar", function()
  guarded(function()
    NS.Slash:OnSlash("set units.player.position.y 120")
    local pos = NS.Units.Position("player")
    assertTrue(pos ~= nil and pos.y == 120, "the CLI wrote the player's Y offset")
  end)
end)

-- red under: a set that stores a position equal to the stacked default (the bar would stop
-- following the stack when the player bar's height changes), or a row with no default for
-- `/at reset` and the Defaults walk to apply.
test("position rows: a write back onto the stacked default clears the position", function()
  guarded(function()
    NS.SetByPath("units.target.position.x", 40)
    assertTrue(NS.Units.Position("target") ~= nil, "precondition: stored")
    NS.Slash:OnSlash("reset units.target.position.x")
    assertEqual(NS.Units.Position("target"), nil, "back on the stack, nothing stored")
    local _, _, _, y = NS.DefaultPosition("target")
    assertEqual(NS.FindSchemaRow("units.target.position.y").default, y,
      "the row's default is the stacked default's axis")
  end)
end)
