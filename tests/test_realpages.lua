local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The real settings pages, driven through their deferred OnShow: the registered subcategories, the
-- Profiles page's self-skip, the combat cover on the sidebar path, the Defaults button, the General
-- and Appearance tab strips, every page's first show and the About page.
--
-- Peeled out of tests/test_widgets.lua, which reached two of the three release runs anti-pattern #53
-- allows in the layout-§1 band. The cases moved verbatim and in their original order, and the
-- runner loads this file straight after test_widgets, so they meet the state they always met.

local Helpers = NS.Helpers

-- ── The real pages, driven through their deferred OnShow ───────────────────────────

test("every schema page registered a real Blizzard subcategory at build time", function()
  for _, name in ipairs({ "General", "Appearance" }) do
    assertTrue(T.mocks.__subcategories[name] ~= nil, name .. " page was registered")
  end
end)

test("the Profiles page self-skips when AceDBOptions is unavailable", function()
  -- It is an optional dependency; the page must opt out silently rather than erroring the build.
  assertEqual(T.mocks.__subcategories["Profiles"], nil)
end)

test("the sidebar path is covered in combat, draws nothing and leaves the window open (options-ui-§2)", function()
  -- CX03. The Blizzard AddOns sidebar hands a canvas frame its OnShow directly -- it never goes
  -- through NS.OpenOptionsPanel -- so a page that parks its own OnShow has no guard at all on the
  -- path a player is most likely to take mid-pull. Every page here declares its body through
  -- Helpers.SetRenderer instead, and the combat lock is the library's (LibKa0s v1.46.1, standard
  -- v2.60.0, options-ui-§2/§13, anti-pattern #88): the page is NOT closed any more; it is covered,
  -- draws nothing, and one gray notice is printed per combat. Writes, Defaults and tab switches are
  -- refused until PLAYER_REGEN_ENABLED, which draws the page from current state.
  --
  -- The cover is asserted rather than "nothing rendered" alone, and deliberately: the Appearance
  -- page has already been shown (tests/test_panelpages.lua runs first and drives it), so a no-render
  -- assertion could pass with no lock present at all. A shown ctx.__combatCover is a claim only the
  -- library's lock can satisfy.
  --
  -- red under: giving either page back a ctx.panel:SetScript("OnShow", ...) of its own.
  -- Profiles is the third page on SetRenderer and cannot be driven here -- AceDBOptions is absent
  -- in the harness, so it self-skips and registers no subcategory (the case above pins that).
  -- docs/smoke-tests.md COMBAT-4 walks all three in the client.
  local lib = T.mocks.LibStub("LibKa0s-Options-1.0")
  local savedICL = T.mocks.InCombatLockdown
  T.mocks.InCombatLockdown = function() return true end

  local out = {}
  local cf  = T.mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end

  local closedBefore = T.mocks.__settingsClosed
  local savedHide, hideCalls = rawget(_G, "HideUIPanel"), 0
  rawset(_G, "HideUIPanel", function() hideCalls = hideCalls + 1 end)

  local pages, childCounts = {}, {}
  local ok, err = pcall(function()
    -- Shown the way the client shows one: on screen first, then OnShow (the mock's Show fires none).
    for _, name in ipairs({ "General", "Appearance" }) do
      T.mocks.__subcategories[name]:Show()
      T.mocks.__subcategories[name]:__fire("OnShow")
    end
    for ctx in pairs(lib.__shownPages) do
      for _, name in ipairs({ "General", "Appearance" }) do
        if ctx.panel == T.mocks.__subcategories[name] then pages[name] = ctx end
      end
    end
    -- A second show inside the SAME combat: still covered, still nothing drawn, no second line.
    for name, ctx in pairs(pages) do
      childCounts[name] = ctx.scroll and #ctx.scroll.children or 0
    end
    for _, name in ipairs({ "General", "Appearance" }) do
      T.mocks.__subcategories[name]:__fire("OnShow")
    end
  end)

  cf.AddMessage = old
  T.mocks.InCombatLockdown = savedICL
  rawset(_G, "HideUIPanel", savedHide)
  assertTrue(ok, tostring(err))

  assertEqual(T.mocks.__settingsClosed, closedBefore, "the Settings window is NOT closed any more")
  assertEqual(hideCalls, 0, "and no HideUIPanel either")
  for _, name in ipairs({ "General", "Appearance" }) do
    local ctx = pages[name]
    assertTrue(ctx ~= nil, name .. " is an on-screen page the library watches combat for")
    assertTrue(ctx.__combatCover ~= nil and ctx.__combatCover:IsShown(),
      name .. " is covered for the rest of the combat")
    assertEqual(ctx.scroll and #ctx.scroll.children or 0, childCounts[name],
      name .. " drew nothing on a show in combat")
  end
  local joined = table.concat(out, "\n")
  local _, hits = joined:gsub("settings are locked during combat", "")
  assertEqual(hits, 1, "one gray notice per combat, in the library's wording: " .. joined)
  assertTrue(joined:find(lib.STRINGS.COMBAT_LOCKED_NOTICE, 1, true) ~= nil,
    "and it is exactly COMBAT_LOCKED_NOTICE, gray (|cffaaaaaa)")

  -- Back off screen, so the suites after this one do not inherit the library's combat watch.
  for _, ctx in pairs(pages) do
    ctx.panel:Hide()
    ctx.panel:__fire("OnHide")
  end
end)

test("first OnShow builds the Defaults button and renders the page", function()
  local panel = T.mocks.__subcategories["Appearance"]
  panel:__fire("OnShow")
  assertTrue(panel.defaultsBtn ~= nil, "the button is built late, after skinners have loaded")
  assertEqual(panel.defaultsBtn.text, "Defaults")
  assertTrue(panel.defaultsBtn.callbacks.OnClick ~= nil, "the parked click handler got wired")
end)

test("the Defaults button restores just its own page", function()
  -- Retargeted: Font and Bar are TABS on one page now, so the Appearance Defaults button resets
  -- both — which is what a page-scoped button is supposed to do, and is why the General page is the
  -- other half of this assertion rather than a sibling appearance page.
  local panel = T.mocks.__subcategories["Appearance"]
  panel:__fire("OnShow")
  T.rawSet("units.player.fontSize", 30)
  T.rawSet("units.player.barWidth", 250)
  T.rawSet("throttleWindow", 0.85)
  panel.defaultsBtn.callbacks.OnClick(panel.defaultsBtn, "OnClick")
  assertEqual(NS.GetSetting("units.player.fontSize"), NS.unitDefaults.fontSize,
    "the Text tab was reset")
  assertEqual(NS.GetSetting("units.player.barWidth"), NS.unitDefaults.barWidth,
    "and so was the Size tab, on the same page")
  assertEqual(NS.GetSetting("throttleWindow"), 0.85, "the General page was not")
  NS.SetByPath("throttleWindow", NS.flatDefaults.throttleWindow)
  T.mocks.__fireTimers()
end)

test("a second OnShow rebuilds the panel body without stacking duplicate widgets", function()
  -- The Appearance page has no `rendered` one-shot guard, because RenderUnitPanel must re-render
  -- on every OnShow so the chrome block and the tab strip reflect ctx.unit. That is only safe
  -- because Helpers.ClearScroll releases the old widgets first — so a second OnShow must land back
  -- at the SAME child count, not a second full set stacked on top of the first.
  -- The Defaults button is unaffected: EnsureDefaultsButton still only builds it once.
  local panel = T.mocks.__subcategories["Appearance"]
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

-- The rendered ctx of a real page. `__panels()` also holds every throwaway panel this suite has
-- created, several of which share a pageKey with a real one -- so "has a scroll" is the half of the
-- match that says this one actually rendered.
local function renderedCtx(pageKey)
  for _, c in ipairs(Helpers.__panels()) do
    if c.pageKey == pageKey and c.scroll then return c end
  end
end

local function tabButtons(ctx)
  local out = {}
  for _, f in ipairs(ctx.__tabKids or {}) do
    if f.__frameType == "Button" then out[#out + 1] = f end
  end
  return out
end

test("the General page draws its groups as a tab strip, Master controls first, Skin last", function()
  -- options-ui-§13 adoption, on the page a player opens first. The mock records nothing about a
  -- Button's text, so the tabs are identified by POSITION and by which one is disabled -- makeTab
  -- disables exactly the active tab, which is how Blizzard's own tab groups mark selection.
  local panel = T.mocks.__subcategories["General"]
  panel:__fire("OnShow")
  local ctx = renderedCtx("general")
  assertTrue(ctx ~= nil, "the General page rendered")

  local tabs = tabButtons(ctx)
  -- Master controls, Behavior and the library's Skin tab (AT-01), which takes the "Appearance"
  -- group's place and lands last on a page with no Keybindings tab (skinning-§3).
  assertEqual(#tabs, 3, "two groups and the Skin tab, three tabs")
  assertEqual(ctx.activeTab, "Master controls",
    "options-ui-§15: the General page opens on Master controls, and it is the FIRST tab")
  assertFalse(tabs[1].__enabled, "the first tab is the selected one")
  assertTrue(tabs[2].__enabled, "and the second is clickable")
  assertTrue(tabs[3].__enabled, "and the third, the Skin tab")
  -- Only that the band is reserved. The strip is library-drawn (O.TabStrip, reached here through
  -- O.RenderTabbedSchema), so the wrap-invariance pin -- the reserved band and every row's y offset
  -- identical for every tab selection of a wrapped strip -- is LibKa0s's own suite's and is not
  -- duplicated here (options-ui-§13 Testing, testing-§8).
  assertTrue(ctx.chromeHeight > 0, "the strip reserves a band, so the first row clears it")

  local labels = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText then labels[child.labelText] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertTrue(labels["Enable Absorb Tracker"], "the Master controls tab shows its own rows")
  assertTrue(not labels["Update throttle (seconds)"], "and not the other tab's")

  -- No section headings: a `group` is the tab now, and RenderTabbedSchema passes `noHeadings`
  -- down. A Heading under a strip means the page silently fell back to RenderSchema.
  for _, child in ipairs(ctx.scroll.children) do
    assertTrue(child.type ~= "Heading", "a tabbed page draws no section headings")
  end
end)

test("clicking Behavior swaps the rows and leaves the button pair on Master controls", function()
  local panel = T.mocks.__subcategories["General"]
  panel:__fire("OnShow")
  local ctx = renderedCtx("general")
  tabButtons(ctx)[2]:__fire("OnClick")
  assertEqual(ctx.activeTab, "Behavior")

  local labels = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText then labels[child.labelText] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertTrue(labels["Update throttle (seconds)"], "the Behavior tab's row is on screen")
  assertTrue(not labels["Enable this unit"],
    "and its skipRender enables are not: the Appearance band draws those")
  assertTrue(not labels["Enable Absorb Tracker"],
    "and the tab it came from is gone, not stacked above it")

  -- The afterGroup button pair is keyed to "Master controls", so it must NOT follow the reader
  -- here. That key is the GROUP NAME, which is why settings/General.lua reads H.MASTER_GROUP
  -- rather than spelling the literal a second time.
  local sawResetButton = false
  local function walkButtons(w)
    for _, child in ipairs(w.children or {}) do
      if child.type == "Button" and child.text == "Reset position" then sawResetButton = true end
      walkButtons(child)
    end
  end
  walkButtons(ctx.scroll)
  assertFalse(sawResetButton, "afterGroup fires for the ACTIVE group only")

  tabButtons(ctx)[1]:__fire("OnClick")   -- leave the page as the rest of the suite found it
  assertEqual(ctx.activeTab, "Master controls")
end)

-- ── The Appearance page's strip, pinned per unit and per tab (AT-15) ─────────────────────────
--
-- Written against the host composition settings/UnitPanel.lua carried until LibKa0s v1.66.0
-- (partitionTabs + H.TabStrip), when the library's partition made a tab of the mirror row's
-- `skipRender` "Link" group and its disabledFor drew the rows disabled under the notice. The page
-- now hands the body to H.RenderTabbedSchema with OptionsTabs minor 8's untabbedSkipRender,
-- disabledReplaces and rerender (GitHub issue #32), and these cases stayed green, untouched,
-- across that adoption: they are what the page draws, whoever composes it.

-- The group order the schema declares for a unit, read straight off the rows: the strip's
-- expected keys. `skipRender` rows name a subject and draw no tab.
local function appearanceGroups(unit)
  local order, labels = {}, {}
  for _, row in ipairs(NS.SchemaForPage("appearance", unit)) do
    if row.group and not row.skipRender then
      if not labels[row.group] then
        labels[row.group] = {}
        order[#order + 1] = row.group
      end
      if row.label then labels[row.group][row.label] = true end
    end
  end
  return order, labels
end

local function scrollLabels(ctx)
  local labels, texts = {}, {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText then labels[child.labelText] = true end
      if child.text then texts[child.text] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)
  return labels, texts
end

local MIRROR_HINT = "Linked to Player. Untick Link to Player above to give this unit its own look."

-- Render the Appearance page for `unit` with its mirror flag forced to `mirrored`, recording the
-- spec every H.TabStrip call is handed. Restores the flag, the unit and the page afterwards.
local function withAppearance(unit, mirrored, body)
  local panel = T.mocks.__subcategories["Appearance"]
  panel:__fire("OnShow")
  local ctx = Helpers.__lastUnitCtx
  local unitCfg = NS.db.profile.units[unit]
  local savedMirror = unitCfg.mirror
  if unit ~= "player" then unitCfg.mirror = mirrored end
  local realStrip, specs = Helpers.TabStrip, {}
  Helpers.TabStrip = function(c, spec, ...)
    specs[#specs + 1] = spec
    return realStrip(c, spec, ...)
  end
  ctx.unit, ctx.activeTab = unit, nil
  local ok, err = pcall(function()
    Helpers.RenderUnitPanel(ctx, "appearance")
    body(ctx, specs)
  end)
  Helpers.TabStrip = realStrip
  unitCfg.mirror = savedMirror
  ctx.unit, ctx.activeTab = "player", nil
  Helpers.RenderUnitPanel(ctx, "appearance")
  if not ok then error(err, 0) end
end

test("every unit's Appearance strip is its schema's groups, and each tab draws that group's rows", function()
  -- red under: a partition keeping an all-skipRender group as a tab (e.g. dropping
  -- untabbedSkipRender: a third "Link" tab on target and focus),
  -- or the tab click re-rendering the rows without retargeting them.
  for _, unit in ipairs(NS.Units.LIST) do
    withAppearance(unit, false, function(ctx, specs)
      local groups, rowLabels = appearanceGroups(unit)
      assertEqual(#groups, 2, unit .. ": Bar and Text")
      local keys = {}
      for i, tab in ipairs(specs[#specs].tabs) do keys[i] = tab.key end
      assertEqual(table.concat(keys, ","), table.concat(groups, ","),
        unit .. ": the strip's keys are the schema's groups, in declaration order")

      for i, group in ipairs(groups) do
        tabButtons(ctx)[i]:__fire("OnClick")
        assertEqual(ctx.activeTab, group, unit .. ": the click retargets the page")
        local shown = scrollLabels(ctx)
        -- This tab's rows are all on screen, and no other tab's is. Keyed by label, and a label
        -- can recur across groups ("Use class color" is on both tabs), so a row counts as another
        -- tab's only when this tab has no row of that label.
        for g, set in pairs(rowLabels) do
          for label in pairs(set) do
            local own = rowLabels[group][label] == true
            assertEqual(shown[label] == true, own,
              ("%s / %s: %s row %q is drawn only on its own tab"):format(unit, group, g, label))
          end
        end
        assertTrue(ctx.__bannerHeight and ctx.__bannerHeight > 0,
          unit .. " / " .. group .. ": the chrome block records its share of the band")
        assertTrue(ctx.chromeHeight >= ctx.__bannerHeight,
          unit .. " / " .. group .. ": the strip's reservation includes the block above it")
      end
    end)
  end
end)

test("a mirrored unit's every tab draws the hint and none of the appearance rows", function()
  -- red under: renderUnitPanelBody ignoring NS.Units.IsMirrored (the rows come back under the
  -- strip), or drawing the rows disabled under the hint as RenderTabbedSchema's disabledFor does.
  for _, unit in ipairs({ "target", "focus" }) do
    withAppearance(unit, true, function(ctx)
      local groups, rowLabels = appearanceGroups(unit)
      assertEqual(#tabButtons(ctx), #groups, unit .. ": the mirrored page keeps its whole strip")
      for i, group in ipairs(groups) do
        tabButtons(ctx)[i]:__fire("OnClick")
        local shown, texts = scrollLabels(ctx)
        assertTrue(texts[MIRROR_HINT], unit .. " / " .. group .. ": the hint is drawn")
        for g, set in pairs(rowLabels) do
          for label in pairs(set) do
            assertFalse(shown[label], ("%s / %s: %s row %q is not drawn"):format(unit, group, g, label))
          end
        end
        assertTrue(ctx.chromeHeight >= ctx.__bannerHeight and ctx.__bannerHeight > 0,
          unit .. " / " .. group .. ": the band still reserves the chrome block")
      end
    end)
  end
end)

test("showing every page builds it without error", function()
  for _, name in ipairs({ "General", "Appearance" }) do
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

test("re-rendering the About page replaces its body rather than stacking a second copy", function()
  -- The main page is re-rendered on every re-show after a refresh marked it dirty (a /at set, a
  -- profile change), so its renderer must clear the scroll first. The hand-rolled body this file
  -- used to carry did not, and the panel grew a second logo, description and command list per
  -- render. Driven through the renderer directly: OnShow short-circuits on a clean page, which is
  -- exactly why the bug survived the first-OnShow case above.
  local panel = T.mocks.__mainPanel
  local ctx
  for _, c in ipairs(NS.Helpers.__panels()) do
    if c.panel == panel then ctx = c end
  end
  assertTrue(ctx ~= nil, "the main canvas ctx is in the panel registry")

  NS.Helpers.BuildMainContent(ctx)
  local firstCount = #ctx.scroll.children
  assertTrue(firstCount > 0, "the About page rendered something")

  NS.Helpers.BuildMainContent(ctx)
  assertEqual(#ctx.scroll.children, firstCount,
    "the second render lands at the same child count, not a doubled/stacked set")
end)
