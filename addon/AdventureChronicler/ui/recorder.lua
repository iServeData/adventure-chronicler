-- Adventure Chronicler: the recorder window, laid out after panel 1 of the approved mock. It shows
-- whether recording is on, the session title, recorded time and the latest few entries, with Add note,
-- Stop and Export. It only shows what was recorded and never adds anything itself.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local R = {}
ns.ui.recorder = R

local WIDTH, HEIGHT = 310, 470
local RECENT, ROW = 3, 32
local TOP_ROWS = -214
local DOT = { green = { 0.30, 0.85, 0.35 }, yellow = { 1.0, 0.80, 0.25 }, gray = { 0.55, 0.55, 0.55 } }

local f, dot, status, titleBox, titleText, titleInput, inputRule, elapsed, emptyLabel, footer, spine
local rows, buttons, links, tick = {}, {}, {}, 0

local function build()
  local W = ns.ui.widgets
  f = W.window("AdventureChroniclerRecorder", "Adventure Recorder", WIDTH, HEIGHT,
    { header = 48, compass = true, titleSize = 19 })
  f:ClearAllPoints()
  f:SetPoint("CENTER", -300, 40)

  -- Status line, centred: a glowing dot and plain words.
  status = W.text(f, "body", 15, W.CREAM)
  status:SetPoint("TOP", 10, -64)
  dot = f:CreateTexture(nil, "OVERLAY")
  dot:SetTexture(W.media("dot"))
  dot:SetSize(18, 18)
  dot:SetPoint("RIGHT", status, "LEFT", -6, 0)
  W.divider(f, -90)

  -- Session title on parchment; an input box when no session is open.
  titleBox = W.parchment(f)
  titleBox:SetPoint("TOPLEFT", 20, -102)
  titleBox:SetPoint("TOPRIGHT", -20, -102)
  titleBox:SetHeight(56)
  local caption = W.text(titleBox, "body", 12, W.INK)
  caption:SetPoint("TOPLEFT", 12, -8)
  caption:SetText("Session title")
  titleText = W.text(titleBox, "title", 19, W.INK)
  titleText:SetPoint("BOTTOMLEFT", 12, 8)
  titleText:SetPoint("RIGHT", -12, 0)
  titleText:SetJustifyH("LEFT")
  titleText:SetWordWrap(false)
  titleInput = CreateFrame("EditBox", nil, titleBox)
  titleInput:SetAutoFocus(false)
  titleInput:SetHeight(22)
  titleInput:SetPoint("BOTTOMLEFT", 12, 6)
  titleInput:SetPoint("RIGHT", -12, 0)
  local ok = titleInput:SetFont(W.FONT_TITLE, 18, "")
  if ok == false then titleInput:SetFontObject("GameFontHighlightLarge") end
  titleInput:SetTextColor(W.INK[1], W.INK[2], W.INK[3])
  titleInput:SetMaxLetters(ns.limits.max_title_chars)
  -- With no session open, Enter starts one. During a session, Enter renames it and Escape keeps the old name.
  titleInput:SetScript("OnEnterPressed", function(self)
    local text = self:GetText()
    local renaming = self.renaming
    self.renaming = false
    self:ClearFocus()
    if renaming then ns.App.rename(text) else ns.App.start(text) end
  end)
  titleInput:SetScript("OnEscapePressed", function(self) self.renaming = false; self:ClearFocus(); R.refresh() end)
  titleInput:SetScript("OnEditFocusLost", function(self)
    if self.renaming then self.renaming = false; R.refresh() end
  end)
  -- Click the title during a session to rename it.
  local rename = CreateFrame("Button", nil, titleBox)
  rename:SetAllPoints()
  rename:SetScript("OnClick", function()
    local s = ns.Session.active(ns.App.db)
    if not s then titleInput:SetFocus() return end
    titleText:Hide()
    titleInput:SetText(s.title or "")
    titleInput:Show(); inputRule:Show()
    titleInput.renaming = true
    titleInput:SetFocus()
    titleInput:HighlightText()
  end)
  rename:SetScript("OnEnter", function(self)
    if not ns.Session.active(ns.App.db) then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText("Click to rename this session")
    GameTooltip:Show()
  end)
  rename:SetScript("OnLeave", function() GameTooltip:Hide() end)
  titleInput:SetFrameLevel((tonumber(rename:GetFrameLevel()) or 1) + 1)
  local pencil = titleBox:CreateTexture(nil, "OVERLAY")
  pencil:SetTexture(W.media("icon_note"))
  pencil:SetSize(16, 16)
  pencil:SetPoint("TOPRIGHT", -10, -8)
  pencil:SetVertexColor(W.INK[1], W.INK[2], W.INK[3], 0.7)
  inputRule = titleBox:CreateTexture(nil, "ARTWORK")
  inputRule:SetColorTexture(W.INK[1], W.INK[2], W.INK[3], 0.45)
  inputRule:SetHeight(1)
  inputRule:SetPoint("BOTTOMLEFT", 12, 6)
  inputRule:SetPoint("BOTTOMRIGHT", -12, 6)

  -- Recorded time. Paused time isn't counted, so it says "Recorded" rather than "Elapsed".
  local clock = f:CreateTexture(nil, "OVERLAY")
  clock:SetTexture(W.media("icon_clock"))
  clock:SetSize(22, 22)
  clock:SetPoint("TOPLEFT", 24, -170)
  local label = W.text(f, "body", 15, W.CREAM)
  label:SetPoint("LEFT", clock, "RIGHT", 10, 0)
  label:SetText("Recorded")
  elapsed = W.text(f, "body", 17, W.CREAM)
  elapsed:SetPoint("RIGHT", f, "TOPRIGHT", -24, -181)
  W.divider(f, -202)

  -- The latest entries on a gold timeline.
  spine = f:CreateTexture(nil, "ARTWORK")
  spine:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.7)
  spine:SetWidth(2)
  spine:SetPoint("TOP", f, "TOPLEFT", 33, TOP_ROWS - ROW / 2)
  for i = 1, RECENT do
    local y = TOP_ROWS - (i - 1) * ROW - ROW / 2
    local r = {}
    r.bead = f:CreateTexture(nil, "OVERLAY")
    r.bead:SetTexture(W.media("dot"))
    r.bead:SetVertexColor(W.GOLD[1], W.GOLD[2], W.GOLD[3])
    r.bead:SetSize(16, 16)
    r.bead:SetPoint("CENTER", f, "TOPLEFT", 33, y)
    r.icon = f:CreateTexture(nil, "OVERLAY")
    r.icon:SetSize(24, 24)
    r.icon:SetPoint("CENTER", f, "TOPLEFT", 64, y)
    r.text = W.text(f, "body", 14, W.CREAM)
    r.text:SetPoint("LEFT", f, "TOPLEFT", 86, y)
    r.text:SetWidth(WIDTH - 86 - 18)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    rows[i] = r
  end
  emptyLabel = W.text(f, "body", 13, W.MUTED)
  emptyLabel:SetPoint("TOP", 0, TOP_ROWS - 36)

  -- Main buttons, as in the mock.
  buttons.note = W.bigButton(f, "Add note", "icon_add_note", 84, 64, function() ns.App.note("") end, "dark")
  buttons.stop = W.bigButton(f, "Stop", "icon_stop", 84, 64, function()
    local s = ns.Session.active(ns.App.db)
    if s then StaticPopup_Show("ADVENTURECHRONICLER_STOP", s.title ~= "" and s.title or "this session") end
  end, "red")
  buttons.export = W.bigButton(f, "Export", "icon_export", 84, 64, function() ns.App.export() end, "dark")
  buttons.stop:SetPoint("BOTTOM", 0, 70)
  buttons.note:SetPoint("RIGHT", buttons.stop, "LEFT", -10, 0)
  buttons.export:SetPoint("LEFT", buttons.stop, "RIGHT", 10, 0)
  buttons.start = W.button(f, "Start recording", 200, function() ns.App.start(titleInput:GetText()) end,
    "gold", 44)
  local ok2 = buttons.start.label:SetFont(W.FONT_TITLE, 18, "")
  if ok2 == false then buttons.start.label:SetFontObject("GameFontNormalLarge") end
  buttons.start:SetPoint("BOTTOM", 0, 80)

  -- Smaller actions as gold links.
  links.pause = W.link(f, "Pause", function()
    local s = ns.Session.active(ns.App.db)
    if s and s.state == "paused" then ns.App.resume() else ns.App.pause() end
  end)
  links.mark = W.link(f, "Bookmark", function() ns.App.mark("") end)
  links.review = W.link(f, "Review", function() ns.App.review() end)
  links.settings = W.link(f, "Settings", function() ns.App.settingsWindow() end)
  links.sep1 = W.text(f, "body", 12, W.MUTED); links.sep1:SetText("·")
  links.sep2 = W.text(f, "body", 12, W.MUTED); links.sep2:SetText("·")
  links.sep3 = W.text(f, "body", 12, W.MUTED); links.sep3:SetText("·")
  -- Pause · Bookmark · Review · Settings, centred on the middle dot; with no session, Review · Settings.
  links.sep2:SetPoint("BOTTOM", 0, 44)
  links.mark:SetPoint("RIGHT", links.sep2, "LEFT", -4, 0)
  links.sep1:SetPoint("RIGHT", links.mark, "LEFT", -4, 0)
  links.pause:SetPoint("RIGHT", links.sep1, "LEFT", -4, 0)
  links.review:SetPoint("LEFT", links.sep2, "RIGHT", 4, 0)
  links.sep3:SetPoint("LEFT", links.review, "RIGHT", 4, 0)
  links.settings:SetPoint("LEFT", links.sep3, "RIGHT", 4, 0)

  -- Footer between two short rules.
  footer = W.text(f, "body", 11, W.MUTED)
  footer:SetPoint("BOTTOM", 0, 18)
  local function rule(anchor, side)
    local l = f:CreateTexture(nil, "ARTWORK")
    l:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.5)
    l:SetSize(28, 1)
    if side == "left" then l:SetPoint("RIGHT", anchor, "LEFT", -8, 0) else l:SetPoint("LEFT", anchor, "RIGHT", 8, 0) end
  end
  rule(footer, "left"); rule(footer, "right")

  f:SetScript("OnUpdate", function(_, dt)
    tick = tick + dt
    if tick >= 1 then tick = 0; R.refresh() end
  end)
  -- While this window is open the mini recorder steps aside; closing it during a session brings the
  -- mini recorder up (even if it had been closed with its x).
  f:SetScript("OnShow", function() if ns.ui.indicator then ns.ui.indicator.update() end end)
  f:SetScript("OnHide", function()
    local I = ns.ui.indicator
    if I then I.closed = false; I.update() end
  end)
