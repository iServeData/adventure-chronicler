-- Adventure Chronicler: Report a problem. WoW add-ons can't send anything, so this writes a short report
-- to copy (version, game build, which settings are on, the last error the add-on caught) and says where
-- to paste it. No log, no import code and no names are in it; the player adds what happened.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local P = {}
ns.ui.report = P

local f, whatInput, counter, reportEdit, placeBox, placeNote, reportText

local function refresh()
  local App = ns.App
  local what = whatInput:GetText() or ""
  counter:SetText(#what .. " / " .. ns.report.MAX_WHAT)
  reportText = ns.report.build(App.reportInfo(what))
  reportEdit:SetText(reportText)
  local invite, issues = App.reportPlace()
  placeBox:SetValue(invite or issues or "")
  placeNote:SetText(invite and issues and ("Or on GitHub: " .. issues .. ". Never paste an import code in a public "
    .. "channel.") or "Never paste an import code in a public channel.")
end

local function build()
  local W = ns.ui.widgets
  f = W.window("AdventureChroniclerReport", "Report a problem", 560, 420, { compass = true, header = 40 })
  f:SetFrameStrata("FULLSCREEN_DIALOG")
  local s1 = W.text(f, "body", 13, W.GOLD)
  s1:SetPoint("TOPLEFT", 20, -54)
  s1:SetText("1. What happened?  |cffa89880optional, one or two lines|r")
  counter = W.text(f, "body", 11, W.MUTED)
  counter:SetPoint("TOPRIGHT", -22, -56)
  local box
  box, whatInput = W.input(f, 30)
  box:SetPoint("TOPLEFT", 18, -74); box:SetPoint("RIGHT", f, "RIGHT", -18, 0)
  -- The limit is shown next to the box, so nothing is cut off without the player seeing it.
  whatInput:SetMaxLetters(ns.report.MAX_WHAT)
  whatInput:SetScript("OnTextChanged", function() refresh() end)
  whatInput:SetScript("OnEnterPressed", function(self) self:ClearFocus(); reportEdit:SetFocus() end)

  local s2 = W.text(f, "body", 13, W.GOLD)
  s2:SetPoint("TOPLEFT", 20, -118)
  s2:SetText("2. Copy the report  |cffa89880Ctrl+A, then Ctrl+C (Cmd on Mac)|r")
  local paper = W.parchment(f)
  paper:SetPoint("TOPLEFT", 18, -138); paper:SetPoint("RIGHT", f, "RIGHT", -18, 0); paper:SetHeight(140)
  local scroll
  scroll, reportEdit = W.multiline(paper)
  scroll:SetPoint("TOPLEFT", 6, -6); scroll:SetPoint("BOTTOMRIGHT", -26, 6)
  reportEdit:SetTextColor(W.INK[1], W.INK[2], W.INK[3])
  reportEdit:SetScript("OnTextChanged", function(self, user)
    if user then self:SetText(reportText); self:HighlightText() end
  end)
  reportEdit:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

  local s3 = W.text(f, "body", 13, W.GOLD)
  s3:SetPoint("TOPLEFT", 20, -298)
  s3:SetText("3. Paste it at:")
  placeBox = W.readonly(f, 26)
  placeBox:SetPoint("LEFT", s3, "RIGHT", 10, 0); placeBox:SetPoint("RIGHT", f, "RIGHT", -18, 0)
  placeNote = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  placeNote:SetPoint("TOPLEFT", 20, -330); placeNote:SetPoint("RIGHT", -18, 0)
  placeNote:SetJustifyH("LEFT")
  local close = W.button(f, "Close", 80, function() f:Hide() end)
  close:SetPoint("BOTTOMRIGHT", -18, 16)
end

function P.open()
  if not f then build() end
  f:Show()
  f:Raise()
  refresh()
end

function P.text() return reportText end
function P.place() return placeBox and placeBox.value end
function P.setWhat(t) if whatInput then whatInput:SetText(t); refresh() end end

return P
