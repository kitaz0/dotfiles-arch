#!/usr/bin/env bash
# Graphite-only idle policy. The hardware power profiles remain independent.
set -euo pipefail
export LC_ALL=C
umask 077
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
defaults="$HOME/.config/graphite/power/defaults.json"
settings="$HOME/.config/graphite/power/settings.json"
fail() { printf '%s\n' "$*" >&2; exit 1; }
session() {
    [[ ${XDG_CURRENT_DESKTOP:-} == Graphite:Hyprland && -n ${WAYLAND_DISPLAY:-} && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} && -n ${XDG_RUNTIME_DIR:-} ]] || fail 'An active Graphite session is required.'
}
validate() {
    jq -es '
        def delay: . as $v | [0,60,120,180,300,420,600,900,1800,2700,3600,7200] | index($v) != null;
        def policy: type == "object" and keys == ["lock","screenOff","suspend"]
            and (.lock | delay) and (.screenOff | delay) and (.suspend | delay);
        length == 1 and (.[0] | type == "object" and keys == ["battery","lockBeforeSleep","mains"]
        and (.mains | policy) and (.battery | policy) and (.lockBeforeSleep | type == "boolean"))
    ' >/dev/null
}
read_settings() {
    local file=$defaults
    [[ ! -e $settings ]] || file=$settings
    [[ -f $file ]] || fail 'Power defaults are missing. Refresh the desktop Stow links.'
    validate < "$file" || fail 'Invalid power settings. Restore valid delays or remove the local settings.json to use defaults.'
    cat -- "$file"
}
source_name() {
    local value
    value=$(busctl --system --timeout=2s get-property org.freedesktop.UPower /org/freedesktop/UPower org.freedesktop.UPower OnBattery 2>/dev/null) || value=
    if [[ $value == 'b true' ]]; then echo battery; else echo mains; fi
}
render() {
    local preferences policy lock off suspend before inhibit
    preferences=$(read_settings) || return 1
    policy=$(source_name)
    IFS=$'\t' read -r lock off suspend before < <(jq -r --arg source "$policy" '[.[$source].lock,.[$source].screenOff,.[$source].suspend,.lockBeforeSleep] | @tsv' <<< "$preferences") || return 1
    inhibit=0
    [[ $before != true ]] || inhibit=3
    printf '# Generated from Graphite power settings; all delays are since last activity.\n'
    printf 'source = ~/.config/graphite/hypr/hypridle.conf\ngeneral {\n'
    printf '    before_sleep_cmd = %s\n    inhibit_sleep = %s\n}\n' "$(if [[ $before == true ]]; then echo '~/.local/lib/graphite/power-policy.sh lock'; fi)" "$inhibit"
    if (( lock )); then
        printf 'listener {\n    timeout = %s\n    on-timeout = ~/.local/lib/graphite/power-policy.sh lock\n}\n' "$lock"
    fi
    if (( off )); then
        printf 'listener {\n    timeout = %s\n' "$off"
        printf '%s\n' "    on-timeout = hyprctl dispatch 'hl.dsp.dpms({ action = \"disable\" })'" "    on-resume = hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })'" '}'
    fi
    if (( suspend )); then
        printf 'listener {\n    timeout = %s\n    on-timeout = systemctl suspend\n}\n' "$suspend"
    fi
    # Hypridle requires at least one listener even for pre-suspend hooks alone.
    if (( lock == 0 && off == 0 && suspend == 0 )); then
        printf 'listener {\n    timeout = 86400\n    on-timeout = true\n}\n'
    fi
}
start() {
    session
    systemctl --user is-active --quiet graphite-power.service && return 0
    systemctl --user is-active --quiet graphite-session.service || fail 'Graphite session helpers are not active.'
    read_settings >/dev/null
    [[ -f $HOME/.config/graphite/hypr/hypridle.conf ]] || fail 'Idle hooks are missing. Refresh the desktop Stow links.'
    systemd-run --user --collect --unit=graphite-power --service-type=exec \
        --property=PartOf=graphite-session.service --property=After=graphite-session.service \
        --property=KillMode=control-group --property=Restart=on-failure --property=RestartSec=3 \
        --property=UnsetEnvironment=DISPLAY \
        --setenv="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" --setenv="HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE" \
        --setenv="XDG_CURRENT_DESKTOP=$XDG_CURRENT_DESKTOP" \
        "$base/power-policy.sh" run
    # Migrate a running pre-policy Graphite session without touching foreign idle daemons.
    local proc args
    for proc in /proc/[0-9]*; do
        [[ -O $proc && -r $proc/cmdline && -r $proc/cgroup ]] || continue
        args=()
        mapfile -d '' -t args < "$proc/cmdline" 2>/dev/null || continue
        [[ ${args[0]:-} == */hypridle || ${args[0]:-} == hypridle ]] || continue
        [[ ${args[1]:-} == -c && ${args[2]:-} == "$HOME/.config/graphite/hypr/hypridle.conf" ]] || continue
        grep -q '/graphite-session.service$' "$proc/cgroup" || continue
        kill -TERM "${proc##*/}" 2>/dev/null || true
    done
}
case ${1:-settings} in
    --help|-h)
        echo 'Usage: power-policy.sh [settings|defaults|save JSON|render|start|reload|lock]'
        echo 'Separate battery/mains idle delays: Never or 1, 2, 3, 5, 7, 10, 15, 30, 45, 60, 120 minutes.'
        echo 'Defaults: lock after 5 minutes, screen off after 7, no automatic suspend, lock before sleep.'
        echo 'Local choices: ~/.config/graphite/power/settings.json; repository defaults: power/defaults.json.'
        echo 'Reload affects only Graphite idle handling. Performance profiles and lid policy are separate.'
        ;;
    settings) read_settings ;;
    defaults) validate < "$defaults" && cat -- "$defaults" ;;
    render) render ;;
    save)
        session
        validate <<< "${2:-}" || fail 'Invalid power settings; nothing saved.'
        [[ ! -L $settings ]] || fail 'Local power settings must be a regular file, not a symlink.'
        mkdir -p -- "$(dirname -- "$settings")"
        temporary=$(mktemp "$(dirname -- "$settings")/.settings.XXXXXX")
        trap 'rm -f -- "$temporary"' EXIT
        jq . <<< "$2" > "$temporary"
        mv -- "$temporary" "$settings"
        "$base/power-policy.sh" reload || fail 'Settings saved, but idle handling could not be reloaded. Try power-policy.sh reload.'
        ;;
    start) start ;;
    reload)
        session
        if systemctl --user is-active --quiet graphite-power.service; then
            systemctl --user kill --kill-whom=main --signal=HUP graphite-power.service
        else start; fi
        ;;
    lock)
        session
        # Keep the locker outside the idle service: reloading policies must never unlock.
        systemctl --user is-active --quiet graphite-lock.service && exit 0
        systemd-run --user --collect --unit=graphite-lock --service-type=exec \
            --property=PartOf=graphite-session.service --property=After=graphite-session.service \
            --property=UnsetEnvironment=DISPLAY \
            --setenv="WAYLAND_DISPLAY=$WAYLAND_DISPLAY" --setenv="HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE" \
            "$base/lock.sh"
        ;;
    run)
        session
        [[ -n ${INVOCATION_ID:-} ]] || fail 'Launch through power-policy.sh start.'
        idle_pid= monitor_pid= reload_requested=0
        runtime="$XDG_RUNTIME_DIR/graphite-hypridle.conf"
        cleanup() {
            [[ -z $idle_pid ]] || kill "$idle_pid" 2>/dev/null || true
            [[ -z $monitor_pid ]] || kill "$monitor_pid" 2>/dev/null || true
            wait 2>/dev/null || true
            rm -f -- "$runtime"
        }
        refresh_idle() {
            local temporary previous
            temporary=$(mktemp "$XDG_RUNTIME_DIR/graphite-idle.XXXXXX")
            if ! render > "$temporary"; then rm -f -- "$temporary"; return 1; fi
            if [[ -n $idle_pid ]] && kill -0 "$idle_pid" 2>/dev/null && cmp -s "$temporary" "$runtime"; then
                rm -f -- "$temporary"; return 0
            fi
            mv -- "$temporary" "$runtime"
            if [[ -n $idle_pid ]]; then
                # The old screen-off listener owns its resume callback. Wake before
                # replacing it so a policy change cannot leave the display asleep.
                timeout 3s hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })' >/dev/null 2>&1 || true
                previous=$idle_pid; idle_pid=
                kill "$previous" 2>/dev/null || true
                wait "$previous" 2>/dev/null || true
            fi
            hypridle -c "$runtime" 3<&- &
            idle_pid=$!
        }
        trap cleanup EXIT
        trap 'exit 0' TERM INT
        # Do not perform nested reads inside the signal trap: they can corrupt an
        # interrupted read's IFS and timeout. Apply at the next bounded loop turn.
        trap 'reload_requested=1' HUP
        # Power source changes come from UPower events, rather than polling its properties.
        exec 3< <(if command -v upower >/dev/null; then exec stdbuf -oL upower --monitor; else exec sleep infinity; fi)
        monitor_pid=$!
        refresh_idle
        while true; do
            if (( reload_requested )); then
                reload_requested=0
                refresh_idle || echo 'Power policy reload failed; previous idle daemon preserved.' >&2
            fi
            if ! kill -0 "$idle_pid" 2>/dev/null; then
                idle_pid=
                fail 'Hypridle exited; restarting power policy.'
            fi
            # Bound only the child-health wait; do not poll UPower properties.
            if IFS= read -r -t 2 event <&3; then
                [[ $event != *'daemon changed'* ]] || refresh_idle || echo 'Power policy reload failed; previous idle daemon preserved.' >&2
            else
                code=$?
                (( code > 128 )) && continue
                fail 'UPower monitor disconnected; restarting power policy.'
            fi
        done
        ;;
    *) fail 'Unknown power-policy command. Use --help.' ;;
esac
