-- Regenerates tests/fixtures/valid_session.acx.txt from the synthetic sample. Run from the repo root:
--   lua tests/lua/gen_fixture.lua
-- Review the diff before committing; the fixture is the contract the reference validator also checks.
package.path = "./?.lua;" .. package.path
_G.describe = function() end
local H = require("tests.lua.helper")
local sample = dofile("tests/lua/export_spec.lua").sample
local ns = H.load()
local text = assert(ns.Export.toText(sample(ns), {}, "0.1.0"))
local f = assert(io.open("tests/fixtures/valid_session.acx.txt", "wb"))
f:write(text, "\n")
f:close()
print("wrote " .. #text .. " bytes")
