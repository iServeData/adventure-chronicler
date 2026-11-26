-- MOCKED: the minimap button's angle maths only (no frames).
describe("minimap button position", function()
  local M
  setup(function()
    local ns = { ui = {} }
    assert(loadfile("addon/AdventureChronicler/ui/minimap.lua"))("AdventureChronicler", ns)
    M = ns.ui.minimap
  end)
  it("turns a cursor position into whole degrees", function()
    assert.equal(0, M.angle(0, 0, 10, 0))
    assert.equal(90, M.angle(0, 0, 0, 10))
    assert.equal(180, M.angle(0, 0, -10, 0))
    assert.equal(270, M.angle(0, 0, 0, -10))
    assert.equal(45, M.angle(5, 5, 15, 15))
  end)
  it("places the button on the edge for an angle", function()
    local x, y = M.offset(90, 80)
    assert.is_true(math.abs(x) < 1e-9); assert.is_true(math.abs(y - 80) < 1e-9)
    x, y = M.offset(nil, 80)  -- default 200 degrees: lower left
    assert.is_true(x < 0 and y < 0)
  end)
end)

-- MOCKED: what clicking the compass does and when the mini recorder shows (0.3.3), logic only.
describe("compass and mini recorder flow", function()
  local H = require("tests.lua.helper")
  local ns = H.load()
  _G.CreateFrame = _G.CreateFrame
    or function() return setmetatable({}, { __index = function() return function() end end }) end
  for _, f in ipairs({ "core/app.lua", "ui/indicator.lua" }) do
    assert(loadfile("addon/AdventureChronicler/" .. f))("AdventureChronicler", ns)
  end
  local A = ns.App
  it("opens the Adventure Recorder when nothing is recording", function()
    assert.equal("open_recorder", A.compassAction(false, false, false))
    assert.equal("close_recorder", A.compassAction(false, true, false))
  end)
  it("while recording: closes the big window, opens it from the mini recorder, or shows the mini recorder", function()
    assert.equal("close_recorder", A.compassAction(true, true, false))
    assert.equal("open_recorder", A.compassAction(true, false, true))
    assert.equal("show_mini", A.compassAction(true, false, false))
  end)
  it("shows the mini recorder only with a session, the big window closed and not closed with x", function()
    local I = ns.ui.indicator
    assert.is_false(I.visible(nil, false, false))
    assert.is_true(I.visible({}, false, false))
    assert.is_false(I.visible({}, true, false))
    assert.is_false(I.visible({}, false, true))
  end)
end)
