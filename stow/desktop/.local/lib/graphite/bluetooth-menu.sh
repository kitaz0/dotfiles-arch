#!/usr/bin/env bash
# BlueZ owns devices and pairing state; no background scanner or pairing agent.
set -euo pipefail
export LC_ALL=C
if ! command -v bluetoothctl >/dev/null; then
    notify-send 'Bluetooth unavailable' 'Review the bluez and bluez-utils packages'
    exit 1
fi
if ! systemctl is-active --quiet bluetooth.service; then
    notify-send 'Bluetooth service is inactive' 'See docs/BLUETOOTH.md; Graphite does not start system services automatically'
    exit 1
fi
# BlueZ --timeout delays successful noninteractive commands too. Use an upper bound.
bt() {
    if timeout --kill-after=1s 10s bluetoothctl "$@"; then
        return 0
    else
        notify-send 'Bluetooth command failed' 'The adapter did not respond successfully. Check Bluetooth settings.'
        return 1
    fi
}
controllers=$(bt list)
count=$(grep -c '^Controller ' <<< "$controllers" || true)
if [[ $count == 0 ]]; then
    notify-send 'Bluetooth' 'No adapter found. Check the adapter and rfkill status.'
    exit 0
fi
if [[ $count != 1 ]]; then
    notify-send 'Bluetooth' 'Multiple adapters: select one explicitly in Bluetooth settings.'
    command -v kcmshell6 >/dev/null || exit 1
    exec kcmshell6 kcm_bluetooth
fi
state=$(bt show)
if grep -q 'Powered: yes' <<< "$state"; then power=off; else power=on; fi
labels=("Turn Bluetooth $power" 'Pair a new device (dialog)' 'Advanced Bluetooth settings')
addresses=() actions=()
devices=$(bt devices Paired)
connected=$(bt devices Connected)
while read -r marker address name; do
    [[ $marker == Device && $address =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || continue
    if grep -q "^Device $address " <<< "$connected"; then
        action=disconnect; label="CONNECTED: $name — disconnect"
    else
        action=connect; label="Connect: $name"
    fi
    addresses+=("$address"); actions+=("$action"); labels+=("$label")
done <<< "$devices"
choice=$(printf '%s\n' "${labels[@]}" | fuzzel --config="$HOME/.config/graphite/fuzzel/fuzzel.ini" \
    --dmenu --index --anchor=top-right --prompt='Bluetooth: ') || exit 0
case $choice in
    0)
        if ! bt power "$power"; then
            notify-send 'Bluetooth power change failed' 'Check rfkill status and the adapter in Bluetooth settings.'
            exit 1
        fi
        ;;
    1)
        command -v bluedevil-wizard >/dev/null || { notify-send 'Pairing unavailable' 'Review the bluedevil package'; exit 1; }
        exec bluedevil-wizard
        ;;
    2)
        command -v kcmshell6 >/dev/null || { notify-send 'Settings unavailable' 'Review bluedevil and kde-cli-tools'; exit 1; }
        exec kcmshell6 kcm_bluetooth
        ;;
    *)
        [[ $choice =~ ^[0-9]{1,3}$ ]] || exit 0
        index=$((10#$choice - 3))
        (( index >= 0 && index < ${#addresses[@]} )) || exit 0
        if ! bt "${actions[index]}" "${addresses[index]}"; then
            notify-send 'Bluetooth action failed' 'Check device power/range and use the pairing dialog if authentication is required.'
            exit 1
        fi
        ;;
esac
