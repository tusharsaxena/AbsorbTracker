-- tests/test_launcher.lua — the launcher: one object registered twice, the rung its left click
-- sits on, and the one boolean that decides whether the minimap button is there.
--
-- What is NOT tested here is the library's own wiring, which lives in the LibKa0s repo. What IS
-- tested is every seam that is this addon's: the descriptor core/LauncherSetup.lua hands over, the
-- rung it chose, the inversion core/Data.lua pays at the read/write seam, and the degradation arm
-- for an install missing LibKa0s, the two broker libraries, or both.
--
-- NEITHER BROKER LIBRARY IS LOADED BY THE HARNESS. `Loader.tocFiles` skips the whole `libs/` block
-- (tests/_kit/loader.lua), so the default state of this environment is the one a player gets with
-- LibDataBroker-1.1 and LibDBIcon-1.0 missing. The cases that need them register fakes into the
-- mock's own LibStub, which is also what lets them see exactly which calls the library made.

local T = _G.AT_TEST
local NS = T.NS
local test, assertEqual, assertTrue, assertFalse, assertNil =
  T.test, T.assertEqual, T.assertTrue, T.assertFalse, T.assertNil

local FOLDER = "AbsorbTracker"

-- ── the broker fakes ───────────────────────────────────────────────────────────────────────────
--
-- Registered through the mock's real NewLibrary rather than poked into a table, so the library's
-- own `LibStub(major, true)` at Register time is what finds them — the same lookup the client
-- makes. They record, and answer, and nothing else: a fake that also behaved would be a second
-- LibDBIcon nobody asked for.
local broker = {}

