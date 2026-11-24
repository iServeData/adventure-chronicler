-- MOCKED: screenshot presets restore the exact previous interface state.
local H = require("tests.lua.helper")

local function setup()
  local ns = H.load()
  local db = ns.Session.newStore(); local c = H.clock()
  ns.Session.start(db, c.now())
  local api = H.api()
  local ctx = H.ctx(ns, db, c, api)
  ns.capture.screenshot.reset()
  return ns, db, api, ctx
end

describe("screenshots", function()
  it("as seen takes the shot without changing anything", function()
    local ns, db, api, ctx = setup()
    assert.is_true(ns.capture.screenshot.take(ctx, "as_seen"))
    assert.equal(1, api.shots); assert.equal(1, api.alpha)
    ns.capture.screenshot.finish(ctx, true)
    assert.equal("succeeded", db.sessions[db.active_id].observations[1].data.status)
  end)

  it("clean scene restores alpha and the exact previous nameplate values", function()
    local ns, _, api, ctx = setup()
    api.alpha = 0.8
    api.cvars = { nameplateShowEnemies = "1", nameplateShowFriends = "0" }
    ns.capture.screenshot.take(ctx, "clean_scene")
    assert.equal(0, api.alpha); assert.equal("0", api.cvars.nameplateShowEnemies)
    api.runTimers(1)
    assert.equal(1, api.shots)
    ns.capture.screenshot.finish(ctx, true)
    assert.equal(0.8, api.alpha)
    assert.same({ nameplateShowEnemies = "1", nameplateShowFriends = "0" }, api.cvars)
  end)

  it("refuses clean scene in combat", function()
    local ns, _, api, ctx = setup()
    api.combat = true
    assert.same({ nil, "in_combat" }, { ns.capture.screenshot.take(ctx, "clean_scene") })
    assert.equal(0, api.shots); assert.equal(1, api.alpha)
  end)

  it("restores even when the screenshot fails or never confirms", function()
    local ns, db, api, ctx = setup()
    ns.capture.screenshot.take(ctx, "clean_scene")
    api.runTimers() -- shot, then the timeout fires
    assert.equal(1, api.alpha); assert.equal("1", api.cvars.nameplateShowEnemies)
    assert.equal("unconfirmed", db.sessions[db.active_id].observations[1].data.status)
    assert.is_nil(ns.capture.screenshot.busy)
  end)

  it("queues the nameplate restore if combat starts, and applies it when combat ends", function()
    local ns, _, api, ctx = setup()
    ns.capture.screenshot.take(ctx, "clean_scene")
    api.combat = true
    ns.capture.screenshot.events.PLAYER_REGEN_DISABLED(ctx)
    assert.equal(1, api.alpha)            -- alpha is not protected and comes back at once
    assert.equal("0", api.cvars.nameplateShowEnemies)
    api.combat = false
    ns.capture.screenshot.events.PLAYER_REGEN_ENABLED(ctx)
    assert.equal("1", api.cvars.nameplateShowEnemies)
  end)

  it("refuses a second shot while one is in progress", function()
    local ns, _, _, ctx = setup()
    ns.capture.screenshot.take(ctx, "clean_scene")
    assert.same({ nil, "busy" }, { ns.capture.screenshot.take(ctx, "as_seen") })
  end)
end)
