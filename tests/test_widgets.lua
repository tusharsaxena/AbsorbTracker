local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The schema-row → AceGUI widget translation layer, as THIS addon is wired to it. The makers
-- themselves are LibKa0s-Options-1.0 and are tested in that repo; these cases pin the pages this
-- addon actually builds, through the real ctx the real builders produced.
--
-- These run against the AceGUI mock in tests/wow_mock.lua: widgets are inert recorders that
-- remember what was set on them and expose __fire(event, ...) so a test can drive a callback
-- exactly as AceGUI would on a click or a slider release. That is what makes the real
-- read → SetByPath → RefreshAllPanels loop observable instead of assumed.
--
-- tests/run.lua calls NS.CreateOptionsPanel() at bootstrap, so NS.AceGUI is stashed and every
-- settings/<page>.lua builder has already run for real.

local Helpers = NS.Helpers
local AceGUI  = NS.AceGUI

local n = 0
local function newCtx()
  n = n + 1
  return Helpers.CreatePanel("ATWidgetTestPanel" .. n, "Widget Test " .. n, {})
end

-- Render one schema path into a throwaway container and hand back the widget + its row.
local function render(path, relativeWidth)
  local ctx = newCtx()
  local row = NS.FindSchemaRow(path)
  assertTrue(row ~= nil, "schema row exists: " .. path)
  local parent = AceGUI:Create("SimpleGroup")
  local widget = Helpers.RenderField(ctx, row, parent, relativeWidth)
  return widget, row, ctx, parent
end

local function withSetting(key, value, body)
  local saved = NS.GetSetting(key)
  NS.SetSetting(key, value)
  local ok, err = pcall(body)
  NS.SetSetting(key, saved)
  if not ok then error(err) end
end

test("NS.AceGUI is stashed once by CreateOptionsPanel, not re-fetched per builder", function()
  assertTrue(NS.AceGUI ~= nil, "the panel build stashes AceGUI (Ka0s standard §3.4)")
end)

-- ── Checkbox ───────────────────────────────────────────────────────────────────────

test("a bool row renders a CheckBox labelled from the schema", function()
  local cb, row = render("showOnlyInCombat")
  assertEqual(cb.type, "CheckBox")
  assertEqual(cb.labelText, row.label)
end)

test("a checkbox reads its initial state from the current setting", function()
  withSetting("showOnlyInCombat", true, function()
    assertTrue(render("showOnlyInCombat").value)
  end)
  withSetting("showOnlyInCombat", false, function()
    assertFalse(render("showOnlyInCombat").value)
  end)
end)

test("clicking a checkbox writes through SetByPath", function()
  withSetting("showOnlyInCombat", false, function()
    local cb = render("showOnlyInCombat")
    cb:__fire("OnValueChanged", true)
    assertTrue(NS.GetSetting("showOnlyInCombat"), "the click reached the DB")
    cb:__fire("OnValueChanged", false)
    assertFalse(NS.GetSetting("showOnlyInCombat"))
  end)
  T.mocks.__fireTimers()
end)

test("a checkbox registers a refresher that re-reads after an external change", function()
  withSetting("showOnlyInCombat", false, function()
    local cb, _, ctx = render("showOnlyInCombat")
    assertFalse(cb.value)
    NS.SetSetting("showOnlyInCombat", true)    -- changed behind the widget's back, e.g. by /at set
    for _, fn in ipairs(ctx.refreshers) do fn() end
    assertTrue(cb.value, "the refresher pulled the new value in")
  end)
end)

test("every widget gets tooltip callbacks wired from the schema desc", function()
  local cb = render("showOnlyInCombat")
  assertTrue(cb.callbacks.OnEnter ~= nil, "OnEnter shows the tooltip")
  assertTrue(cb.callbacks.OnLeave ~= nil, "OnLeave hides it")
end)

