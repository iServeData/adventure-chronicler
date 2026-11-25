-- Adventure Chronicler: the recording indicator. Visible whenever a session is recording or paused,
-- so it is always clear when the addon is collecting information.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local I = {}
ns.ui.indicator = I

local frame, label, elapsed = nil, nil, 0

local function build()
  local W = ns.ui.widgets
  frame = CreateFrame("Button", "AdventureChroniclerIndicator", UIParent)
  frame:SetSize(150, 26)
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
    GameTooltip:AddLine("/ac pause, /ac resume, /ac stop", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  label = W.text(frame, "body", 12, W.CREAM)
  label:SetPoint("CENTER")
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
  if s.state == "recording" then
    label:SetText("|cffff4040REC|r  " .. t)
  else
    label:SetText("|cffffd100PAUSED|r  " .. t)
  end
  frame:Show()
end

return I
