-- Adventure Chronicler: session state machine, observations, notes and retention.
-- Pure logic: no game API calls. Callers pass the current time explicitly.
local _, ns = ...
ns = ns or {}
local util = ns.util
local L = ns.limits

local S = {}
ns.Session = S

S.STATES = { recording = true, paused = true, stopped = true }
S.CERTAINTY = { confirmed = true, inferred = true, seen = true, uncertain = true }

-- ---------------------------------------------------------------- store

function S.newStore()
  return { schema = 1, sessions = {}, order = {}, active_id = nil, last_seen = nil }
end

-- Bring a loaded SavedVariables table to the current layout without discarding data.
function S.migrateStore(db)
  if type(db) ~= "table" then return S.newStore() end
  db.schema = db.schema or 1
  db.sessions = type(db.sessions) == "table" and db.sessions or {}
  db.order = type(db.order) == "table" and db.order or {}
  -- Keep order consistent with sessions (drop ids that no longer exist; add orphans at the end).
  local seen, order = {}, {}
  for _, id in ipairs(db.order) do
    if db.sessions[id] and not seen[id] then order[#order + 1] = id; seen[id] = true end
  end
  local orphans = {}
  for id in pairs(db.sessions) do if not seen[id] then orphans[#orphans + 1] = id end end
  table.sort(orphans, function(a, b) return (db.sessions[a].started_at or 0) < (db.sessions[b].started_at or 0) end)
  for _, id in ipairs(orphans) do order[#order + 1] = id end
  db.order = order
  if db.active_id and not db.sessions[db.active_id] then db.active_id = nil end
  return db
end

function S.active(db)
  return db.active_id and db.sessions[db.active_id] or nil
end

local function hex(n)
  return string.format("%08x", math.floor(n) % 4294967296)
end

-- Session IDs are random and carry no identity. rand is injectable for tests.
function S.newId(now, rand)
  rand = rand or math.random
  return "s-" .. hex(now) .. "-" .. hex(rand(0, 2147483646)) .. hex(rand(0, 2147483646)):sub(1, 4)
end

-- Can a new session start? Returns true, or false plus a reason and (if relevant) the oldest removable id.
function S.canStart(db)
  if S.active(db) then return false, "active" end
  if #db.order < L.max_sessions then return true end
  for _, id in ipairs(db.order) do
    if db.sessions[id].state == "stopped" then return false, "full", id end
  end
  return false, "full_no_stopped"
end

-- ---------------------------------------------------------------- lifecycle

local function openSegment(s, kind, now, reason)
  s.segments[#s.segments + 1] = { kind = kind, start = now, finish = nil, reason = reason }
end

local function closeSegment(s, now)
  local seg = s.segments[#s.segments]
  if seg and not seg.finish then seg.finish = math.max(seg.start, now) end
end

-- Start a new session. info = { client = {...}, character = {...}, title = "..." }
function S.start(db, now, info, rand)
  local ok, why, oldest = S.canStart(db)
  if not ok then return nil, why, oldest end
  info = info or {}
  local id = S.newId(now, rand)
  while db.sessions[id] do id = S.newId(now, rand) end
  local title = util.cleanText(info.title or "")
  if util.utf8len(title) > L.max_title_chars then return nil, "title_too_long" end
  local s = {
    id = id, title = title, state = "recording", interrupted = false,
    started_at = now, ended_at = nil, modified_at = now, exported_at = nil,
    segments = {}, observations = {}, notes = {}, next_seq = 1, next_note = 1,
    counters = { dropped = 0, dropped_by_type = {}, merged = 0, deleted_by_user = 0 },
    dedupe = {},
    client = util.copy(info.client or {}),
    character = util.copy(info.character or {}),
  }
  openSegment(s, "recording", now)
  db.sessions[id] = s
  db.order[#db.order + 1] = id
  db.active_id = id
  return s
end

-- Rename a session. The title is the player's own words, so changing it is not counted as an edit to the
-- observations. An empty title is allowed and shows as "Untitled".
function S.rename(s, now, title)
  title = util.cleanText(title or "")
  if util.utf8len(title) > L.max_title_chars then return nil, "title_too_long" end
  s.title = title
  s.modified_at = now
  return true
end

function S.pause(db, now, reason)
  local s = S.active(db)
  if not s then return nil, "no_session" end
  if s.state ~= "recording" then return nil, "not_recording" end
  closeSegment(s, now)
  s.state = "paused"
  openSegment(s, "paused", now, reason)
  s.modified_at = now
  return s
end

function S.resume(db, now)
  local s = S.active(db)
  if not s then return nil, "no_session" end
  if s.state ~= "paused" then return nil, "not_paused" end
  closeSegment(s, now)
  s.state = "recording"
  openSegment(s, "recording", now)
  s.modified_at = now
  return s
end

function S.stop(db, now)
  local s = S.active(db)
  if not s then return nil, "no_session" end
  closeSegment(s, now)
  s.state = "stopped"
  s.ended_at = now
  s.modified_at = now
  s.dedupe = {}
  db.active_id = nil
  return s
end

-- Called on every load. last_seen is the time written at the previous logout or reload.
-- Records the gap honestly; after a long offline gap the session is paused rather than resumed.
function S.recover(db, now, last_seen)
  local s = S.active(db)
  if not s then return nil end
  local seg = s.segments[#s.segments]
  local prevKind = seg and seg.kind or "recording"
  local gapStart = last_seen or (seg and seg.start) or now
  if gapStart > now then gapStart = now end -- clock moved backwards; never record negative time
  closeSegment(s, gapStart)
  local gap = now - gapStart
  local reason
  if last_seen == nil then reason = "unknown"
  elseif gap <= L.reload_gap then reason = "reload"
  else reason = "offline" end
  s.segments[#s.segments + 1] = { kind = "gap", start = gapStart, finish = now, reason = reason }
  s.modified_at = now
  if reason ~= "reload" then s.interrupted = true end
  if (reason == "offline" and gap > L.offline_pause_after) or reason == "unknown" then
    s.state = "paused"
    openSegment(s, "paused", now, "auto_after_gap")
    return s, "auto_paused", gap
  end
  s.state = (prevKind == "paused") and "paused" or "recording"
  openSegment(s, s.state, now)
  return s, "resumed", gap
end

-- ---------------------------------------------------------------- observations

-- obs = { type = "quest.turned_in", certainty = "confirmed", data = {...}, key = "optional dedupe key" }
-- Returns "added", "merged", "dropped" or nil + reason.
function S.observe(db, now, obs, opts)
  local s = S.active(db)
  if not s then return nil, "no_session" end
  opts = opts or {}
  if s.state ~= "recording" and not opts.allow_paused then return nil, "not_recording" end
  if type(obs) ~= "table" or type(obs.type) ~= "string" then return nil, "invalid" end
  local certainty = obs.certainty or "confirmed"
  if not S.CERTAINTY[certainty] then return nil, "invalid_certainty" end
  local key = obs.key
  if key then
    local prevSeq = s.dedupe[key]
    if prevSeq then
      for i = #s.observations, 1, -1 do
        local p = s.observations[i]
        if p.seq == prevSeq then
          if now - p.t <= L.dedupe_window and util.equal(p.data, obs.data) and p.certainty == certainty then
            p.repeats = (p.repeats or 0) + 1
            s.counters.merged = s.counters.merged + 1
            return "merged", p
          end
          break
        end
      end
    end
  end
  if #s.observations >= L.max_observations then
    s.counters.dropped = s.counters.dropped + 1
    s.counters.dropped_by_type[obs.type] = (s.counters.dropped_by_type[obs.type] or 0) + 1
    return "dropped"
  end
  local last = s.observations[#s.observations]
  local rec = { seq = s.next_seq, t = now, type = obs.type, certainty = certainty, data = util.copy(obs.data or {}) }
  if last and now < last.t then rec.clock_note = "earlier_than_previous" end
  s.next_seq = s.next_seq + 1
  s.observations[#s.observations + 1] = rec
  if key then s.dedupe[key] = rec.seq end
  s.modified_at = now
  return "added", rec
end

function S.deleteObservation(s, seq, now)
  for i, o in ipairs(s.observations) do
    if o.seq == seq then
      table.remove(s.observations, i)
      s.counters.deleted_by_user = s.counters.deleted_by_user + 1
      s.modified_at = now
      return true
    end
  end
  return false
end

-- ---------------------------------------------------------------- notes and bookmarks

-- Adds a note to session s. Never truncates: too-long text is refused so the writer can shorten it.
function S.addNote(s, now, text, kind)
  kind = kind or "note"
  if #s.notes >= L.max_notes then return nil, "too_many" end
  local clean = util.cleanText(text)
  local limit = kind == "bookmark" and L.max_label_chars or L.max_note_chars
  if kind == "note" and clean == "" then return nil, "empty" end
  local n = util.utf8len(clean)
  if n > limit then return nil, "too_long", n, limit end
  local note = { id = s.next_note, t = now, kind = kind, text = clean }
  s.next_note = s.next_note + 1
  s.notes[#s.notes + 1] = note
  s.modified_at = now
  return note
end

function S.editNote(s, now, id, text)
  for _, note in ipairs(s.notes) do
    if note.id == id then
      local clean = util.cleanText(text)
      local limit = note.kind == "bookmark" and L.max_label_chars or L.max_note_chars
      local n = util.utf8len(clean)
      if n > limit then return nil, "too_long", n, limit end
      if note.kind == "note" and clean == "" then return nil, "empty" end
      note.text, note.edited_at = clean, now
      s.modified_at = now
      return note
    end
  end
  return nil, "not_found"
end

function S.deleteNote(s, now, id)
  for i, note in ipairs(s.notes) do
    if note.id == id then table.remove(s.notes, i); s.modified_at = now; return true end
  end
  return false
end

-- ---------------------------------------------------------------- deletion and retention

-- True if deleting would lose notes that were never exported (or changed since export).
function S.hasUnexportedNotes(s)
  if #s.notes == 0 then return false end
  return not s.exported_at or (s.modified_at or 0) > s.exported_at
end

function S.deleteSession(db, id)
  if not db.sessions[id] then return false end
  db.sessions[id] = nil
  for i, oid in ipairs(db.order) do if oid == id then table.remove(db.order, i) break end end
  if db.active_id == id then db.active_id = nil end
  return true
end

-- Total recorded (not paused, not gap) seconds.
function S.recordedSeconds(s, now)
  local total = 0
  for _, seg in ipairs(s.segments) do
    if seg.kind == "recording" then total = total + ((seg.finish or now) - seg.start) end
  end
  return total
end

return S
