-- Adventure Chronicler: user-triggered screenshots with two presets.
--
--   as_seen      takes the screenshot exactly as the screen looks.
--   clean_scene  out of combat only: fades the interface out (UIParent alpha) and hides nameplates,
--                takes the screenshot, then puts back the exact previous alpha and nameplate settings.
--
-- Settings are never changed permanently. If restoring a setting is blocked (combat began),
-- it is queued and applied when combat ends. Hidden nameplates do NOT anonymise everything:
-- names above characters, chat bubbles and other on-screen text can still appear.
-- The addon only records that a screenshot was taken; it never reads or stores image files.
local _, ns = ...
ns = ns or {}
ns.capture = ns.capture or {}

local Sh = { busy = nil, queuedRestore = nil }
ns.capture.screenshot = Sh

Sh.PRESETS = { as_seen = true, clean_scene = true }
Sh.NAMEPLATE_CVARS = { "nameplateShowEnemies", "nameplateShowFriends" }
Sh.TIMEOUT = 5

function Sh.reset() Sh.busy, Sh.queuedRestore = nil, nil end

local function getCVar(api, name)
  if api.C_CVar and api.C_CVar.GetCVar then return api.C_CVar.GetCVar(name) end
  return api.GetCVar and api.GetCVar(name) or nil
end

local function setCVar(api, name, value)
  local f = (api.C_CVar and api.C_CVar.SetCVar) or api.SetCVar
  if not f then return false end
  local ok = pcall(f, name, value)
  return ok
end

local function inCombat(api)
  return api.InCombatLockdown and api.InCombatLockdown() or false
end

-- Put everything back. Safe to call more than once.
function Sh.restore(ctx)
  local b = Sh.busy
  if not b or b.restored then return end
  b.restored = true
  local api = ctx.api
  if b.prevAlpha and api.UIParent then api.UIParent:SetAlpha(b.prevAlpha) end
  if b.prevCVars then
    if inCombat(api) then
      Sh.queuedRestore = b.prevCVars
    else
      for name, value in pairs(b.prevCVars) do setCVar(api, name, value) end
    end
  end
end

-- Returns true or nil + reason ("busy", "in_combat", "unknown_preset", "unavailable").
function Sh.take(ctx, preset)
  preset = preset or "as_seen"
  if not Sh.PRESETS[preset] then return nil, "unknown_preset" end
  if Sh.busy then return nil, "busy" end
  local api = ctx.api
  if not api.Screenshot then return nil, "unavailable" end
  local b = { preset = preset, at = ctx.now() }
  if preset == "clean_scene" then
    if inCombat(api) then return nil, "in_combat" end
    if api.UIParent then
      b.prevAlpha = api.UIParent:GetAlpha()
      api.UIParent:SetAlpha(0)
    end
    b.prevCVars = {}
    for _, name in ipairs(Sh.NAMEPLATE_CVARS) do
      local v = getCVar(api, name)
      if v ~= nil then
        b.prevCVars[name] = v
        setCVar(api, name, "0")
      end
    end
  end
  Sh.busy = b
  local function shoot()
    local ok = pcall(api.Screenshot)
    if not ok then Sh.finish(ctx, false) end
  end
  if preset == "clean_scene" and api.C_Timer and api.C_Timer.After then
    api.C_Timer.After(0.2, shoot) -- let one frame render without the interface
  else
    shoot()
  end
  if api.C_Timer and api.C_Timer.After then
    api.C_Timer.After(Sh.TIMEOUT, function() if Sh.busy == b then Sh.finish(ctx, nil) end end)
  end
  return true
end

-- status: true (succeeded), false (failed) or nil (no confirmation before timeout).
function Sh.finish(ctx, status)
  local b = Sh.busy
  if not b then return end
  Sh.restore(ctx)
  Sh.busy = nil
  local s = status == true and "succeeded" or (status == false and "failed" or "unconfirmed")
  ctx.record({ type = "marker.screenshot", certainty = status == true and "confirmed" or "uncertain",
               data = { preset = b.preset, status = s } }, { allow_paused = true })
end

function Sh.onCombatEnded(ctx)
  if Sh.queuedRestore then
    for name, value in pairs(Sh.queuedRestore) do setCVar(ctx.api, name, value) end
    Sh.queuedRestore = nil
  end
end

Sh.events = {
  SCREENSHOT_SUCCEEDED = function(ctx) Sh.finish(ctx, true) end,
  SCREENSHOT_FAILED = function(ctx) Sh.finish(ctx, false) end,
  PLAYER_REGEN_ENABLED = function(ctx) Sh.onCombatEnded(ctx) end,
  PLAYER_REGEN_DISABLED = function(ctx) if Sh.busy then Sh.restore(ctx) end end,
}

return Sh
