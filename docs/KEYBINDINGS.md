# Keyboard and mouse reference

Super is the Windows/logo key. These are the complete generated compositor shortcuts.

| Shortcut | Action |
| --- | --- |
| Super+Return | Kitty using the current login shell |
| Super+Space | Fuzzel application launcher |
| Super+E | Dolphin |
| Super+O | OBS Studio |
| Super+Q | Close focused window |
| Super+V | Toggle floating |
| Super+F | Toggle fullscreen |
| Super+J | Toggle dwindle split direction |
| Super+P | Toggle pseudotiling |
| Super+Left/Right/Up/Down | Focus window in that direction |
| Super+Shift+Left/Right | Swap with previous/next window in this workspace (cycle order, not geometric direction) |
| Super+F1 | Search categorized live keyboard shortcuts; Escape closes |
| Super+1…9, Super+0 | Workspaces 1…9, 10 |
| Super+Shift+1…9, Super+Shift+0 | Move focused window to workspace 1…9, 10 |
| Super+left-button drag | Move floating window |
| Super+right-button drag | Resize window |
| Super+L | Lock |
| Super+Escape | Power menu: lock, suspend, logout, reboot, power off |
| Super+Shift+V | Search clipboard history and restore selected text/image |
| Super+N | Toggle notification center |
| Super+Shift+N | Toggle Do Not Disturb |
| Print | Capture all outputs to PNG and copy |
| Super+Print | Select region, save and copy PNG |
| Alt+Print | Capture the active window, save and copy PNG |
| Shift+Print | Select region, capture/copy original, open Satty annotation |
| Super+Shift+R | Record a selected region / stop the current quick recording |
| Super+Ctrl+R | Record the focused screen / stop the current quick recording |
| Super+Alt+R | Record the active window rectangle / stop the current quick recording |
| Volume up/down | Change default sink by 5%; upward cap 100% |
| Audio mute | Toggle default sink mute |
| Microphone mute | Toggle default input mute |
| Brightness up/down | Change detected backlight by 5%, minimum one raw brightness unit |
| Media play / pause | Toggle playback through playerctl |
| Media next / previous | Next/previous track |

The sun icon also opens Night Light controls on desktops without a laptop backlight. For terminal use, `night-light.sh start|status|on|off|temperature K` manages Graphite's filter; `--help` describes its range and session lifetime.

Brightness/audio/media keys work while locked. Application/clipboard/recording shortcuts do not. Lock and power commands are also available through scripts in `~/.local/lib/graphite`. `record.sh start|toggle [region|full|window]` (plus `stop|status`), `clipboard.sh pick|clear`, and `screenshot.sh full|region|window|annotate` are the command forms.

Fuzzel: type to search, arrows to navigate, Enter selects/launches, Escape cancels. These same controls apply to clipboard and power menus. Logout/reboot/power off need a second Confirm selection; Cancel is first. Suspend goes through logind and hypridle's pre-sleep lock handling.

All three quick-record shortcuts share one recorder. While it is running, any of them stops and finalizes it; press again after it stops to start another mode. Full-screen recording uses the focused monitor. Window capture uses the visible rectangle on the window's assigned monitor; recording keeps those initial bounds, so keep the window in place and unobscured.

Satty's own Save/Copy controls export annotations; the raw PNG is saved before the editor opens. OBS hotkeys are defined manually inside its profile as described in `OBS.md`; no global OBS shortcuts conflict with quick recording.

Waybar: click a device icon to open its settings; another device icon changes the page in the same window. The clipboard icon opens searchable history. Escape, Close, outside clicks and the same trigger dismiss settings. The bell opens SwayNC separately. New arrivals show a ringing bell and gold highlight until the notification center is opened; opening it acknowledges them without clearing history. Right-click toggles Do Not Disturb; its crossed bell stays visible, with the gold highlight still indicating new arrivals. Click battery for its power panel, or hover for status and estimated time. See [QUICK-SETTINGS.md](QUICK-SETTINGS.md).

Edit `~/.config/graphite/hypr/graphite/bindings.lua`, then run `hyprctl reload` and `hyprctl configerrors`. Configure idle timeouts through the battery popup's Settings page; see [Power settings](POWER.md).

Capture, brightness, media tools and OBS require their recommended/optional packages. The physical keyboard stays on US positions. The single EN/あ bar indicator reports whether Mozc is enabled. Ctrl+Space or clicking the indicator toggles Japanese input; right-click opens input settings; see [JAPANESE.md](JAPANESE.md). Zsh customization is opt-in and does not alter the terminal's login shell.

Super+Shift+P or XF86Display (usually Fn + the display key) opens the display menu. Super+P remains pseudo-tiling. See [DISPLAYS.md](DISPLAYS.md).

Bluetooth: connected-state color and device-name tooltip; quick power/connect/disconnect actions and explicit BlueDevil pairing/settings dialogs. See [BLUETOOTH.md](BLUETOOTH.md).

## Searchable reference

Super+F1 uses the existing themed Fuzzel in read-only dmenu mode. Type a category, action or shortcut; arrows scroll, Enter or Escape closes without executing the selected binding. It reads `hyprctl -j binds` each time, including custom bindings and submaps. Set `description` on custom Lua bindings to show a meaningful action instead of a generic callback. Fcitx shortcuts come from Graphite's private config; active XKB options are queried separately. Application-local shortcuts are outside this compositor reference. If an independently started Fcitx uses another profile, its shortcuts can differ.

The centered reference aims for roughly one third of the focused output area; Fuzzel's character-based width makes sizing approximate. It is one short-lived process, guarded against duplicate launches. Swap shortcuts use Hyprland's previous/next cycle within the current workspace. Exit fullscreen before rearranging windows; test floating and grouped windows separately.
