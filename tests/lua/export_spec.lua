-- MOCKED: JSON, CRC-32, envelope, privacy defaults and deterministic output.
local H = require("tests.lua.helper")

describe("json", function()
  local ns
  before_each(function() ns = H.load() end)
  it("sorts keys and escapes characters that are unsafe in HTML or JavaScript", function()
    local out = ns.json.encode({ b = 1, a = "<x>&\226\128\168", c = ns.json.array({}) })
    assert.equal('{"a":"\\u003cx\\u003e\\u0026\\u2028","b":1,"c":[]}', out)
  end)
  it("refuses NaN and infinity", function()
    assert.has_error(function() ns.json.encode({ x = 0 / 0 }) end)
    assert.has_error(function() ns.json.encode({ x = math.huge }) end)
  end)
end)

describe("crc32", function()
  it("matches the standard check value", function()
    local ns = H.load()
    assert.equal(0xCBF43926, ns.crc32("123456789"))
    assert.equal(0, ns.crc32(""))
  end)
end)

local sample = require("tests.lua.export_spec_sample")

describe("export", function()
  it("leaves out the character name and realm unless the player opts in", function()
    local ns = H.load()
    local doc = ns.Export.build(sample(ns), {})
    assert.is_nil(doc.character.name); assert.is_nil(doc.character.realm)
    assert.equal("HUNTER", doc.character.class)
    assert.is_false(doc.consent.character_identity)
    local opted = ns.Export.build(sample(ns), { include_identity = true })
    assert.equal("Examplechar", opted.character.name)
  end)

  it("wraps the JSON in a checked envelope", function()
    local ns = H.load()
    local text = assert(ns.Export.toText(sample(ns), {}, "0.1.0"))
    local len, crc, body = text:match("^ACX1:(%d+):(%x%x%x%x%x%x%x%x):(.*)$")
    assert.equal(#body, tonumber(len))
    assert.equal(string.format("%08x", ns.crc32(body)), crc)
  end)

  it("produces byte-identical output to the committed fixture", function()
    local ns = H.load()
    local text = ns.Export.toText(sample(ns), {}, "0.1.0")
    local expected = H.read("tests/fixtures/valid_session.acx.txt"):gsub("%s+$", "")
    assert.equal(expected, text)
  end)

  it("refuses to export over the size limit instead of cutting it short", function()
    local ns = H.load()
    local s = sample(ns)
    for i = 1, 150 do
      s.notes[#s.notes + 1] = { id = 100 + i, t = 1, kind = "note", text = string.rep("z", 4000) }
    end
    local text, why = ns.Export.toText(s, {}, "0.1.0")
    assert.is_nil(text); assert.equal("too_large", why)
  end)
end)

describe("timeline wording", function()
  it("labels uncertain things as uncertain", function()
    local ns = H.load()
    assert.equal("Chose a reward: Test Blade (probably)",
      ns.describe.observation({ type = "quest.reward_selected", certainty = "inferred",
        data = { name = "Test Blade" } }))
    assert.equal("Encounter ended: X, result unknown (uncertain)",
      ns.describe.observation({ type = "encounter.end", certainty = "uncertain", data = { name = "X" } }))
  end)
end)

describe("quest text consent at export", function()
  it("leaves the full quest text out unless the setting is on when exporting", function()
    local ns = H.load()
    local db = ns.Session.newStore()
    local s = ns.Session.start(db, 1800000000, {})
    ns.Session.observe(db, 1800000001, { type = "quest.accepted", certainty = "confirmed",
      data = { quest_id = 1, title = "Fixture Tale", description = "Synthetic speech." } })
    local off = ns.Export.build(s, {}, "0.3.0")
    assert.is_nil(off.observations[1].data.description)
    assert.is_false(off.consent.quest_text)
    local on = ns.Export.build(s, { record_quest_text = true }, "0.3.0")
    assert.equal("Synthetic speech.", on.observations[1].data.description)
    assert.equal("Synthetic speech.", s.observations[1].data.description) -- the saved record is untouched
  end)
end)

-- tests/lua/gen_fixture.lua reuses this sample to regenerate the fixture.
return { sample = sample }
