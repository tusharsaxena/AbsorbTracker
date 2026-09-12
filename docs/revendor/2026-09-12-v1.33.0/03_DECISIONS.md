# 03 — Decisions

This run was **non-interactive**. The orchestrator's brief (re-vendor v1.33.0 on
`chore/2026-09-12-libka0s-1.33.0`, after the Profiles `Show()` fix) stood in for the interview.

| Candidate | Decision | Why |
|---|---|---|
| Options 17 font preload | **taken on the copy** | Class A: it needs no host change. |
| Slash 9 docstrings | **taken on the copy** | Class A: comments only. |
| Kit 18 `OnProfileCopied` source key | **taken on the copy**, stale comment corrected | Class A: no outcome changes (588 before and after). |

One optional follow-up was not taken. The testkit document notes that `tests/test_slashcmds.lua:647`
could now pin the full `'CopyFrom' → 'Default'` line rather than its prefix. That is a test
tightening, not part of a re-vendor. It is left as is and not filed: the brief rules out issue
changes on this branch.

No issue was filed, and none is owed.
