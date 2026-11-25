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
