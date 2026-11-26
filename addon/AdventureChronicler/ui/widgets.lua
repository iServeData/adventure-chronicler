-- Adventure Chronicler: shared look for the windows. Dark panels with gold trim, parchment strips and
-- serif headings, drawn with the addon's own artwork in media/ (made by tools/gen_textures.py) and the
-- game's standard fonts. Nothing is downloaded.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local W = {}
ns.ui.widgets = W

local MEDIA = "Interface\\AddOns\\AdventureChronicler\\media\\"
function W.media(name) return MEDIA .. name end

W.FONT_TITLE = "Fonts\\MORPHEUS.TTF"
W.FONT_BODY = "Fonts\\FRIZQT__.TTF"
W.CREAM = { 0.95, 0.90, 0.79 }
W.GOLD = { 0.84, 0.67, 0.36 }
W.INK = { 0.22, 0.14, 0.06 }
W.MUTED = { 0.66, 0.60, 0.50 }

-- A font string in the given face and size, falling back to a standard font object if the face
-- can't be set.
function W.text(parent, face, size, colour, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontHighlight")
  local ok = fs:SetFont(face == "title" and W.FONT_TITLE or W.FONT_BODY, size, "")
  if ok == false then fs:SetFontObject(size >= 16 and "GameFontHighlightLarge" or "GameFontHighlight") end
  local c = colour or W.CREAM
  fs:SetTextColor(c[1], c[2], c[3])
  return fs
end

local function line(parent, layer, r, g, b, a)
  local t = parent:CreateTexture(nil, layer or "BORDER")
  t:SetColorTexture(r, g, b, a or 1)
  return t
end

-- Two gold rules around a frame, like a picture frame, with small diamonds at the corners.
function W.goldBorder(f, inset)
  inset = inset or 0
  local G = W.GOLD
  local function rect(off, thick, alpha)
    local top = line(f, "BORDER", G[1], G[2], G[3], alpha)
    top:SetPoint("TOPLEFT", off, -off); top:SetPoint("TOPRIGHT", -off, -off); top:SetHeight(thick)
    local bottom = line(f, "BORDER", G[1], G[2], G[3], alpha)
    bottom:SetPoint("BOTTOMLEFT", off, off); bottom:SetPoint("BOTTOMRIGHT", -off, off); bottom:SetHeight(thick)
    local left = line(f, "BORDER", G[1], G[2], G[3], alpha)
    left:SetPoint("TOPLEFT", off, -off); left:SetPoint("BOTTOMLEFT", off, off); left:SetWidth(thick)
    local right = line(f, "BORDER", G[1], G[2], G[3], alpha)
    right:SetPoint("TOPRIGHT", -off, -off); right:SetPoint("BOTTOMRIGHT", -off, off); right:SetWidth(thick)
  end
  rect(inset, 2, 0.95)
  rect(inset + 5, 1, 0.55)
  for _, p in ipairs({ "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }) do
    local d = f:CreateTexture(nil, "OVERLAY")
    d:SetTexture(W.media("diamond"))
    d:SetSize(12, 12)
    d:SetPoint("CENTER", f, p, (p:find("LEFT") and 1 or -1) * (inset + 1), (p:find("TOP") and -1 or 1) * (inset + 1))
  end
end

-- A gold rule across a frame with a diamond in the middle.
function W.divider(parent, y, inset)
  inset = inset or 20
  local G = W.GOLD
  local l = line(parent, "ARTWORK", G[1], G[2], G[3], 0.6)
  l:SetHeight(1)
  l:SetPoint("TOPLEFT", inset, y)
  l:SetPoint("TOPRIGHT", -inset, y)
  local d = parent:CreateTexture(nil, "OVERLAY")
  d:SetTexture(W.media("diamond"))
  d:SetSize(10, 10)
  d:SetPoint("CENTER", l, "CENTER")
  return l
end

-- A parchment strip with a thin gold edge.
function W.parchment(parent)
  local p = CreateFrame("Frame", nil, parent)
  local edge = line(p, "BACKGROUND", W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.85)
  edge:SetPoint("TOPLEFT", -1, 1); edge:SetPoint("BOTTOMRIGHT", 1, -1)
  local bg = p:CreateTexture(nil, "BORDER")
  bg:SetAllPoints()
  bg:SetTexture(W.media("parchment"))
  return p
end

local function iconButton(parent, size, tex)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  b:SetNormalTexture(W.media(tex))
  b:SetHighlightTexture(W.media("button_glow"), "ADD")
  return b
end

-- A movable dialog with a dark panel, gold frame, serif title and close button.
-- opts.header sets the title bar height; opts.compass adds the compass emblem.
function W.window(name, title, width, height, opts)
  opts = opts or {}
  local header = opts.header or 30
  local f = CreateFrame("Frame", name, UIParent)
  f:SetSize(width, height)
  f:SetPoint("CENTER")
  f:SetFrameStrata("DIALOG")
  f:SetToplevel(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
  f:SetClampedToScreen(true)

  local bg = f:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(W.media("frame_bg"))
  local hb = f:CreateTexture(nil, "BACKGROUND", nil, 1)
  hb:SetPoint("TOPLEFT", 2, -2); hb:SetPoint("TOPRIGHT", -2, -2); hb:SetHeight(header)
  hb:SetTexture(W.media("header_bg"))
  W.goldBorder(f, 0)
  local rule = line(f, "ARTWORK", W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.8)
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 6, -header)
  rule:SetPoint("TOPRIGHT", -6, -header)

  local left = 14
  if opts.compass then
    local c = f:CreateTexture(nil, "OVERLAY")
    local size = math.floor(header * 0.78)
    c:SetSize(size, size)
    c:SetPoint("LEFT", f, "TOPLEFT", 12, -header / 2)
    c:SetTexture(W.media("compass"))
    left = 12 + size + 8
  end
  f.title = W.text(f, "title", opts.titleSize or (header >= 40 and 20 or 15), W.CREAM)
  f.title:SetPoint("LEFT", f, "TOPLEFT", left, -header / 2)
  f.title:SetText(title)

  local close = iconButton(f, header >= 40 and 24 or 18, "icon_close")
  close:SetPoint("RIGHT", f, "TOPRIGHT", -12, -header / 2)
  close:SetScript("OnClick", function() f:Hide() end)
  f.closeButton = close

  tinsert(UISpecialFrames, name) -- Escape closes it
  f:Hide()
  return f
end

local STYLE = { dark = "button_dark", red = "button_red", gold = "button_gold" }

local function styleButton(b, style)
  b:SetNormalTexture(W.media(STYLE[style] or STYLE.dark))
  b:SetPushedTexture(W.media(STYLE[style] or STYLE.dark))
  local pushed = b:GetPushedTexture()
  if pushed then pushed:SetVertexColor(0.8, 0.8, 0.8) end
  b:SetHighlightTexture(W.media("button_glow"), "ADD")
  b:SetDisabledTexture(W.media(STYLE[style] or STYLE.dark))
  local dis = b:GetDisabledTexture()
  if dis then dis:SetDesaturated(true); dis:SetVertexColor(0.6, 0.6, 0.6) end
end

-- Switch a W.button between styles (used for the selected export format).
function W.restyle(b, style)
  styleButton(b, style)
  local ink = style == "gold" and W.INK or W.CREAM
  b.label:SetTextColor(ink[1], ink[2], ink[3])
  b:SetScript("OnEnable", function(self) self.label:SetTextColor(ink[1], ink[2], ink[3]) end)
end

-- A text button in the gold-trimmed style. style is "dark" (default), "red" or "gold".
function W.button(parent, text, width, onClick, style, height)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(width or 90, height or 24)
  styleButton(b, style)
  local ink = style == "gold" and W.INK or W.CREAM
  b.label = W.text(b, "body", 12, ink)
  b.label:SetPoint("CENTER", 0, 0)
  b.label:SetText(text)
  b.SetText = function(self, t) self.label:SetText(t) end
  b:SetScript("OnClick", onClick)
  b:SetScript("OnDisable", function(self) self.label:SetTextColor(0.5, 0.5, 0.5) end)
  b:SetScript("OnEnable", function(self) self.label:SetTextColor(ink[1], ink[2], ink[3]) end)
  b:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self.label:SetPoint("CENTER", 1, -1) end end)
  b:SetScript("OnMouseUp", function(self) self.label:SetPoint("CENTER", 0, 0) end)
  return b
end

-- A tall button with an icon above its label.
function W.bigButton(parent, text, iconName, width, height, onClick, style)
  local b = W.button(parent, "", width, onClick, style, height)
  b.icon = b:CreateTexture(nil, "OVERLAY")
  b.icon:SetSize(26, 26)
  b.icon:SetPoint("TOP", 0, -8)
  b.icon:SetTexture(W.media(iconName))
  b.label:ClearAllPoints()
  b.label:SetPoint("BOTTOM", 0, 9)
  local ok = b.label:SetFont(W.FONT_BODY, 13, "")
  if ok == false then b.label:SetFontObject("GameFontHighlight") end
  b.label:SetText(text)
  b:SetScript("OnMouseDown", nil); b:SetScript("OnMouseUp", nil)
  return b
end

-- A small gold text link.
function W.link(parent, text, onClick)
  local b = CreateFrame("Button", nil, parent)
  b.label = W.text(b, "body", 12, W.GOLD)
  b.label:SetPoint("CENTER")
  b.SetText = function(self, t)
    self.label:SetText(t)
    self:SetSize((tonumber(self.label:GetStringWidth()) or 60) + 8, 18)
  end
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  b:SetScript("OnEnter", function(self) self.label:SetTextColor(1, 0.86, 0.55) end)
  b:SetScript("OnLeave", function(self) self.label:SetTextColor(W.GOLD[1], W.GOLD[2], W.GOLD[3]) end)
  return b
end

-- A small gold X used to delete a row.
function W.deleteButton(parent)
  local b = iconButton(parent, 16, "icon_close")
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
  edit:SetTextColor(W.CREAM[1], W.CREAM[2], W.CREAM[3])
  edit:SetWidth(300)
  edit:SetScript("OnEscapePressed", edit.ClearFocus)
  scroll:SetScrollChild(edit)
  scroll:SetScript("OnSizeChanged", function(_, w) edit:SetWidth(math.max(50, w - 4)) end)
  scroll:EnableMouse(true)
  scroll:SetScript("OnMouseDown", function() edit:SetFocus() end)
  return scroll, edit
end

-- A scrolling area with a slim gold bar that shows only when the content is taller than the area. Replaces
-- the game's UIPanelScrollFrameTemplate, whose arrows and thumb showed as plain dark squares on WoW Forever
-- (0.3.4 review window). The mouse wheel scrolls; the thumb can be dragged. The caller sets the anchors and
-- calls scroll.setContentHeight(h) after filling the child.
function W.scroll(parent, width, height)
  local sf = CreateFrame("ScrollFrame", nil, parent)
  sf:SetSize(width, height)
  local child = CreateFrame("Frame", nil, sf)
  child:SetSize(width, 10)
  sf:SetScrollChild(child)
  local bar = CreateFrame("Slider", nil, sf)
  bar:SetOrientation("VERTICAL")
  bar:EnableMouse(true)
  bar:SetWidth(6)
  bar:SetPoint("TOPLEFT", sf, "TOPRIGHT", 6, 0)
  bar:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 6, 0)
  local track = line(bar, "BACKGROUND", 0, 0, 0, 0.45)
  track:SetAllPoints()
  local thumb = bar:CreateTexture(nil, "OVERLAY")
  thumb:SetColorTexture(W.GOLD[1], W.GOLD[2], W.GOLD[3], 0.85)
  thumb:SetSize(6, 30)
  bar:SetThumbTexture(thumb)
  bar:SetMinMaxValues(0, 0)
  bar:SetValueStep(1)
  bar:SetValue(0)
  bar:Hide()
  bar:SetScript("OnValueChanged", function(_, v) sf:SetVerticalScroll(v) end)
  sf:EnableMouseWheel(true)
  sf:SetScript("OnMouseWheel", function(_, delta)
    local _, max = bar:GetMinMaxValues()
    bar:SetValue(math.max(0, math.min(tonumber(max) or 0, (tonumber(bar:GetValue()) or 0) - delta * 36)))
  end)
  sf.bar, sf.child = bar, child
  function sf.setContentHeight(h)
    h = math.max(10, h or 10)
    child:SetHeight(h)
    local view = tonumber(sf:GetHeight()) or height
    local max = math.max(0, h - view)
    bar:SetMinMaxValues(0, max)
    if (tonumber(bar:GetValue()) or 0) > max then bar:SetValue(max) end
    thumb:SetHeight(math.max(20, view * view / h))
    if max > 0 then bar:Show() else bar:Hide(); bar:SetValue(0); sf:SetVerticalScroll(0) end
  end
  function sf.toTop() bar:SetValue(0); sf:SetVerticalScroll(0) end
  return sf, child
end

-- A tick box with a label, using the game's own check button. onChange(checked) runs when clicked.
function W.check(parent, label, onChange, colour)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb.label = W.text(cb, "body", 12, colour or W.CREAM)
  cb.label:SetPoint("LEFT", cb, "RIGHT", 4, 0)
  cb.label:SetText(label or "")
  cb:SetScript("OnClick", function(self) if onChange then onChange(self:GetChecked() == true) end end)
  return cb
end

-- A one-line parchment field that can be selected and copied but not changed. Returns the box and the
-- edit box; box:SetValue(text) sets what it shows.
function W.readonly(parent, height)
  local box = W.parchment(parent)
  box:SetHeight(height or 26)
  local e = CreateFrame("EditBox", nil, box)
  e:SetAutoFocus(false)
  e:SetHeight(20)
  e:SetPoint("LEFT", 8, 0)
  e:SetPoint("RIGHT", -8, 0)
  e:SetFontObject(ChatFontNormal)
  e:SetTextColor(W.INK[1], W.INK[2], W.INK[3])
  box.value = ""
  e:SetScript("OnTextChanged", function(self, user) if user then self:SetText(box.value); self:HighlightText() end end)
  e:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  e:SetScript("OnEscapePressed", e.ClearFocus)
  box.SetValue = function(self, v) self.value = v or ""; e:SetText(self.value); e:SetCursorPosition(0) end
  box.edit = e
  return box, e
end

-- A one-line parchment field the player types into. Returns the box and the edit box.
function W.input(parent, height)
  local box = W.parchment(parent)
  box:SetHeight(height or 26)
  local e = CreateFrame("EditBox", nil, box)
  e:SetAutoFocus(false)
  e:SetHeight(20)
  e:SetPoint("LEFT", 8, 0)
  e:SetPoint("RIGHT", -8, 0)
  e:SetFontObject(ChatFontNormal)
  e:SetTextColor(W.INK[1], W.INK[2], W.INK[3])
  e:SetScript("OnEscapePressed", e.ClearFocus)
  box.edit = e
  return box, e
end

-- A button showing the current choice; clicking it opens a list below it. choices = { {value, label}, ... }.
-- onPick(value) runs when one is clicked. Returns the button; button:SetValue(value) updates its label.
function W.choice(parent, width, choices, onPick)
  local b = W.button(parent, "", width, nil, "dark", 24)
  local menu = CreateFrame("Frame", nil, b)
  menu:SetFrameStrata("FULLSCREEN_DIALOG")
  menu:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -2)
  menu:SetSize(width, #choices * 20 + 10)
  local bg = menu:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(W.media("frame_bg"))
  W.goldBorder(menu, 0)
  menu:Hide()
  for i, c in ipairs(choices) do
    local row = CreateFrame("Button", nil, menu)
    row:SetSize(width - 12, 20)
    row:SetPoint("TOPLEFT", 6, -5 - (i - 1) * 20)
    row:SetHighlightTexture(W.media("button_glow"), "ADD")
    row.label = W.text(row, "body", 12, W.CREAM)
    row.label:SetPoint("LEFT", 6, 0)
    row.label:SetText(c[2])
    row:SetScript("OnClick", function() menu:Hide(); b:SetValue(c[1]); if onPick then onPick(c[1]) end end)
  end
  b:SetScript("OnClick", function() if menu:IsShown() then menu:Hide() else menu:Show() end end)
  b.SetValue = function(self, v)
    for _, c in ipairs(choices) do if c[1] == v then self.label:SetText(c[2] .. "  v") end end
  end
  b.menu = menu
  return b
end

return W
