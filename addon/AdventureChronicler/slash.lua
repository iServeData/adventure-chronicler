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
  "/ac export  copy the latest session (import code, Markdown, text or JSON)",
  "/ac settings  open the settings window (Community, Export, Options, Help)",
  "/ac link <https://...>  set where the import code goes (/ac link clear goes back)",
  "/ac community <https://...>  set your community invite (/ac community clear goes back)",
  "/ac report  copy a short problem report (version and settings, no log or names)",
  "/ac whatsnew  what changed in each version",
  "/ac set <setting> on|off  change a setting in chat",
  "/ac set lootquality all|common|uncommon|rare|epic  lowest loot quality recorded",
  "/ac set minimap off|on  hide or show the compass button on the minimap",
  "/ac set buttons off|on  hide or show the small buttons on the mini recorder",
  "/ac version",
}

local SETTABLE = {
  prompt = "prompt_on_instance", pvp = "record_pvp", loot = "record_personal_loot",
  identity = "include_identity", classlevel = "include_class_level", buttons = "indicator_buttons",
  questtext = "record_quest_text", minimap = "minimap_button",
  lootquest = "loot_skip_quest", loottrade = "loot_skip_trade", lootjunk = "loot_skip_junk",
  whatsnew = "whats_new_on_update",
}
local QUALITY = { all = 0, poor = 0, common = 1, uncommon = 2, rare = 3, epic = 4 }

-- on/off for every setting; show/hide too (they read better for the minimap button).
local VALUES = { on = true, off = false, show = true, hide = false }


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
  elseif cmd == "link" then App.setLink(rest)
  elseif cmd == "options" or cmd == "settings" or cmd == "config" then App.settingsWindow("Options")
  elseif cmd == "community" then App.setInvite(rest)
  elseif cmd == "report" then App.reportProblem()
  elseif cmd == "whatsnew" or cmd == "news" or cmd == "changelog" then App.whatsNew()
  elseif cmd == "set" then
    local name, val = rest:match("^(%S+)%s+(%S+)$")
    name, val = name and name:lower(), val and val:lower()
    if name == "indicator" then
      App.print("That setting is gone since 0.3.3. Close the mini recorder with its x; the compass on the "
        .. "minimap brings it back.")
      return
    end
    if name == "lootquality" then
      if QUALITY[val] == nil then App.print("Usage: /ac set lootquality all|common|uncommon|rare|epic") return end
      App.settings.loot_min_quality = QUALITY[val]
      App.print("Loot recorded: " .. ns.options.qualityChoiceLabel(QUALITY[val], true) .. ".")
      App.refresh()
      return
    end
    local key = name and SETTABLE[name]
    if not key or VALUES[val] == nil then App.print("Usage: /ac set <" ..
      "prompt|pvp|loot|identity|classlevel|buttons|questtext|minimap|lootquest|loottrade|lootjunk|whatsnew> on|off")
      return
    end
    App.settings[key] = VALUES[val]
    App.print(name .. " is now " .. (VALUES[val] and "on" or "off") .. ".")
    App.refresh()
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
