#!/usr/bin/env bash
# Search live compositor bindings; selecting a row never executes its action.
set -euo pipefail
umask 077
exec 9>"${XDG_RUNTIME_DIR:?}/graphite-shortcuts.lock"
flock -n 9 || exit 0
helpers=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
bash "$helpers/quick-settings.sh" close
swaync-client --skip-wait --close-panel >/dev/null 2>&1 || true
rows=$(hyprctl -j binds | jq -r '
    def clean: tostring | gsub("[\r\n\t]"; " ");
    def modifiers($m):
        [[64,"Super"],[4,"Ctrl"],[8,"Alt"],[1,"Shift"],[2,"Caps"],[16,"Mod2"],[32,"Mod3"],[128,"Mod5"]]
        | map(select(($m / .[0] | floor) % 2 == 1) | .[1]);
    map(. as $b | (modifiers(.modmask // 0) +
        [if (.key // "") != "" then .key else "code:" + (.keycode | tostring) end] | join("+")) as $key |
        (if (.description // "") != "" then .description else
            "Custom | " + (.dispatcher // "callback") + " " + (.arg // "") end) as $label |
        ($label | clean) + "  |  " + ($key | clean) +
        (if (.submap // "") != "" then " [" + (.submap | clean) + "]" else "" end) +
        (if .release then " (release)" else "" end)) | sort | .[]')
[[ -n $rows ]] || { echo 'No live Hyprland bindings available.' >&2; exit 1; }
# Include non-compositor input shortcuts from the actual Graphite settings.
input="$HOME/.config/graphite/fcitx5/config"
if [[ -f $input ]]; then
    ime=$(awk '/^\[/ { section=$0 } /^[0-9]+=/ && section ~ /^\[Hotkey\// { sub(/^[0-9]+=/, ""); print "Input | Fcitx5 " section "  |  " $0 }' "$input")
    [[ -z $ime ]] || rows+=$'\n'"$ime"
fi
xkb=$(hyprctl -j getoption input:kb_options | jq -r '.str // empty') || xkb=''
[[ -z $xkb ]] || rows+=$'\n'"Input | Active XKB options  |  $xkb"
# About one third of the output area (60% width x 55% height), in logical pixels.
# Fuzzel width is character-based, so font metrics make this approximate.
dimensions=$(hyprctl -j monitors | jq -r '
    map(select(.focused))[0] // empty |
    ((.width / .scale * 0.60 / 9 | floor) | [20, .] | max) as $w |
    ((.height / .scale * 0.55 / 26 - 2 | floor) | [4, .] | max) as $h |
    "\($w) \($h)"') || dimensions=''
width=70; lines=15
if [[ $dimensions =~ ^([0-9]+)\ ([0-9]+)$ ]]; then
    width=${BASH_REMATCH[1]}; lines=${BASH_REMATCH[2]}
fi
printf '%s\n' "$rows" | fuzzel --config="$HOME/.config/graphite/fuzzel/fuzzel.ini" \
    --dmenu --no-sort --counter --anchor=center --width="$width" --lines="$lines" \
    --font='JetBrainsMono Nerd Font:size=11' --line-height=26px \
    --prompt='Shortcuts > ' >/dev/null || {
    code=$?
    [[ $code == 1 || $code == 2 ]] || exit "$code"
}
