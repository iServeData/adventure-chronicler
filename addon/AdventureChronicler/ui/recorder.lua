-- Adventure Chronicler: the recorder window. A small panel showing whether recording is on, the
-- session title, recorded time and the latest few entries, with Add note, Stop and Export buttons.
-- Uses only standard game textures. It shows what was recorded and never adds anything itself.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local R = {}
ns.ui.recorder = R

local RECENT = 3
local DOT = {
  green = "Interface\\COMMON\\Indicator-Green", yellow = "Interface\\COMMON\\Indicator-Yellow",
  gray = "Interface\\COMMON\\Indicator-Gray",
}
local GOLD = { 0.85, 0.65, 0.25 }

local f, dot, status, titleBox, titleText, titleInput, elapsedLabel, emptyLabel, footer
local rows, buttons, tick = {}, {}, 0

local function divider(parent, y)
  local line = parent:CreateTexture(nil, "ARTWORK")
  line:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.5)
  line:SetHeight(1)
  line:SetPoint("TOPLEFT", 20, y)
  line:SetPoint("TOPRIGHT", -20, y)
  return line
end

-- A tall button with an icon above its label, like the mock.
local function bigButton(parent, label, icon, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(86, 46)
  b:SetText("")
  b.icon = b:CreateTexture(nil, "OVERLAY")
  b.icon:SetSize(18, 18)
  b.icon:SetPoint("TOP", 0, -6)
  b.icon:SetTexture(icon)
  b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.label:SetPoint("BOTTOM", 0, 7)
  b.label:SetText(label)
  b:SetScript("OnClick", onClick)
  return b
end

local function build()
  local W = ns.ui.widgets
  f = W.window("AdventureChroniclerRecorder", "Adventure Chronicler", 300, 372)
  f:SetPoint("CENTER", -260, 40)

  local book = f:CreateTexture(nil, "OVERLAY")
  book:SetSize(18, 18)
  book:SetPoint("TOPLEFT", 8, -3)
  book:SetTexture("Interface\\Icons\\INV_Misc_Book_09")

  dot = f:CreateTexture(nil, "OVERLAY")
  dot:SetSize(14, 14)
  dot:SetPoint("TOP", -62, -34)
  status = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  status:SetPoint("LEFT", dot, "RIGHT", 6, 0)
  divider(f, -56)

  -- Session title on a parchment strip; an input box when no session is open.
  titleBox = CreateFrame("Frame", nil, f)
  titleBox:SetPoint("TOPLEFT", 18, -64)
  titleBox:SetPoint("TOPRIGHT", -18, -64)
  titleBox:SetHeight(48)
  local parchment = titleBox:CreateTexture(nil, "BACKGROUND")
  parchment:SetAllPoints()
  parchment:SetColorTexture(0.82, 0.72, 0.52, 0.95)
  local edge = titleBox:CreateTexture(nil, "BORDER")
  edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
  edge:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.8)
  local caption = titleBox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  caption:SetPoint("TOPLEFT", 8, -6)
  caption:SetTextColor(0.25, 0.16, 0.05)
  caption:SetText("Session title")
  titleText = titleBox:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleText:SetPoint("BOTTOMLEFT", 8, 7)
  titleText:SetPoint("RIGHT", -8, 0)
  titleText:SetJustifyH("LEFT")
  titleText:SetWordWrap(false)
  titleText:SetTextColor(0.15, 0.09, 0.02)
  titleInput = CreateFrame("EditBox", nil, titleBox, "InputBoxTemplate")
  titleInput:SetAutoFocus(false)
  titleInput:SetHeight(20)
  titleInput:SetPoint("BOTTOMLEFT", 12, 5)
  titleInput:SetPoint("RIGHT", -8, 0)
  titleInput:SetMaxLetters(ns.limits.max_title_chars)
  titleInput:SetScript("OnEnterPressed", function(self) self:ClearFocus(); ns.App.start(self:GetText()) end)
  titleInput:SetScript("OnEscapePressed", titleInput.ClearFocus)

  local clock = f:CreateTexture(nil, "OVERLAY")
  clock:SetSize(16, 16)
  clock:SetPoint("TOPLEFT", 22, -124)
  clock:SetTexture("Interface\\Icons\\INV_Misc_PocketWatch_01")
  local el = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  el:SetPoint("LEFT", clock, "RIGHT", 8, 0)
  el:SetText("Recorded")
  elapsedLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
  elapsedLabel:SetPoint("TOPRIGHT", -22, -124)
  divider(f, -150)

  -- Latest entries on a thin gold timeline.
  local spine = f:CreateTexture(nil, "ARTWORK")
  spine:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.6)
  spine:SetWidth(2)
  spine:SetPoint("TOPLEFT", 31, -168)
  spine:SetHeight(64)
  R.spine = spine
  for i = 1, RECENT do
    local y = -160 - (i - 1) * 30
    local r = {}
    r.bead = f:CreateTexture(nil, "OVERLAY")
    r.bead:SetSize(10, 10)
    r.bead:SetPoint("TOPLEFT", 27, y - 9)
    r.bead:SetTexture("Interface\\COMMON\\Indicator-Yellow")
    r.icon = f:CreateTexture(nil, "OVERLAY")
    r.icon:SetSize(20, 20)
    r.icon:SetPoint("TOPLEFT", 46, y - 4)
    r.text = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    r.text:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.text:SetPoint("RIGHT", f, "RIGHT", -18, 0)
    r.text:SetJustifyH("LEFT")
    r.text:SetWordWrap(false)
    rows[i] = r
  end
  emptyLabel = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  emptyLabel:SetPoint("TOP", 0, -186)

  buttons.note = bigButton(f, "Add note", "Interface\\Icons\\INV_Misc_Note_06", function() ns.App.note("") end)
  buttons.stop = bigButton(f, "Stop", "Interface\\RAIDFRAME\\ReadyCheck-NotReady", function()
    local s = ns.Session.active(ns.App.db)
    if s then StaticPopup_Show("ADVENTURECHRONICLER_STOP", s.title ~= "" and s.title or "this session") end
  end)
  buttons.export = bigButton(f, "Export", "Interface\\Icons\\INV_Letter_15", function() ns.App.export() end)
  buttons.start = bigButton(f, "Start", "Interface\\Icons\\INV_Misc_Book_09", function()
    ns.App.start(titleInput:GetText())
  end)
  buttons.stop:SetPoint("BOTTOM", 0, 58)
  buttons.note:SetPoint("RIGHT", buttons.stop, "LEFT", -6, 0)
  buttons.export:SetPoint("LEFT", buttons.stop, "RIGHT", 6, 0)
  buttons.start:SetPoint("BOTTOM", 0, 58)

  buttons.pause = ns.ui.widgets.button(f, "Pause", 86, function()
    local s = ns.Session.active(ns.App.db)
    if s and s.state == "paused" then ns.App.resume() else ns.App.pause() end
  end)
  buttons.pause:SetPoint("BOTTOMLEFT", 18, 30)
  buttons.mark = ns.ui.widgets.button(f, "Bookmark", 86, function() ns.App.mark("") end)
  buttons.mark:SetPoint("LEFT", buttons.pause, "RIGHT", 6, 0)
  buttons.review = ns.ui.widgets.button(f, "Review all", 86, function() ns.App.review() end)
  buttons.review:SetPoint("LEFT", buttons.mark, "RIGHT", 6, 0)

  footer = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOM", 0, 12)

  f:SetScript("OnUpdate", function(_, dt)
    tick = tick + dt
    if tick >= 1 then tick = 0; R.refresh() end
  end)
