# Appearance

Graphite uses the **Gruvbox Dark palette** for its bar, settings, terminal, launcher, notifications, wallpaper, lock screen and private Dolphin profile. The technical `graphite` paths and service names remain stable for upgrades. The public name is Graphite / Gruvbox.

The primary accent is Gruvbox bright orange (`#fe8019`) for focus, selection, controls and active workspaces. Gruvbox bright yellow (`#fabd2f`) is the secondary accent for connectivity, displays and links; its muted gold (`#d79921`) supplies darker variants. Gruvbox bright purple (`#d3869b`) accents clipboard, notifications and secondary details. The active window border blends orange into gold. Healthy battery values stay green and errors red, preserving their meaning. Kitty's cyan ANSI slots and the editors' aqua highlights use the same yellow/gold pair. Starship adapts the Tokyo Night preset with rounded, progressively darker Gruvbox gray segments, cream text, and small orange Git/prompt accents. VS Code uses Gruvbox Dark Medium to match the `#282828` backgrounds in Kitty, Neovim, btop and the desktop.

The single editable palette is [`theme/palette.json`](../theme/palette.json). `colors` defines named Gruvbox swatches once; `roles` assigns them to backgrounds, text, accents and status colors. For example, `"accent": "bright_orange"` selects the orange swatch. Change a role to another swatch to change its use throughout the setup, or edit a swatch value to change every role that uses it. The `secondary`/`gold`/`gold_dim` roles give you independent control over the bright and darker secondary variants.

After editing the palette, run from the checkout:

```bash
python3 theme.py
python3 theme.py --check
git diff
```

The first command updates native theme files under `stow/`; `--check` reports missing or stale generated files without writing anything. `--help` describes the command. Commit both the palette/source changes and generated outputs. Python 3.9+ is only needed for editing themes; installing and running the setup uses the committed native files. Nothing generates themes at login, rewrites home files, or restarts applications automatically. The audit includes the drift check and disposable palette-edit tests.

Waybar and SwayNC import the same generated `graphite/theme/colors.css`. Qt Quick components reference `Theme.js`, Kitty includes `colors.conf`, and Neovim reads its generated `graphite.palette` Lua module. Each app package works independently of the desktop package.

Hyprland, Hyprlock, Fuzzel, Starship, btop, Fastfetch, Lazygit, VS Code, private Qt widgets, Dolphin/KDE colors, display SVGs and the optional Zsh prompt use native formats rendered from `theme/templates/`. Templates reference roles such as `{{accent}}`, with `|hex`, `|rgb` or `|ansi` where a format requires it. The [template map](../theme/templates.json) lists each template and its generated file. To change non-color settings in one of these generated configs, edit its matching `.in` template and run the generator; direct edits to its output are overwritten on the next generation. CSS, QML, Kitty's main settings and Neovim's plugin settings remain directly editable. `~/.local/share/graphite/palette.json` is a generated export, not another source of colors. Binary wallpaper artwork and third-party theme defaults are not recolored by this command.

When first updating to shared theme files, refresh the new links before reloading applications:

```bash
bash apply-config.sh --apply
hyprctl reload
bash ~/.local/lib/graphite/waybar.sh reload
swaync-client --reload-css
```

Use `--desktop-only` on the Stow command if that is your installed scope. Close/reopen quick settings after refreshing the links. Reopen affected applications as needed; Kitty can reload its config with Ctrl+Shift+F5. Subsequent palette edits only need generation and the relevant reloads, unless new files were added. No logout is required. Fastfetch and btop use the same orange/gold/purple roles; see [Applications](APPLICATIONS.md).

Input-method settings use an application-local Gruvbox stylesheet with Qt's Fusion style. The EN/あ right-click launcher applies it to `fcitx5-config-qt`; it does not alter Plasma's theme. Reopen that window after a theme update.

Power settings use the same locally styled Qt Quick controls and Gruvbox palette as the other Graphite popup pages. They do not launch KDE's power settings or change Plasma's theme.

Lazygit uses gold shortcuts and cream text on a dark surface for selected rows. Both its standalone config and LazyVim/Snacks' generated theme use that contrast pair; the audit checks the selected text and shortcut contrast. This keeps the `?` shortcut menu legible independently of terminal ANSI blue settings.

## Dark mode

The GTK Settings portal reads `org.gnome.desktop.interface color-scheme`. Application preferences control their appearance independently of the bar colors.

```bash
bash ~/.local/lib/graphite/appearance.sh status
bash ~/.local/lib/graphite/appearance.sh dark
```

This explicitly changes the **user-wide** dark preference, including other sessions that read it. The previous value is saved once. Restart applications that cache the preference and select their System/Automatic theme. Applications with independent theme settings may require selecting Dark in their own preferences.

Undo before unlinking:

```bash
bash ~/.local/lib/graphite/appearance.sh restore
```

It refuses to overwrite an unrelated later preference. The required schema is provided by the recommended `gsettings-desktop-schemas` package. No theme command runs automatically at login.

## Gruvbox versus Breeze

A palette, widget style, icon pack and dark preference are different settings. **Breeze is the Qt widget style and Breeze Dark is the icon pack.** Gruvbox supplies the colors.

Deployment registers `~/.local/share/color-schemes/Gruvbox.colors`, using the same colors as Dolphin. Qt/KDE applications can select Gruvbox through their appearance settings. If `plasma-apply-colorscheme` is installed, `plasma-apply-colorscheme --list-schemes` lists available palettes; record your current selection before explicitly applying `plasma-apply-colorscheme Gruvbox`. This is a user-wide change and is separate from configuration linking; select your recorded previous scheme before unlinking if you applied it. Breeze can remain the widget style while using Gruvbox colors.

[Gruvbox Plus](https://github.com/SylEleuth/gruvbox-plus-icon-pack) is a possible optional icon pack, distributed separately (including AUR). It is not silently added to the official-repository package workflow. If you choose it, review its upstream installation/license and use the actual installed theme directory name in Fuzzel, Dolphin and your normal GTK/Qt settings. Existing Breeze icons remain functional by default. No third-party installer or icon assets are bundled.

Portal behavior follows [xdg-desktop-portal-gtk Settings](https://github.com/flatpak/xdg-desktop-portal-gtk/blob/main/src/settings.c).

## Application appearance diagnostics

Fully quit/reopen the affected application and compare the stored preference with the portal's value:

```bash
gsettings get org.gnome.desktop.interface color-scheme
gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme
loginctl show-user "$USER" -p Linger -p Sessions
```

Expect `prefer-dark` and portal value `uint32 1`. An application explicitly set to Light can still ignore them. If the portal is stale, after stopping recording/screen sharing you can restart the configured GTK backend and broker, then reopen the app:

```bash
systemctl --user restart xdg-desktop-portal-gtk.service xdg-desktop-portal.service
```

This interrupts active portal sessions; it is a manual diagnostic step, not a login workaround. Do not change lingering or kill the whole user session just to update a theme. References: [GTK Settings change signals](https://github.com/flatpak/xdg-desktop-portal-gtk/blob/main/src/settings.c), [systemd user lingering](https://www.freedesktop.org/software/systemd/man/252/loginctl.html).
