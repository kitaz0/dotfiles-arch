#!/usr/bin/env bash
# Explicit user-wide portal preference, never run automatically at login.
set -euo pipefail
umask 077
schema=org.gnome.desktop.interface
key=color-scheme
state="${XDG_STATE_HOME:-$HOME/.local/state}/graphite/appearance"
case ${1:-status} in status|dark|restore) ;; *) echo 'Usage: appearance.sh [status|dark|restore]' >&2; exit 2 ;; esac
current=$(gsettings get "$schema" "$key")
if [[ ${1:-status} == status ]]; then
    printf 'Portal color preference: %s\n' "$current"
    exit 0
fi
mkdir -p -- "$state"
exec 9>"$state/lock"
flock -n 9 || { echo 'Appearance change already running' >&2; exit 1; }
backup="$state/color-scheme.before"
[[ ! -L $backup ]] || { echo 'Refusing symlinked preference backup' >&2; exit 1; }
if [[ $1 == dark ]]; then
    current=$(gsettings get "$schema" "$key")
    # Do not replace the original backup on repeated application.
    if [[ ! -e $backup ]]; then
        staging=$(mktemp "$state/.before-XXXXXX")
        trap 'rm -f -- "$staging"' EXIT
        printf '%s\n' "$current" > "$staging"
        mv -- "$staging" "$backup"
    fi
    gsettings set "$schema" "$key" prefer-dark
    echo 'Dark preference enabled for this user; restart applications that cache it.'
else
    [[ -f $backup ]] || { echo 'No saved appearance preference'; exit 0; }
    before=$(<"$backup")
    case $before in "'default'"|"'prefer-dark'"|"'prefer-light'") ;; *) echo 'Invalid preference backup' >&2; exit 1 ;; esac
    current=$(gsettings get "$schema" "$key")
    [[ $current == "'prefer-dark'" || $current == "$before" ]] || { echo 'CONFLICT: preference changed since application; leaving it untouched' >&2; exit 1; }
    gsettings set "$schema" "$key" "$before"
    rm -- "$backup"
    echo 'Previous color preference restored.'
fi
