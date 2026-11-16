#!/usr/bin/env bash
set -euo pipefail
umask 077
usage() {
    cat <<'HELP'
Usage: record.sh [start|toggle [region|full|window]|stop|status]

Default: toggle region recording. Full records the focused monitor.
Window records the active window's initial visible rectangle on its monitor;
it does not follow the window if it moves. All modes share one recorder.
Toggle stops any current recording; it never switches modes in one invocation.
Start refuses while another recording is active or still stopping.
Quick recordings have no audio and are saved in ~/Videos/Recordings/.
    --help, -h       Show this help without contacting systemd
HELP
}
action=${1:-toggle}
mode=${2:-region}
case $action in
    --help|-h) usage; exit 0 ;;
    start|toggle) (( $# <= 2 )) || { usage >&2; exit 2; } ;;
    stop|status) (( $# <= 1 )) || { usage >&2; exit 2; } ;;
    *) usage >&2; exit 2 ;;
esac
case $mode in region|full|window) ;; *) usage >&2; exit 2 ;; esac
case $mode in
    region) label='Region recording' ;;
    full) label='Full-screen recording' ;;
    window) label='Window recording' ;;
esac
unit=graphite-recorder.service
current_label() {
    local description
    description=$(systemctl --user show "$unit" --property=Description --value 2>/dev/null) || description=''
    case $description in
        'Region recording'|'Full-screen recording'|'Window recording') printf '%s' "$description" ;;
        *) printf '%s' 'Recording' ;;
    esac
}
stop_recording() {
    local recording
    recording=$(current_label)
    systemctl --user stop "$unit"
    notify-send "$recording stopped" 'Saved in ~/Videos/Recordings'
}
if [[ $action == status ]]; then systemctl --user status "$unit" --no-pager; exit; fi
exec 9>"${XDG_RUNTIME_DIR:?}/graphite-record.guard"
flock -n 9 || exit 0
if [[ $action == stop ]]; then stop_recording; exit; fi
state=$(systemctl --user show "$unit" --property=ActiveState --value 2>/dev/null) || state=inactive
case $state in
    active|activating|reloading|refreshing)
        if [[ $action == start ]]; then
            notify-send "$(current_label) already running" 'Stop the current recording before starting another mode.'
            exit 1
        fi
        stop_recording
        exit ;;
    deactivating)
        notify-send "$(current_label) is finishing" 'Wait for the current recording to finish before starting another.'
        exit 1 ;;
    inactive|failed|'') ;;
    *) echo "Recorder state is unavailable: $state" >&2; exit 1 ;;
esac
systemctl --user is-active --quiet graphite-session.service || { echo 'Graphite helpers must be active before recording' >&2; exit 1; }
commands=(wf-recorder)
if [[ $mode == region ]]; then commands+=(slurp); else commands+=(hyprctl jq); fi
for command in "${commands[@]}"; do
    command -v "$command" >/dev/null || { notify-send 'Recording unavailable' "Install recommended capture dependencies: $command missing"; exit 1; }
done
helpers=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
args=()
if [[ $mode == region ]]; then
    geometry=$(slurp) || exit 0
    [[ -n $geometry ]] || exit 0
else
    target=$(bash "$helpers/capture-target.sh" "$mode") || { notify-send 'Recording unavailable' 'No visible capture target could be found'; exit 1; }
    output=$(jq -er .output <<< "$target")
    args=(-o "$output")
    geometry=''
    [[ $mode != window ]] || geometry=$(jq -er .geometry <<< "$target")
fi
if [[ -n $geometry ]]; then
    [[ $geometry =~ ^-?[0-9]+,-?[0-9]+\ ([1-9][0-9]*)x([1-9][0-9]*)$ ]] || { echo 'Invalid recording geometry' >&2; exit 1; }
    args+=(-g "$geometry")
fi
mkdir -p -- "$HOME/Videos/Recordings"
file=$(mktemp "$HOME/Videos/Recordings/$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.mkv")
# -y applies only to the unique empty file we just reserved with mktemp.
systemctl --user reset-failed "$unit" 2>/dev/null || true
if ! systemd-run --user --collect --unit=graphite-recorder --service-type=exec --description="$label" \
    --property=KillSignal=SIGINT --property=TimeoutStopSec=30 \
    --property=PartOf=graphite-session.service --property=After=graphite-session.service \
    --setenv="WAYLAND_DISPLAY=${WAYLAND_DISPLAY:?}" --setenv="XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
    wf-recorder -y "${args[@]}" -c libx264 -p preset=ultrafast -p crf=23 -f "$file" 9>&-; then
    [[ -s $file ]] || rm -f -- "$file"
    exit 1
fi
notify-send "$label started" 'Press any quick-record shortcut to stop and finalize. No audio.'