local function fakes()
  if broker.ldb then return broker end

  local ldb = T.mocks.LibStub:NewLibrary("LibDataBroker-1.1", 4)
  ldb.objects, ldb.created = {}, {}
  function ldb:NewDataObject(name, tbl)
    if self.objects[name] then return nil end   -- the real one answers nil for a taken name
    self.objects[name] = tbl
    self.created[#self.created + 1] = name
    return tbl
  end
  function ldb:GetDataObjectByName(name) return self.objects[name] end

  local icons = T.mocks.LibStub:NewLibrary("LibDBIcon-1.0", 45)
  icons.registered, icons.shown, icons.hidden = {}, {}, {}
  function icons:Register(name, obj, db)
    self.registered[#self.registered + 1] = { name = name, object = obj, db = db }
  end
  function icons:Show(name) self.shown[#self.shown + 1] = name end
  function icons:Hide(name) self.hidden[#self.hidden + 1] = name end

  broker.ldb, broker.icons = ldb, icons
  return broker
end

--- Run `fn` with NS.SetByPath spied on, and hand back every (path, value) pair it saw. The real
--- seam still runs: the point is to prove the click went THROUGH it, not to stop it.
local function seamCalls(fn)
  local real, seen = NS.SetByPath, {}
  NS.SetByPath = function(path, value)
    seen[#seen + 1] = { path = path, value = value }
    return real(path, value)
  end
  local ok, err = pcall(fn)
  NS.SetByPath = real
  assertTrue(ok, "the act raised: " .. tostring(err))
  return seen
end

-- ── one object, registered twice ───────────────────────────────────────────────────────────────

test("launcher: Register builds ONE broker object and hands that same object to LibDBIcon", function()
  -- launcher-§1, and the reason it is one object rather than two features: a minimap button and a
  -- Titan/ElvUI row are two DRAWINGS of one table. Two tables is anti-pattern #81 — they agree on
  -- the day they are written and drift on the first behavior change, and nothing reports it because
  -- both halves still work.
  --
  -- red under: a second data object; a broker object registered under one name and a button under
  -- another (LibDBIcon keys the saved POSITION by that name, so the spelling is not cosmetic); a
  -- `type` other than "launcher", which makes a display draw an empty value cell beside the icon
  -- forever; an icon that is not this addon's own file.
  local b = fakes()
  assertTrue(NS.Launcher:Register(), "Register must report the launcher fully wired")

  assertEqual(#b.ldb.created, 1, "exactly one LibDataBroker object")
  assertEqual(b.ldb.created[1], FOLDER, "the object is named for the addon FOLDER")
  assertEqual(#b.icons.registered, 1, "exactly one LibDBIcon registration")
  assertEqual(b.icons.registered[1].name, FOLDER, "both registrations use the SAME name")

  local object = NS.Launcher:Object()
  assertTrue(object ~= nil, "the object is published")
  assertTrue(b.icons.registered[1].object == object,
    "LibDBIcon must be handed the SAME object LibDataBroker holds, not a copy of it")
  assertEqual(object.type, "launcher", "a broker display reads `type` to decide what to draw")
  assertEqual(object.icon, NS.Constants.LOGO_ICON_PATH, "the icon is the addon's own logo")
  assertTrue(type(object.OnClick) == "function", "one OnClick, shared by both surfaces")
end)

test("launcher: LibDBIcon is handed db.global.minimap ITSELF, not a copy", function()
  -- The descriptor passes a FUNCTION, not a table, and this is the case that says why: a table
  -- captured at file load is a table AceDB later replaces, and the failure is silent — the button
  -- would simply forget its position every login, because LibDBIcon would be writing `minimapPos`
  -- into an orphan.
  --
  -- red under: `minimap = NS.db.global.minimap` in core/LauncherSetup.lua; a shallow copy; a table
  -- built fresh at Register time.
  local b = fakes()
  NS.Launcher:Register()
  assertTrue(b.icons.registered[1].db == NS.db.global.minimap,
    "the launcher must hand over the live global table, so LibDBIcon's writes and the settings "
      .. "row's writes land in one place")
end)

test("launcher: Register is idempotent", function()
  -- A host may call it from OnInitialize and again from a login handler, and a second
  -- LibDBIcon:Register on a name it already holds builds a second button over the first.
  local b = fakes()
  NS.Launcher:Register()
  local objects, buttons = #b.ldb.created, #b.icons.registered
  assertTrue(NS.Launcher:Register(), "a second call still reports wired")
  assertTrue(NS.Launcher:Register(), "and a third")
  assertEqual(#b.ldb.created, objects, "no second data object")
  assertEqual(#b.icons.registered, buttons, "no second minimap button")
  assertTrue(NS.Launcher:IsRegistered(), "IsRegistered agrees with Register")
end)

-- ── the rung ───────────────────────────────────────────────────────────────────────────────────

test("launcher: LEFT-click toggles the lock, through the seam the checkbox writes through", function()
  -- THE RUNG, and it is (b): launcher-§2 spends the left button on the addon's preview switch where
  -- it has one, and this addon's preview switch IS the lock (options-ui-§15's exemption — unlocking
  -- paints the placeholder and shows a target bar with nothing targeted). Rung (a) needs a primary
  -- window, which this addon does not have.
  --
  -- The assertion that matters is not "locked changed" but "it changed THROUGH NS.SetByPath". That
  -- is the seam the Lock frame checkbox, `/at lock`, `/at unlock` and the Defaults button all reach,
  -- and it is where the `locked` onChange lives — the in-combat unlock refusal, the preview clear
  -- and the repaint. A click that wrote `db.profile.locked` directly would flip the same boolean and
  -- silently skip all three.
  --
  -- red under: an onClick that writes the profile itself; an onClick that keeps its own `locked`
  -- upvalue; an onClick that opens the settings panel, which would be rung (c) and is the skipped
  -- rule launcher-§2 calls anti-pattern #81.
  fakes()
  NS.Launcher:Register()
  local object = NS.Launcher:Object()

  NS.SetByPath("locked", true)
  local seen = seamCalls(function() object.OnClick(object, "LeftButton") end)
  assertEqual(#seen, 1, "one write, not two")
  assertEqual(seen[1].path, "locked", "the left click writes the LOCK")
  assertEqual(seen[1].value, false)
  assertFalse(NS.GetSetting("locked"), "and the lock actually moved")

  seen = seamCalls(function() object.OnClick(object, "LeftButton") end)
  assertEqual(seen[1].value, true, "it toggles rather than setting one way")
  assertTrue(NS.GetSetting("locked"))
end)

test("launcher: RIGHT-click always opens the settings panel, and touches nothing else", function()
  -- True on every addon whatever its rung, which is what lets rungs (a) and (b) spend the left
  -- button on something better: the panel is never more than one click away.
  fakes()
  NS.Launcher:Register()
  local object = NS.Launcher:Object()

  NS.SetByPath("locked", true)
  local real, opened = NS.OpenOptionsPanel, 0
  NS.OpenOptionsPanel = function() opened = opened + 1 end
  local seen = seamCalls(function() object.OnClick(object, "RightButton") end)
  NS.OpenOptionsPanel = real

  assertEqual(opened, 1, "right-click opens the panel")
  assertEqual(#seen, 0, "and writes nothing")
  assertTrue(NS.GetSetting("locked"), "the lock is untouched by the right button")
end)

-- ── the icon ───────────────────────────────────────────────────────────────────────────────────

test("launcher: the icon file is the one the TOC names, and is a format the client can load", function()
  -- ANTI-PATTERN #82'S SUBTLER HALF. A wrong texture path draws nothing and raises nothing; so does
  -- a TGA in the wrong format. Neither would be reported by any other gate in this repo, and the
  -- result is the same either way — a launcher whose button is invisible, which is worse than not
  -- having adopted one.
  --
  -- layout-§4 fixes the file at 128x128, uncompressed 32-bit: TGA image type 2 in header byte 3,
  -- 32 bits per pixel in byte 17. Read here rather than trusted, because the recipe that produces
  -- it lives outside this repo.
  --
  -- red under: an IconTexture pointing at a Blizzard path or a numeric file id; a TOC and a
  -- constant that name different files; an RLE-compressed (type 10) or 24-bit re-export.
  local toc = io.open("AbsorbTracker.toc", "r")
  assertTrue(toc ~= nil, "cannot open AbsorbTracker.toc (tests run from the repo root)")
  local declared
  for line in toc:lines() do
    local v = line:gsub("\r", ""):match("^##%s*IconTexture:%s*(.-)%s*$")
    if v then declared = v end
  end
  toc:close()
  assertEqual(declared, NS.Constants.LOGO_ICON_PATH,
    "the TOC's `## IconTexture` and the launcher's icon must be the SAME file (launcher-§4)")
  assertTrue(declared:match("^Interface\\AddOns\\") ~= nil,
    "the icon is the addon's own art, never a Blizzard path or a numeric file id")

  local onDisk = "media/logos/absorbtracker.logo.128.tga"
  assertEqual(declared:gsub("\\", "/"):lower(),
    ("Interface/AddOns/" .. FOLDER .. "/" .. onDisk):lower(),
    "the declared path must be the file that actually ships")

  local f = io.open(onDisk, "rb")
  assertTrue(f ~= nil, "the icon file is missing from media/logos/ — the button would draw NOTHING")
  local header = f:read(18)
  f:close()
  assertTrue(header ~= nil and #header == 18, "the file is too short to be a TGA at all")
  local b = { header:byte(1, 18) }
  assertEqual(b[3], 2, "TGA image type must be 2 (uncompressed true-color), not 10 (RLE)")
  assertEqual(b[17], 32, "TGA must be 32 bits per pixel — `convert(\"RGBA\")` is what makes it so")
  assertEqual(b[13] + b[14] * 256, 128, "width must be 128")
  assertEqual(b[15] + b[16] * 256, 128, "height must be 128")
end)

-- ── the minimap row ────────────────────────────────────────────────────────────────────────────

test("launcher: the Minimap button row is stored, global, and says SHOWN", function()
  -- launcher-§3. The row's sense and the stored key's sense are OPPOSITE on purpose: the stored key
  -- is LibDBIcon's OWN `hide`, which the library also writes, and a second boolean beside it would
  -- be a copy of one state free to disagree the first time the player used LibDBIcon's menu.
  --
  -- GLOBAL is the other half. A profile-scoped table would move the player's button on a profile
  -- switch made for an unrelated reason, and options-ui-§12's Reset all settings — a profile reset
  -- by definition — would un-hide a button they deliberately hid.
  local row = NS.FindSchemaRow(NS.Constants.MINIMAP_PATH)
  assertTrue(row ~= nil, "the composer must emit the row for a host that declares `minimapPath`")
  assertEqual(row.label, "Minimap button")
  assertEqual(row.type, "bool")
  assertEqual(row.group, "Master controls")
  assertTrue(row.sessionOnly == nil, "the row is STORED — a reload must not bring the button back")
  assertEqual(row.default, true, "the row's own sense is SHOWN")
  assertEqual(NS.defaults.global.minimap.hide, false,
    "and the stored default is the same state in LibDBIcon's inverted spelling")
  assertNil(NS.defaults.profile.minimap,
    "nothing about the button belongs to a profile (launcher-§3)")
  assertNil(NS.defaults.global.minimap.minimapPos,
    "`minimapPos` is LibDBIcon's to write on the first drag; a declared default would be this "
      .. "addon asserting an angle it has no opinion about")
end)

test("launcher: the row's get/set invert onto `hide`, and the button follows immediately", function()
  -- The whole cost of storing the library's own key, paid once, at the single write seam
  -- (core/Data.lua). The Show/Hide half is what makes the button follow the checkbox NOW rather
  -- than at the next reload.
  --
  -- red under: a get that forgets to invert (the checkbox would read backwards); a set that writes
  -- `hide = value`; a set that stores without moving the button; a parallel `showMinimapIcon` key.
  local b = fakes()
  NS.Launcher:Register()
  local shown, hidden = #b.icons.shown, #b.icons.hidden

  NS.SetByPath(NS.Constants.MINIMAP_PATH, false)
  assertEqual(NS.db.global.minimap.hide, true, "unchecking the row HIDES, in LibDBIcon's spelling")
  assertFalse(NS.GetSetting(NS.Constants.MINIMAP_PATH), "and the row reads back as unchecked")
  assertEqual(#b.icons.hidden, hidden + 1, "the button was hidden, not left for the next reload")
  assertEqual(b.icons.hidden[#b.icons.hidden], FOLDER)

  NS.SetByPath(NS.Constants.MINIMAP_PATH, true)
  assertEqual(NS.db.global.minimap.hide, false)
  assertTrue(NS.GetSetting(NS.Constants.MINIMAP_PATH))
  assertEqual(#b.icons.shown, shown + 1, "and shown again")
  assertEqual(b.icons.shown[#b.icons.shown], FOLDER)

  -- ONE key, not two. A `show`/`showMinimapIcon` beside `hide` is the copy anti-pattern #81 names.
  for key in pairs(NS.db.global.minimap) do
    assertTrue(key == "hide" or key == "minimapPos",
      "db.global.minimap must hold only LibDBIcon's own keys, got `" .. tostring(key) .. "`")
  end
end)

test("launcher: Reset all settings cannot un-hide the button", function()
  -- options-ui-§12 makes Reset all settings a PROFILE reset, and launcher-§3 puts the button in the
  -- global store precisely so that reset cannot reach past the settings it warned about into the
  -- frame furniture. Asserted through the veto the panel and the degraded stub share, and through
  -- the reset-count walk, which must not promise a row it was never going to change.
  fakes()
  NS.Launcher:Register()

  NS.SetByPath(NS.Constants.MINIMAP_PATH, true)
  local base = NS.ProfileRowsOffDefault()
  NS.SetByPath(NS.Constants.MINIMAP_PATH, false)
  assertEqual(NS.ProfileRowsOffDefault(), base,
    "the walk that counts what a reset WOULD change must not count this row -- it would promise a "
      .. "number the reset cannot deliver (debug-logging-\194\16710)")

  NS.Helpers.RestoreAllDefaults()
  assertEqual(NS.db.global.minimap.hide, true, "a hidden button stays hidden through a reset-all")
  assertFalse(NS.GetSetting(NS.Constants.MINIMAP_PATH), "and the row still reads unchecked")

  NS.SetByPath(NS.Constants.MINIMAP_PATH, true)
end)

test("launcher: the General page's Defaults button cannot un-hide the button either", function()
  -- DECISION A, AND THE HALF THIS ADDON ACTUALLY FAILED. launcher-§3 states the survival as a
  -- PROPERTY of the setting rather than deriving it from where the value is stored: whether the
  -- button is shown is a per-installation display preference, in the same class as the ANGLE the
  -- player dragged it to, which LibDBIcon keeps in this very table and which no reset touches.
  --
  -- The old derivation -- Reset all settings is a profile reset, the table is global, therefore it
  -- cannot be reached -- is true of THAT reset and says nothing about this one. The General page's
  -- Defaults button walks `rowsForPage("general")`, the minimap row is on that page carrying
  -- `default = true`, and LibKa0s-Options' RestoreDefaults consults no veto at all: before the
  -- exemption in settings/OptionsSetup.lua, one press put a deliberately hidden button back.
  --
  -- Exercised through the button the page actually parks, not through the library entry point it
  -- calls, so a rewiring of `defaultsOnClick` is caught too.
  --
  -- red under: dropping `survivesEveryReset` from the descriptor's `applyDefault`.
  local b = fakes()
  NS.Launcher:Register()

  NS.SetByPath(NS.Constants.MINIMAP_PATH, false)
  assertEqual(NS.db.global.minimap.hide, true, "precondition: the player hid the button")
  local shown, hidden = #b.icons.shown, #b.icons.hidden

  local ctx = NS.Helpers.__panelFor("general")
  assertTrue(ctx ~= nil, "the General page is registered")
  assertTrue(type(ctx.panel.defaultsOnClick) == "function",
    "settings/General.lua parks the page's Defaults handler on the panel")
  ctx.panel.defaultsOnClick()

  assertEqual(NS.db.global.minimap.hide, true, "a hidden button stays hidden through page Defaults")
  assertFalse(NS.GetSetting(NS.Constants.MINIMAP_PATH), "and the row still reads unchecked")
  assertEqual(#b.icons.shown, shown, "the button was never told to come back")
  assertEqual(#b.icons.hidden, hidden, "and it was not re-hidden either -- the row was not written")

  NS.SetByPath(NS.Constants.MINIMAP_PATH, true)
end)

test("launcher: the page Defaults button still resets every OTHER General row", function()
  -- The exemption is ONE ROW. A veto that swallowed the page would be a worse bug than the one it
  -- fixed, and it would go unnoticed: a Defaults press that does nothing looks like a page already
  -- at its defaults.
  --
  -- red under: a veto keyed on the page, the group, or `row.default == true`.
  fakes()
  NS.Launcher:Register()

  NS.SetByPath(NS.Constants.MINIMAP_PATH, false)
  NS.SetByPath("scale", 0.5)
  NS.SetByPath("locked", not NS.flatDefaults.locked)

  NS.Helpers.__panelFor("general").panel.defaultsOnClick()

  assertEqual(NS.GetSetting("scale"), NS.flatDefaults.scale, "scale came back")
  assertEqual(NS.GetSetting("locked"), NS.flatDefaults.locked, "and so did the lock")
  assertEqual(NS.db.global.minimap.hide, true, "while the one exempt row did not move")

  NS.SetByPath(NS.Constants.MINIMAP_PATH, true)
end)

-- ── degradation ────────────────────────────────────────────────────────────────────────────────

local function freshEnv()
  local Loader     = dofile("tests/_kit/loader.lua")
  local buildMocks = dofile("tests/wow_mock.lua")
  Loader.addonName = FOLDER
  local mocks, ns = buildMocks(), {}
  Loader.loadAll(Loader.xmlFiles("libs/LibKa0s/LibKa0s.xml"), ns, mocks)
  Loader.loadAll(Loader.tocFiles("AbsorbTracker.toc"), ns, mocks)
  -- The DB, because the launcher hands LibDBIcon `db.global.minimap` and without it the register
  -- would fail at the table rather than at the library under test. Its own mocks, so the shared
  -- environment's SavedVariables are untouched.
  ns:InitDB()
  return ns, mocks
end

test("launcher: with BOTH broker libraries absent, Register reports absent and does not raise", function()
  -- The bargain the library strikes deliberately (libs/LibKa0s/Launcher.lua): both are resolved
  -- with `LibStub(..., true)` at REGISTER time, so a host whose libs/ folder is missing them gets a
  -- launcher that says so rather than one that takes the addon's OnInitialize down with it.
  --
  -- A fresh environment, because the cases above registered fakes into the shared one.
  local ns = freshEnv()
  assertTrue(ns.Launcher ~= nil, "the seam publishes NS.Launcher either way")
  local ok, result = pcall(function() return ns.Launcher:Register() end)
  assertTrue(ok, "Register raised with no broker libraries: " .. tostring(result))
  assertFalse(result, "and answers honestly that the button is not there")
  assertFalse(ns.Launcher:IsRegistered())
  assertNil(ns.Launcher:Object())
end)

test("launcher: with LibDataBroker but no LibDBIcon, the plugin exists and the button does not", function()
  -- The honest middle answer: a broker display still shows the addon, and `Register` still returns
  -- false, because the section's headline surface — the button — is not there. Registering the
  -- missing half later must then still work, which is what says the failure was not cached.
  local ns, mocks = freshEnv()
  local ldb = mocks.LibStub:NewLibrary("LibDataBroker-1.1", 4)
  ldb.objects = {}
  function ldb:NewDataObject(name, tbl) self.objects[name] = tbl return tbl end
  function ldb:GetDataObjectByName(name) return self.objects[name] end

  assertFalse(ns.Launcher:Register(), "no minimap button, so not fully wired")
  assertTrue(ns.Launcher:Object() ~= nil, "but the broker plugin is real")
  assertFalse(ns.Launcher:IsRegistered())

  local icons = mocks.LibStub:NewLibrary("LibDBIcon-1.0", 45)
  icons.registered = {}
  function icons:Register(name, obj, db)
    self.registered[#self.registered + 1] = { name = name, object = obj, db = db }
  end
  icons.Show = function() end
  icons.Hide = function() end
  assertTrue(ns.Launcher:Register(), "a later call picks up the half that was missing")
  assertEqual(#icons.registered, 1, "and registers exactly one button")
end)

test("launcher: with LibKa0s absent the seam still answers, and still remembers the choice", function()
  -- The degradation stub's contract, and it is the store rather than the button: a player who
  -- unchecks Minimap button on a broken install must have that choice honored the day the library
  -- is back. Answering out of the store is also what keeps the checkbox honest — reading `true`
  -- because nothing contradicted it would be a lie the player can see.
  local loadDegraded = dofile("tests/degraded_env.lua")
  local ns = loadDegraded()
  assertTrue(ns.Launcher ~= nil, "core/LauncherSetup.lua publishes NS.Launcher on both arms")
  assertFalse(ns.Launcher:Register(), "nothing to register")
  assertFalse(ns.Launcher:IsRegistered())
  assertNil(ns.Launcher:Object())

  -- No InitDB in this environment, so the store is absent: the stub must not raise on it.
  assertTrue(ns.Launcher:IsShown(), "with no store at all, the button reads as shown — the default")
  assertFalse(ns.Launcher:SetShown(false), "and SetShown says the button itself could not be moved")

  ns.db = { global = { minimap = {} } }
  ns.Launcher:SetShown(false)
  assertEqual(ns.db.global.minimap.hide, true, "the choice is recorded in LibDBIcon's own key")
  assertFalse(ns.Launcher:IsShown())
  ns.Launcher:SetShown(true)
  assertEqual(ns.db.global.minimap.hide, false)
  assertTrue(ns.Launcher:IsShown())
end)
