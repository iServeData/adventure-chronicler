-- Adventure Chronicler: review window. Lists sessions, shows a session's timeline and notes, and lets
-- the player delete a whole session, a single observation or a note. Nothing is sent anywhere.
-- The Filter only hides rows from view (core/reviewfilter.lua); nothing is deleted and exports keep everything.
-- 0.3.5: the status line under the title shows the export size; hovering a row shows a tooltip and
-- clicking it opens the details panel (ui/details.lua); instance enter/leave lines within a second show as
-- one row (core/details.lua, display only).
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local R = { selected = nil, page = 1 }
R.filter = ns.reviewfilter and ns.reviewfilter.new() or { types = {}, qualities = {} }
ns.ui.review = R

local PAGE = 60
local f, list, listChild, timeline, timelineChild, header, status, pageLabel, titleBox, titleInput, renameLink
local continueB
local SIZE_EVERY = 15 -- while recording, the export size is worked out again at most this often (seconds)
local sizeCache = { key = nil, id = nil, bytes = nil, at = 0, pending = false }
local sessionRows, lineRows = {}, {}
local filterButton, filterClear, filterPanel
local filterChecks = {}

-- Item quality from the game's item data on this computer; nil if the game hasn't loaded the item yet.
function R.qualityOf(itemID)
  local fn = (C_Item and C_Item.GetItemQualityByID)
  if fn then
    local ok, q = pcall(fn, itemID)
    if ok and type(q) == "number" then return q end
  end
  local info = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
  if info then
    local ok, _, _, q = pcall(info, itemID)
    if ok and type(q) == "number" then return q end
  end
  return nil
end

local function refreshFilterButton()
  if not filterButton then return end
  local n = ns.reviewfilter.count(R.filter)
  filterButton:SetText(n > 0 and ("Filter |cffffd100(" .. n .. ")|r") or "Filter")
  filterClear:SetShown(n > 0)
  for _, c in ipairs(filterChecks) do c:SetChecked(c.get()) end
end

