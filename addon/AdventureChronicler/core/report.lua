-- Adventure Chronicler: the text for Report a problem. Pure, so it can be tested. It only lists the
-- add-on's version, the game version, which settings are on and the last error the add-on caught, plus
-- what the player typed. No log, no import code, no character or player names.
local _, ns = ...
ns = ns or {}

local P = {}
ns.report = P

P.MAX_WHAT = 200     -- characters the player can type in "What happened?"
P.MAX_ERROR = 200    -- characters of the error kept; longer ones are shortened and say so

-- The short names used in the report, as in /ac set.
P.SHORT = {
  { "loot", "record_personal_loot" }, { "questtext", "record_quest_text" }, { "pvp", "record_pvp" },
  { "prompt", "prompt_on_instance" }, { "identity", "include_identity" }, { "classlevel", "include_class_level" },
  { "minimap", "minimap_button" }, { "buttons", "indicator_buttons" }, { "lootquest", "loot_skip_quest" },
  { "loottrade", "loot_skip_trade" }, { "lootjunk", "loot_skip_junk" }, { "whatsnew", "whats_new_on_update" },
}

-- Removes WoW colour and link codes and other markup from an error message, then shortens it.
function P.cleanError(msg)
  if msg == nil then return nil end
  local s = tostring(msg)
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1"):gsub("|", "/")
  s = s:gsub("[%c]+", " ")
  if #s > P.MAX_ERROR then s = s:sub(1, P.MAX_ERROR) .. "... (shortened)" end
  return s
end

local function hours(secs)
  secs = tonumber(secs) or 0
  if secs < 60 then return "under a minute" end
  if secs < 3600 then return math.floor(secs / 60) .. " min" end
  return (string.format("%.1f h", secs / 3600):gsub("%.0 h", " h"))
end

-- info = { version, client = { version, build, interface }, session = nil | { state, recorded },
--          mini_shown, settings, last_error = nil | { where, message }, what }
function P.build(info)
  local c = info.client or {}
  local lines = {}
  lines[1] = string.format("Adventure Chronicler %s · WoW %s (%s) · interface %s", tostring(info.version),
    tostring(c.version or "?"), tostring(c.build or "?"), tostring(c.interface or "?"))
  local st = info.session
  local rec = st and string.format("%s (%s)", st.state, hours(st.recorded)) or "no session open"
  lines[2] = string.format("Recording: %s · mini recorder: %s · minimap button: %s", rec,
    info.mini_shown and "showing" or "closed", (info.settings or {}).minimap_button and "on" or "off")
  local on, off = {}, {}
  for _, pair in ipairs(P.SHORT) do
    local v = (info.settings or {})[pair[2]]
    if v == true then on[#on + 1] = pair[1] elseif v == false then off[#off + 1] = pair[1] end
  end
  local q = tonumber((info.settings or {}).loot_min_quality) or 0
  lines[3] = "Settings on: " .. (#on > 0 and table.concat(on, ", ") or "none") .. " · off: "
    .. (#off > 0 and table.concat(off, ", ") or "none") .. " · loot quality: "
    .. (ns.options and ns.options.qualityChoiceLabel(q, true) or tostring(q))
  local e = info.last_error
  lines[4] = "Last error the add-on caught: "
    .. (e and (tostring(e.where or "?") .. ": " .. (P.cleanError(e.message) or "?")) or "none")
  local what = (info.what or ""):gsub("[%c]+", " "):match("^%s*(.-)%s*$")
  lines[5] = "What happened: " .. (what ~= "" and what or "(not filled in)")
  return table.concat(lines, "\n")
end

return P
