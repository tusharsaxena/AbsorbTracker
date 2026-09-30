# Candidates (AbsorbTracker)

| # | Surface | What it offers | Blocker? |
|---|---|---|---|
| C1 | Slash minor 17 profile surface: `profiles` descriptor field, `Sl:CliProfile`, `Sl:ProfileSwitch`, `lib.ProfileNames` | The shared `profile` verb: bare lists profiles with the current one marked, `profile <name>` switches to an existing profile only, an unknown name is refused with a did-you-mean and the list. | The stub members are (see `01_DELTA.md`); adopting the verb is not. |
