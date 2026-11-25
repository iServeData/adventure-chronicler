-- Adventure Chronicler: places visited. Records entering a zone or instance; never infers completion.
local _, ns = ...
ns = ns or {}
ns.capture = ns.capture or {}
local util = ns.util

local Z = { last = nil, lastInstance = nil }
ns.capture.zones = Z

function Z.reset() Z.last, Z.lastInstance = nil, nil end

local function instanceInfo(api)
  if not api.GetInstanceInfo then return nil end
  local name, instanceType, difficultyID, difficultyName, maxPlayers, _, _, instanceID = api.GetInstanceInfo()
  if not instanceType or instanceType == "none" then return nil end
  return {
    id = instanceID, name = name, type = instanceType,
    difficulty_id = difficultyID, difficulty = difficultyName, max_players = maxPlayers,
  }
end

function Z.snapshot(api)
  local mapID = api.C_Map and api.C_Map.GetBestMapForUnit and api.C_Map.GetBestMapForUnit("player")
  mapID = util.safe(mapID, api)
  local mapName, mapType
  if mapID and api.C_Map.GetMapInfo then
    local info = api.C_Map.GetMapInfo(mapID)
    mapName = info and info.name
    mapType = info and info.mapType
  end
  local zone = api.GetRealZoneText and api.GetRealZoneText() or nil
  return { map_id = mapID, map = mapName, map_type = mapType, zone = zone ~= "" and zone or nil,
           instance = instanceInfo(api) }
end

-- Continent, world and cosmic maps (map types 0 to 2), plus the Kalimdor and Eastern Kingdoms map IDs in
-- case the type is missing. Seen on boats and zeppelins between zones.
local CONTINENT_IDS = { [1414] = true, [1415] = true }
local function continentOnly(snap)
  local wide = (type(snap.map_type) == "number" and snap.map_type <= 2) or CONTINENT_IDS[snap.map_id]
  return wide and (snap.zone == nil or snap.zone == snap.map)
end

function Z.check(ctx)
  local snap = Z.snapshot(ctx.api)
  local inst = snap.instance
  local instKey = inst and ((inst.id or 0) .. ":" .. (inst.difficulty_id or 0)) or nil
  if Z.lastInstance and Z.lastInstance ~= instKey then
    ctx.record({ type = "instance.leave", certainty = "confirmed", data = { instance = Z.lastInstanceData } })
  end
  if instKey and Z.lastInstance ~= instKey then
    ctx.record({ type = "instance.enter", certainty = "confirmed", data = { instance = inst } })
    if ctx.onInstanceEnter then ctx.onInstanceEnter(inst) end
  end
  Z.lastInstance, Z.lastInstanceData = instKey, inst
  -- Keyed on the zone name: on a flight path the map can switch to the continent while the zone
  -- stays the same, which would otherwise log the same arrival twice.
  -- In transit the map can be a whole continent with no zone; that isn't an arrival, so wait for the
  -- next real zone instead of logging one.
  if continentOnly(snap) then return end
  local key = snap.zone or tostring(snap.map_id or "?")
  if key ~= Z.last then
    Z.last = key
    if snap.map_id or snap.zone then
      ctx.record({ type = "zone.enter", certainty = "confirmed", key = "zone:" .. key,
                   data = { map_id = snap.map_id, map = snap.map, zone = snap.zone } })
    end
  end
end

Z.events = {
  PLAYER_ENTERING_WORLD = function(ctx) Z.check(ctx) end,
  ZONE_CHANGED_NEW_AREA = function(ctx) Z.check(ctx) end,
}

return Z
