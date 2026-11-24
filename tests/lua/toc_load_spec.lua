-- MOCKED smoke test: loads every file in the .toc order against stub frames and drives the slash
-- commands end to end. It catches load-order and wiring mistakes; it says nothing about how the
-- real client draws the windows.
local H = require("tests.lua.helper")

local function stubObject()
  local o = {}
  return setmetatable(o, { __index = function(t, k)
    local f = function() return stubObject() end
    if k == "GetText" then f = function() return t._text or "" end end
    if k == "SetText" then f = function(_, v) t._text = v end end
    if k == "IsShown" then f = function() return t._shown end end
    if k == "Show" then f = function() t._shown = true end end
    if k == "Hide" then f = function() t._shown = false end end
    rawset(t, k, f)
    return f
  end })
end

local function withGame(fn)
  local saved = {}
  local fake = H.api()
  local events, printed = {}, {}
  local G = {
    CreateFrame = function()
      local f = stubObject()
      f.RegisterEvent = function(_, e) events[e] = true end
      f.SetScript = function(self, name, h) rawset(self, "_" .. name, h) end
      return f
    end,
    UIParent = fake.UIParent, UISpecialFrames = {}, GameTooltip = stubObject(), ChatFontNormal = {},
    DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) printed[#printed + 1] = m end },
    StaticPopupDialogs = {}, StaticPopup_Show = function() end, SlashCmdList = {},
    hooksecurefunc = function() end, C_Timer = { After = function() end, NewTicker = function() end },
    C_CVar = fake.C_CVar, InCombatLockdown = fake.InCombatLockdown, Screenshot = fake.Screenshot,
    GetBuildInfo = function() return "1.60.1", "00000", "", 16001 end, GetLocale = function() return "enUS" end,
    UnitClass = function() return "Hunter", "HUNTER" end, UnitName = function() return "Examplechar" end,
    UnitLevel = function() return 24 end, GetRealmName = function() return "Example Realm" end,
    time = function() return 1800000000 end, date = os.date, tinsert = table.insert,
  }
  for k, v in pairs(G) do saved[k] = rawget(_G, k); _G[k] = v end
  local ok, err = pcall(fn, events, printed)
  for k in pairs(G) do _G[k] = saved[k] end
  _G.AdventureChroniclerDB, _G.AdventureChroniclerCharDB = nil, nil
  if not ok then error(err, 0) end
end

describe("addon load (stubbed)", function()
  it("loads every .toc file and runs the commands", function()
    withGame(function(events, printed)
      local ns, frames = {}, {}
      local real = _G.CreateFrame
      _G.CreateFrame = function(...) local f = real(...); frames[#frames + 1] = f; return f end
      for line in io.lines("addon/AdventureChronicler/AdventureChronicler.toc") do
        if line ~= "" and not line:match("^##") then
          local path = "addon/AdventureChronicler/" .. line:gsub("\\", "/")
          assert(loadfile(path))("AdventureChronicler", ns)
        end
      end
      assert.truthy(events.QUEST_TURNED_IN); assert.truthy(events.ADDON_LOADED)
      assert.is_nil(events.COMBAT_LOG_EVENT_UNFILTERED); assert.is_nil(events.CHAT_MSG_SAY)
      local onEvent = rawget(frames[1], "_OnEvent")
      onEvent(frames[1], "ADDON_LOADED", "AdventureChronicler")
      onEvent(frames[1], "PLAYER_LOGIN")
      local slash = _G.SlashCmdList.ADVENTURECHRONICLER
      slash("start Synthetic test")
      slash("note A short synthetic note")
      slash("mark")
      slash("pause"); slash("resume"); slash("stop")
      local db = _G.AdventureChroniclerCharDB
      local s = db.sessions[db.order[1]]
      assert.equal("stopped", s.state); assert.equal(2, #s.notes)
      assert.is_false(_G.AdventureChroniclerDB.settings.include_identity)
      assert.is_false(_G.AdventureChroniclerDB.settings.record_personal_loot)
      assert.is_false(_G.AdventureChroniclerDB.settings.prompt_on_instance)
      slash("export")
      assert.truthy(s.exported_at)
      assert.truthy(#printed > 0)
    end)
  end)
end)
