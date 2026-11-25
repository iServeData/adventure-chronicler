-- Shared synthetic session for the export tests (and tests/lua/gen_fixture.lua).
local H = require("tests.lua.helper")

local function sample(ns)
  local S = ns.Session
  local db = S.newStore()
  local c = H.clock(1800000000)
  local s = S.start(db, c.now(), { title = "Synthetic evening",
    client = { flavor = "forever", version = "1.60.1", build = "00000", interface = 16001, locale = "enUS" },
    character = { name = "Examplechar", realm = "Example Realm", class = "HUNTER", level = 24 } },
    function() return 1 end)
  S.observe(db, c.now(), { type = "zone.enter", key = "zone:1", data = { map_id = 1, zone = "Example Vale" } })
  c.advance(120)
  S.observe(db, c.now(), { type = "quest.turned_in", data = { quest_id = 101, title = "Synthetic Quest" } })
  S.addNote(s, c.now(), "We nearly wiped on the second pull.")
  c.advance(60)
  S.stop(db, c.now())
  return s
end

return sample
