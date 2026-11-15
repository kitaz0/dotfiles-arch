#!/usr/bin/env bash
# A small GNU Stow wrapper: initial conflict backups, no deployment history.
set -euo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
apply=0 desktop_only=0 unstow=0 mode=
for arg in "$@"; do
    case $arg in
        --apply) [[ $mode != preview ]] || { echo "Choose --apply or --dry-run" >&2; exit 2; }; mode=apply; apply=1 ;;
        --dry-run) [[ $mode != apply ]] || { echo "Choose --apply or --dry-run" >&2; exit 2; }; mode=preview ;;
        --desktop-only) desktop_only=1 ;;
        --unstow) unstow=1 ;;
        --help|-h)
            cat <<'HELP'
Usage: bash apply-config.sh [--dry-run|--apply] [--desktop-only] [--unstow]

Default: preview desktop, Kitty, Starship, LazyVim, VS Code, Fastfetch, btop and Lazygit links. No files changed.
    --apply          Back up conflicting destination files, then link with GNU Stow
    --desktop-only   Select the desktop package; leave application configs alone
    --unstow         Remove selected Stow links (preview unless --apply is supplied)
    --dry-run        Preview the selected operation (the default)
    --help, -h       Show this help

Existing destination files are moved into ~/.local/state/graphite/backups/.
Application-written Fcitx settings are seeded only when absent, never symlinked.
Unstow does not restore backups or remove Fcitx settings, packages or login entries.
Use Git for config history. --rollback, --uninstall and --replace-existing are retired.
Keep this checkout in place while its links are installed. See docs/INSTALLATION.md.
HELP
            exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done
[[ $EUID != 0 ]] || { echo 'Run as your regular user, not root.' >&2; exit 1; }
[[ $HOME == /* && -d $HOME && ! -L $HOME ]] || { echo 'HOME must be an absolute, real directory.' >&2; exit 1; }
[[ -z ${XDG_CONFIG_HOME:-} || $XDG_CONFIG_HOME == "$HOME/.config" ]] || { echo 'This setup uses conventional ~/.config paths.' >&2; exit 1; }
for cmd in stow find sort readlink; do
    command -v "$cmd" >/dev/null || { echo "Missing $cmd; review bash install-deps.sh --review first." >&2; exit 1; }
done
packages=(desktop)
(( desktop_only )) || packages+=(kitty starship nvim vscode fastfetch btop lazygit)
stow_args=(--dir="$base/stow" --target="$HOME" --no-folding --verbose=1)
if (( unstow )); then
    (( apply )) || stow_args+=(--simulate)
    exec stow "${stow_args[@]}" --delete "${packages[@]}"
fi
# Walk only the explicit package files. Never adopt home files into the repository.
conflicts=()
declare -A seen=()
check_parents() {
    local parent
    parent=$(dirname -- "$HOME/$1")
    while [[ $parent != "$HOME" ]]; do
        [[ ! -L $parent && ( ! -e $parent || -d $parent ) ]] || {
            echo "Refusing linked/non-directory ancestor: $parent" >&2; return 1;
        }
        parent=$(dirname -- "$parent")
    done
}
for package in "${packages[@]}"; do
    [[ -d $base/stow/$package && ! -L $base/stow/$package ]] || { echo "Missing package: $package" >&2; exit 1; }
    [[ -z $(find "$base/stow/$package" -type l -print -quit) ]] || { echo "Package source contains a symlink: $package" >&2; exit 1; }
    while IFS= read -r -d '' source; do
        rel=${source#"$base/stow/$package/"}
        [[ $rel != *$'\n'* && $rel != *$'\t'* && ! -v seen[$rel] ]] || { echo 'Invalid/duplicate package destination' >&2; exit 1; }
        seen[$rel]=1
        check_parents "$rel"
        destination="$HOME/$rel"
        [[ ! -d $destination || -L $destination ]] || { echo "A directory occupies a file destination: $destination" >&2; exit 1; }
        if [[ -L $destination && $(readlink -m -- "$destination") == "$source" ]]; then
            continue
        elif [[ -e $destination || -L $destination ]]; then
            conflicts+=("$rel")
            echo "BACKUP: $destination"
        else
            echo "LINK: $destination"
        fi
    done < <(find "$base/stow/$package" -type f -print0 | sort -z)
done
for source in "$base/defaults/fcitx5/config" "$base/defaults/fcitx5/profile" "$base/defaults/fcitx5/conf/classicui.conf"; do
    [[ -f $source ]] || { echo "Missing Fcitx default: $source" >&2; exit 1; }
    rel=".config/graphite/fcitx5/${source#"$base/defaults/fcitx5/"}"
    check_parents "$rel"
    [[ -e $HOME/$rel || -L $HOME/$rel ]] || echo "SEED: $HOME/$rel"
done
if (( ! apply )); then
    if (( ${#conflicts[@]} == 0 )); then
        stow "${stow_args[@]}" --simulate --restow "${packages[@]}"
    else
        echo 'Conflicts above would be backed up before Stow runs. No files moved.'
    fi
    echo "Preview only. Selected packages: ${packages[*]}"
    exit 0
fi
umask 077
if (( ${#conflicts[@]} )); then
    state="${XDG_STATE_HOME:-$HOME/.local/state}/graphite/backups"
    [[ $state == /* && $state != "$base" && $state != "$base/"* ]] || { echo 'Backup directory must be absolute and outside the repository.' >&2; exit 1; }
    parent=$state
    while [[ $parent != / ]]; do
        [[ ! -L $parent ]] || { echo "Refusing linked backup ancestor: $parent" >&2; exit 1; }
        parent=$(dirname -- "$parent")
    done
    mkdir -p -- "$state"
    backup=$(mktemp -d "$state/before-stow-$(date -u +%Y%m%dT%H%M%S)-XXXXXX")
    echo "Original files will be preserved in: $backup"
    for rel in "${conflicts[@]}"; do
        mkdir -p -- "$backup/$(dirname -- "$rel")"
        mv -T -- "$HOME/$rel" "$backup/$rel"
    done
fi
# Stow checks its complete plan before creating links. A failed plan leaves backups available.
stow "${stow_args[@]}" --simulate --restow "${packages[@]}"
stow "${stow_args[@]}" --restow "${packages[@]}"
for source in "$base/defaults/fcitx5/config" "$base/defaults/fcitx5/profile" "$base/defaults/fcitx5/conf/classicui.conf"; do
    destination="$HOME/.config/graphite/fcitx5/${source#"$base/defaults/fcitx5/"}"
    if [[ ! -e $destination && ! -L $destination ]]; then
        mkdir -p -- "$(dirname -- "$destination")"
        cp -n -- "$source" "$destination"
    fi
done
echo "Linked packages: ${packages[*]}. Config edits are now edits to this checkout."
