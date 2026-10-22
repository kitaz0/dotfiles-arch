#!/usr/bin/env bash
# Observe processed udev events only. Never mount, unmount or change device policy.
set -euo pipefail
action= bus= kind=
udevadm monitor --udev --property --subsystem-match=block | while IFS= read -r line; do
    case $line in
        ACTION=*) action=${line#ACTION=} ;;
        ID_BUS=*) bus=${line#ID_BUS=} ;;
        DEVTYPE=*) kind=${line#DEVTYPE=} ;;
        '')
            if [[ $action == add && $bus == usb && $kind == disk ]]; then
                notify-send -a Graphite -i drive-removable-media 'USB drive connected' \
                    'Open Dolphin (Super+E). Use Safely Remove in its Places sidebar before unplugging.' || true
            fi
            action= bus= kind=
            ;;
    esac
done
