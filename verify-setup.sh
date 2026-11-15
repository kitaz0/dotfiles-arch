#!/usr/bin/env bash
# Read-only diagnostics. Never start services, launch panels, lock or suspend.
set -uo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
verbose=0 desktop_only=0
for arg in "$@"; do
    case $arg in
        --verbose) verbose=1 ;;
        --desktop-only) desktop_only=1 ;;
        --help|-h)
            echo 'Usage: bash verify-setup.sh [--verbose] [--desktop-only]'
            echo 'Read-only Stow links, dependencies, config, power-policy and session checks.'
            echo 'Default: desktop, Kitty, Starship, LazyVim, VS Code, Fastfetch and btop. --desktop-only omits application packages.'
            echo '--verbose prints full diagnostics. Exit 1: required check failed; exit 2: invalid arguments.'
            exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done
passed=0 failed=0 warned=0 skipped=0
report() {
    local level=$1 label=$2 details=${3:-} line count=0
    case $level in
        PASS) (( passed += 1 )) ;;
        FAIL) (( failed += 1 )) ;;
        WARN) (( warned += 1 )) ;;
        SKIP) (( skipped += 1 )) ;;
    esac
    printf '%-4s %s\n' "$level" "$label"
    if [[ -n $details ]] && { (( verbose )) || [[ $level == FAIL || $level == WARN ]]; }; then
        while IFS= read -r line; do
            if (( ! verbose && count >= 8 )); then
                echo '     … more details available with --verbose'
                break
            fi
            printf '     %s\n' "$line"
            (( count += 1 ))
        done <<< "$details"
    fi
}
probe() {
    local label=$1 severity=$2 output
    shift 2
    if output=$("$@" 2>&1); then report PASS "$label" "$output"
    else report "$severity" "$label" "$output"; fi
}
missing=()
for cmd in bash flock timeout qs systemctl systemd-run dbus-update-activation-environment busctl pgrep jq stow git readlink find \
    start-hyprland Hyprland hyprctl kitty dolphin waybar fuzzel swaybg hyprlock hypridle \
    swaync swaync-client cliphist wl-copy wl-paste wpctl udisksctl udevadm fc-match notify-send; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
