-- Adventure Chronicler: the recording indicator. Visible whenever a session is recording or paused,
-- so it is always clear when the addon is collecting information. Three sizes:
--   full       REC / PAUSED and the time, a minimize button (x), and a row of small buttons: Open,
--              Note, Bookmark, Pause or Resume, Stop, Export and Review (/ac set buttons off hides the row)
--   minimized  a small tab: Open button, a red (recording) or gold (paused) dot and the time.
--              Clicking the tab brings the full window back. Remembered between sessions.
--   hidden     only with /ac set indicator hide (off by default). Nothing on screen, so the addon
--              reminds you in chat when recording starts, resumes, or you log in while recording,
--              and the minimap button shows the dot.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local I = {}
ns.ui.indicator = I

local frame, label, row, tab, tabLabel, tabDot, elapsed = nil, nil, nil, nil, nil, nil, 0
local buttons = {}

local SIZE, GAP, PAD = 22, 3, 4
local TAB_W, TAB_H = 84, 20
I.RED, I.YELLOW = { 1, 0.25, 0.25 }, { 1, 0.82, 0 }

local function stopAsk()
  local s = ns.Session.active(ns.App.db)
  if s then StaticPopup_Show("ADVENTURECHRONICLER_STOP", s.title ~= "" and s.title or "this session") end
end

local function pauseOrResume()
  local s = ns.Session.active(ns.App.db)
  if s and s.state == "paused" then ns.App.resume() else ns.App.pause() end
end

function I.minimize(on)
  ns.App.settings.indicator_minimized = on and true or false
  I.update()
end

-- key, icon, tooltip, action, tint
local ROW = {
  { "open", "compass", "Open Adventure Chronicler", function() ns.App.recorder() end },
  { "note", "icon_add_note", "Add note", function() ns.App.note("") end },
  { "mark", "icon_bookmark", "Bookmark this moment", function() ns.App.mark("") end },
  { "pause", "icon_pause", "Pause", pauseOrResume },
  { "stop", "icon_stop", "Stop (asks first)", stopAsk, { 1, 0.45, 0.4 } },
  { "export", "icon_export", "Export", function() ns.App.export() end },
  { "review", "icon_review", "Review", function() ns.App.review() end },
}
I.ROW = ROW

local function smallButton(parent, spec, size)
  local W = ns.ui.widgets
  size = size or SIZE
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(W.media("button_dark"))
  b:SetHighlightTexture(W.media("button_glow"), "ADD")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(size - 6, size - 6)
  b.icon:SetPoint("CENTER")
  b.icon:SetTexture(W.media(spec[2]))
  if spec[5] then b.icon:SetVertexColor(spec[5][1], spec[5][2], spec[5][3]) end
  b.tip = spec[3]
  b:SetScript("OnClick", spec[4])
  b:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1) end)
  b:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", 0, 0) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(self.tip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function border(f)
  local G = ns.ui.widgets.GOLD
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, "BORDER")
    t:SetColorTexture(G[1], G[2], G[3], 0.9)
    if side == "TOP" or side == "BOTTOM" then
      t:SetHeight(1); t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT")
    else
      t:SetWidth(1); t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side)
    end
  end
end

local function movable(f)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
end

local function ticker(f)
  f:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed >= 1 then elapsed = 0; I.update() end
  end)
end