end

function R.refresh()
  if not f or not f:IsShown() then return end
  local App = ns.App
  local s = ns.Session.active(App.db)
  local colour, words = ns.describe.status(s)
  dot:SetTexture(DOT[colour])
  status:SetText(words)

  local open = s ~= nil
  titleText:SetShown(open)
  titleInput:SetShown(not open)
  if open then titleText:SetText(s.title ~= "" and s.title or "Untitled") end
  elapsedLabel:SetText(ns.util.formatDuration(open and ns.Session.recordedSeconds(s, App.now()) or 0))

  local recent = open and ns.describe.recent(s, RECENT) or {}
  for i, r in ipairs(rows) do
    local e = recent[i]
    r.bead:SetShown(e ~= nil); r.icon:SetShown(e ~= nil); r.text:SetShown(e ~= nil)
    if e then r.icon:SetTexture(e.icon); r.text:SetText(e.text) end
  end
  R.spine:SetShown(#recent > 1)
  R.spine:SetHeight(math.max(1, (#recent - 1) * 30))
  emptyLabel:SetText(open and (#recent == 0 and "Nothing recorded yet." or "")
    or "Name your session, then press Start.")

  buttons.start:SetShown(not open)
  buttons.note:SetShown(open); buttons.stop:SetShown(open); buttons.export:SetShown(open)
  buttons.pause:SetShown(open); buttons.mark:SetShown(open)
  buttons.pause:SetText(s and s.state == "paused" and "Resume" or "Pause")

  footer:SetText(App.settings.include_identity and "Character name is included in exports"
    or "Chat and other players are never recorded")
end

function R.toggle()
  if not f then build() end
  if f:IsShown() then f:Hide() else f:Show(); R.refresh() end
end

function R.open()
  if not f then build() end
  f:Show()
  R.refresh()
end

return R
