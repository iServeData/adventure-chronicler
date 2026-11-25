-- Adventure Chronicler: plain-language wording for timeline rows. Pure; shared by the review window
-- and tests. Wording never claims more than the observation's certainty supports.
local _, ns = ...
ns = ns or {}

local D = {}
ns.describe = D

local CERTAINTY_LABEL = { confirmed = "", seen = " (seen)", inferred = " (probably)", uncertain = " (uncertain)" }

local function q(d) return d.title or ("quest " .. tostring(d.quest_id or "?")) end
local function inst(d) return (d.instance and d.instance.name) or d.name or "an instance" end

local WORDS = {
  ["zone.enter"] = function(d) return "Arrived in " .. (d.zone or d.map or "an unknown place") end,
  ["instance.enter"] = function(d) return "Entered " .. inst(d) end,
  ["instance.leave"] = function(d) return "Left " .. inst(d) end,
  ["encounter.start"] = function(d) return "Encounter began: " .. (d.name or "unknown") end,
  ["encounter.end"] = function(d)
    local r = { success = "defeated", wipe_or_reset = "not defeated (wipe or reset)" }
    return "Encounter ended: " .. (d.name or "unknown") .. ", " .. (r[d.result] or "result unknown")
  end,
  ["quest.rewards_offered"] = function(d)
    local n = d.choices and #d.choices or 0
    return "Reward window opened for " .. q(d) .. (n > 0 and (" (" .. n .. " choices shown)") or "")
  end,
  ["quest.reward_selected"] = function(d) return "Chose a reward: " .. (d.name or "unknown item") end,
  ["quest.turned_in"] = function(d) return "Turned in " .. q(d) end,
  ["item.received"] = function(d)
    local count = (d.count_delta or 1) > 1 and (" x" .. d.count_delta) or ""
    return "Received " .. (d.name or ("item " .. tostring(d.item_id))) .. count
  end,
  ["loot.seen"] = function(d) return "Loot window showed " .. (d.items and #d.items or 0) .. " item(s)" end,
  ["pvp.battleground_enter"] = function(d) return "Entered battleground " .. (d.name or "") end,
  ["pvp.battleground_leave"] = function(d) return "Left battleground " .. (d.name or "") end,
  ["pvp.battleground_result"] = function(d)
    local r = { won = "won", lost = "lost" }
    return "Battleground " .. (d.name or "") .. " ended: " .. (r[d.outcome] or "result unknown")
  end,
  ["player.death"] = function() return "You died" end,
  ["marker.bookmark"] = function() return "Bookmark" end,
  ["marker.screenshot"] = function(d)
    local p = d.preset == "clean_scene" and "clean scene" or "as seen"
    return "Screenshot (" .. p .. ")" .. (d.status == "succeeded" and "" or (", " .. tostring(d.status)))
  end,
}

-- compact leaves out the repeat count; the recorder window is narrow, and the review window shows it.
function D.observation(o, compact)
  local f = WORDS[o.type]
  local text = f and f(o.data or {}) or o.type
  text = text .. (CERTAINTY_LABEL[o.certainty] or "")
  local n = o.repeats or 0
  if n > 0 and not compact then
    text = text .. string.format(" [+%d %s]", n, n == 1 and "repeat" or "repeats")
  end
  return text
end

-- Icons for the recorder window: the addon's own gold line icons in media/.
local MEDIA = "Interface\\AddOns\\AdventureChronicler\\media\\icon_"
local ICON = {}
for _, k in ipairs({ "zone", "instance", "encounter", "quest", "item", "pvp", "death", "screenshot",
                     "bookmark", "note", "other" }) do ICON[k] = MEDIA .. k end
D.ICON = ICON

local FAMILY = {
  ["zone.enter"] = "zone", ["instance.enter"] = "instance", ["instance.leave"] = "instance",
  ["encounter.start"] = "encounter", ["encounter.end"] = "encounter",
  ["quest.rewards_offered"] = "quest", ["quest.reward_selected"] = "quest", ["quest.turned_in"] = "quest",
  ["item.received"] = "item", ["loot.seen"] = "item",
  ["pvp.battleground_enter"] = "pvp", ["pvp.battleground_leave"] = "pvp", ["pvp.battleground_result"] = "pvp",
  ["player.death"] = "death", ["marker.screenshot"] = "screenshot",
}

function D.iconFor(obsType) return ICON[FAMILY[obsType] or "other"] end

-- The newest entries of a session, oldest first, for the recorder window. Notes and bookmarks are
-- included; the bookmark marker is skipped because its note row already shows it.
function D.recent(s, n)
  local all = {}
  for _, o in ipairs(s.observations or {}) do
    if o.type ~= "marker.bookmark" then
      all[#all + 1] = { t = o.t, seq = o.seq or 0, icon = D.iconFor(o.type), text = D.observation(o, true) }
    end
  end
  for _, note in ipairs(s.notes or {}) do
    local bookmark = note.kind == "bookmark"
    local preview = (note.text or ""):gsub("\n", " ")
    all[#all + 1] = { t = note.t, seq = 0, icon = bookmark and ICON.bookmark or ICON.note,
                      text = (bookmark and "Bookmark" or "Note") .. (preview ~= "" and (": " .. preview) or "") }
  end
  table.sort(all, function(a, b) if a.t ~= b.t then return a.t < b.t end return a.seq < b.seq end)
  local out = {}
  for i = math.max(1, #all - n + 1), #all do out[#out + 1] = all[i] end
  return out
end

-- What the status line says. Recording is always shown plainly so the player knows it is on.
function D.status(s)
  if not s then return "gray", "Not recording" end
  if s.state == "recording" then return "green", "Recording locally" end
  if s.state == "paused" then return "yellow", "Paused" .. (s.interrupted and " (interrupted)" or "") end
  return "gray", "Stopped"
end

return D
