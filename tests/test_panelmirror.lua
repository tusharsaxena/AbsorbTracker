local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- The Appearance page's mirror half, driven through its real canvas: the chrome block's refresher
-- (the mirror checkbox and the row partition following RestoreDefaults, `/at set` and
-- RefreshAllPanels), its re-entrancy guard and failure reporting, the two-tier refresher (a plain
-- schema write repaints nothing, a mirror flip rebuilds the page), the refresher surviving a tab
-- click, the Link group never becoming a tab, and the hidden page's lazy rebuild.
--
-- Peeled out of tests/test_panelpages.lua when that file entered the layout-§1 1000-1500 band. The
-- cases moved verbatim and in their original order, and the runner loads this file straight after
-- test_panelpages, so the Appearance page they reach is the one that file has already opened. The
-- few lookup helpers they share with test_panelpages are repeated below rather than exported,
-- because a suite file returns nothing the runner reads.

local Helpers = NS.Helpers

-- Reach the real Appearance page canvas the harness built, then drive its OnShow.
local function barPanel()
  return T.mocks.__subcategories["Appearance"]
end

-- The widgets in the page's ONE chrome block (options-ui-§14), in creation order. They are not in
-- the scroll and they are not the library's: RenderUnitPanel records them on ctx.__chromeWidgets.
local function chromeWidget(ctx, pred)
  for _, w in ipairs(ctx.__chromeWidgets or {}) do
    if pred(w) then return w end
  end
end

local function chromeLabel(ctx, label)
  return chromeWidget(ctx, function(w) return w.labelText == label end)
end

