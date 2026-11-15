#!/usr/bin/env bash
# A separate transient service follows Graphite's lifetime, never Plasma's.
set -euo pipefail
fail() { echo "$*" >&2; exit 1; }
session() {
    [[ ${XDG_CURRENT_DESKTOP:-} == Graphite:Hyprland && -n ${WAYLAND_DISPLAY:-} && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || fail 'An active Graphite session is required.'
}
active() { systemctl --user is-active --quiet graphite-night-light.service; }
start() {
    session
    command -v hyprsunset >/dev/null || return 0
    active && return 0
    systemctl --user is-active --quiet graphite-session.service || fail 'Graphite session helpers are not active.'
    ! pgrep -u "$UID" -x hyprsunset >/dev/null || fail 'An existing Hyprsunset instance is preserved; Graphite will not replace it.'
    systemd-run --user --collect --unit=graphite-night-light --service-type=exec \
        --property=PartOf=graphite-session.service --property=After=graphite-session.service \
        --property=UnsetEnvironment=DISPLAY \
        --setenv="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" \
        --setenv="HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE" \
        --setenv="XDG_CONFIG_HOME=$HOME/.config/graphite" \
        hyprsunset --identity --temperature 4500
}
ipc() { timeout 1s hyprctl hyprsunset "$@"; }
case ${1:-status} in
    --help|-h)
        echo 'Usage: night-light.sh [start|status|on|off|temperature K]'
        echo 'Night Light starts off. Temperature range: 2500–6500 K; lower is warmer.'
        echo 'Its service stops with Graphite; an existing foreign instance is preserved.'
        ;;
    start) start ;;
    status)
        installed=false; available=false; enabled=false; temperature=4500
        command -v hyprsunset >/dev/null && installed=true
        if [[ ${XDG_CURRENT_DESKTOP:-} == Graphite:Hyprland && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && $installed && active; then
            identity=$(ipc identity get 2>/dev/null) || identity=
            value=$(ipc temperature 2>/dev/null) || value=
            if [[ $identity == true || $identity == false ]] && [[ $value =~ ^[0-9]{4,5}$ ]] && (( value >= 1000 && value <= 20000 )); then
                available=true; temperature=$value
                [[ $identity != false ]] || enabled=true
            fi
        fi
        printf '{"installed":%s,"available":%s,"enabled":%s,"temperature":%s}\n' "$installed" "$available" "$enabled" "$temperature"
        ;;
    on|off|temperature)
        session
        command -v hyprsunset >/dev/null || fail 'Install hyprsunset to use Night Light.'
        if [[ $1 == temperature ]]; then
            [[ ${2:-} =~ ^[0-9]{4}$ ]] && (( 10#$2 >= 2500 && 10#$2 <= 6500 )) || fail 'Temperature must be between 2500 and 6500 K.'
        fi
        if [[ $1 == off ]] && ! active; then exit 0; fi
        if ! active; then
            start
            for attempt in {1..10}; do
                ipc identity get >/dev/null 2>&1 && break
                sleep 0.1
            done
        fi
        case $1 in
            on) ipc identity false ;;
            off) ipc identity ;;
            temperature) ipc temperature "$2" ;;
        esac
        ;;
    *) fail 'Usage: night-light.sh [start|status|on|off|temperature K]' ;;
esac
