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

function D.observation(o)
  local f = WORDS[o.type]
  local text = f and f(o.data or {}) or o.type
  text = text .. (CERTAINTY_LABEL[o.certainty] or "")
  if (o.repeats or 0) > 0 then text = text .. string.format(" [+%d repeats]", o.repeats) end
  return text
end

return D
