-- Adventure Chronicler: the mini recorder. A small window with REC / PAUSED, the time, a close
-- button (x) and a row of small buttons: Open, Note, Bookmark, Pause or Resume, Stop, Export and
-- Review (/ac set buttons off hides the row). When it shows (0.3.3):
--   - a session is recording or paused, and
--   - the Recorder window is closed (closing that window while recording brings it up), and
--   - you haven't closed it with x. The compass on the minimap brings it back; so does logging in or
--     reloading while a session is open, so it is always clear when the addon is collecting.
-- If the minimap button is turned off, closing it says once in chat how to get back (/ac).
local _, ns = ...
ns = ns or {}
ns.ui = ns.ui or {}

local I = {}
ns.ui.indicator = I

local frame, label, row, elapsed = nil, nil, nil, 0
local buttons = {}

local SIZE, GAP, PAD = 22, 3, 4
I.RED, I.YELLOW = { 1, 0.25, 0.25 }, { 1, 0.82, 0 }

local function stopAsk()
  local s = ns.Session.active(ns.App.db)
  if s then StaticPopup_Show("ADVENTURECHRONICLER_STOP", s.title ~= "" and s.title or "this session") end
end

local function pauseOrResume()
  local s = ns.Session.active(ns.App.db)
  if s and s.state == "paused" then ns.App.resume() else ns.App.pause() end
end

-- Closed with x, until the compass brings it back, a session starts or stops, the Recorder
-- window is closed, or the game is reloaded. Not saved: after a login or reload it shows again.
I.closed = false
local warnedFor

function I.close()
  I.closed = true
  I.update()
  local App = ns.App
  local s = ns.Session.active(App.db)
  if s and App.settings.minimap_button == false and warnedFor ~= s.id then
    warnedFor = s.id
    App.print(s.state == "recording" and "Still recording, /ac to open." or "A session is still paused, /ac to open.")
  end
end

function I.reopen()
  I.closed = false
  I.update()
end

-- key, icon, tooltip, action, tint
local ROW = {
  { "open", "compass", "Open Adventure Chronicler", function() ns.App.recorder() end },
  { "note", "icon_add_note", "Add note", function() ns.App.note("") end },
  { "mark", "icon_bookmark", "Bookmark this moment", function() ns.App.mark("") end },
  { "pause", "icon_pause", "Pause", pauseOrResume },
  { "stop", "icon_stop", "Stop (asks first)", stopAsk, { 1, 0.45, 0.4 } },
  { "export", "icon_export", "Export", function() ns.App.export() end },
  { "review", "icon_review", "Review", function() ns.App.review() end },
}
I.ROW = ROW

local function smallButton(parent, spec, size)
  local W = ns.ui.widgets
  size = size or SIZE
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(size, size)
  local bg = b:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(W.media("button_dark"))
  b:SetHighlightTexture(W.media("button_glow"), "ADD")
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(size - 6, size - 6)
  b.icon:SetPoint("CENTER")
  b.icon:SetTexture(W.media(spec[2]))
  if spec[5] then b.icon:SetVertexColor(spec[5][1], spec[5][2], spec[5][3]) end
  b.tip = spec[3]
  b:SetScript("OnClick", spec[4])
  b:SetScript("OnMouseDown", function(self) self.icon:SetPoint("CENTER", 1, -1) end)
  b:SetScript("OnMouseUp", function(self) self.icon:SetPoint("CENTER", 0, 0) end)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(self.tip)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", function() GameTooltip:Hide() end)
  return b
end

local function border(f)
  local G = ns.ui.widgets.GOLD
  for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
    local t = f:CreateTexture(nil, "BORDER")
    t:SetColorTexture(G[1], G[2], G[3], 0.9)
    if side == "TOP" or side == "BOTTOM" then
      t:SetHeight(1); t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT")
    else
      t:SetWidth(1); t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side)
    end
  end
end

local function movable(f)
  f:SetMovable(true)
  f:SetClampedToScreen(true)
  f:RegisterForDrag("LeftButton")
  f:RegisterForClicks("LeftButtonUp")
  f:SetScript("OnDragStart", f.StartMoving)
  f:SetScript("OnDragStop", f.StopMovingOrSizing)
end

local function ticker(f)
  f:SetScript("OnUpdate", function(_, dt)
    elapsed = elapsed + dt
    if elapsed >= 1 then elapsed = 0; I.update() end
  end)
end

local function build()
  local W = ns.ui.widgets
  frame = CreateFrame("Button", "AdventureChroniclerIndicator", UIParent)
  frame:SetSize(#ROW * (SIZE + GAP) - GAP + PAD * 2, 26)
  frame:SetPoint("TOP", 0, -120)
  local bg = frame:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints()
  bg:SetTexture(W.media("frame_bg"))
  border(frame)
  movable(frame)
  frame:SetScript("OnClick", function() ns.App.recorder() end)
  frame:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine("Adventure Chronicler")
    GameTooltip:AddLine("Click to open the Recorder. Drag to move.", 1, 1, 1)
    GameTooltip:AddLine("x closes it; the compass on the minimap brings it back.", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("The small buttons: open, note, bookmark, pause, stop, export, review.", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("/ac set buttons off hides them.", 0.8, 0.8, 0.8)
    GameTooltip:Show()
  end)
  frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
  label = W.text(frame, "body", 12, W.CREAM)
  label:SetPoint("TOP", 0, -7)

  local close = smallButton(frame, { "close", "icon_close", "Close (the compass on the minimap brings it back)",
    function() I.close() end }, 16)
  close:SetPoint("TOPRIGHT", -4, -5)
  buttons.close = close

  row = CreateFrame("Frame", nil, frame)
  row:SetPoint("BOTTOMLEFT", PAD, PAD)
  row:SetPoint("BOTTOMRIGHT", -PAD, PAD)
  row:SetHeight(SIZE)
  for i, spec in ipairs(ROW) do
    local b = smallButton(row, spec)
    b:SetPoint("LEFT", (i - 1) * (SIZE + GAP), 0)
    buttons[spec[1]] = b
  end
  ticker(frame)
end

function I.frames() return frame, buttons end

-- Whether the mini recorder should be on screen. recorderShown: the Recorder window is open.
function I.visible(s, recorderShown, closed)
  return s ~= nil and not recorderShown and not closed
end

local function recorderShown()
  local R = ns.ui.recorder
  return R and R.isShown and R.isShown() or false
end

function I.update()
  local App = ns.App
  if not App.loaded then return end
  local s = ns.Session.active(App.db)
  if ns.ui.minimap then ns.ui.minimap.update() end
  if not I.visible(s, recorderShown(), I.closed) then
    if frame then frame:Hide() end
    return
  end
  local t = ns.util.formatDuration(ns.Session.recordedSeconds(s, App.now()))
  local paused = s.state ~= "recording"
  if not frame then build() end
  if paused then label:SetText("|cffffd100PAUSED|r  " .. t) else label:SetText("|cffff4040REC|r  " .. t) end
  local W = ns.ui.widgets
  buttons.pause.icon:SetTexture(W.media(paused and "icon_resume" or "icon_pause"))
  buttons.pause.tip = paused and "Resume" or "Pause"
  if App.settings.indicator_buttons ~= false then
    row:Show(); frame:SetHeight(26 + SIZE + PAD)
  else
    row:Hide(); frame:SetHeight(26)
  end
  frame:Show()
end

return I
