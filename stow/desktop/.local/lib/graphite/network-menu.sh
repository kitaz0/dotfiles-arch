#!/usr/bin/env bash
set -euo pipefail
if ! command -v nmcli >/dev/null || ! systemctl is-active --quiet NetworkManager.service; then
    notify-send 'Network' 'Manage connections with your existing network service; Graphite does not replace it.'
    exit 0
fi
export LC_ALL=C
radio=$(nmcli radio wifi)
if [[ $radio == enabled ]]; then target=off; else target=on; fi
labels=("Turn Wi-Fi $target" 'Advanced / add a network (nmtui)')
ids=()
active=$(nmcli -g UUID connection show --active)
connections=$(nmcli -g UUID connection show)
while IFS= read -r id; do
    [[ -n $id ]] || continue
    kind=$(nmcli -g connection.type connection show uuid "$id")
    [[ $kind == 802-11-wireless ]] || continue
    name=$(nmcli -g connection.id connection show uuid "$id")
    ids+=("$id")
    if grep -Fxq -- "$id" <<< "$active"; then
        ssid=$(nmcli -g 802-11-wireless.ssid connection show uuid "$id")
        label="CONNECTED: ${ssid//$'\n'/ }"
        device=$(nmcli -g GENERAL.DEVICES connection show uuid "$id")
        # Interface counters are cumulative, not live rates; tolerate hot-unplug.
        if [[ $device =~ ^[a-zA-Z0-9_.:-]+$ && $device != . && $device != .. ]]; then
            stats=/sys/class/net/$device/statistics
            if [[ -r $stats/rx_bytes && -r $stats/tx_bytes ]]; then
                rx=$(cat "$stats/rx_bytes" 2>/dev/null) || rx=
                tx=$(cat "$stats/tx_bytes" 2>/dev/null) || tx=
                if [[ $rx =~ ^[0-9]+$ && $tx =~ ^[0-9]+$ ]]; then
                    label+=" | Received $(numfmt --to=iec-i --suffix=B "$rx") / Sent $(numfmt --to=iec-i --suffix=B "$tx")"
                fi
            fi
        fi
        labels+=("$label")
    else
        labels+=("Connect: ${name//$'\n'/ }")
    fi
done <<< "$connections"
choice=$(printf '%s\n' "${labels[@]}" | fuzzel --config="$HOME/.config/graphite/fuzzel/fuzzel.ini" \
    --dmenu --index --anchor=top-right --prompt='Wi-Fi: ') || exit 0
[[ $choice =~ ^[0-9]+$ ]] || exit 0
case $choice in
    0) nmcli radio wifi "$target" ;;
    1) exec "$HOME/.local/lib/graphite/terminal.sh" -e nmtui ;;
    *)
        index=$((choice - 2))
        (( index < ${#ids[@]} )) || exit 1
        grep -Fxq -- "${ids[index]}" <<< "$active" && exit 0
        if ! nmcli --wait 15 connection up uuid "${ids[index]}"; then
            notify-send 'Wi-Fi connection failed' 'Use Advanced to enter credentials or inspect the connection.'
            exit 1
        fi
        ;;
esac
