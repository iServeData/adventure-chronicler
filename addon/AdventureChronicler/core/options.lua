-- Adventure Chronicler: the settings shown in the Options tab, grouped into categories (A-Z). Pure data
-- and helpers so they can be tested; the window in ui/settings.lua draws them. Every setting here can
-- also be changed in chat with /ac set.
local _, ns = ...
ns = ns or {}

local O = {}
ns.options = O

O.CATEGORIES = { "Export", "Loot", "Minimap", "Privacy", "Recording", "Windows" }

-- kind = "check" (default) or "quality" (the minimum quality list).
O.LIST = {
  { cat = "Export", key = "include_class_level", label = "Put my class and level in exports",
    help = "Not identifying on their own." },
  { cat = "Loot", key = "record_personal_loot", label = "Record my loot windows",
    help = "Off unless you turn it on. Seeing loot isn't receiving it; entries say \"seen\"." },
  { cat = "Loot", key = "loot_min_quality", kind = "quality", label = "Record items of quality",
    help = "Lower-quality items in a loot window are left out of the log. Quest items follow their own box." },
  { cat = "Loot", key = "loot_skip_quest", label = "Leave out quest items" },
  { cat = "Loot", key = "loot_skip_trade", label = "Leave out trade goods (cloth, leather, herbs, ore)" },
  { cat = "Loot", key = "loot_skip_junk", label = "Leave out junk you sell to vendors",
    help = "Grey (Poor quality) items." },
  { cat = "Minimap", key = "minimap_button", label = "Show the compass button on the minimap" },
  { cat = "Privacy", key = "include_identity", label = "Put my character name and realm in exports",
    help = "Off unless you turn it on." },
  { cat = "Recording", key = "prompt_on_instance", label = "Ask to start when I enter a dungeon or raid",
    help = "It only asks; it never starts on its own." },
  { cat = "Recording", key = "record_pvp", label = "Record battlegrounds and my deaths" },
  { cat = "Recording", key = "record_quest_text", label = "Keep the quest giver's full text",
    help = "Objectives are always kept." },
  { cat = "Windows", key = "indicator_buttons", label = "Show the small buttons on the mini recorder" },
  { cat = "Windows", key = "whats_new_on_update", label = "Show What's new once after an update",
    help = "Help, What's new opens it any time." },
}

-- What each category's footnote says.
O.NOTES = {
  Loot = "These only change what's recorded from now on. Nothing already in your log is removed; use the "
    .. "review window's Filter to hide entries instead. Quality and item type come from the game's own item "
    .. "data on your computer; an item whose type the game doesn't say is kept.",
}

-- Item quality names, lowest first, as the game numbers them, with the colours the game uses.
O.QUALITY = { [0] = "Poor", [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary" }
O.QUALITY_COLOUR = { [0] = "9d9d9d", [1] = "ffffff", [2] = "1eff00", [3] = "0070dd", [4] = "a335ee",
                     [5] = "ff8000" }
O.MIN_QUALITY_CHOICES = { 0, 1, 2, 3, 4 }

function O.qualityChoiceLabel(q, plain)
  q = tonumber(q) or 0
  if q <= 0 then return "All qualities" end
  local name = O.QUALITY[q] or tostring(q)
  if not plain then name = "|cff" .. (O.QUALITY_COLOUR[q] or "ffffff") .. name .. "|r" end
  return name .. (q >= 4 and " only" or " and better")
end

function O.inCategory(cat)
  local out = {}
  for _, o in ipairs(O.LIST) do if o.cat == cat then out[#out + 1] = o end end
  return out
end

-- Settings whose category, label or explanation contain the text (any case). "" finds nothing.
function O.search(text)
  text = (text or ""):lower():match("^%s*(.-)%s*$")
  if text == "" then return {} end
  local out = {}
  for _, o in ipairs(O.LIST) do
    local hay = (o.cat .. " " .. o.label .. " " .. (o.help or "")):lower()
    if hay:find(text, 1, true) then out[#out + 1] = o end
  end
  return out
end

-- Puts the given settings back to their defaults.
function O.reset(settings, defaults, list)
  for _, o in ipairs(list) do settings[o.key] = defaults[o.key] end
end

return O
