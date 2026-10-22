#!/usr/bin/env bash
# Per-application profile only: never change the session's XDG environment.
set -euo pipefail
if [[ ${XDG_CURRENT_DESKTOP:-} != Graphite:Hyprland ]]; then
    exec dolphin "$@"
fi
[[ ${GRAPHITE_DOLPHIN_CONFIG:-} != 1 ]] || exec dolphin --new-window "$@"
normal_config=${XDG_CONFIG_HOME:-$HOME/.config}
normal_dirs=${XDG_CONFIG_DIRS:-/etc/xdg}
exec env GRAPHITE_DOLPHIN_CONFIG=1 \
    GRAPHITE_PARENT_CONFIG_HOME="$normal_config" GRAPHITE_PARENT_CONFIG_DIRS="$normal_dirs" \
    GRAPHITE_PARENT_QT_PLATFORM="${QT_QPA_PLATFORMTHEME-}" GRAPHITE_PARENT_QT_STYLE="${QT_STYLE_OVERRIDE-}" \
    XDG_CONFIG_HOME="$HOME/.config/graphite/dolphin" \
    XDG_CONFIG_DIRS="$normal_config:$normal_dirs" \
    QT_QPA_PLATFORMTHEME=kde QT_STYLE_OVERRIDE=Breeze \
    dolphin --new-window "$@"
