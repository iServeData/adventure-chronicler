-- MOCKED tests for 0.3.4: the Options list, the loot recording filter, the review Filter, Report a problem
-- and the What's new text. They check logic and wording only; how the windows look and whether the game's
-- loot window returns these values is on the in-game checklist (docs/testing.md).
local H = require("tests.lua.helper")

describe("options list", function()
  it("has categories A-Z and every setting in one of them", function()
    local ns = H.load()
    local cats = ns.options.CATEGORIES
    local sorted = { unpack(cats) }
    table.sort(sorted)
    assert.same(sorted, cats)
    local known = {}
    for _, c in ipairs(cats) do known[c] = true end
    for _, o in ipairs(ns.options.LIST) do assert.truthy(known[o.cat], o.key) end
  end)

  it("searches labels, explanations and categories, in any case", function()
    local ns = H.load()
    local keys = {}
    for _, o in ipairs(ns.options.search("QUEST")) do keys[o.key] = true end
    assert.truthy(keys.loot_skip_quest); assert.truthy(keys.record_quest_text)
    assert.same({}, ns.options.search("   "))
    assert.same({}, ns.options.search("no such words"))
  end)

  it("puts a category back to its defaults", function()
    local ns = H.load()
    local settings = { record_personal_loot = true, loot_skip_trade = true, record_pvp = false }
    local defaults = { record_personal_loot = false, loot_skip_trade = false, record_pvp = true }
    ns.options.reset(settings, defaults, ns.options.inCategory("Loot"))
    assert.is_false(settings.record_personal_loot); assert.is_false(settings.loot_skip_trade)
    assert.is_false(settings.record_pvp) -- another category: unchanged
  end)

  it("names the quality choices plainly", function()
    local ns = H.load()
    assert.equal("All qualities", ns.options.qualityChoiceLabel(0, true))
    assert.equal("Uncommon and better", ns.options.qualityChoiceLabel(2, true))
    assert.equal("Epic only", ns.options.qualityChoiceLabel(4, true))
  end)
end)

