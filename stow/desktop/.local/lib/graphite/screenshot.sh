#!/usr/bin/env bash
set -euo pipefail
umask 077
mode=${1:-region}
case $mode in
    full|region|annotate) ;;
    *) echo 'Usage: screenshot.sh full|region|annotate' >&2; exit 2 ;;
esac
for command in grim; do
    command -v "$command" >/dev/null || { notify-send 'Screenshot unavailable' "Missing recommended package: $command"; exit 1; }
done
if [[ $mode != full ]] && ! command -v slurp >/dev/null; then notify-send 'Screenshot unavailable' 'Install slurp'; exit 1; fi
if [[ $mode == annotate ]] && ! command -v satty >/dev/null; then notify-send 'Annotation unavailable' 'Install satty'; exit 1; fi
geometry='' 
if [[ $mode != full ]]; then
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
notify-send 'Screenshot saved and copied' "$file"
