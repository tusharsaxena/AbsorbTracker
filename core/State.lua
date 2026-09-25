local _, NS = ...

-- Session-only runtime state. Nothing here is persisted to SavedVariables. The debug flag
-- (NS.State.debug) defaults off and resets on every /reload and fresh login (Ka0s standard debug-logging-§5).
--
-- There is no test-mode flag here. `options-ui-§15` exempts an addon whose unlocked view already IS
-- its preview from the Test mode row, which is this addon: preview is `not locked` and nothing else
-- (NS.InPreview, modules/Display.lua).
NS.State = NS.State or {}

-- Every event name the client refused this session, appended once each by the SafeRegister helpers
-- (core/CoreSetup.lua, events-frames-taint-§1). Read back by `/at debug events` and the [Init] summary.
NS.State.rejectedEvents = NS.State.rejectedEvents or {}
