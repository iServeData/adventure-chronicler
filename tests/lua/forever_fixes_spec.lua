-- MOCKED: the 0.3.2 fixes for WoW Forever, against a fake API modelled on what a real 0.3.0 log showed
-- (every loot window listed twice; no GetQuestLogTitle, only C_QuestLog; reward names not loaded yet).
-- All quests, items and text here are synthetic. Nothing here proves how the real client behaves.
local H = require("tests.lua.helper")

local function setup(settings)
  local ns = H.load()
  local db = ns.Session.newStore()
  local c = H.clock()
  ns.Session.start(db, c.now())
  local api = H.api()
  local ctx = H.ctx(ns, db, c, api, settings)
  ctx.fillItemName = function(id, name) return ns.Session.fillItemName(db, c.now(), id, name) end
  for _, m in pairs(ns.capture) do m.reset() end
  return ns, db, c, api, ctx
end

local function obs(db) return db.sessions[db.active_id].observations end

local function lootWindow(api, items)
  api.GetNumLootItems = function() return #items end
  api.GetLootSlotLink = function(i) return "|cffffffff|Hitem:" .. items[i][1] .. "::|h[" .. items[i][2] .. "]|h|r" end
  api.GetLootSlotInfo = function(i) return nil, nil, items[i][3] or 1 end
end

