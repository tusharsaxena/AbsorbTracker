-- tests/prose_waivers.lua — what the kit's US-English gate MUST NOT correct here.
--
-- Read by `tests/_kit/test_prose.lua` (localization-5). Per FILE and per WORD, never per file
-- alone: a whole-file waiver hides every OTHER British spelling in a file this repo edits often,
-- which is how a gate acquires a blind spot the size of a module.
--
-- THE KEYS ARE THE PUBLISHED `BRITISH` ENTRIES, lowercase, exactly as localization-5 spells them
-- -- the gate lowercases each line before it matches, so a waiver written in the casing the FILE
-- uses silently waives nothing. This file is itself outside the scan (kit revision 24), which is
-- why the reasons below can name the words plainly.

return {
    waived = {
        -- THE SESSION-3 PERF-STRING CHECK. LibKa0s-Perf-1.0 minor 8 respelled five player-facing
        -- strings, and the step quotes the British forms in order to tell the reader that a
        -- double L in the client means the string did NOT come from the vendored payload.
        -- Correcting the quote deletes the check.
        ["docs/smoke-tests.md"] = { cancelled = true, labelled = true },
    },
}
