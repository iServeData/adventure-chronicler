-- Adventure Chronicler: small helpers with no game API use (testable outside the client).
local _, ns = ...
ns = ns or {}

local util = {}
ns.util = util

-- Count UTF-8 characters (code points). Invalid bytes count as one character each.
function util.utf8len(s)
  local n, i, len = 0, 1, #s
  while i <= len do
    local c = s:byte(i)
    local step = 1
    if c >= 0xF0 and c <= 0xF4 then step = 4
    elseif c >= 0xE0 then step = 3
    elseif c >= 0xC2 and c <= 0xDF then step = 2 end
    if step > 1 and c < 0xF8 then
      for k = 1, step - 1 do
        local cc = s:byte(i + k)
        if not cc or cc < 0x80 or cc > 0xBF then step = 1 break end
      end
    else
      step = 1
    end
    n = n + 1
    i = i + step
  end
  return n
end

-- Replace invalid UTF-8 sequences with U+FFFD so exports are always valid UTF-8.
function util.utf8clean(s)
  local out, i, len = {}, 1, #s
  while i <= len do
    local c = s:byte(i)
    local need, min
    if c < 0x80 then need, min = 0, 0
    elseif c >= 0xC2 and c <= 0xDF then need, min = 1, 0x80
    elseif c >= 0xE0 and c <= 0xEF then need, min = 2, 0x800
    elseif c >= 0xF0 and c <= 0xF4 then need, min = 3, 0x10000
    else need = -1 end
    local ok = need >= 0
    local cp
    if ok and need > 0 then
      cp = c % (2 ^ (6 - need))
      for k = 1, need do
        local cc = s:byte(i + k)
        if not cc or cc < 0x80 or cc > 0xBF then ok = false break end
        cp = cp * 64 + (cc - 0x80)
      end
      if ok and (cp < min or cp > 0x10FFFF or (cp >= 0xD800 and cp <= 0xDFFF)) then ok = false end
    end
    if ok then
      out[#out + 1] = s:sub(i, i + need)
      i = i + need + 1
    else
      out[#out + 1] = "\239\191\189"
      i = i + 1
    end
  end
  return table.concat(out)
end

-- Strip WoW UI escape sequences (colours, hyperlinks, textures) to plain text.
-- "||" is a literal pipe in WoW text and is kept as a single "|".
function util.stripEscapes(s)
  s = s:gsub("||", "\1")
  s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
  s = s:gsub("|cn[%w_]+:", "")
  s = s:gsub("|r", "")
  s = s:gsub("|H.-|h(.-)|h", "%1")
  s = s:gsub("|T.-|t", "")
  s = s:gsub("|A.-|a", "")
  s = s:gsub("|K.-|k", "")
  s = s:gsub("|n", "\n")
  s = s:gsub("\1", "|")
  return s
end

-- Normalise user-authored text: strip escapes, fix encoding, normalise newlines, trim ends.
function util.cleanText(s)
  if type(s) ~= "string" then return "" end
  s = util.stripEscapes(s)
  s = util.utf8clean(s)
  s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
  s = s:gsub("^%s+", ""):gsub("%s+$", "")
  return s
end

-- The first n characters (code points) of s, and whether anything was cut. Callers record the cut
-- explicitly (for example text_cut = true) so shortened text is never passed off as whole.
function util.utf8cut(s, n)
  if util.utf8len(s) <= n then return s, false end
  local count, i, len = 0, 1, #s
  while i <= len and count < n do
    local c = s:byte(i)
    local step = (c >= 0xF0 and 4) or (c >= 0xE0 and 3) or (c >= 0xC2 and 2) or 1
    i = i + step
    count = count + 1
  end
  return util.utf8clean(s:sub(1, i - 1)), true
end

-- Parse an item ID from an item link or item string.
function util.itemIdFromLink(link)
  if type(link) ~= "string" then return nil end
  local id = link:match("item:(%d+)")
  return id and tonumber(id) or nil
end

function util.copy(t)
  if type(t) ~= "table" then return t end
  local r = {}
  for k, v in pairs(t) do r[k] = util.copy(v) end
  return r
end

-- Deep equality for plain data tables (used for de-duplication).
function util.equal(a, b)
  if a == b then return true end
  if type(a) ~= "table" or type(b) ~= "table" then return false end
  for k, v in pairs(a) do if not util.equal(v, b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end

-- Combat-restricted ("secret") values may not be inspected by addons.
-- Returns value, isSecret. Secret values are never stored.
function util.safe(v, api)
  local f = api and api.issecretvalue
  if f and f(v) then return nil, true end
  return v, false
end

function util.formatDuration(sec)
  sec = math.max(0, math.floor(sec or 0))
  local h = math.floor(sec / 3600)
  local m = math.floor((sec % 3600) / 60)
  local s = sec % 60
  return string.format("%d:%02d:%02d", h, m, s)
end

return util
