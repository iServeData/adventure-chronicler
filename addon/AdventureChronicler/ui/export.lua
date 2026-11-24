-- Adventure Chronicler: export dialog. Shows the export text selected so it can be copied with
-- Ctrl+C (Cmd+C on Mac) and pasted into the QuestersBoard import form or saved to a file.
-- The addon cannot write files or reach the internet; copying is always the player's choice.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local X = {}
ns.ui.export = X

local f, edit, info, text

local function build()
  local W = ns.ui.widgets
  f = W.window("AdventureChroniclerExport", "Adventure Chronicler: export", 520, 320)
  info = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  info:SetPoint("TOPLEFT", 16, -32)
  info:SetPoint("RIGHT", -16, 0)
  info:SetJustifyH("LEFT")
  local scroll
  scroll, edit = W.multiline(f)
  scroll:SetPoint("TOPLEFT", 14, -76)
  scroll:SetPoint("BOTTOMRIGHT", -32, 44)
  -- Read-only: typing restores the original text so the copied export is always intact.
  edit:SetScript("OnTextChanged", function(self, user) if user then self:SetText(text); self:HighlightText() end end)
  edit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  local close = W.button(f, "Close", 80, function() f:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -24, 12)
  local sel = W.button(f, "Select all", 90, function() edit:SetFocus(); edit:HighlightText() end)
  sel:SetPoint("RIGHT", close, "LEFT", -6, 0)
end

function X.open(exportText, s)
  if not f then build() end
  text = exportText
  local sum = ns.Export.summary(s)
  info:SetText(string.format("%d observations, %d notes, %.1f KB. Press Ctrl+C (Cmd+C on Mac) to copy.\n"
    .. "Contains no chat or other players. Character name is %s.", sum.observations, sum.notes, #text / 1024,
    ns.App.settings.include_identity and "|cffffd100included|r" or "not included"))
  edit:SetText(text)
  f:Show()
  edit:SetFocus()
  edit:HighlightText()
end

return X
