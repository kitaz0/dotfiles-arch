#!/usr/bin/env bash
set -euo pipefail
umask 077
unit=graphite-recorder.service
action=${1:-toggle}
exec 9>"${XDG_RUNTIME_DIR:?}/graphite-record.guard"
flock -n 9 || exit 0
active() { systemctl --user is-active --quiet "$unit"; }
case $action in
    status) systemctl --user status "$unit" --no-pager; exit ;;
    stop) systemctl --user stop "$unit"; exit ;;
    toggle) if active; then systemctl --user stop "$unit"; notify-send 'Recording stopped' 'Saved in ~/Videos/Recordings'; exit; fi ;;
    start) if active; then echo 'Already recording' >&2; exit 1; fi ;;
    *) echo 'Usage: record.sh start|stop|toggle|status' >&2; exit 2;;
esac
active && exit 0
systemctl --user is-active --quiet graphite-session.service || { echo 'Graphite helpers must be active before recording' >&2; exit 1; }
for command in slurp wf-recorder; do
    command -v "$command" >/dev/null || { notify-send 'Recording unavailable' "Install recommended capture dependencies: $command missing"; exit 1; }
done
geometry=$(slurp) || exit 0
[[ -n $geometry ]] || exit 0
mkdir -p -- "$HOME/Videos/Recordings"
file=$(mktemp "$HOME/Videos/Recordings/$(date +%Y-%m-%d_%H-%M-%S)-XXXXXX.mkv")
# -y applies only to the unique empty file we just reserved with mktemp.
systemctl --user reset-failed "$unit" 2>/dev/null || true
if ! systemd-run --user --collect --unit=graphite-recorder --service-type=exec \
    --property=KillSignal=SIGINT --property=TimeoutStopSec=30 \
    --property=PartOf=graphite-session.service --property=After=graphite-session.service \
    --setenv="WAYLAND_DISPLAY=${WAYLAND_DISPLAY:?}" --setenv="XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR" \
    wf-recorder -y -g "$geometry" -c libx264 -p preset=ultrafast -p crf=23 -f "$file"; then
    [[ -s $file ]] || rm -f -- "$file"
    exit 1
fi
notify-send 'Recording started' 'Super+Shift+R stops and finalizes it. Quick recording has no audio.'
