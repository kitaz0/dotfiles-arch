#!/usr/bin/env bash
# Work around stale frames after resume on Hyprland 0.56 (upstream #15590).
set -euo pipefail
[[ ${XDG_CURRENT_DESKTOP:-} == Graphite:Hyprland ]] || exit 0
[[ -n ${WAYLAND_DISPLAY:-} && -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] || exit 0
# Wake first, then allow the panel to settle before refreshing renderer outputs.
# Keep the locker alive: this must never unlock or restart the session.
timeout 3s hyprctl dispatch 'hl.dsp.dpms({ action = "enable" })'
sleep 0.5
timeout 3s hyprctl dispatch 'hl.dsp.force_renderer_reload()'