local function buildFilter()
  local Wd, F = ns.ui.widgets, ns.reviewfilter
  filterButton = Wd.button(f, "Filter", 92, function()
    if filterPanel:IsShown() then filterPanel:Hide() else filterPanel:Show() end
  end, "dark", 22)
  filterButton:SetPoint("TOPRIGHT", -44, -38)
  -- The red x clears every filter, like the profession window's.
  filterClear = CreateFrame("Button", nil, filterButton)
  filterClear:SetSize(16, 16)
  filterClear:SetPoint("CENTER", filterButton, "TOPRIGHT", -2, -2)
  filterClear:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
  filterClear:SetScript("OnClick", function() F.clear(R.filter); R.page = 1; R.refresh() end)

  filterPanel = CreateFrame("Frame", nil, f)
  filterPanel:SetFrameStrata("FULLSCREEN_DIALOG")
  filterPanel:SetSize(300, 330)
  filterPanel:SetPoint("TOPRIGHT", filterButton, "BOTTOMRIGHT", 0, -4)
  local bg = filterPanel:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(); bg:SetTexture(Wd.media("frame_bg"))
  Wd.goldBorder(filterPanel, 0)
  filterPanel:Hide()
  local function add(label, colour, get, set, x, y)
    local c = Wd.check(filterPanel, label, function(on) set(on); R.page = 1; R.refresh() end, colour)
    c:SetPoint("TOPLEFT", x, y)
    c.get = get
    filterChecks[#filterChecks + 1] = c
    return c
  end
  add("Hide \"seen\" if received", nil, function() return R.filter.hide_seen_received end,
    function(on) R.filter.hide_seen_received = on end, 12, -10)
  local show = Wd.text(filterPanel, "body", 11, Wd.MUTED)
  show:SetPoint("TOPLEFT", 16, -44); show:SetText("SHOW")
  local function setAll(on) for _, t in ipairs(F.TYPES) do R.filter.types[t] = (not on) or nil end end
  local all = Wd.link(filterPanel, "Check all", function() setAll(true); R.refresh() end)
  all:SetPoint("LEFT", show, "RIGHT", 12, 0)
  local none = Wd.link(filterPanel, "Uncheck all", function() setAll(false); R.refresh() end)
  none:SetPoint("LEFT", all, "RIGHT", 8, 0)
  for i, t in ipairs(F.TYPES) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    add(t, nil, function() return not R.filter.types[t] end,
      function(on) R.filter.types[t] = (not on) or nil end, 12 + col * 140, -60 - row * 24)
  end
  local ql = Wd.text(filterPanel, "body", 11, Wd.MUTED)
  ql:SetPoint("TOPLEFT", 16, -190); ql:SetText("LOOT QUALITY")
  for i, q in ipairs(F.QUALITIES) do
    local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
    local name = q == "unknown" and "Unknown quality" or ns.options.QUALITY[q]
    local hex = q == "unknown" and "a89880" or ns.options.QUALITY_COLOUR[q]
    local colour = { tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255,
                     tonumber(hex:sub(5, 6), 16) / 255 }
    add(name, colour, function() return not R.filter.qualities[q] end,
      function(on) R.filter.qualities[q] = (not on) or nil end, 12 + col * 140, -206 - row * 24)
  end
  local note = Wd.text(filterPanel, "body", 10, Wd.MUTED)
  note:SetPoint("BOTTOMLEFT", 14, 10); note:SetPoint("RIGHT", -14, 0); note:SetJustifyH("LEFT")
  note:SetText("Only hides rows here. Nothing is deleted; exports keep everything.")
end

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
  r.del = ns.ui.widgets.deleteButton(r)
  r.del:SetPoint("RIGHT")
  pool[i] = r
  return r
end

local function build()
  f = W().window("AdventureChroniclerReview", W().BRAND .. ": review", 760, 460, { compass = true })
  list, listChild = W().scroll(f, 220, 366)
  list:SetPoint("TOPLEFT", 14, -42)

  header = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  header:SetPoint("TOPLEFT", 262, -42)
  header:SetPoint("RIGHT", -196, 0)
  header:SetJustifyH("LEFT")
  header:SetWordWrap(false)
  status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  status:SetPoint("TOPLEFT", 262, -62)
  status:SetPoint("RIGHT", -44, 0)
  status:SetJustifyH("LEFT")
  status:SetWordWrap(false)

  -- Rename: click the title (or Rename), type, Enter saves, Escape keeps the old name. Works on any
  -- session, stopped or not. Only the title changes; observations and notes stay as they are.
  titleBox = W().parchment(f)
  titleBox:SetPoint("TOPLEFT", 258, -36)
  titleBox:SetPoint("TOPRIGHT", -192, -36)
  titleBox:SetHeight(26)
  titleBox:Hide()
  titleInput = CreateFrame("EditBox", nil, titleBox)
  titleInput:SetAutoFocus(false)
  titleInput:SetHeight(22)
  titleInput:SetPoint("LEFT", 8, 0)
  titleInput:SetPoint("RIGHT", -8, 0)
  titleInput:SetFontObject(ChatFontNormal)
  titleInput:SetTextColor(W().INK[1], W().INK[2], W().INK[3])
  titleInput:SetMaxLetters(ns.limits.max_title_chars)
  local function endRename() titleBox:Hide(); header:Show(); renameLink:Show() end
  titleInput:SetScript("OnEnterPressed", function(self)
    local id, text = R.selected, self:GetText()
    self:ClearFocus(); endRename()
    if id then ns.App.rename(text, id) end
  end)
  titleInput:SetScript("OnEscapePressed", function(self) self:ClearFocus(); endRename() end)
  titleInput:SetScript("OnEditFocusLost", function() endRename() end)
  local function startRename()
    local s = R.selected and ns.App.db.sessions[R.selected]
    if not s then return end
    header:Hide(); renameLink:Hide(); titleBox:Show()
    titleInput:SetText(s.title or "")
    titleInput:SetFocus()
    titleInput:HighlightText()
  end
  R.startRename = startRename
  local clickTitle = CreateFrame("Button", nil, f)
  clickTitle:SetPoint("TOPLEFT", 258, -38)
  clickTitle:SetPoint("TOPRIGHT", -196, -38)
  clickTitle:SetHeight(22)
  clickTitle:SetScript("OnClick", startRename)
  renameLink = W().link(f, "Rename", startRename)
  renameLink:SetPoint("TOPRIGHT", -142, -40)
  buildFilter()

  timeline, timelineChild = W().scroll(f, 460, 326)
  timeline:SetPoint("TOPLEFT", 262, -82)

  local export = W().button(f, "Export", 80, function() if R.selected then ns.App.export(R.selected) end end)
  export:SetPoint("BOTTOMRIGHT", -18, 16)
  local note = W().button(f, "Add note", 80, function() if R.selected then ns.ui.notes.open(R.selected) end end)
  note:SetPoint("RIGHT", export, "LEFT", -6, 0)
  local delete = W().button(f, "Delete session", 110, function()
    local s = R.selected and ns.App.db.sessions[R.selected]
    if not s then return end
    local warn = ns.Session.hasUnexportedNotes(s) and " It has notes that were never exported." or ""
    StaticPopup_Show("ADVENTURECHRONICLER_DELETE_SESSION", warn, nil, { id = s.id })
  end, "red")
  delete:SetPoint("RIGHT", note, "LEFT", -6, 0)
  -- Continue: only for a stopped session. Greyed out, with the reason on hover, when it can't.
  continueB = W().button(f, "Continue", 80, function() if R.selected then ns.App.continue(R.selected) end end)
  continueB:SetPoint("RIGHT", delete, "LEFT", -6, 0)
  continueB:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Continue recording", 1, 0.82, 0)
    GameTooltip:AddLine(self.why or "Record again in this session. The time since you stopped shows as a pause.",
      0.95, 0.90, 0.79, true)
    GameTooltip:Show()
  end)
  continueB:SetScript("OnLeave", function() GameTooltip:Hide() end)
  continueB:Hide()
  local nextB = W().button(f, ">", 28, function() R.page = R.page + 1; timeline.toTop(); R.refresh() end)
  nextB:SetPoint("BOTTOMLEFT", 330, 16)
  pageLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pageLabel:SetPoint("RIGHT", nextB, "LEFT", -6, 0)
  local prevB = W().button(f, "<", 28, function() R.page = math.max(1, R.page - 1); timeline.toTop(); R.refresh() end)
  prevB:SetPoint("RIGHT", pageLabel, "LEFT", -6, 0)
