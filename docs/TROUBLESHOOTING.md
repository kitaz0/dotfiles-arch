# Troubleshooting

## Startup and updates

Use a TTY or fallback session. Run `bash verify-setup.sh`, `Hyprland --verify-config --config "$HOME/.config/graphite/hypr/hyprland.lua"`, and inspect `journalctl --user -b -u graphite-session.service`. Do not start a second compositor inside an existing graphical session.

Inspect `bash apply-config.sh --dry-run` before linking. Existing regular destination files are backed up before replacement; symlinked parent directories require manual resolution. A linked file edit changes the Git checkout directly. See [Deployment](DEPLOYMENT.md) for Git recovery, backup restoration and unstowing.

## Popups and bar

Close/reopen settings after QML updates. Check [0.3.2 compatibility](QUICKSHELL-COMPATIBILITY.md) for narrowly annotated metadata warnings. Run `fc-match 'JetBrainsMono Nerd Font'` if icons are missing. The mute glyph uses the older supported volume-off codepoint. Waybar filters only complete bare battery-status lines (`Full`, `Charging`, `Discharging`, `Not charging`, `Unknown`, `Plugged`); battery behavior and other logs remain unchanged.

## Clipboard

Both interfaces use `~/.cache/graphite/cliphist/db` (or XDG_CACHE_HOME). Run `bash ~/.local/lib/graphite/clipboard.sh pick` in a terminal for diagnostics. IDs are decoded without an extra newline, required by [older cliphist parsers](https://github.com/sentriz/cliphist/blob/v0.6.1/cliphist.go#L193). Failed decoding must not replace the clipboard. No history may mean foreign wl-paste watchers caused Graphite's collectors to be skipped; inspect session logs before adding watchers. History can contain secrets: `clipboard.sh clear` clears Graphite's database.

## Appearance, capture and devices

[Dark mode/theme](THEME.md) explains why changing bar colors does not theme every app. [Recording](OBS.md) distinguishes optional OBS from quick recording. [Displays](DISPLAYS.md), [Bluetooth](BLUETOOTH.md) and [Japanese input](JAPANESE.md) cover their integrations.

Dolphin uses UDisks2/polkit for mount/eject; close files before safe removal. Its embedded terminal requires Konsole; external Graphite terminal actions use Kitty. Missing authorization should be diagnosed rather than worked around with broad permissions.

Suspend/resume depends on compositor, locker and drivers. Keep a TTY available and collect kernel/session logs. No GPU driver, kernel option or power-manager replacement is applied by this project.

Graphite's resume hook enables the displays, waits half a second for the panel to settle and refreshes renderer outputs while preserving the running locker. A brief display flicker may occur. If the refresh is unnecessary for your hardware, set `after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'` in `~/.config/graphite/hypr/hypridle.conf`, then run `bash ~/.local/lib/graphite/power-policy.sh reload`. Validate both lid-close and menu suspend on your system. See [Power settings](POWER.md) for idle-policy diagnostics.
