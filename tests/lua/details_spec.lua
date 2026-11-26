-- MOCKED tests for 0.3.5: the review window's export size wording, the grouping of instance enter/leave
-- lines, and what the tooltips and details panel say. Logic and wording only; how the game draws the
-- tooltips (and whether WoW Forever has quest tooltips) is on the in-game checklist (docs/testing.md).
local H = require("tests.lua.helper")

local function obs(t, type_, data, extra)
  local o = { t = t, seq = t, type = type_, certainty = "confirmed", data = data or {} }
  for k, v in pairs(extra or {}) do o[k] = v end
  return { t = t, seq = t, obs = o }
end
local SM = { instance = { name = "Example Abbey", type = "party", difficulty = "Normal", max_players = 5 } }

describe("export size wording", function()
  it("shows KB of the limit, amber from 400 KB and red past the limit", function()
    local D = H.load().details
    assert.equal("6.2 KB", D.kb(6349))
    assert.equal("512 KB", D.kb(524288))
    local text, level = D.sizeText(6349, 524288)
    assert.equal("export 6.2 KB of 512 KB", text); assert.equal("ok", level)
    assert.equal("warn", select(2, D.sizeText(400 * 1024, 524288)))
    text, level = D.sizeText(600 * 1024, 524288)
    assert.equal("over", level); assert.truthy(text:find("too large to export", 1, true))
    assert.equal("export size not worked out", (D.sizeText(nil, 524288)))
  end)

  it("matches the length of the real import code", function()
    local ns = H.load()
    local db = ns.Session.migrateStore(nil)
    local s = ns.Session.start(db, 1800000000, { client = {}, character = {} })
    ns.Session.observe(db, 1800000005,
      { type = "zone.enter", certainty = "confirmed", data = { zone = "Example Vale" } })
    local text = ns.Export.toText(s, {}, "0.3.5")
    assert.equal(#text, ns.Export.size(s, {}, "0.3.5"))
  end)
end)

describe("grouping instance enter/leave lines", function()
  it("shows a portal flicker as one row and keeps every line", function()
    local D = H.load().details
    local list = {
      obs(100, "instance.leave", SM), obs(101, "zone.enter", { zone = "Example Glades" }),
      obs(126, "instance.enter", SM), obs(126, "instance.leave", SM), obs(126, "instance.enter", SM),
      obs(126, "zone.enter", { zone = "Example Abbey" }),
      obs(168, "instance.enter", SM), obs(169, "instance.leave", SM), obs(169, "instance.enter", SM),
      obs(300, "instance.leave", SM),
    }
    local out = D.group(list)
    assert.equal(6, #out)
    assert.equal(3, #out[3].group)
    assert.equal("instance.enter", out[3].obs.type)  -- the last line of the run: where you ended up
    assert.equal(" |cffa89880[+2 enter/leave lines]|r", D.groupSuffix(out[3]))
    assert.equal(3, #out[5].group)
    assert.is_nil(out[6].group); assert.equal("", D.groupSuffix(out[6]))
    assert.equal(10, #list) -- the list it was given is unchanged
  end)

  it("doesn't group different instances or lines more than a second apart", function()
    local D = H.load().details
    local other = { instance = { name = "Example Keep" } }
    assert.equal(2, #D.group({ obs(1, "instance.enter", SM), obs(1, "instance.enter", other) }))
    assert.equal(2, #D.group({ obs(1, "instance.enter", SM), obs(3, "instance.leave", SM) }))
    assert.equal(2, #D.group({ obs(1, "zone.enter", { zone = "A" }), obs(1, "zone.enter", { zone = "A" }) }))
  end)
end)

describe("tooltips and the details panel", function()
  it("finds the items and the quest on an event", function()
    local D = H.load().details
    local loot = obs(1, "loot.seen", { items = { { item_id = 1, name = "Example Rags", count = 3 },
                                                { item_id = 2, count = 1 } } }).obs
    local items = D.items(loot)
    assert.equal(2, #items)
    assert.equal("Example Rags x3", D.itemLabel(items[1]))
    assert.equal("item 2 (name not loaded)", D.itemLabel(items[2]))
    local recv = obs(1, "item.received", { quest_id = 9, item_id = 7, name = "Example Cloak", count_delta = 1 }).obs
    assert.equal(1, #D.items(recv)); assert.is_nil(D.questId(recv)) -- an item event, even from a quest
    assert.equal(42, D.questId(obs(1, "quest.accepted", { quest_id = 42 }).obs))
    assert.is_nil(D.questId(obs(1, "quest.snapshot", { quests = {} }).obs))
    assert.is_nil(D.questId(obs(1, "zone.enter", { zone = "x" }).obs))
  end)

  it("says what was recorded, and 'not recorded' for what wasn't", function()
    local D = H.load().details
    local q = obs(1, "quest.accepted", { quest_id = 42, title = "Example Errand", level = 12 }).obs
    local tip = table.concat(D.tooltip(q), "\n")
    assert.truthy(tip:find("Level 12", 1, true))
    assert.truthy(tip:find("Objectives: not recorded", 1, true))
    assert.truthy(tip:find("Confirmed by the game", 1, true))
    local rows = D.lines(q)
    local function find(label) for _, r in ipairs(rows) do if r.label == label then return r.text end end end
    assert.equal("Example Errand", find("Quest"))
    assert.equal("not recorded", find("Objectives"))
    assert.is_nil(find("Summary")) -- optional fields that weren't recorded are left out, not invented
    local z = D.lines(obs(1, "zone.enter", {}).obs)
    assert.equal("Zone", z[1].label); assert.equal("not recorded", z[1].text)
  end)

  it("lists objectives, reward items and money as recorded", function()
    local D = H.load().details
    local q = obs(1, "quest.accepted", { title = "Example Errand", objectives = {
      { index = 1, text = "Example pelts: 2/6" }, { index = 2, text = "Talk to the warden", finished = true } } }).obs
    local texts = {}
    for _, r in ipairs(D.lines(q)) do texts[#texts + 1] = r.text end
    assert.truthy(table.concat(texts, "\n"):find("Talk to the warden (done)", 1, true))
    local offer = obs(1, "quest.rewards_offered", { quest_id = 5, title = "Example Errand",
      choices = { { item_id = 11, name = "Example Boots" }, { item_id = 12, name = "Example Gloves" } } }).obs
    local items = 0
    for _, r in ipairs(D.lines(offer)) do if r.item then items = items + 1 end end
    assert.equal(2, items)
    local done = D.lines(obs(1, "quest.turned_in", { title = "Example Errand", xp = 450, money_copper = 12345 }).obs)
    local money
    for _, r in ipairs(done) do if r.label == "Money" then money = r.text end end
    assert.equal("1 g 23 s 45 c", money)
  end)

  it("names the kind and the certainty in plain words", function()
    local D = H.load().details
    assert.equal("Loot", D.kind("loot.seen")); assert.equal("Other", D.kind("something.new"))
    local seen = obs(1, "loot.seen", { items = {} }, { certainty = "seen" }).obs
    assert.truthy(table.concat(D.tooltip(seen), "\n"):find("not proof", 1, true))
    local merged = obs(1, "zone.enter", { zone = "x" }, { repeats = 2 }).obs
    assert.truthy(table.concat(D.tooltip(merged), "\n"):find("Repeated 2 more times", 1, true))
  end)
end)