local function build()
  local W = ns.ui.widgets
  frame = CreateFrame("Button", "AdventureChroniclerIndicator", UIParent)
  frame:SetSize(#ROW * (SIZE + GAP) - GAP + PAD * 2, 26)
  frame:SetPoint("TOP", 0, -120)
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(W.media("frame_bg"))
  border(frame)
  movable(frame)
  frame:SetScript("OnClick", function() ns.App.recorder() end)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Adventure Chronicler")
    GameTooltip:AddLine("Click to open. Drag to move. x makes it a small tab.", 1, 1, 1)
    GameTooltip:AddLine("The small buttons: open, note, bookmark, pause, stop, export, review.", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("/ac set buttons off hides them.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  label = W.text(frame, "body", 12, W.CREAM)
  label:SetPoint("TOP", 0, -7)

  local close = smallButton(frame, { "minimize", "icon_close", "Minimize (click the small tab to bring it back)",
    function() I.minimize(true) end }, 16)
  close:SetPoint("TOPRIGHT", -4, -5)
  buttons.minimize = close

  row = CreateFrame("Frame", nil, frame)
  row:SetPoint("BOTTOMLEFT", PAD, PAD)
  row:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  row:SetHeight(SIZE)
  for i, spec in ipairs(ROW) do
    local b = smallButton(row, spec)
    b:SetPoint("LEFT", (i - 1) * (SIZE + GAP), 0)
    buttons[spec[1]] = b
  end
  ticker(frame)
end

local function buildTab()
  local W = ns.ui.widgets
  tab = CreateFrame("Button", "AdventureChroniclerIndicatorTab", UIParent)
  tab:SetSize(TAB_W, TAB_H)
  tab:SetPoint("TOP", 0, -120)
  local bg = tab:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(W.media("frame_bg"))
  border(tab)
  movable(tab)
  tab:SetScript("OnClick", function() I.minimize(false) end)
  tab:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Adventure Chronicler")
    GameTooltip:AddLine("Click to show the full window. Drag to move.", 1, 1, 1)
    GameTooltip:Show()
  end)
  tab:SetScript("OnLeave", function() GameTooltip:Hide() end)
  local open = smallButton(tab, { "tab_open", "compass", "Open Adventure Chronicler",
    function() ns.App.recorder() end }, 16)
  open:SetPoint("LEFT", 2, 0)
  buttons.tab_open = open
  tabDot = tab:CreateTexture(nil, "ARTWORK")
  tabDot:SetSize(8, 8)
  tabDot:SetTexture(W.media("dot"))
  tabDot:SetPoint("LEFT", open, "RIGHT", 5, 0)
  tabLabel = W.text(tab, "body", 11, W.CREAM)
  tabLabel:SetPoint("LEFT", tabDot, "RIGHT", 4, 0)
  ticker(tab)
end

function I.frames() return frame, tab, buttons end

-- Which form to show for this session: nil (none), "full", "tab" or "hidden".
function I.mode(settings, s)
  if not s then return nil end
  if settings.show_indicator == false then return "hidden" end
  if settings.indicator_minimized == true then return "tab" end
  return "full"
end

function I.update()
  local App = ns.App
  if not App.loaded then return end
  local s = ns.Session.active(App.db)
  local mode = I.mode(App.settings, s)
  if mode ~= "full" and frame then frame:Hide() end
  if mode ~= "tab" and tab then tab:Hide() end
  if ns.ui.minimap then ns.ui.minimap.update() end
  if mode ~= "full" and mode ~= "tab" then return end
  local t = ns.util.formatDuration(ns.Session.recordedSeconds(s, App.now()))
  local paused = s.state ~= "recording"
  if mode == "tab" then
    if not tab then buildTab() end
    local c = paused and I.YELLOW or I.RED
    tabDot:SetVertexColor(c[1], c[2], c[3])
    tabLabel:SetText(t)
    tab:Show()
    return
  end
  if not frame then build() end
  if paused then label:SetText("|cffffd100PAUSED|r  " .. t) else label:SetText("|cffff4040REC|r  " .. t) end
  local W = ns.ui.widgets
  buttons.pause.icon:SetTexture(W.media(paused and "icon_resume" or "icon_pause"))
  buttons.pause.tip = paused and "Resume" or "Pause"
  if App.settings.indicator_buttons ~= false then
    row:Show(); frame:SetHeight(26 + SIZE + PAD)
  else
    row:Hide(); frame:SetHeight(26)
  end
  frame:Show()
end

return I
