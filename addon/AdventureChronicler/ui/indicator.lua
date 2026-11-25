-- Adventure Chronicler: the recording indicator. Visible whenever a session is recording or paused,
-- so it is always clear when the addon is collecting information. Under the REC / PAUSED line is a row
-- of small buttons: Note, Bookmark, Pause or Resume, Stop, Export and Review (/ac set buttons off hides it).
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local I = {}
ns.ui.indicator = I

local frame, label, row, elapsed = nil, nil, nil, 0
local buttons = {}

local SIZE, GAP, PAD = 22, 3, 4

local function stopAsk()
  local s = ns.Session.active(ns.App.db)
  if s then StaticPopup_Show("ADVENTURECHRONICLER_STOP", s.title ~= "" and s.title or "this session") end
end

local function pauseOrResume()
  local s = ns.Session.active(ns.App.db)
  if s and s.state == "paused" then ns.App.resume() else ns.App.pause() end
end

-- key, icon, tooltip, action, tint
local ROW = {
  { "note", "icon_add_note", "Add note", function() ns.App.note("") end },
  { "mark", "icon_bookmark", "Bookmark this moment", function() ns.App.mark("") end },
  { "pause", "icon_pause", "Pause", pauseOrResume },
  { "stop", "icon_stop", "Stop (asks first)", stopAsk, { 1, 0.45, 0.4 } },
  { "export", "icon_export", "Export", function() ns.App.export() end },
  { "review", "icon_review", "Review", function() ns.App.review() end },
}

local function smallButton(parent, spec)
  local W = ns.ui.widgets
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(SIZE, SIZE)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(W.media("button_dark"))
  b:SetHighlightTexture(W.media("button_glow"), "ADD")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(SIZE - 6, SIZE - 6)
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

local function build()
  local W = ns.ui.widgets
  frame = CreateFrame("Button", "AdventureChroniclerIndicator", UIParent)
  frame:SetSize(#ROW * (SIZE + GAP) - GAP + PAD * 2, 26)
  frame:SetPoint("TOP", 0, -120)
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(W.media("frame_bg"))
  local G = W.GOLD
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = frame:CreateTexture(nil, "BORDER")
    t:SetColorTexture(G[1], G[2], G[3], 0.9)
    if side == "TOP" or side == "BOTTOM" then
      t:SetHeight(1); t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT")
    else
      t:SetWidth(1); t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side)
    end
  end
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:RegisterForClicks("LeftButtonUp")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnClick", function() ns.App.recorder() end)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Adventure Chronicler")
    GameTooltip:AddLine("Click to open the recorder. Drag to move.", 1, 1, 1)
    GameTooltip:AddLine("The small buttons: note, bookmark, pause, stop, export, review.", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("/ac set buttons off hides them.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  label = W.text(frame, "body", 12, W.CREAM)
  label:SetPoint("TOP", 0, -7)

  row = CreateFrame("Frame", nil, frame)
  row:SetPoint("BOTTOMLEFT", PAD, PAD)
  row:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  row:SetHeight(SIZE)
  for i, spec in ipairs(ROW) do
    local b = smallButton(row, spec)
    b:SetPoint("LEFT", (i - 1) * (SIZE + GAP), 0)
    buttons[spec[1]] = b
  end
  frame:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed >= 1 then elapsed = 0; I.update() end
  end)
end

function I.update()
  local App = ns.App
  if not App.loaded then return end
  local s = ns.Session.active(App.db)
  if not s then
    if frame then frame:Hide() end
    return
  end
  if not frame then build() end
  local t = ns.util.formatDuration(ns.Session.recordedSeconds(s, App.now()))
  local paused = s.state ~= "recording"
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
