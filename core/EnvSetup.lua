-- core/EnvSetup.lua — the LibKa0s-Env-1.0 seam: where this addon's own TOC manifest is read
-- (library-stack-§7).
--
-- ---------------------------------------------------------------------------
-- WHAT THIS REPLACED
-- ---------------------------------------------------------------------------
--
-- The whole of core/Compat.lua, which is why that file is gone rather than emptied. It held one
-- function, `Compat.GetAddOnMetadata`, and its own header called itself "the single seam for the
-- deprecated addon-metadata API". The seam is still single; it just lives in the library now, and a
-- shim file kept alive with nothing in it is a place for the next shim to land without anyone
-- asking whether it should.
--
-- That reader was written ELEVEN times across nine addons before the library had it: six copies in
-- a core/Compat.lua, in four different spellings, and five more inlined straight at the call site
-- where no audit of the shim files would ever have found them. Not one of the eleven behaved
-- differently from any other, which is precisely what made it the library's business rather than
-- any addon's.
--
-- ---------------------------------------------------------------------------
-- WHY THE LIBRARY HAS TO BE TOLD OUR NAME
-- ---------------------------------------------------------------------------
--
-- Same reason core/MediaSetup.lua passes it, and it is the one thing the library cannot get right
-- on its own: LibKa0s is VENDORED, so a copy cannot know which addon folder it sits in. `addonName`
-- is the FIRST VARARG every TOC-loaded file gets — not the `## Title`, not the chat prefix, and not
-- a hand-typed literal. Here those read "AbsorbTracker", "Ka0s Absorb Tracker" and "[AT]", and only
-- the first is the folder. A wrong name reads some other addon's manifest, or none at all, and
-- answers nil without raising a thing.
--
-- ---------------------------------------------------------------------------
-- WHAT A DEGRADED INSTALL GETS
-- ---------------------------------------------------------------------------
--
-- Exactly what this addon got before the library existed. Both helpers fall back to the same ladder
-- the deleted shim ran — C_AddOns first, the deprecated global second, nil last — so an install
-- missing LibKa0s still reads its own TOC for `/at version` and for the About page's Notes line.
-- That is why the fallbacks are written out rather than left to answer nil: this is a seam, not a
-- feature. tests/test_envsetup.lua drives that arm through tests/degraded_env.lua, as a real load
-- with libs/LibKa0s/*.lua absent rather than as a hand-stub.
--
-- ---------------------------------------------------------------------------
-- WHAT THE SEAM MUST NOT CHANGE
-- ---------------------------------------------------------------------------
--
-- Any answer. The deleted shim already agreed with the library rung for rung, so a difference in
-- what comes back here is a defect in the adoption rather than an improvement.
--
-- Nothing here is resolved at load beyond the LibStub lookup, so this file's TOC position is
-- conventional rather than load-bearing — unlike core/MediaSetup.lua's, which is, and says so.

local addonName, NS = ...

local Env = LibStub and LibStub("LibKa0s-Env-1.0", true)

--- One field of this addon's TOC manifest, or nil.
---
--- NIL IS A REAL ANSWER, twice over: the library may be absent AND the client may expose no reader
--- at all, which is exactly what a headless run looks like. A field the TOC does not carry also
--- answers nil on a perfectly healthy client. Callers that need a value supply their own —
--- settings/About.lua prints "" for an unreadable Notes.
---
--- @param field string  a TOC key: "Version", "Title", "Notes", "Author", …
--- @return string|nil
function NS.Meta(field)
    if Env then return Env.GetAddOnMetadata(addonName, field) end
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        return C_AddOns.GetAddOnMetadata(addonName, field)
    end
    if GetAddOnMetadata then
        return GetAddOnMetadata(addonName, field)
    end
    return nil
end

--- This addon's version string, preferring the TOC over the fallback constant. Never nil.
---
--- The fallback stays visible HERE rather than inside the library because which constant this addon
--- falls back to is genuinely its own business — and because a packaged addon whose TOC can be read
--- should never report the constant somebody forgot to edit.
---
--- `NS.version` is read at CALL time, not captured as an upvalue: core/Namespace.lua publishes it
--- and loads after this file.
---
--- @return string
function NS.Version()
    if Env then return Env.Version(addonName, NS.version) or "?" end
    return NS.Meta("Version") or NS.version or "?"
end
