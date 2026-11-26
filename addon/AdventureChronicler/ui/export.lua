-- Adventure Chronicler: export dialog. Shows the session selected so it can be copied with Ctrl+C
-- (Cmd+C on Mac). Four formats:
--   Import code  for the QuestersBoard import form (the only form QuestersBoard reads)
--   Markdown, Text, JSON  readable copies to keep as a file
-- WoW doesn't let add-ons write files or open a browser, so "save to file" means paste into a new
-- file (a file name is suggested), and the import code shows the address to paste it at, to copy.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local X = {}
ns.ui.export = X

local f, edit, info, hint, text, session, kind, scroll, sel
local tabs = {}
local step1, step2, pasteBox, pasteNote
local exportedBefore = false

local HINT = {
  markdown = "Readable copy. To keep it as a file, paste into a new file and save it as:",
  text = "Plain text copy. To keep it as a file, paste into a new file and save it as:",
  json = "The data as indented JSON (not an import code). To keep it, paste into a new file and save it as:",
}

-- The import code shows the two steps (copy it, paste it at the address); the other formats show the
-- file name to save them under.
local function layout(isCode)
  step1:SetShown(isCode); step2:SetShown(isCode); pasteBox:SetShown(isCode); pasteNote:SetShown(isCode)
  hint:SetShown(not isCode)
  scroll:ClearAllPoints()
  scroll:SetPoint("TOPLEFT", 16, isCode and -128 or -138)
  scroll:SetPoint("BOTTOMRIGHT", -34, isCode and 112 or 50)
  sel:SetText(isCode and "Select code" or "Select all")
  if isCode then
    local url = ns.App.link()
    pasteBox:SetValue(url or "")
    pasteNote:SetText("Click the address and press Ctrl+C (Cmd+C on Mac), then paste it in your browser.\n"
      .. X.secondLine(session, exportedBefore))
  end
end

-- The second line under the address. A session that was continued or exported before may already be on
-- the board: pasting it again offers to update that story's log, never a second story.
function X.secondLine(s, before)
  if s and ((s.continued or 0) > 0 or before) then
    return "Already imported it? Paste it at the same address to update that story's log."
  end
  return "Change it in Settings (Export tab) or with |cffffd100/ac link|r."
end

local function setKind(k)
  local F = ns.ExportFormats
  local out, nameOrWhy, size = F.render(k, session, ns.App.settings, ns.App.VERSION)
  if not out then
    if k ~= "code" then setKind("code") end
    hint:Show()
    if nameOrWhy == "too_large" then
      hint:SetText(string.format("|cffff6060This format is too large to show (%d KB).|r",
        math.ceil((size or 0) / 1024)))
    else
      hint:SetText("|cffff6060This format couldn't be made. Please report this with /ac report.|r")
    end
    return
  end
  kind = k
  for key, b in pairs(tabs) do ns.ui.widgets.restyle(b, key == k and "gold" or "dark") end
  layout(k == "code")
  if k ~= "code" then hint:SetText(HINT[k] .. "\n|cffffd100" .. nameOrWhy .. "|r") end
  text = out
  edit:SetText(text)
  edit:SetCursorPosition(0)
  edit:SetFocus()
  edit:HighlightText()
end

local function build()
  local W = ns.ui.widgets
  f = W.window("AdventureChroniclerExport", W.BRAND .. ": export", 540, 430, { compass = true })
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

  step1 = W.text(f, "body", 13, W.GOLD)
  step1:SetPoint("TOPLEFT", 18, -108)
  step1:SetText("1. Copy the code  |cffa89880Ctrl+A, then Ctrl+C (Cmd on Mac)|r")

  scroll, edit = W.multiline(f)
  -- Read-only: typing restores the original text so the copied export is always intact.
  edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(text); self:HighlightText() end end)
  edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

  step2 = W.text(f, "body", 13, W.GOLD)
  step2:SetPoint("BOTTOMLEFT", 18, 90)
  step2:SetText("2. Paste the code at:")
  pasteBox = W.readonly(f, 26)
  pasteBox:SetPoint("LEFT", step2, "RIGHT", 10, 0)
  pasteBox:SetPoint("RIGHT", f, "RIGHT", -18, 0)
  pasteNote = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  pasteNote:SetPoint("TOPLEFT", step2, "BOTTOMLEFT", 0, -10)
  pasteNote:SetPoint("RIGHT", -16, 0)
  pasteNote:SetJustifyH("LEFT")

  local close = W.button(f, "Close", 80, function() f:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -18, 16)
  sel = W.button(f, "Select code", 100, function() edit:SetFocus(); edit:HighlightText() end, "gold")
  sel:SetPoint("RIGHT", close, "LEFT", -6, 0)
end

X.setKind = function(k) if f and session then setKind(k) end end
X.pasteAddress = function() return pasteBox and pasteBox.value end
X.refresh = function() if f and f:IsShown() and kind == "code" then layout(true) end end

-- exportText is the import code App.export already checked; the other formats are made on demand.
function X.open(exportText, s, before)
  if not f then build() end
  session = s
  exportedBefore = before == true
  local sum = ns.Export.summary(s)
  local name = s.title ~= nil and s.title ~= "" and ("|cffd6ab5c" .. s.title .. "|r · ") or ""
  info:SetText(string.format("%s%d observations, %d notes (%.1f KB)\n"
    .. "Contains no chat or other players. Character name is %s.", name, sum.observations, sum.notes,
    #exportText / 1024, ns.App.settings.include_identity and "|cffffd100included|r" or "not included"))
  f:Show()
  f:Raise()
  setKind(kind or "code")
end

return X
