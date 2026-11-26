-- Adventure Chronicler: what the review window shows about one event. Pure; shared by the review window,
-- its details panel and tests. Only what was recorded is shown. Anything missing says "not recorded";
-- nothing is filled in or guessed.
local _, ns = ...
ns = ns or {}

local Dt = {}
ns.details = Dt

Dt.NOT_RECORDED = "not recorded"
Dt.GROUP_SECONDS = 1     -- enter/leave lines this close together are shown as one row
Dt.SIZE_WARN = 400 * 1024 -- the export size turns amber from here; red past the export limit

Dt.CERTAINTY = {
  confirmed = "Confirmed by the game",
  seen = "Seen on screen (not proof it was received)",
  inferred = "Worked out from other events",
  uncertain = "Uncertain",
}

local KIND = {
  ["zone.enter"] = "Zone", ["instance.enter"] = "Instance", ["instance.leave"] = "Instance",
  ["encounter.start"] = "Encounter", ["encounter.end"] = "Encounter",
  ["quest.accepted"] = "Quest", ["quest.progress"] = "Quest", ["quest.snapshot"] = "Quest log",
  ["quest.rewards_offered"] = "Quest reward", ["quest.reward_selected"] = "Quest reward",
  ["quest.turned_in"] = "Quest", ["item.received"] = "Item", ["loot.seen"] = "Loot",
  ["pvp.battleground_enter"] = "Battleground", ["pvp.battleground_leave"] = "Battleground",
  ["pvp.battleground_result"] = "Battleground", ["player.death"] = "Death",
  ["marker.screenshot"] = "Screenshot", ["marker.bookmark"] = "Bookmark",
}
function Dt.kind(obsType) return KIND[obsType] or "Other" end

-- "6.2 KB", from bytes. One decimal under 100 KB, whole numbers above.
function Dt.kb(bytes)
  local k = (tonumber(bytes) or 0) / 1024
  if k < 100 then return string.format("%.1f KB", k) end
  return string.format("%d KB", math.floor(k + 0.5))
end

-- The export size for the header line, and its level: "ok", "warn" (from SIZE_WARN) or "over" (too large).
function Dt.sizeText(bytes, max)
  if not bytes then return "export size not worked out", "ok" end
  local text = "export " .. Dt.kb(bytes) .. " of " .. Dt.kb(max)
  if bytes > max then return text .. " (too large to export)", "over" end
  if bytes >= Dt.SIZE_WARN then return text, "warn" end
  return text, "ok"
end