done
[[ -x /usr/lib/hyprpolkitagent/hyprpolkitagent ]] || missing+=(/usr/lib/hyprpolkitagent/hyprpolkitagent)
if (( ${#missing[@]} )); then report FAIL 'Required dependencies' "Missing: ${missing[*]}"
else report PASS 'Required dependencies'; fi
missing=()
for cmd in grim slurp satty wf-recorder ffprobe pavucontrol pactl playerctl brightnessctl wdisplays \
    bluetoothctl bluedevil-wizard kcmshell6 nmcli nmtui fcitx5 fcitx5-remote fcitx5-configtool; do
    command -v "$cmd" >/dev/null || missing+=("$cmd")
done
if (( ${#missing[@]} )); then report WARN 'Optional feature dependencies' "Unavailable controls: ${missing[*]}"
else report PASS 'Optional feature dependencies'; fi
file_errors=() script_errors=() link_errors=() total=0
packages=(desktop)
(( desktop_only )) || packages+=(kitty starship nvim vscode fastfetch btop)
for package in "${packages[@]}"; do
    if [[ ! -d $base/stow/$package ]]; then file_errors+=("Missing source package: $package"); continue; fi
    while IFS= read -r -d '' source; do
        rel=${source#"$base/stow/$package/"}
        (( total += 1 ))
        if [[ ! -f $HOME/$rel ]]; then file_errors+=("Missing installed file: $rel"); continue; fi
        if [[ $source == *.sh ]]; then
            [[ -x $HOME/$rel ]] || script_errors+=("Not executable: $rel")
            output=$(bash -n "$HOME/$rel" 2>&1) || script_errors+=("$rel: $output")
        fi
        if command -v readlink >/dev/null; then
            [[ -L $HOME/$rel && $(readlink -f -- "$HOME/$rel") == "$source" ]] || link_errors+=("Not linked to this checkout: $rel")
        fi
    done < <(find "$base/stow/$package" -type f -print0)
done
for rel in config profile conf/classicui.conf; do
    [[ -f $HOME/.config/graphite/fcitx5/$rel ]] || file_errors+=("Missing local Fcitx settings: $rel")
    [[ ! -L $HOME/.config/graphite/fcitx5/$rel ]] || link_errors+=("Fcitx settings should be local writable files: $rel")
done
if (( ${#file_errors[@]} )); then report FAIL "Installed files ($total Stow entries)" "$(printf '%s\n' "${file_errors[@]}")"
else report PASS "Installed files ($total Stow entries)"; fi
if (( ${#script_errors[@]} )); then report FAIL 'Installed helper permissions and Bash syntax' "$(printf '%s\n' "${script_errors[@]}")"
else report PASS 'Installed helper permissions and Bash syntax'; fi
if (( ${#link_errors[@]} )); then report FAIL 'Stow links and local Fcitx settings' "$(printf '%s\n' "${link_errors[@]}")"
else report PASS 'Stow links point to this checkout; Fcitx settings are local'; fi
if (( ! desktop_only )); then
    apps_missing=()
    for cmd in starship nvim; do command -v "$cmd" >/dev/null || apps_missing+=("$cmd"); done
    if (( ${#apps_missing[@]} )); then report FAIL 'Application dependencies' "Missing: ${apps_missing[*]}"
    else report PASS 'Application dependencies'; fi
    if command -v code >/dev/null; then report PASS 'VS Code CLI available (extension checks are separate)'
    else report WARN 'VS Code CLI unavailable' 'Install Microsoft VS Code separately to use the Code/User settings package.'; fi
    report SKIP 'VS Code extensions: run bash install-vscode-extensions.sh --check separately'
    tools_missing=()
    for cmd in fastfetch btop; do command -v "$cmd" >/dev/null || tools_missing+=("$cmd"); done
    if (( ${#tools_missing[@]} )); then report WARN 'Terminal utility dependencies' "Missing optional apps: ${tools_missing[*]}"
    else report PASS 'Fastfetch and btop available'; fi
    if command -v nvim >/dev/null; then
        version=$(nvim --version 2>&1)
        if [[ $version =~ NVIM[[:space:]]v([0-9]+)\.([0-9]+)\.([0-9]+) ]] && \
            (( BASH_REMATCH[1] > 0 || BASH_REMATCH[2] > 11 || (BASH_REMATCH[2] == 11 && BASH_REMATCH[3] >= 2) )); then
            report PASS 'Neovim meets LazyVim minimum (0.11.2)' "${version%%$'\n'*}"
        else report FAIL 'LazyVim needs Neovim >= 0.11.2' "${version%%$'\n'*}"; fi
    fi
fi
if command -v timeout >/dev/null; then
    if command -v Hyprland >/dev/null; then
        probe 'Hyprland configuration parses' FAIL timeout --kill-after=1s 15s Hyprland --verify-config --config "$HOME/.config/graphite/hypr/hyprland.lua"
    fi
    if command -v fuzzel >/dev/null; then
        probe 'Fuzzel configuration parses' FAIL timeout --kill-after=1s 5s fuzzel --check-config --config="$HOME/.config/graphite/fuzzel/fuzzel.ini"
    fi
    if command -v zsh >/dev/null; then probe 'Zsh configuration parses' FAIL zsh -n "$HOME/.config/graphite/zsh/graphite.zsh"; fi
    if command -v jq >/dev/null; then
        if (( ! desktop_only )); then
            probe 'Application settings JSON parses' FAIL jq empty "$HOME/.config/Code/User/settings.json" "$HOME/.config/fastfetch/config.jsonc"
        fi
        probe 'Bar, notification and palette JSON parses' FAIL jq empty "$HOME/.config/graphite/waybar/config.jsonc" "$HOME/.config/graphite/swaync/config.json" "$HOME/.local/share/graphite/palette.json"
        if [[ -f $HOME/.local/lib/graphite/power-policy.sh ]]; then
            probe 'Power idle settings are valid' FAIL bash "$HOME/.local/lib/graphite/power-policy.sh" settings
        fi
    fi
    if [[ -x /usr/lib/qt6/bin/qmllint ]]; then
        probe 'QML lint (tooling warnings need review)' WARN timeout --kill-after=1s 20s /usr/lib/qt6/bin/qmllint -I /usr/lib/qt6/qml "$HOME/.config/graphite/quick-settings/"*.qml
    else report SKIP 'QML lint: qmllint unavailable'; fi
else report SKIP 'Configuration tooling: timeout unavailable'; fi
if command -v fc-match >/dev/null; then
    font_errors=() fonts=()
    for family in 'Noto Sans' 'JetBrainsMono Nerd Font' 'JetBrainsMono Nerd Font Mono'; do
        actual=$(fc-match -f '%{family}\n' "$family" 2>/dev/null) || actual='query failed'
        fonts+=("$family -> $actual")
        [[ ${actual,,} == *"${family,,}"* ]] || font_errors+=("$family -> $actual")
    done
    if (( ${#font_errors[@]} )); then report WARN 'Fonts resolved to fallbacks' "$(printf '%s\n' "${font_errors[@]}")"
    else report PASS 'Configured fonts resolve' "$(printf '%s\n' "${fonts[@]}")"; fi
fi
graphite=0 manager_ok=0
[[ ${XDG_CURRENT_DESKTOP:-} != Graphite:Hyprland ]] || graphite=1
echo "Session: ${XDG_CURRENT_DESKTOP:-unknown} (${XDG_SESSION_TYPE:-unknown})"
if command -v timeout >/dev/null && command -v systemctl >/dev/null; then
    if manager_env=$(timeout --kill-after=1s 5s systemctl --user show-environment 2>&1); then
        manager_ok=1
        report PASS 'Systemd user manager reachable'
        env_errors=()
        for name in XDG_CURRENT_DESKTOP WAYLAND_DISPLAY DISPLAY; do
            [[ -n ${!name:-} ]] || continue
            value=''
            while IFS= read -r line; do [[ $line != "$name="* ]] || value=${line#*=}; done <<< "$manager_env"
            [[ $value == "${!name}" ]] || env_errors+=("$name: terminal=${!name}, manager=${value:-unset}")
        done
        if [[ ${XDG_CURRENT_DESKTOP:-} != *Hyprland* && $manager_env == *HYPRLAND_INSTANCE_SIGNATURE=* ]]; then
            env_errors+=('Hyprland instance signature remains outside Hyprland; review stale session state.')
        fi
        if (( ${#env_errors[@]} )); then report WARN 'Session activation environment differs' "$(printf '%s\n' "${env_errors[@]}")"
        else report PASS 'Session activation environment matches this terminal'; fi
    else report WARN 'Cannot inspect user services in this environment' "$manager_env"; fi
fi
if (( manager_ok )); then
    if (( graphite )); then
        probe 'Graphite helper service active' FAIL timeout 5s systemctl --user is-active graphite-session.service
        probe 'Graphite idle policy service active' FAIL timeout 5s systemctl --user is-active graphite-power.service
        if (( verbose )); then
            output=$(timeout 5s systemctl --user status graphite-session.service --no-pager --full 2>&1) || true
            printf '%s\n' "$output"
        fi
    else
        active=() unknown=()
        for unit in graphite-session.service graphite-recorder.service graphite-night-light.service graphite-power.service graphite-lock.service; do
            state=$(timeout 5s systemctl --user show "$unit" -p ActiveState --value 2>/dev/null) || state=unknown
            case $state in
                active|activating|deactivating|reloading) active+=("$unit: $state") ;;
                inactive|failed) ;;
                *) unknown+=("$unit: state unavailable") ;;
            esac
        done
        if (( ${#active[@]} )); then report WARN 'Graphite services remain outside its desktop' "$(printf '%s\n' "${active[@]}")"
        elif (( ${#unknown[@]} )); then report SKIP 'Logout cleanup: service state unavailable' "$(printf '%s\n' "${unknown[@]}")"
        else report PASS 'No active Graphite services in this desktop'; fi
    fi
    for unit in pipewire.service pipewire-pulse.service wireplumber.service; do
        probe "$unit active (may activate on demand)" WARN timeout 5s systemctl --user is-active "$unit"
    done
    probe 'Desktop portal active (may activate on demand)' WARN timeout 5s systemctl --user is-active xdg-desktop-portal.service
else report SKIP 'Service health and logout cleanup: user manager unavailable'; fi
if (( graphite )) && [[ -n ${HYPRLAND_INSTANCE_SIGNATURE:-} ]] && command -v timeout >/dev/null && command -v hyprctl >/dev/null; then
    if errors=$(timeout 5s hyprctl configerrors 2>&1); then
        if [[ -z $errors || $errors == ok ]]; then report PASS 'Running compositor reports no configuration errors'
        else report FAIL 'Running compositor configuration errors' "$errors"; fi
    else report FAIL 'Cannot query running compositor' "$errors"; fi
    if command -v jq >/dev/null; then
        monitors=$(timeout 5s hyprctl -j monitors 2>&1)
        if (( $? == 0 )) && count=$(jq -er 'if type == "array" then length else error("Expected monitor array") end' <<< "$monitors" 2>/dev/null) && (( count > 0 )); then
            report PASS "Compositor has $count active output(s)" "$monitors"
        else report FAIL 'No active compositor outputs or invalid monitor response' "$monitors"; fi
    fi
    if (( manager_ok )) && command -v busctl >/dev/null; then
        owner=$(timeout 5s busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus NameHasOwner s org.freedesktop.Notifications 2>&1)
        if [[ $owner == 'b true' ]]; then report PASS 'Notification service has a D-Bus owner'
        else report WARN 'Notification service unavailable' "$owner"; fi
    fi
elif (( graphite )); then report FAIL 'Graphite session is missing compositor access variables or tools'
else report SKIP 'Live compositor, outputs and notifications: run again inside Graphite'; fi
if command -v timeout >/dev/null && command -v systemctl >/dev/null; then
    system_bus=$(timeout 5s systemctl show -p Version --value 2>&1)
    if (( $? != 0 )); then
        report WARN 'Cannot inspect system services in this environment' "$system_bus"
        report SKIP 'UDisks, network and Bluetooth: system manager unavailable'
    else
        probe 'UDisks available (may activate on demand)' WARN timeout 5s systemctl is-active udisks2.service
        if command -v nmcli >/dev/null; then probe 'NetworkManager device query' WARN timeout --kill-after=1s 5s nmcli device status; fi
        if command -v bluetoothctl >/dev/null; then
            if timeout 5s systemctl is-active --quiet bluetooth.service; then
                if adapters=$(timeout --kill-after=1s 5s bluetoothctl list 2>&1) && [[ -n $adapters ]]; then report PASS 'Bluetooth adapter discovered' "$adapters"
                else report WARN 'No Bluetooth adapter discovered or query failed' "$adapters"; fi
            else report SKIP 'Bluetooth adapter check: service inactive'; fi
        fi
    fi
fi
if (( verbose )) && command -v pacman >/dev/null; then
    echo 'Installed versions:'
    pacman -Q stow git kitty starship neovim hyprland hyprlock hypridle quickshell qt6-declarative fcitx5 fcitx5-mozc fcitx5-gtk fcitx5-qt noto-fonts-cjk 2>&1 || true
fi
report SKIP 'Manual: suspend/resume redraw, lid/lock, hotplug, input, USB eject, capture and playback'
echo
printf 'Summary: %d passed, %d failed, %d warnings, %d skipped.\n' "$passed" "$failed" "$warned" "$skipped"
if (( failed )); then echo 'Required checks failed. Review FAIL entries before relying on the setup.'
else echo 'Required checks passed. Review warnings and complete the manual checks.'; fi
echo 'Use --verbose for full diagnostics; docs/TESTING.md covers interactive checks. No repairs were performed.'
(( failed == 0 ))
