-- Adventure Chronicler: documented limits. Changing a value here changes behaviour everywhere,
-- including the reference validator's expectations (see docs/schema.md).
local _, ns = ...
ns = ns or {}

ns.limits = {
  max_sessions = 50,            -- per character; starting a 51st asks before removing the oldest stopped one
  max_observations = 2000,      -- per session; further observations are counted as dropped, never silently lost
  max_notes = 200,              -- notes and bookmarks per session
  max_note_chars = 4000,        -- per note, in characters (code points)
  max_title_chars = 120,        -- session label
  max_label_chars = 200,        -- bookmark label
  dedupe_window = 60,           -- seconds: identical repeated observations within this window are merged
  reload_gap = 120,             -- seconds: a gap up to this long on load is treated as a UI reload
  offline_pause_after = 900,    -- seconds: after an offline gap this long, the session is paused, not resumed
  max_export_bytes = 524288,    -- 512 KiB per exported session
}

return ns.limits
