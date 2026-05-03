-- AbsorbTracker: Options/Bar.lua
--
-- Bar sub-page: dimensions, fill texture/color, background texture/color.
-- Class-color toggles use disabledIf to grey out the matching color
-- picker when their toggle is on.
--
-- Layout produces:
--     [Bar Width]          | [Bar Height]
--     [Bar Texture]        | [Bar Color]
--     [Use Class Color]
--     [Background Texture] | [Background Color]
--     [Use Class Color]

local AddonName, AddonTable = ...

local flatDefaults = AddonTable.flatDefaults

AddonTable.RegisterSchemaRows({
    {
        path    = "barWidth",
        page    = "bar",
        group   = "Size",
        order   = 10,
        type    = "number",
        label   = "Bar Width (in px)",
        desc    = "Width of the absorb bar in pixels.",
        default = flatDefaults.barWidth,
        min = 50, max = 500, step = 1, fmt = "%d px",
    },
    {
        path    = "barHeight",
        page    = "bar",
        group   = "Size",
        order   = 20,
        type    = "number",
        label   = "Bar Height (in px)",
        desc    = "Height of the absorb bar in pixels.",
        default = flatDefaults.barHeight,
        min = 10, max = 100, step = 1, fmt = "%d px",
    },

    {
        path    = "barTexture",
        page    = "bar",
        group   = "Bar Fill",
        order   = 10,
        type    = "string",
        label   = "Bar Texture",
        desc    = "LibSharedMedia statusbar texture used for the bar fill.",
        default = flatDefaults.barTexture,
        dialogControl = "LSM30_Statusbar",
        values = AddonTable.Helpers.LSMValues("statusbar"),
    },
    {
        path     = "barColor",
        page     = "bar",
        group    = "Bar Fill",
        order    = 20,
        type     = "color",
        label    = "Bar Color",
        desc     = "RGBA fill color for the bar (only used when Use Class Color is off).",
        default  = flatDefaults.barColor,
        hasAlpha = true,
        disabledIf = "useClassColorBar",
    },
    {
        path    = "useClassColorBar",
        page    = "bar",
        group   = "Bar Fill",
        order   = 30,
        type    = "bool",
        label   = "Use Class Color",
        desc    = "Use your class color for the bar fill. Greys out the Bar Color picker.",
        default = flatDefaults.useClassColorBar,
        solo   = true,
    },

    {
        path    = "bgTexture",
        page    = "bar",
        group   = "Background",
        order   = 10,
        type    = "string",
        label   = "Background Texture",
        desc    = "LibSharedMedia statusbar texture drawn behind the bar fill.",
        default = flatDefaults.bgTexture,
        dialogControl = "LSM30_Statusbar",
        values = AddonTable.Helpers.LSMValues("statusbar"),
    },
    {
        path     = "bgColor",
        page     = "bar",
        group    = "Background",
        order    = 20,
        type     = "color",
        label    = "Background Color",
        desc     = "RGBA color drawn behind the bar (only used when Use Class Color is off).",
        default  = flatDefaults.bgColor,
        hasAlpha = true,
        disabledIf = "useClassColorBg",
    },
    {
        path    = "useClassColorBg",
        page    = "bar",
        group   = "Background",
        order   = 30,
        type    = "bool",
        label   = "Use Class Color",
        desc    = "Use a darkened class color for the background. Greys out the Background Color picker.",
        default = flatDefaults.useClassColorBg,
        solo   = true,
    },
})

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local H   = AddonTable.Helpers
    local ctx = H.CreatePanel("AbsorbTrackerBarPanel", "Bar", {
        pageKey         = "bar",
        defaultsButton  = true,
        defaultsTooltip = "Restore every Bar setting on this profile to its addon default.",
    })
    if ctx.panel.defaultsBtn then
        ctx.panel.defaultsBtn:SetCallback("OnClick", function()
            H.RestoreDefaults("bar", ctx)
        end)
    end

    local rendered = false
    ctx.panel:SetScript("OnShow", function()
        if rendered then return end
        rendered = true
        H.RenderSchema(ctx, "bar")
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "Bar")
end

if AddonTable.RegisterOptionsPage then
    AddonTable.RegisterOptionsPage("bar", "Bar", build)
end
