-- Adventure Chronicler: CRC-32 (IEEE 802.3, same as zlib.crc32) to detect damaged copy/paste.
-- A checksum detects accidents only. It is not a signature and proves nothing about gameplay.
local _, ns = ...
ns = ns or {}

local bitlib = bit -- luacheck: ignore (WoW provides the LuaBitOp "bit" library)

local bxor, band, rshift
if bitlib and bitlib.bxor then
  bxor, band, rshift = bitlib.bxor, bitlib.band, bitlib.rshift
else
  -- Portable arithmetic fallback (used by plain Lua 5.1 tests).
  bxor = function(a, b)
    local r, p = 0, 1
    for _ = 1, 32 do
      local x, y = a % 2, b % 2
      if x ~= y then r = r + p end
      a, b, p = (a - x) / 2, (b - y) / 2, p * 2
    end
    return r
  end
  band = function(a, m) return a % (m + 1) end -- only used with m = 0xFF
  rshift = function(a, n) return math.floor(a / 2 ^ n) end
end

local function u32(n) return n % 4294967296 end

local T = {}
for i = 0, 255 do
  local c = i
  for _ = 1, 8 do
    if c % 2 == 1 then c = bxor(rshift(c, 1), 0xEDB88320) else c = rshift(c, 1) end
  end
  T[i] = u32(c)
end

local function crc32(s)
  local crc = 0xFFFFFFFF
  for i = 1, #s do
    crc = bxor(rshift(u32(crc), 8), T[band(bxor(u32(crc), s:byte(i)), 0xFF)])
  end
  return u32(bxor(u32(crc), 0xFFFFFFFF))
end

ns.crc32 = crc32
return crc32
