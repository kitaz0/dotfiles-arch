#!/usr/bin/env bash
# Install only the listed missing extensions. Never uninstall or force updates.
set -euo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
mode=install
for arg in "$@"; do
    case $arg in
        --dry-run|--check)
            [[ $mode == install || $mode == "$arg" ]] || { echo 'Choose --dry-run or --check.' >&2; exit 2; }
            mode=$arg ;;
        --help|-h)
            cat <<'HELP'
Usage: bash install-vscode-extensions.sh [--dry-run|--check]

Default: install missing IDs from extensions/vscode.txt into VS Code's default profile.
    --dry-run   Show the extension list without calling VS Code or downloading
    --check     Report missing extensions without installing (exit 1 if missing)
    --help, -h  Show this help

Requires the code CLI for installation/checking. CODE_BIN may name another CLI.
Already-installed extensions are left alone. Other extensions are never removed.
No --force, updates, account data or extension binaries are stored in this repo.
Configuration linking is separate: bash apply-config.sh --apply.
HELP
            exit 0 ;;
        *) echo "Unknown option: $arg (see --help)" >&2; exit 2 ;;
    esac
done
[[ -r $base/extensions/vscode.txt ]] || { echo 'Missing extensions/vscode.txt' >&2; exit 1; }
ids=()
declare -A seen=()
while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    [[ -n $line && $line != \#* ]] || continue
    [[ $line =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || { echo 'Invalid extension ID in extensions/vscode.txt; nothing installed.' >&2; exit 2; }
    id=${line,,}
    [[ ! -v seen[$id] ]] || continue
    seen[$id]=1
    ids+=("$id")
done < "$base/extensions/vscode.txt"
(( ${#ids[@]} )) || { echo 'No extensions listed.'; exit 0; }
if [[ $mode == --dry-run ]]; then
    printf 'ENSURE: %s\n' "${ids[@]}"
    echo 'Preview only; VS Code was not invoked.'
    exit 0
fi
editor=${CODE_BIN:-code}
command -v "$editor" >/dev/null || { echo "VS Code CLI not found: $editor. Install VS Code or set CODE_BIN." >&2; exit 1; }
if ! output=$("$editor" --list-extensions); then
    echo 'Cannot list installed extensions; nothing installed.' >&2
    exit 1
fi
declare -A installed=()
while IFS= read -r line; do
    line=${line%$'\r'}
    [[ $line =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*\.[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || continue
    installed[${line,,}]=1
done <<< "$output"
kept=0 missing=0 added=0 failed=0
for id in "${ids[@]}"; do
    if [[ -v installed[$id] ]]; then
        echo "KEEP: $id"
        (( kept += 1 ))
    elif [[ $mode == --check ]]; then
        echo "MISSING: $id"
        (( missing += 1 ))
    elif "$editor" --install-extension "$id"; then
        (( added += 1 ))
    else
        echo "FAILED: $id" >&2
        (( failed += 1 ))
    fi
done
printf 'Summary: %d already installed, %d installed, %d missing, %d failed.\n' "$kept" "$added" "$missing" "$failed"
(( missing == 0 && failed == 0 ))
