-- Adventure Chronicler: hover tooltips and the details panel for the review window's rows.
-- Hovering an item shows the game's own item tooltip (from the item data the game already has on this
-- computer); a quest tries the game's quest tooltip and falls back to what was recorded. Clicking a row
-- opens a panel beside the review window with everything recorded for it (core/details.lua). Shift-click
-- on an item puts its link in the chat box, only if the player has the chat box open. Read-only: nothing
-- is changed, sent or looked up online.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local P = { entry = nil }
ns.ui.details = P

local panel, scroll, child, head, meta
local rows = {}
local WIDTH, TEXT_W = 330, 286

local function W() return ns.ui.widgets end
local function Dt() return ns.details end

local function qualityHex(id)
  local q = id and ns.ui.review and ns.ui.review.qualityOf and ns.ui.review.qualityOf(id)
  return q and ns.options and ns.options.QUALITY_COLOUR[q] or nil
end

local function itemLink(id)
  local info = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
  if not (id and info) then return nil end
  local ok, _, link = pcall(info, id)
  return ok and link or nil
end

local function requestItem(id)
  if id and C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
end

local function addLines(lines)
  for _, l in ipairs(lines or {}) do GameTooltip:AddLine(l, 0.95, 0.90, 0.79, true) end
end

-- The game's tooltip for a hyperlink ("item:123" or "quest:456"). True if the game filled it in.
local function gameTooltip(owner, link)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local ok = pcall(GameTooltip.SetHyperlink, GameTooltip, link)
  return ok and (tonumber(GameTooltip:NumLines()) or 0) > 0
end

-- An item: the game's tooltip, then the recorded lines. If the game hasn't loaded the item yet, the
-- recorded name now and one more try a moment later.
function P.showItem(owner, it, extra, retried)
  local id = it and it.item_id
  if id and gameTooltip(owner, "item:" .. id) then
    if extra and #extra > 0 then GameTooltip:AddLine(" "); addLines(extra) end
    GameTooltip:Show()
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(Dt().itemLabel(it or {}), 1, 1, 1)
  if id then GameTooltip:AddLine("The game hasn't loaded this item's details yet.", 0.66, 0.60, 0.50, true) end
  addLines(extra)
  GameTooltip:Show()
  if id and not retried and C_Timer and C_Timer.After then
    requestItem(id)
    C_Timer.After(0.5, function()
      if GameTooltip:GetOwner() == owner and owner:IsMouseOver() then P.showItem(owner, it, extra, true) end
    end)
  end
end

