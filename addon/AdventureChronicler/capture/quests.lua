-- Adventure Chronicler: quests accepted, objective progress, turn-ins and rewards.
--
-- Quest log facts (schema version 2), as the game's quest log showed them:
--   quest.accepted  (confirmed) the game reported the quest was accepted; title, objectives and the
--                               short objective summary. The quest giver's full text only with
--                               /ac set questtext on.
--   quest.progress  (confirmed) an objective's count changed (for example 3/8 -> 4/8). Changes in a
--                               row for the same objective are merged into one entry with the last count.
--   quest.snapshot  (seen)      at Start, quests already in the log, marked "already in progress".
-- Progress is what the quest log said, not proof of who did the work or that it was finished.
--
-- Turn-in facts, never merged into a guess:
--   quest.rewards_offered  (seen)      the reward panel showed these items
--   quest.reward_selected  (inferred)  the player clicked "Complete Quest" with this choice
--   quest.turned_in        (confirmed) the game reported the turn-in
--   item.received          (inferred)  bag count of a reward item went up shortly after the turn-in
-- Cancelling the panel leaves only "offered". Seeing a reward is not receiving it.
local _, ns = ...
ns = ns or {}
ns.capture = ns.capture or {}
local util = ns.util

local Q = { pending = {}, current = nil, awaitingBags = {}, baseline = nil, busy = false, wanted = {}, late = {} }
ns.capture.quests = Q

Q.RECEIPT_WINDOW = 10 -- seconds after turn-in to look for bag changes
Q.ACCEPT_RETRY = 10   -- seconds after accepting to keep looking for objectives the log hadn't filled in yet

function Q.reset()
  Q.pending, Q.current, Q.awaitingBags, Q.baseline, Q.busy, Q.wanted, Q.late = {}, nil, {}, nil, false, {}, {}
end

local function itemCount(api, itemID)
  local f = (api.C_Item and api.C_Item.GetItemCount) or api.GetItemCount
  if not f or not itemID then return nil end
  local ok, n = pcall(f, itemID)
  return ok and n or nil
end

