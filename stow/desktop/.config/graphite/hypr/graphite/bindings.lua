local base = os.getenv("HOME") .. "/.local/lib/graphite/"
local function run(key, command, opts) hl.bind(key, hl.dsp.exec_cmd(command), opts or {}) end
local function script(key, name, args, opts) run(key, '"' .. base .. name .. '" ' .. (args or ""), opts) end
run("SUPER + Return", 'kitty --config "' .. os.getenv("HOME") .. '/.config/graphite/kitty/kitty.conf"', { description = "Applications | Open Kitty" })
script("SUPER + E", "dolphin.sh", nil, { description = "Applications | Open Dolphin" })
run("SUPER + Space", 'fuzzel --config="' .. os.getenv("HOME") .. '/.config/graphite/fuzzel/fuzzel.ini"', { description = "Applications | Application launcher" })
hl.bind("SUPER + Q", hl.dsp.window.close(), { description = "Windows | Close window" })
hl.bind("SUPER + V", hl.dsp.window.float({ action = "toggle" }), { description = "Windows | Toggle floating" })
hl.bind("SUPER + F", hl.dsp.window.fullscreen({ action = "toggle", mode = "fullscreen" }), { description = "Windows | Toggle fullscreen" })
hl.bind("SUPER + J", hl.dsp.layout("togglesplit"), { description = "Windows | Toggle split" })
hl.bind("SUPER + P", hl.dsp.window.pseudo(), { description = "Windows | Toggle pseudo tiling" })
script("SUPER + L", "lock.sh", nil, { description = "Session | Lock screen" })
script("SUPER + SHIFT + V", "clipboard.sh", nil, { description = "Clipboard | Search clipboard history" })
script("SUPER + N", "quick-settings.sh", "notifications", { description = "Session | Notification center" })
run("SUPER + SHIFT + N", "swaync-client -d", { description = "Session | Toggle do not disturb" })
script("SUPER + Escape", "power-menu.sh", nil, { description = "Session | Power menu" })
script("Print", "screenshot.sh", "full", { description = "Capture | Full screenshot" })
script("SUPER + Print", "screenshot.sh", "region", { description = "Capture | Region screenshot" })
script("ALT + Print", "screenshot.sh", "window", { description = "Capture | Active window screenshot" })
script("SHIFT + Print", "screenshot.sh", "annotate", { description = "Capture | Annotate screenshot" })
script("SUPER + SHIFT + R", "record.sh", "toggle region", { description = "Capture | Record region / stop current recording" })
script("SUPER + CTRL + R", "record.sh", "toggle full", { description = "Capture | Record full screen / stop current recording" })
script("SUPER + ALT + R", "record.sh", "toggle window", { description = "Capture | Record active window / stop current recording" })
run("SUPER + O", "command -v obs >/dev/null && obs || notify-send 'OBS unavailable' 'Review the optional obs package group'", { description = "Applications | OBS Studio" })
for _, direction in ipairs({"left", "right", "up", "down"}) do
    hl.bind("SUPER + " .. direction, hl.dsp.focus({ direction = direction }), { description = "Windows | Focus " .. direction })
end
for i = 1, 10 do
    hl.bind("SUPER + " .. (i % 10), hl.dsp.focus({ workspace = i }), { description = "Workspaces | Focus workspace " .. i })
    hl.bind("SUPER + SHIFT + " .. (i % 10), hl.dsp.window.move({ workspace = i }), { description = "Workspaces | Move window to workspace " .. i })
end
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(), { mouse = true, description = "Windows | Drag window" })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true, description = "Windows | Resize window" })
script("XF86AudioRaiseVolume", "volume.sh", "up", {locked=true,repeating=true, description = "Media | Raise volume" })
script("XF86AudioLowerVolume", "volume.sh", "down", {locked=true,repeating=true, description = "Media | Lower volume" })
script("XF86AudioMute", "volume.sh", "mute", {locked=true, description = "Media | Toggle mute" })
script("XF86AudioMicMute", "volume.sh", "mic", {locked=true, description = "Media | Toggle microphone mute" })
script("XF86MonBrightnessUp", "brightness.sh", "up", {locked=true,repeating=true, description = "Display | Raise brightness" })
script("XF86MonBrightnessDown", "brightness.sh", "down", {locked=true,repeating=true, description = "Display | Lower brightness" })
run("XF86AudioPlay", "command -v playerctl >/dev/null && playerctl play-pause || notify-send 'Media control unavailable' 'Check playerctl and an active media player'", {locked=true, description = "Media | Play or pause" })
run("XF86AudioPause", "command -v playerctl >/dev/null && playerctl play-pause || notify-send 'Media control unavailable' 'Check playerctl and an active media player'", {locked=true, description = "Media | Play or pause" })
run("XF86AudioNext", "command -v playerctl >/dev/null && playerctl next || notify-send 'Media control unavailable' 'Check playerctl and an active media player'", {locked=true, description = "Media | Next track" })
run("XF86AudioPrev", "command -v playerctl >/dev/null && playerctl previous || notify-send 'Media control unavailable' 'Check playerctl and an active media player'", {locked=true, description = "Media | Previous track" })

script("SUPER + SHIFT + P", "quick-settings.sh", "displays", { description = "Display | Display arrangement" })
script("XF86Display", "quick-settings.sh", "displays", { description = "Display | Display arrangement" })

-- Native cycle swaps stay on this workspace; directional swaps can cross monitors.
hl.bind("SUPER + SHIFT + left", hl.dsp.window.swap({ prev = true }), { description = "Windows | Swap with previous window on workspace" })
hl.bind("SUPER + SHIFT + right", hl.dsp.window.swap({ next = true }), { description = "Windows | Swap with next window on workspace" })
script("SUPER + F1", "shortcuts.sh", nil, { description = "Help | Search keyboard shortcuts" })
