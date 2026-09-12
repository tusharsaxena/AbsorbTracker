# 03 — Decisions

This run was **non-interactive**. The orchestrating session gave the instructions for the
2026-09-12 triage wave B2, and they stood in for the interview:

- re-vendor v1.31.0;
- adopt any kit-17 surface that retires a local mock layer, but only if the suite stays green;
- file no issues and push nothing.

| Candidate | Decision | Why |
|---|---|---|
| B1 `spec.bind` | **not offered** | No fit: this addon has no registry records, and every row is path-keyed through `NS.SetByPath` (02_CANDIDATES B1). |
| B2 retire a local mock layer | **nothing to adopt** | `tests/wow_mock.lua` carries no layer that kit 17 replaces (02_CANDIDATES B2). |

No issue was filed, and none is owed: nothing was declined as *not now* or *never*.
