# Installation

Target: Arch Linux, GNU Stow, systemd, SDDM, Hyprland 0.56.2 (Lua API) and Quickshell 0.3.2. LazyVim requires Neovim >= 0.11.2. Keep a working fallback session or TTY. Concurrent graphical sessions under the same user share D-Bus activation state and are unsupported.

## First installation or migration

1. Clone this repository to a permanent location such as `~/hyprland-setup`. Do not move/delete it while its links are installed.
2. Exit Graphite and close the applications whose configuration is being replaced. Use another desktop or a TTY.
3. Run `bash install-deps.sh --review`. Review and execute its printed pacman command. It includes GNU Stow and Git. No packages or services are changed automatically.
4. Run `bash apply-config.sh --dry-run`. Review every `BACKUP`, `LINK` and `SEED` destination.
5. Run `bash apply-config.sh --apply`. Existing conflicting files, including old copy-installed Graphite files, move to the printed backup directory outside the repository. Stow then creates file symlinks with `--no-folding`, keeping directories real.
6. Run `bash verify-setup.sh`. Run it again inside Graphite for compositor/session checks.

All scripts support `--help`. The default scope includes desktop, Kitty, Starship, LazyVim, VS Code, Fastfetch, btop and Lazygit. Use `--desktop-only` consistently for package review, linking and verification to omit application configurations and Starship/LazyVim dependencies. It does not remove apps installed by an earlier full installation. VS Code itself is installed separately; extension downloads are an explicit step described in [Applications](APPLICATIONS.md). Shell startup files, keys, packages and service enablement remain untouched.

Fcitx settings are copied from `defaults/fcitx5/` only when missing; existing settings are preserved. These writable files remain outside the Stow packages so input-method saves cannot change repository defaults. The installer refuses symlinked destination parent directories; resolve custom linked dotfile layouts manually before applying.

## Power profiles and Night Light

Package review recommends `power-profiles-daemon` only when a system battery is detected, excluding peripheral batteries. It skips the package when TLP, tlp-pd, tuned, tuned-ppd, auto-cpufreq or system76-power is installed. Existing power managers are preserved. If the review selects power-profiles-daemon, install the printed packages and then enable the shared system service:

```bash
sudo systemctl enable --now power-profiles-daemon.service
```

This service is shared with other desktops, including Plasma. The battery panel exposes profiles supported by the running service. Its Settings button opens Graphite's own page for battery/plugged-in lock, screen-off and suspend delays. KDE's PowerDevil is not required. See [Power settings](POWER.md) for preferences, defaults and activation in an existing session.

`hyprsunset` is recommended on laptops and desktops. After installing it and refreshing Stow links, Graphite starts its own Night Light service at login with the filter off. To start it in an existing Graphite session without restarting the other helpers:

```bash
bash ~/.local/lib/graphite/night-light.sh start
bash ~/.local/lib/graphite/waybar.sh reload
```

Use the sun icon for its toggle and warmth slider. The private `~/.config/graphite/hypr/hyprsunset.conf` has no scheduled profiles by default. The launcher sets `XDG_CONFIG_HOME` for this service alone so Hyprsunset reads that file without relying on the broken `--config` argument in version 0.4.0. The transient service is bound to Graphite's lifetime and exits on logout. It does not enable the upstream global user service or replace an existing Hyprsunset instance.

## Login entry

Install the separate SDDM entry once, from the project directory. This command refuses an existing entry:

```bash
sudo sh -c 'set -eu; dst=/usr/share/wayland-sessions/graphite-hyprland.desktop; if [ -e "$dst" ] || [ -L "$dst" ]; then echo "Already exists: compare it with the project copy" >&2; exit 1; fi; install -m 644 session/graphite-hyprland.desktop "$dst"'
```

For an existing entry, compare it with `cmp session/graphite-hyprland.desktop /usr/share/wayland-sessions/graphite-hyprland.desktop`. Home configuration linking does not update system files. Log out, select **Hyprland (Graphite/Gruvbox)** and follow [Testing](TESTING.md). Restarting SDDM terminates graphical sessions.

## Customization and updates

Desktop configs live at `~/.config/graphite/`, helpers at `~/.local/lib/graphite/`, and ordinary app configs at `~/.config/kitty/`, `~/.config/starship.toml`, `~/.config/nvim/` and `~/.config/Code/User/settings.json`. Their symlinks point into `stow/` in this checkout.

Edit through either path, review `git diff`, and commit the configuration. Pull updates with a clean Git working tree, then refresh links:

```bash
git pull
bash apply-config.sh --dry-run
bash apply-config.sh --apply
bash verify-setup.sh
```

Add `--desktop-only` when appropriate. Existing-file replacement is automatically backed up; there is no `--replace-existing` flag. When an application replaces a symlink with a regular file, review that file's changes before running the installer again: it will preserve it in the backup and restore the repository link. Deliberately copy any changes you want to keep into the source first.

Changing Git commits affects linked files immediately. Stop/restart affected apps as appropriate; log out/in after changes to startup helpers or hypridle. Use [Git and recovery](DEPLOYMENT.md) to reverse changes or unlink the setup. The previous deployment ledger is not used or deleted; preserve any old backups you still need.

[Application setup](APPLICATIONS.md) · [Appearance](THEME.md) · [Japanese input](JAPANESE.md) · [Bluetooth](BLUETOOTH.md) · [Displays](DISPLAYS.md).
