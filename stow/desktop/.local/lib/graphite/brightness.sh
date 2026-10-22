#!/usr/bin/env bash
set -euo pipefail
case ${1:-} in
    up) change=+5% ;;
    down) change=5%- ;;
    *) echo 'Usage: brightness.sh up|down' >&2; exit 2 ;;
esac
# Desktops without a backlight have no action to perform.
compgen -G '/sys/class/backlight/*' >/dev/null || exit 0
command -v brightnessctl >/dev/null || { notify-send "Brightness unavailable" "Install brightnessctl for these controls"; exit 1; }
# Optional getopt arguments must use =; '-n 5' makes 5 the operation.
result=$(brightnessctl -c backlight -m --min-value=1 set "$change") || exit 1
while IFS=, read -r device class current percent maximum; do
    [[ $class == backlight && $percent =~ ^([0-9]+)%$ ]] || continue
    value=${BASH_REMATCH[1]}
    notify-send -a Graphite -u low -t 1500 -h boolean:transient:true \
        -h string:x-canonical-private-synchronous:graphite-brightness \
        -h "int:value:$value" -i display-brightness "Brightness ${value}%" || true
done <<< "$result"
