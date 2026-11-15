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
    home|wifi|bluetooth|audio|mixer|brightness|clipboard|displays|power|power-settings) export GRAPHITE_SETTINGS_PAGE=${1:-audio} ;;
    *) exit 2 ;;
esac
command -v qs >/dev/null || { notify-send 'Quick settings unavailable' 'Review and install the quickshell package, then try again.'; exit 1; }
[[ -n ${WAYLAND_DISPLAY:-} && -n ${XDG_RUNTIME_DIR:-} ]] || exit 1
# One top-level Graphite panel at a time. Do not wait for a missing daemon.
timeout 2s swaync-client --skip-wait --close-panel >/dev/null 2>&1 || true
if timeout 2s qs ipc -p "$config" call settings toggle "$GRAPHITE_SETTINGS_PAGE" >/dev/null 2>&1; then
    exit 0
fi
# Basic allows the locally styled Qt Quick controls; no platform-native style override.
export QT_QUICK_CONTROLS_STYLE=Basic
# Quickshell owns instance detection. An inherited flock descriptor can keep a
# dead popup locked after launching an external application, so do not use one.
exec qs --no-duplicate -p "$config"
