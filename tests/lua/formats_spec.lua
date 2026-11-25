-- MOCKED: the readable export formats (Markdown, Text, JSON), file names and the link check.
local H = require("tests.lua.helper")
local sample = require("tests.lua.export_spec_sample")

local function render(ns, kind, s, settings)
  return ns.ExportFormats.render(kind, s or sample(ns), settings or {}, "0.2.4")
end

describe("readable formats", function()
  local ns
  before_each(function() ns = H.load() end)

  it("leaves out the character name and realm unless the player opts in", function()
    for _, kind in ipairs({ "markdown", "text", "json" }) do
      local out = assert(render(ns, kind))
      assert.is_nil(out:find("Examplechar", 1, true), kind)
      assert.is_nil(out:find("Example Realm", 1, true), kind)
      local opted = assert(render(ns, kind, nil, { include_identity = true }))
      assert.truthy(opted:find("Examplechar", 1, true), kind)
    end
  end)

  it("says the log is player-provided and not game-verified", function()
    assert.truthy(render(ns, "markdown"):find("Not game-verified", 1, true))
    assert.truthy(render(ns, "text"):find("Not game-verified", 1, true))
    assert.truthy(render(ns, "json"):find('"self_reported": true', 1, true))
  end)

  it("writes Markdown with the title, timeline and notes", function()
    local md = render(ns, "markdown")
    assert.truthy(md:match("^# Synthetic evening\n"))
    assert.truthy(md:find("## Timeline", 1, true))
    assert.truthy(md:find("Turned in: Synthetic Quest", 1, true) or md:find("Synthetic Quest", 1, true))
    assert.truthy(md:find("## Notes", 1, true))
    assert.truthy(md:find("We nearly wiped on the second pull.", 1, true))
  end)

  it("never shortens notes", function()
    local s = sample(ns)
    local long = string.rep("A long synthetic note. ", 300)
    s.notes[#s.notes + 1] = { id = 99, t = s.started_at + 30, kind = "note", text = long }
    for _, kind in ipairs({ "markdown", "text" }) do
      assert.truthy(render(ns, kind, s):find(long, 1, true), kind)
    end
  end)

  it("shows paused time instead of hiding it", function()
    local s = sample(ns)
    table.insert(s.segments, 2, { kind = "paused", start = s.started_at + 10, finish = s.started_at + 20,
      reason = "player" })
    assert.truthy(render(ns, "text", s):find("Paused until", 1, true))
  end)

  it("makes JSON that is the same data as the import code, indented", function()
    local code = assert(ns.Export.toText(sample(ns), {}, "0.2.4"))
    local pretty = render(ns, "json")
    assert.is_nil(pretty:find("^ACX1"))
    assert.truthy(pretty:find('\n  "format": "adventure-chronicler.session"', 1, true))
    -- Removing the indentation gives back exactly the compact body.
    local body = code:match("^ACX1:%d+:%x+:(.*)$")
    local squashed = pretty:gsub("\n%s*", ""):gsub('": ', '":')
    assert.equal(body, squashed)
  end)

  it("keeps the import code unchanged", function()
    assert.equal(ns.Export.toText(sample(ns), {}, "0.2.4"), (render(ns, "code")))
  end)

  it("suggests lowercase file names with underscores", function()
    local _, name = render(ns, "markdown")
    assert.truthy(name:match("^adventure_%d%d%d%d%-%d%d%-%d%d_synthetic_evening%.md$"), name)
    local _, j = render(ns, "json"); assert.truthy(j:match("%.json$"))
    local _, c = render(ns, "code"); assert.truthy(c:match("_import_code%.txt$"))
    local s = sample(ns); s.title = ""
    local _, u = render(ns, "text", s); assert.truthy(u:match("_untitled%.txt$"), u)
    s.title = "Deadmines!! / with friends"
    local _, w = render(ns, "text", s); assert.truthy(w:match("_deadmines_with_friends%.txt$"), w)
  end)
end)

describe("quest detail in files", function()
  it("lists objectives as recorded in the Markdown timeline", function()
    local md = render(H.load(), "markdown")
    assert.truthy(md:find("Accepted Synthetic Quest (1 objective). Objectives as recorded: Fixture Wolf slain: 0/8",
      1, true))
    assert.truthy(md:find("Progress on Synthetic Quest: Fixture Wolf slain: 8/8 (done)", 1, true))
  end)
end)
