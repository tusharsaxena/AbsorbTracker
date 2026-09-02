local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

-- The panel toolkit as THIS addon is wired to it. The toolkit itself is LibKa0s-Options-1.0 and is
-- tested in that repo; what these cases pin is that AbsorbTracker still reaches it correctly through
-- NS.Helpers (settings/OptionsSetup.lua) — the CreatePanel factory + registry,
-- and the reset/refresh trio (RestoreDefaults / RestoreAllDefaults / RefreshAllPanels) that both
-- the Defaults buttons and the /at reset* verbs run through.
--
-- The widget-building half (EnsureScroll / Section / InlineButtonPair / RenderSchema) needs a live
-- AceGUI-3.0, which is absent headlessly, so it is covered by the in-game smoke tests instead —
-- see docs/smoke-tests.md.

local Helpers = NS.Helpers

-- ── CreatePanel + the panel registry ───────────────────────────────────────────────

test("CreatePanel returns a ctx wired to a panel, a body and an empty refresher list", function()
  local ctx = Helpers.CreatePanel("ATTestPanelA", "Test A", { pageKey = "general" })
  assertTrue(ctx.panel ~= nil, "ctx carries the canvas frame")
  assertTrue(ctx.body ~= nil, "and its body child")
  assertEqual(ctx.pageKey, "general")
  assertEqual(#ctx.refreshers, 0)
  assertEqual(ctx.scroll, nil, "the AceGUI scroll frame stays lazy until first render")
end)

-- ── the Blizzard canvas contract (LibKa0s-Options-1.0 minor 5) ─────────────────────
--
-- Blizzard's Settings window calls OnCommit on apply, OnRefresh on re-show, and OnDefault from its
-- own FOOTER defaults control — which is a different widget from the header Defaults button this
-- addon builds, and is not per-page. The library stamps all three in CreatePanel as of minor 5, so
-- this addon gained a working footer control without a line of its own changing. These cases are
-- what notice if a re-vendor takes it away again: nothing in this repo would otherwise, because
-- every page's header button keeps working and looks equivalent to the user.
--
-- RAWGET throughout, and that is the point rather than a style choice. The frame mock synthesizes a
-- no-op for any PascalCase key, so `type(panel.OnDefault) == "function"` is true whether or not a
-- single line ever set it.

test("the canvas frame carries OnCommit, OnDefault and OnRefresh from the library", function()
  local ctx = Helpers.CreatePanel("ATTestPanelCanvas1", "Canvas 1", { defaultsButton = true })
  assertEqual(type(rawget(ctx.panel, "OnCommit")),  "function", "OnCommit")
  assertEqual(type(rawget(ctx.panel, "OnDefault")), "function", "OnDefault")
  assertEqual(type(rawget(ctx.panel, "OnRefresh")), "function", "OnRefresh")
end)

test("OnDefault reaches a defaultsOnClick parked AFTER the panel is built", function()
  -- The ordering is the whole reason the library forwards rather than assigns, and it is this
  -- addon's shape that makes it matter: settings/General.lua, Bar.lua, Border.lua and Font.lua all
  -- park their handler after CreatePanel returns, because the button does not exist until first
  -- OnShow. A re-vendor that turned the forwarder back into an assignment would capture nil in all
  -- four pages, silently, and only the footer control would notice — in game.
  local ctx = Helpers.CreatePanel("ATTestPanelCanvas2", "Canvas 2", { defaultsButton = true })
  local ran = 0
  ctx.panel.defaultsOnClick = function() ran = ran + 1 end
  rawget(ctx.panel, "OnDefault")()
  assertEqual(ran, 1, "the footer control must reach the page's parked defaults action")
end)

test("a page that parks no defaults action still has a callable, inert OnDefault", function()
  -- The footer control is not per-page, so it can be clicked while the landing page is open.
  local ctx = Helpers.CreatePanel("ATTestPanelCanvas3", "Canvas 3", {})
  assertNil(rawget(ctx.panel, "defaultsOnClick"))
  rawget(ctx.panel, "OnDefault")()   -- must not raise
end)

test("CreatePanel names the panel with the plain title for the Blizzard left tree", function()
  -- The header FontString gets the "Ka0s Absorb Tracker > Page" breadcrumb, but panel.name (what
  -- Blizzard renders in the category tree) must stay unprefixed or the tree reads doubled up.
  local ctx = Helpers.CreatePanel("ATTestPanelB", "Test B", {})
  assertEqual(ctx.panel.name, "Test B")
end)

test("CreatePanel starts the panel hidden", function()
  local ctx = Helpers.CreatePanel("ATTestPanelC", "Test C", {})
  assertFalse(ctx.panel:IsShown(), "Blizzard shows the canvas when its category is selected")
end)

test("CreatePanel only DECLARES the Defaults button, never builds it", function()
  -- options-ui-§5 / anti-pattern #42: the widget must be created on first OnShow, after every
  -- addon (including UI skinners hooking AceGUI:RegisterAsWidget) has loaded. Building it here
  -- would be a load-order race that renders the button unskinned.
  local ctx = Helpers.CreatePanel("ATTestPanelD", "Test D", { defaultsButton = true })
  assertTrue(ctx.panel.wantsDefaultsButton, "the intent is recorded")
  assertEqual(ctx.panel.defaultsBtn, nil, "but no widget exists yet")
end)

test("CreatePanel records no Defaults intent when the page did not ask for one", function()
  local ctx = Helpers.CreatePanel("ATTestPanelE", "Test E", {})
  assertFalse(ctx.panel.wantsDefaultsButton)
end)

test("CreatePanel carries the defaults tooltip through to the lazy builder", function()
  local ctx = Helpers.CreatePanel("ATTestPanelF", "Test F",
    { defaultsButton = true, defaultsTooltip = "Reset this page" })
  assertEqual(ctx.panel.defaultsTooltip, "Reset this page")
end)

test("EnsureDefaultsButton builds the button once, then is idempotent", function()
  local ctx = Helpers.CreatePanel("ATTestPanelG", "Test G",
    { defaultsButton = true, defaultsTooltip = "Reset this page" })
  local clicked = 0
  ctx.panel.defaultsOnClick = function() clicked = clicked + 1 end

  Helpers.EnsureDefaultsButton(ctx.panel)
  local btn = ctx.panel.defaultsBtn
  assertTrue(btn ~= nil, "the first call builds it")
  assertEqual(btn.text, "Defaults")
  assertTrue(btn.callbacks.OnClick ~= nil, "the handler parked on the panel got wired to it")
  assertTrue(btn.callbacks.OnEnter ~= nil, "and the tooltip is attached")

  Helpers.EnsureDefaultsButton(ctx.panel)
  assertEqual(ctx.panel.defaultsBtn, btn, "a second call reuses the same widget")

  btn.callbacks.OnClick(btn, "OnClick")
  assertEqual(clicked, 1)
end)

test("EnsureDefaultsButton is a safe no-op without AceGUI, and on a nil panel", function()
  local ctx = Helpers.CreatePanel("ATTestPanelG2", "Test G2", { defaultsButton = true })
  -- Nils the handle the toolkit itself reads, not NS.AceGUI. Since the extraction NS.Helpers IS
  -- the LibKa0s-Options instance and it stashes AceGUI on itself (Ka0s standard library-stack-§4, one lookup
  -- rather than one per builder); NS.AceGUI is the copy it hands the host for its own page files.
  -- In game the two are always the same object, so this is the same scenario read at the seam the
  -- code under test actually uses.
  local saved = Helpers.AceGUI
  Helpers.AceGUI = nil
  local ok = pcall(Helpers.EnsureDefaultsButton, ctx.panel)
  Helpers.AceGUI = saved
  assertTrue(ok, "must not raise when AceGUI is absent")
  assertEqual(ctx.panel.defaultsBtn, nil, "and must not half-build anything")
  assertTrue(pcall(Helpers.EnsureDefaultsButton, nil), "must not raise on a nil panel")
end)

test("EnsureDefaultsButton leaves a panel that never wanted one alone", function()
  local ctx = Helpers.CreatePanel("ATTestPanelH", "Test H", {})
  Helpers.EnsureDefaultsButton(ctx.panel)
  assertEqual(ctx.panel.defaultsBtn, nil)
end)

-- ── RestoreDefaults ────────────────────────────────────────────────────────────────

test("RestoreDefaults resets every row on the named page", function()
  local rows = NS.SchemaForPage("appearance")
  assertTrue(#rows > 0, "the Appearance page has schema rows to reset")
  for _, row in ipairs(rows) do
    if row.type == "number" then NS.SetSetting(row.path, (row.default or 0) + 1) end
  end
  Helpers.RestoreDefaults("appearance")
  for _, row in ipairs(rows) do
    if row.type == "number" then
      assertEqual(NS.GetSetting(row.path), row.default, row.path .. " is back at its default")
    end
  end
end)

test("RestoreDefaults leaves other pages untouched", function()
  -- The per-panel Defaults button must be page-scoped; a stray global reset here would silently
  -- wipe settings the user never asked about. Border and Font are tabs on the Appearance page now,
  -- not pages, so the pair that proves the scoping is General against Appearance: a General reset
  -- must not touch a unit's styling, and an Appearance reset must not touch the throttle.
  NS.SetSetting("units.player.borderSize", 20)
  Helpers.RestoreDefaults("general")
  assertEqual(NS.GetSetting("units.player.borderSize"), 20,
    "an Appearance value survives a General-page reset")

  NS.SetSetting("throttleWindow", 0.85)
  Helpers.RestoreDefaults("appearance")
  assertEqual(NS.GetSetting("throttleWindow"), 0.85,
    "a General value survives an Appearance-page reset")

  Helpers.RestoreDefaults("appearance")
  Helpers.RestoreDefaults("general")
end)

test("RestoreDefaults runs the ctx refreshers so open widgets re-read", function()
  local ctx = Helpers.CreatePanel("ATTestPanelI", "Test I", { pageKey = "appearance" })
  local ran = 0
  ctx.refreshers[1] = function() ran = ran + 1 end
  ctx.refreshers[2] = function() ran = ran + 1 end
  Helpers.RestoreDefaults("appearance", ctx)
  assertEqual(ran, 2)
end)

test("RestoreDefaults survives a refresher that throws", function()
  -- Refreshers touch live AceGUI widgets; one dead widget must not abort the rest of the reset.
  local ctx = Helpers.CreatePanel("ATTestPanelJ", "Test J", { pageKey = "appearance" })
  local ran = 0
  ctx.refreshers[1] = function() error("boom") end
  ctx.refreshers[2] = function() ran = ran + 1 end
  assertTrue(pcall(Helpers.RestoreDefaults, "appearance", ctx),
    "RestoreDefaults must not propagate")
  assertEqual(ran, 1, "the refresher after the failing one still ran")
  ctx.refreshers[1] = function() end
end)

test("RestoreDefaults on a page with no rows is a harmless no-op", function()
  assertTrue(pcall(Helpers.RestoreDefaults, "nosuchpage"))
end)

-- ── RestoreAllDefaults ─────────────────────────────────────────────────────────────

test("RestoreAllDefaults resets every schema row that is not on the profiles page", function()
  -- Retargeted (spec §9): schema rows now live at dotted per-unit paths, not flat keys.
  NS.SetSetting("units.player.barWidth", 333)
  NS.SetSetting("units.player.borderSize", 30)
  NS.SetSetting("units.player.fontSize", 30)
  Helpers.RestoreAllDefaults()
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth)
  assertEqual(NS.GetSetting("units.player.borderSize"), NS.unitDefaults.borderSize)
  assertEqual(NS.GetSetting("units.player.fontSize"), NS.unitDefaults.fontSize)
  T.mocks.__fireTimers()
end)

test("RestoreAllDefaults clears the saved bar position so the bar recenters", function()
  -- `position` is written by dragging, not by a schema row, so ApplyDefault never touches it. The
  -- explicit clear here is what keeps the popup and `/at resetall` from diverging (they once did).
  -- Retargeted (spec §9): position is now per-unit; check every unit, not just one flat field.
  for _, u in ipairs(NS.Units.LIST) do
    NS.db.profile.units[u].position = { point = "TOPLEFT", relPoint = "TOPLEFT", x = 5, y = 5 }
  end
  Helpers.RestoreAllDefaults()
  for _, u in ipairs(NS.Units.LIST) do
    assertEqual(NS.db.profile.units[u].position, nil, u .. " kept its position")
  end
  T.mocks.__fireTimers()
end)

test("RestoreAllDefaults publishes POSITION so the bar moves immediately", function()
  local seen = 0
  local target = NS.NewBusTarget()
  target:RegisterMessage(NS.MSG.POSITION, function() seen = seen + 1 end)
  Helpers.RestoreAllDefaults()
  target:UnregisterMessage(NS.MSG.POSITION)
  assertEqual(seen, 1)
  T.mocks.__fireTimers()
end)

test("RestoreAllDefaults skips the profiles page (resetting it would delete user data)", function()
  local touched = {}
  local origApply = NS.ApplyDefault
  NS.ApplyDefault = function(row) touched[#touched + 1] = row.page end
  local ok, err = pcall(Helpers.RestoreAllDefaults)
  NS.ApplyDefault = origApply
  if not ok then error(err) end
  for _, page in ipairs(touched) do
    assertTrue(page ~= "profiles", "no profiles-page row may be reset")
  end
  T.mocks.__fireTimers()
end)

-- ── RefreshAllPanels ───────────────────────────────────────────────────────────────

test("RefreshAllPanels runs the refreshers of every registered panel", function()
  local a = Helpers.CreatePanel("ATTestPanelK", "Test K", {})
  local b = Helpers.CreatePanel("ATTestPanelL", "Test L", {})
  local ranA, ranB = 0, 0
  a.refreshers[1] = function() ranA = ranA + 1 end
  b.refreshers[1] = function() ranB = ranB + 1 end
  Helpers.RefreshAllPanels()
  assertEqual(ranA, 1)
  assertEqual(ranB, 1)
  a.refreshers[1] = function() end
  b.refreshers[1] = function() end
end)

test("RefreshAllPanels isolates a throwing refresher from the rest", function()
  local bad = Helpers.CreatePanel("ATTestPanelM", "Test M", {})
  local good = Helpers.CreatePanel("ATTestPanelN", "Test N", {})
  local ran = 0
  bad.refreshers[1] = function() error("dead widget") end
  good.refreshers[1] = function() ran = ran + 1 end
  assertTrue(pcall(Helpers.RefreshAllPanels), "one dead panel must not break the others")
  assertEqual(ran, 1)
  bad.refreshers[1] = function() end
  good.refreshers[1] = function() end
end)

test("NS.RefreshOptionsPanel delegates to RefreshAllPanels", function()
  local ctx = Helpers.CreatePanel("ATTestPanelO", "Test O", {})
  local ran = 0
  ctx.refreshers[1] = function() ran = ran + 1 end
  NS.RefreshOptionsPanel()
  assertEqual(ran, 1)
  ctx.refreshers[1] = function() end
end)

-- ── Shared layout constants ────────────────────────────────────────────────────────

test("the cross-slice layout constants are published for the widget/about slices", function()
  -- Widgets.lua and About.lua read these off Helpers rather than keeping private copies, so the
  -- panel spacing stays in lockstep. A nil here silently collapses every row to zero height.
  assertEqual(type(Helpers.ROW_VSPACER), "number")
  assertEqual(type(Helpers.SECTION_HEADING_H), "number")
  assertEqual(type(Helpers.BUTTON_PAIR_REL), "number")
  assertTrue(Helpers.BUTTON_PAIR_REL < 0.5,
    "the paired-button width is inset under 0.5 so the right button clears the scroll clip")
end)

-- ── The Appearance page: Unit banner + mirror header + tab strip ───────────────────

-- Reach the real Appearance page canvas the harness built, then drive its OnShow.
local function barPanel()
  return T.mocks.__subcategories["Appearance"]
end

-- FIRST, before anything below fires an OnShow, and that position is the case. It used to live in
-- tests/test_widgets.lua against the Font page, which worked only because nothing had opened that
-- page yet; the Appearance collapse left no unopened page there, and a case that depends on
-- which OTHER file ran first is a case that passes for the wrong reason. Asserted here, where the
-- ordering is local and visible.
test("a page renders nothing until its first OnShow", function()
  -- The body is deferred because ctx.body has zero width at enable time and AceGUI lays children
  -- out against the container's current width.
  local panel = barPanel()
  assertTrue(panel:GetScript("OnShow") ~= nil, "the deferred render is wired to OnShow")
  assertEqual(panel.defaultsBtn, nil, "and nothing has been built yet")
end)

test("the Appearance page opens on the player unit with no mirror controls", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  assertEqual(ctx.unit, "player")
end)

-- Depth-first, because the header is laid out by LibKa0s-Options' RenderGrid rather than by hand:
-- every item — wide or paired — lands inside a full-width Flow SimpleGroup that RenderGrid adds to
-- the scroll, so nothing the header builds is a direct child of ctx.scroll any more.
local function findWidget(root, pred)
  for _, child in ipairs(root.children or {}) do
    if pred(child) then return child end
    local hit = findWidget(child, pred)
    if hit then return hit end
  end
end

local function isUnitDropdown(w) return w.type == "Dropdown" and w.labelText == "Unit" end

-- The widgets in the page's ONE chrome block (options-ui-§14), in creation order: the Unit picker,
-- and for target/focus the mirror checkbox and the copy button. They are not in the scroll and they
-- are not the library's, so `findWidget` cannot see them: RenderUnitPanel records them on
-- ctx.__chromeWidgets, which is both its release ledger and the only handle a suite has on a widget
-- a click would reach.
local function chromeWidget(ctx, pred)
  for _, w in ipairs(ctx.__chromeWidgets or {}) do
    if pred(w) then return w end
  end
end

local function chromeLabel(ctx, label)
  return chromeWidget(ctx, function(w) return w.labelText == label end)
end

local function chromeButton(ctx, text)
  return chromeWidget(ctx, function(w) return w.type == "Button" and w.text == text end)
end

test("the Unit picker is in the page's chrome block, and is the page's only picker", function()
  -- options-ui-§14: the picker for "which thing is this page editing" belongs in the chrome band
  -- above the strip, and there must be exactly ONE of it. Three pages used to draw three copies of
  -- this dropdown into three scrolls over one piece of state. It is built INSIDE H.PageHeader's
  -- frame rather than through H.PageBanner, because §14 allows a page one chrome block and this
  -- one also carries the two page-wide mirror controls.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  local dd = ctx.__bannerWidget
  assertTrue(dd ~= nil, "no Unit banner was rendered")
  assertEqual(dd.labelText, "Unit")
  assertEqual(#dd.order, 3)
  assertEqual(dd.order[1], "player")
  assertEqual(dd.value, "player")
  assertEqual(findWidget(ctx.scroll, isUnitDropdown), nil,
    "the scroll must carry no second copy of the picker")
end)

test("switching the picker to focus re-renders the page for that unit", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  local dd = ctx.__bannerWidget
  assertTrue(dd ~= nil, "no Unit banner was rendered")

  -- The mirror checkbox only exists for target/focus, never for player (buildChromeBlock returns
  -- at `if ctx.unit == "player"`). So its presence/absence is a proxy for "did the page actually
  -- get rebuilt for the new unit" — asserting only ctx.unit would pass even if the OnValueChanged
  -- callback dropped its RenderUnitPanel call and merely reassigned the field.
  local function hasMirrorCheckbox()
    return chromeLabel(ctx, "Use same styling as Player") ~= nil
  end
  assertTrue(not hasMirrorCheckbox(), "the player page has no mirror controls before the switch")

  dd:__fire("OnValueChanged", "focus")
  assertEqual(ctx.unit, "focus")
  assertTrue(hasMirrorCheckbox(),
    "switching to focus must actually re-render the page, not just flip ctx.unit")

  NS.Helpers.RenderUnitPanel(ctx, "appearance")   -- restore to a known state for later tests
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

-- ── The tab strip (options-ui-§13) ────────────────────────────────────────────────
--
-- The mock records nothing about a Button's text, so a tab cannot be asserted by its label. What it
-- does record is `__enabled`, and that is enough to pin the whole contract: makeTab disables
-- exactly the ACTIVE tab (a disabled button does not highlight and does not fire, which is how
-- Blizzard's own tab groups mark selection), so the index of the one disabled button IS the
-- selected tab's position in the strip.

-- The strip's buttons, in tab order. ctx.__tabKids also holds the content panel TabStrip draws
-- under the tabs, which is a Frame rather than a Button — filtered out here rather than counted,
-- because it is not a tab and a count that included it would be one off forever.
local function tabButtons(ctx)
  local out = {}
  for _, f in ipairs(ctx.__tabKids or {}) do
    if f.__frameType == "Button" then out[#out + 1] = f end
  end
  return out
end

local function tabNames(ctx)
  local names = NS.Helpers.__partitionTabs(NS.SchemaForPage("appearance", ctx.unit))
  return names
end

test("the Appearance page draws one tab per schema group, in declaration order", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  ctx.unit = "player"
  ctx.activeTab = nil
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local names = tabNames(ctx)
  assertEqual(#tabButtons(ctx), #names, "one button per group, and no more")
  assertEqual(ctx.activeTab, names[1],
    "a page with no tab selected opens on the first, never blank")

  local disabled = {}
  for i, b in ipairs(tabButtons(ctx)) do
    if not b.__enabled then disabled[#disabled + 1] = i end
  end
  assertEqual(#disabled, 1, "exactly one tab is marked selected")
  assertEqual(disabled[1], 1, "and it is the one ctx.activeTab names")
end)

test("clicking a tab switches the page to that tab's rows and nothing else's", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  ctx.unit = "player"
  ctx.activeTab = nil
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local names = tabNames(ctx)
  local borderIndex
  for i, n in ipairs(names) do if n == "Border" then borderIndex = i end end
  assertTrue(borderIndex ~= nil, "the Appearance page has a Border tab")

  tabButtons(ctx)[borderIndex]:__fire("OnClick")
  assertEqual(ctx.activeTab, "Border", "the click must retarget the page, not just repaint it")

  local labels = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText then labels[child.labelText] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertTrue(labels["Border style"], "the Border tab's own rows must be on screen")
  assertTrue(not labels["Bar Width (in px)"],
    "and the tab it came from must be gone, not stacked above it")

  ctx.activeTab = nil
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("a tab click keeps the chrome block, and never grows a second copy of it", function()
  -- The reason this page drives H.TabStrip itself instead of handing the whole body to
  -- H.RenderTabbedSchema: that function renders the active group's rows and nothing else, and its
  -- tab click is ClearScroll + a re-render of ITSELF — which would overwrite the hint this page
  -- draws in place of those rows whenever the unit is mirrored.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  tabButtons(ctx)[2]:__fire("OnClick")
  assertTrue(ctx.__bannerWidget ~= nil, "the picker survives a tab click")
  assertEqual(#ctx.__chromeKids, 2,
    "the chrome ledger holds the block's frame and its divider, never a second set")
  assertEqual(findWidget(ctx.scroll, isUnitDropdown), nil, "and no copy leaked into the scroll")

  ctx.activeTab = nil
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("a mirrored unit STILL gets its tab strip, with the mirrored state as content", function()
  -- The reversal. A mirrored unit used to get no strip at all, on the argument that its five tabs
  -- hold nothing to click through. options-ui-§13 answers that the other way round: the strip is a
  -- property of the PAGE, not of its state, so the page that loses its chrome for one state is the
  -- page that looks broken -- and the only exemptions are pages the flow engine never renders,
  -- which this is not. So the strip is drawn first and unconditionally, and the empty state is
  -- content INSIDE the page.
  -- red under: restoring the `if not mirrored` branch around the strip, or dropping the hint.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = true
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  assertEqual(#tabButtons(ctx), #tabNames(ctx), "a mirrored unit gets the same strip as any other")
  assertTrue(#tabButtons(ctx) > 0, "and that strip is not empty")
  assertTrue(ctx.__bannerWidget ~= nil, "the Unit picker is still there")

  local texts = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.text then texts[child.text] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertTrue(texts["Linked to Player \226\128\148 uncheck to customize."],
    "the mirrored state is explained in the page body, under the strip")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("a mirrored unit shows only its chrome block, no appearance rows", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = true
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local labels = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText then labels[child.labelText] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)

  assertTrue(chromeLabel(ctx, "Use same styling as Player") ~= nil,
    "the mirror checkbox is in the chrome block")
  assertTrue(not labels["Bar Width (in px)"], "mirrored appearance rows must be hidden")
  -- The enable toggle moved to General's Bars tab; the mirror flag is the only per-unit
  -- row left on this page and it renders in the header, not the body.
  assertTrue(not labels["Enable this bar"], "the enable toggle no longer lives on the Bar page")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("unchecking the mirror reveals the appearance rows", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local labels = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText then labels[child.labelText] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertTrue(labels["Bar Width (in px)"], "an unlinked unit must expose its own appearance rows")

  NS.db.profile.units.focus.mirror = true
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("the copy button snapshots the player's styling and clears the mirror", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.player.barWidth = 288
  NS.db.profile.units.target.mirror = true
  ctx.unit = "target"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local btn = chromeButton(ctx, "Copy styling from Player")
  assertTrue(btn ~= nil, "no copy button was rendered")
  btn:__fire("OnClick")

  assertEqual(NS.db.profile.units.target.mirror, false)
  assertEqual(NS.db.profile.units.target.barWidth, 288)

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("a page Defaults button resets that page across every unit", function()
  NS.db.profile.units.player.barWidth = 111
  NS.db.profile.units.target.barWidth = 222
  NS.db.profile.units.focus.barWidth  = 333
  NS.Helpers.RestoreDefaults("appearance")
  assertEqual(NS.db.profile.units.player.barWidth, NS.unitDefaults.barWidth)
  assertEqual(NS.db.profile.units.target.barWidth, NS.unitDefaults.barWidth)
  assertEqual(NS.db.profile.units.focus.barWidth,  NS.unitDefaults.barWidth)
end)

test("RestoreAllDefaults clears all three saved positions", function()
  for _, u in ipairs(NS.Units.LIST) do
    NS.db.profile.units[u].position = { point = "TOP", relPoint = "TOP", x = 1, y = 1 }
  end
  NS.Helpers.RestoreAllDefaults()
  for _, u in ipairs(NS.Units.LIST) do
    assertEqual(NS.db.profile.units[u].position, nil, u .. "'s position survived the reset")
  end
end)

test("the mirror checkbox renders exactly once — the block owns it, RenderRows must skip it",
  function()
  -- RenderRows is handed BOTH perUnitRows (which includes the alwaysPerUnit+skipRender mirror
  -- row) and styledRows. If it ignored `row.skipRender`, the mirror row would render a second,
  -- bespoke CheckBox down in the body with the same label as the block's — a set-membership
  -- check (labels[x] = true) cannot see that duplicate, so this counts occurrences instead.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local count = 0
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText == "Use same styling as Player" then count = count + 1 end
      walk(child)
    end
  end
  walk(ctx.scroll)
  for _, w in ipairs(ctx.__chromeWidgets or {}) do
    if w.labelText == "Use same styling as Player" then count = count + 1 end
  end
  assertEqual(count, 1,
    "the mirror checkbox must appear exactly once (the chrome block), never again from the body")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

-- ── the page's one chrome block (options-ui-§14) ──────────────────────────────────
--
-- These five replace the three that pinned the mirror header's layout INSIDE the scroll. The header
-- was RenderGrid'd into the scroll below the strip, which is exactly what §14 forbids for a control
-- that applies to every tab; the layout those three measured is gone with it. What is pinned now is
-- where the page-wide controls live, what the block reserves for them, what a raise inside it
-- costs, that its widgets go back to AceGUI's pool, and that the one row still in the scroll keeps
-- the page's vertical rhythm.

test("the page-wide mirror controls sit in the chrome block, never in the scroll", function()
  -- options-ui-§14: "Controls that apply to every tab MUST sit in that band too, above the strip --
  -- never in the scroll below it", and it names copy among the page-wide acts. Both controls govern
  -- all five tabs -- mirroring replaces every tab's rows with the hint, CopyFromPlayer copies every
  -- appearance key -- so drawn in the scroll they read as belonging to whichever tab happens to be
  -- selected, and vanish on the next click. They were drawn there until this change.
  -- red under: handing either control back to Helpers.RenderGrid.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  assertTrue(chromeLabel(ctx, "Use same styling as Player") ~= nil,
    "the mirror checkbox belongs to the chrome block")
  assertTrue(chromeButton(ctx, "Copy styling from Player") ~= nil,
    "and so does the copy button")
  assertEqual(findWidget(ctx.scroll, function(w)
    return w.labelText == "Use same styling as Player"
        or w.text == "Copy styling from Player"
  end), nil, "neither may be drawn into the scroll under the strip")

  -- ONE block, and the picker is inside it. PageHeader and PageBanner release the same ledger and
  -- write the same ctx.__bannerHeight, so a page calling both would draw one band and leave the
  -- other's widgets orphaned in it. The ledger holds the block's frame and its divider, and the
  -- picker is a widget of the block rather than a second entry.
  -- red under: swapping the picker back to Helpers.PageBanner.
  assertEqual(#ctx.__chromeKids, 2,
    "the chrome ledger holds one block frame and one divider, never a second block")
  assertTrue(chromeLabel(ctx, "Unit") ~= nil, "and the picker is built inside that one block")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("the chrome block reserves the band its second row needs", function()
  -- The library does the band arithmetic over a height the HOST declares, so a block that drew a
  -- row it had not asked for would have the tab strip placed on top of it.
  -- red under: returning Helpers.BANNER_H from chromeBlockHeight for every unit.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  local playerBand = ctx.__bannerHeight
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  local focusBand = ctx.__bannerHeight

  assertTrue(type(playerBand) == "number" and playerBand > 0, "the player's block reserves a band")
  assertEqual(focusBand - playerBand, Helpers.ROW_VSPACER + 24,
    "target and focus reserve exactly one more row than the player, who gets the picker alone: " ..
    "ROW_VSPACER plus CONTROL_H (24, AceGUI's own CheckBox and Button height)")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("a raise inside the chrome block costs the block, not the page", function()
  -- H.PageHeader pcalls the builder and reports the raise. The hand-rolled header this replaced was
  -- pcall'd per ITEM by RenderGrid, which is the guarantee a block drawn in one go cannot make --
  -- so what has to hold is the coarser one: the strip and every row under it still render, and the
  -- user is told. AttachTooltip is the seam every block widget touches, so failing it for one label
  -- is the cheapest faithful stand-in for "an AceGUI widget error inside the block".
  -- red under: dropping the pcall in O.PageHeader, or building the block outside it.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"

  local out = {}
  local cf  = T.mocks.DEFAULT_CHAT_FRAME
  local oldMsg = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end

  local saved = Helpers.AttachTooltip
  Helpers.AttachTooltip = function(w, label, desc)
    if label == "Use same styling as Player" then error("simulated widget failure") end
    return saved(w, label, desc)
  end
  local ok = pcall(NS.Helpers.RenderUnitPanel, ctx, "appearance")
  Helpers.AttachTooltip = saved
  cf.AddMessage = oldMsg

  assertTrue(ok, "RenderUnitPanel must not raise")
  assertTrue(#tabButtons(ctx) > 0, "the strip must still be drawn")
  assertTrue(findWidget(ctx.scroll, function(w) return w.labelText == "Bar Width (in px)" end) ~= nil,
    "and the schema rows below the block must still render")
  local joined = table.concat(out, "\n")
  assertTrue(joined:find("simulated widget failure", 1, true) ~= nil,
    "the block's failure must be reported, not swallowed: " .. joined)

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("the chrome block's widgets go back to AceGUI's pool, after the render and not before",
  function()
  -- ClearScroll gets this for free (ReleaseChildren releases everything in the scroll); the chrome
  -- band has no equivalent, because the library's ledger hides and unparents the FRAME the host
  -- drew into and knows nothing about the AceGUI widgets parented to it. Unreleased, the page mints
  -- a fresh Dropdown, CheckBox and Button on every unit switch, tab click and mirror toggle -- and
  -- a WoW frame, once created, is never destroyed.
  -- red under: dropping releaseStaleChromeWidgets; or calling it on the way IN, where the widget
  -- whose callback is running would be back in the pool in time for that same render to hand it
  -- straight out again.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local before = {}
  for i, w in ipairs(ctx.__chromeWidgets) do before[i] = w end
  assertEqual(#before, 3, "the block holds the picker, the mirror checkbox and the copy button")
  for _, w in ipairs(before) do
    assertFalse(w.__released, "the live block's widgets are not released")
  end

  -- Driven from the picker's OWN callback, which is how a render is usually reached.
  ctx.__bannerWidget:__fire("OnValueChanged", "target")

  for _, w in ipairs(before) do
    assertTrue(w.__released, "every widget of the previous block must go back to the pool")
  end
  for _, w in ipairs(ctx.__chromeWidgets) do
    assertFalse(w.__released, "and the block this render built must not go with them")
  end

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("the mirrored hint is a laid-out row followed by a ROW_VSPACER", function()
  -- What is left in the scroll for a mirrored unit, and RenderGrid emits AddSpacer(ROW_VSPACER)
  -- after every flushed row unconditionally -- so the hint keeps the same vertical rhythm as any
  -- schema row further down a page. AddSpacer builds a SimpleGroup with no layout and a fixed
  -- height, which is what tells the two apart.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = true
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local kids = ctx.scroll.children
  assertEqual(kids[1].type, "SimpleGroup")
  assertEqual(kids[1].layout, "Flow", "the hint is a laid-out row, not a spacer")
  assertEqual(kids[2].type, "SimpleGroup")
  assertEqual(kids[2].height, Helpers.ROW_VSPACER,
    "and it is followed by the ROW_VSPACER that follows every flushed row")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("ClearScroll resets ctx.refreshers, so repeated renders do not leak stale closures",
  function()
  -- Every RenderField call appends one refresher closure. Without ClearScroll wiping the table,
  -- each OnShow / unit switch would grow ctx.refreshers forever with closures over widgets that
  -- ReleaseChildren already tore down — and RefreshAllPanels pcalls every one of them on every
  -- /at set, profile change, and Reset All.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  local firstCount = #ctx.refreshers
  assertTrue(firstCount > 0, "the render registered at least one refresher")

  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  assertEqual(#ctx.refreshers, firstCount,
    "re-rendering the SAME unit repeatedly must not grow ctx.refreshers")

  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  assertEqual(#ctx.refreshers, firstCount,
    "switching units and back must also leave ctx.refreshers at a stable size")
end)

-- ── The General page's inline action buttons ────────────────────────────────────

-- Nothing in the suite reached Helpers.InlineButtonPair's onClick before this. The General page's
-- ctx is private to Helpers' `renderedPanels` list and there is no __lastUnitCtx equivalent for
-- it, so the "Reset Position" button was structurally untestable -- which is exactly how it
-- shipped as a silent no-op (it nil'd `db.profile.position`, the pre-v3 FLAT key the v3 migration
-- DELETES, while every bar re-anchors from units.<unit>.position). The harness's AceGUI factory
-- records every widget it hands out; that is the seam used here.
local function aceGUIButton(text)
  for _, w in ipairs(NS.AceGUI.__created) do
    if w.type == "Button" and w.text == text then return w end
  end
end

test("the General page's Reset position button clears EVERY unit's saved position", function()
  T.mocks.__subcategories["General"]:__fire("OnShow")
  local btn = aceGUIButton("Reset position")
  assertTrue(btn ~= nil, "no Reset position button was rendered on the General page")

  for _, u in ipairs(NS.Units.LIST) do
    NS.Units.SetPosition(u, { point = "TOP", relPoint = "TOP", x = 7, y = 7 })
  end
  btn:__fire("OnClick")
  for _, u in ipairs(NS.Units.LIST) do
    assertEqual(NS.Units.Position(u), nil,
      u .. "'s saved position survived the Reset position button")
  end
end)

test("the Reset position button and /at resetposition run the SAME shared helper", function()
  -- Helpers.RestoreAllDefaults's own comment records that the panel and the CLI diverged on
  -- exactly this once and were unified. Assert the delegation, not just the outcome, so a future
  -- re-inlined loop is caught even if it happens to behave identically on the day it lands.
  T.mocks.__subcategories["General"]:__fire("OnShow")
  local btn = aceGUIButton("Reset position")
  local real, calls = NS.Helpers.ResetAllPositions, 0
  NS.Helpers.ResetAllPositions = function() calls = calls + 1; return real() end

  btn:__fire("OnClick")
  assertEqual(calls, 1, "the panel button must delegate to Helpers.ResetAllPositions")
  NS.Slash:OnSlash("resetposition")
  assertEqual(calls, 2, "and so must the slash verb")

  NS.Helpers.ResetAllPositions = real
end)

-- ── The chrome block registers a refresher ────────────────────────────────────

-- The mirror checkbox and the "Copy styling from Player" button are built inline by
-- RenderUnitPanel, not through RenderField, so neither used to append anything to ctx.refreshers:
-- RefreshAllPanels structurally could not update them, and nothing re-ran the mirrored/unmirrored
-- row partition. The panel then lied exactly once (it self-corrects on the next OnShow).
--
-- The checkbox is read out of the chrome block and the rows out of the scroll, which is the split
-- options-ui-§14 draws: page-wide controls in the band, the tab's own rows below it.
local function mirrorHeaderState(ctx)
  local cb = chromeLabel(ctx, "Use same styling as Player")
  local hasAppearanceRows = false
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText == "Bar Width (in px)" then hasAppearanceRows = true end
      walk(child)
    end
  end
  walk(ctx.scroll)
  return cb and cb.value, hasAppearanceRows
end

test("a page refresh re-syncs the mirror checkbox and re-runs the row partition", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local checked, hasRows = mirrorHeaderState(ctx)
  assertFalse(checked, "an unlinked unit's block checkbox starts unticked")
  assertTrue(hasRows, "and its appearance rows are on screen")

  -- Exactly what the page Defaults button does: reset every row (which puts units.focus.mirror
  -- back to its default `true`), then run the refreshers.
  NS.Helpers.RestoreDefaults("appearance", ctx)
  assertEqual(NS.db.profile.units.focus.mirror, true, "the reset really did re-mirror the unit")

  checked, hasRows = mirrorHeaderState(ctx)
  assertTrue(checked, "the block's checkbox must re-read the restored mirror flag")
  assertFalse(hasRows,
    "and the appearance rows must be partitioned back off a now-mirrored unit")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("`/at set units.<unit>.mirror` re-syncs an open panel's mirror checkbox", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  assertTrue(select(2, mirrorHeaderState(ctx)), "precondition: the appearance rows are visible")

  NS.Slash:OnSlash("set units.focus.mirror true")

  local checked, hasRows = mirrorHeaderState(ctx)
  assertTrue(checked, "the CLI write must be reflected in the open panel's block checkbox")
  assertFalse(hasRows, "and the now-mirrored unit's appearance rows must disappear")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("the block's refresher cannot recurse: a refresh fired mid-render is a no-op", function()
  -- The block's refresher re-renders the panel, and a render registers a fresh header refresher.
  -- ctx.__rendering is what stops that from being a cycle; prove it holds rather than trusting it.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  local before = #ctx.refreshers
  ctx.__rendering = true
  NS.Helpers.RenderUnitPanel(ctx, "appearance")   -- must return immediately, registering nothing
  assertEqual(#ctx.refreshers, before, "a re-entrant render must not append another refresher")
  ctx.__rendering = false
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("a raise mid-render must not latch the re-entrancy flag for the session", function()
  -- ctx.__rendering is set on the way in. Cleared only on the normal exit path, ANY raise inside
  -- the render -- a widget error, a malformed schema row, a nil NS.Units.LABEL entry -- leaves it
  -- latched, and every later render (dropdown switch, mirror toggle, refresher, re-OnShow) returns
  -- silently at the guard. The page then looks frozen with no error after the first, and only
  -- /reload recovers it.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx

  -- The strip, NOT a widget inside the chrome block: H.PageHeader pcalls its builder, so a raise
  -- in there is contained before it ever reaches the body and could not redden this. The seams the
  -- OUTER pcall owns are the ones the body calls directly, and TabStrip is one of them.
  local savedStrip = Helpers.TabStrip
  Helpers.TabStrip = function() error("planted render failure") end
  local ok = pcall(NS.Helpers.RenderUnitPanel, ctx, "appearance")
  Helpers.TabStrip = savedStrip

  assertTrue(ok, "a failed render must be contained, not thrown at the caller")
  assertFalse(ctx.__rendering, "the flag must clear on the failure path too")

  -- The claim that actually matters: the page still renders after a failed one.
  local before = #NS.AceGUI.__created
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  assertTrue(#NS.AceGUI.__created > before,
    "the render after a failed one must actually rebuild the page, not return at the guard")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("a failed unit-panel render is reported in chat, never swallowed", function()
  -- Containing the raise must not trade a session-killing latch for a silent one: the user has to
  -- be told the page did not draw, and told why.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx

  local out = {}
  local cf  = T.mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end

  -- Planted on a seam the body calls directly, for the reason the re-entrancy case above gives:
  -- a raise inside the chrome block belongs to H.PageHeader's own pcall and its own report.
  local savedStrip = Helpers.TabStrip
  Helpers.TabStrip = function() error("planted render failure") end
  pcall(NS.Helpers.RenderUnitPanel, ctx, "appearance")
  Helpers.TabStrip = savedStrip
  cf.AddMessage = old

  local joined = table.concat(out, "\n")
  assertTrue(joined:find("planted render failure", 1, true) ~= nil,
    "the render failure must reach the user, with its cause: " .. joined)

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("an ordinary schema write does NOT re-render the whole unit page", function()
  -- The library's schema `set` calls RefreshAllPanels after EVERY schema write, so the header
  -- refresher runs on every checkbox click, slider drag and LSM pick on this page. It must only
  -- re-render when the mirror state actually changed: an unconditional re-render has ClearScroll
  -- release the very widget whose OnValueChanged is still on the stack (an LSM dropdown with an
  -- open pullout, a slider mid-drag), and takes scroll position and tooltips with it.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  -- The Bar tab, not whichever tab the page happened to open on: "Use class color" is the write
  -- being simulated and it only exists on a color tab.
  ctx.activeTab = "Bar"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local target
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText == "Use class color" and not target then target = child end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertTrue(target ~= nil, "no Use class color checkbox on the unlinked focus page's Bar tab")

  local widgetsBefore = #NS.AceGUI.__created
  local firstChild    = ctx.scroll.children[1]
  target:__fire("OnValueChanged", true)

  assertEqual(#NS.AceGUI.__created, widgetsBefore,
    "an appearance write must create no widgets -- the page must not be torn down and rebuilt")
  assertEqual(ctx.scroll.children[1], firstChild,
    "the live widgets must survive the write, not be released under their own callback")

  NS.SetByPath("units.focus.useClassColorBar", false)
  NS.db.profile.units.focus.mirror = true
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("a mirror-state change DOES re-render -- the two-tier refresher keeps both halves", function()
  -- The companion to the test above: prove the cheap path did not cost us the re-render. Counts
  -- widget creations rather than only inspecting labels, so "it re-partitioned" is measured at the
  -- same seam the no-re-render test measures.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local widgetsBefore = #NS.AceGUI.__created
  NS.SetByPath("units.focus.mirror", true)
  NS.Helpers.RefreshAllPanels()

  assertTrue(#NS.AceGUI.__created > widgetsBefore,
    "flipping the mirror must rebuild the page so the row partition re-runs")
  local checked, hasRows = mirrorHeaderState(ctx)
  assertTrue(checked, "and the block's checkbox follows the new mirror state")
  assertFalse(hasRows, "and the mirrored unit's appearance rows are gone")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("/at resetposition does not claim success when the settings helpers are absent", function()
  -- Same silent-lie shape as the Reset Position no-op: the acknowledgment must live inside the
  -- guard, not after it.
  local real = NS.Helpers.ResetAllPositions
  NS.Helpers.ResetAllPositions = nil
  local out = {}
  local cf  = T.mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(function() NS.Slash:OnSlash("resetposition") end)
  cf.AddMessage = old
  NS.Helpers.ResetAllPositions = real
  if not ok then error(err) end

  local joined = table.concat(out, "\n")
  assertTrue(joined:find("Bar positions reset", 1, true) == nil,
    "it must not report success it did not achieve: " .. joined)
  assertTrue(joined:find("Cannot reset positions", 1, true) ~= nil,
    "and it must say what went wrong: " .. joined)
end)

-- -- the `L` trap -----------------------------------------------------------------------------

test("the Defaults button the library renders is prose, not its own STRINGS key", function()
  -- LibKa0s-Options-1.0 takes NO `L` override (its `L` is lib.LAYOUT, a geometry table), so no
  -- descriptor mutation can redden this — see tests/test_ltrap.lua's header for why that is
  -- recorded rather than faked. What it does pin is the one library-owned string this addon puts
  -- on screen through Options: EnsureDefaultsButton sets lib.STRINGS.DEFAULTS_LABEL on the widget,
  -- and this reads it back off the built button.
  local ctx = Helpers.CreatePanel("ATTestPanelLTrap", "Test L", { defaultsButton = true })
  Helpers.EnsureDefaultsButton(ctx.panel)
  local btn = ctx.panel.defaultsBtn
  assertTrue(btn ~= nil, "the Defaults button must have been built")
  local text = btn.text
  assertTrue(type(text) == "string" and text ~= "", "the Defaults button must render a label")
  assertNil(text:match("^[A-Z][A-Z0-9_]+$"),
    "the Defaults button resolved to prose, not to its own key (got '" .. text .. "')")
  -- Non-vacuity: the assertion above is only worth something if this string really is the
  -- library's, so pin the coupling rather than the literal "Defaults".
  local lib = T.mocks.LibStub("LibKa0s-Options-1.0", true)
  assertEqual(text, lib.STRINGS.DEFAULTS_LABEL,
    "the rendered label must be the library's own string, not a host copy")
end)
