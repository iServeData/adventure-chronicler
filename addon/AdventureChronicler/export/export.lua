-- Adventure Chronicler: turn one session into the versioned export (docs/schema.md) and wrap it
-- in the copy/paste envelope:  ACX1:<byte length>:<crc32 hex>:<json>
local _, ns = ...
ns = ns or {}
local json = ns.json
local util = ns.util
local L = ns.limits

local E = {}
ns.Export = E

E.FORMAT = "adventure-chronicler.session"
E.SCHEMA_VERSION = 2
E.PREFIX = "ACX1"

local A = json.array

local function orNull(v) if v == nil then return json.null end return v end

local function segmentsOut(s)
  local out = A()
  for _, seg in ipairs(s.segments) do
    out[#out + 1] = { kind = seg.kind, start = seg.start, finish = orNull(seg.finish), reason = orNull(seg.reason) }
  end
  return out
end

-- Arrays inside observation data are marked by key name so empty lists encode as [].
local ARRAY_KEYS = { choices = true, guaranteed = true, items = true, objectives = true, quests = true }

local function dataOut(v)
  if type(v) ~= "table" then return v end
  local isList = #v > 0 or next(v) == nil
  if isList and #v > 0 then
    local out = A()
    for i = 1, #v do out[i] = dataOut(v[i]) end
    return out
  end
  local out = {}
  for k, val in pairs(v) do
    if ARRAY_KEYS[k] and type(val) == "table" and #val == 0 then out[k] = A()
    else out[k] = dataOut(val) end
  end
  return out
end

-- The quest giver's full text leaves the addon only while /ac set questtext is on at export time.
local function observationsOut(s, keepQuestText)
  local out = A()
  for _, o in ipairs(s.observations) do
    local data = o.data or {}
    if o.type == "quest.accepted" and data.description ~= nil and not keepQuestText then
      data = util.copy(data)
      data.description = nil
    end
    out[#out + 1] = {
      seq = o.seq, t = o.t, type = o.type, certainty = o.certainty,
      data = dataOut(data), repeats = o.repeats or 0, clock_note = orNull(o.clock_note),
    }
  end
  return out
end

local function notesOut(s)
  local out = A()
  for _, n in ipairs(s.notes) do
    out[#out + 1] = { id = n.id, t = n.t, kind = n.kind, text = n.text, edited_at = orNull(n.edited_at) }
  end
  return out
end

-- settings decide which optional, identifying fields leave the addon.
function E.build(s, settings, recorderVersion)
  settings = settings or {}
  local includeIdentity = settings.include_identity == true
  local includeClassLevel = settings.include_class_level ~= false
  local ch = s.character or {}
  local character = {}
  if includeIdentity then
    character.name = orNull(ch.name)
    character.realm = orNull(ch.realm)
  end
  if includeClassLevel then
    character.class = orNull(ch.class)
    character.level = orNull(ch.level)
  end
  local c = s.client or {}
  local dropped = {}
  for k, v in pairs(s.counters.dropped_by_type or {}) do dropped[k] = v end
  return {
    format = E.FORMAT,
    schema_version = E.SCHEMA_VERSION,
    recorder = { name = "AdventureChronicler", version = recorderVersion or "0.0.0" },
    game = {
      id = "wow", flavor = c.flavor or "forever",
      client_version = orNull(c.version), build = orNull(c.build),
      interface = orNull(c.interface), locale = orNull(c.locale),
    },
    consent = {
      character_identity = includeIdentity,
      class_and_level = includeClassLevel,
      personal_loot = settings.record_personal_loot == true,
      quest_text = settings.record_quest_text == true,
    },
    character = character,
    session = {
      id = s.id, title = s.title or "", state = s.state, interrupted = s.interrupted and true or false,
      started_at = s.started_at, ended_at = orNull(s.ended_at), clock = "unix_seconds",
      segments = segmentsOut(s),
    },
    observations = observationsOut(s, settings.record_quest_text == true),
    author = { notes = notesOut(s) },
    integrity = {
      observations_dropped = s.counters.dropped or 0,
      dropped_by_type = dropped,
      merged_repeats = s.counters.merged or 0,
      deleted_by_user = s.counters.deleted_by_user or 0,
      self_reported = true,
    },
  }
end

function E.envelope(jsonText)
  return string.format("%s:%d:%08x:%s", E.PREFIX, #jsonText, ns.crc32(jsonText), jsonText)
end

-- Returns the envelope text, or nil + reason + size.
function E.toText(s, settings, recorderVersion)
  local ok, body = pcall(json.encode, E.build(s, settings, recorderVersion))
  if not ok then return nil, "encode_failed", body end
  local text = E.envelope(body)
  if #text > L.max_export_bytes then return nil, "too_large", #text end
  return text
end

-- Small sanity helper so the export dialog can show what it contains.
function E.summary(s)
  return {
    observations = #s.observations, notes = #s.notes,
    title = s.title ~= "" and s.title or nil, started_at = s.started_at,
    length = util.formatDuration((s.ended_at or s.modified_at or s.started_at) - s.started_at),
  }
end

return E
