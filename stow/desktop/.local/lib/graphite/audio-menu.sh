#!/usr/bin/env bash
# Quick controls in a layer-shell menu; advanced routing stays in pavucontrol.
set -euo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
menu() {
    fuzzel --config="$HOME/.config/graphite/fuzzel/fuzzel.ini" --dmenu --index \
        --anchor=top-right --prompt="$1"
}
mixer() {
    command -v pavucontrol >/dev/null || { notify-send 'Audio' 'Install the recommended pavucontrol package for the full mixer'; return 1; }
    exec pavucontrol --tab="$1"
}
device_menu() {
    local kind=$1 singular=$2 data current rows row name label selected
    local names=() labels=()
    command -v pactl >/dev/null || { notify-send 'Audio' 'pactl (libpulse) is required for device selection'; return 1; }
    data=$(pactl --format=json list "$kind")
    current=$(pactl "get-default-$singular")
    rows=$(jq -c '.[] | {name, description}' <<< "$data")
    [[ -n $rows ]] || { notify-send 'Audio' 'No audio devices found'; return 0; }
    while IFS= read -r row; do
        name=$(jq -r '.name' <<< "$row")
        label=$(jq -r '.description | gsub("[\\r\\n\\t]"; " ")' <<< "$row")
        [[ $name != "$current" ]] || label="CURRENT: $label"
        names+=("$name"); labels+=("$label")
    done <<< "$rows"
    selected=$(printf '%s\n' "${labels[@]}" | menu 'Audio device: ') || return 0
    [[ $selected =~ ^[0-9]+$ ]] || return 0
    (( selected < ${#names[@]} )) || return 1
    pactl "set-default-$singular" "${names[selected]}"
}
output=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
input=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@) || input=unavailable
labels=("Output: $output (close)" "Microphone: $input (close)"
    'Volume up 5%' 'Volume down 5%' 'Mute / unmute output' 'Mute / unmute microphone'
    'Choose output device' 'Choose microphone'
    'Application volumes and playback routing' 'Recording streams and routing'
    'Output levels and ports' 'Microphone levels and ports' 'Hardware profiles')
choice=$(printf '%s\n' "${labels[@]}" | menu 'Audio: ') || exit 0
case $choice in
    0|1) exit 0 ;;
    2) exec "$base/volume.sh" up ;;
    3) exec "$base/volume.sh" down ;;
    4) exec "$base/volume.sh" mute ;;
    5) exec "$base/volume.sh" mic ;;
    6) device_menu sinks sink ;;
    7) device_menu sources source ;;
    8) mixer 1 ;;
    9) mixer 2 ;;
    10) mixer 3 ;;
    11) mixer 4 ;;
    12) mixer 5 ;;
    *) exit 0 ;;
esac
