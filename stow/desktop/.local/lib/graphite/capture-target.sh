#!/usr/bin/env bash
# Resolve a visible capture target in Hyprland's logical coordinates.
set -euo pipefail
case ${1:-} in
    --help|-h)
        echo 'Usage: capture-target.sh full|window'
        echo 'Print JSON containing output and geometry. Window bounds are clipped to their monitor.'
        exit 0 ;;
    full|window) mode=$1 ;;
    *) echo 'Usage: capture-target.sh full|window' >&2; exit 2 ;;
esac
(( $# == 1 )) || exit 2
monitors=$(hyprctl -j monitors)
if [[ $mode == full ]]; then
    jq -er 'first(.[] | select(.focused == true and (.disabled // false | not))) |
        if (.name | type) == "string" and .name != "" then {output: .name} else error("No focused output") end' <<< "$monitors"
    exit
fi
window=$(hyprctl -j activewindow)
jq -en --argjson monitors "$monitors" --argjson window "$window" '
    $window | select((.address // "") != "" and (.mapped // true) and (.hidden // false | not)) |
    select((.at | length) == 2 and (.size | length) == 2 and .size[0] > 0 and .size[1] > 0) as $w |
    first($monitors[] | select(.id == $w.monitor and (.disabled // false | not))) as $m |
    (if (($m.transform // 0) % 2) == 1 then [$m.height, $m.width] else [$m.width, $m.height] end) as $pixels |
    ([($w.at[0] | floor), $m.x] | max) as $x |
    ([($w.at[1] | floor), $m.y] | max) as $y |
    ([($w.at[0] + $w.size[0] | ceil), ($m.x + $pixels[0] / $m.scale | floor)] | min) as $right |
    ([($w.at[1] + $w.size[1] | ceil), ($m.y + $pixels[1] / $m.scale | floor)] | min) as $bottom |
    select($right > $x and $bottom > $y) |
    {output: $m.name, geometry: "\($x),\($y) \($right - $x)x\($bottom - $y)"}
'
