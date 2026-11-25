-- Adventure Chronicler: battleground participation, results and the player's own deaths.
-- No opponent names, kills, assists or targeting information are ever read or stored.
local _, ns = ...
ns = ns or {}
ns.capture = ns.capture or {}
local util = ns.util

local P = { active = nil, resultRecorded = false, dead = false }
ns.capture.pvp = P

function P.reset() P.active, P.resultRecorded = nil, false end

local FACTION_BY_WINNER = { [0] = "Horde", [1] = "Alliance" }

local function inBattleground(api)
  if not api.GetInstanceInfo then return false end
  local name, instanceType, _, _, _, _, _, instanceID = api.GetInstanceInfo()
  return instanceType == "pvp", name, instanceID
end

function P.check(ctx)
  if ctx.settings.record_pvp == false then return end
  local api = ctx.api
  local inside, name, instanceID = inBattleground(api)
  if inside and not P.active then
    P.active = { name = name, instance_id = instanceID, at = ctx.now() }
    P.resultRecorded = false
    ctx.record({ type = "pvp.battleground_enter", certainty = "confirmed",
                 data = { instance_id = instanceID, name = name } })
  elseif not inside and P.active then
    ctx.record({ type = "pvp.battleground_leave", certainty = "confirmed",
                 data = { instance_id = P.active.instance_id, name = P.active.name,
                          result_recorded = P.resultRecorded } })
    P.active = nil
  end
end

-- Winner as reported by the client. 0 = Horde, 1 = Alliance; anything else is recorded as unknown.
function P.result(ctx, winner)
  if ctx.settings.record_pvp == false or not P.active or P.resultRecorded then return end
  local api = ctx.api
  winner = util.safe(winner, api)
  if winner == nil and api.GetBattlefieldWinner then winner = util.safe(api.GetBattlefieldWinner(), api) end
  if winner == nil then return end -- not finished yet
  local mine = api.UnitFactionGroup and api.UnitFactionGroup("player") or nil
  local winnerFaction = FACTION_BY_WINNER[winner]
  local outcome = "unknown"
  if winnerFaction and mine then outcome = (winnerFaction == mine) and "won" or "lost" end
  P.resultRecorded = true
  ctx.record({ type = "pvp.battleground_result", certainty = outcome == "unknown" and "uncertain" or "confirmed",
               data = { instance_id = P.active.instance_id, name = P.active.name, winner = winnerFaction or "unknown",
                        player_faction = mine, outcome = outcome } })
end

-- The client can report the same death more than once (seen in game: two reports a second apart). A death
-- is only logged again after the player has been alive in between.
function P.onDeath(ctx)
  if ctx.settings.record_pvp == false then return end
  if P.dead then return end
  P.dead = true
  local api = ctx.api
  local context = "world"
  if P.active then context = "battleground"
  elseif api.IsInInstance then
    local inInstance, kind = api.IsInInstance()
    if inInstance then context = kind or "instance" end
  end
  ctx.record({ type = "player.death", certainty = "confirmed",
               data = { context = context, zone = api.GetRealZoneText and api.GetRealZoneText() or nil } })
end

P.events = {
  PLAYER_ENTERING_WORLD = function(ctx) P.check(ctx) end,
  ZONE_CHANGED_NEW_AREA = function(ctx) P.check(ctx) end,
  UPDATE_BATTLEFIELD_STATUS = function(ctx) P.check(ctx) end,
  PVP_MATCH_COMPLETE = function(ctx, winner) P.result(ctx, winner) end,
  UPDATE_BATTLEFIELD_SCORE = function(ctx) P.result(ctx, nil) end,
  PLAYER_DEAD = function(ctx) P.onDeath(ctx) end,
  -- PLAYER_ALIVE also fires on release to a ghost, so only count it when the player isn't a ghost.
  PLAYER_ALIVE = function(ctx)
    local api = ctx.api
    if not (api.UnitIsGhost and api.UnitIsGhost("player")) then P.dead = false end
  end,
  PLAYER_UNGHOST = function() P.dead = false end,
}

return P