local function readItems(api, kind, count)
  local list = {}
  for i = 1, count or 0 do
    local name, _, qty, _, _, itemID = api.GetQuestItemInfo(kind, i)
    local link = api.GetQuestItemLink and api.GetQuestItemLink(kind, i)
    itemID = itemID or util.itemIdFromLink(link)
    local entry = { index = i, item_id = itemID, name = (name ~= "" and name) or nil, count = qty or 1 }
    if not entry.name then
      entry.name_pending = true -- item not cached yet; the ID is still reliable
      if itemID then Q.wanted[itemID] = true end -- filled in when the game sends the name (Q.onItemInfo)
      if itemID and api.C_Item and api.C_Item.RequestLoadItemDataByID then
        pcall(api.C_Item.RequestLoadItemDataByID, itemID)
      end
    end
    list[#list + 1] = entry
  end
  return list
end

-- ------------------------------------------------------------------ quest log

local function L() return ns.limits end

local function clean(text, max)
  if type(text) ~= "string" then return nil, false end
  text = util.cleanText(text)
  if text == "" then return nil, false end
  return util.utf8cut(text, max)
end

-- "Fixture Wolf slain: 3/8" -> 3, 8 (the last a/b in the text).
local function parseCount(text)
  local a, b
  for x, y in (text or ""):gmatch("(%d+)%s*/%s*(%d+)") do a, b = tonumber(x), tonumber(y) end
  return a, b
end

local function readObjectives(api, index, questID)
  local out = {}
  local max = L().max_objectives
  local list
  if questID and api.C_QuestLog and api.C_QuestLog.GetQuestObjectives then
    local ok, r = pcall(api.C_QuestLog.GetQuestObjectives, questID)
    if ok and type(r) == "table" and #r > 0 then list = r end
  end
  if list then
    for j, o in ipairs(list) do
      if j > max then break end
      local text = clean(o.text, 200)
      local a, b = parseCount(text)
      out[#out + 1] = { index = j, text = text, type = o.type, finished = o.finished == true,
                        fulfilled = o.numFulfilled or a, required = o.numRequired or b }
    end
  elseif index and api.GetNumQuestLeaderBoards and api.GetQuestLogLeaderBoard then
    local n = api.GetNumQuestLeaderBoards(index) or 0
    for j = 1, math.min(n, max) do
      local text, kind, finished = api.GetQuestLogLeaderBoard(j, index)
      text = clean(text, 200)
      local a, b = parseCount(text)
      out[#out + 1] = { index = j, text = text, type = kind, finished = finished == true or finished == 1,
                        fulfilled = a, required = b }
    end
  end
  return out
end

-- Every quest the log lists. WoW Forever has only the C_QuestLog functions (a real 0.3.0 log showed
-- GetQuestLogTitle and GetNumQuestLogEntries missing, so accepted quests had just a title); older
-- clients have only the globals, which stay as the fallback. With the globals, quests under collapsed
-- headers can't be read.
local function questComplete(api, info, questID)
  if info.isComplete ~= nil then return info.isComplete == 1 or info.isComplete == true end
  local f = api.C_QuestLog.IsComplete or api.C_QuestLog.ReadyForTurnIn
  if not f then return false end
  local ok, r = pcall(f, questID)
  return ok and r == true
end

local function readLogModern(api)
  local out, order = {}, {}
  local ok, n = pcall(api.C_QuestLog.GetNumQuestLogEntries)
  if not ok or type(n) ~= "number" then return nil end
  for i = 1, n do
    local okInfo, info = pcall(api.C_QuestLog.GetInfo, i)
    if okInfo and type(info) == "table" and not info.isHeader and not info.isHidden
        and type(info.questID) == "number" and info.questID > 0 then
      local id = info.questID
      local idx = info.questLogIndex or i
      out[id] = { index = idx, quest_id = id, title = clean(info.title, 200), level = info.level,
                  complete = questComplete(api, info, id), objectives = readObjectives(api, idx, id) }
      order[#order + 1] = id
    end
  end
  return out, order
end

local function readLog(api)
  if api.C_QuestLog and api.C_QuestLog.GetNumQuestLogEntries and api.C_QuestLog.GetInfo then
    local out, order = readLogModern(api)
    if out then return out, order end
  end
  local out, order = {}, {}
  if not api.GetNumQuestLogEntries or not api.GetQuestLogTitle then return out, order end
  local n = api.GetNumQuestLogEntries() or 0
  for i = 1, n do
    local title, level, _, isHeader, _, isComplete, _, questID = api.GetQuestLogTitle(i)
    if title and not isHeader and questID and questID > 0 then
      out[questID] = { index = i, quest_id = questID, title = clean(title, 200), level = level,
                       complete = isComplete == 1 or isComplete == true,
                       objectives = readObjectives(api, i, questID) }
      order[#order + 1] = questID
    end
  end
  return out, order
end
Q.readLog = readLog

-- The short objective summary and (only when allowed) the full quest text. Selecting a quest log
-- entry is how the game exposes this; the player's own selection is put back straight away.
-- C_QuestLog.SetSelectedQuest on Forever, SelectQuestLogEntry on older clients.
local function selectAndRead(api, index, questID)
  local C = api.C_QuestLog
  if C and C.SetSelectedQuest and questID then
    local prev = C.GetSelectedQuest and C.GetSelectedQuest() or nil
    local ok, desc, summary = pcall(function()
      C.SetSelectedQuest(questID)
      return api.GetQuestLogQuestText(index)
    end)
    if prev and prev ~= 0 and prev ~= questID then pcall(C.SetSelectedQuest, prev) end
    return ok, desc, summary
  end
  local prev = api.GetQuestLogSelection and api.GetQuestLogSelection() or nil
  local ok, desc, summary = pcall(function()
    api.SelectQuestLogEntry(index)
    return api.GetQuestLogQuestText()
  end)
  if prev then pcall(api.SelectQuestLogEntry, prev) end
  return ok, desc, summary
end

local function readText(api, index, questID, wantFull)
  if not api.GetQuestLogQuestText then return {} end
  local modern = api.C_QuestLog and api.C_QuestLog.SetSelectedQuest
  if not modern and not api.SelectQuestLogEntry then return {} end
  Q.busy = true
  local ok, desc, summary = selectAndRead(api, index, questID)
  Q.busy = false
  if not ok then return {} end
  local r = {}
  local cut1, cut2
  r.summary, cut1 = clean(summary, L().max_quest_summary_chars)
  if wantFull then r.description, cut2 = clean(desc, L().max_quest_text_chars) end
  if cut1 or cut2 then r.text_cut = true end
  return r
end

local function baselineFrom(log)
  local b = {}
  for id, q in pairs(log) do
    local objs = {}
    for _, o in ipairs(q.objectives) do
      objs[o.index] = { fulfilled = o.fulfilled, finished = o.finished, text = o.text }
    end
    b[id] = { title = q.title, objectives = objs }
  end
  return b
end

-- QUEST_ACCEPTED(questLogIndex, questID) on Classic clients, QUEST_ACCEPTED(questID) on others.
function Q.onAccepted(ctx, a, b)
  local api = ctx.api
  local questID = b or a
  if type(questID) ~= "number" or questID <= 0 then return end
  local log = readLog(api)
  local q = log[questID]
  local data = { quest_id = questID }
  if q then
    data.title, data.level, data.objectives = q.title, q.level, q.objectives
    local t = readText(api, q.index, questID, ctx.settings.record_quest_text == true)
    data.summary, data.description, data.text_cut = t.summary, t.description, t.text_cut
  elseif api.C_QuestLog and api.C_QuestLog.GetTitleForQuestID then
    data.title = clean(api.C_QuestLog.GetTitleForQuestID(questID), 200)
  end
  local _, rec = ctx.record({ type = "quest.accepted", certainty = "confirmed", key = "accept:" .. questID,
                             data = data })
  Q.baseline = Q.baseline or {}
  if q then Q.baseline[questID] = baselineFrom({ [questID] = q })[questID] end
  -- On Forever the log often hasn't filled in a new quest's objectives when QUEST_ACCEPTED fires (a real
  -- 0.3.2 log showed an accepted quest with none). Look again on the next log updates, for a short while.
  if type(rec) == "table" and (not q or #(q.objectives or {}) == 0) then
    Q.late[questID] = { rec = rec, until_t = (ctx.now and ctx.now() or 0) + Q.ACCEPT_RETRY }
  end
end

-- Fills in what the quest log shows now for a quest accepted moments ago (within Q.ACCEPT_RETRY): only
-- empty fields change, from the log itself. Nothing is guessed; a quest that never shows objectives
-- keeps none. The export format is unchanged (no new fields).
local function fillLate(ctx, log)
  local now = ctx.now and ctx.now() or 0
  for id, w in pairs(Q.late) do
    local q = log[id]
    local d = w.rec.data
    if q and type(d) == "table" then
      if not d.title and q.title then d.title = q.title end
      if not d.level and q.level then d.level = q.level end
      if #(d.objectives or {}) == 0 and #(q.objectives or {}) > 0 then d.objectives = q.objectives end
      if not d.summary then
        local t = readText(ctx.api, q.index, id, ctx.settings.record_quest_text == true)
        if t.summary then d.summary = t.summary end
        if t.description and not d.description then d.description = t.description end
        if t.text_cut then d.text_cut = true end
      end
      if #(d.objectives or {}) > 0 then Q.late[id] = nil end
    end
    if Q.late[id] and now > w.until_t then Q.late[id] = nil end
  end
end
Q.fillLate = fillLate

-- QUEST_LOG_UPDATE: compare objective counts with the last reading. The first reading only sets
-- the baseline; an objective seen for the first time is not counted as progress.
function Q.onLogUpdate(ctx)
  if Q.busy then return end
  local log = readLog(ctx.api)
  if next(Q.late) then fillLate(ctx, log) end
  local old = Q.baseline
  Q.baseline = baselineFrom(log)
  if not old then return end
  for id, q in pairs(log) do
    local was = old[id]
    if was then
      for _, o in ipairs(q.objectives) do
        local w = was.objectives[o.index]
        if w and (w.fulfilled ~= o.fulfilled or w.finished ~= o.finished) then
          local key = "progress:" .. id .. ":" .. o.index
          local data = { quest_id = id, title = q.title, index = o.index, text = o.text,
                         fulfilled = o.fulfilled, required = o.required, finished = o.finished }
          if not (ctx.amend and ctx.amend(key, data)) then
            ctx.record({ type = "quest.progress", certainty = "confirmed", key = key, data = data })
          end
        end
      end
    end
  end
end

-- At Start: one list of the quests already in the log. "Already in progress" means only that they
-- were in the log; nothing about how they got there.
function Q.snapshot(ctx)
  local log, order = readLog(ctx.api)
  Q.baseline = baselineFrom(log)
  if #order == 0 then return end
  local quests = {}
  local max = L().max_snapshot_quests
  for _, id in ipairs(order) do
    if #quests >= max then break end
    local q = log[id]
    quests[#quests + 1] = { quest_id = id, title = q.title, level = q.level, complete = q.complete,
                            objectives = q.objectives }
  end
  ctx.record({ type = "quest.snapshot", certainty = "seen",
               data = { quests = quests, listed = #order, kept = #quests } })
end

-- When a stopped session continues: read the quest log again so later progress is measured from now,
-- without recording a new list (the session already has its list from Start).
function Q.rebase(ctx)
  local log = readLog(ctx.api)
  Q.baseline = baselineFrom(log)
end

-- ------------------------------------------------------------------ turn-ins

-- QUEST_COMPLETE: the reward panel is open.
function Q.onComplete(ctx)
  local api = ctx.api
  local questID = api.GetQuestID and api.GetQuestID() or nil
  if not questID or questID == 0 then return end
  local title = api.GetTitleText and api.GetTitleText() or nil
  local choices = readItems(api, "choice", api.GetNumQuestChoices and api.GetNumQuestChoices() or 0)
  local guaranteed = readItems(api, "reward", api.GetNumQuestRewards and api.GetNumQuestRewards() or 0)
  local now = ctx.now()
  for id, old in pairs(Q.pending) do -- forget offers that were cancelled long ago
    if now - (old.offered_at or now) > 3600 then Q.pending[id] = nil end
  end
  local p = { quest_id = questID, title = title, choices = choices, guaranteed = guaranteed, offered_at = now }
  Q.pending[questID] = p
  Q.current = questID
  ctx.record({ type = "quest.rewards_offered", certainty = "seen", key = "offer:" .. questID,
               data = { quest_id = questID, title = title, choices = choices, guaranteed = guaranteed } })
end

-- Post-hook on GetQuestReward(choiceIndex): runs after the game's own handler; changes nothing.
function Q.onGetQuestReward(ctx, choiceIndex)
  local questID = Q.current
  local p = questID and Q.pending[questID]
  if not p then return end
  local api = ctx.api
  local selected
  if #p.choices > 0 then
    for _, c in ipairs(p.choices) do if c.index == choiceIndex then selected = c end end
  end
  p.selected = selected
  -- Snapshot bag counts now so a later increase can be attributed (as an inference).
  p.before = {}
  local watch = {}
  if selected then watch[#watch + 1] = selected end
  for _, g in ipairs(p.guaranteed) do watch[#watch + 1] = g end
  for _, it in ipairs(watch) do
    if it.item_id then p.before[it.item_id] = itemCount(api, it.item_id) end
  end
  p.watch = watch
  if #p.choices > 0 then
    ctx.record({ type = "quest.reward_selected", certainty = selected and "inferred" or "uncertain",
                 key = "select:" .. questID,
                 data = { quest_id = questID, choice_index = choiceIndex,
                          item_id = selected and selected.item_id or nil, name = selected and selected.name or nil } })
  end
end

-- QUEST_TURNED_IN(questID, xpReward, moneyReward)
function Q.onTurnedIn(ctx, questID, xp, money)
  if not questID then return end
  local api = ctx.api
  local p = Q.pending[questID]
  local title = p and p.title
  if not title and api.C_QuestLog and api.C_QuestLog.GetTitleForQuestID then
    title = api.C_QuestLog.GetTitleForQuestID(questID)
  end
  if Q.baseline then Q.baseline[questID] = nil end
  ctx.record({ type = "quest.turned_in", certainty = "confirmed", key = "turnin:" .. questID,
               data = { quest_id = questID, title = title, xp = xp, money_copper = money } })
  if p and p.watch and #p.watch > 0 then
    Q.awaitingBags[#Q.awaitingBags + 1] = { quest_id = questID, watch = p.watch, before = p.before, at = ctx.now() }
  end
  Q.pending[questID] = nil
  if Q.current == questID then Q.current = nil end
end

-- BAG_UPDATE_DELAYED: compare counts for recently turned-in quests.
function Q.onBags(ctx)
  local now = ctx.now()
  local keep = {}
  for _, w in ipairs(Q.awaitingBags) do
    local found = false
    for _, it in ipairs(w.watch) do
      local before = w.before[it.item_id]
      local after = itemCount(ctx.api, it.item_id)
      if before and after and after > before then
        found = true
        ctx.record({ type = "item.received", certainty = "inferred", key = "recv:" .. w.quest_id .. ":" .. it.item_id,
                     data = { quest_id = w.quest_id, item_id = it.item_id, name = it.name, count_delta = after - before,
                              basis = "bag_count_increase_after_turn_in" } })
      end
    end
    if not found and now - w.at <= Q.RECEIPT_WINDOW then keep[#keep + 1] = w end
  end
  Q.awaitingBags = keep
end

-- GET_ITEM_INFO_RECEIVED / ITEM_DATA_LOAD_RESULT (itemID, success): the game has loaded an item a
-- reward panel listed without a name. Its name (for that same item ID, from the game) is filled in on
-- the waiting offer and on what was already recorded; nothing else changes.
local function itemName(api, itemID)
  local C = api.C_Item
  local tries = { C and C.GetItemNameByID, C and C.GetItemInfo, api.GetItemInfo }
  for _, f in ipairs(tries) do
    if f then
      local ok, name = pcall(f, itemID)
      if ok and type(name) == "string" and name ~= "" then return name end
    end
  end
end

function Q.onItemInfo(ctx, itemID, success)
  if type(itemID) ~= "number" or not Q.wanted[itemID] or success == false then return end
  local name = itemName(ctx.api, itemID)
  if not name then return end
  name = clean(name, 200)
  if not name then return end
  Q.wanted[itemID] = nil
  for _, p in pairs(Q.pending) do
    for _, list in ipairs({ p.choices, p.guaranteed }) do
      for _, it in ipairs(list or {}) do
        if it.item_id == itemID and it.name_pending then it.name, it.name_pending = name, nil end
      end
    end
  end
  if ctx.fillItemName then ctx.fillItemName(itemID, name) end
end

-- QUEST_FINISHED: the panel closed. If no turn-in followed, the offer stays recorded as "seen" only.
function Q.onFinished()
  Q.current = nil
end

Q.events = {
  QUEST_ACCEPTED = function(ctx, ...) Q.onAccepted(ctx, ...) end,
  QUEST_LOG_UPDATE = function(ctx) Q.onLogUpdate(ctx) end,
  QUEST_COMPLETE = function(ctx) Q.onComplete(ctx) end,
  QUEST_TURNED_IN = function(ctx, ...) Q.onTurnedIn(ctx, ...) end,
  QUEST_FINISHED = function(ctx) Q.onFinished(ctx) end,
  BAG_UPDATE_DELAYED = function(ctx) Q.onBags(ctx) end,
  GET_ITEM_INFO_RECEIVED = function(ctx, ...) Q.onItemInfo(ctx, ...) end,
  ITEM_DATA_LOAD_RESULT = function(ctx, ...) Q.onItemInfo(ctx, ...) end,
}

return Q
