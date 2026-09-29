# Summary (AbsorbTracker)

LibKa0s v1.62.0 -> v1.63.0 from the tag, base taken from the CLAUDE.md provenance line. Slash 16 -> 17;
every other file unchanged. `tests/_kit` unchanged at kit revision 31. The CLAUDE.md provenance line
is rolled. No span bundle, no base correction.

Contract blocker: the degraded Slash stub lacked `CliProfile` and `ProfileSwitch`, which the
by-name parity case reads off the live instance. Both were added to the stub in the copy commit,
on route (b).

Adopted: only the Slash minor 17 profile surface, by `SP-AT-02` (second commit). Nothing declined.

Gate after the copy and the stub:

- tests: 810 passed, 0 failed, 0 skipped, 810 total (810 before)
- luacheck: 0 warnings / 0 errors in 67 files
