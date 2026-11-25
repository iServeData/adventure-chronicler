-- Adventure Chronicler: a minimap button that opens the recorder, so /ac isn't needed. Drag it around
-- the minimap's edge; /ac set minimap off hides it. While a session is recording it shows a red dot
-- (gold while paused). The border and background are the game's own minimap button art.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local M = {}
ns.ui.minimap = M

local btn, dot
local atan2 = math.atan2 or math.atan -- luacheck: ignore (Lua 5.1 in the game; 5.3+ in tests)

-- Position on the edge of the minimap for an angle in degrees (0 = right, 90 = top).
function M.offset(angle, radius)
  local a = math.rad(angle or 200)
  return math.cos(a) * radius, math.sin(a) * radius
end

-- The angle in whole degrees (0-359) from the minimap centre to a point.
function M.angle(cx, cy, px, py)
  return math.floor(math.deg(atan2(py - cy, px - cx)) + 0.5) % 360
end

local function place()
  local r = (Minimap:GetWidth() or 140) / 2 + 10
  local x, y = M.offset(ns.App.settings.minimap_angle, r)
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function follow()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local s = Minimap:GetEffectiveScale()
  if not (mx and px and s and s > 0) then return end
  ns.App.settings.minimap_angle = M.angle(mx, my, px / s, py / s)
  place()
end

local function build()
  local W = ns.ui.widgets
  btn = CreateFrame("Button", "AdventureChroniclerMinimapButton", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:RegisterForClicks("LeftButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  bg:SetPoint("TOPLEFT", 7, -5)
  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetTexture(W.media("compass"))
  icon:SetPoint("TOPLEFT", 7, -6)
  local ring = btn:CreateTexture(nil, "OVERLAY")
  ring:SetSize(53, 53)
  ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
  ring:SetPoint("TOPLEFT")
  dot = btn:CreateTexture(nil, "OVERLAY", nil, 2)
  dot:SetSize(9, 9)
  dot:SetTexture(W.media("dot"))
  dot:SetPoint("TOPRIGHT", -3, -3)
  btn:SetScript("OnClick", function() ns.App.recorder() end)
  btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", follow) end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Adventure Chronicler")
    local _, status = ns.describe.status(ns.Session.active(ns.App.db))
    GameTooltip:AddLine(status, 1, 1, 1)
    GameTooltip:AddLine("Click to open. Drag to move around the minimap.", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("/ac set minimap off hides this button.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function M.frame() return btn, dot end

function M.update()
  local App = ns.App
  if not App.loaded or not _G.Minimap then return end
  if App.settings.minimap_button == false then
    if btn then btn:Hide() end
    return
  end
  if not btn then build() end
  place()
  local s = ns.Session.active(App.db)
  if s then
    local c = s.state == "recording" and ns.ui.indicator.RED or ns.ui.indicator.YELLOW
    dot:SetVertexColor(c[1], c[2], c[3])
    dot:Show()
  else
    dot:Hide()
  end
  btn:Show()
end

return M
