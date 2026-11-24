-- Adventure Chronicler: optional personal loot (off by default; turn on in /ac options).
-- Records items shown in the player's own loot window as "seen". Seeing loot is not receiving it.
-- Chat (including loot messages) is never read.
local _, ns = ...
ns = ns or {}
ns.capture = ns.capture or {}
local util = ns.util

local Lo = {}
function Lo.reset() end
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
  if #items > 0 then
    ctx.record({ type = "loot.seen", certainty = "seen", data = { items = items } })
  end
end

Lo.events = {
  LOOT_READY = function(ctx) Lo.onReady(ctx) end,
}

return Lo
