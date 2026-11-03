-- tests/test_skin_picker_preview.lua — the skin picker's eye on this addon's seam (R6-PV;
-- core/SkinSetup.lua, LibKa0s OptionsSkinPicker minor 11's spec.preview, R6-L1).
--
-- The owner's rule (Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND6, images 62, 63 and 66): when
-- the picker shows and the addon's main surface is hidden, the addon enters its preview mode; the
-- eye toggles it; every close puts it back as it was. This addon has no window and no test mode, so
-- its mode is UNLOCK (the lead's call 2): the surface is the unlocked bars, "hidden" means locked,
-- and every enter and exit is the `/at unlock` / `/at lock` verb's own handler, the call the
-- launcher's Lock entry makes, so the settings checkbox, the launcher and the combat refusal (the
-- `locked` row's onChange) stay in step. What the library pins itself (the record, the paint, the
-- queue, the park) is its own suite's; this file pins what this addon hands it and that the real
-- window drives the real lock.
--
-- After test_skin_picker; leaves the picker down, marked unseen, and the bars on the shipped
-- unlocked default.

local T = _G.AT_TEST
local NS, mocks = T.NS, T.mocks
local test, assertEqual, assertTrue, assertFalse = T.test, T.assertEqual, T.assertTrue, T.assertFalse

local O = NS.Helpers
local PATH = "skin.pickerSeen"

local function locked() return NS.GetSetting("locked") and true or false end

--- Run `fn` with chat swallowed: the lock verbs echo the stored value.
local function quietly(fn)
  local cf = mocks.DEFAULT_CHAT_FRAME
  local old = rawget(cf, "AddMessage")
  cf.AddMessage = function() end
  local ok, err = pcall(fn)
  cf.AddMessage = old
  if not ok then error(err, 0) end
end

--- `fn(f)` on this addon's real picker, opened with the bars locked (`lock` true) or unlocked;
--- whatever it raised, the picker goes down quietly and the profile goes back to the shipped
--- unlocked default with the picker unseen.
local function opened(lock, fn)
  return function()
    NS.HideSkinPicker()
    quietly(function()
      NS.SetByPath(PATH, false)
      NS.SetByPath("locked", lock)
    end)
    local ok, err = pcall(function()
      quietly(function()
        local f = NS.MaybeShowSkinPicker()
        assertTrue(f ~= nil and f:IsShown(), "the library's picker did not show")
        fn(f)
      end)
    end)
    quietly(function()
      NS.HideSkinPicker()
      NS.SetByPath(PATH, false)
      NS.SetByPath("locked", false)
    end)
    mocks.__fireTimers()
    if not ok then error(err, 0) end
  end
end

-- ── the spec ─────────────────────────────────────────────────────────────────────────────────

test("Skin preview: the spec hands the picker spec.preview in unlock mode, and no onPreview", function()
  -- red under: the old spec with no eye, a one-shot onPreview left beside it, or a mode word the
  -- lead's call 2 did not give this addon.
  local spec = NS.SkinPickerSpec()
  local p = spec.preview
  assertEqual(type(p), "table", "spec.preview")
  assertEqual(p.mode, "unlock", "the lead's call 2: AbsorbTracker previews by unlocking")
  for _, k in ipairs({ "enter", "exit", "isActive", "isShown" }) do
    assertEqual(type(p[k]), "function", "spec.preview." .. k)
  end
  assertEqual(spec.onPreview, nil, "the one-shot eye is gone")
end)

test("Skin preview: isActive and isShown read the stored lock, as the launcher's isLocked does", function()
  local p = NS.SkinPickerSpec().preview
  quietly(function() NS.SetByPath("locked", true) end)
  assertFalse(p.isActive(), "locked: the mode is off")
  assertFalse(p.isShown(), "locked: the surface (the unlocked bars) is hidden")
  quietly(function() NS.SetByPath("locked", false) end)
  assertTrue(p.isActive(), "unlocked: the mode is on")
  assertTrue(p.isShown(), "unlocked: the surface is shown")
end)

test("Skin preview: enter and exit run the /at unlock and /at lock verbs' own handlers", function()
  -- red under: a write that bypasses the verbs (the launcher would still toggle through them, and
  -- the two could drift), or an exit that unlocks.
  local p = NS.SkinPickerSpec().preview
  local ran = {}
  local real = {}
  for _, c in ipairs(NS.COMMANDS) do
    if c[1] == "lock" or c[1] == "unlock" then
      local name, fn = c[1], c[3]
      real[name] = fn
      c[3] = function(...) ran[#ran + 1] = name; return fn(...) end
    end
  end
  local ok, err = pcall(function()
    quietly(function()
      NS.SetByPath("locked", true)
      p.enter("picker")
      assertFalse(locked(), "enter unlocks the bars")
      p.exit("eye")
      assertTrue(locked(), "exit locks them")
    end)
    assertEqual(table.concat(ran, ","), "unlock,lock", "through the verbs, in that order")
  end)
  for _, c in ipairs(NS.COMMANDS) do
    if real[c[1]] then c[3] = real[c[1]] end
  end
  quietly(function() NS.SetByPath("locked", false) end)
  if not ok then error(err, 0) end
end)

-- ── the real window ──────────────────────────────────────────────────────────────────────────

test("Skin preview: opened with the bars locked, the picker unlocks them and shows a lit eye", opened(true, function(f)
  assertFalse(locked(), "a hidden surface: the picker entered unlock mode")
  assertTrue(f.preview ~= nil and f.preview:IsShown(), "the eye shows")
  assertTrue(f.preview.lit == true, "and is lit while the bars are unlocked")
end))

test("Skin preview: the eye toggles the lock, off and on", opened(true, function(f)
  f.preview:__fire("OnClick")
  assertTrue(locked(), "the eye locks the bars")
  assertFalse(f.preview.lit, "and dims")
  assertTrue(f:IsShown(), "the picker stays up")
  f.preview:__fire("OnClick")
  assertFalse(locked(), "a second click unlocks them again")
  assertTrue(f.preview.lit == true, "and lights")
end))

-- Every close route the player has, and this addon's own: each puts the lock back.
local ROUTES = {
  { "the close control", function(f) f.close:__fire("OnClick") end },
  { "Apply", function(f) f.apply:__fire("OnClick") end },
  { "Escape", function(f) f:Hide(); f:__fire("OnHide") end },
  { "the library's HideSkinPicker", function() O.HideSkinPicker() end },
  { "the gear", function(f)
      local realOpen, realSelect = O.OpenOptionsPanel, O.SelectTab
      O.OpenOptionsPanel = function() return true end
      O.SelectTab = function() return true end
      local ok, err = pcall(function() f.settings:__fire("OnClick") end)
      O.OpenOptionsPanel, O.SelectTab = realOpen, realSelect
      if not ok then error(err, 0) end
    end },
}

for _, route in ipairs(ROUTES) do
  test("Skin preview: " .. route[1] .. " locks the bars it unlocked", opened(true, function(f)
    assertFalse(locked(), "the picker unlocked them")
    route[2](f)
    assertTrue(not f:IsShown(), route[1] .. " closes the window")
    assertTrue(locked(), route[1] .. " puts the lock back")
  end))
end

test("Skin preview: this addon's own close (stand-down, reset) moves no lock", opened(true, function(f)
  -- red under: a restore that writes on the stand-down (a perf capture must write nothing to
  -- SavedVariables) or over what a profile reset just put back.
  assertFalse(locked(), "the picker unlocked the bars")
  NS.HideSkinPicker()
  assertTrue(not f:IsShown(), "NS.HideSkinPicker takes the window down")
  assertFalse(locked(), "and leaves the lock as the picker left it")
end))

test("Skin preview: a profile switch puts back the lock of the profile the picker opened on", opened(true, function()
  -- red under: a restore that writes the new profile (its own lock is the player's), or one that
  -- leaves the old profile unlocked.
  assertFalse(locked(), "the picker unlocked Default's bars")
  local ok, err = pcall(function()
    -- The new profile is unseen, so the picker shows again, fresh, over its own lock.
    NS.db:SetProfile("PreviewOther")
    assertFalse(locked(), "the new profile keeps its own (shipped, unlocked) lock")
    assertTrue(NS.db.sv.profiles.Default.locked == true, "Default is locked again, as it opened")
  end)
  NS.HideSkinPicker()
  NS.db:SetProfile("Default")
  if NS.db.sv.profiles then NS.db.sv.profiles.PreviewOther = nil end
  if not ok then error(err, 0) end
end))

test("Skin preview: a mode that was on and the eye turned off is on again after the close", opened(false, function(f)
  f.preview:__fire("OnClick")
  assertTrue(locked(), "the eye locked the bars")
  f.close:__fire("OnClick")
  assertFalse(locked(), "the close unlocks them again, as they were at open")
end))

test("Skin preview: bars already unlocked are left alone, open and close", opened(false, function(f)
  assertFalse(locked(), "a shown surface is not entered (it is on already)")
  assertTrue(f.preview.lit == true, "the eye is lit")
  f.close:__fire("OnClick")
  assertFalse(locked(), "and the close does not lock what the picker never unlocked")
end))

test("Skin preview: in combat the eye's unlock is refused and the close undoes nothing", opened(true, function(f)
  -- The picker opened out of combat and unlocked; the eye locks; combat starts; the eye's unlock is
  -- the `locked` row's refusal, so the bars stay locked, and the close leaves them locked.
  f.preview:__fire("OnClick")
  assertTrue(locked(), "the eye locked the bars")
  local real = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return true end
  local ok, err = pcall(function()
    f.preview:__fire("OnClick")
    assertTrue(locked(), "the unlock is refused in combat, through the verb's own seam")
    assertFalse(f.preview.lit, "and the eye stays dim")
    f.close:__fire("OnClick")
    assertTrue(locked(), "the close leaves the bars locked: the picker opened them locked")
  end)
  mocks.InCombatLockdown = real
  if not ok then error(err, 0) end
end))

test("Skin preview: this addon's own close in combat parks no lock move for after combat", opened(false, function(f)
  -- red under: a quiet close (an `/at disable` mid-fight, a reset) whose skipped restore the
  -- library parks for the end of combat, which then runs the `/at unlock` verb on a stood-down
  -- addon, or during a perf capture's no-write window.
  f.preview:__fire("OnClick")
  assertTrue(locked(), "the eye locked the bars")
  local real = mocks.InCombatLockdown
  mocks.InCombatLockdown = function() return true end
  local ok, err = pcall(function()
    NS.HideSkinPicker()
    assertTrue(not f:IsShown(), "NS.HideSkinPicker takes the window down")
    assertTrue(locked(), "and leaves the lock as the picker left it")
  end)
  mocks.InCombatLockdown = real
  if not ok then error(err, 0) end
  -- The end of combat, as the library's park frame hears it (OptionsRegistry.lua).
  mocks.LibStub("LibKa0s-Options-1.0").__OnParkEvent("PLAYER_REGEN_ENABLED")
  assertTrue(locked(), "combat's end moves no lock either")
end))