-- The strip's buttons, in tab order. ctx.__tabKids also holds the content panel TabStrip draws
-- under the tabs, which is a Frame rather than a Button, so it is filtered out.
local function tabButtons(ctx)
  local out = {}
  for _, f in ipairs(ctx.__tabKids or {}) do
    if f.__frameType == "Button" then out[#out + 1] = f end
  end
  return out
end

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
  -- SHOWN, and that is load-bearing rather than tidy-up. The page declares its body through
  -- Helpers.SetRenderer now (settings/Appearance.lua), and the library's refresh is two-tier: an
  -- on-screen ctx re-renders, a hidden one is flagged dirty and repaints on its next OnShow. A mock
  -- panel nobody ever showed takes the second branch, so "the open panel followed the CLI write"
  -- would be asserted against a page the library was entitled to leave alone. `open` is in this
  -- case's name; this is the line that makes it true.
  panel:Show()
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  assertTrue(select(2, mirrorHeaderState(ctx)), "precondition: the appearance rows are visible")

  NS.Slash:OnSlash("set units.focus.mirror true")

  local checked, hasRows = mirrorHeaderState(ctx)
  assertTrue(checked, "the CLI write must be reflected in the open panel's block checkbox")
  assertFalse(hasRows, "and the now-mirrored unit's appearance rows must disappear")

  panel:Hide()
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
  -- OUTER pcall owns are the ones the body reaches directly, and TabStrip is one of them (drawn
  -- by RenderTabbedSchema, which does not pcall it).
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

  -- SHOWN, so the scalar refresh the write fires actually reaches the refreshers. Hidden, the
  -- library would flag the ctx dirty and return, and this case would pass without the two-tier
  -- refresher it exists to hold honest ever running -- green for the wrong reason, which is the
  -- one outcome a regression case must never have.
  panel:Show()
  local widgetsBefore = #NS.AceGUI.__created
  local firstChild    = ctx.scroll.children[1]
  target:__fire("OnValueChanged", true)

  assertEqual(#NS.AceGUI.__created, widgetsBefore,
    "an appearance write must create no widgets -- the page must not be torn down and rebuilt")
  assertEqual(ctx.scroll.children[1], firstChild,
    "the live widgets must survive the write, not be released under their own callback")

  panel:Hide()
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

  -- Shown for the reason the `/at set` case above spells out: RefreshAllPanels only re-renders a
  -- ctx that is on screen, and a hidden one it merely flags dirty.
  panel:Show()
  local widgetsBefore = #NS.AceGUI.__created
  NS.SetByPath("units.focus.mirror", true)
  NS.Helpers.RefreshAllPanels()

  assertTrue(#NS.AceGUI.__created > widgetsBefore,
    "flipping the mirror must rebuild the page so the row partition re-runs")
  local checked, hasRows = mirrorHeaderState(ctx)
  assertTrue(checked, "and the block's checkbox follows the new mirror state")
  assertFalse(hasRows, "and the mirrored unit's appearance rows are gone")

  panel:Hide()
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

-- Every label and every text in the scroll, depth-first.
local function scrollContent(ctx)
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

test("after a tab click the two-tier refresher is still registered", function()
  -- AbsorbTracker#32. The page's block refresher is appended AFTER the body, and a tab click that
  -- cleared the scroll and redrew only the rows (RenderTabbedSchema's own click, without the
  -- minor-8 `rerender`) would reset ctx.refreshers and lose it: the checkbox and the row partition
  -- would stop following a mirror change made through the refreshers alone. RestoreDefaults is that
  -- path -- it resets units.focus.mirror to `true` and runs only the refreshers.
  -- red under: a tab click that does not re-run the whole page render.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit, ctx.activeTab = "focus", nil
  NS.Helpers.RenderUnitPanel(ctx, "appearance")

  tabButtons(ctx)[2]:__fire("OnClick")
  assertEqual(ctx.activeTab, "Bar", "the click retargets the page to the second tab")
  assertTrue((scrollContent(ctx))["Use class color"], "precondition: the Bar tab's rows are drawn")

  NS.Helpers.RestoreDefaults("appearance", ctx)
  assertEqual(NS.db.profile.units.focus.mirror, true, "the reset re-mirrored the unit")
  local labels, texts = scrollContent(ctx)
  assertTrue(chromeLabel(ctx, "Use same styling as Player").value,
    "the block's checkbox follows the reset after a tab click")
  assertFalse(labels["Use class color"], "the now-mirrored unit's rows are gone")
  assertTrue(texts["Linked to Player \226\128\148 uncheck to customize."], "and the hint replaces them")

  ctx.unit, ctx.activeTab = "player", nil
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)

test("the Link group never becomes a tab, mirrored or not", function()
  -- The mirror row is the Link group's only row and carries skipRender: its widget is the bespoke
  -- checkbox in the chrome block. A partition that kept skipRender rows would grow a sixth tab,
  -- "Link", holding nothing, on target and focus.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  local realStrip, keys = Helpers.TabStrip, nil
  Helpers.TabStrip = function(c, spec, ...)
    keys = {}
    for i, t in ipairs(spec.tabs) do keys[i] = t.key end
    return realStrip(c, spec, ...)
  end
  local ok, err = pcall(function()
    for _, unit in ipairs({ "target", "focus" }) do
      for _, mirrored in ipairs({ false, true }) do
        NS.db.profile.units[unit].mirror = mirrored
        ctx.unit, ctx.activeTab, keys = unit, nil, nil
        NS.Helpers.RenderUnitPanel(ctx, "appearance")
        local where = unit .. (mirrored and " (mirrored)" or "")
        assertTrue(keys ~= nil, where .. ": the strip was drawn")
        assertEqual(table.concat(keys, ","), "Size,Bar,Background,Border,Text",
          where .. ": five tabs, and Link is none of them")
      end
    end
  end)
  Helpers.TabStrip = realStrip
  NS.db.profile.units.target.mirror, NS.db.profile.units.focus.mirror = true, true
  ctx.unit, ctx.activeTab = "player", nil
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  if not ok then error(err, 0) end
end)

test("a hidden Appearance page is not rebuilt by a mirror flip; its next OnShow rebuilds it", function()
  -- AbsorbTracker#20 (review F-008), pinned. The two-tier refresher above re-renders the page on a
  -- mirror flip, and that rebuild is only worth paying for a page on screen. The page declares its
  -- body through Helpers.SetRenderer (settings/Appearance.lua), so the library's refresh gate marks
  -- a hidden ctx dirty and returns without running its refreshers; SetRenderer's OnShow repaints it
  -- later (options-ui-§11). Red under: the page dropping SetRenderer, which brings back the legacy
  -- path that runs every refresher of a page nobody can see.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  -- The Size tab, which holds the "Bar Width (in px)" row mirrorHeaderState looks for, rather than
  -- whichever tab an earlier case left active.
  ctx.activeTab = "Size"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
  assertTrue(select(2, mirrorHeaderState(ctx)), "precondition: the unlinked unit's rows are drawn")

  panel:Hide()
  local widgetsBefore = #NS.AceGUI.__created
  NS.SetByPath("units.focus.mirror", true)
  NS.Helpers.RefreshAllPanels()
  assertEqual(#NS.AceGUI.__created, widgetsBefore,
    "a hidden page must not be rebuilt by the mirror flip")
  assertTrue(ctx._dirty == true, "it is flagged dirty instead")

  panel:Show()
  panel:__fire("OnShow")
  assertTrue(#NS.AceGUI.__created > widgetsBefore, "the next OnShow rebuilds the page")
  local checked, hasRows = mirrorHeaderState(ctx)
  assertTrue(checked, "and the block's checkbox shows the flag written while it was hidden")
  assertFalse(hasRows, "and the now-mirrored unit's rows are gone")

  panel:Hide()
  NS.db.profile.units.focus.mirror = true
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "appearance")
end)
