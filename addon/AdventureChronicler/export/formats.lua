-- Adventure Chronicler: readable copies of a session, for saving as a file. WoW doesn't let add-ons
-- write files, so these are shown for copying, with a suggested file name.
--   code      the ACX1 import code (for QuestersBoard and the reference validator)
--   markdown  a Markdown page: details, timeline, then notes in full
--   text      the same as plain text
--   json      the export document, indented (no envelope, so it isn't an import code)
-- Everything comes from the same document as the import code, so the same privacy settings apply.
-- Notes are always written out in full.
local _, ns = ...
ns = ns or {}
local L = ns.limits

local F = {}
ns.ExportFormats = F

F.ORDER = { "code", "markdown", "text", "json" }
F.LABEL = { code = "Import code", markdown = "Markdown", text = "Text", json = "JSON" }
F.EXT = { code = "txt", markdown = "md", text = "txt", json = "json" }

local function fmtDate(t, pattern)
  local d = date or (os and os.date)
  return d(pattern, t)
end

local CLASS = {
  WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
  SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

-- Lowercase, underscores, no spaces: adventure_2026-11-24_evening_run.md
function F.filename(doc, kind)
  local day = fmtDate(doc.session.started_at, "%Y-%m-%d")
  local slug = (doc.session.title or ""):lower():gsub("[^%w]+", "_"):gsub("^_+", ""):gsub("_+$", "")
  if slug == "" then slug = "untitled" end
  if #slug > 40 then slug = slug:sub(1, 40):gsub("_+$", "") end
  local suffix = kind == "code" and "_import_code" or ""
  return string.format("adventure_%s_%s%s.%s", day, slug, suffix, F.EXT[kind] or "txt")
end

local function recordedSeconds(doc)
  local last = doc.session.started_at
  for _, o in ipairs(doc.observations) do if o.t > last then last = o.t end end
  for _, n in ipairs(doc.author.notes) do if n.t > last then last = n.t end end
  local total, open = 0, false
  for _, seg in ipairs(doc.session.segments) do
    if seg.kind == "recording" then
      local finish = seg.finish
      if type(finish) ~= "number" then open = true; finish = math.max(seg.start, last) end
      total = total + (finish - seg.start)
    end
  end
  return total, open
end

-- Timeline rows: observations (described the same way as in game), notes and bookmarks, and the
-- paused and gap segments, so missing time is visible rather than hidden.
local function rows(doc)
  local out = {}
  for _, o in ipairs(doc.observations) do
    if o.type ~= "marker.bookmark" then
      out[#out + 1] = { t = o.t, order = 1, seq = o.seq, text = ns.describe.observation(o) }
    end
  end
  for i, n in ipairs(doc.author.notes) do
    local text
    if n.kind == "bookmark" then
      text = (n.text ~= "" and ("Bookmark: " .. n.text:gsub("%s+", " ")) or "Bookmark")
    else
      text = string.format("Note %d (in full below)", i)
    end
    out[#out + 1] = { t = n.t, order = 2, seq = i, text = text }
  end
  local WHY = { reload = "interface reload", offline = "logged out", player = "you paused",
                unknown = "reason unknown", auto_after_gap = "paused after a gap" }
  for i, seg in ipairs(doc.session.segments) do
    if seg.kind ~= "recording" then
      local finish = type(seg.finish) == "number" and fmtDate(seg.finish, "%H:%M:%S") or "end"
      local what = seg.kind == "paused" and "Paused" or "Not recording"
      local why = type(seg.reason) == "string" and WHY[seg.reason] or nil
      out[#out + 1] = { t = seg.start, order = 0, seq = i,
                        text = string.format("%s until %s%s", what, finish, why and (" (" .. why .. ")") or "") }
    end
  end
  table.sort(out, function(a, b)
    if a.t ~= b.t then return a.t < b.t end
    if a.order ~= b.order then return a.order < b.order end
    return a.seq < b.seq
  end)
  return out
end

local function details(doc)
  local s = doc.session
  local total, open = recordedSeconds(doc)
  local list = {}
  list[#list + 1] = "Started: " .. fmtDate(s.started_at, "%Y-%m-%d %H:%M") .. " (local time)"
  list[#list + 1] = "Recorded: " .. (open and "at least " or "") .. ns.util.formatDuration(total)
    .. " (paused time not counted)"
  if s.state ~= "stopped" then list[#list + 1] = "State: still recording when exported" end
  if s.interrupted then list[#list + 1] = "State: interrupted" end
  local ch = doc.character or {}
  if type(ch.name) == "string" then
    list[#list + 1] = "Character: " .. ch.name .. (type(ch.realm) == "string" and (" of " .. ch.realm) or "")
  end
  if type(ch.class) == "string" or type(ch.level) == "number" then
    list[#list + 1] = "Class and level: " .. (CLASS[ch.class] or tostring(ch.class or "unknown"))
      .. (type(ch.level) == "number" and (", level " .. ch.level) or "")
  end
  local g = doc.game
  list[#list + 1] = string.format("Recorded with: Adventure Chronicler %s, WoW %s%s", doc.recorder.version,
    type(g.client_version) == "string" and g.client_version or "(version unknown)",
    type(g.build) == "string" and (" build " .. g.build) or "")
  local integ = doc.integrity
  if (integ.deleted_by_user or 0) > 0 then
    list[#list + 1] = string.format("Removed by the player before export: %d observation(s)", integ.deleted_by_user)
  end
  if (integ.observations_dropped or 0) > 0 then
    list[#list + 1] = string.format("Not kept because the session was full: %d observation(s)",
      integ.observations_dropped)
  end
  return list
end

local DISCLAIMER = "Player-provided log from the Adventure Chronicler add-on. Not game-verified. "
  .. "No chat or other players are included."

local function title(doc)
  return doc.session.title ~= "" and doc.session.title or "Untitled session"
end

local function markdown(doc)
  local out = { "# " .. title(doc), "" }
  for _, line in ipairs(details(doc)) do out[#out + 1] = "- " .. line end
  out[#out + 1] = ""
  out[#out + 1] = "> " .. DISCLAIMER
  out[#out + 1] = ""
  out[#out + 1] = "## Timeline"
  out[#out + 1] = ""
  local r = rows(doc)
  if #r == 0 then out[#out + 1] = "Nothing was recorded." end
  for _, row in ipairs(r) do out[#out + 1] = string.format("- `%s` %s", fmtDate(row.t, "%H:%M:%S"), row.text) end
  local notes = {}
  for i, n in ipairs(doc.author.notes) do if n.kind ~= "bookmark" then notes[#notes + 1] = { i = i, n = n } end end
  if #notes > 0 then
    out[#out + 1] = ""
    out[#out + 1] = "## Notes"
    for _, e in ipairs(notes) do
      out[#out + 1] = ""
      out[#out + 1] = string.format("### Note %d, %s%s", e.i, fmtDate(e.n.t, "%H:%M"),
        type(e.n.edited_at) == "number" and " (edited)" or "")
      out[#out + 1] = ""
      out[#out + 1] = e.n.text
    end
  end
  out[#out + 1] = ""
  return table.concat(out, "\n")
end

local function plain(doc)
  local name = title(doc)
  local out = { name, string.rep("=", math.min(60, math.max(3, ns.util.utf8len(name)))), "" }
  for _, line in ipairs(details(doc)) do out[#out + 1] = line end
  out[#out + 1] = ""
  out[#out + 1] = DISCLAIMER
  out[#out + 1] = ""
  out[#out + 1] = "Timeline"
  out[#out + 1] = "--------"
  local r = rows(doc)
  if #r == 0 then out[#out + 1] = "Nothing was recorded." end
  for _, row in ipairs(r) do out[#out + 1] = fmtDate(row.t, "%H:%M:%S") .. "  " .. row.text end
  local first = true
  for i, n in ipairs(doc.author.notes) do
    if n.kind ~= "bookmark" then
      if first then out[#out + 1] = ""; out[#out + 1] = "Notes"; out[#out + 1] = "-----"; first = false end
      out[#out + 1] = ""
      out[#out + 1] = string.format("Note %d, %s%s", i, fmtDate(n.t, "%H:%M"),
        type(n.edited_at) == "number" and " (edited)" or "")
      out[#out + 1] = n.text
    end
  end
  out[#out + 1] = ""
  return table.concat(out, "\n")
end

-- Returns text, file name; or nil, reason, size.
function F.render(kind, s, settings, version)
  local doc = ns.Export.build(s, settings, version)
  local text
  if kind == "code" then
    local t, why, size = ns.Export.toText(s, settings, version)
    if not t then return nil, why, size end
    text = t
  else
    local ok, result = pcall(function()
      if kind == "markdown" then return markdown(doc)
      elseif kind == "text" then return plain(doc)
      elseif kind == "json" then return ns.json.encodePretty(doc) .. "\n"
      end
      error("unknown format")
    end)
    if not ok then return nil, "encode_failed", result end
    text = result
    if #text > L.max_export_bytes * 2 then return nil, "too_large", #text end
  end
  return text, F.filename(doc, kind)
end

return F
