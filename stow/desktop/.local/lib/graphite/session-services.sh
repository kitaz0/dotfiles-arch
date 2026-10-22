#!/usr/bin/env bash
# Finite launcher. systemd owns helper descendants; no polling or PID supervision.
set -euo pipefail
umask 077
[[ -n ${INVOCATION_ID:-} ]] || { echo 'Launch through session-start.sh' >&2; exit 1; }
for command in waybar swaybg hypridle swaync wl-paste cliphist busctl pgrep; do
    command -v "$command" >/dev/null || { echo "Missing helper: $command" >&2; exit 1; }
done
owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications)
[[ $owner == 'b false' || $owner == 'b true' ]] || { echo "Unexpected notification owner response: $owner" >&2; exit 1; }
"$HOME/.local/lib/graphite/waybar.sh" &
swaybg -i "$HOME/.local/share/graphite/wallpaper.png" -m fill &
hypridle -c "$HOME/.config/graphite/hypr/hypridle.conf" &
"$HOME/.local/lib/graphite/usb-notify.sh" &
if [[ $owner == 'b false' ]]; then
    swaync -c "$HOME/.config/graphite/swaync/config.json" -s "$HOME/.config/graphite/swaync/style.css" &
else
    echo 'Notification bus already owned; Graphite notification-center controls may be unavailable' >&2
fi
# Foreign authentication agents have no common query interface. This is only a
# best-effort duplicate check; validate authorization on the actual login seat.
if ! pgrep -u "$UID" -f '([p]olkit.*(agent|authentication)|[h]yprpolkitagent)' >/dev/null; then
    /usr/lib/hyprpolkitagent/hyprpolkitagent &
fi
if pgrep -u "$UID" -f '[w]l-paste.*--watch' >/dev/null; then
    echo 'Foreign clipboard watcher detected; Graphite collection skipped. Review its owner before enabling Graphite history.' >&2
else
    wl-paste --type text --watch "$HOME/.local/lib/graphite/clipboard.sh" store &
    wl-paste --type image --watch "$HOME/.local/lib/graphite/clipboard.sh" store &
fi
# No global autostart entry: its lifetime belongs to this Graphite cgroup.
"$HOME/.local/lib/graphite/input-method.sh" start &
# ExitType=cgroup keeps this unit active while its helper processes remain.
