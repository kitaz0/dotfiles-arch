-- Hyprland 0.56.2: Lua API, not hyprlang.
local root = os.getenv("HOME") .. "/.config/graphite/hypr/graphite/"
for _, name in ipairs({"appearance", "input", "monitors", "rules", "bindings", "autostart"}) do
    -- v0.56.2 tracks required modules for reload and clears their reload cache.
    require(root .. name .. ".lua")
end
