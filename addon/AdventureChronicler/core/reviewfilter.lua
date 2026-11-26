-- Adventure Chronicler: the review window's Filter. Pure, so it can be tested. It only decides which rows
-- are shown; nothing is deleted and exports always contain everything.
local _, ns = ...
ns = ns or {}

local F = {}
ns.reviewfilter = F

-- Entry types, A-Z, and which observation types belong to each.
F.TYPES = { "Deaths", "Encounters", "Instances", "Loot", "Notes", "Other", "PvP", "Quests", "Screenshots",
            "Zones" }
local PREFIX = { zone = "Zones", instance = "Instances", encounter = "Encounters", quest = "Quests",
                 item = "Loot", loot = "Loot", pvp = "PvP" }

function F.category(entry)
  if entry.note then return "Notes" end
  local t = entry.obs and entry.obs.type or ""
  if t == "player.death" then return "Deaths" end
  if t == "marker.screenshot" then return "Screenshots" end
  return PREFIX[t:match("^([^.]+)")] or "Other"
end

-- Loot quality buckets: 0-5 as the game numbers them, plus "unknown" for items the game hasn't loaded.
F.QUALITIES = { 0, 1, 2, 3, 4, 5, "unknown" }

function F.new() return { types = {}, qualities = {}, hide_seen_received = false } end

-- How many filters are on (the number on the Filter button).
function F.count(state)
  local n = state.hide_seen_received and 1 or 0
  for _, v in pairs(state.types) do if v then n = n + 1 end end
  for _, v in pairs(state.qualities) do if v then n = n + 1 end end
  return n
end

function F.clear(state) state.types, state.qualities, state.hide_seen_received = {}, {}, false end

-- The items a row is about: loot.seen lists several, item.received one. Other rows have none.
local function itemsOf(obs)
  if not obs then return nil end
  local d = obs.data or {}
  if obs.type == "loot.seen" then return d.items or {} end
  if obs.type == "item.received" and d.item_id then return { { item_id = d.item_id } } end
  return nil
end

-- qualityOf(itemID) returns 0-5, or nil when the game doesn't know the item yet ("unknown").
-- Returns the rows to show and how many there were in all.
function F.apply(entries, state, qualityOf)
  local received = {}
  if state.hide_seen_received then
    for _, e in ipairs(entries) do
      if e.obs and e.obs.type == "item.received" and e.obs.data then received[e.obs.data.item_id or -1] = true end
    end
  end
  local anyQuality = next(state.qualities) ~= nil
  local out = {}
  for _, e in ipairs(entries) do
    local show = not state.types[F.category(e)]
    local items = show and itemsOf(e.obs)
    if items then
      if anyQuality then
        local visible = false
        for _, it in ipairs(items) do
          local q = qualityOf and qualityOf(it.item_id)
          local key = type(q) == "number" and math.max(0, math.min(5, q)) or "unknown"
          if not state.qualities[key] then visible = true break end
        end
        show = visible
      end
      if show and state.hide_seen_received and e.obs.type == "loot.seen" and #items > 0 then
        local all = true
        for _, it in ipairs(items) do if not received[it.item_id] then all = false break end end
        if all then show = false end
      end
    end
    if show then out[#out + 1] = e end
  end
  return out, #entries
end

return F