local function money(c)
  c = tonumber(c)
  if not c then return nil end
  local g, s, k = math.floor(c / 10000), math.floor((c % 10000) / 100), c % 100
  local parts = {}
  if g > 0 then parts[#parts + 1] = g .. " g" end
  if s > 0 then parts[#parts + 1] = s .. " s" end
  if k > 0 or #parts == 0 then parts[#parts + 1] = k .. " c" end
  return table.concat(parts, " ")
end

local function instName(d) return (d.instance and d.instance.name) or d.name end

-- ------------------------------------------------------------------ grouping (display only)

local FLICKER = { ["instance.enter"] = true, ["instance.leave"] = true }

-- Runs of instance enter/leave lines for the same instance, each within GROUP_SECONDS of the one before,
-- become one row: the last line of the run, with e.group listing every entry in it. Seen in a real 0.3.4
-- log at instance portals ("Entered / Left / Entered" in one second). The observations themselves are not
-- changed, merged or deleted; exports keep every one.
function Dt.group(entries)
  local out = {}
  local i = 1
  while i <= #entries do
    local e = entries[i]
    local name = e.obs and FLICKER[e.obs.type] and instName(e.obs.data or {})
    local j = i
    if name then
      while j < #entries do
        local nx = entries[j + 1]
        if not (nx.obs and FLICKER[nx.obs.type] and instName(nx.obs.data or {}) == name
                and (nx.t - entries[j].t) <= Dt.GROUP_SECONDS) then break end
        j = j + 1
      end
    end
    if j > i then
      local run = {}
      for k = i, j do run[#run + 1] = entries[k] end
      local last = entries[j]
      out[#out + 1] = { t = last.t, seq = last.seq, obs = last.obs, group = run }
    else
      out[#out + 1] = e
    end
    i = j + 1
  end
  return out
end

-- " [+2 enter/leave lines]" for a grouped row.
function Dt.groupSuffix(e)
  if not e.group then return "" end
  local n = #e.group - 1
  return string.format(" |cffa89880[+%d enter/leave %s]|r", n, n == 1 and "line" or "lines")
end

-- ------------------------------------------------------------------ items and quests on an event

-- Items an event names: { item_id, name, count }. Order as recorded.
function Dt.items(o)
  local d, out = o.data or {}, {}
  local function add(it)
    if type(it) == "table" and (it.item_id or it.name) then
      out[#out + 1] = { item_id = it.item_id, name = it.name, count = it.count or it.count_delta or 1 }
    end
  end
  if o.type == "loot.seen" then for _, it in ipairs(d.items or {}) do add(it) end
  elseif o.type == "quest.rewards_offered" then
    for _, it in ipairs(d.choices or {}) do add(it) end
    for _, it in ipairs(d.guaranteed or {}) do add(it) end
  elseif o.type == "item.received" or o.type == "quest.reward_selected" then
    if d.item_id or d.name then add(d) end
  end
  return out
end

function Dt.questId(o)
  local d = o.data or {}
  if type(o.type) == "string" and o.type:find("^quest%.") and o.type ~= "quest.snapshot" then
    return tonumber(d.quest_id)
  end
  return nil
end

-- What Shift-click on a timeline row links in chat: the one item or quest the event is about, or nil.
-- { item = {...} } or { quest = {...} }. Loot windows and reward choices list several items, so the row
-- itself links nothing; their items each link from the details panel.
function Dt.linkTarget(o)
  local items = Dt.items(o)
  if #items == 1 and o.type ~= "loot.seen" and o.type ~= "quest.rewards_offered" then return { item = items[1] } end
  local d = o.data or {}
  local qid = Dt.questId(o)
  if qid or (type(o.type) == "string" and o.type:find("^quest%.") and o.type ~= "quest.snapshot" and d.title) then
    return { quest = { quest_id = qid, title = d.title, level = d.level } }
  end
  return nil
end

-- The plain text Shift-click puts in chat when the game can't make a real link: "[Name]".
function Dt.plainLink(name) return "[" .. tostring(name) .. "]" end

local function itemLabel(it)
  local name = it.name or ("item " .. tostring(it.item_id or "?") .. " (name not loaded)")
  return name .. ((it.count or 1) > 1 and (" x" .. it.count) or "")
end
Dt.itemLabel = itemLabel

-- ------------------------------------------------------------------ the tooltip

-- What the hover tooltip says beyond the game's own item or quest tooltip: short lines, recorded facts.
function Dt.tooltip(o)
  local d = o.data or {}
  local lines = {}
  local function add(t) if t and t ~= "" then lines[#lines + 1] = t end end
  if o.type == "quest.accepted" then
    if d.level then add("Level " .. d.level) end
    local objs = d.objectives or {}
    if #objs == 0 then add("Objectives: " .. Dt.NOT_RECORDED) end
    for _, ob in ipairs(objs) do add("- " .. (ob.text or ("objective " .. tostring(ob.index)))
      .. (ob.finished and " (done)" or "")) end
    if d.summary then add(d.summary) end
  elseif o.type == "quest.progress" then
    add(d.text or (d.fulfilled and d.required and (d.fulfilled .. "/" .. d.required)) or nil)
    if d.finished then add("Objective done") end
  elseif o.type == "quest.turned_in" then
    if d.xp then add(d.xp .. " XP") end
    if d.money_copper then add(money(d.money_copper)) end
  elseif o.type == "loot.seen" or o.type == "quest.rewards_offered" then
    for _, it in ipairs(Dt.items(o)) do add(itemLabel(it)) end
  elseif o.type == "encounter.end" then
    if d.duration then add(d.duration .. " seconds") end
  elseif o.type == "instance.enter" or o.type == "instance.leave" then
    local i = d.instance or {}
    add(i.difficulty); if i.max_players then add(i.max_players .. " players") end
  elseif o.type == "zone.enter" then
    if d.map and d.map ~= d.zone then add(d.map) end
  end
  if (o.repeats or 0) > 0 then add("Repeated " .. o.repeats .. " more time" .. (o.repeats == 1 and "" or "s")) end
  add("|cffa89880" .. (Dt.CERTAINTY[o.certainty] or "Certainty " .. Dt.NOT_RECORDED) .. "|r")
  add("|cffa89880Click for everything recorded.|r")
  return lines
end

-- ------------------------------------------------------------------ the details panel

-- Rows for the details panel: { label = "Zone", text = "...", item = {...} }. A row with only text is a
-- line of its own (objectives, items). Labels without a recorded value say "not recorded".
function Dt.lines(o)
  local d = o.data or {}
  local out = {}
  local function row(label, value)
    out[#out + 1] = { label = label, text = value ~= nil and tostring(value) or Dt.NOT_RECORDED }
    return out[#out]
  end
  -- The "Quest" row of a quest event: hover shows the quest, Shift-click links it in chat.
  local function questRow()
    local r = row("Quest", d.title)
    if d.quest_id or d.title then r.quest = { quest_id = d.quest_id, title = d.title, level = d.level } end
  end
  local function opt(label, value) if value ~= nil and value ~= "" then row(label, value) end end
  local function itemRows(list, heading)
    if heading then out[#out + 1] = { label = heading, text = #list == 0 and Dt.NOT_RECORDED or "" } end
    for _, it in ipairs(list) do out[#out + 1] = { text = itemLabel(it), item = it } end
  end
  local t = o.type
  if t == "zone.enter" then
    row("Zone", d.zone); opt("Map", d.map); opt("Map ID", d.map_id)
  elseif t == "instance.enter" or t == "instance.leave" then
    local i = d.instance or {}
    row("Instance", i.name); opt("Kind", i.type); opt("Difficulty", i.difficulty)
    opt("Max players", i.max_players); opt("Instance ID", i.id)
  elseif t == "encounter.start" or t == "encounter.end" then
    row("Encounter", d.name)
    if t == "encounter.end" then
      local r = { success = "defeated", wipe_or_reset = "not defeated (wipe or reset)" }
      row("Result", r[d.result] or "unknown")
      opt("Duration", d.duration and (d.duration .. " seconds"))
    end
    opt("Group size", d.group_size); opt("Encounter ID", d.encounter_id)
    if d.restricted_values then row("Note", "the game withheld some values") end
  elseif t == "quest.accepted" then
    questRow(); opt("Quest ID", d.quest_id); opt("Level", d.level)
    local objs = d.objectives or {}
    out[#out + 1] = { label = "Objectives", text = #objs == 0 and Dt.NOT_RECORDED or "" }
    for _, ob in ipairs(objs) do
      out[#out + 1] = { text = (ob.text or ("objective " .. tostring(ob.index))) .. (ob.finished and " (done)" or "") }
    end
    opt("Summary", d.summary); opt("Quest text", d.description)
    if d.text_cut then row("Note", "the quest text was longer and was shortened") end
  elseif t == "quest.progress" then
    questRow(); opt("Quest ID", d.quest_id)
    row("Objective", d.text or (d.index and ("objective " .. d.index)))
    opt("Count", d.fulfilled and d.required and (d.fulfilled .. "/" .. d.required))
    row("Done", d.finished and "yes" or "no")
  elseif t == "quest.snapshot" then
    row("Quests in the log", d.listed); opt("Kept", d.kept)
    for _, qq in ipairs(d.quests or {}) do
      local name = qq.title or ("quest " .. tostring(qq.quest_id))
      out[#out + 1] = { text = name .. (qq.level and (" (" .. qq.level .. ")") or ""),
                        quest = { quest_id = qq.quest_id, title = qq.title, level = qq.level } }
    end
  elseif t == "quest.rewards_offered" then
    questRow(); opt("Quest ID", d.quest_id)
    itemRows(d.choices or {}, "Choices shown")
    if d.guaranteed and #d.guaranteed > 0 then itemRows(d.guaranteed, "Also given") end
  elseif t == "quest.reward_selected" then
    opt("Quest ID", d.quest_id); opt("Choice", d.choice_index)
    itemRows(Dt.items(o), "Item")
  elseif t == "quest.turned_in" then
    questRow(); opt("Quest ID", d.quest_id); opt("XP", d.xp); opt("Money", money(d.money_copper))
  elseif t == "item.received" then
    itemRows(Dt.items(o), "Item"); opt("From quest ID", d.quest_id)
  elseif t == "loot.seen" then
    itemRows(Dt.items(o), "Items shown")
  elseif t == "pvp.battleground_enter" or t == "pvp.battleground_leave" or t == "pvp.battleground_result" then
    row("Battleground", d.name)
    if t == "pvp.battleground_result" then row("Result", d.outcome or "unknown") end
  elseif t == "marker.screenshot" then
    row("Kind", d.preset == "clean_scene" and "clean scene" or "as seen"); opt("Result", d.status)
  else
    local keys = {}
    for k, v in pairs(d) do if type(v) ~= "table" then keys[#keys + 1] = k end end
    table.sort(keys)
    for _, k in ipairs(keys) do row(k, d[k]) end
  end
  if (o.repeats or 0) > 0 then
    row("Repeated", o.repeats .. " more time" .. (o.repeats == 1 and "" or "s") .. ", merged")
  end
  return out
end

return Dt
