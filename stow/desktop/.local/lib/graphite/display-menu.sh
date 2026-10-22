#!/usr/bin/env bash
# Session-only monitor rules. Persistent preferences belong in monitors.lua.
set -euo pipefail
menu() {
    fuzzel --config="$HOME/.config/graphite/fuzzel/fuzzel.ini" --dmenu --index --prompt="$1"
}
if (( $# > 0 )); then
    [[ $# == 2 ]] || exit 2
    case $1 in right) choice=0 ;; left) choice=1 ;; mirror) choice=2 ;; only) choice=5 ;; other) choice=6 ;; *) exit 2 ;; esac
    requested=$2
else
    choice=$(printf '%s\n' 'Extend: other screen on the right' 'Extend: other screen on the left' \
        'Mirror selected screen onto the other' 'Graphical arrangement / modes (wdisplays)' \
        'Restore saved configuration (reload)' | menu 'Displays: ') || exit 0
fi
case $choice in
    3)
        command -v wdisplays >/dev/null || { notify-send 'Displays' 'Install the recommended wdisplays package'; exit 1; }
        exec wdisplays
        ;;
    4) exec hyprctl reload ;;
    0|1|2|5|6) ;;
    *) exit 0 ;;
esac
data=$(hyprctl -j monitors all)
names=$(jq -er 'if type == "array" and length == 2 then .[].name else error("Quick layouts require exactly two connected displays; use wdisplays") end' <<< "$data") || {
    notify-send 'Displays' 'Quick layouts require exactly two connected displays. Use graphical arrangement for other setups.'
    exit 1
}
mapfile -t outputs <<< "$names"
[[ ${#outputs[@]} == 2 && ${outputs[0]} != "${outputs[1]}" ]] || exit 1
# Connector names become Lua strings: reject unexpected characters, never eval input.
for output in "${outputs[@]}"; do
    [[ $output =~ ^[a-zA-Z0-9_.-]+$ ]] || { notify-send 'Displays' 'Unsupported connector name; use graphical arrangement'; exit 1; }
done
if [[ -n ${requested:-} ]]; then
    if [[ $requested == "${outputs[0]}" ]]; then selected=0
    elif [[ $requested == "${outputs[1]}" ]]; then selected=1
    else echo 'Selected display is no longer connected.' >&2; exit 1
    fi
else
    selected=$(printf '%s\n' "${outputs[@]}" | menu 'Reference / mirror source: ') || exit 0
fi
[[ $selected == 0 || $selected == 1 ]] || exit 0
source=${outputs[selected]}
target=${outputs[1-selected]}
if [[ $choice == 6 ]]; then
    swap=$source; source=$target; target=$swap
fi
position=auto-right
mirror=
[[ $choice != 1 ]] || position=auto-left
if [[ $choice == 2 ]]; then mirror=$source; position=auto; fi
# Recheck after interaction: do not apply stale selections after unplugging.
current=$(hyprctl -j monitors all | jq -er '.[].name')
[[ $current == "$names" ]] || { notify-send 'Displays changed' 'Open the menu again'; exit 1; }
rules="hl.monitor({ output = \"$source\", mode = \"preferred\", position = \"0x0\", scale = \"auto\", disabled = false, mirror = \"\" })
hl.monitor({ output = \"$target\", mode = \"preferred\", position = \"$position\", scale = \"auto\", disabled = false, mirror = \"$mirror\" })"
if [[ $choice == 5 || $choice == 6 ]]; then
    # Enable the remaining output before disabling the other. Never disable both.
    rules="hl.monitor({ output = \"$source\", mode = \"preferred\", position = \"0x0\", scale = \"auto\", disabled = false, mirror = \"\" })
    hl.monitor({ output = \"$target\", disabled = true })"
fi
result=$(hyprctl eval "$rules")
[[ $result == ok ]] || { printf '%s\n' "$result" >&2; notify-send 'Display configuration failed' 'Inspect hyprctl configerrors; reload to restore saved rules'; exit 1; }
