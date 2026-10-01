local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The settings pages as the harness's OnEnable built them, driven through their real canvases:
-- settings/UnitPanel.lua's per-unit Appearance page (the Unit picker, the chrome block, the mirror
-- controls, the tab strip and the two-tier refresher) and the General page's inline Reset position
-- button, with `/at resetposition` alongside it because both run Helpers.ResetAllPositions.
--
-- Peeled out of tests/test_helpers.lua when that file neared the layout-§1 cap (review finding
-- AbsorbTracker-R-14). The cases moved verbatim and in their original order, and the runner loads
-- this file straight after test_helpers, so the shared environment they see is unchanged. That
-- order is load-bearing: the first case below asserts the Appearance page has not rendered yet, so
-- nothing earlier in the run may fire its OnShow.

local Helpers = NS.Helpers

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

-- The strip the page owes: one tab per distinct `group` among the unit's DRAWN rows, in declaration
-- order. Derived here from the schema rather than read back from the page's own partition, so a
-- case comparing it with the buttons on screen compares two independent answers.
local function tabNames(ctx)
  local names, seen = {}, {}
  for _, row in ipairs(NS.SchemaForPage("appearance", ctx.unit)) do
    if row.group and not row.skipRender and not seen[row.group] then
      seen[row.group] = true
      names[#names + 1] = row.group
    end
  end
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
  -- The page hands RenderTabbedSchema a `rerender` (OptionsTabs minor 8), so a tab click re-runs
  -- the whole page render, block included, rather than the library's ClearScroll + rows-only
  -- redraw. The block is drawn once per render and its ledger replaced, never stacked.
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

test("a raise in the unit panel body is reported as one space-joined chat line", function()
  -- settings/UnitPanel.lua hands the printer the label and the raw error as two PARTS rather than a
  -- pre-formatted line (events-frames-taint-§8's SHOULD half); NS.Print SafeToStrings each part and
  -- joins them with one space, so the line is byte-identical to the old ("...: %s"):format.
  -- red under: a changed separator (the label passed with its own trailing space prints two).
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx

  local out = {}
  local cf  = T.mocks.DEFAULT_CHAT_FRAME
  local oldMsg = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local saved = NS.SchemaForPage
  NS.SchemaForPage = function() error("simulated body failure", 0) end
  local ok = pcall(NS.Helpers.RenderUnitPanel, ctx, "appearance")
  NS.SchemaForPage = saved
  cf.AddMessage = oldMsg

  assertTrue(ok, "RenderUnitPanel must not raise")
  local hit
  for _, line in ipairs(out) do
    if line:find("Unit panel render failed", 1, true) then hit = line end
  end
  assertTrue(hit ~= nil, "the failure must be reported: " .. table.concat(out, " / "))
  assertEqual(hit:match("Unit panel render failed.*$"), "Unit panel render failed: simulated body failure")
  assertTrue(hit:sub(-#"simulated body failure") == "simulated body failure", "nothing trails the error")

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

test("the mirrored hint is a full-width line followed by a ROW_VSPACER", function()
  -- What is left in the scroll for a mirrored unit: RenderTabbedSchema's disabled notice (a
  -- full-width Label, through TextRow) and the ROW_VSPACER the library adds under it, so the hint
  -- keeps the vertical rhythm of a schema row -- and nothing after them (disabledReplaces).
  -- AddSpacer builds a SimpleGroup with a fixed height, which is what tells the spacer apart.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = true
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  local kids = ctx.scroll.children
  assertEqual(kids[1].type, "Label", "the hint is a line of its own")
  assertEqual(kids[1].text, "Linked to Player \226\128\148 uncheck to customize.")
  assertEqual(kids[2].type, "SimpleGroup")
  assertEqual(kids[2].height, Helpers.ROW_VSPACER, "and it is followed by a ROW_VSPACER")
  assertEqual(kids[3], nil, "and nothing under it: the hint replaces the rows")

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
