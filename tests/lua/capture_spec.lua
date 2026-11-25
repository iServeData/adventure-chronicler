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
