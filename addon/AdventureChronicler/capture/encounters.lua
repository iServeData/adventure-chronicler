-- Adventure Chronicler: boss encounters reported by the game (ENCOUNTER_START / ENCOUNTER_END).
-- One boss kill is recorded as one boss kill. Nothing here infers a full dungeon clear.
local _, ns = ...
ns = ns or {}
ns.capture = ns.capture or {}
local util = ns.util

local En = { open = {} }
ns.capture.encounters = En

function En.reset() En.open = {} end

local function clean(api, ...)
  local out, anySecret = {}, false
  for i = 1, select("#", ...) do
    local v, secret = util.safe(select(i, ...), api)
    out[i] = v
    if secret then anySecret = true end
  end
  return out, anySecret
end

function En.onStart(ctx, ...)
  local v, secret = clean(ctx.api, ...)
  local id = v[1]
  if id then En.open[id] = ctx.now() end
  ctx.record({ type = "encounter.start", certainty = secret and "uncertain" or "confirmed",
               key = "enc_start:" .. tostring(id),
               data = { encounter_id = id, name = v[2], difficulty_id = v[3], group_size = v[4],
                        restricted_values = secret or nil } })
end

function En.onEnd(ctx, ...)
  local v, secret = clean(ctx.api, ...)
  local id, success = v[1], v[5]
  local started = id and En.open[id]
  if id then En.open[id] = nil end
  local result
  if success == 1 or success == true then result = "success"
  elseif success == 0 or success == false then result = "wipe_or_reset"
  else result = "unknown" end
  ctx.record({ type = "encounter.end", certainty = (secret or result == "unknown") and "uncertain" or "confirmed",
               key = "enc_end:" .. tostring(id),
               data = { encounter_id = id, name = v[2], difficulty_id = v[3], group_size = v[4], result = result,
                        duration = started and (ctx.now() - started) or nil, restricted_values = secret or nil } })
end

En.events = {
  ENCOUNTER_START = function(ctx, ...) En.onStart(ctx, ...) end,
  ENCOUNTER_END = function(ctx, ...) En.onEnd(ctx, ...) end,
}

return En
