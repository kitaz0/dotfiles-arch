#!/usr/bin/env bash
set -euo pipefail
exec 9>"${XDG_RUNTIME_DIR:?}/graphite-lock.guard"
flock -n 9 || exit 0
pgrep -u "$UID" -x hyprlock >/dev/null && exit 0
exec hyprlock -c "$HOME/.config/graphite/hypr/hyprlock.conf"
