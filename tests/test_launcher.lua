-- tests/test_launcher.lua — the launcher: one object registered twice, the two buttons and the
-- options menu's entries, and the one boolean that decides whether the minimap button is there.
--
-- What is NOT tested here is the library's own wiring, which lives in the LibKa0s repo. What IS
-- tested is every seam that is this addon's: the descriptor core/LauncherSetup.lua hands over, the
-- menu entries it passes and the handlers they route to, the inversion core/Data.lua pays at the read/write seam, and the degradation arm
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

test("launcher: the broker label is the BRAND NAME in plain text", function()
  -- launcher-§1, and the reason it is a rule rather than a preference: `label` is what a broker
  -- display prints in its own row, BESIDE the other ten Ka0s addons. This one used to say
  -- "Absorb Tracker", so a display sorting its plugins alphabetically filed it under A while every
  -- sibling sat together under K -- one collection reading as eleven unrelated addons.
  --
  -- red under: the short spelling coming back; the folder name (that is `name`, which LibDBIcon
  -- keys the saved position by); any color escape, which is what makes this NOT the TOC `## Title`
  -- -- a Title may carry them and one in the collection does.
  fakes()
  NS.Launcher:Register()
  local object = NS.Launcher:Object()

  assertEqual(object.label, "Ka0s Absorb Tracker", "the brand name, `Ka0s <Name>`")
  assertTrue(object.label:find("|", 1, true) == nil,
    "plain text: no escape sequence of any kind may reach a broker row")
  assertTrue(object.label ~= FOLDER, "the folder name is an identifier, not prose")
  assertTrue(object.label ~= object.name, "and `name` is the registration, not the label")
end)

test("launcher: the label is not WIRED to the TOC Title, even though both read the same today", function()
  -- The two strings match in this addon because its Title happens to carry no color escapes. The
  -- rule is about the WIRING, not the value: `label` is a literal in core/LauncherSetup.lua, read
  -- from nothing. Ka0s Pretty Chat's Title is `Ka0s |cffff0000P|cffff9900r|...`, and an addon that
  -- fed `NS.Meta("Title")` into this field would be one TOC edit away from splattering its row
  -- across a display.
  --
  -- It is now the ONE brand constant rather than a literal spelled here, and that is a tightening
  -- rather than a loosening of the same rule: slash-commands-§7 makes the disabled refusal line
  -- carry this exact string, so `label` and the dispatcher's `brandName` have to be the same
  -- spelling. Two literals would be two brand names. What the rule forbids is a read of the
  -- MANIFEST, and this reads a plain-text constant in core/Constants.lua.
  --
  -- red under: `label = NS.Meta("Title")` or any other read of the manifest; a second literal here
  -- that drifts from the constant the refusal line is built out of.
  local src = io.open("core/LauncherSetup.lua", "r")
  assertTrue(src ~= nil, "cannot open core/LauncherSetup.lua (tests run from the repo root)")
  local body = src:read("*a")
  src:close()
  local assigned = body:match("\n%s*label%s*=%s*(.-),\r?\n")
  assertEqual(assigned, "NS.Constants.BRAND",
    "`label` must be the one brand constant, never a read of `## Title` or of the folder name")
  assertEqual(NS.Constants.BRAND, "Ka0s Absorb Tracker", "and that constant is the plain-text brand")
  assertEqual(NS.Launcher:Object().label, "Ka0s Absorb Tracker", "which is what the object carries")
end)

-- ── the two buttons (Launcher minor 4, launcher-§2) ────────────────────────────────────────────
--
-- LEFT-click opens the settings panel, on every addon, in either state. RIGHT-click opens the
-- client's own context menu, built by the LIBRARY out of the accessor-and-toggle pairs the
-- descriptor passes. What is this addon's, and what these cases pin, is WHICH pairs it passes --
-- Enabled and Locked, the row WowAddonStandards' ADDONS.md records; no Test mode (options-ui-§15's
-- exemption: the lock IS the preview) and no Show window (there is no primary window) -- and that
-- each toggle is the SAME handler its slash verb runs, so the refusals and the echo are the verb's.

local Menu = dofile("tests/mock_menu.lua")(T.mocks)

--- Run `fn` with the fake MenuUtil installed, and take it away again whatever happens: left
--- installed, every later suite's right click would open a menu instead of the panel.
local function withMenu(fn)
  Menu.install()
  local ok, err = pcall(fn)
  Menu.remove()
  if not ok then error(err, 0) end
end

