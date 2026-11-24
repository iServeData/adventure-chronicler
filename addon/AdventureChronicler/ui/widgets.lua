-- Adventure Chronicler: small shared helpers for the windows. Uses only standard Blizzard templates.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local W = {}
ns.ui.widgets = W

-- A movable dialog with a title and close button. Position is not saved between sessions.
function W.window(name, title, width, height)
  local f = CreateFrame("Frame", name, UIParent, "BasicFrameTemplateWithInset")
  f:SetSize(width, height)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)
  f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  f.title:SetPoint("TOP", 0, -5)
  f.title:SetText(title)
  tinsert(UISpecialFrames, name) -- Escape closes it
  f:Hide()
  return f
end

function W.button(parent, text, width, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(width or 90, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

-- A scrolling multi-line edit box. No letter limit is set so the game never cuts text off silently;
-- the caller checks length and refuses to save instead.
function W.multiline(parent)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  local edit = CreateFrame("EditBox", nil, scroll)
  edit:SetMultiLine(true)
  edit:SetAutoFocus(false)
  edit:SetFontObject(ChatFontNormal)
  edit:SetWidth(300)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  scroll:SetScrollChild(edit)
  scroll:SetScript("OnSizeChanged", function(_, w) edit:SetWidth(math.max(50, w - 4)) end)
  scroll:EnableMouse(true)
  scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
  return scroll, edit
end

return W
