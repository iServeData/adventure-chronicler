-- Adventure Chronicler: optional personal loot (off by default; turn on in Settings or /ac set loot on).
-- Records items shown in the player's own loot window as "seen". Seeing loot is not receiving it.
-- Chat (including loot messages) is never read.
--
-- The Loot settings can leave items out of the recording: below a minimum quality, quest items, trade goods
-- or grey junk. Left-out items are never recorded at all (not just hidden). Quality and quest-item flags
-- come from the loot window itself, item type from the game's item data on this computer; when the game
-- doesn't say, the item is kept rather than guessed about.
--
-- WoW Forever fires LOOT_READY twice for one loot window (seen in a real 0.3.0 log: every window listed
-- twice, 0-1 seconds apart). The same items again while the window is still open, or within
-- Lo.SAME_WINDOW seconds, are taken as the same window and recorded once. Two identical windows looted
-- within those seconds of each other would also count once; that's the trade-off.
local _, ns = ...
ns = ns or {}
ns.capture = ns.capture or {}
local util = ns.util

local Lo = { last = nil }
Lo.SAME_WINDOW = 2 -- seconds
function Lo.reset() Lo.last = nil end

-- "17056x1,4306x2": the items and counts in the order the window listed them.
local function signature(items)
  local parts = {}
  for _, it in ipairs(items) do parts[#parts + 1] = tostring(it.item_id) .. "x" .. tostring(it.count) end
  return table.concat(parts, ",")
end
ns.capture.loot = Lo

Lo.TRADE_GOODS_CLASS = 7 -- the game's item class for trade goods (cloth, leather, herbs, ore...)

-- Whether a loot window item is recorded under the Loot settings. it = { quality, quest, class_id }; any
-- of them can be nil when the game doesn't say, and nil never leaves an item out.
function Lo.keep(it, settings)
  if it.quest == true then return settings.loot_skip_quest ~= true end
  local q = tonumber(it.quality)
  if q and settings.loot_skip_junk == true and q == 0 then return false end
  if q and q < (tonumber(settings.loot_min_quality) or 0) then return false end
  if settings.loot_skip_trade == true and it.class_id == Lo.TRADE_GOODS_CLASS then return false end
  return true
end

local function classOf(api, itemID)
  local fn = (api.C_Item and api.C_Item.GetItemInfoInstant) or api.GetItemInfoInstant
  if not fn then return nil end
  local ok, _, _, _, _, _, classID = pcall(fn, itemID)
  return ok and tonumber(classID) or nil
end

local function qualityOf(api, itemID)
  local fn = api.C_Item and api.C_Item.GetItemQualityByID
  if not fn then return nil end
  local ok, q = pcall(fn, itemID)
  return ok and type(q) == "number" and q or nil
end

function Lo.onReady(ctx)
  if ctx.settings.record_personal_loot ~= true then return end
  local api = ctx.api
  if not api.GetNumLootItems or not api.GetLootSlotLink then return end
  local items = {}
  for i = 1, api.GetNumLootItems() do
    local link = api.GetLootSlotLink(i)
    local itemID = util.itemIdFromLink(link)
    if itemID then
      local qty, quality, isQuest
      if api.GetLootSlotInfo then
        local _, _, q, _, qual, _, quest = api.GetLootSlotInfo(i)
        qty, quality, isQuest = q, qual, quest
      end
      -- Older clients return these in other places; anything that isn't the expected type counts as unknown.
      if type(quality) ~= "number" then quality = qualityOf(api, itemID) end
      local it = { quality = quality, quest = isQuest == true, class_id = classOf(api, itemID) }
      if Lo.keep(it, ctx.settings) then
        items[#items + 1] = { item_id = itemID, name = link and link:match("%[(.-)%]") or nil, count = qty or 1 }
      end
    end
  end
  if #items == 0 then return end
  local sig, now = signature(items), ctx.now()
  local last = Lo.last
  if last and last.sig == sig and (last.open or now - last.t <= Lo.SAME_WINDOW) then return end
  Lo.last = { sig = sig, t = now, open = true }
  ctx.record({ type = "loot.seen", certainty = "seen", data = { items = items } })
end

function Lo.onClosed()
  if Lo.last then Lo.last.open = false end
end

Lo.events = {
  LOOT_READY = function(ctx) Lo.onReady(ctx) end,
  LOOT_CLOSED = function() Lo.onClosed() end,
}

return Lo
