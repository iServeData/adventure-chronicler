-- Test helper: loads addon files the way the game does (each file receives addonName, ns) and
-- provides a small fake game API. These are MOCKED tests; they do not prove anything about the
-- real client. See docs/testing.md for the in-game checklist.
local H = {}

local ROOT = "addon/AdventureChronicler/"
local CORE = { "core/util.lua", "core/limits.lua", "core/community.lua", "core/options.lua", "core/report.lua",
  "core/session.lua", "core/describe.lua", "core/reviewfilter.lua", "core/details.lua",
  "core/changelog_data.lua",
  "export/json.lua", "export/crc32.lua", "export/export.lua", "export/formats.lua",
  "capture/zones.lua", "capture/quests.lua", "capture/encounters.lua", "capture/pvp.lua",
  "capture/loot.lua", "capture/screenshot.lua" }

function H.load()
  local ns = {}
  for _, f in ipairs(CORE) do
    local chunk = assert(loadfile(ROOT .. f))
    chunk("AdventureChronicler", ns)
  end
  return ns
end

-- A fake clock and a store with an active session helper.
function H.clock(start)
  local c = { t = start or 1800000000 }
  function c.now() return c.t end
  function c.advance(s) c.t = c.t + s end
  return c
end

-- Minimal fake API. Tests override fields as needed.
function H.api(over)
  local api = {
    cvars = { nameplateShowEnemies = "1", nameplateShowFriends = "0" },
    combat = false, shots = 0, timers = {}, bags = {}, alpha = 1,
  }
  api.C_CVar = {
    GetCVar = function(n) return api.cvars[n] end,
    SetCVar = function(n, v)
      if api.combat then error("blocked in combat") end
      api.cvars[n] = tostring(v)
    end,
  }
  api.InCombatLockdown = function() return api.combat end
  api.Screenshot = function() api.shots = api.shots + 1 end
  api.C_Timer = { After = function(d, fn) api.timers[#api.timers + 1] = { d = d, fn = fn } end }
  api.UIParent = { GetAlpha = function() return api.alpha end, SetAlpha = function(_, a) api.alpha = a end }
  api.minimapShown = true
  api.Minimap = { IsShown = function() return api.minimapShown end,
                  Hide = function() api.minimapShown = false end, Show = function() api.minimapShown = true end }
  api.date = function() return "15:52:16" end
  api.C_Item = { GetItemCount = function(id) return api.bags[id] or 0 end }
  function api.runTimers(maxDelay)
    local pending = api.timers
    api.timers = {}
    for _, t in ipairs(pending) do
      if not maxDelay or t.d <= maxDelay then t.fn() else api.timers[#api.timers + 1] = t end
    end
  end
  for k, v in pairs(over or {}) do api[k] = v end
  return api
end

-- ctx like the one App provides, recording into db.
function H.ctx(ns, db, clock, api, settings)
  return {
    api = api or H.api(), now = clock.now, settings = settings or {},
    record = function(obs, opts) return ns.Session.observe(db, clock.now(), obs, opts) end,
    amend = function(key, data) return ns.Session.amendLast(db, clock.now(), key, data) end,
  }
end

function H.read(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("*a")
  f:close()
  return s
end

return H
