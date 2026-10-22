-- Development regression only: execute the actual monitor module with a stub API.
-- From the project directory: lua docs/test-monitors.lua
local rules = {}
hl = { monitor = function(rule) rules[#rules + 1] = rule end }
os.getenv = function() error("Monitor defaults must not depend on environment discovery") end
dofile("stow/desktop/.config/graphite/hypr/graphite/monitors.lua")
assert(#rules == 1)
assert(rules[1].output == "" and rules[1].mode == "preferred")
assert(rules[1].position == "auto" and rules[1].scale == "auto")
print("PASS: native monitor defaults need no discovery environment")
