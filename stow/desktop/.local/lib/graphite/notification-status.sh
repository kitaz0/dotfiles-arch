#!/usr/bin/env bash
# One event stream; opening the notification center acknowledges new arrivals.
set -euo pipefail
umask 077
case ${1:-watch} in
    --help|-h) echo 'Usage: notification-status.sh [watch]'; exit 0 ;;
    watch) ;;
    *) echo 'Usage: notification-status.sh [watch]' >&2; exit 2 ;;
esac
(( $# <= 1 )) || exit 2
state="${XDG_RUNTIME_DIR:?}/graphite-notifications.state"
previous=0 unread=false
if [[ -f $state && ! -L $state && -O $state ]]; then
    read -r previous unread < "$state" || true
    [[ $previous =~ ^[0-9]+$ && $unread =~ ^(true|false)$ ]] || { previous=0; unread=false; }
fi
coproc EVENTS { exec swaync-client --skip-wait --subscribe; }
subscriber=$EVENTS_PID
exec 8<&"${EVENTS[0]}"
cleanup() {
    kill "$subscriber" 2>/dev/null || true
    wait "$subscriber" 2>/dev/null || true
}
trap cleanup EXIT
trap 'exit 0' INT TERM
while IFS= read -r line <&8; do
    fields=$(jq -er 'select((.count | type) == "number" and .count >= 0 and .count == (.count | floor)) |
        select((.visible | type) == "boolean" and (.dnd | type) == "boolean" and (.inhibited | type) == "boolean") |
        [.count, .visible, .dnd, .inhibited] | @tsv' <<< "$line") || continue
    IFS=$'\t' read -r count visible dnd inhibited <<< "$fields"
    before="$previous $unread"
    if [[ $visible == true || $count == 0 ]]; then
        unread=false
    elif (( count > previous )); then
        unread=true
    fi
    previous=$count
    if [[ "$previous $unread" != "$before" ]]; then
        temporary=$(mktemp "${XDG_RUNTIME_DIR}/graphite-notifications-XXXXXX")
        printf '%s %s\n' "$previous" "$unread" > "$temporary"
        mv -f -- "$temporary" "$state"
    fi
    alt=none
    $unread && alt=notification
    $inhibited && alt="inhibited-$alt"
    $dnd && alt="dnd-$alt"
    jq -cn --arg text "$count" --arg alt "$alt" --argjson unread "$unread" \
        '{text:$text, alt:$alt, class:([$alt] + if $unread then ["unread"] else [] end)}'
done
# Let Waybar restart the subscriber when the daemon disconnects.
exit 1
