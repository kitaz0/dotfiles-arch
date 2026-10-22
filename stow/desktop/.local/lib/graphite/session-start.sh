#!/usr/bin/env bash
set -euo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
[[ ${XDG_CURRENT_DESKTOP:-} == Graphite:Hyprland ]] || exit 1
[[ -n ${WAYLAND_DISPLAY:-} && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || { echo 'An active Graphite session is required' >&2; exit 1; }
# A watchdog restart has a new display/signature: replace only our previous group.
systemctl --user stop graphite-recorder.service graphite-session.service 2>/dev/null || true
systemctl --user reset-failed graphite-session.service 2>/dev/null || true
# Hyprland also imports these asynchronously. This synchronous barrier ensures
# activation sees the current display before helpers make their first D-Bus calls.
dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
envargs=()
for name in WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_ID XDG_RUNTIME_DIR HYPRLAND_INSTANCE_SIGNATURE XDG_CONFIG_HOME XDG_CONFIG_DIRS XDG_CACHE_HOME DBUS_SESSION_BUS_ADDRESS PATH LANG LANGUAGE XCURSOR_THEME XCURSOR_SIZE QT_IM_MODULE GTK_IM_MODULE XMODIFIERS; do
    [[ ! -v $name ]] || envargs+=(--setenv="$name=${!name}")
done
# Only Fcitx receives this session's XWayland display, never a stale manager value.
[[ ! -v DISPLAY ]] || envargs+=(--setenv="GRAPHITE_XWAYLAND_DISPLAY=$DISPLAY")
systemd-run --user --collect --unit=graphite-session --service-type=exec \
    --property=ExitType=cgroup --property=KillMode=control-group \
    --property=UnsetEnvironment=DISPLAY "${envargs[@]}" "$base/session-services.sh"
