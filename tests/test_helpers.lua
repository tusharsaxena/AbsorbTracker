local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse

-- settings/Helpers.lua — the panel toolkit's non-AceGUI half: the CreatePanel factory + registry,
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
  local saved = NS.AceGUI
  NS.AceGUI = nil
  local ok = pcall(Helpers.EnsureDefaultsButton, ctx.panel)
  NS.AceGUI = saved
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
  local rows = NS.SchemaForPage("bar")
  assertTrue(#rows > 0, "the bar page has schema rows to reset")
  for _, row in ipairs(rows) do
    if row.type == "number" then NS.SetSetting(row.path, (row.default or 0) + 1) end
  end
  Helpers.RestoreDefaults("bar")
  for _, row in ipairs(rows) do
    if row.type == "number" then
      assertEqual(NS.GetSetting(row.path), row.default, row.path .. " is back at its default")
    end
  end
end)

test("RestoreDefaults leaves other pages untouched", function()
  -- The per-panel Defaults button must be page-scoped; a stray global reset here would silently
  -- wipe settings the user never asked about.
  NS.SetSetting("borderSize", 20)
  Helpers.RestoreDefaults("bar")
  assertEqual(NS.GetSetting("borderSize"), 20, "a border-page value survives a bar-page reset")
  Helpers.RestoreDefaults("border")
end)

test("RestoreDefaults runs the ctx refreshers so open widgets re-read", function()
  local ctx = Helpers.CreatePanel("ATTestPanelI", "Test I", { pageKey = "bar" })
  local ran = 0
  ctx.refreshers[1] = function() ran = ran + 1 end
  ctx.refreshers[2] = function() ran = ran + 1 end
  Helpers.RestoreDefaults("bar", ctx)
  assertEqual(ran, 2)
end)

