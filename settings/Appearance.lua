-- AbsorbTracker: settings/Appearance.lua
--
-- The one per-unit appearance page. It replaces the three that used to stand beside each other --
-- settings/Bar.lua, settings/Border.lua and settings/Font.lua -- and the reason is the Unit picker,
-- not the row count: each of those pages carried its OWN copy of it, `ctx.unit` is per-panel state,
-- and so styling the target bar meant picking "Target" three times. options-ui-§14 says the picker
-- belongs in the page banner and that there must be exactly ONE of it; one banner over one page is
-- the shape that rule describes.
--
-- The page draws (settings/UnitPanel.lua does the drawing):
--
--     [ Unit v ] [x] Enable this unit [x] Link to Player [ Copy from Player ]
--                                     ^ the band (chrome), options-ui-§14: ONE row, four cells;
--                                       the last two are target / focus only, empty for player
--     ------------------------------------------
--     [ Bar ][ Text ]                                        <- the tab strip (chrome), options-ui-§13
--
--     Bar    -- Size --
--            [Bar width (px)]         [Bar height (px)]
--            -- Fill --
--            [Bar texture]            [Bar opacity]
--            [Bar color]              [Use class color]
--            [Use the skin's texture]
--            -- Background --
--            [Background texture]
--            [Background color]       [Use class color]
--            -- Border --
--            [Border style]           [Border thickness (px)]
--            [Border color]           [Use class color]
--            [Use the skin's border]
--     Text   [Font]                   [Font size]
--            [Font color]             [Use class color]
--            [Font flags]             [Font shadow]
--            [Use the skin's font]
--
-- FOLLOWING THE SKIN (skinning-§6). Each composer takes `fromSkin = true` and appends its
-- "Use the skin's ..." companion on a line of its own, default ON (defaults/Profile.lua). While a
-- companion is on, the picker it governs is disabled and shows the skin's value; the stored pick
-- waits for the player to turn it off. Two rows the composers do not govern follow it too, by the
-- composer's own two fields (`disabledIf`, `skinValue`): the background texture under the bar
-- texture's companion (the skin has no background-texture token, DECISIONS D3) and the border
-- thickness under the border's (a skin's "None" or flat 1 px edge at the stored 12 px would leave
-- an empty inset, D4). The colors never follow the skin (X4): they stay the player's.
--
-- THE BLOCKS ARE COMPOSED, NOT TYPED OUT (options-ui-§16). H.BarGroup, H.BorderGroup and
-- H.FontGroup emit the canonical block from one declaration each, and H.ColorPair emits the
-- Background subsection's swatch and its companion. A hand-written copy of any of them is anti-pattern #73:
-- the composer is what makes the order, the labels, the ranges and the class-color companion
-- identical in nine addons without nine people agreeing to be careful.
--
-- NOTHING STORED MOVED. `keys` and `defaults` carry this addon's own paths and starting values into
-- the composer, so `units.<unit>.border` is still `border` (not `borderStyle`) and
-- `useClassColorText` is still `useClassColorText` (not `useClassColorFont`). What changed is what
-- is DECLARED and how it is laid out -- labels, tooltips, ranges and line breaks.
--
-- WHAT THE COMPOSERS ADDED. `fontShadow` is a new stored key: the canonical font block has six rows
-- and this addon had five. It is honored in modules/Display.lua's appearance pass, beside SetFont,
-- because a setting that is declared and not honored is worse than one that is absent.
--
-- WHAT WENT. `barTexture` carried `solo = true` purely to keep the Bar tab's pairs from splitting
-- across lines -- a parity count done by hand, which any added row would have broken silently. The
-- composer's `startsLine` does that job properly and by construction, so the flag is gone. So are
-- this file's private `fontFlagOptions` / `fontFlagSorting` tables: the flag set is H.FONT_FLAGS
-- now, which is the whole point of having one.
--
-- ONE TAB PER STYLED SURFACE (item 020, ABS-L03, L04, L-new2; XC-19). The bar is one surface, so it
-- is one tab, Bar, with a subsection heading per part of it -- Size, Fill (the composed bar block),
-- Background, Border -- because options-ui-§7 asks for a heading wherever a tab mixes kinds, and
-- §16's last bullet allows composed groups to share a tab under their own headings. Size and fill
-- are read together, and a fill color is chosen against the background and border it sits in, so
-- one tab replaces four clicks. No heading repeats the tab's name, which §7 forbids.
--
-- THE BACKGROUND SUBSECTION IS NOT A BAR GROUP, and options-ui-§16 says so: a group over a background
-- takes the swatch and its companion and nothing else. Its texture row survives because this addon's
-- backdrop genuinely HAS a fill texture (modules/Display.lua sets `backdropInfo.bgFile` from it) --
-- it is a control wired to something, not a texture picker invented to fill a heading out.
--
-- TAB ORDER IS DECLARATION ORDER; SUBSECTION ORDER IS `order`. H.RenderTabbedSchema partitions a
-- page's rows by `group` in the order the rows were registered, so the array below IS the strip.
-- Inside a group SchemaForPage sorts by `order`, so each subsection takes its own hundred (Size
-- 10-20, Fill 100+, Background 200+, Border 300+) and the runs cannot interleave -- an interleaved
-- subsection prints its heading twice. tests/test_schema.lua pins the four runs.
--
-- Size leads because dimensions are what a player opens this page for; Fill, Background and Border
-- follow front to back; Text is last because it is set once. The three colored surfaces plus Text
-- all run the SAME two lines -- `[<surface> color] [Use class color]` -- so a reader who has learned
-- one has learned four, and the headings tell the two "Use class color" rows on Bar apart.
--
-- Every row is generated once per unit in NS.Units.LIST: the path is prefixed with `units.<unit>.`
-- and tagged `unit = unit`, so Helpers.RenderUnitPanel can filter the page to the selected unit
-- (settings/Schema.lua: SchemaForPage). The `default =` values come from NS.unitDefaults so all
-- three units share one canonical default.

local _, NS = ...

local unitDefaults = NS.unitDefaults

local H = NS.Helpers

local PAGE = "appearance"

-- NO `disabledIf` ON ANY COLOR ROW, and that is a reversal worth stating.
--
-- Each of these four swatches used to gray itself out while its "Use class color" partner was on,
-- and each toggle's own desc advertised that it would. The argument was that a control the code is
-- not currently reading should say so. What it cost is the ordinary order of operations: setting a
-- color BEFORE deciding you want the class one is normal, and a grayed swatch makes that a
-- two-visit job -- turn the toggle off, set the color, turn the toggle back on.
--
-- The half of the old argument that survives is that the row IS unread under the other mode, and
-- that is what the tooltip says now instead of graying the widget. The alpha channel was always live
-- (core/Data.lua's color getters take the class RGB and keep the swatch's `a`), so the swatch was
-- never fully dead even under the old design -- which is the clearest evidence the graying was
-- overstating the case. The composers carry that sentence for us now (H.CLASS_COLOR_NOTE), and
-- options-ui-§17 forbids `disabledIf` on a color row outright. `disabledIf` itself is untouched, and
-- is a LibKa0s-Options-1.0 feature this addon simply no longer asks for; tests/test_widgets.lua
-- still pins it against a synthetic row.

-- WHICH CLASS, declared rather than inferred (options-ui-§17). All four surfaces on this page paint
-- one tracked unit's bar, so all four resolve to THAT unit's class -- not the player's, which is
-- what all four did before this pass. The path prefix is not what decides it and could not be: a
-- control stored under `units.<unit>.` that drew the player's own spells would be player-scoped.
-- This declaration is what an audit reads, and core/Data.lua's getters pass the same unit token.
local function classColorFor(unit)
    return { source = "unit", unit = unit }
end

-- The composers return plain arrays of ordinary schema rows and stamp nothing of ours on them.
-- `unit` is this addon's own field -- settings/Schema.lua's SchemaForPage filters the page on it --
-- so it is added here, once, rather than wished for upstream.
local function appendBlock(rows, unit, block)
    for _, row in ipairs(block) do
        row.unit = unit
        rows[#rows + 1] = row
    end
end

--- Put `row` under the composer companion at `companion`, as the composer governs its own picker:
--- disabled while the companion is on, showing the skin's `token` meanwhile. The stored value is
--- untouched; core/Data.lua draws the token while the companion is on.
local function followsSkin(row, companion, token)
    row.disabledIf = companion
    row.skinValue = function()
        if NS.GetSetting(companion) ~= true then return nil end
        local S = NS.Skin
        return S and type(S.Resolve) == "function" and S.Resolve(token, nil, true) or nil
    end
    return row
end

--- The row at `path` in a composed block.
local function rowAt(block, path)
    for _, row in ipairs(block) do
        if row.path == path then return row end
    end
end

local function addUnitRows(unit)
    local p = "units." .. unit .. "."
    local classColor = classColorFor(unit)

    -- ── Bar > Size ────────────────────────────────────────────────────────────
    --
    -- Hand-written, and legitimately so: options-ui-§16 names three canonical blocks and a
    -- width/height pair is none of them, so there is no composer to reach for. The tooltips name
    -- the addon-wide multiplier (options-ui-§21, XC-11).
    local rows = {
        {
            path     = p .. "barWidth",
            page     = PAGE,
            unit     = unit,
            group    = "Bar",
            subgroup = "Size",
            order    = 10,
            type    = "number",
            label   = "Bar width (px)",
            desc    = "Width of this bar, in pixels. Multiplied by Master scale on General > Master controls.",
            default = unitDefaults.barWidth,
            min = 50, max = 500, step = 1, fmt = "%d px",
        },
        {
            path     = p .. "barHeight",
            page     = PAGE,
            unit     = unit,
            group    = "Bar",
            subgroup = "Size",
            order    = 20,
            type    = "number",
            label   = "Bar height (px)",
            desc    = "Height of this bar, in pixels. Multiplied by Master scale on General > Master controls.",
            default = unitDefaults.barHeight,
            min = 10, max = 100, step = 1, fmt = "%d px",
        },
    }

    -- ── Bar > Fill ────────────────────────────────────────────────────────────
    --
    -- The canonical bar block: [Bar texture][Bar opacity] / [Bar color][Use class color]. Every leaf
    -- name the composer derives already IS this addon's stored path, so no `keys` is needed.
    --
    -- `barAlpha` is the PER-UNIT opacity and stays here. It is not Master opacity, which is the
    -- addon-wide row on the General page's Master controls tab (options-ui-§15 forbids conflating
    -- the two); NS.GetBarAlpha multiplies them.
    --
    -- ITS TOOLTIP IS OURS (compose minor 10, `tooltips`, ABS-L12). The canonical words describe the
    -- fill's opacity, but modules/Display.lua applies `barAlpha` through SetAlpha on the whole bar
    -- frame -- fill, background, border and text. The label stays canonical.
    appendBlock(rows, unit, H.BarGroup({
        prefix     = p,
        page       = PAGE,
        group      = "Bar",
        subgroup   = "Fill",
        order      = 100,
        classColor = classColor,
        fromSkin   = true,
        tooltips   = {
            barAlpha = "Opacity of this whole bar (fill, background, border, text). "
                .. "Multiplied by Master opacity on General > Master controls.",
            barTextureFromSkin = "Draw this bar's fill and background in the skin's texture. "
                .. "The two texture pickers are not read while this is on.",
        },
        defaults   = {
            barTexture         = unitDefaults.barTexture,
            barAlpha           = unitDefaults.barAlpha,
            barColor           = unitDefaults.barColor,
            useClassColorBar   = unitDefaults.useClassColorBar,
            barTextureFromSkin = unitDefaults.barTextureFromSkin,
        },
    }))

    -- ── Bar > Background ──────────────────────────────────────────────────────
    --
    -- The texture is this addon's own row, declared ahead of the pair rather than handed over as the
    -- composer's `extra`: an extra is appended AFTER the mandated rows, and the texture reads first
    -- here for the same reason it does in Fill. The swatch carries `startsLine`, so the pair
    -- lands on its own line whatever precedes it.
    rows[#rows + 1] = followsSkin({
        path     = p .. "bgTexture",
        page     = PAGE,
        unit     = unit,
        group    = "Bar",
        subgroup = "Background",
        order    = 200,
        type    = "string",
        label   = "Background texture",
        desc    = "Texture drawn behind the fill, across the whole bar. Not read while "
            .. "Use the skin's texture (Fill) is on.",
        default = unitDefaults.bgTexture,
        dialogControl = "LSM30_Statusbar",
        values = H.LSMValues("statusbar"),
    }, p .. "barTextureFromSkin", "bar.texture")
    appendBlock(rows, unit, H.ColorPair({
        prefix       = p,
        page         = PAGE,
        group        = "Bar",
        subgroup     = "Background",
        order        = 210,
        key          = "bgColor",
        companionKey = "useClassColorBg",
        label        = "Background color",
        classColor   = classColor,
        defaults     = {
            bgColor         = unitDefaults.bgColor,
            useClassColorBg = unitDefaults.useClassColorBg,
        },
    }))

    -- ── Bar > Border ──────────────────────────────────────────────────────────
    --
    -- No `show = true`: this addon has no "Show border" toggle, and §16 only permits the composer to
    -- prepend one where the addon already has it. Inventing one would be a second control over a
    -- surface the border style's own "None" entry already turns off.
    --
    -- `keys` keeps the stored path `units.<unit>.border`, which is what every profile on disk holds
    -- and what `/at set units.player.border` names.
    --
    -- `fromSkin = true`: the companion is stored beside the picker, `units.<unit>.borderFromSkin`,
    -- and defaulted through its canonical leaf, `borderStyleFromSkin`.
    local border = H.BorderGroup({
        prefix     = p,
        page       = PAGE,
        group      = "Bar",
        subgroup   = "Border",
        order      = 300,
        classColor = classColor,
        fromSkin   = true,
        keys       = { borderStyle = "border" },
        tooltips   = {
            borderSize = "Border edge width, in pixels. Not read while Use the skin's border is on: "
                .. "the skin's thickness is drawn.",
            borderStyleFromSkin = "Draw this border in the skin's border style and thickness. The "
                .. "border style and thickness pickers are not read while this is on.",
        },
        defaults   = {
            borderStyle         = unitDefaults.border,
            borderSize          = unitDefaults.borderSize,
            borderColor         = unitDefaults.borderColor,
            useClassColorBorder = unitDefaults.useClassColorBorder,
            borderStyleFromSkin = unitDefaults.borderFromSkin,
        },
    })
    local size = rowAt(border, p .. "borderSize")
    if size then followsSkin(size, p .. "borderFromSkin", "bar.borderSize") end
    appendBlock(rows, unit, border)

    -- ── Text ──────────────────────────────────────────────────────────────────
    --
    -- The canonical font block, six rows over three lines. `keys` keeps `useClassColorText`, the path
    -- this addon has always stored the companion under; `fontShadow` is the one leaf that had no
    -- stored key at all before this pass.
    appendBlock(rows, unit, H.FontGroup({
        prefix     = p,
        page       = PAGE,
        group      = "Text",
        order      = 10,
        classColor = classColor,
        fromSkin   = true,
        -- "From skin" leads Font flags and is its default (OptionsCompose minor 14, ruling D-07):
        -- with fromSkin, the minimum font setting every element carries.
        flagsFromSkin = true,
        keys       = { useClassColorFont = "useClassColorText" },
        defaults   = {
            font              = unitDefaults.font,
            fontSize          = unitDefaults.fontSize,
            fontColor         = unitDefaults.fontColor,
            useClassColorFont = unitDefaults.useClassColorText,
            fontFlags         = unitDefaults.fontFlags,
            fontShadow        = unitDefaults.fontShadow,
            fontFromSkin      = unitDefaults.fontFromSkin,
        },
    }))

    -- The mirror flag ("Link to Player"). Not rendered in the page body — Helpers.RenderUnitPanel
    -- draws it as a band checkbox above the tab strip — but kept in the schema so
    -- `/at set units.focus.mirror false` works. The player is the mirror SOURCE and gets no row.
    -- One word for the state, "link" (ABS-L10, XC-15), and the band checkbox reads this row's
    -- label and desc, so `/at list` and the panel say the same thing.
    --
    -- IT CARRIES A GROUP AND STILL DRAWS NO TAB. options-ui-§13 wants every row attributable to a
    -- section, and a group-less row is the authoring defect the library now reports; but this row's
    -- widget is the bespoke mirror header, not a tab's content, so settings/UnitPanel.lua hands
    -- RenderTabbedSchema `untabbedSkipRender` (OptionsTabs minor 8), which keeps an all-skipRender
    -- group off the strip. Naming the subject and drawing no
    -- tab for it is the honest pair — the alternative was a whole tab holding one invisible row.
    if unit ~= "player" then
        rows[#rows + 1] = {
            path       = p .. "mirror",
            page       = PAGE,
            unit       = unit,
            alwaysPerUnit = true,
            skipRender = true,
            group      = "Link",
            order      = 20,
            type       = "bool",
            label      = "Link to Player",
            desc       = "Use the Player bar's look for this bar (all appearance settings). Position and enable stay this bar's own.",
            default    = true,
        }
    end

    NS.RegisterSchemaRows(rows)
end

for _, unit in ipairs(NS.Units.LIST) do addUnitRows(unit) end

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local ctx = H.CreatePanel("AbsorbTrackerAppearancePanel", "Appearance", {
        pageKey         = PAGE,
        defaultsButton  = true,
        -- The second sentence is options-ui-§14's disclosure for the per-unit enables this page's
        -- band draws but General's Defaults resets (ABS-L14).
        defaultsTooltip = "Restore every Appearance setting on this profile to its addon default, "
            .. "on every unit. Which bars are shown is reset by the General page's Defaults.",
    })
    -- Parked, not wired: the Defaults button does not exist yet — it is built
    -- on first OnShow (see Helpers.EnsureDefaultsButton).
    ctx.panel.defaultsOnClick = function()
        H.RestoreDefaults(PAGE, ctx)
    end

    -- Declared THROUGH SetRenderer rather than a hand-wired OnShow (options-ui-§11). The library
    -- owns that script now: it builds the Defaults button and, in combat, covers the page and draws
    -- nothing until PLAYER_REGEN_ENABLED, refusing writes, Defaults and tab switches meanwhile; the
    -- Settings window is never closed (the library's combat lock, options-ui-§2). That lock is the
    -- point -- the Blizzard AddOns sidebar opens a canvas without going anywhere near
    -- OpenOptionsPanel, so this page was reachable mid-pull while docs/settings-panel.md described
    -- a gate that could not see it.
    --
    -- RenderUnitPanel is safe to be the renderer because it was always written to be re-run: the
    -- picker and the tab strip both call it, and it opens with Helpers.ClearScroll and drains the
    -- chrome ledger, so nothing stacks. SetRenderer simply narrows WHEN it runs unprompted --
    -- first show, and again on the next show after a refresh marked the page dirty while hidden.
    H.SetRenderer(ctx, function(c)
        H.RenderUnitPanel(c, PAGE)
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "Appearance")
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage(PAGE, "Appearance", build)
end
