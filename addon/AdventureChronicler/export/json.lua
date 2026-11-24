-- Adventure Chronicler: minimal, deterministic JSON encoder (export only; the addon never parses imports).
-- Object keys are sorted so the same session always produces the same text.
local _, ns = ...
ns = ns or {}

local json = {}
ns.json = json

local ARRAY = {}
json.null = setmetatable({}, { __tostring = function() return "null" end })

-- Mark a table as a JSON array (so empty tables encode as [] rather than {}).
function json.array(t)
  return setmetatable(t or {}, ARRAY)
end

local escapes = {
  ['"'] = '\\"', ["\\"] = "\\\\", ["\b"] = "\\b", ["\f"] = "\\f",
  ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t",
  ["<"] = "\\u003c", [">"] = "\\u003e", ["&"] = "\\u0026",
}

local function encodeString(s)
  s = s:gsub('[%c"\\<>&]', function(c)
    return escapes[c] or string.format("\\u%04x", c:byte())
  end)
  -- U+2028 / U+2029 are valid JSON but break some JavaScript contexts.
  s = s:gsub("\226\128\168", "\\u2028"):gsub("\226\128\169", "\\u2029")
  return '"' .. s .. '"'
end

local function encodeNumber(n)
  if n ~= n or n == math.huge or n == -math.huge then error("json: non-finite number") end
  if n == math.floor(n) and math.abs(n) < 2 ^ 53 then return string.format("%d", n) end
  return string.format("%.14g", n)
end

local encode

local function encodeTable(t, depth)
  if depth > 16 then error("json: nesting too deep") end
  local out = {}
  if getmetatable(t) == ARRAY then
    for i = 1, #t do out[i] = encode(t[i], depth + 1) end
    return "[" .. table.concat(out, ",") .. "]"
  end
  local keys = {}
  for k in pairs(t) do
    if type(k) ~= "string" then error("json: object keys must be strings") end
    keys[#keys + 1] = k
  end
  table.sort(keys)
  for i, k in ipairs(keys) do out[i] = encodeString(k) .. ":" .. encode(t[k], depth + 1) end
  return "{" .. table.concat(out, ",") .. "}"
end

encode = function(v, depth)
  local tv = type(v)
  if v == json.null then return "null"
  elseif tv == "string" then return encodeString(v)
  elseif tv == "number" then return encodeNumber(v)
  elseif tv == "boolean" then return v and "true" or "false"
  elseif tv == "table" then return encodeTable(v, depth)
  end
  error("json: cannot encode " .. tv)
end

function json.encode(v)
  return encode(v, 0)
end

return json