describe("loot recording filter", function()
  local function lootApi(items)
    return H.api({
      GetNumLootItems = function() return #items end,
      GetLootSlotLink = function(i)
        return "|cffffffff|Hitem:" .. items[i].id .. "::|h[" .. items[i].name .. "]|h|r"
      end,
      GetLootSlotInfo = function(i) return nil, nil, 1, nil, items[i].quality, false, items[i].quest end,
      GetItemInfoInstant = function(id)
        for _, it in ipairs(items) do if it.id == id then return id, nil, nil, nil, nil, it.class end end
      end,
    })
  end
  local ITEMS = {
    { id = 101, name = "Example Rags", quality = 0, class = 15 },
    { id = 102, name = "Example Linen", quality = 1, class = 7 },
    { id = 103, name = "Example Bracers", quality = 2, class = 4 },
    { id = 104, name = "Example Quest Token", quality = 1, quest = true, class = 12 },
    { id = 105, name = "Example Mystery", quality = nil, class = nil },
  }

  local function record(settings)
    local ns = H.load()
    local clock = H.clock()
    local db = ns.Session.migrateStore(nil)
    ns.Session.start(db, clock.now(), { client = {}, character = {} })
    settings.record_personal_loot = true
    local ctx = H.ctx(ns, db, clock, lootApi(ITEMS), settings)
    ns.capture.loot.reset()
    ns.capture.loot.onReady(ctx)
    local s = ns.Session.active(db)
    local ids = {}
    for _, o in ipairs(s.observations) do
      if o.type == "loot.seen" then for _, it in ipairs(o.data.items) do ids[#ids + 1] = it.item_id end end
    end
    return ids
  end

  it("records everything by default", function()
    assert.same({ 101, 102, 103, 104, 105 }, record({}))
  end)

  it("leaves out lower qualities, trade goods and junk; quest items follow their own box", function()
    assert.same({ 103, 104, 105 }, record({ loot_min_quality = 2 }))
    assert.same({ 101, 103, 104, 105 }, record({ loot_skip_trade = true }))
    assert.same({ 102, 103, 104, 105 }, record({ loot_skip_junk = true }))
    assert.same({ 101, 102, 103, 105 }, record({ loot_skip_quest = true }))
  end)

  it("keeps an item when the game doesn't say its quality or type", function()
    local ids = record({ loot_min_quality = 4, loot_skip_trade = true })
    assert.same({ 104, 105 }, ids)
  end)

  it("records nothing when every item is left out", function()
    local ns = H.load()
    local clock = H.clock()
    local db = ns.Session.migrateStore(nil)
    ns.Session.start(db, clock.now(), { client = {}, character = {} })
    local ctx = H.ctx(ns, db, clock, lootApi({ ITEMS[1] }), { record_personal_loot = true, loot_skip_junk = true })
    ns.capture.loot.reset()
    ns.capture.loot.onReady(ctx)
    for _, o in ipairs(ns.Session.active(db).observations) do assert.not_equal("loot.seen", o.type) end
  end)
end)

describe("review filter", function()
  local function entries()
    return {
      { t = 1, seq = 1, obs = { type = "zone.enter", data = {} } },
      { t = 2, seq = 2, obs = { type = "loot.seen", data = { items = { { item_id = 1 }, { item_id = 2 } } } } },
      { t = 3, seq = 3, obs = { type = "loot.seen", data = { items = { { item_id = 3 } } } } },
      { t = 4, seq = 4, obs = { type = "item.received", data = { item_id = 3 } } },
      { t = 5, seq = 0, note = { kind = "note", text = "x" } },
      { t = 6, seq = 5, obs = { type = "player.death", data = {} } },
    }
  end
  local QUALITY = { [1] = 0, [2] = 3 } -- item 3 unknown

  it("shows everything with no filter, and counts filters", function()
    local ns = H.load()
    local F = ns.reviewfilter
    local st = F.new()
    local shown, total = F.apply(entries(), st, function(id) return QUALITY[id] end)
    assert.equal(6, #shown); assert.equal(6, total); assert.equal(0, F.count(st))
  end)

  it("hides types, qualities and seen loot that was received", function()
    local ns = H.load()
    local F = ns.reviewfilter
    local st = F.new()
    st.types.Notes, st.types.Deaths = true, true
    assert.equal(4, #F.apply(entries(), st, function(id) return QUALITY[id] end))
    st = F.new(); st.qualities[0] = true
    assert.equal(6, #F.apply(entries(), st, function(id) return QUALITY[id] end)) -- item 2 is Rare: row stays
    st.qualities[3] = true
    assert.equal(5, #F.apply(entries(), st, function(id) return QUALITY[id] end))
    st.qualities.unknown = true
    assert.equal(3, #F.apply(entries(), st, function(id) return QUALITY[id] end))
    st = F.new(); st.hide_seen_received = true
    local shown = F.apply(entries(), st, function(id) return QUALITY[id] end)
    assert.equal(5, #shown)
    for _, e in ipairs(shown) do assert.not_equal(3, e.t) end
    assert.equal(1, F.count(st))
    F.clear(st); assert.equal(0, F.count(st))
  end)

  it("never changes the entries it's given", function()
    local ns = H.load()
    local list = entries()
    local st = ns.reviewfilter.new()
    st.types.Loot = true
    ns.reviewfilter.apply(list, st, function() return nil end)
    assert.equal(6, #list)
  end)
end)

describe("report a problem", function()
  local function info(over)
    local i = {
      version = "0.3.4", client = { version = "1.60.1", build = "00000", interface = 16001 },
      session = { state = "recording", recorded = 3 * 3600 }, mini_shown = false,
      settings = { record_personal_loot = true, record_pvp = false, minimap_button = true, loot_min_quality = 2 },
      last_error = nil, what = "",
    }
    for k, v in pairs(over or {}) do i[k] = v end
    return i
  end

  it("lists versions, state, settings and the last error, and nothing else", function()
    local ns = H.load()
    local text = ns.report.build(info({ what = "  It broke\nafter a reload  " }))
    local lines = {}
    for l in text:gmatch("[^\n]+") do lines[#lines + 1] = l end
    assert.equal(5, #lines)
    assert.equal("Adventure Chronicler 0.3.4 · WoW 1.60.1 (00000) · interface 16001", lines[1])
    assert.equal("Recording: recording (3 h) · mini recorder: closed · minimap button: on", lines[2])
    assert.truthy(lines[3]:find("on: loot, minimap", 1, true))
    assert.truthy(lines[3]:find("off: pvp", 1, true))
    assert.truthy(lines[3]:find("loot quality: Uncommon and better", 1, true))
    assert.equal("Last error the add-on caught: none", lines[4])
    assert.equal("What happened: It broke after a reload", lines[5])
  end)

  it("says when nothing was typed and no session is open", function()
    local ns = H.load()
    local text = ns.report.build(info({ session = false }))
    assert.truthy(text:find("Recording: no session open", 1, true))
    assert.truthy(text:find("What happened: (not filled in)", 1, true))
  end)

  it("removes colour codes from errors and says when one is shortened", function()
    local ns = H.load()
    assert.equal("x.lua:2: bad /value", ns.report.cleanError("x.lua:2: |cffff0000bad|r |value"))
    local long = ns.report.cleanError(string.rep("e", 300))
    assert.equal(ns.report.MAX_ERROR + #"... (shortened)", #long)
    assert.truthy(long:find("(shortened)", 1, true))
  end)
end)

describe("what's new", function()
  it("is built from changelog.toml, newest first, with every change", function()
    local ns = H.load()
    local list = ns.CHANGELOG
    assert.truthy(#list >= 2)
    assert.equal("0.3.7", list[1].version)
    for _, r in ipairs(list) do assert.truthy(#r.changes >= 1, r.version) end
  end)

  it("makes the text safe for a WoW font string", function()
    local ns = H.load()
    local fs = {}
    local loaded = assert(loadfile("addon/AdventureChronicler/ui/whatsnew.lua"))
    ns.ui = fs
    loaded("AdventureChronicler", ns)
    assert.equal("a || b", ns.ui.whatsnew.format("a | b"))
    assert.equal("use |cffffd100/ac link|r now", ns.ui.whatsnew.format("use `/ac link` now"))
    local sample = { version = "9.9.9", date = "2026-01-01", title = "Synthetic", changes = {
      { kind = "New", area = "Review", text = "A synthetic change." } } }
    assert.truthy(ns.ui.whatsnew.page(sample):find("New", 1, true))
  end)
end)