--- Right-click the one object and hand back the menu the library opened.
local function openMenu()
  local object = NS.Launcher:Object()
  local before = Menu.opens
  object.OnClick(object, "RightButton")
  assertEqual(Menu.opens, before + 1, "the right click opened no menu")
  return Menu.last
end

--- Run `fn` with the named NS.COMMANDS handlers spied on (the real ones still run), and hand back
--- the verbs that were run, in order. This is what proves a menu entry and `/at <verb>` are one
--- handler rather than two that agree today.
local function verbCalls(names, fn)
  local calls, saved = {}, {}
  for _, c in ipairs(NS.COMMANDS) do
    if names[c[1]] then
      local real = c[3]
      saved[c] = real
      c[3] = function(...)
        calls[#calls + 1] = c[1]
        return real(...)
      end
    end
  end
  local ok, err = pcall(fn)
  for c, real in pairs(saved) do c[3] = real end
  assertTrue(ok, "the act raised: " .. tostring(err))
  return calls
end

test("launcher: LEFT-click opens the settings panel, and writes nothing", function()
  -- launcher-§2 (v2.67.0): the left button has one meaning on every addon. It used to toggle the
  -- lock here (rung (b)); that toggle is the menu's Locked entry now.
  --
  -- red under: an `onClick` still honored; a left click that writes the lock.
  fakes()
  NS.Launcher:Register()
  local object = NS.Launcher:Object()

  NS.SetByPath("locked", true)
  local real, opened = NS.OpenOptionsPanel, 0
  NS.OpenOptionsPanel = function() opened = opened + 1 end
  local seen = seamCalls(function() object.OnClick(object, "LeftButton") end)
  NS.OpenOptionsPanel = real

  assertEqual(opened, 1, "left-click opens the panel")
  assertEqual(#seen, 0, "and writes nothing")
  assertTrue(NS.GetSetting("locked"), "the lock is untouched by the left button")
end)

test("launcher: RIGHT-click opens the options menu: the brand title, Enabled, Locked, nothing else", function()
  -- The menu entries are exactly ADDONS.md's row for this addon. A Test mode entry would name a
  -- state with no settings row; a Show window entry, a window this addon does not have.
  --
  -- red under: a missing `setEnabled` or `toggleLock` (half a pair draws nothing); a
  -- `toggleTestMode` or `toggleWindow` passed; right-click opening the panel instead.
  fakes()
  NS.Launcher:Register()
  NS.SetByPath("enabled", true)
  withMenu(function()
    local real, opened = NS.OpenOptionsPanel, 0
    NS.OpenOptionsPanel = function() opened = opened + 1 end
    local menu = openMenu()
    NS.OpenOptionsPanel = real

    assertEqual(opened, 0, "right-click opens the menu, not the panel")
    assertEqual(menu.titles[1], "Ka0s Absorb Tracker", "the menu is titled with the brand label")
    assertEqual(table.concat(menu:Texts(), " / "), "Enabled / Locked")
  end)
end)

test("launcher menu: each entry reads its state on every open", function()
  -- The checkboxes read `isEnabled` / `isLocked` when the menu opens, never a copy.
  fakes()
  NS.Launcher:Register()
  NS.SetByPath("enabled", true)
  withMenu(function()
    NS.SetByPath("locked", true)
    local menu = openMenu()
    assertTrue(menu:Checked("Enabled"), "Enabled reads checked")
    assertTrue(menu:Checked("Locked"), "Locked reads checked")

    NS.SetByPath("locked", false)
    assertFalse(openMenu():Checked("Locked"), "the next open reads the lock afresh")
    NS.SetByPath("locked", true)
  end)
end)

test("launcher menu: Enabled runs the /at enable and /at disable handlers themselves", function()
  -- setEnabled(bool) routes to the SAME NS.COMMANDS entries the dispatcher runs, so the write goes
  -- through NS.SetByPath (the `enabled` onChange, the stand-down latch) and the echo is the verb's.
  --
  -- red under: a setEnabled that writes the setting itself; one that ignores its argument.
  fakes()
  NS.Launcher:Register()
  NS.SetByPath("enabled", true)
  withMenu(function()
    local calls = verbCalls({ enable = true, disable = true }, function() openMenu():Click("Enabled") end)
    assertEqual(table.concat(calls, ","), "disable", "unchecking Enabled runs /at disable's handler")
    assertFalse(NS.GetSetting("enabled") ~= false, "and the addon is off")

    calls = verbCalls({ enable = true, disable = true }, function() openMenu():Click("Enabled") end)
    assertEqual(table.concat(calls, ","), "enable", "checking it again runs /at enable's handler")
    assertTrue(NS.GetSetting("enabled") ~= false, "and the addon is back on")
  end)
end)

test("launcher menu: Locked runs the /at lock and /at unlock handlers themselves", function()
  -- toggleLock routes to the verb matching the STORED lock, so the `locked` onChange (the combat
  -- unlock refusal, the preview clear, the repaint) and the echo are the verb's.
  --
  -- red under: a toggleLock that writes `locked` itself, or keeps its own upvalue.
  fakes()
  NS.Launcher:Register()
  NS.SetByPath("enabled", true)
  NS.SetByPath("locked", true)
  withMenu(function()
    local calls = verbCalls({ lock = true, unlock = true }, function() openMenu():Click("Locked") end)
    assertEqual(table.concat(calls, ","), "unlock", "unchecking Locked runs /at unlock's handler")
    assertFalse(NS.GetSetting("locked"), "and the bars are unlocked")

    calls = verbCalls({ lock = true, unlock = true }, function() openMenu():Click("Locked") end)
    assertEqual(table.concat(calls, ","), "lock", "checking it again runs /at lock's handler")
    assertTrue(NS.GetSetting("locked"), "and the bars are locked")
  end)
end)

test("launcher menu: while disabled, Locked is grayed with the note and Enabled stays live", function()
  -- slash-commands-§7: features refuse while disabled; the library grays every entry but Enabled.
  fakes()
  NS.Launcher:Register()
  NS.SetByPath("locked", true)
  NS.SetByPath("enabled", false)
  local ok, err = pcall(withMenu, function()
    local menu = openMenu()
    assertEqual(table.concat(menu:Texts(), " / "), "Enabled / Locked (enable the addon first)")
    assertFalse(menu:Find("Locked").enabled, "Locked is grayed")
    assertTrue(menu:Find("Enabled").enabled, "Enabled is live")
    local calls = verbCalls({ lock = true, unlock = true }, function() menu:Click("Locked") end)
    assertEqual(#calls, 0, "a grayed entry runs no handler")
    assertTrue(NS.GetSetting("locked"), "and the lock did not move")
  end)
  NS.SetByPath("enabled", true)
  assertTrue(ok, tostring(err))
end)

test("launcher: with no client menu API, right-click falls back to the settings panel", function()
  -- The harness's default: no MenuUtil, as on a pre-11.0 client. The panel holds every toggle the
  -- menu would have.
  fakes()
  NS.Launcher:Register()
  local object = NS.Launcher:Object()
  local real, opened = NS.OpenOptionsPanel, 0
  NS.OpenOptionsPanel = function() opened = opened + 1 end
  local seen = seamCalls(function() object.OnClick(object, "RightButton") end)
  NS.OpenOptionsPanel = real
  assertEqual(opened, 1, "right-click opens the panel")
  assertEqual(#seen, 0, "and writes nothing")
end)

test("launcher: the descriptor carries none of the fields Launcher minor 4 retired", function()
  -- launcher-§5: a retired field is ignored, which is exactly why it has to be caught here -- it
  -- would sit in the setup file as dead configuration nothing reports.
  local src = assert(io.open("core/LauncherSetup.lua", "r"))
  local body = src:read("*a")
  src:close()
  for _, field in ipairs({ "onClick", "leftClickLabel", "disabledLine", "slash",
      "toggleTestMode", "isTestMode", "toggleWindow", "isWindowShown" }) do
    assertTrue(body:find("\n%s*" .. field .. "%s*=") == nil,
      "core/LauncherSetup.lua must not pass `" .. field .. "`")
  end
end)

-- ── the status tooltip (Launcher minor 3, launcher-§1) ─────────────────────────────────────────
--
-- The LIBRARY draws the tooltip, in one shape across the collection. What is this addon's, and
-- what these cases pin, is the descriptor that feeds it: `version` out of the TOC, `isLocked` off
-- the `locked` row, and NO `isTestMode` —
-- options-ui-§15's exemption means this addon has no Test mode row, so a `Test mode:` line would
-- report a state the player can find nowhere else. No `onTooltipShow` either: there is nothing of
-- this addon's own to append, and a host hook that drew a title or a hint would draw it twice.

--- A GameTooltip stand-in that records each line, raw. The kit's GameTooltip is a bare frame with
--- no AddLine, so the library's draw is driven against this instead of against it.
local function hover()
  local tt = { lines = {} }
  function tt:AddLine(line) self.lines[#self.lines + 1] = line end
  NS.Launcher:Object().OnTooltipShow(tt)
  local plain = {}
  for i, line in ipairs(tt.lines) do
    plain[i] = (tostring(line):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
  end
  return plain, tt.lines
end

--- The TOC's own `## Version`, read off disk, so the expectation is not a second literal.
local function tocVersion()
  local f = assert(io.open("AbsorbTracker.toc", "r"))
  local v
  for line in f:lines() do
    v = v or line:gsub("\r", ""):match("^##%s*Version:%s*(.-)%s*$")
  end
  f:close()
  return v
end

--- Run `fn` with the client's manifest reader answering this addon's TOC. The harness has no
--- C_AddOns by default, which is the headless shape NS.Meta already answers nil for.
local function withManifest(fn)
  local real = T.mocks.C_AddOns
  T.mocks.C_AddOns = { GetAddOnMetadata = function(name, field)
    if name == FOLDER and field == "Version" then return tocVersion() end
    return nil
  end }
  local ok, err = pcall(fn)
  T.mocks.C_AddOns = real
  if not ok then error(err, 0) end
end

test("launcher tooltip: enabled and locked, the whole tooltip is exactly five lines", function()
  -- The full shape, pinned as one list so an extra line (a Test mode line, a host title, a second
  -- hint) and a missing one are both red.
  --
  -- red under: `isTestMode` passed; `isLocked` or `version` not passed; an `onTooltipShow` that
  -- draws anything. The two hints are the library's fixed pair since Launcher minor 4.
  fakes()
  NS.Launcher:Register()
  NS.SetByPath("enabled", true)
  NS.SetByPath("locked", true)
  withManifest(function()
    local lines = hover()
    assertEqual(#lines, 5, "title, Enabled, Locked, Left-click, Right-click: " .. table.concat(lines, " / "))
    assertEqual(lines[1], "Ka0s Absorb Tracker  v" .. tocVersion(), "the brand label and the TOC version")
    assertEqual(lines[2], "Enabled: Yes")
    assertEqual(lines[3], "Locked: Yes")
    assertEqual(lines[4], "Left-click: Open settings")
    assertEqual(lines[5], "Right-click: Options menu")
  end)
end)

test("launcher tooltip: the version is the TOC's, and absent it the title is the label alone", function()
  -- `version` reads `## Version` through NS.Meta on every show. With no manifest reader (the
  -- headless shape) it answers nil and the library draws the label alone -- never `v?` or the
  -- fallback constant, which would be a version this build does not claim.
  --
  -- red under: `version = NS.version`; `version = NS.Version` (answers "?" headless).
  fakes()
  NS.Launcher:Register()
  local lines = hover()
  assertEqual(lines[1], "Ka0s Absorb Tracker", "no manifest, no version")
  withManifest(function()
    assertEqual(hover()[1], "Ka0s Absorb Tracker  v" .. tocVersion())
  end)
end)

test("launcher tooltip: Locked follows the lock on every show, green Yes and red No", function()
  -- `isLocked` reads the same `locked` value the Lock frame checkbox and the menu's Locked entry
  -- write, asked on each show, so a click and the next hover cannot disagree.
  --
  -- red under: isLocked captured once; isLocked reading anything but the `locked` setting.
  fakes()
  NS.Launcher:Register()
  NS.SetByPath("enabled", true)
  NS.SetByPath("locked", true)
  local lines, raw = hover()
  assertEqual(lines[3], "Locked: Yes")
  assertTrue(raw[3]:find("|cFF00FF00Yes|r", 1, true) ~= nil, "Yes is green: " .. tostring(raw[3]))

  withMenu(function() openMenu():Click("Locked") end)
  lines, raw = hover()
  assertEqual(lines[3], "Locked: No", "the menu unlocked, and the next hover says so")
  assertTrue(raw[3]:find("|cFFFF0000No|r", 1, true) ~= nil, "No is red: " .. tostring(raw[3]))
  NS.SetByPath("locked", true)
end)

test("launcher tooltip: no Test mode line, because this addon has no Test mode", function()
  -- options-ui-§15's exemption (settings/General.lua): the lock IS the preview. A Test mode line
  -- would name a state the settings panel has no row for.
  --
  -- red under: `isTestMode` passed, whatever it reads.
  fakes()
  NS.Launcher:Register()
  for _, line in ipairs(hover()) do
    assertTrue(line:find("Test mode", 1, true) == nil, "unexpected line: " .. line)
  end
end)

test("launcher tooltip: disabled, it still draws, says No, and the hints do not change", function()
  -- The owner's ruling (M5): the tooltip shows WHILE DISABLED, when a player most needs to ask.
  -- Since Launcher minor 4 neither button is gated, so the hints read the same in either state.
  --
  -- red under: isEnabled not passed.
  fakes()
  NS.Launcher:Register()
  NS.SetByPath("locked", true)
  NS.SetByPath("enabled", false)
  local ok, lines, raw = pcall(hover)
  NS.SetByPath("enabled", true)
  assertTrue(ok, "the tooltip raised while disabled: " .. tostring(lines))
  assertEqual(#lines, 5, table.concat(lines, " / "))
  assertEqual(lines[2], "Enabled: No")
  assertTrue(raw[2]:find("|cFFFF0000No|r", 1, true) ~= nil, "No is red: " .. raw[2])
  assertEqual(lines[3], "Locked: Yes", "the lock is still reported while disabled")
  assertEqual(lines[4], "Left-click: Open settings", "the left button is never gated")
  assertEqual(lines[5], "Right-click: Options menu", "nor is the right")
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

-- ── the row's CLI path reads in the row's own sense (launcher-§3) ──────────────────────────────
--
-- The path a player types is `global.minimap.shown`, the sense of the checkbox. The STORED key is
-- still LibDBIcon's own `hide`, so there is no SavedVariables migration and no `shown` key is ever
-- written (anti-pattern #81). The old spelling is gone from the CLI and answers unknown setting.

local function slash(line)
  local out = {}
  local cf = T.mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function(_, msg) out[#out + 1] = msg end
  local ok, err = pcall(NS.Slash.OnSlash, NS.Slash, line)
  cf.AddMessage = old  -- nil restores the metatable no-op
  if not ok then error(err) end
  return (table.concat(out, "\n"):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
end

local function assertNoShownKey(where)
  for key in pairs(NS.db.global.minimap) do
    assertTrue(key ~= "shown", "no `shown` key is ever stored (" .. where .. ")")
  end
end

test("launcher: /at get global.minimap.shown reads the row's sense off the stored hide", function()
  -- red under: a constant still spelled `global.minimap.hide` (Setting not found).
  assertEqual(NS.Constants.MINIMAP_PATH, "global.minimap.shown")
  NS.SetByPath(NS.Constants.MINIMAP_PATH, true)
  assertEqual(NS.db.global.minimap.hide, false, "precondition: the button is shown")
  local out = slash("get global.minimap.shown")
  assertTrue(out:find("global.minimap.shown = true", 1, true) ~= nil, out)
  assertNoShownKey("after a get")
end)

test("launcher: /at set global.minimap.shown false stores hide = true and hides the button", function()
  fakes()
  NS.Launcher:Register()
  slash("set global.minimap.shown false")
  assertEqual(NS.db.global.minimap.hide, true, "the stored key is LibDBIcon's `hide`, inverted")
  assertFalse(NS.MinimapShown(), "and the row reads unchecked")
  assertNoShownKey("after a set")
  NS.SetByPath(NS.Constants.MINIMAP_PATH, true)
end)

test("launcher: the old CLI spelling global.minimap.hide answers unknown setting", function()
  -- red under: keeping the hide spelling as the path.
  local out = slash("get global.minimap.hide")
  assertTrue(out:find("Setting not found", 1, true) ~= nil, out)
end)

test("launcher: the renamed path is not reported missing from the defaults", function()
  -- The row owns its storage (its own get/set), so the validator does not look for a
  -- `global.minimap.shown` default that must never exist (architecture-§5's closure-backed row).
  local errors, _, missing = NS.ValidateSchema()
  assertEqual(errors, 0)
  assertEqual(missing, 0)
end)

test("launcher: a legacy store keeps its hidden button, and its angle, across the rename", function()
  -- No SavedVariables migration: the key the old build wrote is the key this build reads.
  fakes()
  NS.Launcher:Register()
  local saved = NS.db.global.minimap
  NS.db.global.minimap = { hide = true, minimapPos = 200 }

  local out = slash("get global.minimap.shown")
  assertTrue(out:find("global.minimap.shown = false", 1, true) ~= nil, out)
  assertFalse(NS.GetSetting(NS.Constants.MINIMAP_PATH), "the legacy hidden button reads hidden")
  assertEqual(NS.db.global.minimap.hide, true, "and stays hidden")
  assertEqual(NS.db.global.minimap.minimapPos, 200, "the dragged angle is untouched")

  slash("set global.minimap.shown true")
  assertEqual(NS.db.global.minimap.hide, false)
  assertEqual(NS.db.global.minimap.minimapPos, 200, "a set does not move the angle either")
  assertNoShownKey("after a set on a legacy store")

  NS.db.global.minimap = saved
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
