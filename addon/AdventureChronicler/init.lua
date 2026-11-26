-- Adventure Chronicler: event wiring. Each capture module lists the events it needs; this file
-- registers them and passes them on. Nothing here reads chat, other players or the combat log.
local ADDON, ns = ...
local App = ns.App

local modules = { ns.capture.zones, ns.capture.quests, ns.capture.encounters, ns.capture.pvp,
                  ns.capture.loot, ns.capture.screenshot }
local handlers = {}
for _, m in ipairs(modules) do
  for event, fn in pairs(m.events) do
    handlers[event] = handlers[event] or {}
    table.insert(handlers[event], fn)
  end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LOGOUT")
-- pcall: an event this client doesn't have (for example ITEM_DATA_LOAD_RESULT on an older client)
-- must not stop the others from registering.
for event in pairs(handlers) do pcall(frame.RegisterEvent, frame, event) end

frame:SetScript("OnEvent", function(_, event, ...)
  if event == "ADDON_LOADED" then
    if ... == ADDON then App.load() end
    return
  elseif event == "PLAYER_LOGIN" then
    App.recover()
    return
  elseif event == "PLAYER_LOGOUT" then
    App.onLogout()
    return
  end
  if not App.loaded then return end
  local list = handlers[event]
  if not list then return end
  for _, fn in ipairs(list) do
    -- One module failing must never break the others or the player's UI.
    local ok, err = pcall(fn, App.ctx, ...)
    if not ok then App.noteError(event, err) end
  end
  if event ~= "BAG_UPDATE_DELAYED" then App.refresh() end
end)

-- The reward choice is only known when the player clicks "Complete Quest".
hooksecurefunc("GetQuestReward", function(choiceIndex)
  if not App.loaded then return end
  local ok, err = pcall(ns.capture.quests.onGetQuestReward, App.ctx, choiceIndex)
  if not ok then App.noteError("GetQuestReward", err) end
end)

-- Keep last_seen fresh so a crash (no logout event) still leaves an honest gap estimate.
C_Timer.NewTicker(30, function() if App.loaded and ns.Session.active(App.db) then App.db.last_seen = App.now() end end)
