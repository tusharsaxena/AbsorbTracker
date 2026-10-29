local addonName, NS = ...

-- core/SkinSetup.lua — the LibKa0s-Skin-1.0 seam: which skin this addon wears (skinning-§3).
--
-- ── WHAT IT PUBLISHES ────────────────────────────────────────────────────────────────────────
--
--   NS.Skin                 the owner's facade, `Skin:For("AbsorbTracker")`: the painting
--                           vocabulary and Token / Color / Resolve / OnLooksChanged. Every surface
--                           that draws reads its looks here.
--   NS.SkinChoice()         the stored (source, skin) pair, read through NS.GetSetting; "ka0s",
--                           "ka0s" before NS:InitDB has built the profile store.
--   NS.WriteSkinChoice(s,k,i,m) the write seam: every half through NS.SetByPath, the one seam
--                           `/at set` and the panel already write through (architecture-§5); `i`,
--                           the Scope's `{ panel, fonts }`, writes the two exceptions, and `m`, the
--                           Font and texture section's `{ font, texture }`, writes the two
--                           overrides, "" for false (the skin's own). A nil half is not written.
--   NS.ApplySkinIgnore(p,f) moves the applied exceptions: `Skin:SetIgnore`, live; no argument
--                           applies the stored pair, a nil half keeps that half.
--   NS.SkinFontsIgnored()   true while the applied "Ignore fonts" is on (`Skin:GetIgnore`, live;
--                           false without the library). core/Data.lua reads it for the HUD face:
--                           the library's Resolve/Token never check it, only P.font does.
--   NS.SkinOverride()       the stored overrides: font, texture, each an LSM key or false for the
--                           skin's own; false, false before NS:InitDB.
--   NS.ApplySkinOverride(f,t) moves the applied overrides: `Skin:SetOverride`, live; no argument
--                           applies the stored pair, a nil half keeps that half, false or "" clears.
--   NS.ApplySkinChoice(s,k) moves the applied skin: `Skin:SetChoice`, which resolves, repaints
--                           every frame recorded for this owner and THEN fires OnLooksChanged. No
--                           argument applies the stored pair (addon:OnInitialize, the profile
--                           events), and with it the stored exceptions and overrides; a nil half
--                           keeps that half (each Skin tab row's onChange).
--   OnLooksChanged          one listener, registered here: it republishes APPEARANCE, so the HUD
--                           bars repaint with the skin's media on every switch (core/Data.lua).
--   NS.SKIN_SOURCE_OPTIONS  the source row's values, and NS.SKIN_OPTIONS the skin row's (every
--   NS.SKIN_OPTIONS         registered skin, in the library's order). settings/General.lua reads
--                           both at file load.
--   NS.SkinPaintAce(w)      an AceGUI widget this addon acquired itself, painted for this owner:
--   NS.SkinPaintAceTree(c)  `Skin:PaintAce` / `Skin:PaintAceTree` with the owner bound (the facade
--                           carries neither). Nothing while the owner ignores its settings panel
--                           (the Scope's Ignore settings panel, on by default); the release puts
--                           the widget back stock (the library chains its restore onto the widget's
--                           own OnRelease, and this addon sets no OnRelease of its own).
--   NS.MaybeShowSkinPicker() the first-run skin picker (LibKa0s OptionsSkinPicker 1): the Options
--                           instance's SkinPicker while the profile's `skin.pickerSeen` is false
--                           and the addon stands up; held to PLAYER_REGEN_ENABLED in combat.
--                           Answers the frame, or nil, "queued" behind another Ka0s addon's picker.
--   NS.HideSkinPicker()     takes a shown picker down (its pending preview put back) or out of the
--                           queue WITHOUT marking it seen: the stand-down, and first on every
--                           profile event; drops a held combat deferral.
--   NS.SkinPickerSpec()     the spec MaybeShowSkinPicker hands the library.
--
-- ── WHERE IT LOADS ───────────────────────────────────────────────────────────────────────────
--
-- After core/CoreSetup.lua, whose NS.Print the reload line uses (at call time), and before
-- core/WidgetsSetup.lua and every module, so the owner is registered before modules/Bar.lua builds
-- the drag strips at file load with `owner = addonName`, and before settings/General.lua reads the
-- two option lists. Nothing here reads the profile at load: RegisterOwner calls `get` once, before
-- AceDB exists, and it answers Ka0s Default; the profile's pair is applied by NS.ApplySkinChoice
-- right after NS:InitDB (core/AbsorbTracker.lua).
--
-- ── WHERE THE CHOICE LIVES ───────────────────────────────────────────────────────────────────
--
-- `profile.skin` (defaults/Profile.lua): source, skin, ignorePanel, ignoreFonts, font, texture and
-- pickerSeen, seven skip-render rows on General > Skin (settings/General.lua). The tab is the
-- library's O.AppearanceTab, so the rows exist for the defaults, the resets and the CLI.
--
-- ── WHY A ROW'S onChange PASSES ONE HALF ─────────────────────────────────────────────────────
--
-- The Skin tab and another addon's "Copy to every Ka0s addon" both call Skin:SetChoice FIRST and
-- write the store after, one half at a time. A row reaction that re-applied the whole stored pair
-- would apply the half-written one in between: a second repaint, to a skin the player never
-- picked. Applying only the row's own half against the applied choice makes each write a no-op
-- (SetChoice is idempotent), so a pick is ONE effective SetChoice and one repaint, while a bare
-- `/at set skin.skin obsidian` still repaints.

local Skin = LibStub and LibStub("LibKa0s-Skin-1.0", true)

local SOURCE_PATH, SKIN_PATH = "skin.source", "skin.skin"
local PANEL_PATH, FONTS_PATH = "skin.ignorePanel", "skin.ignoreFonts"
local FONT_PATH, TEXTURE_PATH = "skin.font", "skin.texture"
local DEFAULT = "ka0s"

NS.SKIN_SOURCE_OPTIONS = {
    { value = "ka0s", text = "Ka0s skins" },
    { value = "eui",  text = "EllesmereUI" },
}

-- The skin row's values: every registered skin, Ka0s Default first. Without the library the one
-- skin the degraded facade can draw.
NS.SKIN_OPTIONS = {}
if Skin and type(Skin.Skins) == "function" then
    for _, def in ipairs(Skin:Skins()) do
        NS.SKIN_OPTIONS[#NS.SKIN_OPTIONS + 1] = { value = def.key, text = def.label or def.key }
    end
end
if #NS.SKIN_OPTIONS == 0 then NS.SKIN_OPTIONS[1] = { value = DEFAULT, text = "Ka0s Default" } end

--- A stored value, read through the settings seam, nil before NS:InitDB.
local function stored(path)
    if not (NS.db and NS.GetSetting) then return nil end
    return NS.GetSetting(path)
end

--- The stored pair, lazily and nil-safely: Ka0s Default until the profile store exists.
function NS.SkinChoice()
    return stored(SOURCE_PATH) or DEFAULT, stored(SKIN_PATH) or DEFAULT
end

--- A stored override as the profile keeps it: the LSM key, or "" for the skin's own (false, nil, "").
local function storedKey(v)
    if type(v) == "string" and v ~= "" then return v end
    return ""
end

--- The write seam: every half through NS.SetByPath (validate, store, the [Set] line, onChange).
--- `media` is `{ font = key|false, texture = key|false }`: the Skin tab's Font and texture pick and
--- another addon's copy both hand it here, after Skin:SetOverride moved the applied pair, so each
--- row's onChange re-applies its own half as a no-op.
function NS.WriteSkinChoice(source, skin, ignore, media)
    local set = NS.SetByPath
    if not (NS.db and set) then return end
    if source ~= nil then set(SOURCE_PATH, source) end
    if skin ~= nil then set(SKIN_PATH, skin) end
    if type(ignore) == "table" then
        set(PANEL_PATH, ignore.panel == true)
        set(FONTS_PATH, ignore.fonts == true)
    end
    if type(media) == "table" then
        set(FONT_PATH, storedKey(media.font))
        set(TEXTURE_PATH, storedKey(media.texture))
    end
end

--- The stored overrides, nil-safely: each an LSM key, or false for the skin's own; false, false
--- until the profile store exists.
function NS.SkinOverride()
    if not NS.db then return false, false end
    local font, texture = storedKey(stored(FONT_PATH)), storedKey(stored(TEXTURE_PATH))
    return font ~= "" and font or false, texture ~= "" and texture or false
end

--- The stored exceptions, nil-safely: false, false until the profile store exists.
local function storedIgnore()
    if not NS.db then return false, false end
    return stored(PANEL_PATH) == true, stored(FONTS_PATH) == true
end

-- ── the first-run skin picker (LibKa0s OptionsSkinPicker 1) ──────────────────────────────────
--
-- WHEN. Once per session at login (addon:OnEnable, after the options panel is registered, so the
-- gear has a page to open), and again after every profile event (adoptProfile in
-- core/AbsorbTracker.lua), because a new, copied or reset profile carries its own `pickerSeen`.
-- Never while the addon stands down, and never in combat: a start in combat is held for the
-- PLAYER_REGEN_ENABLED edge, one target at most (the library's queue waits out combat only for
-- the NEXT owner's picker; a first call with nothing up shows at once, whatever the lockdown).
--
-- SEEN. The library calls `onClose` once per showing, by any route the player takes (Apply, its
-- close control, the gear, Escape), and once for a picker still queued behind another Ka0s addon's
-- when that addon's "Apply to all Ka0s addons" dismisses it unshown; that is the one write of
-- `skin.pickerSeen`, through NS.SetByPath. A close this addon makes itself (NS.HideSkinPicker: the
-- stand-down, a profile event) is not the player's and writes nothing.
--
-- NO EYE (the rollout's X6 / D6). This addon has no window and no test mode to preview a skin in:
-- its preview is unlocking the bars, which is a stored write (`locked`), and the player bar is
-- normally on screen already. So `onPreview` is absent and the library hides the button; a pick
-- still previews live on the drag strips, the console and the settings chrome.
--
-- PREVIEW. A pick only previews: the Skin major moves and the strips repaint, but `set`
-- (NS.WriteSkinChoice) runs only on Apply, the gear or Apply to all. The close control and Escape
-- put back the stored choice as it reads at the close (the library's revert reads `get`). A
-- profile event takes the picker down FIRST, before the new profile's skin is applied, so the new
-- profile's whole pair is what NS.ApplySkinChoice leaves worn.

local PICKER_PATH = "skin.pickerSeen"
local pickerTarget       -- the one-shot PLAYER_REGEN_ENABLED target, while a start is held
local quietClose = false -- true while NS.HideSkinPicker takes the picker down

--- The Options instance (settings/OptionsSetup.lua's NS.Helpers), read at call time: it loads
--- after this file.
local function options() return NS.Helpers end

--- The player's close: the picker seen, and nothing else. The library's put-back already wears the
--- stored choice, so the skin is not this callback's to move.
local function pickerClosed()
    if quietClose then return end
    if not (NS.db and NS.SetByPath) then return end
    NS.SetByPath(PICKER_PATH, true)
end

function NS.SkinPickerSpec()
    return {
        owner = addonName, get = NS.SkinChoice, set = NS.WriteSkinChoice,
        -- The gear's default: O.OpenOptionsPanel("general"), the key settings/General.lua gave
        -- RegisterOptionsPage, then O.SelectTab("general", "Appearance"), the Skin tab's key.
        page = "general", tab = "Appearance",
        onClose = pickerClosed,
    }
end

local function dropPickerDeferral()
    if pickerTarget then pickerTarget:UnregisterAllEvents(); pickerTarget = nil end
end

local function inCombat()
    return type(InCombatLockdown) == "function" and InCombatLockdown() == true
end

--- True while this profile has not closed the picker and the addon stands up.
local function pickerDue()
    if not (NS.db and NS.GetSetting) then return false end
    if NS.IsStoodDown and NS.IsStoodDown() then return false end
    return NS.GetSetting(PICKER_PATH) == false
end

function NS.HideSkinPicker()
    dropPickerDeferral()
    local O = options()
    if not (O and type(O.HideSkinPicker) == "function") then return end
    quietClose = true
    local ok, err = pcall(O.HideSkinPicker)
    quietClose = false
    if not ok then error(err, 0) end
end

--- Show the picker when this profile has not seen it: answers the library's frame, or nil,
--- "queued" while another Ka0s addon's picker is up (it shows when that one closes), or nil.
function NS.MaybeShowSkinPicker()
    local O = options()
    if not (O and type(O.SkinPicker) == "function") then return nil end
    if not pickerDue() then
        NS.HideSkinPicker()
        return nil
    end
    if inCombat() then
        if pickerTarget then return nil end
        pickerTarget = NS.NewBusTarget and NS.NewBusTarget()
        if not pickerTarget then return nil end
        NS.SafeRegisterEvent(pickerTarget, "PLAYER_REGEN_ENABLED", function()
            dropPickerDeferral()
            NS.MaybeShowSkinPicker()
        end, NS.State and NS.State.rejectedEvents)
        return nil
    end
    return O.SkinPicker(NS.SkinPickerSpec())
end

-- ── the degraded arm ─────────────────────────────────────────────────────────────────────────

if not Skin then
    local function noop() end
    local S = { owner = addonName, apiVersion = 3, FROM_SKIN = "@skin" }
    -- Every vocabulary name answers, as a no-op that never raises: this addon draws no window
    -- chrome of its own, so there is no pre-library look a primitive would have to repeat. The
    -- list is LibKa0s-Skin-1.0's VOCAB; tests/test_surface_parity.lua holds this table to the live
    -- facade key for key.
    for _, name in ipairs({
        "Shell", "Panel", "Inset", "FadeRegions", "FadeNineSlice", "Button", "WhiteButtonLabel",
        "StateButtonLabel", "EditBox", "Checkbox", "Dropdown", "ScrollBar", "Tab", "SetTabSelection",
        "CloseButton", "PageButton", "SquareIcon", "SortHeaderBar", "Font", "White", "ApplyBarFill",
        "GetAccentColor", "GetPanelColor", "GetFont",
        "TitleBar", "Divider", "Footer", "Card", "Slider", "NavItem", "Drawer", "ListRow", "MenuFrame",
        "Tooltip", "Strip", "Cover", "Text", "ChartStyle", "BarStyle", "IconBorder", "GlowColor",
        "BarTexture",
    }) do S[name] = noop end

    -- No skin to read: every token answers nil ("leave the host's"), so a value resolved against
    -- one is the host's own, the look this addon drew before skins.
    S.Token = function() return nil end
    S.Color = function() return nil end
    S.Resolve = function(_, value)
        if value == S.FROM_SKIN then return nil end
        return value
    end
    S.OnLooksChanged = function(fn) return fn end   -- the skin never changes without the library
    S.IsEnabled = function() return false end
    S.GetStyle = function() return "ka0s:" .. DEFAULT end

    NS.Skin = S
    function NS.ApplySkinChoice() return false, false end
    function NS.ApplySkinIgnore() return false, false end
    function NS.SkinFontsIgnored() return false end
    function NS.ApplySkinOverride() return false end
    -- Nothing to paint an AceGUI row with: stock AceGUI, as the client draws it.
    function NS.SkinPaintAce() return false end
    function NS.SkinPaintAceTree() return 0 end
    return
end

-- ── the live seam ────────────────────────────────────────────────────────────────────────────

NS.Skin = Skin:For(addonName)
Skin:RegisterOwner(addonName, {
    label = NS.Constants and NS.Constants.BRAND or addonName,
    get = NS.SkinChoice,
    set = NS.WriteSkinChoice,
})

-- The HUD follows a skin switch, an override and an exception change: the library fires
-- OnLooksChanged after each, and the bars repaint through the one appearance path every other
-- restyle takes (modules/Display.lua resolves the media again, core/Data.lua). The bars are not
-- recorded frames, so nothing else would repaint them. A stood-down addon's bus reaches nobody.
NS.Skin.OnLooksChanged(function()
    if NS.bus and NS.MSG then NS.bus:SendMessage(NS.MSG.APPEARANCE) end
end)

-- The AceGUI rows (SkinAce.lua). NS.AceGUI is normally the Options instance's owner proxy, which
-- paints on Create already; PaintAce for the same owner repaints in place, so a host call after it
-- is harmless, and it is what paints a widget acquired any other way (AceConfigDialog's, on the
-- Profiles page). Each guards on the member, so a copy whose SkinAce secondary did not attach
-- paints nothing.
function NS.SkinPaintAce(widget)
    if type(Skin.PaintAce) ~= "function" then return false end
    return Skin:PaintAce(addonName, widget)
end

function NS.SkinPaintAceTree(container)
    if type(Skin.PaintAceTree) ~= "function" then return 0 end
    return Skin:PaintAceTree(addonName, container)
end

-- The one line a reload request earns on the path that has no popup of its own (a profile event
-- or a `/at set` leaving an EllesmereUI that painted this session). The Skin tab raises the
-- library's popup for its own picks.
local RELOAD_LINE = "Reload your interface (/reload) to finish changing the skin."

--- The applied "Ignore fonts". The library's Resolve and Token never read it (only P.font, the
--- primitives' path, does), so the HUD's own font getter asks here (core/Data.lua).
function NS.SkinFontsIgnored()
    if type(Skin.GetIgnore) ~= "function" then return false end
    local _, fonts = Skin:GetIgnore(addonName)
    return fonts == true
end

function NS.ApplySkinIgnore(panel, fonts)
    if type(Skin.SetIgnore) ~= "function" then return false, false end
    if panel == nil and fonts == nil then panel, fonts = storedIgnore() end
    local changed, reload = Skin:SetIgnore(addonName, panel, fonts)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    return changed, reload
end

--- No argument applies the stored overrides; a nil half keeps that half, false or "" clears it
--- (the skin's own). A copy without SetOverride (a Skin major before minor 6) moves nothing.
function NS.ApplySkinOverride(font, texture)
    if type(Skin.SetOverride) ~= "function" then return false end
    if font == nil and texture == nil then font, texture = NS.SkinOverride() end
    return Skin:SetOverride(addonName, font, texture)
end

--- No argument applies the stored pair AND the stored exceptions and overrides (addon:OnInitialize,
--- the profile events); a nil half keeps that half and leaves the rest alone (each Skin tab row).
function NS.ApplySkinChoice(source, skin)
    local whole = source == nil and skin == nil
    if whole then source, skin = NS.SkinChoice() end
    local changed, reload = Skin:SetChoice(addonName, source, skin)
    if reload and NS.Print then NS.Print(RELOAD_LINE) end
    if whole then
        NS.ApplySkinIgnore()
        NS.ApplySkinOverride()
    end
    return changed, reload
end
