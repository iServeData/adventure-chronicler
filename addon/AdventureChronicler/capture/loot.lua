-- Adventure Chronicler: optional personal loot (off by default; turn on in /ac options).
-- Records items shown in the player's own loot window as "seen". Seeing loot is not receiving it.
-- Chat (including loot messages) is never read.
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

function Lo.onReady(ctx)
  if ctx.settings.record_personal_loot ~= true then return end
  local api = ctx.api
  if not api.GetNumLootItems or not api.GetLootSlotLink then return end
  local items = {}
  for i = 1, api.GetNumLootItems() do
    local link = api.GetLootSlotLink(i)
    local itemID = util.itemIdFromLink(link)
    if itemID then
      local qty
      if api.GetLootSlotInfo then
        local _, _, q = api.GetLootSlotInfo(i)
        qty = q
      end
      items[#items + 1] = { item_id = itemID, name = link and link:match("%[(.-)%]") or nil, count = qty or 1 }
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
