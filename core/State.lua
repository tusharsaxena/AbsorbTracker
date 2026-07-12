local addonName, NS = ...

-- Session-only runtime state. Nothing here is persisted to SavedVariables. The debug flag
-- (NS.State.debug) defaults off and resets on every /reload and fresh login (Ka0s standard §12.5).
NS.State = NS.State or {}
