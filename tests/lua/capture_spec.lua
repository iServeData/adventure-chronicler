-- MOCKED: capture modules against a fake game API.
local H = require("tests.lua.helper")

local function setup(settings)
  local ns = H.load()
  local db = ns.Session.newStore()
  local c = H.clock()
  ns.Session.start(db, c.now())
  local api = H.api()
  local ctx = H.ctx(ns, db, c, api, settings)
  for _, m in pairs(ns.capture) do m.reset() end
  return ns, db, c, api, ctx
end

local function types(db)
  local out = {}
  for _, o in ipairs(db.sessions[db.active_id].observations) do out[#out + 1] = o.type end
  return out
end

local function questApi(api, q)
  api.GetQuestID = function() return q.id end
  api.GetTitleText = function() return q.title end
  api.GetNumQuestChoices = function() return #(q.choices or {}) end
  api.GetNumQuestRewards = function() return #(q.rewards or {}) end
  api.GetQuestItemInfo = function(kind, i)
    local it = (kind == "choice" and q.choices or q.rewards)[i]
    return it.name, nil, it.count or 1, nil, nil, it.id
  end
end

describe("quest rewards", function()
  it("records a turn-in with no reward choice", function()
    local ns, db, _, api, ctx = setup()
    questApi(api, { id = 101, title = "Synthetic Quest" })
    ns.capture.quests.onComplete(ctx)
    ns.capture.quests.onGetQuestReward(ctx, 0)
    ns.capture.quests.onTurnedIn(ctx, 101, 250, 100)
    assert.same({ "quest.rewards_offered", "quest.turned_in" }, types(db))
  end)

  it("treats seeing choices as seen and the click as an inference, never as received", function()
    local ns, db, c, api, ctx = setup()
    questApi(api, { id = 102, title = "Choose Wisely", choices = { { id = 9001, name = "Test Blade" },
      { id = 9002, name = "Test Staff" } } })
    ns.capture.quests.onComplete(ctx)
    ns.capture.quests.onGetQuestReward(ctx, 2)
    ns.capture.quests.onTurnedIn(ctx, 102)
    local obs = db.sessions[db.active_id].observations
    assert.equal("seen", obs[1].certainty); assert.equal(2, #obs[1].data.choices)
    assert.equal("inferred", obs[2].certainty); assert.equal(9002, obs[2].data.item_id)
    assert.equal(3, #obs) -- no item.received until the bags actually change
    api.bags[9002] = 1; c.advance(1)
    ns.capture.quests.onBags(ctx)
    assert.equal("item.received", obs[4].type); assert.equal("inferred", obs[4].certainty)
  end)

  it("leaves a cancelled reward panel as offered only", function()
    local ns, db, _, api, ctx = setup()
    questApi(api, { id = 103, choices = { { id = 1, name = "A" } } })
    ns.capture.quests.onComplete(ctx)
    ns.capture.quests.onFinished(ctx)
    assert.same({ "quest.rewards_offered" }, types(db))
  end)

  it("uses the final choice when the player changes selection before completing", function()
    local ns, db, _, api, ctx = setup()
    questApi(api, { id = 104, choices = { { id = 1, name = "A" }, { id = 2, name = "B" } } })
    ns.capture.quests.onComplete(ctx)
    ns.capture.quests.onGetQuestReward(ctx, 1)
    local sel = db.sessions[db.active_id].observations[2]
    assert.equal(1, sel.data.item_id)
  end)

  it("merges a repeated QUEST_COMPLETE for the same panel", function()
    local ns, db, _, api, ctx = setup()
    questApi(api, { id = 105, choices = { { id = 1, name = "A" } } })
    ns.capture.quests.onComplete(ctx); ns.capture.quests.onComplete(ctx)
    local obs = db.sessions[db.active_id].observations
    assert.equal(1, #obs); assert.equal(1, obs[1].repeats)
  end)

  it("keeps rapid turn-ins separate", function()
    local ns, db, _, api, ctx = setup()
    for id = 201, 203 do
      questApi(api, { id = id, title = "Q" .. id })
      ns.capture.quests.onComplete(ctx); ns.capture.quests.onGetQuestReward(ctx, 0)
      ns.capture.quests.onTurnedIn(ctx, id)
    end
    local turned = 0
    for _, t in ipairs(types(db)) do if t == "quest.turned_in" then turned = turned + 1 end end
    assert.equal(3, turned)
  end)

  it("keeps the item ID when the item name is not cached yet", function()
    local ns, db, _, api, ctx = setup()
    local requested
    api.C_Item.RequestLoadItemDataByID = function(id) requested = id end
    questApi(api, { id = 106, choices = { { id = 7777, name = "" } } })
    ns.capture.quests.onComplete(ctx)
    local ch = db.sessions[db.active_id].observations[1].data.choices[1]
    assert.equal(7777, ch.item_id); assert.is_true(ch.name_pending); assert.equal(7777, requested)
  end)
end)

describe("zones, instances and encounters", function()
  it("records entering an instance without inferring completion", function()
    local ns, db, _, api, ctx = setup()
    api.GetInstanceInfo = function() return "Synthetic Depths", "party", 1, "Normal", 5, 0, false, 9999 end
    api.GetRealZoneText = function() return "Synthetic Depths" end
    ns.capture.zones.check(ctx)
    ns.capture.encounters.onEnd(ctx, 55, "Test Boss", 1, 5, 1)
    assert.same({ "instance.enter", "zone.enter", "encounter.end" }, types(db))
    for _, o in ipairs(db.sessions[db.active_id].observations) do
      assert.is_nil(o.data.cleared); assert.is_nil(o.data.completed)
    end
  end)

  it("logs one arrival when a flight path switches the map but not the zone", function()
    local ns, db, _, api, ctx = setup()
    local map = 1443
    api.C_Map = { GetBestMapForUnit = function() return map end,
                  GetMapInfo = function(id) return { name = id == 1414 and "Example Continent" or "Example Vale" } end }
    api.GetRealZoneText = function() return "Example Vale" end
    ns.capture.zones.check(ctx)
    map = 1414
    ns.capture.zones.check(ctx)
    assert.same({ "zone.enter" }, types(db))
  end)

  it("does not log a continent as an arrival while travelling between zones", function()
    local ns, db, _, api, ctx = setup()
    local map, zone = 1443, "Example Vale"
    api.C_Map = { GetBestMapForUnit = function() return map end,
                  GetMapInfo = function(id)
                    if id == 1415 then return { name = "Example Continent", mapType = 2 } end
                    return { name = id == 1443 and "Example Vale" or "Example Coast", mapType = 3 }
                  end }
    api.GetRealZoneText = function() return zone end
    ns.capture.zones.check(ctx)
    map, zone = 1415, ""
    ns.capture.zones.check(ctx)
    map, zone = 1415, "Example Continent"
    ns.capture.zones.check(ctx)
    map, zone = 1443, "Example Vale"
    ns.capture.zones.check(ctx)
    map, zone = 1444, "Example Coast"
    ns.capture.zones.check(ctx)
    local zones = {}
    for _, o in ipairs(db.sessions[db.active_id].observations) do zones[#zones + 1] = o.data.zone end
    assert.same({ "Example Vale", "Example Coast" }, zones)
  end)

  it("records a wipe as not defeated and stores no secret values", function()
    local ns, db, _, api, ctx = setup()
    local SECRET = {}
    api.issecretvalue = function(v) return v == SECRET end
    ns.capture.encounters.onEnd(ctx, 56, SECRET, 1, 5, 0)
    local o = db.sessions[db.active_id].observations[1]
    assert.equal("wipe_or_reset", o.data.result); assert.is_nil(o.data.name)
    assert.equal("uncertain", o.certainty); assert.is_true(o.data.restricted_values)
  end)
end)

describe("pvp and deaths", function()
  it("records battleground entry, result and exit with no opponents", function()
    local ns, db, _, api, ctx = setup({ record_pvp = true })
    api.GetInstanceInfo = function() return "Synthetic Gulch", "pvp", 0, "", 10, 0, false, 489 end
    api.UnitFactionGroup = function() return "Horde" end
    ns.capture.pvp.check(ctx)
    ns.capture.pvp.result(ctx, 0)
    ns.capture.pvp.result(ctx, 0) -- second report is ignored
    api.GetInstanceInfo = function() return "World", "none" end
    ns.capture.pvp.check(ctx)
    assert.same({ "pvp.battleground_enter", "pvp.battleground_result", "pvp.battleground_leave" }, types(db))
    assert.equal("won", db.sessions[db.active_id].observations[2].data.outcome)
  end)

  it("logs one death when the client reports it twice, and a new death after coming back", function()
    local ns, db, _, api, ctx = setup({ record_pvp = true })
    local P = ns.capture.pvp
    P.dead = false
    api.GetRealZoneText = function() return "Example Vale" end
    local ghost = false
    api.UnitIsGhost = function() return ghost end
    P.events.PLAYER_DEAD(ctx); P.events.PLAYER_DEAD(ctx)
    ghost = true; P.events.PLAYER_ALIVE(ctx) -- released: still dead
    P.events.PLAYER_DEAD(ctx)
    ghost = false; P.events.PLAYER_UNGHOST(ctx)
    P.events.PLAYER_DEAD(ctx)
    P.events.PLAYER_ALIVE(ctx) -- resurrected on the spot
    P.events.PLAYER_DEAD(ctx)
    assert.same({ "player.death", "player.death", "player.death" }, types(db))
  end)

  it("records nothing when pvp recording is off", function()
    local ns, db, _, api, ctx = setup({ record_pvp = false })
    api.GetInstanceInfo = function() return "Synthetic Gulch", "pvp" end
    ns.capture.pvp.check(ctx); ns.capture.pvp.onDeath(ctx)
    assert.same({}, types(db))
  end)
end)

describe("loot", function()
  it("is off by default", function()
    local ns, db, _, api, ctx = setup({})
    api.GetNumLootItems = function() return 1 end
    api.GetLootSlotLink = function() return "|cffffffff|Hitem:123::|h[Thing]|h|r" end
    ns.capture.loot.onReady(ctx)
    assert.same({}, types(db))
    ctx.settings.record_personal_loot = true
    ns.capture.loot.onReady(ctx)
    local o = db.sessions[db.active_id].observations[1]
    assert.equal("seen", o.certainty); assert.equal(123, o.data.items[1].item_id)
  end)
end)

-- A fake quest log: entries are headers or quests { id, title, level, objectives = { {text, kind, done} } }.
local function questLog(api, entries)
  api.questSelection = 0
  api.GetNumQuestLogEntries = function() return #entries end
  api.GetQuestLogTitle = function(i)
    local e = entries[i]
    if e.header then return e.header, nil, nil, true end
    return e.title, e.level or 10, nil, false, false, e.complete and 1 or nil, nil, e.id
  end
  api.GetNumQuestLeaderBoards = function(i) return #(entries[i].objectives or {}) end
  api.GetQuestLogLeaderBoard = function(j, i)
    local o = entries[i].objectives[j]
    return o[1], o[2] or "monster", o[3] or false
  end
  api.GetQuestLogSelection = function() return api.questSelection end
  api.SelectQuestLogEntry = function(i) api.questSelection = i end
  api.GetQuestLogQuestText = function()
    local e = entries[api.questSelection]
    return e and e.description, e and e.summary
  end
  return entries
end

local function last(db) local obs = db.sessions[db.active_id].observations return obs[#obs] end

describe("quest log", function()
  it("records an accepted quest with its objectives and summary, but not the full text by default", function()
    local ns, db, _, api, ctx = setup()
    questLog(api, { { header = "Example Vale" },
      { id = 201, title = "Fixture Hunt", level = 12, summary = "Slay 8 Fixture Wolves.",
        description = "A long synthetic speech.", objectives = { { "Fixture Wolf slain: 0/8" } } } })
    api.questSelection = 1
    ns.capture.quests.onAccepted(ctx, 2, 201)
    local o = last(db)
    assert.equal("quest.accepted", o.type)
    assert.equal("Fixture Hunt", o.data.title)
    assert.equal("Slay 8 Fixture Wolves.", o.data.summary)
    assert.is_nil(o.data.description)
    assert.same({ index = 1, text = "Fixture Wolf slain: 0/8", type = "monster", finished = false,
                  fulfilled = 0, required = 8 }, o.data.objectives[1])
    assert.equal(1, api.questSelection) -- the player's own selection is put back
  end)

  it("keeps the full text only when the setting is on, and says when text was shortened", function()
    local ns, db, _, api, ctx = setup({ record_quest_text = true })
    questLog(api, { { id = 202, title = "Fixture Tale", summary = "Talk.", description = string.rep("x", 5000) } })
    ns.capture.quests.onAccepted(ctx, 202) -- one-argument form
    local o = last(db)
    assert.equal(4000, #o.data.description)
    assert.is_true(o.data.text_cut)
  end)

  it("records progress, merging changes in a row into one entry with the last count", function()
    local ns, db, c, api, ctx = setup()
    local log = questLog(api, { { id = 203, title = "Fixture Hunt", objectives = { { "Fixture Wolf slain: 0/8" } } } })
    ns.capture.quests.onLogUpdate(ctx) -- first reading: baseline only
    assert.same({}, types(db))
    for n = 1, 8 do
      c.advance(20)
      log[1].objectives[1] = { "Fixture Wolf slain: " .. n .. "/8", "monster", n == 8 }
      ns.capture.quests.onLogUpdate(ctx)
      ns.capture.quests.onLogUpdate(ctx) -- an update with no change adds nothing
    end
    assert.same({ "quest.progress" }, types(db))
    local o = last(db)
    assert.equal(8, o.data.fulfilled)
    assert.is_true(o.data.finished)
    assert.equal(7, o.data.updates)
    assert.equal(c.now(), o.data.last_t)
    assert.equal(1800000020, o.t) -- keeps the time of the first change
  end)

  it("starts a new progress entry when something else happened in between", function()
    local ns, db, _, api, ctx = setup()
    local log = questLog(api, { { id = 204, title = "Fixture Hunt", objectives = { { "Fixture Wolf slain: 0/8" } } } })
    ns.capture.quests.onLogUpdate(ctx)
    log[1].objectives[1] = { "Fixture Wolf slain: 1/8" }; ns.capture.quests.onLogUpdate(ctx)
    ctx.record({ type = "player.death", data = {} })
    log[1].objectives[1] = { "Fixture Wolf slain: 2/8" }; ns.capture.quests.onLogUpdate(ctx)
    assert.same({ "quest.progress", "player.death", "quest.progress" }, types(db))
  end)

  it("does not count a quest appearing in the log as progress", function()
    local ns, db, _, api, ctx = setup()
    local log = questLog(api, {})
    ns.capture.quests.onLogUpdate(ctx)
    log[1] = { id = 205, title = "New", objectives = { { "Fixture Crate: 2/3" } } }
    ns.capture.quests.onLogUpdate(ctx)
    assert.same({}, types(db))
  end)

  it("lists quests already in the log at Start, marked seen", function()
    local ns, db, _, api, ctx = setup()
    questLog(api, { { header = "Example Vale" }, { id = 206, title = "Fixture Errand", complete = true,
                    objectives = { { "Fixture Crate: 3/3", "object", true } } } })
    ns.capture.quests.snapshot(ctx)
    local o = last(db)
    assert.equal("quest.snapshot", o.type)
    assert.equal("seen", o.certainty)
    assert.equal(1, o.data.listed)
    assert.is_true(o.data.quests[1].complete)
    assert.equal("Quest log at start: 1 quest already in progress (seen)", ns.describe.observation(o))
  end)

  it("never fails when the quest log functions are missing", function()
    local ns, db, _, _, ctx = setup()
    ns.capture.quests.onAccepted(ctx, 207)
    ns.capture.quests.onLogUpdate(ctx)
    ns.capture.quests.snapshot(ctx)
    assert.same({ "quest.accepted" }, types(db))
  end)
end)
