-- Adventure Chronicler: quest turn-ins and rewards.
--
-- Three separate facts, never merged into a guess:
--   quest.rewards_offered  (seen)      the reward panel showed these items
--   quest.reward_selected  (inferred)  the player clicked "Complete Quest" with this choice
--   quest.turned_in        (confirmed) the game reported the turn-in
--   item.received          (inferred)  bag count of a reward item went up shortly after the turn-in
-- Cancelling the panel leaves only "offered". Seeing a reward is not receiving it.
local _, ns = ...
ns = ns or {}
ns.capture = ns.capture or {}
local util = ns.util

local Q = { pending = {}, current = nil, awaitingBags = {} }
ns.capture.quests = Q

Q.RECEIPT_WINDOW = 10 -- seconds after turn-in to look for bag changes

function Q.reset() Q.pending, Q.current, Q.awaitingBags = {}, nil, {} end

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
      if itemID and api.C_Item and api.C_Item.RequestLoadItemDataByID then
        pcall(api.C_Item.RequestLoadItemDataByID, itemID)
      end
    end
    list[#list + 1] = entry
  end
  return list
end

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

-- QUEST_FINISHED: the panel closed. If no turn-in followed, the offer stays recorded as "seen" only.
function Q.onFinished()
  Q.current = nil
end

Q.events = {
  QUEST_COMPLETE = function(ctx) Q.onComplete(ctx) end,
  QUEST_TURNED_IN = function(ctx, ...) Q.onTurnedIn(ctx, ...) end,
  QUEST_FINISHED = function(ctx) Q.onFinished(ctx) end,
  BAG_UPDATE_DELAYED = function(ctx) Q.onBags(ctx) end,
}

return Q
