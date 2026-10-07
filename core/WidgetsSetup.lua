local _, NS = ...

-- core/WidgetsSetup.lua — the LibKa0s-Widgets-1.0 seam (library-stack-§7, testing-§8).
--
-- The major is resolved ONCE, here, and published as NS.Widgets: the live library table when
-- libs/LibKa0s loaded, or a stub when it did not. modules/Bar.lua and modules/Display.lua capture
-- NS.Widgets as a file-scope upvalue at load, so this file has to load before modules\Bar.lua (the
-- TOC line says so). Until AT-02 each of those two modules called LibStub for the major itself and
-- carried its own nil-guard; the guards now reduce to the stub's contract below.
--
-- THE STUB CARRIES EXACTLY THE MEMBERS THE ADDON REACHES, and no more (tests/test_surface_parity.lua
-- derives that set from the source and pins it on both arms):
--
--   * DragHandle — a function answering nil. NS.CreateBar keeps `bar.handle` nil, so a build with
--     no LibKa0s draws no strip, and the bar body's own drag is the one grab point left. That is the
--     widget's documented degradation (LibKa0s Widgets docs, "Degraded"); a hand-built strip here
--     would be the second copy the widget exists to delete.
--   * DRAG_HANDLE — a table whose HEIGHT and GAP are both 0, rather than nil. modules/Display.lua
--     adds the two into HANDLE_ROOM, so zero sizes give HANDLE_ROOM = 0 (no strip, no room kept for
--     one in the default stack) with no nil-guard at the consumer. The live table's other members
--     (RESERVE, HELP_HIT, CLOSE_GAP) are read only off a strip that exists, which the stub never
--     builds, so it does not carry them.

local lib = LibStub and LibStub("LibKa0s-Widgets-1.0", true)

if lib then
    NS.Widgets = lib
    return
end

NS.Widgets = {
    DragHandle  = function() return nil end,
    DRAG_HANDLE = { HEIGHT = 0, GAP = 0 },
}
