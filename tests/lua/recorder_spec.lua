-- MOCKED tests for the recorder window's wording and recent-entry list. They check the text the
-- window shows; how the window looks in the real client is covered by the in-game checklist.
local H = require("tests.lua.helper")

local function session()
  return {
    state = "recording", interrupted = false,
    observations = {
      { seq = 1, t = 100, type = "zone.enter", certainty = "confirmed", data = { zone = "Example Vale" } },
      { seq = 2, t = 200, type = "instance.enter", certainty = "confirmed",
        data = { instance = { name = "Synthetic Depths" } } },
      { seq = 3, t = 300, type = "encounter.end", certainty = "confirmed",
        data = { name = "Test Boss", result = "success" } },
      { seq = 4, t = 400, type = "marker.bookmark", certainty = "confirmed", data = { note_id = "n1" } },
    },
    notes = { { id = "n1", t = 400, kind = "bookmark", text = "First attempt" } },
  }
end

describe("recorder window text", function()
  it("shows the newest three entries, oldest first, with the bookmark once", function()
    local ns = H.load()
    local r = ns.describe.recent(session(), 3)
    assert.equal(3, #r)
    assert.equal("Entered Synthetic Depths", r[1].text)
    assert.equal("Encounter ended: Test Boss, defeated", r[2].text)
    assert.equal("Bookmark: First attempt", r[3].text)
    assert.equal(ns.describe.ICON.bookmark, r[3].icon)
  end)

  it("never says a dungeon was cleared", function()
    local ns = H.load()
    for _, e in ipairs(ns.describe.recent(session(), 10)) do
      assert.is_nil(e.text:lower():find("clear")); assert.is_nil(e.text:lower():find("complete"))
    end
  end)

  it("handles an empty session and unknown types", function()
    local ns = H.load()
    assert.same({}, ns.describe.recent({ observations = {}, notes = {} }, 3))
    assert.equal(ns.describe.ICON.other, ns.describe.iconFor("something.new"))
  end)

  it("states the recording status plainly", function()
    local ns = H.load()
    assert.same({ "gray", "Not recording" }, { ns.describe.status(nil) })
    assert.same({ "green", "Recording locally" }, { ns.describe.status({ state = "recording" }) })
    assert.same({ "yellow", "Paused (interrupted)" }, { ns.describe.status({ state = "paused", interrupted = true }) })
    assert.same({ "gray", "Stopped" }, { ns.describe.status({ state = "stopped" }) })
  end)
end)
