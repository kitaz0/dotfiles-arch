#!/usr/bin/env bash
set -euo pipefail
umask 077
shopt -s nullglob
case ${1:-start} in
    start|reload) action=${1:-start} ;;
    --help|-h)
        echo 'Usage: waybar.sh [start|reload]'
        echo 'Reload refreshes only Graphite bars owned by this user; input services stay running.'
        exit 0 ;;
    *) echo 'Usage: waybar.sh [start|reload]' >&2; exit 2 ;;
esac
(( $# <= 1 )) || { echo 'Usage: waybar.sh [start|reload]' >&2; exit 2; }
battery=false
for supply in /sys/class/power_supply/*; do
    [[ ! -r $supply/type || $(<"$supply/type") != Battery ]] || battery=true
done
config=$(mktemp "${XDG_RUNTIME_DIR:?}/graphite-waybar-XXXXXX.json")
trap 'rm -f -- "$config"' EXIT
# Keep only the hardware-dependent override in the generated file. Including
# the source makes SIGUSR2 pick up module/config edits without restarting Fcitx.
jq --arg source "$HOME/.config/graphite/waybar/config.jsonc" --argjson battery "$battery" '
    {include: $source, "modules-right": (.["modules-right"] | map(select(. != "battery" or $battery)))}
' "$HOME/.config/graphite/waybar/config.jsonc" > "$config"
if [[ $action == reload ]]; then
    refreshed=false
    for pid in $(pgrep -u "$UID" -x waybar || true); do
        mapfile -d '' -t args < "/proc/$pid/cmdline" 2>/dev/null || continue
        [[ ${args[1]:-} == -c && ${args[3]:-} == -s &&
            ${args[4]:-} == "$HOME/.config/graphite/waybar/style.css" ]] || continue
        live=${args[2]}
        [[ ${live%/*} == "$XDG_RUNTIME_DIR" &&
            ${live##*/} =~ ^graphite-waybar-[[:alnum:]]+\.json$ &&
            -f $live && -O $live && ! -L $live ]] || continue
        # Also upgrades bars launched before the source-include configuration.
        cp -- "$config" "$live"
        kill -USR2 "$pid"
        refreshed=true
    done
    $refreshed || { echo 'No running Graphite Waybar found for this user.' >&2; exit 1; }
    exit 0
fi
# Filter only bare battery-status debug lines; preserve every other diagnostic.
# Keep Waybar as the waited/signalled child, not the pipeline filter.
waybar -c "$config" -s "$HOME/.config/graphite/waybar/style.css" > >(sed -u -E '/^(Full|Charging|Discharging|Not charging|Unknown|Plugged)$/d' >&2) 2>&1 &
bar=$!
trap 'kill -TERM "$bar" 2>/dev/null || true; wait "$bar" 2>/dev/null || true; exit 0' INT TERM
wait "$bar"
