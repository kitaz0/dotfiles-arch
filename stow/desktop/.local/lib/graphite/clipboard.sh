#!/usr/bin/env bash
set -euo pipefail
umask 077
db="${XDG_CACHE_HOME:-$HOME/.cache}/graphite/cliphist/db"
temp=''
trap '[[ -z $temp ]] || rm -f -- "$temp"' EXIT
# Explicit path avoids collecting into or clearing the user's existing history.
clip() { cliphist -config-path /dev/null -db-path "$db" "$@"; }
restore() {
    [[ $1 =~ ^[0-9]+$ ]] || { echo 'Invalid clipboard entry ID' >&2; return 2; }
    # Decode completely before replacing the clipboard; retain binary bytes.
    temp=$(mktemp "${XDG_RUNTIME_DIR:?}/graphite-clipboard-XXXXXX")
    if ! printf '%s' "$1" | clip decode > "$temp"; then
        echo 'Clipboard entry is unavailable; refresh history.' >&2
        return 1
    fi
    # Older cliphist can succeed with an empty result for a missing ID.
    [[ -s $temp ]] || { echo 'Clipboard entry is empty or no longer available.' >&2; return 1; }
    wl-copy < "$temp"
    rm -f -- "$temp"
    temp=''
}
case ${1:-pick} in
    clear) clip wipe; exit ;;
    store) clip store; exit ;;
    list-json)
        [[ -f $db ]] || { printf '[]\n'; exit 0; }
        clip list | jq -Rs 'split("\n") | map(select(length > 0) | capture("^(?<id>[0-9]+)\\t(?<preview>.*)$"))'
        exit
        ;;
    restore) restore "${2:-}"; exit ;;
    pick) ;;
    *) echo 'Usage: clipboard.sh [pick|clear|store|list-json|restore ID]' >&2; exit 2 ;;
esac
choice=$(clip list | fuzzel --config="$HOME/.config/graphite/fuzzel/fuzzel.ini" --dmenu --prompt='Clipboard ❯ ') || exit 0
[[ -n $choice ]] || exit 0
restore "${choice%%$'\t'*}"
