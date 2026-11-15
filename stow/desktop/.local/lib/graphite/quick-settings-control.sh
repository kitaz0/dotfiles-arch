#!/usr/bin/env bash
# JSON snapshots and explicitly allowlisted actions for the on-demand popup.
# Arguments are data, never shell/Lua code. Queries do not activate system services.
set -euo pipefail
export LC_ALL=C
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fail() { printf '%s\n' "$*" >&2; exit 1; }
bt() { timeout --kill-after=1s 5s bluetoothctl "$@"; }
one_adapter() {
    systemctl is-active --quiet bluetooth.service || fail 'Bluetooth service is inactive; see docs/BLUETOOTH.md.'
    local controllers
    controllers=$(bt list)
    [[ $(grep -c '^Controller ' <<< "$controllers" || true) == 1 ]] || fail 'Use advanced Bluetooth settings to select an adapter (zero or multiple adapters found).'
}
network_manager() {
    command -v nmcli >/dev/null && systemctl is-active --quiet NetworkManager.service || fail 'Wi-Fi controls require your existing NetworkManager service.'
}
percent() { [[ ${1:-} =~ ^[0-9]{1,3}$ ]] && (( 10#$1 <= 100 )); }
power_profile_service() {
    command -v powerprofilesctl >/dev/null || return 1
    local service owner
    for service in org.freedesktop.UPower.PowerProfiles net.hadess.PowerProfiles; do
        owner=$(busctl --system --timeout=2s call org.freedesktop.DBus /org/freedesktop/DBus \
            org.freedesktop.DBus NameHasOwner s "$service" 2>/dev/null) || continue
        [[ $owner != 'b true' ]] || return 0
    done
    return 1
}
case ${1:-} in
    power-profiles)
        active=; profiles=()
        if power_profile_service; then
            active=$(timeout 2s powerprofilesctl get) || fail 'Cannot read the active power profile.'
            raw=$(timeout 2s powerprofilesctl list) || fail 'Cannot list power profiles.'
            while IFS= read -r line; do
                if [[ $line =~ ^[[:space:]]*\*?[[:space:]]*(power-saver|balanced|performance):[[:space:]]*$ ]]; then
                    profiles+=("${BASH_REMATCH[1]}")
                fi
            done <<< "$raw"
        fi
        printf '%s\n' "${profiles[@]}" | jq -Rs --arg active "$active" \
            '{active:$active,profiles:(split("\n")|map(select(length>0)))}'
        ;;
    power-profile)
        case ${2:-} in power-saver|balanced|performance) ;; *) fail 'Invalid power profile.' ;; esac
        power_profile_service || fail 'No active power profile service is available.'
        timeout 5s powerprofilesctl set "$2"
        ;;
    backlight)
        raw=$(brightnessctl -c backlight -m info 2>/dev/null) || raw=
        while IFS=, read -r device class current value maximum; do
            if [[ $class == backlight && $device =~ ^[a-zA-Z0-9_.:-]+$ && $device != . && $device != .. && $maximum =~ ^[0-9]+$ ]]; then
                jq -n --arg device "$device" --argjson maximum "$maximum" '{device:$device,maximum:$maximum}'
                exit 0
            fi
        done <<< "$raw"
        printf '%s\n' '{"device":"","maximum":0}'
        ;;
    levels)
        volume=null; muted=false; brightness=null; mic=null
        raw=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || raw=
        if [[ $raw =~ ^Volume:\ ([0-9]+\.[0-9]+) ]]; then
            volume=$(awk -v v="${BASH_REMATCH[1]}" 'BEGIN { printf "%d", v * 100 + 0.5 }')
            [[ $raw != *'[MUTED]'* ]] || muted=true
        fi
        raw=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null) || raw=
        if [[ $raw =~ ^Volume:\ ([0-9]+\.[0-9]+) ]]; then
            mic=false
            [[ $raw != *'[MUTED]'* ]] || mic=true
        fi
        raw=$(brightnessctl -c backlight -m info 2>/dev/null) || raw=
        while IFS=, read -r device class current value maximum; do
            if [[ $class == backlight && $value =~ ^([0-9]{1,3})%$ ]]; then
                brightness=$((10#${BASH_REMATCH[1]})); break
            fi
        done <<< "$raw"
        jq -n --argjson volume "$volume" --argjson muted "$muted" --argjson mic "$mic" --argjson brightness "$brightness" \
            '{volume:$volume, muted:$muted, mic:$mic, brightness:$brightness}'
        ;;
    wifi)
        network_manager
        radio=$(nmcli radio wifi)
        active=$(nmcli -g UUID connection show --active)
        profiles=$(nmcli -t -f UUID,TYPE connection show)
        rows=()
        while IFS=: read -r id kind; do
            [[ $kind == 802-11-wireless && $id =~ ^[[:xdigit:]-]{36}$ ]] || continue
            name=$(nmcli -g 802-11-wireless.ssid connection show uuid "$id")
            connected=false
            grep -Fxq -- "$id" <<< "$active" && connected=true
            rows+=("$(jq -n --arg id "$id" --arg name "$name" --argjson connected "$connected" '{id:$id,name:$name,connected:$connected}')")
        done <<< "$profiles"
        printf '%s\n' "${rows[@]}" | jq -s --arg radio "$radio" '{enabled:($radio=="enabled"),items:.}'
        ;;
    bluetooth)
        one_adapter
        state=$(bt show); paired=$(bt devices Paired); connected=$(bt devices Connected)
        rows=()
        while read -r marker address name; do
            [[ $marker == Device && $address =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || continue
            online=false
            grep -q "^Device $address " <<< "$connected" && online=true
            rows+=("$(jq -n --arg id "$address" --arg name "$name" --argjson connected "$online" '{id:$id,name:$name,connected:$connected}')")
        done <<< "$paired"
        printf '%s\n' "${rows[@]}" | jq -s --arg state "$state" '{enabled:($state|contains("Powered: yes")),items:.}'
        ;;
    audio)
        sinks=$(pactl --format=json list sinks); sources=$(pactl --format=json list sources)
        sink=$(pactl get-default-sink); source=$(pactl get-default-source)
        jq -n --argjson sinks "$sinks" --argjson sources "$sources" --arg sink "$sink" --arg source "$source" \
            '{items:([$sinks[]|{id:.name,name:("Output: " + .description),kind:"sink",connected:(.name==$sink)}] + [$sources[]|select(.monitor_of_sink == null or .monitor_of_sink == 4294967295)|{id:.name,name:("Microphone: " + .description),kind:"source",connected:(.name==$source)}])}'
        ;;
    displays)
        hyprctl -j monitors all | jq '{items:[.[]|{id:.name,hyprId:.id,name:(.description // .name),disabled:(.disabled // false),mirrorOf:(.mirrorOf // "none"),x:(.x // 0),y:(.y // 0)}]}'
        ;;
    bt-operation)
        systemctl is-active --quiet bluetooth.service || fail 'Bluetooth service is inactive.'
        method=${2:-}; path=${3:-}
        case $method in
            on|off)
                [[ $path =~ ^/org/bluez/hci[0-9]+$ ]] || fail 'Invalid adapter path.'
                value=true; [[ $method != off ]] || value=false
                busctl --system --timeout=10s set-property org.bluez "$path" org.bluez.Adapter1 Powered b "$value"
                ;;
            connect|disconnect|forget)
                [[ $path =~ ^/org/bluez/hci[0-9]+/dev_([[:xdigit:]]{2}_){5}[[:xdigit:]]{2}$ ]] || fail 'Invalid device path.'
                case $method in
                    connect) busctl --system --timeout=20s call org.bluez "$path" org.bluez.Device1 Connect ;;
                    disconnect) busctl --system --timeout=20s call org.bluez "$path" org.bluez.Device1 Disconnect ;;
                    forget) busctl --system --timeout=20s call org.bluez "${path%/*}" org.bluez.Adapter1 RemoveDevice o "$path" ;;
                esac
                ;;
            *) fail 'Unknown Bluetooth operation.' ;;
        esac
        ;;
    volume)
        percent "${2:-}" || fail 'Invalid volume percentage.'
        wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ "$((10#$2))%"
        ;;
    brightness)
        percent "${2:-}" && (( 10#$2 >= 5 )) || fail 'Brightness must be between 5 and 100 percent.'
        # brightnessctl reports missing hardware/access as an error; never chmod DRM/backlight nodes.
        brightnessctl -c backlight --min-value=1 set "$((10#$2))%"
        ;;
    mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    mic) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
    wifi-power)
        network_manager
        [[ ${2:-} == on || ${2:-} == off ]] || exit 2
        nmcli radio wifi "$2"
        ;;
    wifi-connect)
        network_manager
        [[ ${2:-} =~ ^[[:xdigit:]-]{36}$ ]] || exit 2
        nmcli --wait 15 connection up uuid "$2"
        ;;
    bluetooth-power)
        one_adapter
        [[ ${2:-} == on || ${2:-} == off ]] || exit 2
        bt power "$2"
        ;;
    bluetooth-connect|bluetooth-disconnect)
        one_adapter
        [[ ${2:-} =~ ^([[:xdigit:]]{2}:){5}[[:xdigit:]]{2}$ ]] || exit 2
        timeout --kill-after=1s 15s bluetoothctl "${1#bluetooth-}" "$2"
        ;;
    sink|source)
        [[ -n ${2:-} && $2 != -* ]] || exit 2
        pactl "set-default-$1" "$2"
        ;;
    display-right|display-left|display-mirror|display-only|display-other)
        [[ ${2:-} =~ ^[a-zA-Z0-9_.-]+$ ]] || exit 2
        exec bash "$base/display-menu.sh" "${1#display-}" "$2"
        ;;
    *) fail 'Unknown quick-settings operation.' ;;
esac
