-- Executes the actual binding module against recording stubs, not Hyprland.
local bindings = {}
local function dispatcher(name)
    return function(args) return { name = name, args = args } end
end
local function namespace(prefix)
    return setmetatable({}, { __index = function(_, key) return dispatcher(prefix .. key) end })
end
hl = {
    dsp = setmetatable({ window = namespace("window.") }, { __index = function(_, key) return dispatcher(key) end }),
    bind = function(key, action, opts)
        key = key:lower()
        assert(not bindings[key], "Duplicate shortcut: " .. key)
        assert(opts and opts.description and opts.description:find(" | ", 1, true), "Missing description: " .. key)
        bindings[key] = action
    end,
}
dofile("stow/desktop/.config/graphite/hypr/graphite/bindings.lua")
for _, direction in ipairs({"left", "right", "up", "down"}) do
    assert(bindings["super + " .. direction].args.direction == direction)
end
assert(bindings["super + shift + left"].name == "window.swap")
assert(bindings["super + shift + left"].args.prev == true)
assert(bindings["super + shift + right"].args.next == true)
assert(bindings["super + f1"].args:find("shortcuts.sh", 1, true))
assert(bindings["super + shift + v"].args:find("clipboard.sh", 1, true))
for i = 1, 10 do
    assert(bindings["super + " .. (i % 10)].args.workspace == i)
    assert(bindings["super + shift + " .. (i % 10)].args.workspace == i)
end
print("PASS: binding module executes, no duplicate shortcuts, all bindings described, focus/workspaces preserved, cycle swaps and reference added")
