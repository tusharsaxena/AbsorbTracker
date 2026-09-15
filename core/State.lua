local _, NS = ...

-- Session-only runtime state. Nothing here is persisted to SavedVariables. The debug flag
-- (NS.State.debug) defaults off and resets on every /reload and fresh login (Ka0s standard debug-logging-§5).
--
-- NS.State.testMode is test mode (preview-mode): true while the bars show the placeholder whether or
-- not they are locked, nil otherwise. Off at every /reload, ended by combat (core/AbsorbTracker.lua),
-- and switched through Master controls' `state.testMode` session row (settings/General.lua).
NS.State = NS.State or {}