end

local function stamp(t) return date("%Y-%m-%d %H:%M", t) end

-- The import code's size in bytes, worked out when a session is opened or changed. While a session is
-- recording it changes with every event, so it's worked out again at most every SIZE_EVERY seconds.
function R.exportSize(s)
  local App, st = ns.App, ns.App.settings
  local key = table.concat({ tostring(s.id), tostring(s.modified_at), #s.observations, #s.notes,
    tostring(s.counters.merged), tostring(s.title), tostring(st.include_identity),
    tostring(st.include_class_level), tostring(st.record_quest_text), tostring(st.record_personal_loot) }, "|")
  if key == sizeCache.key then return sizeCache.bytes end
  local now = App.now()
  if s.state == "recording" and sizeCache.id == s.id and sizeCache.bytes and now - sizeCache.at < SIZE_EVERY then
    if not sizeCache.pending and C_Timer and C_Timer.After then
      sizeCache.pending = true
      C_Timer.After(SIZE_EVERY, function() sizeCache.pending = false; R.refresh() end)
    end
    return sizeCache.bytes
  end
  sizeCache.key, sizeCache.id, sizeCache.at = key, s.id, now
  sizeCache.bytes = ns.Export.size(s, st, App.VERSION)
  return sizeCache.bytes
end

local SIZE_COLOUR = { ok = "cccccc", warn = "ffb340", over = "ff4040" }