-- A row in the review window's timeline.
function P.showEntry(owner, e)
  local o = e.obs
  if not o then return end
  local D = Dt()
  local text = ns.describe.observation(o)
  if e.group then
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 0.82, 0)
    GameTooltip:AddLine(#e.group .. " lines recorded within a second (all kept):", 0.66, 0.60, 0.50, true)
    for _, g in ipairs(e.group) do
      GameTooltip:AddLine(date("%H:%M:%S", g.t) .. "  " .. ns.describe.observation(g.obs), 0.95, 0.90, 0.79)
    end
    GameTooltip:AddLine("Click for everything recorded.", 0.66, 0.60, 0.50)
    GameTooltip:Show()
    return
  end
  local extra = D.tooltip(o)
  local items = D.items(o)
  if #items == 1 and items[1].item_id and o.type ~= "loot.seen" then
    P.showItem(owner, items[1], extra)
    return
  end
  local qid = D.questId(o)
  if qid and gameTooltip(owner, "quest:" .. qid) then
    GameTooltip:AddLine(" "); addLines(extra); GameTooltip:Show()
    return
  end
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:SetText(text, 1, 0.82, 0, 1, true)
  for _, l in ipairs(extra) do
    local it
    for _, x in ipairs(items) do if D.itemLabel(x) == l then it = x end end
    local hex = it and qualityHex(it.item_id)
    if hex then GameTooltip:AddLine("|cff" .. hex .. l .. "|r", 1, 1, 1, true) else addLines({ l }) end
  end
  GameTooltip:Show()
end

function P.hideTooltip() GameTooltip:Hide() end

-- ------------------------------------------------------------------ the panel

local function build(review)
  panel = CreateFrame("Frame", nil, review)
  panel:SetSize(WIDTH, 460)
  panel:SetPoint("TOPLEFT", review, "TOPRIGHT", 4, 0)
  panel:EnableMouse(true)
  local bg = panel:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(); bg:SetTexture(W().media("frame_bg"))
  W().goldBorder(panel, 0)
  head = W().text(panel, "title", 16, W().GOLD)
  head:SetPoint("TOPLEFT", 16, -14)
  head:SetPoint("RIGHT", -40, 0)
  head:SetJustifyH("LEFT")
  head:SetWordWrap(false) -- one line; the rows below have the full details
  meta = W().text(panel, "body", 11, W().MUTED)
  meta:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
  meta:SetPoint("RIGHT", -16, 0)
  meta:SetJustifyH("LEFT")
  local x = W().deleteButton(panel)
  x:SetPoint("TOPRIGHT", -12, -12)
  x:SetScript("OnClick", function() P.hide() end)
  scroll, child = W().scroll(panel, TEXT_W + 8, 330)
  scroll:SetPoint("TOPLEFT", 16, -86)
  local foot = W().text(panel, "body", 10, W().MUTED)
  foot:SetPoint("BOTTOMLEFT", 16, 14); foot:SetPoint("RIGHT", -16, 0); foot:SetJustifyH("LEFT")
  foot:SetText("Only what was recorded. Shift-click an item to link it in chat.")
  panel:Hide()
end

local function rowAt(i)
  local r = rows[i]
  if r then return r end
  r = CreateFrame("Button", nil, child)
  r:SetWidth(TEXT_W)
  r.text = W().text(r, "body", 12, W().CREAM)
  r.text:SetPoint("TOPLEFT", 0, 0)
  r.text:SetWidth(TEXT_W)
  r.text:SetJustifyH("LEFT")
  r.text:SetWordWrap(true)
  rows[i] = r
  return r
end

local function fill(list)
  for _, r in ipairs(rows) do r:Hide() end
  local y = 0
  for i, l in ipairs(list) do
    local r = rowAt(i)
    local indent = l.indent or 0
    r:ClearAllPoints()
    r:SetPoint("TOPLEFT", indent, -y)
    r.text:SetWidth(TEXT_W - indent)
    r.text:SetText(l.text)
    local h = math.max(16, (tonumber(r.text:GetStringHeight()) or 14) + 4)
    r:SetHeight(h)
    r:SetScript("OnEnter", nil); r:SetScript("OnLeave", nil); r:SetScript("OnClick", nil)
    if l.item then
      local it = l.item
      r:SetScript("OnEnter", function(self) P.showItem(self, it) end)
      r:SetScript("OnLeave", P.hideTooltip)
      r:SetScript("OnClick", function()
        local link = itemLink(it.item_id)
        if link and IsShiftKeyDown and IsShiftKeyDown() and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
      end)
    end
    r:Show()
    y = y + h + (l.gap or 2)
  end
  scroll.setContentHeight(y)
  scroll.toTop()
end

local function esc(s) return (tostring(s or ""):gsub("|", "||")) end

-- Turns core/details.lua rows into text for the panel.
local function render(o)
  local out = {}
  for _, l in ipairs(Dt().lines(o)) do
    if l.item then
      local hex = qualityHex(l.item.item_id) or "f2e6c9"
      out[#out + 1] = { text = "|cff" .. hex .. esc(l.text) .. "|r", item = l.item, indent = 12 }
    elseif l.label then
      local v = l.text ~= "" and (" |cfff2e6c9" .. esc(l.text) .. "|r") or ""
      out[#out + 1] = { text = "|cffd6ab5c" .. esc(l.label) .. ":|r" .. v }
    else
      out[#out + 1] = { text = esc(l.text), indent = 12 }
    end
  end
  return out
end

function P.open(review, e)
  if not (e and e.obs) then return end
  if not panel then build(review) end
  local o = e.obs
  P.entry = e
  head:SetText(esc(ns.describe.observation(o)))
  meta:SetText(date("%Y-%m-%d %H:%M:%S", o.t or e.t) .. " · " .. Dt().kind(o.type) .. " · "
    .. (Dt().CERTAINTY[o.certainty] or ("certainty " .. Dt().NOT_RECORDED)))
  local list = {}
  if e.group then
    list[#list + 1] = { text = "|cffd6ab5cThis row stands for " .. #e.group
      .. " lines recorded within a second. All of them are kept and exported:|r" }
    for _, g in ipairs(e.group) do
      list[#list + 1] = { text = date("%H:%M:%S", g.t) .. "  " .. esc(ns.describe.observation(g.obs)), indent = 12 }
    end
    list[#list].gap = 10
  end
  for _, l in ipairs(render(o)) do list[#list + 1] = l end
  -- Beside the review window, on whichever side has room.
  panel:ClearAllPoints()
  local right = review.GetRight and tonumber(review:GetRight())
  local screen = UIParent.GetRight and tonumber(UIParent:GetRight())
  if right and screen and right + WIDTH + 4 > screen then
    panel:SetPoint("TOPRIGHT", review, "TOPLEFT", -4, 0)
  else
    panel:SetPoint("TOPLEFT", review, "TOPRIGHT", 4, 0)
  end
  panel:Show()
  fill(list)
end

-- Click the same row again to close it.
function P.toggle(review, e)
  if P.isShown() and P.entry and e.obs and P.entry.obs == e.obs then P.hide() else P.open(review, e) end
end

function P.hide() if panel then panel:Hide() end P.entry = nil end
function P.isShown() return panel ~= nil and panel:IsShown() == true end
function P.texts()
  local out = {}
  for _, r in ipairs(rows) do if r:IsShown() then out[#out + 1] = r.text:GetText() end end
  return out
end

return P
