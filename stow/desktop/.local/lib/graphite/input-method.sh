#!/usr/bin/env bash
# Graphite's Fcitx profile is isolated from Plasma's normal ~/.config/fcitx5.
set -euo pipefail
case ${1:-start} in
    status)
        if ! command -v fcitx5-remote >/dev/null || ! pgrep -u "$UID" -x fcitx5 >/dev/null; then
            printf '%s\n' '{"text":"EN","class":"inactive","tooltip":"Direct input. Fcitx5 is not running."}'
            exit 0
        fi
        state=$(timeout 1s fcitx5-remote 2>/dev/null) || state=unknown
        case $state in
            0|1)
                printf '%s\n' '{"text":"EN","class":"inactive","tooltip":"Direct input. Ctrl+Space toggles Japanese; right-click opens input settings."}'
                ;;
            2)
                engine=$(timeout 1s fcitx5-remote -n 2>/dev/null) || engine=
                case $engine in
                    mozc)
                        printf '%s\n' '{"text":"あ","class":["active","japanese"],"tooltip":"Japanese input (Mozc) enabled. Ctrl+Space toggles direct input; right-click opens input settings."}' ;;
                    keyboard-*)
                        printf '%s\n' '{"text":"EN","class":"inactive","tooltip":"Direct keyboard input. Ctrl+Space toggles Japanese; right-click opens input settings."}' ;;
                    '')
                        printf '%s\n' '{"text":"?","class":"unavailable","tooltip":"Could not query the active input method."}' ;;
                    *)
                        printf '%s\n' '{"text":"IM","class":"active","tooltip":"Another input method is active; right-click opens input settings."}' ;;
                esac
                ;;
            *)
                printf '%s\n' '{"text":"?","class":"unavailable","tooltip":"Could not query Fcitx5 input state."}'
                ;;
        esac
        ;;
    watch)
        # Fcitx's tray emits NewIcon on mode/focus changes, even when its item
        # is hidden by Waybar. Also refresh when the daemon starts or exits.
        coproc IM_EVENTS {
            exec busctl --user --json=short \
                --match="type='signal',path='/StatusNotifierItem',interface='org.kde.StatusNotifierItem',member='NewIcon'" \
                --match="type='signal',sender='org.freedesktop.DBus',interface='org.freedesktop.DBus',member='NameOwnerChanged',arg0='org.fcitx.Fcitx5'" \
                monitor
        }
        monitor_pid=$IM_EVENTS_PID
        exec {events}<&"${IM_EVENTS[0]}"
        trap 'kill "$monitor_pid" 2>/dev/null || true; wait "$monitor_pid" 2>/dev/null || true' EXIT
        trap 'exit 0' INT TERM
        last=
        while :; do
            current=$(bash "${BASH_SOURCE[0]}" status)
            if [[ $current != "$last" ]]; then
                printf '%s\n' "$current"
                last=$current
            fi
            # The occasional health check also covers a change during initial
            # subscription or an unavailable/disabled Fcitx tray addon.
            if IFS= read -r -t 30 _event <&"$events"; then
                continue
            else
                result=$?
                (( result > 128 )) || exit "$result"
            fi
        done
        ;;
    toggle)
        command -v fcitx5-remote >/dev/null || exit 1
        pgrep -u "$UID" -x fcitx5 >/dev/null || exit 1
        exec timeout 1s fcitx5-remote -t
        ;;
    configure)
        export FCITX_CONFIG_HOME="$HOME/.config/graphite/fcitx5"
        # The generic configtool wrapper drops Qt arguments; call the Qt app
        # directly so the palette is local to this window, never Plasma-wide.
        exec fcitx5-config-qt -style Fusion -stylesheet "$HOME/.config/graphite/qt/widgets.qss"
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
    *) echo 'Usage: input-method.sh start|status|watch|toggle|configure' >&2; exit 2 ;;
esac
