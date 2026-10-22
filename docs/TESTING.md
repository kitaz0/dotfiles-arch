# Verification checklist

Local development: `python docs/audit.py` runs Bash syntax, Stow layout/link checks and disposable command fixtures. Python 3.11+ and optional Node are development-only. Checks requiring unavailable interpreters or tooling are marked as skipped. A successful run saves a local report in `.checks/validation.md` (ignored by Git). Command fixtures do not replace the desktop and hardware checks below.

On Arch, run `bash verify-setup.sh` before logout. Use `--desktop-only` if application configs were omitted. The default output groups dependencies and installed links, shows issue details (up to eight lines per check), and ends with pass/fail/warning/skip counts. Use `--verbose` for full command output and installed versions. Exit 1 means a required check failed; warnings and skips alone return 0. Missing files, helper permissions/syntax and parser errors are failures; incorrect links fail verification; optional features and unavailable service access are reported separately. Fcitx settings are checked as local writable files.

Target-machine checks include real Hyprland/Fuzzel/Zsh/JSON parsers, QML lint, font fallback detection, systemd environment comparison, active outputs and notification ownership inside Graphite, and leftover Graphite services outside it. Service queries are read-only; an active helper cgroup is not proof that every helper is healthy. Inactive services may activate on demand. Use verbose output to inspect the helper process tree. QML lint success does not prove popup rendering or interaction works. A restricted environment may block service access; rerun from a normal terminal for those checks. Outside Graphite, its compositor checks are skipped rather than claimed as passed.

After entering Graphite:

1. Run `hyprctl configerrors`; verify monitors, scale, keyboard, touchpad and layout switching.
2. Open each bar popup; hover/click other icons, Escape, outside-click and reopen. The first outside click must dismiss without activating the app underneath. Check both monitors.
3. Change volume/brightness with keys and sliders; verify actual state, mute icon, devices and application mixer.
4. Copy text and an image, restore through the clipboard icon and Super+Shift+V, then paste into suitable apps. Test an empty history and a removed entry.
5. Open three windows: test focus arrows, workspace-local swap shortcuts and Super+F1 search.
6. Connect/disconnect Wi-Fi and Bluetooth; test required authentication and unavailable hardware.
7. Capture a screenshot and short recording; play it back. Check OBS separately if installed.
8. Check application dark mode, file dialogs, USB mount/eject and notifications.
9. Test manual lock, idle, suspend/resume and lid-close while keeping a TTY available. Verify the lock screen repaints, accepts input and reveals the desktop after successful authentication.
10. Log out cleanly, enter another session/TTY, and verify no Graphite helper processes remain. Preview unstowing outside Graphite and verify the migration backup before relying on it for recovery.

Diagnostics: `journalctl --user -b -u graphite-session.service --no-pager -n 80`. Bare Waybar battery-status lines are filtered; other warnings/errors are retained. A direct `waybar -c ~/.config/graphite/waybar/config.jsonc -s ~/.config/graphite/waybar/style.css` bypasses the filter for diagnosis; stop the existing bar first to avoid duplicates.
