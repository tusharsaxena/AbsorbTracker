# Lifecycle: the disabled state is total

What *Enable Absorb Tracker* switched off actually does: the one latch, the two holds on it, what
stands down, what survives, and how the addon comes back up. This page was the
`## The disabled state is total` section of [ARCHITECTURE.md](./ARCHITECTURE.md) until the hub was
brought back under documentation-§3's spill rule. The login sequence and the event wiring it gates
are in [data-flow.md](./data-flow.md); the slash gate a disabled addon applies is in
[slash-dispatch.md](./slash-dispatch.md).

## The rule

`slash-commands-§7`. **Disabled means the addon is not running** — not hidden, not quiet, not
skipping a repaint. A player who unticks *Enable Absorb Tracker* has asked for the same outcome they
would get by unticking the addon in Blizzard's own AddOns list, minus the `/reload`.

**This addon used to implement a draw gate**, and the entry that described it was accurate: `enabled`
was one rung of `NS.ShouldShowBar`'s ladder and nothing else, so the bars went away and every
registration stayed live. That is the shape `anti-pattern #85` names. An early-returning handler did
not stop watching — it stopped reacting, and the client went on walking the registration list on
every `UNIT_ABSORB_AMOUNT_CHANGED` in a raid, building the argument frame and entering Lua to run
the comparison that decided to leave.

## One latch, two named holds

`core/Lifecycle.lua` owns a single `LibKa0s-Lifecycle-1.0` instance, `NS.lifecycle`:

| Hold | Taken by | Lifetime |
|---|---|---|
| `disabled` | the stored `enabled` path, through `NS.SyncEnabledHold()` | **persisted** — surviving a `/reload` is the entire point of the setting |
| `perf` | `LibKa0s-Perf-1.0`'s Experiment B, which takes and releases it itself | **session-only**, never written to SavedVariables |

The addon is stood down whenever **at least one** hold is taken and stood up only when the **last**
one is released. There is no `:StandUp()` member to call, and its absence is the feature: a resume
that stood the addon up would resurrect one the player disabled mid-capture, and a disable that did
the same would end a run that was still recording. Both go through release-and-re-evaluate.

`NS.SyncEnabledHold()` is the one line every surface reaches — the Master controls checkbox and
`/at enable` / `/at disable` / `/at set enabled` through the `enabled` row's `onChange`, a Defaults
press through the same row, and AceDB's `OnProfileChanged` / `OnProfileCopied` / `OnProfileReset`
through `adoptProfile`, which re-reads the store because a profile switch can flip the path with
nothing else being touched. The latch's `Set` re-evaluates on its own, and when that stands the addon
up, `adoptProfile` leaves the bar passes to `StandUp` rather than publishing them a second time.

**There is no second teardown path.** `core/PerfSetup.lua` no longer carries `suspend` / `resume`:
those bodies **are** `NS.StandDown` / `NS.StandUp`, and the perf descriptor passes the latch
instead. Two mechanisms that both mean "be inert" diverge on the first module added after the second
one was written.

## What stands down

- **Every AceEvent registration on the addon object** — `PLAYER_ENTERING_WORLD`, the combat pair,
  and the two swap events — actually `UnregisterEvent`ed.
- **All three per-unit `RegisterUnitEvent` frames**, `UnregisterAllEvents`'d.
- **Every bus subscription.** A `RegisterMessage` is a registration like any other. The subscribing
  modules hold their targets as file-locals, so the record lives with the factory that made them:
  every `NS.NewBusTarget()` target is tracked by `LibKa0s-Bus-1.0`, `StandDown` calls
  `NS.BusStandDown()` last and `StandUp` calls `NS.BusStandUp()` first, so no receiver has to ask
  the latch for its subscription to come down. The `UNITS` receiver asks `NS.IsStoodDown()` anyway,
  as a registration guard for the LibKa0s-less stub that records nothing
  ([ARCHITECTURE.md → Known Limitations](./ARCHITECTURE.md#known-limitations)).
- **Every timer**: the coalescing repaint (`NS.CancelPendingRepaint`) and the `/at debug hold` preview
  hold (`NS.ClearPreview`).
- **The bars, at the source.** `StandDown` publishes `VISIBILITY` *before* it takes the bus down, and
  `NS.ShouldShowBar`'s rung 0 asks `NS.IsStoodDown()` — the latch, never the stored `enabled` — so it
  already answers no, so nothing — a combat transition, a target swap, a settings
  change — can re-show a bar behind the switch's back.
- **No SavedVariables write from a game event.** The finding this fixes: entering combat while
  disabled used to write `locked = true` and print `Bars locked — combat started`. `OnEnterCombat`
  is **unchanged**; what changed is that `PLAYER_REGEN_DISABLED` is no longer registered, so the
  client never calls it. That is the difference between standing down and gating.

**No secure work is held pending**, and that is a statement about this addon rather than an omission.
§7 requires `UnregisterStateDriver` / `UnregisterAttributeDriver` / a secure-attribute rewrite to
wait for `PLAYER_REGEN_ENABLED`; this addon owns no secure frame, no state driver and no attribute
driver — the bars are plain `CreateFrame("Frame", …, "BackdropTemplate")` — so the whole stand-down
is combat-safe and completes in the same turn as the write. The day a secure element arrives here it
holds its half pending, and `core/Lifecycle.lua` carries that note.

## What survives, because it is setup

The chat command registration, the dispatcher and `NS.COMMANDS`; the settings-category registration
and the panel body (`CreateOptionsPanel` is deliberately outside `OnEnable`'s latch gate); the AceDB
handle, the single write seam and the three profile callbacks; and the launcher's registration. The
addon is inert; its command surface is not the addon.

## Standing up rebuilds from current state

Never from a snapshot taken on the way down. `StandUp` re-subscribes the bus, calls
`RegisterLifecycleEvents` and `SyncUnitEventFrames` — which read the enabled set **as it is now** —
and publishes `POSITION` → `VISIBILITY` → `APPEARANCE` → `REPAINT`. `POSITION` is there and is not
symmetric with `StandDown` for a reason: a login that came up disabled never applied the stored
anchors, so a later enable has to place the bars before it shows them.

`tests/test_disabled.lua` is the conformance suite §7 requires, and it asserts on the **registration
set** through the kit's recording mocks — never on a handler's return value, because a suite written
against an early return certifies the draw gate it exists to catch.
