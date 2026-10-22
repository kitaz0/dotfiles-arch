#!/usr/bin/env bash
set -euo pipefail
sink=@DEFAULT_AUDIO_SINK@
title=Volume
case ${1:-} in
    up) wpctl set-volume -l 1 "$sink" 5%+ ;;
    down) wpctl set-volume "$sink" 5%- ;;
    mute) wpctl set-mute "$sink" toggle ;;
    mic) sink=@DEFAULT_AUDIO_SOURCE@; title=Microphone; wpctl set-mute "$sink" toggle ;;
    *) echo 'Usage: volume.sh up|down|mute|mic' >&2; exit 2 ;;
esac
state=$(LC_ALL=C wpctl get-volume "$sink")
value=$(awk '{printf "%.0f", $2 * 100}' <<< "$state")
[[ $value =~ ^[0-9]+$ ]] || exit 1
label="$title ${value}%"
[[ $state != *'[MUTED]'* ]] || label="$title muted"
(( value <= 100 )) || value=100
notify-send -a Graphite -u low -t 1500 -h boolean:transient:true \
    -h "string:x-canonical-private-synchronous:graphite-$title" \
    -h "int:value:$value" -i audio-volume-high "$label" || true
