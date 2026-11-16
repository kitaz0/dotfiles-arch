#!/usr/bin/env bash
set -euo pipefail
umask 077
mode=${1:-region}
case $mode in
    --help|-h)
        echo 'Usage: screenshot.sh [full|region|window|annotate]'
        echo 'Full captures all outputs; window captures the focused window on its monitor.'
        exit 0 ;;
    full|region|window|annotate) ;;
    *) echo 'Usage: screenshot.sh [full|region|window|annotate]' >&2; exit 2 ;;
esac
(( $# <= 1 )) || exit 2
case $mode in
    full) label='Full-screen screenshot' ;;
    region) label='Region screenshot' ;;
    window) label='Window screenshot' ;;
    annotate) label='Region screenshot (annotation)' ;;
esac
helpers=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
commands=(grim wl-copy)
[[ $mode != window ]] || commands+=(hyprctl jq)
for command in "${commands[@]}"; do
    command -v "$command" >/dev/null || { notify-send 'Screenshot unavailable' "Missing recommended package: $command"; exit 1; }
done
if [[ $mode == region || $mode == annotate ]] && ! command -v slurp >/dev/null; then notify-send 'Screenshot unavailable' 'Install slurp'; exit 1; fi
if [[ $mode == annotate ]] && ! command -v satty >/dev/null; then notify-send 'Annotation unavailable' 'Install satty'; exit 1; fi
geometry=''
if [[ $mode == window ]]; then
    target=$(bash "$helpers/capture-target.sh" window) || { notify-send 'Screenshot unavailable' 'No visible active window could be captured'; exit 1; }
    geometry=$(jq -er .geometry <<< "$target")
elif [[ $mode != full ]]; then
    geometry=$(slurp) || exit 0
    [[ -n $geometry ]] || exit 0
fi
dir="$HOME/Pictures/Screenshots"
mkdir -p -- "$dir"
file=$(mktemp "$dir/$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.png")
args=()
[[ -z $geometry ]] || args=(-g "$geometry")
if ! grim "${args[@]}" "$file"; then rm -f -- "$file"; echo 'Capture failed' >&2; exit 1; fi
wl-copy --type image/png < "$file"
if [[ $mode == annotate ]]; then
    # Original is preserved; the export name is separately reserved.
    edited=$(mktemp "$dir/$(date +%Y-%m-%d_%H-%M-%S)-edited-XXXXXX.png")
    if ! satty --filename "$file" --output-filename "$edited" --copy-command wl-copy; then
        [[ -s $edited ]] || rm -f -- "$edited"
        exit 1
    fi
    [[ -s $edited ]] || rm -f -- "$edited"
fi
notify-send "$label saved and copied" "$file"
