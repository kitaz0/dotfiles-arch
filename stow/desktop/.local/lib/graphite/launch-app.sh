#!/usr/bin/env bash
# Fuzzel's argv prefix: only Dolphin needs a private application profile.
set -euo pipefail
(( $# )) || exit 2
if [[ ${1##*/} == dolphin ]]; then
    shift
    exec "$HOME/.local/lib/graphite/dolphin.sh" "$@"
fi
exec "$@"
