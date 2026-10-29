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
    function NS.ApplySkinOverride() return false end
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

-- The one line a reload request earns on the path that has no popup of its own (a profile event
-- or a `/at set` leaving an EllesmereUI that painted this session). The Skin tab raises the
-- library's popup for its own picks.
local RELOAD_LINE = "Reload your interface (/reload) to finish changing the skin."

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
