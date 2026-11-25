-- Adventure Chronicler: slash commands. /ac is used unless another addon already owns it,
-- in which case /advchron works instead (/advchron always works).
local _, ns = ...
ns = ns or {}

local HELP = {
  "/ac  open or close the recorder window",
  "/ac start [name]  start recording a session",
  "/ac pause | resume  pause or continue recording",
  "/ac note [text]  add a note (no text opens the editor)",
  "/ac mark [label]  add a bookmark",
  "/ac title <name>  rename the session that is open",
  "/ac shot [clean]  take a screenshot (as seen, or clean scene out of combat)",
  "/ac stop  end the session",
  "/ac review  open the review window",
  "/ac export  copy the latest session",
  "/ac options  show settings;  /ac set <setting> on|off",
  "/ac version",
}

local SETTABLE = {
  prompt = "prompt_on_instance", pvp = "record_pvp", loot = "record_personal_loot",
  identity = "include_identity", classlevel = "include_class_level",
}

local function options(App)
  for short, key in pairs(SETTABLE) do
    App.print(string.format("%s: %s", short, App.settings[key] and "on" or "off"))
  end
end

function ns.handleSlash(msg)
  local App = ns.App
  if not App.loaded then return end
  msg = msg or ""
  local cmd, rest = msg:match("^%s*(%S*)%s*(.-)%s*$")
  cmd = (cmd or ""):lower()
  if cmd == "start" then App.start(rest)
  elseif cmd == "pause" then App.pause()
  elseif cmd == "resume" then App.resume()
  elseif cmd == "note" then App.note(rest)
  elseif cmd == "mark" then App.mark(rest)
  elseif cmd == "title" then App.rename(rest)
  elseif cmd == "shot" then App.shot((rest == "clean" or rest == "clean_scene") and "clean_scene" or "as_seen")
  elseif cmd == "stop" then App.stop()
  elseif cmd == "" then App.recorder()
  elseif cmd == "review" then App.review()
  elseif cmd == "export" then App.export()
  elseif cmd == "options" then options(App)
  elseif cmd == "set" then
    local name, val = rest:match("^(%S+)%s+(%S+)$")
    local key = name and SETTABLE[name:lower()]
    if not key or (val ~= "on" and val ~= "off") then App.print("Usage: /ac set <" ..
      "prompt|pvp|loot|identity|classlevel> on|off") return end
    App.settings[key] = (val == "on")
    App.print(name .. " is now " .. val .. ".")
  elseif cmd == "version" then App.print("version " .. App.VERSION)
  elseif cmd == "help" then for _, line in ipairs(HELP) do App.print(line) end
  else for _, line in ipairs(HELP) do App.print(line) end end
end

SLASH_ADVENTURECHRONICLER1 = "/advchron" -- luacheck: ignore
-- Only claim /ac if nothing else has registered it.
local taken = false
for k, v in pairs(_G) do
  if type(k) == "string" and k:match("^SLASH_") and type(v) == "string" and v:lower() == "/ac" then taken = true end
end
if not taken then SLASH_ADVENTURECHRONICLER2 = "/ac" end -- luacheck: ignore
SlashCmdList["ADVENTURECHRONICLER"] = function(msg) ns.handleSlash(msg) end