end

function R.refresh()
  if not f or not f:IsShown() then return end
  local App = ns.App
  local s = ns.Session.active(App.db)
  local colour, words = ns.describe.status(s)
  local c = DOT[colour]
  dot:SetVertexColor(c[1], c[2], c[3])
  status:SetText(words)

  local open = s ~= nil
  local editing = titleInput.renaming
  titleText:SetShown(open and not editing)
  titleInput:SetShown(not open or editing)
  inputRule:SetShown(not open or editing)
  if open and not editing then titleText:SetText(s.title ~= "" and s.title or "Untitled") end
  elapsed:SetText(ns.util.formatDuration(open and ns.Session.recordedSeconds(s, App.now()) or 0))

  local recent = open and ns.describe.recent(s, RECENT) or {}
  for i, r in ipairs(rows) do
    local e = recent[i]
    r.bead:SetShown(e ~= nil); r.icon:SetShown(e ~= nil); r.text:SetShown(e ~= nil)
    if e then r.icon:SetTexture(e.icon); r.text:SetText(e.text) end
  end
  spine:SetShown(#recent > 1)
  spine:SetHeight(math.max(1, (#recent - 1) * ROW))
  emptyLabel:SetText(open and (#recent == 0 and "Nothing recorded yet." or "")
    or "Name your session, then start recording.")

  buttons.start:SetShown(not open)
  buttons.note:SetShown(open); buttons.stop:SetShown(open); buttons.export:SetShown(open)
  links.pause:SetShown(open); links.mark:SetShown(open)
  links.sep1:SetShown(open)
  links.pause:SetText(s and s.state == "paused" and "Resume" or "Pause")
  links.review:ClearAllPoints()
  if open then links.review:SetPoint("LEFT", links.sep2, "RIGHT", 4, 0)
  else links.review:SetPoint("RIGHT", links.sep2, "LEFT", -4, 0) end
  links.sep3:ClearAllPoints()
  if open then links.sep3:SetPoint("LEFT", links.review, "RIGHT", 4, 0)
  else links.sep3:Hide() end
  links.sep3:SetShown(open)
  links.settings:ClearAllPoints()
  if open then links.settings:SetPoint("LEFT", links.sep3, "RIGHT", 4, 0)
  else links.settings:SetPoint("LEFT", links.sep2, "RIGHT", 4, 0) end

  footer:SetText(App.settings.include_identity and "Character name included in exports"
    or "Chat and other players never recorded")
end

function R.toggle()
  if not f then build() end
  if f:IsShown() then f:Hide() else f:Show(); R.refresh() end
end

function R.isShown() return f ~= nil and f:IsShown() == true end

function R.close() if f then f:Hide() end end

function R.open()
  if not f then build() end
  f:Show()
  R.refresh()
end

return R
