-- MOCKED: session lifecycle, recovery, gaps, retention and limits.
local H = require("tests.lua.helper")

describe("session lifecycle", function()
  local ns, S, db, c
  before_each(function()
    ns = H.load(); S = ns.Session; db = S.newStore(); c = H.clock()
  end)

  it("starts, pauses, resumes and stops with honest segments", function()
    local s = assert(S.start(db, c.now(), { title = "Evening run" }))
    c.advance(60); assert(S.pause(db, c.now()))
    c.advance(30); assert(S.resume(db, c.now()))
    c.advance(90); assert(S.stop(db, c.now()))
    assert.equal("stopped", s.state)
    assert.is_nil(db.active_id)
    assert.equal(150, S.recordedSeconds(s, c.now()))
    local kinds = {}
    for _, seg in ipairs(s.segments) do kinds[#kinds + 1] = seg.kind end
    assert.same({ "recording", "paused", "recording" }, kinds)
  end)

  it("renames a session during recording without touching its observations", function()
    local s = assert(S.start(db, c.now(), { title = "" }))
    local before = #s.observations
    c.advance(5)
    assert.is_true(S.rename(s, c.now(), "  Evening run "))
    assert.equal("Evening run", s.title)
    assert.equal(c.now(), s.modified_at)
    assert.equal(before, #s.observations)
    assert.equal(0, s.counters.deleted_by_user)
    assert.same({ nil, "title_too_long" }, { S.rename(s, c.now(), string.rep("x", ns.limits.max_title_chars + 1)) })
    assert.equal("Evening run", s.title)
    assert.is_true(S.rename(s, c.now(), ""))
    assert.equal("", s.title)
  end)

  it("refuses invalid transitions", function()
    assert.same({ nil, "no_session" }, { S.pause(db, c.now()) })
    S.start(db, c.now())
    assert.same({ nil, "active" }, { S.start(db, c.now()) })
    assert.same({ nil, "not_paused" }, { S.resume(db, c.now()) })
  end)

  it("does not record while paused, except markers", function()
    S.start(db, c.now()); S.pause(db, c.now())
    assert.same({ nil, "not_recording" }, { S.observe(db, c.now(), { type = "zone.enter" }) })
    assert.equal("added", (S.observe(db, c.now(), { type = "marker.bookmark" }, { allow_paused = true })))
  end)

  it("treats a short gap as a reload and keeps recording", function()
    local s = S.start(db, c.now())
    c.advance(100); local last = c.now(); c.advance(20)
    local _, how = S.recover(db, c.now(), last)
    assert.equal("resumed", how)
    assert.equal("recording", s.state)
    assert.is_false(s.interrupted)
    assert.equal("reload", s.segments[2].reason)
  end)

  it("marks an offline gap as interrupted and pauses after a long one", function()
    local s = S.start(db, c.now())
    c.advance(100); local last = c.now(); c.advance(3600)
    local _, how, gap = S.recover(db, c.now(), last)
    assert.equal("auto_paused", how); assert.equal(3600, gap)
    assert.equal("paused", s.state); assert.is_true(s.interrupted)
    -- the gap is not counted as recorded time
    assert.equal(100, S.recordedSeconds(s, c.now()))
  end)

  it("records an unknown gap when there is no last-seen time", function()
    local s = S.start(db, c.now()); c.advance(50)
    local _, how = S.recover(db, c.now(), nil)
    assert.equal("auto_paused", how)
    assert.equal("unknown", s.segments[2].reason)
  end)

  it("never records negative time when the clock moves backwards", function()
    local s = S.start(db, c.now())
    S.recover(db, c.now() - 500, c.now())
    for _, seg in ipairs(s.segments) do
      if seg.finish then assert.is_true(seg.finish >= seg.start) end
    end
  end)

  it("keeps a paused session paused after a reload", function()
    local s = S.start(db, c.now()); S.pause(db, c.now()); local last = c.now(); c.advance(10)
    S.recover(db, c.now(), last)
    assert.equal("paused", s.state)
  end)
end)

describe("observations", function()
  local ns, S, db, c
  before_each(function() ns = H.load(); S = ns.Session; db = S.newStore(); c = H.clock(); S.start(db, c.now()) end)

  it("merges identical repeats inside the window and counts them", function()
    local o = { type = "zone.enter", key = "zone:1", data = { zone = "A" } }
    assert.equal("added", (S.observe(db, c.now(), o)))
    c.advance(5)
    assert.equal("merged", (S.observe(db, c.now(), o)))
    local s = S.active(db)
    assert.equal(1, #s.observations); assert.equal(1, s.observations[1].repeats)
    c.advance(120)
    assert.equal("added", (S.observe(db, c.now(), o)))
  end)

  it("does not merge when the data differ", function()
    S.observe(db, c.now(), { type = "x", key = "k", data = { a = 1 } })
    assert.equal("added", (S.observe(db, c.now(), { type = "x", key = "k", data = { a = 2 } })))
  end)

  it("flags out-of-order timestamps instead of reordering them", function()
    S.observe(db, c.now(), { type = "a" })
    local _, rec = S.observe(db, c.now() - 10, { type = "b" })
    assert.equal("earlier_than_previous", rec.clock_note)
    assert.equal(2, rec.seq)
  end)

  it("counts observations over the limit instead of losing them silently", function()
    local s = S.active(db)
    for i = 1, ns.limits.max_observations do S.observe(db, c.now(), { type = "t", data = { i = i } }) end
    assert.equal("dropped", (S.observe(db, c.now(), { type = "zone.enter" })))
    assert.equal(1, s.counters.dropped); assert.equal(1, s.counters.dropped_by_type["zone.enter"])
  end)

  it("rejects unknown certainty levels", function()
    assert.same({ nil, "invalid_certainty" }, { S.observe(db, c.now(), { type = "a", certainty = "maybe" }) })
  end)

  it("deletes one observation and counts it", function()
    local _, rec = S.observe(db, c.now(), { type = "a" })
    assert.is_true(S.deleteObservation(S.active(db), rec.seq, c.now()))
    assert.equal(0, #S.active(db).observations)
    assert.equal(1, S.active(db).counters.deleted_by_user)
  end)
end)

describe("notes", function()
  local ns, S, s, c
  before_each(function() ns = H.load(); S = ns.Session; c = H.clock(); s = S.start(S.newStore(), c.now()) end)

  it("keeps Unicode intact and counts characters, not bytes", function()
    local text = "Ragefire \226\128\148 caf\195\169 \240\159\144\137" -- em dash, accented e, emoji
    local n = assert(S.addNote(s, c.now(), text))
    assert.equal(text, n.text)
    assert.equal(17, ns.util.utf8len(n.text))
  end)

  it("accepts a note at exactly the limit and refuses one over it without truncating", function()
    local max = ns.limits.max_note_chars
    assert.truthy(S.addNote(s, c.now(), string.rep("\195\169", max)))
    local n, why, len, lim = S.addNote(s, c.now(), string.rep("a", max + 1))
    assert.is_nil(n); assert.equal("too_long", why); assert.equal(max + 1, len); assert.equal(max, lim)
    assert.equal(1, #s.notes)
  end)

  it("replaces invalid UTF-8 and strips UI escape codes", function()
    local n = S.addNote(s, c.now(), "|cffff0000red|r and |Hitem:123|h[Thing]|h \255 end")
    assert.equal("red and [Thing] \239\191\189 end", n.text)
  end)

  it("refuses an empty note but allows an empty bookmark label", function()
    assert.same({ nil, "empty" }, { S.addNote(s, c.now(), "   ") })
    assert.truthy(S.addNote(s, c.now(), "", "bookmark"))
  end)

  it("edits refuse over-limit text and keep the original", function()
    local n = S.addNote(s, c.now(), "first")
    assert.is_nil((S.editNote(s, c.now(), n.id, string.rep("x", ns.limits.max_note_chars + 1))))
    assert.equal("first", n.text)
  end)

  it("knows when notes were never exported", function()
    S.addNote(s, c.now(), "x")
    assert.is_true(S.hasUnexportedNotes(s))
    s.exported_at = c.now() + 1
    assert.is_false(S.hasUnexportedNotes(s))
  end)

  it("limits the number of notes", function()
    for i = 1, ns.limits.max_notes do assert.truthy(S.addNote(s, c.now(), "n" .. i)) end
    assert.same({ nil, "too_many" }, { S.addNote(s, c.now(), "one more") })
  end)
end)

describe("retention", function()
  it("asks before removing the oldest stopped session when full", function()
    local ns = H.load(); local S = ns.Session; local db = S.newStore(); local c = H.clock()
    local first
    for i = 1, ns.limits.max_sessions do
      local s = S.start(db, c.now()); first = first or s.id; S.stop(db, c.now()); c.advance(1)
      assert.truthy(s, i)
    end
    local ok, why, oldest = S.canStart(db)
    assert.is_false(ok); assert.equal("full", why); assert.equal(first, oldest)
    -- nothing was deleted automatically
    assert.equal(ns.limits.max_sessions, #db.order)
  end)

  it("repairs an inconsistent saved store without losing sessions", function()
    local ns = H.load(); local S = ns.Session
    local db = S.migrateStore({ sessions = { a = { started_at = 2 }, b = { started_at = 1 } },
      order = { "a", "a", "missing" }, active_id = "gone" })
    assert.same({ "a", "b" }, db.order); assert.is_nil(db.active_id)
    assert.same(S.newStore(), S.migrateStore("garbage"))
  end)
end)

-- MOCKED (0.3.6): continuing a stopped session.
describe("continuing a stopped session", function()
  local ns, S, db, c
  before_each(function()
    ns = H.load(); S = ns.Session; db = S.newStore(); c = H.clock()
  end)

  it("records again in the same session and keeps the stopped time as a pause", function()
    local s = assert(S.start(db, c.now(), { title = "Evening run" }))
    c.advance(600); S.stop(db, c.now())
    local stoppedAt = s.ended_at
    c.advance(3 * 3600 + 120)
    local again, gap = S.continue(db, c.now(), s.id)
    assert.equal(s, again); assert.equal(3 * 3600 + 120, gap)
    assert.equal("recording", s.state); assert.equal(s.id, db.active_id); assert.is_nil(s.ended_at)
    assert.same({ kind = "paused", start = stoppedAt, finish = c.now(), reason = "player" }, s.segments[2])
    assert.equal("recording", s.segments[3].kind); assert.is_nil(s.segments[3].finish)
    c.advance(60)
    assert.equal(660, S.recordedSeconds(s, c.now())) -- the stopped time is not counted as recorded
    assert.equal(1, s.continued)
    assert.is_false(s.interrupted) -- the player chose to stop; nothing was lost
    S.stop(db, c.now())
    assert.equal(1, #db.order) -- still one session, not a new one
  end)

  it("refuses when it can't, and says why", function()
    local a = assert(S.start(db, c.now(), {}))
    assert.same({ false, "not_stopped" }, { S.canContinue(db, a.id) })
    S.stop(db, c.now())
    local b = assert(S.start(db, c.now(), {}))
    assert.same({ false, "active" }, { S.canContinue(db, a.id) })
    assert.same({ nil, "active" }, { S.continue(db, c.now(), a.id) })
    S.stop(db, c.now())
    assert.same({ false, "not_found" }, { S.canContinue(db, "s-missing") })
    for i = 1, ns.limits.max_observations do a.observations[i] = { seq = i, t = 0, type = "zone.enter" } end
    assert.same({ false, "full" }, { S.canContinue(db, a.id) })
    assert.is_true(S.canContinue(db, b.id))
  end)

  it("never records negative time if the clock went backwards", function()
    local s = assert(S.start(db, c.now(), {}))
    c.advance(100); S.stop(db, c.now())
    c.advance(-50)
    local _, gap = S.continue(db, c.now(), s.id)
    assert.equal(0, gap)
    local p = s.segments[#s.segments - 1]
    assert.is_true(p.finish >= p.start)
  end)

  it("picks the most recently stopped session for /ac continue", function()
    local a = assert(S.start(db, c.now(), {})); c.advance(10); S.stop(db, c.now())
    local b = assert(S.start(db, c.now(), {})); c.advance(10); S.stop(db, c.now())
    assert.equal(b, S.lastStopped(db))
    c.advance(10); S.continue(db, c.now(), a.id); c.advance(10); S.stop(db, c.now())
    assert.equal(a, S.lastStopped(db))
  end)

  it("says how long it was stopped in short words", function()
    assert.equal("40s", S.shortDuration(40)); assert.equal("5m", S.shortDuration(300))
    assert.equal("2h 14m", S.shortDuration(2 * 3600 + 14 * 60)); assert.equal("1d 3h", S.shortDuration(27 * 3600))
  end)

  it("exports a continued session that the import checks accept", function()
    local s = assert(S.start(db, c.now(), { title = "Evening run" }))
    S.observe(db, c.now(), { type = "zone.enter", certainty = "confirmed", data = { zone = "Example Vale" } })
    c.advance(60); S.stop(db, c.now()); c.advance(600); S.continue(db, c.now(), s.id); c.advance(60)
    local doc = ns.Export.build(s, {}, "0.3.6")
    local kinds = {}
    for _, seg in ipairs(doc.session.segments) do kinds[#kinds + 1] = seg.kind .. ":" .. tostring(seg.reason) end
    assert.same({ "recording:null", "paused:player", "recording:null" }, kinds)
    assert.equal("recording", doc.session.state)
  end)
end)
