#!/usr/bin/env bash
set -euo pipefail
umask 077
shopt -s nullglob
backlights=(/sys/class/backlight/*)
battery=false
for supply in /sys/class/power_supply/*; do
    [[ ! -r $supply/type || $(<"$supply/type") != Battery ]] || battery=true
done
config=$(mktemp "${XDG_RUNTIME_DIR:?}/graphite-waybar-XXXXXX.json")
trap 'rm -f -- "$config"' EXIT
jq --argjson battery "$battery" --argjson backlight "$(( ${#backlights[@]} > 0 ))" '
    .["modules-right"] |= map(select(
        (. != "battery" or $battery) and (. != "backlight" or $backlight == 1)))
' "$HOME/.config/graphite/waybar/config.jsonc" > "$config"
# Filter only bare battery-status debug lines; preserve every other diagnostic.
# Keep Waybar as the waited/signalled child, not the pipeline filter.
waybar -c "$config" -s "$HOME/.config/graphite/waybar/style.css" > >(sed -u -E '/^(Full|Charging|Discharging|Not charging|Unknown|Plugged)$/d' >&2) 2>&1 &
bar=$!
trap 'kill -TERM "$bar" 2>/dev/null || true; wait "$bar" 2>/dev/null || true; exit 0' INT TERM
wait "$bar"
