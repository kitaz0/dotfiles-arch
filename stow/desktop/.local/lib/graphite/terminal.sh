#!/usr/bin/env bash
set -euo pipefail
if [[ ${GRAPHITE_DOLPHIN_CONFIG:-} == 1 ]]; then
    # Editors/shells launched from Dolphin should use their ordinary configuration.
    export XDG_CONFIG_HOME="${GRAPHITE_PARENT_CONFIG_HOME:?}"
    export XDG_CONFIG_DIRS="${GRAPHITE_PARENT_CONFIG_DIRS:?}"
    unset GRAPHITE_DOLPHIN_CONFIG GRAPHITE_PARENT_CONFIG_HOME GRAPHITE_PARENT_CONFIG_DIRS
    if [[ -n ${GRAPHITE_PARENT_QT_PLATFORM:-} ]]; then
        export QT_QPA_PLATFORMTHEME=$GRAPHITE_PARENT_QT_PLATFORM
    else
        unset QT_QPA_PLATFORMTHEME
    fi
    if [[ -n ${GRAPHITE_PARENT_QT_STYLE:-} ]]; then
        export QT_STYLE_OVERRIDE=$GRAPHITE_PARENT_QT_STYLE
    else
        unset QT_STYLE_OVERRIDE
    fi
    unset GRAPHITE_PARENT_QT_PLATFORM GRAPHITE_PARENT_QT_STYLE
fi
exec kitty "$@"
