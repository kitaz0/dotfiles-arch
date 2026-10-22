#!/usr/bin/env bash
set -euo pipefail
[[ $# == 0 || ( $# == 1 && $1 == start ) ]] || { echo 'Usage: start-session.sh [start]' >&2; exit 2; }
[[ $EUID != 0 ]] || { echo 'Run as the regular user' >&2; exit 1; }
[[ -n ${XDG_RUNTIME_DIR:-} ]] || { echo 'A logind login with XDG_RUNTIME_DIR is required' >&2; exit 1; }
[[ -z ${WAYLAND_DISPLAY:-} && -z ${DISPLAY:-} ]] || { echo 'Log out of the other desktop before launching Graphite' >&2; exit 1; }
for command in start-hyprland systemctl; do
    command -v "$command" >/dev/null || { echo "Required command missing: $command" >&2; exit 1; }
done
# No GPU override and no XDG configuration redirection. Preserve explicit AQ_DRM_DEVICES.
export XDG_CURRENT_DESKTOP=Graphite:Hyprland XDG_SESSION_TYPE=wayland
# Session-local Qt5/XWayland integration; native GTK Wayland uses text-input-v3.
# Do not override a user's explicit input framework or change Plasma settings.
graphite_ime_compatible=true
for name in GTK_IM_MODULE QT_IM_MODULE; do
    case ${!name:-} in ''|fcitx|wayland) ;; *) graphite_ime_compatible=false ;; esac
done
if $graphite_ime_compatible && command -v fcitx5 >/dev/null && ! pgrep -u "$UID" -x 'ibus-daemon|fcitx' >/dev/null; then
    export QT_IM_MODULE=${QT_IM_MODULE:-fcitx} XMODIFIERS=${XMODIFIERS:-@im=fcitx}
fi
systemctl --user show-environment >/dev/null || { echo 'Cannot access the systemd user manager' >&2; exit 1; }
cleanup() {
    trap - EXIT
    # Recording gets SIGINT and its stop timeout before the helper cgroup is stopped.
    systemctl --user stop graphite-recorder.service 2>/dev/null || true
    systemctl --user stop graphite-session.service 2>/dev/null || true
}
trap cleanup EXIT
session_pid=''
terminate() {
    trap - INT TERM HUP
    [[ -z $session_pid ]] || kill -TERM "$session_pid" 2>/dev/null || true
    [[ -z $session_pid ]] || wait "$session_pid" 2>/dev/null || true
    exit "$1"
}
trap 'terminate 130' INT
trap 'terminate 143' TERM
trap 'terminate 129' HUP
start-hyprland -- --config "$HOME/.config/graphite/hypr/hyprland.lua" &
session_pid=$!
result=0
wait "$session_pid" || result=$?
exit "$result"
