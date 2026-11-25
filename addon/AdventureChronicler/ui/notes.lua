-- Adventure Chronicler: notes editor. Multi-line, scrollable and resizable, with a live character
-- count. Text over the limit is never cut off: Save is disabled until the note is short enough.
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local N = {}
ns.ui.notes = N

local f, edit, counter, saveBtn
N.sessionId, N.noteId, N.original = nil, nil, ""

local function limit() return ns.limits.max_note_chars end

local function dirty() return edit and edit:GetText() ~= N.original end

function N.updateCounter()
  local n = ns.util.utf8len(ns.util.cleanText(edit:GetText()))
  local over = n > limit()
  counter:SetText(string.format("%s%d / %d|r", over and "|cffff4040" or "|cffcccccc", n, limit()))
  if over or n == 0 then saveBtn:Disable() else saveBtn:Enable() end
end

local function build()
  local W = ns.ui.widgets
  f = W.window("AdventureChroniclerNotes", "Adventure Chronicler: note", 460, 300, { compass = true })
  f:SetResizable(true)
  if f.SetResizeBounds then f:SetResizeBounds(320, 200, 900, 700) end
  local scroll
  scroll, edit = W.multiline(f)
  scroll:SetPoint("TOPLEFT", 16, -42)
  scroll:SetPoint("BOTTOMRIGHT", -34, 50)
  edit:SetScript("OnTextChanged", function() N.updateCounter() end)
  counter = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  counter:SetPoint("BOTTOMLEFT", 18, 22)
  saveBtn = W.button(f, "Save", 80, function() N.save() end, "gold")
  saveBtn:SetPoint("BOTTOMRIGHT", -24, 16)
  local cancel = W.button(f, "Cancel", 80, function() N.close() end)
  cancel:SetPoint("RIGHT", saveBtn, "LEFT", -6, 0)
  local grip = CreateFrame("Button", nil, f)
  grip:SetSize(16, 16)
  grip:SetPoint("BOTTOMRIGHT", -6, 6)
  grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
  grip:SetScript("OnMouseDown", function() f:StartSizing("BOTTOMRIGHT") end)
  grip:SetScript("OnMouseUp", function() f:StopMovingOrSizing() end)
  -- Closing with Escape or the X keeps unsaved text in a confirmation rather than losing it.
  f:SetScript("OnHide", function()
    if dirty() and not N.closing then
      StaticPopup_Show("ADVENTURECHRONICLER_UNSAVED_NOTE")
    end
    N.closing = nil
  end)
end

-- Open the editor for a new note (noteId nil) or an existing one.
function N.open(sessionId, noteId)
  if not f then build() end
  if f:IsShown() and dirty() then
    ns.App.print("Finish or cancel the note you're writing first.")
    edit:SetFocus()
    return
  end
  N.sessionId, N.noteId = sessionId, noteId
  local s = ns.App.db.sessions[sessionId]
  local text = ""
  if s and noteId then
    for _, n in ipairs(s.notes) do if n.id == noteId then text = n.text end end
  end
  N.original = text
  edit:SetText(text)
  N.updateCounter()
  f:Show()
  edit:SetFocus()
end

function N.reopen() if f then N.closing = true; f:Show(); edit:SetFocus() end end

function N.close(discard)
  if discard then N.original = edit:GetText() end
  if dirty() then f:Hide() return end -- OnHide will ask
  N.closing = true
  f:Hide()
end

function N.save()
  local App, S = ns.App, ns.Session
  local s = App.db.sessions[N.sessionId]
  if not s then App.print("That session no longer exists. Your text is still in the editor.") return end
  local ok, why, len, lim
  if N.noteId then ok, why, len, lim = S.editNote(s, App.now(), N.noteId, edit:GetText())
  else ok, why, len, lim = S.addNote(s, App.now(), edit:GetText(), "note") end
  if not ok then
    if why == "too_long" then App.print(string.format("The note is %d characters; the limit is %d.", len, lim))
    elseif why == "too_many" then App.print("This session has the most notes it can hold.")
    else App.print("Nothing to save.") end
    return
  end
  N.original = edit:GetText()
  N.closing = true
  f:Hide()
  App.print("Note saved.")
  App.refresh()
end

function N.discard() if edit then N.original = edit:GetText() end end

return N