test("RestoreDefaults survives a refresher that throws", function()
  -- Refreshers touch live AceGUI widgets; one dead widget must not abort the rest of the reset.
  local ctx = Helpers.CreatePanel("ATTestPanelJ", "Test J", { pageKey = "bar" })
  local ran = 0
  ctx.refreshers[1] = function() error("boom") end
  ctx.refreshers[2] = function() ran = ran + 1 end
  assertTrue(pcall(Helpers.RestoreDefaults, "bar", ctx), "RestoreDefaults must not propagate")
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

test("RestoreAllDefaults clears the saved bar position so the bar recentres", function()
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

-- ── Per-unit panel: Unit dropdown + mirror header ──────────────────────────────────

-- Reach the real Bar page canvas the harness built, then drive its OnShow.
local function barPanel()
  return T.mocks.__subcategories["Bar"]
end

test("the Bar page opens on the player unit with no mirror header", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  assertEqual(ctx.unit, "player")
end)

test("RenderUnitPanel draws a Unit dropdown listing all three units", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  local dd
  for _, child in ipairs(ctx.scroll.children) do
    if child.type == "Dropdown" and child.labelText == "Unit" then dd = child break end
  end
  assertTrue(dd ~= nil, "no Unit dropdown was rendered")
  assertEqual(#dd.order, 3)
  assertEqual(dd.order[1], "player")
  assertEqual(dd.value, "player")
end)

test("switching the dropdown to focus re-renders the page for that unit", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  local dd
  for _, child in ipairs(ctx.scroll.children) do
    if child.type == "Dropdown" and child.labelText == "Unit" then dd = child break end
  end

  -- The mirror checkbox only exists for target/focus, never for player (RenderUnitPanel gates it
  -- behind `if ctx.unit ~= "player"`). So its presence/absence is a proxy for "did the scroll
  -- actually get rebuilt for the new unit" — asserting only ctx.unit would pass even if the
  -- OnValueChanged callback dropped its RenderUnitPanel call and merely reassigned the field.
  local function hasMirrorCheckbox()
    local found = false
    local function walk(w)
      for _, child in ipairs(w.children or {}) do
        if child.labelText == "Use same styling as Player" then found = true end
        walk(child)
      end
    end
    walk(ctx.scroll)
    return found
  end
  assertTrue(not hasMirrorCheckbox(), "the player page has no mirror header before the switch")

  dd:__fire("OnValueChanged", "focus")
  assertEqual(ctx.unit, "focus")
  assertTrue(hasMirrorCheckbox(),
    "switching to focus must actually re-render the page, not just flip ctx.unit")

  NS.Helpers.RenderUnitPanel(ctx, "bar")   -- restore to a known state for later tests
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("a mirrored unit shows only its header, no appearance rows", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = true
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "bar")

  local labels = {}
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText then labels[child.labelText] = true end
      walk(child)
    end
  end
  walk(ctx.scroll)

  assertTrue(labels["Use same styling as Player"], "the mirror checkbox is the header")
  assertTrue(not labels["Bar Width (in px)"], "mirrored appearance rows must be hidden")
  -- The enable toggle moved to General's Master controls; the mirror flag is the only per-unit
  -- row left on this page and it renders in the header, not the body.
  assertTrue(not labels["Enable this bar"], "the enable toggle no longer lives on the Bar page")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("unchecking the mirror reveals the appearance rows", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "bar")

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
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("the copy button snapshots the player's styling and clears the mirror", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.player.barWidth = 288
  NS.db.profile.units.target.mirror = true
  ctx.unit = "target"
  NS.Helpers.RenderUnitPanel(ctx, "bar")

  local btn
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.type == "Button" and child.text == "Copy styling from Player" then btn = child end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertTrue(btn ~= nil, "no copy button was rendered")
  btn:__fire("OnClick")

  assertEqual(NS.db.profile.units.target.mirror, false)
  assertEqual(NS.db.profile.units.target.barWidth, 288)

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("a page Defaults button resets that page across every unit", function()
  NS.db.profile.units.player.barWidth = 111
  NS.db.profile.units.target.barWidth = 222
  NS.db.profile.units.focus.barWidth  = 333
  NS.Helpers.RestoreDefaults("bar")
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

test("the mirror checkbox renders exactly once — the header owns it, RenderRows must skip it",
  function()
  -- RenderRows is handed BOTH perUnitRows (which includes the alwaysPerUnit+skipRender mirror
  -- row) and styledRows. If it ignored `row.skipRender`, the mirror row would render a second,
  -- bespoke CheckBox down in the body with the same label as the header's — a set-membership
  -- check (labels[x] = true) cannot see that duplicate, so this counts occurrences instead.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "bar")

  local count = 0
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText == "Use same styling as Player" then count = count + 1 end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertEqual(count, 1,
    "the mirror checkbox must appear exactly once (the header), never a second time from the body")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
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
  NS.Helpers.RenderUnitPanel(ctx, "bar")
  local firstCount = #ctx.refreshers
  assertTrue(firstCount > 0, "the render registered at least one refresher")

  NS.Helpers.RenderUnitPanel(ctx, "bar")
  NS.Helpers.RenderUnitPanel(ctx, "bar")
  NS.Helpers.RenderUnitPanel(ctx, "bar")

  assertEqual(#ctx.refreshers, firstCount,
    "re-rendering the SAME unit repeatedly must not grow ctx.refreshers")

  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")

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

test("the General page's Reset Position button clears EVERY unit's saved position", function()
  T.mocks.__subcategories["General"]:__fire("OnShow")
  local btn = aceGUIButton("Reset Position")
  assertTrue(btn ~= nil, "no Reset Position button was rendered on the General page")

  for _, u in ipairs(NS.Units.LIST) do
    NS.Units.SetPosition(u, { point = "TOP", relPoint = "TOP", x = 7, y = 7 })
  end
  btn:__fire("OnClick")
  for _, u in ipairs(NS.Units.LIST) do
    assertEqual(NS.Units.Position(u), nil,
      u .. "'s saved position survived the Reset Position button")
  end
end)

test("the Reset Position button and /at resetposition run the SAME shared helper", function()
  -- Helpers.RestoreAllDefaults's own comment records that the panel and the CLI diverged on
  -- exactly this once and were unified. Assert the delegation, not just the outcome, so a future
  -- re-inlined loop is caught even if it happens to behave identically on the day it lands.
  T.mocks.__subcategories["General"]:__fire("OnShow")
  local btn = aceGUIButton("Reset Position")
  local real, calls = NS.Helpers.ResetAllPositions, 0
  NS.Helpers.ResetAllPositions = function() calls = calls + 1; return real() end

  btn:__fire("OnClick")
  assertEqual(calls, 1, "the panel button must delegate to Helpers.ResetAllPositions")
  NS.Slash:OnSlash("resetposition")
  assertEqual(calls, 2, "and so must the slash verb")

  NS.Helpers.ResetAllPositions = real
end)

-- ── The mirror header registers a refresher ────────────────────────────────────

-- The mirror checkbox and the "Copy styling from Player" button are built inline by
-- RenderUnitPanel, not through RenderField, so neither used to append anything to ctx.refreshers:
-- RefreshAllPanels structurally could not update them, and nothing re-ran the mirrored/unmirrored
-- row partition. The panel then lied exactly once (it self-corrects on the next OnShow).
local function mirrorHeaderState(ctx)
  local checked, hasAppearanceRows = nil, false
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText == "Use same styling as Player" then checked = child.value end
      if child.labelText == "Bar Width (in px)" then hasAppearanceRows = true end
      walk(child)
    end
  end
  walk(ctx.scroll)
  return checked, hasAppearanceRows
end

test("a page refresh re-syncs the mirror checkbox and re-runs the row partition", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "bar")

  local checked, hasRows = mirrorHeaderState(ctx)
  assertFalse(checked, "an unlinked unit's header checkbox starts unticked")
  assertTrue(hasRows, "and its appearance rows are on screen")

  -- Exactly what the page Defaults button does: reset every row (which puts units.focus.mirror
  -- back to its default `true`), then run the refreshers.
  NS.Helpers.RestoreDefaults("bar", ctx)
  assertEqual(NS.db.profile.units.focus.mirror, true, "the reset really did re-mirror the unit")

  checked, hasRows = mirrorHeaderState(ctx)
  assertTrue(checked, "the header checkbox must re-read the restored mirror flag")
  assertFalse(hasRows,
    "and the appearance rows must be partitioned back off a now-mirrored unit")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("`/at set units.<unit>.mirror` re-syncs an open panel's mirror header", function()
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
  assertTrue(select(2, mirrorHeaderState(ctx)), "precondition: the appearance rows are visible")

  NS.Slash:OnSlash("set units.focus.mirror true")

  local checked, hasRows = mirrorHeaderState(ctx)
  assertTrue(checked, "the CLI write must be reflected in the open panel's header checkbox")
  assertFalse(hasRows, "and the now-mirrored unit's appearance rows must disappear")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("the header refresher cannot recurse: a refresh fired mid-render is a no-op", function()
  -- The header refresher re-renders the panel, and a render registers a fresh header refresher.
  -- ctx.__rendering is what stops that from being a cycle; prove it holds rather than trusting it.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  local before = #ctx.refreshers
  ctx.__rendering = true
  NS.Helpers.RenderUnitPanel(ctx, "bar")   -- must return immediately, registering nothing
  assertEqual(#ctx.refreshers, before, "a re-entrant render must not append another refresher")
  ctx.__rendering = false
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("an ordinary schema write does NOT re-render the whole unit page", function()
  -- settings/Widgets.lua's `set` calls RefreshAllPanels after EVERY schema write, so the header
  -- refresher runs on every checkbox click, slider drag and LSM pick on this page. It must only
  -- re-render when the mirror state actually changed: an unconditional re-render has ClearScroll
  -- release the very widget whose OnValueChanged is still on the stack (an LSM dropdown with an
  -- open pullout, a slider mid-drag), and takes scroll position and tooltips with it.
  local panel = barPanel()
  panel:__fire("OnShow")
  local ctx = NS.Helpers.__lastUnitCtx
  NS.db.profile.units.focus.mirror = false
  ctx.unit = "focus"
  NS.Helpers.RenderUnitPanel(ctx, "bar")

  local target
  local function walk(w)
    for _, child in ipairs(w.children or {}) do
      if child.labelText == "Use Class Color" and not target then target = child end
      walk(child)
    end
  end
  walk(ctx.scroll)
  assertTrue(target ~= nil, "no Use Class Color checkbox on the unlinked focus page")

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
  NS.Helpers.RenderUnitPanel(ctx, "bar")
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
  NS.Helpers.RenderUnitPanel(ctx, "bar")

  local widgetsBefore = #NS.AceGUI.__created
  NS.SetByPath("units.focus.mirror", true)
  NS.Helpers.RefreshAllPanels()

  assertTrue(#NS.AceGUI.__created > widgetsBefore,
    "flipping the mirror must rebuild the page so the row partition re-runs")
  local checked, hasRows = mirrorHeaderState(ctx)
  assertTrue(checked, "and the header checkbox follows the new mirror state")
  assertFalse(hasRows, "and the mirrored unit's appearance rows are gone")

  ctx.unit = "player"
  NS.Helpers.RenderUnitPanel(ctx, "bar")
end)

test("/at resetposition does not claim success when the settings helpers are absent", function()
  -- Same silent-lie shape as the Reset Position no-op: the acknowledgement must live inside the
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
