-- Adventure Chronicler: controller. Connects saved data, the session logic, capture modules and the UI.
local ADDON, ns = ...
ns = ns or {}
local S = ns.Session
local L = ns.limits

local App = { loaded = false, warnedFull = false }
ns.App = App

App.VERSION = "0.3.0"
App.DEFAULT_SETTINGS = {
  prompt_on_instance = false,   -- ask (never auto-start) when entering a dungeon or raid
  record_pvp = true,            -- battleground entry/exit/result and own deaths
  record_personal_loot = false, -- opt-in
  record_quest_text = false,    -- opt-in: the quest giver's full text (objectives are always kept)
  include_identity = false,     -- opt-in: character name and realm in exports
  include_class_level = true,   -- class and level in exports (not identifying on their own)
  show_indicator = true,        -- the recording indicator is always shown while recording or paused
  indicator_buttons = true,     -- small Note, Bookmark, Pause, Stop, Export, Review buttons on the indicator
  questersboard_url = "",       -- your own QuestersBoard address, set with /ac link ("" = App.DEFAULT_LINK)
}

-- Where the export window's Open QuestersBoard button points until you set your own with /ac link.
-- A placeholder: no real community address is shipped in the add-on.
App.DEFAULT_LINK = "https://example.com/import"

-- Accepts only a plain https:// address (no spaces, quotes or WoW escape codes), up to 200 characters.
function App.validLink(url)
  if type(url) ~= "string" then return nil end
  url = url:match("^%s*(.-)%s*$")
  if #url > 200 or #url < 12 then return nil end
  if not url:lower():match("^https://[%w%-%.]+%.[%a][%w%-]*") then return nil end
  if url:find("[%s%c\"'<>|\\`]") then return nil end
  return url
end

-- The address the button shows: yours if set and valid, otherwise the default.
function App.link()
  return App.validLink(App.settings and App.settings.questersboard_url) or App.validLink(App.DEFAULT_LINK)
end

function App.setLink(url)
  if url == nil or url == "" then
    local own = App.validLink(App.settings.questersboard_url)
    App.print("QuestersBoard address: " .. (App.link() or "none") .. (own and "" or " (the default)"))
    return
  end
  if url == "clear" or url == "off" or url == "default" then
    App.settings.questersboard_url = ""
    App.print("QuestersBoard address is back to the default: " .. (App.link() or "none"))
    return
  end
  local ok = App.validLink(url)
  if not ok then
    App.print("That doesn't look like an https:// address. Example: /ac link https://example.com/import")
    return
  end
  App.settings.questersboard_url = ok
  App.print("QuestersBoard address set to " .. ok)
end

local api = _G
App.api = api

function App.now() return api.time() end

function App.print(msg)
  if api.DEFAULT_CHAT_FRAME then api.DEFAULT_CHAT_FRAME:AddMessage("|cffd9a441Adventure Chronicler:|r " .. msg) end
end

local function clientInfo()
  local version, build, _, interface = api.GetBuildInfo()
  return { flavor = "forever", version = version, build = build, interface = interface,
           locale = api.GetLocale and api.GetLocale() or nil }
end

local function characterInfo()
  local _, classFile = api.UnitClass("player")
  return { name = api.UnitName("player"), realm = api.GetRealmName and api.GetRealmName() or nil,
           class = classFile, level = api.UnitLevel("player") }
end

-- Called once SavedVariables are available.
function App.load()
  api.AdventureChroniclerDB = type(api.AdventureChroniclerDB) == "table" and api.AdventureChroniclerDB or {}
  local acct = api.AdventureChroniclerDB
  acct.schema = acct.schema or 1
  acct.settings = type(acct.settings) == "table" and acct.settings or {}
  for k, v in pairs(App.DEFAULT_SETTINGS) do if acct.settings[k] == nil then acct.settings[k] = v end end
  App.settings = acct.settings
  api.AdventureChroniclerCharDB = S.migrateStore(api.AdventureChroniclerCharDB)
  App.db = api.AdventureChroniclerCharDB
  App.loaded = true
end

-- Called at PLAYER_LOGIN: record any gap since the last save and tell the player.
function App.recover()
  local s, how, gap = S.recover(App.db, App.now(), App.db.last_seen)
  if s then
    if how == "auto_paused" then
      App.print(string.format("Your session was paused because the game was closed for %s. Type /ac resume to "
        .. "continue it or /ac stop to end it.", ns.util.formatDuration(gap or 0)))
    else
      App.print("Recording continues (" .. s.state .. ").")
    end
  end
  App.refresh()
end

function App.onLogout()
  if App.db then App.db.last_seen = App.now() end
end

function App.refresh()
  if ns.ui and ns.ui.indicator then ns.ui.indicator.update() end
  if ns.ui and ns.ui.review and ns.ui.review.refresh then ns.ui.review.refresh() end
  if ns.ui and ns.ui.recorder and ns.ui.recorder.refresh then ns.ui.recorder.refresh() end
end

-- Capture modules call this. Records only while a session is recording (markers also while paused).
function App.record(obs, opts)
  if not App.loaded then return end
  local result = S.observe(App.db, App.now(), obs, opts)
  if result == "dropped" and not App.warnedFull then
    App.warnedFull = true
    App.print(string.format("This session reached %d observations. New ones are counted but not kept. "
      .. "Your notes are not affected.", L.max_observations))
  end
  return result
end

App.ctx = {
  api = api,
  now = function() return App.now() end,
  record = function(obs, opts) return App.record(obs, opts) end,
  amend = function(key, data) return S.amendLast(App.db, App.now(), key, data) end,
  settings = setmetatable({}, { __index = function(_, k) return App.settings and App.settings[k] end }),
  onInstanceEnter = function(inst) App.onInstanceEnter(inst) end,
  notify = function(msg) App.print(msg) end,
}

