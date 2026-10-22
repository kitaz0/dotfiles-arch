#!/usr/bin/env bash
# Graphite's Fcitx profile is isolated from Plasma's normal ~/.config/fcitx5.
set -euo pipefail
case ${1:-start} in
    status)
        if ! command -v fcitx5-remote >/dev/null || ! pgrep -u "$UID" -x fcitx5 >/dev/null; then
            printf '%s\n' '{"text":"","tooltip":"No Fcitx5 instance"}'
            exit 0
        fi
        state=$(timeout 1s fcitx5-remote 2>/dev/null) || state=0
        engine=$(timeout 1s fcitx5-remote -n 2>/dev/null) || engine=
        if [[ $state == 2 && $engine == mozc ]]; then
            printf '%s\n' '{"text":"JA","class":"active","tooltip":"Mozc enabled - Ctrl+Space toggles input. Character mode is shown by Mozc."}'
        else
            printf '%s\n' '{"text":"A","tooltip":"Direct input / other engine - Ctrl+Space toggles Mozc in the Graphite profile"}'
        fi
        ;;
    configure)
        export FCITX_CONFIG_HOME="$HOME/.config/graphite/fcitx5"
        exec fcitx5-configtool
        ;;
    start)
        [[ ${XDG_CURRENT_DESKTOP:-} == Graphite:Hyprland ]] || exit 0
        command -v fcitx5 >/dev/null || exit 0
        if pgrep -u "$UID" -x 'fcitx5|fcitx|ibus-daemon' >/dev/null; then
            echo 'An input method is already running; Graphite will not replace it.' >&2
            exit 0
        fi
        owner=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.fcitx.Fcitx5) || exit 1
        [[ $owner == 'b false' ]] || exit 0
        for name in GTK_IM_MODULE QT_IM_MODULE; do
            case ${!name:-} in ''|fcitx|wayland) ;; *) echo "Preserving existing $name; not starting another input framework." >&2; exit 0 ;; esac
        done
        export FCITX_CONFIG_HOME="$HOME/.config/graphite/fcitx5"
        [[ -z ${GRAPHITE_XWAYLAND_DISPLAY:-} ]] || export DISPLAY="$GRAPHITE_XWAYLAND_DISPLAY"
        exec fcitx5
        ;;
    *) echo 'Usage: input-method.sh start|status|configure' >&2; exit 2 ;;
esac
