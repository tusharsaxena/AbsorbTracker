-- AbsorbTracker: settings/Font.lua
--
-- Font sub-page: face, size, outline.
--
-- Layout produces:
--     [Font Face]    | [Font Size]
--     [Font Outline]                              (solo: 3rd row)

local addonName, NS = ...

local flatDefaults = NS.flatDefaults

local fontFlagOptions = {
    [""]                          = "None",
    ["OUTLINE"]                   = "Outline",
    ["THICKOUTLINE"]              = "Thick Outline",
    ["MONOCHROME"]                = "Monochrome",
    ["MONOCHROME, OUTLINE"]       = "Monochrome, Outline",
    ["MONOCHROME, THICKOUTLINE"]  = "Monochrome, Thick Outline",
}

local fontFlagSorting = {
    "", "OUTLINE", "THICKOUTLINE",
    "MONOCHROME", "MONOCHROME, OUTLINE", "MONOCHROME, THICKOUTLINE",
}

NS.RegisterSchemaRows({
    {
        path    = "font",
        page    = "font",
        group   = "Typography",
        order   = 10,
        type    = "string",
        label   = "Font Face",
        desc    = "LibSharedMedia font used for the absorb amount text.",
        default = flatDefaults.font,
        dialogControl = "LSM30_Font",
        values = NS.Helpers.LSMValues("font"),
    },
    {
        path    = "fontSize",
        page    = "font",
        group   = "Typography",
        order   = 20,
        type    = "number",
        label   = "Font Size",
        desc    = "Absorb-amount text size in pixels.",
        default = flatDefaults.fontSize,
        min = 6, max = 32, step = 1,
    },
    {
        path    = "fontFlags",
        page    = "font",
        group   = "Typography",
        order   = 30,
        type    = "string",
        label   = "Font Outline",
        desc    = "Outline / monochrome flags applied to the absorb-amount text.",
        default = flatDefaults.fontFlags,
        values  = fontFlagOptions,
        sorting = fontFlagSorting,
        solo    = true,
    },
})

local function build(mainCategory)
    if not (Settings and Settings.RegisterCanvasLayoutSubcategory) then
        return nil
    end

    local H   = NS.Helpers
    local ctx = H.CreatePanel("AbsorbTrackerFontPanel", "Font", {
        pageKey         = "font",
        defaultsButton  = true,
        defaultsTooltip = "Restore every Font setting on this profile to its addon default.",
    })
    -- Parked, not wired: the Defaults button does not exist yet — it is built
    -- on first OnShow (see Helpers.EnsureDefaultsButton).
    ctx.panel.defaultsOnClick = function()
        H.RestoreDefaults("font", ctx)
    end

    local rendered = false
    ctx.panel:SetScript("OnShow", function()
        H.EnsureDefaultsButton(ctx.panel)
        if rendered then return end
        rendered = true
        H.RenderSchema(ctx, "font")
    end)

    return Settings.RegisterCanvasLayoutSubcategory(
        mainCategory, ctx.panel, "Font")
end

if NS.RegisterOptionsPage then
    NS.RegisterOptionsPage("font", "Font", build)
end