function App.onInstanceEnter(inst)
  if not App.settings.prompt_on_instance or S.active(App.db) then return end
  if inst and (inst.type == "party" or inst.type == "raid") and api.StaticPopup_Show then
    api.StaticPopup_Show("ADVENTURECHRONICLER_START_PROMPT", inst.name or "this instance")
  end
end

-- ------------------------------------------------------------- commands

local messages = {
  active = "A session is already open. Use /ac stop first.",
  no_session = "No session is open. Use /ac start.",
  not_recording = "The session isn't recording.",
  not_paused = "The session isn't paused.",
  title_too_long = "That session name is too long (" .. L.max_title_chars .. " characters at most).",
  full_no_stopped = "You have " .. L.max_sessions .. " sessions and none is stopped. Stop or delete one first.",
}

function App.start(title)
  local info = { client = clientInfo(), character = characterInfo(), title = title }
  local s, why, oldest = S.start(App.db, App.now(), info)
  if not s and why == "full" then
    local old = App.db.sessions[oldest]
    if api.StaticPopup_Show then
      local warn = S.hasUnexportedNotes(old) and " It has notes that were never exported." or ""
      api.StaticPopup_Show("ADVENTURECHRONICLER_REMOVE_OLDEST", warn, nil, { id = oldest, title = title })
    end
    return
  end
  if not s then App.print(messages[why] or why) return end
  App.warnedFull = false
  -- Record where the session begins.
  if ns.capture.zones then ns.capture.zones.reset(); ns.capture.zones.check(App.ctx) end
  if ns.capture.quests then pcall(ns.capture.quests.snapshot, App.ctx) end
  App.print("Recording started. /ac pause, /ac note, /ac mark, /ac stop.")
  App.refresh()
end

function App.removeOldestThenStart(id, title)
  S.deleteSession(App.db, id)
  App.start(title)
end

function App.pause()
  local s, why = S.pause(App.db, App.now(), "player")
  App.print(s and "Paused. Nothing is recorded until /ac resume." or messages[why])
  App.refresh()
end

function App.resume()
  local s, why = S.resume(App.db, App.now())
  App.print(s and "Recording resumed." or messages[why])
  App.refresh()
end

function App.stop()
  local s, why = S.stop(App.db, App.now())
  if s then
    App.print("Session stopped. /ac review to look it over, /ac export to copy it.")
  else
    App.print(messages[why])
  end
  App.refresh()
end

function App.rename(title, id)
  local s = id and App.db.sessions[id] or S.active(App.db)
  if not s then App.print(messages.no_session) return end
  local ok, why = S.rename(s, App.now(), title)
  if not ok then App.print(messages[why] or why) return end
  App.print(s.title ~= "" and ("Session renamed: " .. s.title) or "Session name cleared.")
  App.refresh()
end

function App.note(text)
  local s = S.active(App.db)
  if not s then App.print(messages.no_session) return end
  if text and text ~= "" then
    local n, why, len, limit = S.addNote(s, App.now(), text, "note")
    if n then App.print("Note saved.")
    elseif why == "too_long" then
      App.print(string.format("That note is %d characters; the limit is %d. Use /ac note on its own for the editor.",
        len, limit))
    else App.print(why == "too_many" and "This session has the most notes it can hold." or "Nothing to save.") end
  elseif ns.ui and ns.ui.notes then
    ns.ui.notes.open(s.id)
  end
  App.refresh()
end

function App.mark(label)
  local s = S.active(App.db)
  if not s then App.print(messages.no_session) return end
  local n, why = S.addNote(s, App.now(), label or "", "bookmark")
  if n then
    App.record({ type = "marker.bookmark", certainty = "confirmed", data = { note_id = n.id } },
      { allow_paused = true })
    App.print("Bookmark added.")
  else
    App.print(why == "too_long" and "That bookmark label is too long." or "Couldn't add a bookmark.")
  end
  App.refresh()
end

function App.shot(preset)
  local ok, why = ns.capture.screenshot.take(App.ctx, preset)
  if not ok then
    local msg = {
      in_combat = "Clean scene isn't available in combat. Try again when combat ends.",
      busy = "A screenshot is already being taken.",
      unknown_preset = "Use /ac shot (as seen) or /ac shot clean.",
      unavailable = "Screenshots aren't available.",
    }
    App.print(msg[why] or why)
  end
end

function App.export(id)
  local s = id and App.db.sessions[id] or S.active(App.db)
  if not s then
    local last = App.db.order[#App.db.order]
    s = last and App.db.sessions[last]
  end
  if not s then App.print("There are no sessions to export.") return end
  local text, why, size = ns.Export.toText(s, App.settings, App.VERSION)
  if not text then
    if why == "too_large" then
      App.print(string.format("This session is too large to export (%d KB; the limit is %d KB). "
        .. "Delete some observations in /ac review.", math.ceil(size / 1024), L.max_export_bytes / 1024))
    else
      App.print("Export failed. Please report this with /ac version.")
    end
    return
  end
  s.exported_at = App.now()
  if ns.ui and ns.ui.export then ns.ui.export.open(text, s) end
end

function App.review()
  if ns.ui and ns.ui.review then ns.ui.review.open() end
end

function App.recorder()
  if ns.ui and ns.ui.recorder then ns.ui.recorder.toggle() end
end

_G.AdventureChronicler_OnCompartmentClick = function() App.recorder() end -- luacheck: ignore

return App