test("relativeWidth is applied when given, full width otherwise", function()
  assertEqual(render("showOnlyInCombat", 0.5).relativeWidth, 0.5)
  local full = render("showOnlyInCombat")
  assertEqual(full.relativeWidth, nil)
  assertTrue(full.fullWidth, "no relative width means the widget spans the row")
end)

-- ── SessionCheckbox (non-schema) ───────────────────────────────────────────────────

test("SessionCheckbox reads and writes the caller's get/set, never the DB", function()
  -- The Debug-console toggle is session-only and must not become a saved setting.
  local state = false
  local ctx = newCtx()
  local before = NS.db.profile
  local cb = Helpers.SessionCheckbox(ctx, AceGUI:Create("SimpleGroup"), 0.5, {
    label   = "Debug console",
    tooltip = "Show the console",
    get     = function() return state end,
    set     = function(v) state = v end,
  })
  assertFalse(cb.value, "initial state comes from get()")
  cb:__fire("OnValueChanged", true)
  assertTrue(state, "the click reached set()")
  assertEqual(NS.db.profile, before, "and nothing was persisted")
  assertEqual(NS.db.profile.debugConsole, nil, "no stray key was written")
end)

test("SessionCheckbox registers a refresher so external state changes show up", function()
  local state = false
  local ctx = newCtx()
  local cb = Helpers.SessionCheckbox(ctx, AceGUI:Create("SimpleGroup"), 0.5, {
    label = "Debug console", get = function() return state end, set = function() end,
  })
  state = true
  for _, fn in ipairs(ctx.refreshers) do fn() end
  assertTrue(cb.value)
end)

-- ── Slider ─────────────────────────────────────────────────────────────────────────

test("a number row renders a Slider carrying the schema's range and step", function()
  local s, row = render("units.player.barWidth")
  assertEqual(s.type, "Slider")
  assertEqual(s.min, row.min)
  assertEqual(s.max, row.max)
  assertEqual(s.step, row.step)
  assertFalse(s.isPercent, "raw units, not a percentage")
end)

test("a slider shows the current value", function()
  withSetting("units.player.barWidth", 275, function()
    assertEqual(render("units.player.barWidth").value, 275)
  end)
end)

test("a slider falls back to the row default when the stored value is not a number", function()
  -- A corrupt SavedVariable would otherwise hand AceGUI a nil/string and blow up the layout.
  local saved = NS.db.profile.units.player.barWidth
  NS.db.profile.units.player.barWidth = "not a number"
  local s, row = render("units.player.barWidth")
  NS.db.profile.units.player.barWidth = saved
  assertEqual(s.value, row.default)
end)

test("releasing a slider snaps the value to the row's step", function()
  local s, row = render("units.player.barWidth")
  s:__fire("OnMouseUp", 217.4)
  local v = NS.GetSetting("units.player.barWidth")
  assertEqual(v % row.step, 0, "the committed value sits on a step boundary")
  assertEqual(v, 217)
  NS.SetByPath("units.player.barWidth", NS.unitDefaults.barWidth)
  T.mocks.__fireTimers()
end)

test("slider snapping is relative to the row's min, not to zero", function()
  -- snapToStep offsets by `min` before rounding; a step that does not divide `min` evenly would
  -- otherwise land the slider on values it can never reach by dragging.
  local s, row = render("units.player.fontSize")
  s:__fire("OnMouseUp", (row.min or 0) + (row.step or 1) * 2 + (row.step or 1) * 0.4)
  local v = NS.GetSetting("units.player.fontSize")
  assertEqual((v - row.min) % row.step, 0)
  NS.SetByPath("units.player.fontSize", NS.unitDefaults.fontSize)
  T.mocks.__fireTimers()
end)

-- ── Dropdown ───────────────────────────────────────────────────────────────────────

