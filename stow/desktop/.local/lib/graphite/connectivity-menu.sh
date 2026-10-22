#!/usr/bin/env bash
set -euo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
choice=$(printf '%s\n' 'Wi-Fi / network' 'Bluetooth' | \
    fuzzel --config="$HOME/.config/graphite/fuzzel/fuzzel.ini" --dmenu --index \
        --anchor=top-right --prompt='Connectivity: ') || exit 0
case $choice in
    0) exec "$base/network-menu.sh" ;;
    1) exec "$base/bluetooth-menu.sh" ;;
esac
