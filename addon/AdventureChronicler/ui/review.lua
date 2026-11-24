-- Adventure Chronicler: review window. Lists sessions, shows a session's timeline and notes, and lets
-- the player delete a whole session, a single observation or a note. Nothing is sent anywhere.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local R = { selected = nil, page = 1 }
ns.ui.review = R

local PAGE = 60
local f, list, listChild, timeline, timelineChild, header, pageLabel
local sessionRows, lineRows = {}, {}

local function W() return ns.ui.widgets end

local function rowsIn(parent, pool, i, width)
  local r = pool[i]
  if r then return r end
  r = CreateFrame("Button", nil, parent)
  r:SetSize(width, 18)
  r:SetPoint("TOPLEFT", 0, -(i - 1) * 18)
  r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.text:SetPoint("LEFT", 4, 0)
  r.text:SetPoint("RIGHT", -24, 0)
  r.text:SetJustifyH("LEFT")
  r.text:SetWordWrap(false)
  r.del = CreateFrame("Button", nil, r, "UIPanelCloseButton")
  r.del:SetSize(18, 18)
  r.del:SetPoint("RIGHT")
  pool[i] = r
  return r
end

local function build()
  f = W().window("AdventureChroniclerReview", "Adventure Chronicler: review", 760, 460)
  list = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  list:SetPoint("TOPLEFT", 12, -32)
  list:SetSize(220, 380)
  listChild = CreateFrame("Frame", nil, list)
  listChild:SetSize(220, 10)
  list:SetScrollChild(listChild)

  header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", 262, -32)
  header:SetPoint("RIGHT", -16, 0)
  header:SetJustifyH("LEFT")

  timeline = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  timeline:SetPoint("TOPLEFT", 262, -54)
  timeline:SetSize(460, 356)
  timelineChild = CreateFrame("Frame", nil, timeline)
  timelineChild:SetSize(460, 10)
  timeline:SetScrollChild(timelineChild)

  local export = W().button(f, "Export", 80, function() if R.selected then ns.App.export(R.selected) end end)
  export:SetPoint("BOTTOMRIGHT", -16, 12)
  local note = W().button(f, "Add note", 80, function() if R.selected then ns.ui.notes.open(R.selected) end end)
  note:SetPoint("RIGHT", export, "LEFT", -6, 0)
  local delete = W().button(f, "Delete session", 110, function()
    local s = R.selected and ns.App.db.sessions[R.selected]
    if not s then return end
    local warn = ns.Session.hasUnexportedNotes(s) and " It has notes that were never exported." or ""
    StaticPopup_Show("ADVENTURECHRONICLER_DELETE_SESSION", warn, nil, { id = s.id })
  end)
  delete:SetPoint("RIGHT", note, "LEFT", -6, 0)
  local nextB = W().button(f, ">", 28, function() R.page = R.page + 1; R.refresh() end)
  nextB:SetPoint("BOTTOMLEFT", 330, 12)
  pageLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pageLabel:SetPoint("RIGHT", nextB, "LEFT", -6, 0)
  local prevB = W().button(f, "<", 28, function() R.page = math.max(1, R.page - 1); R.refresh() end)
  prevB:SetPoint("RIGHT", pageLabel, "LEFT", -6, 0)
end

local function stamp(t) return date("%Y-%m-%d %H:%M", t) end

-- Build the visible rows (notes and observations merged by time) for one session.
function R.entries(s)
  local out = {}
  for _, o in ipairs(s.observations) do
    -- A bookmark is shown once, as its note row; the marker only records when it was added.
    if o.type ~= "marker.bookmark" then out[#out + 1] = { t = o.t, seq = o.seq, obs = o } end
  end
  for _, n in ipairs(s.notes) do out[#out + 1] = { t = n.t, seq = 0, note = n } end
  table.sort(out, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.seq < b.seq end)
  return out
end

function R.refresh()
  if not f or not f:IsShown() then return end
  local App = ns.App
  local db = App.db
  if R.selected and not db.sessions[R.selected] then R.selected = nil end
  if not R.selected then R.selected = db.active_id or db.order[#db.order] end
  for _, r in ipairs(sessionRows) do r:Hide() end
  local i = 0
  for k = #db.order, 1, -1 do
    local s = db.sessions[db.order[k]]
    i = i + 1
    local r = rowsIn(listChild, sessionRows, i, 210)
    local name = s.title ~= "" and s.title or stamp(s.started_at)
    local mark = s.id == db.active_id and ("|cffff4040" .. s.state .. "|r ") or ""
    r.text:SetText((s.id == R.selected and "> " or "") .. mark .. name)
    r:SetScript("OnClick", function() R.selected = s.id; R.page = 1; R.refresh() end)
    r.del:Hide()
    r:Show()
  end
  listChild:SetHeight(math.max(10, i * 18))
  for _, r in ipairs(lineRows) do r:Hide() end
  local s = R.selected and db.sessions[R.selected]
  if not s then header:SetText("No sessions yet. Type /ac start to begin.") pageLabel:SetText("") return end
  local recorded = ns.util.formatDuration(ns.Session.recordedSeconds(s, App.now()))
  header:SetText(string.format("%s  |cffcccccc%s, recorded %s%s%s|r", s.title ~= "" and s.title or "Untitled",
    s.state, recorded, s.interrupted and ", interrupted" or "",
    s.counters.dropped > 0 and (", " .. s.counters.dropped .. " not kept (full)") or ""))
  local entries = R.entries(s)
  local pages = math.max(1, math.ceil(#entries / PAGE))
  R.page = math.min(R.page, pages)
  pageLabel:SetText(R.page .. " / " .. pages)
  local first = (R.page - 1) * PAGE + 1
  local n = 0
  for k = first, math.min(#entries, first + PAGE - 1) do
    local e = entries[k]
    n = n + 1
    local r = rowsIn(timelineChild, lineRows, n, 450)
    local when = date("%H:%M:%S", e.t)
    if e.obs then
      r.text:SetText("|cff999999" .. when .. "|r  " .. ns.describe.observation(e.obs))
      r:SetScript("OnClick", nil)
      r.del:SetScript("OnClick", function()
        ns.Session.deleteObservation(s, e.obs.seq, App.now()); R.refresh()
      end)
    else
      local kind = e.note.kind == "bookmark" and "Bookmark" or "Note"
      local preview = e.note.text:gsub("\n", " ")
      r.text:SetText("|cff999999" .. when .. "|r  |cffd9a441" .. kind .. ":|r " .. preview)
      r:SetScript("OnClick", function() if e.note.kind == "note" then ns.ui.notes.open(s.id, e.note.id) end end)
      r.del:SetScript("OnClick", function() ns.Session.deleteNote(s, App.now(), e.note.id); R.refresh() end)
    end
    r.del:Show()
    r:Show()
  end
  timelineChild:SetHeight(math.max(10, n * 18))
end

function R.open()
  if not f then build() end
  f:Show()
  R.refresh()
end

return R
