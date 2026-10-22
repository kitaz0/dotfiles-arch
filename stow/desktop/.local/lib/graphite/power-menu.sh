#!/usr/bin/env bash
set -euo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
choices=$'Lock\n'
if [[ -r /sys/power/state && $(</sys/power/state) =~ (mem|freeze) ]]; then choices+=$'Suspend\n'; fi
choices+=$'Log out\nReboot\nPower off\n'
choice=$(printf '%s' "$choices" | fuzzel --config="$HOME/.config/graphite/fuzzel/fuzzel.ini" --dmenu --prompt='Power ❯ ') || exit 0
case $choice in
    Lock) exec "$base/lock.sh" ;;
    Suspend) systemctl suspend ;;
    'Log out'|Reboot|'Power off')
        confirm=$(printf 'Cancel\nConfirm\n' | fuzzel --config="$HOME/.config/graphite/fuzzel/fuzzel.ini" --dmenu --prompt="$choice ❯ ") || exit 0
        [[ $confirm == Confirm ]] || exit 0
        case $choice in
            'Log out')
                if systemctl --user is-active --quiet graphite-recorder.service; then
                    systemctl --user stop graphite-recorder.service
                fi
                hyprctl dispatch 'hl.dsp.exit()' ;;
            Reboot) systemctl reboot ;;
            'Power off') systemctl poweroff ;;
        esac ;;
esac
