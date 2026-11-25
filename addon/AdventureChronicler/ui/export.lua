-- Adventure Chronicler: export dialog. Shows the session selected so it can be copied with Ctrl+C
-- (Cmd+C on Mac). Four formats:
--   Import code  for the QuestersBoard import form (the only form QuestersBoard reads)
--   Markdown, Text, JSON  readable copies to keep as a file
-- WoW doesn't let add-ons write files or open a browser, so "save to file" means paste into a new
-- file (a file name is suggested), and the QuestersBoard button shows the address to copy.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local X = {}
ns.ui.export = X

local f, edit, info, hint, text, session, kind
local tabs = {}
local linkWin, linkEdit, linkInfo, linkText

local HINT = {
  code = "For the QuestersBoard import form. Copy it, then use the QuestersBoard button to open the page.",
  markdown = "Readable copy. To keep it as a file, paste into a new file and save it as:",
  text = "Plain text copy. To keep it as a file, paste into a new file and save it as:",
  json = "The data as indented JSON (not an import code). To keep it, paste into a new file and save it as:",
}

local function setKind(k)
  local F = ns.ExportFormats
  local out, nameOrWhy, size = F.render(k, session, ns.App.settings, ns.App.VERSION)
  if not out then
    if k ~= "code" then setKind("code") end
    if nameOrWhy == "too_large" then
      hint:SetText(string.format("|cffff6060This format is too large to show (%d KB).|r",
        math.ceil((size or 0) / 1024)))
    else
      hint:SetText("|cffff6060This format couldn't be made. Please report this with /ac version.|r")
    end
    return
  end
  kind = k
  for key, b in pairs(tabs) do ns.ui.widgets.restyle(b, key == k and "gold" or "dark") end
  if k == "code" then hint:SetText(HINT.code .. "\nFile name if you keep it: |cffffd100" .. nameOrWhy .. "|r")
  else hint:SetText(HINT[k] .. "\n|cffffd100" .. nameOrWhy .. "|r") end
  text = out
  edit:SetText(text)
  edit:SetCursorPosition(0)
  edit:SetFocus()
  edit:HighlightText()
end

local function buildLink()
  local W = ns.ui.widgets
  linkWin = W.window("AdventureChroniclerLink", "Open QuestersBoard", 440, 170, {})
  linkWin:SetFrameStrata("FULLSCREEN_DIALOG")
  linkWin:SetFrameLevel((tonumber(f:GetFrameLevel()) or 1) + 20)
  linkInfo = linkWin:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  linkInfo:SetPoint("TOPLEFT", 18, -42)
  linkInfo:SetPoint("RIGHT", -16, 0)
  linkInfo:SetJustifyH("LEFT")
  local box = W.parchment(linkWin)
  box:SetPoint("TOPLEFT", 16, -88)
  box:SetPoint("TOPRIGHT", -16, -88)
  box:SetHeight(30)
  linkEdit = CreateFrame("EditBox", nil, box)
  linkEdit:SetAutoFocus(false)
  linkEdit:SetHeight(22)
  linkEdit:SetPoint("LEFT", 8, 0)
  linkEdit:SetPoint("RIGHT", -8, 0)
  linkEdit:SetFontObject(ChatFontNormal)
  linkEdit:SetTextColor(W.INK[1], W.INK[2], W.INK[3])
  -- Read-only, like the export text.
  linkEdit:SetScript("OnTextChanged", function(self, user)
    if user then self:SetText(linkText); self:HighlightText() end
  end)
  linkEdit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  linkEdit:SetScript("OnEscapePressed", function() linkWin:Hide() end)
  local close = W.button(linkWin, "Close", 80, function() linkWin:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -18, 14)
end

local function openLink()
  if not linkWin then buildLink() end
  local url = ns.App.validLink(ns.App.settings.questersboard_url)
  if url then
    linkText = url
    linkInfo:SetText("WoW add-ons can't open a browser. Press Ctrl+C (Cmd+C on Mac) to copy this address,\n"
      .. "then paste it into your browser. Copy the import code first if you haven't yet.")
    linkEdit:GetParent():Show()
  else
    linkText = ""
    linkInfo:SetText("No QuestersBoard address is set yet. Type this in chat, using your community's address:\n"
      .. "|cffffd100/ac link https://your-questersboard-address|r\nIt's saved with your settings on this computer.")
    linkEdit:GetParent():Hide()
  end
  linkEdit:SetText(linkText)
  linkWin:Show()
  linkWin:Raise()
  if url then linkEdit:SetFocus(); linkEdit:HighlightText() end
end

local function build()
  local W = ns.ui.widgets
  f = W.window("AdventureChroniclerExport", "Adventure Chronicler: export", 540, 400, { compass = true })
  -- Sits above the review window so its rows never show through. The note window shares this layer, and
  -- whichever of the two was opened or clicked last is on top.
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  info:SetPoint("TOPLEFT", 18, -42)
  info:SetPoint("RIGHT", -16, 0)
  info:SetJustifyH("LEFT")

  local label = W.text(f, "body", 12, W.CREAM)
  label:SetPoint("TOPLEFT", 18, -84)
  label:SetText("Format")
  local prev
  local WIDTH = { code = 100, markdown = 86, text = 60, json = 60 }
  for _, k in ipairs(ns.ExportFormats.ORDER) do
    local key = k
    local b = W.button(f, ns.ExportFormats.LABEL[k], WIDTH[k], function() setKind(key) end, "dark", 22)
    if prev then b:SetPoint("LEFT", prev, "RIGHT", 4, 0) else b:SetPoint("LEFT", label, "RIGHT", 10, 0) end
    tabs[k] = b
    prev = b
  end

  hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  hint:SetPoint("TOPLEFT", 18, -104)
  hint:SetPoint("RIGHT", -16, 0)
  hint:SetJustifyH("LEFT")

  local scroll
  scroll, edit = W.multiline(f)
  scroll:SetPoint("TOPLEFT", 16, -138)
  scroll:SetPoint("BOTTOMRIGHT", -34, 50)
  -- Read-only: typing restores the original text so the copied export is always intact.
  edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(text); self:HighlightText() end end)
  edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  local close = W.button(f, "Close", 80, function() f:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -18, 16)
  local sel = W.button(f, "Select all", 90, function() edit:SetFocus(); edit:HighlightText() end, "gold")
  sel:SetPoint("RIGHT", close, "LEFT", -6, 0)
  local qb = W.button(f, "Open QuestersBoard", 150, openLink)
  qb:SetPoint("BOTTOMLEFT", 18, 16)
  f:SetScript("OnHide", function() if linkWin then linkWin:Hide() end end)
end

X.openLink = function() if f then openLink() end end
X.setKind = function(k) if f and session then setKind(k) end end

-- exportText is the import code App.export already checked; the other formats are made on demand.
function X.open(exportText, s)
  if not f then build() end
  session = s
  local sum = ns.Export.summary(s)
  info:SetText(string.format("%d observations, %d notes (import code %.1f KB). Ctrl+C (Cmd+C on Mac) copies.\n"
    .. "Contains no chat or other players. Character name is %s.", sum.observations, sum.notes, #exportText / 1024,
    ns.App.settings.include_identity and "|cffffd100included|r" or "not included"))
  f:Show()
  f:Raise()
  setKind(kind or "code")
end

return X
