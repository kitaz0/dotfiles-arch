#!/usr/bin/env bash
# On-demand popup; no background shell service and no global Qt settings.
set -euo pipefail
config="$HOME/.config/graphite/quick-settings/shell.qml"
case ${1:-audio} in
    close|notifications)
        timeout 2s qs ipc -p "$config" call settings close >/dev/null 2>&1 || true
        [[ $1 != notifications ]] || exec swaync-client --skip-wait --toggle-panel
        exit 0
        ;;
esac
case ${1:-audio} in
    home|wifi|bluetooth|audio|mixer|brightness|clipboard|displays) export GRAPHITE_SETTINGS_PAGE=${1:-audio} ;;
    *) exit 2 ;;
esac
command -v qs >/dev/null || { notify-send 'Quick settings unavailable' 'Review and install the quickshell package, then try again.'; exit 1; }
[[ -n ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} ]] || exit 1
# One top-level Graphite panel at a time. Do not wait for a missing daemon.
swaync-client --skip-wait --close-panel >/dev/null 2>&1 || true
umask 077
exec 9>"$XDG_RUNTIME_DIR/graphite-quick-settings.lock"
if ! flock -n 9; then
    # Only address this configuration, never another user's Quickshell instance.
    qs ipc -p "$HOME/.config/graphite/quick-settings/shell.qml" call settings toggle "$GRAPHITE_SETTINGS_PAGE"
    exit $?
fi
# Basic allows the locally styled Qt Quick controls; no platform-native style override.
export QT_QUICK_CONTROLS_STYLE=Basic
exec qs -p "$HOME/.config/graphite/quick-settings/shell.qml"