-- The line under the title: state, time, counts, export size, and anything worth knowing.
function R.statusText(s, bytes, shown, total)
  local recorded = ns.util.formatDuration(ns.Session.recordedSeconds(s, ns.App.now()))
  local nObs, nNotes = 0, #s.notes
  for _, o in ipairs(s.observations) do if o.type ~= "marker.bookmark" then nObs = nObs + 1 end end
  local sizeText, level = ns.details.sizeText(bytes, ns.limits.max_export_bytes)
  local parts = { s.state .. (s.interrupted and " (interrupted)" or ""), "recorded " .. recorded,
    nObs .. (nObs == 1 and " event" or " events") }
  if nNotes > 0 then parts[#parts + 1] = nNotes .. (nNotes == 1 and " note" or " notes") end
  parts[#parts + 1] = "|cff" .. SIZE_COLOUR[level] .. sizeText .. "|cffcccccc"
  if s.counters.dropped > 0 then parts[#parts + 1] = s.counters.dropped .. " not kept (full)" end
  if shown and total and shown ~= total then
    parts[#parts + 1] = string.format("|cffa89880showing %d of %d|cffcccccc", shown, total)
  end
  return "|cffcccccc" .. table.concat(parts, " · ") .. "|r"
end

-- The Continue button: shown for a stopped session, greyed out with the reason when it can't continue.
function R.updateContinue(s)
  if not continueB then return end
  if not s or s.state ~= "stopped" then continueB:Hide() return end
  local ok, why = ns.Session.canContinue(ns.App.db, s.id)
  continueB.why = (not ok) and (ns.App.CONTINUE_WHY[why] or why) or nil
  continueB:SetEnabled(ok == true)
  continueB:Show()
end

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
    r:SetScript("OnClick", function()
      if R.selected ~= s.id then ns.ui.details.hide(); timeline.toTop() end
      R.selected = s.id; R.page = 1; R.refresh()
    end)
    r.del:Hide()
    r:Show()
  end
  list.setContentHeight(i * 18)
  for _, r in ipairs(lineRows) do r:Hide() end
  local s = R.selected and db.sessions[R.selected]
  if not s then
    header:SetText("No sessions yet. Type /ac start to begin.") status:SetText("") pageLabel:SetText("")
    R.updateContinue(nil)
    -- Nothing to rename, filter or show details for once the last session is gone.
    ns.ui.details.hide(); renameLink:Hide(); filterButton:Hide(); filterPanel:Hide()
    timeline.setContentHeight(0)
    return
  end
  header:SetText(s.title ~= "" and s.title or "Untitled")
  if not titleBox:IsShown() then renameLink:Show() end
  filterButton:Show()
  R.updateContinue(s)
  local all = R.entries(s)
  local filtered, total = ns.reviewfilter.apply(all, R.filter, R.qualityOf)
  refreshFilterButton()
  status:SetText(R.statusText(s, R.exportSize(s), #filtered, total))
  local entries = ns.details.group(filtered)
  if ns.ui.details.isShown() then
    local still = false
    local open = ns.ui.details.entry and ns.ui.details.entry.obs
    for _, o in ipairs(s.observations) do if o == open then still = true end end
    if not still then ns.ui.details.hide() end
  end
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
      r.text:SetText("|cff999999" .. when .. "|r  " .. ns.describe.observation(e.obs) .. ns.details.groupSuffix(e))
      r:SetScript("OnClick", function()
        -- Shift-click links the row's item or quest in chat, like the details panel; a plain click opens it.
        local P = ns.ui.details
        if P.shiftDown() and not e.group then
          local target = ns.details.linkTarget(e.obs)
          if target then P.link(target) return end
        end
        P.toggle(f, e)
      end)
      r:SetScript("OnEnter", function(self) ns.ui.details.showEntry(self, e) end)
      r:SetScript("OnLeave", function() ns.ui.details.hideTooltip() end)
      -- A grouped row's x deletes every line in it, as the row shows them as one.
      r.del:SetScript("OnClick", function()
        for _, g in ipairs(e.group or { e }) do ns.Session.deleteObservation(s, g.obs.seq, App.now()) end
        R.refresh()
      end)
    else
      r:SetScript("OnEnter", nil)
      r:SetScript("OnLeave", nil)
      local kind = e.note.kind == "bookmark" and "Bookmark" or "Note"
      local preview = e.note.text:gsub("\n", " ")
      local sep = preview ~= "" and ":|r " or "|r"
      r.text:SetText("|cff999999" .. when .. "|r  |cffd9a441" .. kind .. sep .. preview)
      r:SetScript("OnClick", function() if e.note.kind == "note" then ns.ui.notes.open(s.id, e.note.id) end end)
      r.del:SetScript("OnClick", function() ns.Session.deleteNote(s, App.now(), e.note.id); R.refresh() end)
    end
    r.del:Show()
    r:Show()
  end
  timeline.setContentHeight(n * 18)
end

function R.open()
  if not f then build() end
  f:Show()
  R.refresh()
end

return R
