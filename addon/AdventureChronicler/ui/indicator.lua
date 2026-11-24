-- Adventure Chronicler: the recording indicator. Visible whenever a session is recording or paused,
-- so it is always clear when the addon is collecting information.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local I = {}
ns.ui.indicator = I

local frame, label, elapsed = nil, nil, 0

local function build()
  frame = CreateFrame("Button", "AdventureChroniclerIndicator", UIParent, "BackdropTemplate")
  frame:SetSize(150, 24)
  frame:SetPoint("TOP", 0, -120)
  frame:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
                      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
                      insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  frame:SetBackdropColor(0, 0, 0, 0.75)
  frame:SetMovable(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:RegisterForClicks("LeftButtonUp")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetScript("OnClick", function() ns.App.review() end)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Adventure Chronicler")
    GameTooltip:AddLine("Click to review. Drag to move.", 1, 1, 1)
    GameTooltip:AddLine("/ac pause, /ac resume, /ac stop", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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