describe("loot windows on Forever", function()
  it("records a window once when the game reports it twice", function()
    local ns, db, c, api, ctx = setup({ record_personal_loot = true })
    lootWindow(api, { { 9101, "Fixture Hide" }, { 9102, "Fixture Cloth", 2 } })
    ns.capture.loot.onReady(ctx)
    ns.capture.loot.onReady(ctx) -- same moment, window still open
    c.advance(1); ns.capture.loot.onReady(ctx) -- one second later
    assert.equal(1, #obs(db))
    ns.capture.loot.onClosed()
    c.advance(1); ns.capture.loot.onReady(ctx) -- closed, but within 2 seconds: still the same window
    assert.equal(1, #obs(db))
  end)

  it("keeps separate windows, including the same items a little later", function()
    local ns, db, c, api, ctx = setup({ record_personal_loot = true })
    lootWindow(api, { { 9101, "Fixture Hide" } })
    ns.capture.loot.onReady(ctx); ns.capture.loot.onClosed()
    c.advance(5); ns.capture.loot.onReady(ctx); ns.capture.loot.onClosed()
    lootWindow(api, { { 9103, "Fixture Feather" } })
    c.advance(1); ns.capture.loot.onReady(ctx)
    assert.equal(3, #obs(db))
  end)
end)

-- A C_QuestLog-only quest log, as on Forever: no GetQuestLogTitle or GetNumQuestLogEntries globals.
local function modernLog(api, entries)
  api.selected = 0
  api.C_QuestLog = {
    GetNumQuestLogEntries = function() return #entries end,
    GetInfo = function(i)
      local e = entries[i]
      if e.header then return { title = e.header, isHeader = true, questLogIndex = i } end
      return { title = e.title, questID = e.id, level = e.level or 30, isHeader = false, questLogIndex = i }
    end,
    GetQuestObjectives = function(id)
      for _, e in ipairs(entries) do
        if e.id == id then
          local out = {}
          for _, o in ipairs(e.objectives or {}) do
            out[#out + 1] = { text = o[1], type = "monster", finished = o[2] == true,
                              numFulfilled = o[3], numRequired = o[4] }
          end
          return out
        end
      end
      return {}
    end,
    IsComplete = function(id) for _, e in ipairs(entries) do if e.id == id then return e.complete == true end end end,
    GetSelectedQuest = function() return api.selected end,
    SetSelectedQuest = function(id) api.selected = id end,
    GetTitleForQuestID = function(id) for _, e in ipairs(entries) do if e.id == id then return e.title end end end,
  }
  api.GetQuestLogQuestText = function()
    for _, e in ipairs(entries) do if e.id == api.selected then return e.description, e.summary end end
  end
  return entries
end

describe("quest log on Forever (C_QuestLog only)", function()
  it("records objectives and the summary when a quest is accepted, and keeps the player's selection", function()
    local ns, db, _, api, ctx = setup()
    modernLog(api, { { header = "Fixture Barrens" },
      { id = 9201, title = "Fixture Family", summary = "Find the fixture heirloom.",
        description = "A long synthetic speech.",
        objectives = { { "Fixture Heirloom: 0/1", false, 0, 1 } } },
      { id = 9202, title = "Fixture Errand" } })
    api.selected = 9202
    ns.capture.quests.onAccepted(ctx, 9201)
    local o = obs(db)[1]
    assert.equal("quest.accepted", o.type)
    assert.equal("Fixture Family", o.data.title)
    assert.equal("Find the fixture heirloom.", o.data.summary)
    assert.is_nil(o.data.description)
    assert.same({ index = 1, text = "Fixture Heirloom: 0/1", type = "monster", finished = false, fulfilled = 0,
                  required = 1 }, o.data.objectives[1])
    assert.equal(9202, api.selected)
  end)

  it("lists quests already in the log at Start and records progress", function()
    local ns, db, _, api, ctx = setup()
    local log = modernLog(api, { { id = 9203, title = "Fixture Wolves",
                                   objectives = { { "Fixture Wolf slain: 2/8", false, 2, 8 } } },
                                  { id = 9204, title = "Fixture Done", complete = true } })
    ns.capture.quests.snapshot(ctx)
    local snap = obs(db)[1]
    assert.equal("quest.snapshot", snap.type); assert.equal(2, snap.data.listed)
    assert.is_true(snap.data.quests[2].complete)
    log[1].objectives = { { "Fixture Wolf slain: 3/8", false, 3, 8 } }
    ns.capture.quests.onLogUpdate(ctx)
    local p = obs(db)[2]
    assert.equal("quest.progress", p.type); assert.equal(3, p.data.fulfilled)
  end)
end)

describe("objectives that reach the quest log after QUEST_ACCEPTED (0.3.3)", function()
  it("fills in empty fields from the next log updates, without adding entries", function()
    local ns, db, c, api, ctx = setup()
    local log = modernLog(api, { { id = 9211, title = "Fixture Crystal", summary = "Bring a fixture crystal." } })
    ns.capture.quests.onAccepted(ctx, 9211) -- the log has the quest but no objectives yet
    local o = obs(db)[1]
    assert.same({}, o.data.objectives)
    c.advance(1)
    log[1].objectives = { { "Fixture Crystal: 0/1", false, 0, 1 } }
    ns.capture.quests.onLogUpdate(ctx)
    assert.equal(1, #obs(db)) -- filled in place, not a second entry, and not counted as progress
    assert.equal("Fixture Crystal: 0/1", o.data.objectives[1].text)
    assert.equal("Bring a fixture crystal.", o.data.summary)
    assert.is_nil(ns.capture.quests.late[9211])
  end)

  it("fills in a quest the log didn't list yet, title from the log", function()
    local ns, db, c, api, ctx = setup()
    local entries = {}
    local log = modernLog(api, entries)
    api.C_QuestLog.GetTitleForQuestID = function() return nil end
    ns.capture.quests.onAccepted(ctx, 9212)
    local o = obs(db)[1]
    assert.is_nil(o.data.title)
    c.advance(2)
    log[1] = { id = 9212, title = "Fixture Late", objectives = { { "Fixture Shard: 0/3", false, 0, 3 } } }
    ns.capture.quests.onLogUpdate(ctx)
    assert.equal("Fixture Late", o.data.title); assert.equal(3, o.data.objectives[1].required)
  end)

  it("stops looking after the retry window and never invents objectives", function()
    local ns, db, c, api, ctx = setup()
    local log = modernLog(api, { { id = 9213, title = "Fixture Talk" } })
    ns.capture.quests.onAccepted(ctx, 9213)
    c.advance(ns.capture.quests.ACCEPT_RETRY + 1)
    ns.capture.quests.onLogUpdate(ctx)
    assert.is_nil(ns.capture.quests.late[9213])
    log[1].objectives = { { "Fixture Word: 0/1", false, 0, 1 } }
    ns.capture.quests.onLogUpdate(ctx)
    assert.same({}, obs(db)[1].data.objectives) -- too late: left as recorded
  end)

  it("doesn't retry when the objectives were there at once", function()
    local ns, _, _, api, ctx = setup()
    modernLog(api, { { id = 9214, title = "Fixture Ready", objectives = { { "Fixture Hide: 0/2", false, 0, 2 } } } })
    ns.capture.quests.onAccepted(ctx, 9214)
    assert.is_nil(ns.capture.quests.late[9214])
  end)
end)

describe("reward names that load later", function()
  it("fills in the name on the offer and on the recorded observations, for that item only", function()
    local ns, db, _, api, ctx = setup()
    local loaded = {}
    api.C_Item.RequestLoadItemDataByID = function() end
    api.C_Item.GetItemNameByID = function(id) return loaded[id] end
    api.GetQuestID = function() return 9301 end
    api.GetTitleText = function() return "Fixture Reward" end
    api.GetNumQuestChoices = function() return 2 end
    api.GetNumQuestRewards = function() return 0 end
    api.GetQuestItemInfo = function(_, i) return "", nil, 1, nil, nil, 9400 + i end
    ns.capture.quests.onComplete(ctx)
    ns.capture.quests.onGetQuestReward(ctx, 1)
    local offer, sel = obs(db)[1], obs(db)[2]
    assert.is_true(offer.data.choices[1].name_pending)
    ns.capture.quests.onItemInfo(ctx, 9401, true) -- not loaded yet: nothing changes
    assert.is_true(offer.data.choices[1].name_pending)
    loaded[9401] = "Fixture Boots"
    ns.capture.quests.onItemInfo(ctx, 9401, true)
    assert.equal("Fixture Boots", offer.data.choices[1].name); assert.is_nil(offer.data.choices[1].name_pending)
    assert.equal("Fixture Boots", sel.data.name)
    assert.is_true(offer.data.choices[2].name_pending) -- the other item stays pending
    loaded[9999] = "Unrelated"
    ns.capture.quests.onItemInfo(ctx, 9999, true) -- an item nobody asked about: ignored
    assert.equal(2, #obs(db))
  end)
end)