test("a string row falls back to a plain Dropdown when the LSM widget is absent", function()
  -- AceGUI-3.0-SharedMediaWidgets is an optional dependency; without it the option must still
  -- render (no media swatch, but usable) rather than erroring on an unknown widget type.
  local dd, row = render("units.player.barTexture")
  assertEqual(row.dialogControl, "LSM30_Statusbar", "the row does ask for the LSM widget")
  assertEqual(dd.type, "Dropdown", "but falls back when it is not registered")
end)

test("a string row uses its dialogControl widget when that IS registered", function()
  AceGUI:RegisterWidgetType("LSM30_Statusbar",
    function() return T.mocks.__makeAceGUIWidget("LSM30_Statusbar") end, 1)
  local ok, err = pcall(function()
    assertEqual(render("units.player.barTexture").type, "LSM30_Statusbar")
  end)
  AceGUI.WidgetRegistry["LSM30_Statusbar"]   = nil
  AceGUI.__widgetVersions["LSM30_Statusbar"] = nil
  if not ok then error(err) end
end)

test("a dropdown's list is alphabetically ordered by default", function()
  local dd = render("units.player.font")
  assertTrue(type(dd.list) == "table", "the values hash was applied")
  local order = dd.order
  for i = 2, #order do
    assertTrue(order[i - 1] <= order[i], "dropdown order is sorted")
  end
end)

