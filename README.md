# Graphite / Gruvbox

An Arch Linux desktop and dotfiles setup for **Hyprland 0.56.2 and Quickshell 0.3.2**, with GNU Stow, Kitty, Starship, Neovim/LazyVim, VS Code, Fastfetch, btop and Lazygit settings. Gruvbox Dark with warm orange, gold and purple accents. Git tracks configuration history; Stow links the checkout into your home directory. No driver changes or automatic package installation.

## Install

Keep the checkout at a permanent location. Run as your regular user, outside Graphite for the initial migration:

```bash
git clone <repository-url> ~/hyprland-setup
cd ~/hyprland-setup
bash install-deps.sh --review
# Review and run the printed pacman command, including GNU Stow.
bash apply-config.sh --dry-run
bash apply-config.sh --apply
bash verify-setup.sh
```

The default installs **desktop, Kitty, Starship, LazyVim, VS Code, Fastfetch, btop and Lazygit configurations**. To leave your ordinary app configs alone, add `--desktop-only` to all three scripts. The desktop still needs the Kitty executable; its settings are then your own.

Existing files occupying selected destinations are moved to `~/.local/state/graphite/backups/` before Stow creates links. The installer never adopts home files into Git. Review the preview: application configs affect those apps in every desktop session. Add the separate login entry using [Installation](docs/INSTALLATION.md), then select **Hyprland (Graphite/Gruvbox)**.

## Maintain

Edit ordinary linked settings through their usual paths or inside `stow/`. Colors are maintained centrally in [`theme/palette.json`](theme/palette.json): run `python3 theme.py` after changing them. Generated configs use source templates under `theme/templates/`; edit their `.in` sources for other settings too. See [Appearance](docs/THEME.md) for the file mapping and reload steps. Review and commit the sources together with their generated files:

```bash
git diff
git add stow/ theme/ theme.py
git commit -m "Update configuration"
git push
```

Most edits are live through the symlinks; reload or restart affected applications. After pulling updates, refresh the links with `bash apply-config.sh --apply` (include `--desktop-only` if that is your selected scope). Keep the checkout in place. Git history replaces the previous custom rollback system; see [Deployment and recovery](docs/DEPLOYMENT.md).

| Command | Purpose |
| --- | --- |
| `bash apply-config.sh --help` | Linking, backup and unstow options |
| `bash apply-config.sh --unstow` | Preview removal of the selected links |
| `bash apply-config.sh --unstow --apply` | Remove links; keep backups and local state |
| `bash install-vscode-extensions.sh --dry-run` | Preview the VS Code extension list without downloads |
| `bash install-vscode-extensions.sh` | Install missing listed extensions with the VS Code CLI |
| `bash install-deps.sh --help` | Package review and optional categories |
| `bash install-deps.sh --review --optional=obs` | Include optional OBS dependencies |
| `bash verify-setup.sh --verbose` | Full link/config/session diagnostics |
| `python3 theme.py` | Regenerate app themes from the central palette |
| `python3 theme.py --check` | Check generated themes without writing |

Only configuration, desktop helpers and project documentation belong in this repository. Keys, credentials, histories, caches, downloads and migration backups stay outside it. [Application configuration](docs/APPLICATIONS.md) covers shell integration and LazyVim first launch.

## Controls

| Shortcut / control | Action |
| --- | --- |
| Super+Return / E / Space | Terminal / file manager / launcher |
| Super+Q / F / V | Close / fullscreen / floating |
| Super+Arrows | Focus a window |
| Super+Shift+Left/Right | Swap with previous/next window on this workspace |
| Super+1..0 / Super+Shift+1..0 | Switch workspace / move window |
| Super+F1 | Search all configured shortcuts |
| Super+Shift+V / clipboard bar icon | Search and restore clipboard history |
| Super+N / Super+L | Notifications / lock |
| Super+Shift+P | Visual display arrangement chooser |
| Print / Super+Print / Shift+Print | Screenshot / region / annotation |
| Super+Shift+R / Super+O | Quick recording / OBS (optional) |
| Device icons | Wi-Fi, Bluetooth, audio mixer, brightness/Night Light and battery/power settings |
| Ctrl+Space | Japanese conversion on a US physical layout (single EN/あ indicator) |

[All shortcuts](docs/KEYBINDINGS.md) · [Settings and clipboard](docs/QUICK-SETTINGS.md) · [Appearance](docs/THEME.md) · [Troubleshooting](docs/TROUBLESHOOTING.md) · [Recording](docs/OBS.md) · [Tests](docs/TESTING.md)

Use the [testing checklist](docs/TESTING.md) to verify the setup on your hardware.

## Project structure

`stow/desktop/`, `stow/kitty/`, `stow/starship/`, `stow/nvim/`, `stow/vscode/`, `stow/fastfetch/`, `stow/btop/` and `stow/lazygit/` mirror home-directory destinations. `defaults/fcitx5/` supplies local writable seeds. Battery → Settings configures separate battery/plugged-in idle delays; [Power settings](docs/POWER.md) explains local preferences and Git defaults. `extensions/vscode.txt` lists VS Code extensions for the separate installer. `session/` holds the login entry; `licenses/` retains third-party notices. Root scripts review packages, invoke Stow and verify the setup. [Documentation index](docs/README.md) · [Public file tree](docs/TREE.txt).
