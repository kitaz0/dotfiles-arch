-- Event only fires on compositor start, not configuration reload.
hl.on("hyprland.start", function()
    hl.exec_cmd('"' .. os.getenv("HOME") .. '/.local/lib/graphite/session-start.sh"')
end)