test("a row with explicit `sorting` keeps that order instead of sorting", function()
  -- Font outline styles read in a deliberate order (None, Outline, Thick…); alphabetising them
  -- would scramble it.
  local dd, row = render("units.player.fontFlags")
  assertTrue(row.sorting ~= nil, "fontFlags declares an explicit order")
  assertEqual(#dd.order, #row.sorting)
  for i, key in ipairs(row.sorting) do
    assertEqual(dd.order[i], key, "position " .. i .. " preserved")
  end
end)

test("a dropdown shows the current value and writes the chosen one", function()
  local saved = NS.GetSetting("units.player.fontFlags")
  local dd = render("units.player.fontFlags")
  assertEqual(dd.value, saved)
  dd:__fire("OnValueChanged", "NONE")
  assertEqual(NS.GetSetting("units.player.fontFlags"), "NONE")
  NS.SetByPath("units.player.fontFlags", saved)
  T.mocks.__fireTimers()
end)

test("a dropdown's refresher re-applies the list, so a grown LSM list appears", function()
  local dd, _, ctx = render("units.player.fontFlags")
  dd.list, dd.order = nil, nil
  for _, fn in ipairs(ctx.refreshers) do fn() end
  assertTrue(dd.list ~= nil, "the list was rebuilt, not just the value re-read")
  assertTrue(dd.order ~= nil)
end)

-- ── ColorPicker ────────────────────────────────────────────────────────────────────

test("a color row renders a ColorPicker seeded from the stored rgba", function()
  withSetting("units.player.barColor", { r = 0.1, g = 0.2, b = 0.3, a = 0.4 }, function()
    local cp, row = render("units.player.barColor")
    assertEqual(cp.type, "ColorPicker")
    assertEqual(cp.hasAlpha, row.hasAlpha and true or false)
    assertTrue(math.abs(cp.color.r - 0.1) < 1e-6)
    assertTrue(math.abs(cp.color.a - 0.4) < 1e-6)
  end)
end)

test("a color picker substitutes 1s for a missing/corrupt stored colour", function()
  local saved = NS.db.profile.units.player.barColor
  NS.db.profile.units.player.barColor = "not a table"
  local cp = render("units.player.barColor")
  NS.db.profile.units.player.barColor = saved
  assertEqual(cp.color.r, 1)
  assertEqual(cp.color.a, 1)
end)

test("disabledIf greys the swatch out while its sibling toggle is on", function()
  withSetting("units.player.useClassColorBar", true, function()
    assertTrue(render("units.player.barColor").disabled, "class colour on -> swatch disabled")
  end)
  withSetting("units.player.useClassColorBar", false, function()
    assertFalse(render("units.player.barColor").disabled, "class colour off -> swatch live")
  end)
end)

test("the refresher re-evaluates disabledIf, so the pair tracks on the same frame", function()
  -- This is what makes "Use Class Color" grey out its partner swatch immediately: set() calls
  -- RefreshAllPanels, which re-runs this refresher.
  withSetting("units.player.useClassColorBar", false, function()
    local cp, _, ctx = render("units.player.barColor")
    assertFalse(cp.disabled)
    NS.SetSetting("units.player.useClassColorBar", true)
    for _, fn in ipairs(ctx.refreshers) do fn() end
    assertTrue(cp.disabled)
  end)
end)

test("OnValueConfirmed commits the colour immediately (cancel must not wait on the throttle)", function()
  local cp = render("units.player.barColor")
  T.mocks.__fireTimers()
  cp:__fire("OnValueConfirmed", 0.5, 0.6, 0.7, 0.8)
  local c = NS.GetSetting("units.player.barColor")
  assertTrue(math.abs(c.r - 0.5) < 1e-6 and math.abs(c.a - 0.8) < 1e-6,
    "the confirmed colour is stored without a timer round-trip")
  NS.ApplyDefault(NS.FindSchemaRow("units.player.barColor"))
  T.mocks.__fireTimers()
end)

test("OnValueChanged throttles a drag to ONE timer and commits the latest value", function()
  -- A live-preview drag fires at up to 60 Hz. Without the single re-armed timer that is 60
  -- repaints and 60 closures a second.
  local cp = render("units.player.barColor")
  T.mocks.__fireTimers()
  assertEqual(#T.mocks.__timers, 0)

  cp:__fire("OnValueChanged", 0.1, 0.1, 0.1, 1)
  cp:__fire("OnValueChanged", 0.2, 0.2, 0.2, 1)
  cp:__fire("OnValueChanged", 0.3, 0.3, 0.3, 1)
  assertEqual(#T.mocks.__timers, 1, "three drag frames arm exactly one timer")

  T.mocks.__fireTimers()
  local c = NS.GetSetting("units.player.barColor")
  assertTrue(math.abs(c.r - 0.3) < 1e-6, "the LAST drag value wins, not the first")

  NS.ApplyDefault(NS.FindSchemaRow("units.player.barColor"))
  T.mocks.__fireTimers()
end)

test("a drag that resumes after the timer fired arms a fresh one", function()
  local cp = render("units.player.barColor")
  T.mocks.__fireTimers()
  cp:__fire("OnValueChanged", 0.4, 0.4, 0.4, 1)
  assertEqual(#T.mocks.__timers, 1)
  T.mocks.__fireTimers()
  cp:__fire("OnValueChanged", 0.5, 0.5, 0.5, 1)
  assertEqual(#T.mocks.__timers, 1, "the timer self-cleared, so the next frame re-arms")
  T.mocks.__fireTimers()
  local c = NS.GetSetting("units.player.barColor")
  assertTrue(math.abs(c.r - 0.5) < 1e-6)
  NS.ApplyDefault(NS.FindSchemaRow("units.player.barColor"))
  T.mocks.__fireTimers()
end)

-- ── RenderField dispatch ───────────────────────────────────────────────────────────

test("RenderField dispatches each schema type to its widget", function()
  assertEqual(render("showOnlyInCombat").type, "CheckBox")
  assertEqual(render("units.player.barWidth").type, "Slider")
  assertEqual(render("units.player.fontFlags").type, "Dropdown")
  assertEqual(render("units.player.barColor").type, "ColorPicker")
end)

test("RenderField returns nil for an unrecognised type instead of erroring", function()
  local ctx = newCtx()
  local widget = Helpers.RenderField(ctx, { path = "x", type = "mystery", label = "X" },
    AceGUI:Create("SimpleGroup"), 0.5)
  assertEqual(widget, nil)
end)

test("RenderField adds the widget to the parent it was given", function()
  local ctx = newCtx()
  local parent = AceGUI:Create("SimpleGroup")
  local w = Helpers.RenderField(ctx, NS.FindSchemaRow("units.player.barWidth"), parent, 0.5)
  assertEqual(#parent.children, 1)
  assertEqual(parent.children[1], w)
end)

-- ── RenderSchema layout ────────────────────────────────────────────────────────────

-- Collect every widget RenderSchema produced, depth-first, so the row/heading structure can be
-- asserted without reaching into AceGUI internals.
local function flatten(widget, out)
  out = out or {}
  for _, child in ipairs(widget.children or {}) do
    out[#out + 1] = child
    flatten(child, out)
  end
  return out
end

test("RenderSchema pairs widgets two-to-a-row inside full-width Flow groups", function()
  local ctx = newCtx()
  Helpers.RenderSchema(ctx, "border")
  local rows = {}
  for _, child in ipairs(ctx.scroll.children) do
    if child.type == "SimpleGroup" and child.layout == "Flow" then rows[#rows + 1] = child end
  end
  assertTrue(#rows > 0, "at least one flow row was laid out")
  for _, r in ipairs(rows) do
    assertTrue(r.fullWidth, "each row spans the panel so its two halves split it evenly")
    assertTrue(#r.children <= 2, "never more than two widgets per row")
  end
end)

test("RenderSchema gives each paired widget half the row", function()
  local ctx = newCtx()
  Helpers.RenderSchema(ctx, "border")
  for _, w in ipairs(flatten(ctx.scroll)) do
    if w.relativeWidth then assertEqual(w.relativeWidth, 0.5) end
  end
end)

test("a `solo` row is rendered alone on its own line", function()
  -- barTexture and bgTexture are solo pivots; pairing them would misread as a two-column group.
  local ctx = newCtx()
  Helpers.RenderSchema(ctx, "bar")
  local soloRow
  for _, child in ipairs(ctx.scroll.children) do
    if child.type == "SimpleGroup" and child.layout == "Flow" then
      for _, w in ipairs(child.children) do
        if w.labelText == NS.FindSchemaRow("units.player.barTexture").label then soloRow = child end
      end
    end
  end
  assertTrue(soloRow ~= nil, "the barTexture row was found")
  assertEqual(#soloRow.children, 1, "a solo row holds exactly one widget")
end)

test("RenderSchema emits a Heading for each schema group", function()
  local ctx = newCtx()
  Helpers.RenderSchema(ctx, "bar")
  local headings = {}
  for _, child in ipairs(ctx.scroll.children) do
    if child.type == "Heading" then headings[child.text] = true end
  end
  local groups = {}
  for _, row in ipairs(NS.SchemaForPage("bar")) do
    if row.group then groups[row.group] = true end
  end
  for group in pairs(groups) do
    assertTrue(headings[group], "group '" .. group .. "' got a section heading")
  end
end)

test("an afterGroup callback fires exactly once, after its group's last row", function()
  local ctx = newCtx()
  local fired = 0
  local group = NS.FindSchemaRow("units.player.borderSize").group
  Helpers.RenderSchema(ctx, "border", { [group] = function() fired = fired + 1 end })
  assertEqual(fired, 1)
end)

-- The General page's Master controls run the three enable toggles down the LEFT column, each
-- paired with a global on the right; Enable Focus Bar is the odd one out and takes the Debug
-- console checkbox as its partner through the pairWith seam (asserted separately below).
-- RenderRows fills left-then-right in schema order, so the pairing is entirely a product of row
-- order — a re-numbered `order` silently re-columns the page, which is what these pin.
test("each enable toggle leads its row, paired with a global on the right", function()
  local ctx = newCtx()
  Helpers.RenderSchema(ctx, "general")

  local function rowContaining(label)
    for _, child in ipairs(ctx.scroll.children) do
      if child.type == "SimpleGroup" and child.layout == "Flow" then
        for _, w in ipairs(child.children) do
          if w.labelText == label then return child end
        end
      end
    end
  end

  local pairs_ = {
    { "Enable Player Bar", "Lock Position"       },
    { "Enable Target Bar", "Show only in combat" },
  }
  for _, p in ipairs(pairs_) do
    local row = rowContaining(p[1])
    assertTrue(row ~= nil, "no row rendered for " .. p[1])
    assertEqual(#row.children, 2, p[1] .. " must share its row with exactly one widget")
    assertEqual(row.children[2].labelText, p[2], p[1] .. " must pair with " .. p[2])
  end
end)

test("every tracked unit gets an enable toggle on the General page", function()
  local ctx = newCtx()
  Helpers.RenderSchema(ctx, "general")
  local labels = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText then labels[child.labelText] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)
  for _, unit in ipairs(NS.Units.LIST) do
    assertTrue(labels["Enable " .. NS.Units.LABEL[unit] .. " Bar"],
      unit .. " has no enable toggle on the General page")
  end
end)

test("a pairWith partner is attached to the named row and is one-shot", function()
  -- `units.focus.enabled` is the production pairing site: the session-only "Debug console"
  -- checkbox rides beside Enable Focus Bar as the right half of its row (settings/General.lua).
  -- It only works because the five schema rows above pair off as 2 + 2 + 1, leaving Enable Focus
  -- Bar alone on its row — pairWith declines to fire otherwise, so this doubles as a guard that
  -- the Master controls row count stays odd.
  local ctx = newCtx()
  local made = 0
  local partner = {
    ["units.focus.enabled"] = function(_ctxRef, rowGroup)
      made = made + 1
      rowGroup:AddChild(AceGUI:Create("CheckBox"))
    end,
  }
  Helpers.RenderSchema(ctx, "general", nil, partner)
  assertEqual(made, 1, "the partner was built once")
  assertEqual(partner["units.focus.enabled"], nil, "and the entry was consumed so it cannot repeat")

  -- It must land as the SECOND widget of that row, not on a line of its own.
  local lockedLabel = NS.FindSchemaRow("units.focus.enabled").label
  local row
  for _, child in ipairs(ctx.scroll.children) do
    if child.type == "SimpleGroup" and child.layout == "Flow" then
      for _, w in ipairs(child.children) do
        if w.labelText == lockedLabel then row = child end
      end
    end
  end
  assertTrue(row ~= nil, "the Enable Focus Bar row was found")
  assertEqual(#row.children, 2, "the pair stays 50/50 and never overflows to three-wide")
end)

test("RenderSchema runs a layout pass at the end", function()
  local ctx = newCtx()
  Helpers.RenderSchema(ctx, "font")
  assertTrue((ctx.scroll.layoutCount or 0) > 0, "DoLayout is what positions the children")
end)

test("EnsureScroll is lazy, created once, and patched for an always-visible scrollbar", function()
  local ctx = newCtx()
  assertEqual(ctx.scroll, nil, "no scroll frame until something is rendered")
  local first = Helpers.EnsureScroll(ctx)
  assertEqual(Helpers.EnsureScroll(ctx), first, "subsequent calls reuse it")
  -- The marker moved with the patch: it is `_ka0sAlwaysScrollbar` now, not `_atAlwaysScrollbar`.
  -- AceGUI pools ScrollFrames across every addon in a session, so a per-addon marker name would let
  -- two LibKa0s-consuming addons each patch a widget the other had already patched.
  assertTrue(first._ka0sAlwaysScrollbar, "LibKa0s-Options-1.0's scrollbar patch was applied")
  assertTrue(first.scrollBarShown, "the scrollbar and its gutter stay shown across pages")
  assertEqual(first.content.width, first.content.original_width - 20,
    "the content is inset by the scrollbar gutter so every page's right edge lines up")
end)

-- ── The real pages, driven through their deferred OnShow ───────────────────────────

test("every schema page registered a real Blizzard subcategory at build time", function()
  for _, name in ipairs({ "General", "Bar", "Border", "Font" }) do
    assertTrue(T.mocks.__subcategories[name] ~= nil, name .. " page was registered")
  end
end)

test("the Profiles page self-skips when AceDBOptions is unavailable", function()
  -- It is an optional dependency; the page must opt out silently rather than erroring the build.
  assertEqual(T.mocks.__subcategories["Profiles"], nil)
end)

test("a page renders nothing until its first OnShow", function()
  -- The body is deferred because ctx.body has zero width at enable time and AceGUI lays children
  -- out against the container's current width.
  local panel = T.mocks.__subcategories["Font"]
  assertTrue(panel:GetScript("OnShow") ~= nil, "the deferred render is wired to OnShow")
  assertEqual(panel.defaultsBtn, nil, "and nothing has been built yet")
end)

test("first OnShow builds the Defaults button and renders the page", function()
  local panel = T.mocks.__subcategories["Font"]
  panel:__fire("OnShow")
  assertTrue(panel.defaultsBtn ~= nil, "the button is built late, after skinners have loaded")
  assertEqual(panel.defaultsBtn.text, "Defaults")
  assertTrue(panel.defaultsBtn.callbacks.OnClick ~= nil, "the parked click handler got wired")
end)

test("the Defaults button restores just its own page", function()
  local panel = T.mocks.__subcategories["Font"]
  panel:__fire("OnShow")
  NS.SetSetting("units.player.fontSize", 30)
  NS.SetSetting("units.player.barWidth", 250)
  panel.defaultsBtn.callbacks.OnClick(panel.defaultsBtn, "OnClick")
  assertEqual(NS.GetSetting("units.player.fontSize"), NS.unitDefaults.fontSize, "the Font page was reset")
  assertEqual(NS.GetSetting("units.player.barWidth"), 250, "the Bar page was not")
  NS.SetByPath("units.player.barWidth", NS.unitDefaults.barWidth)
  T.mocks.__fireTimers()
end)

test("a second OnShow rebuilds the panel body without stacking duplicate widgets", function()
  -- Task 6: Bar/Border/Font dropped their `rendered` one-shot guard, because RenderUnitPanel must
  -- re-render on every OnShow so the Unit dropdown and mirror header reflect ctx.unit. That is
  -- only safe because Helpers.ClearScroll releases the old widgets first — so a second OnShow
  -- must land back at the SAME child count, not a second full set stacked on top of the first.
  -- The Defaults button is unaffected: EnsureDefaultsButton still only builds it once.
  local panel = T.mocks.__subcategories["Border"]
  panel:__fire("OnShow")               -- first show: builds
  local btn = panel.defaultsBtn
  assertTrue(btn ~= nil, "the first show built the button")
  local ctx = NS.Helpers.__lastUnitCtx
  local firstCount = #ctx.scroll.children
  assertTrue(firstCount > 0, "the first show rendered something")

  local ok, err = pcall(function() panel:__fire("OnShow") end)   -- second show: must not stack
  if not ok then error(err) end

  assertEqual(panel.defaultsBtn, btn, "the Defaults button is not rebuilt on a repeat show")
  assertEqual(#ctx.scroll.children, firstCount,
    "the scroll ends at the same child count as the first show, not a doubled/stacked set")
end)

test("showing every page builds it without error", function()
  for _, name in ipairs({ "General", "Bar", "Border", "Font" }) do
    local panel = T.mocks.__subcategories[name]
    local ok, err = pcall(function() panel:__fire("OnShow") end)
    assertTrue(ok, name .. " page failed to render: " .. tostring(err))
    assertTrue(panel.defaultsBtn ~= nil, name .. " built its Defaults button")
  end
  T.mocks.__fireTimers()
end)

test("the main page's About content renders on its first OnShow", function()
  local panel = T.mocks.__mainPanel
  assertTrue(panel ~= nil, "the main canvas was registered")
  local ok, err = pcall(function() panel:__fire("OnShow") end)
  assertTrue(ok, "BuildMainContent failed: " .. tostring(err))
end)
