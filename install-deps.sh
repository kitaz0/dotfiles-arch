#!/usr/bin/env bash
# Review-only generator. Does not invoke sudo or install anything.
set -euo pipefail
base=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# Review/dry-run flags may accompany one package selection, in either order.
mode=--review
selection=''
info=''
desktop_only=0
for arg in "$@"; do
    case $arg in
        --desktop-only) desktop_only=1 ;;
        --help|-h) info=help ;;
        --list-optional) info=list ;;
        --review|--dry-run) continue ;;
        --minimal|--with-optional|--optional=?*)
            if [[ -n $selection && $selection != "$arg" ]]; then
                echo 'Choose one package selection: --minimal, --with-optional, or --optional=CATEGORY' >&2
                exit 2
            fi
            selection=$arg
            mode=$arg
            ;;
        *) echo "Invalid argument: $arg" >&2
            echo 'Run install-deps.sh --help for usage or --list-optional for categories.' >&2
            exit 2 ;;
    esac
done
# Discovery is local and never queries pacman or proposes a transaction.
if [[ -n $info ]]; then
    [[ -z $selection ]] || { echo 'Use --help or --list-optional separately from package selection flags.' >&2; exit 2; }
    if [[ $info == help ]]; then
        printf '%s\n' \
            'Usage: bash install-deps.sh [--review|--dry-run] [SELECTION] [--desktop-only]' \
            '' \
            'Default: desktop plus Kitty, Starship and LazyVim dependencies.' \
            '  --desktop-only        Omit Starship/LazyVim dependencies' \
            '  --minimal             Essential packages only' \
            '  --optional=CATEGORY   Default packages plus one optional/development category' \
            '  --with-optional       All categories; review carefully before installing' \
            '  --list-optional       List available categories, packages and purposes locally' \
            '  --help, -h            Show this help' \
            '' \
            'Example: bash install-deps.sh --review --optional=obs' \
            'Package review requires Arch/pacman. This script never installs packages or changes services.'
    else
        awk -F '\t' '
            BEGIN { printf "%-18s %-12s %-26s %s\n", "CATEGORY", "TYPE", "PACKAGE", "PURPOSE" }
            $1 == "optional" || $1 == "development" { printf "%-18s %-12s %-26s %s\n", $2, $1, $3, $4 }
        ' "$base/packages.tsv"
        printf '\n%s\n' 'Select one with: bash install-deps.sh --optional=CATEGORY' \
            'This adds the category to essential/recommended packages. Availability is checked during review.'
    fi
    exit 0
fi
case $mode in
    --review) extra='' ;;
    --minimal) extra=minimal ;;
    --with-optional) extra=all ;;
    --optional=*) extra=${mode#--optional=} ;;
esac
command -v pacman >/dev/null || { echo 'Run this review script on Arch Linux' >&2; exit 1; }
if [[ -n $extra && $extra != all && $extra != minimal ]] && ! awk -F '\t' -v category="$extra" '($1 == "optional" || $1 == "development") && $2 == category { found=1 } END { exit !found }' "$base/packages.tsv"; then
    echo "Unknown optional category: $extra (use --list-optional)" >&2; exit 2
fi
missing=(); unavailable=0; selected=0
while IFS=$'\t' read -r status category package purpose; do
    [[ $status != \#* && -n $status ]] || continue
    if (( desktop_only )) && [[ $category == apps ]]; then continue; fi
    if [[ $extra == minimal && $status != essential ]]; then continue; fi
    if [[ ( $status == optional || $status == development ) && $extra != all && $extra != "$category" ]]; then continue; fi
    selected=$((selected+1))
    if ! pacman -Si "$package" >/dev/null 2>&1; then echo "UNAVAILABLE: $package; verify current official repository name" >&2; unavailable=1; continue; fi
    if pacman -Q "$package" >/dev/null 2>&1; then echo "Present: $package ($purpose)"; else missing+=("$package"); echo "Missing: $package ($purpose)"; fi
done < "$base/packages.tsv"
(( selected > 0 )) || { echo 'No matching category' >&2; exit 2; }
(( unavailable == 0 )) || exit 1
# This project expects PipeWire/WirePlumber. Refuse to propose replacing a detected
# alternative stack; pacman and the user remain responsible for any migration.
for alternative in pulseaudio pipewire-media-session; do
    if pacman -Q "$alternative" >/dev/null 2>&1; then
        echo "REVIEW REQUIRED: existing $alternative; no installation command printed. Preserve or deliberately migrate your audio stack first." >&2
        exit 1
    fi
done
if [[ $extra != minimal ]]; then
    for alternative in ibus fcitx; do
        if pacman -Q "$alternative" >/dev/null 2>&1; then
            echo "REVIEW REQUIRED: $alternative is installed. Choose one input framework before adding Fcitx5; no installation command printed." >&2
            exit 1
        fi
    done
fi
echo 'Review services and transaction conflicts first; Arch does not support partial upgrades.'  
echo 'Regular user runs the following command with sudo for package changes:'
printf 'sudo pacman -Syu --needed'
if (( ${#missing[@]} )); then printf ' %q' "${missing[@]}"; fi
printf '\n'
echo 'No packages installed; no services changed; no configuration applied.'
