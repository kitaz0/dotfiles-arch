# Appearance

Graphite uses the **Gruvbox Dark palette** for its bar, settings, terminal, launcher, notifications, wallpaper, lock screen and private Dolphin profile. The technical `graphite` paths and service names remain stable for upgrades. The public name is Graphite / Gruvbox.

The primary accent is Gruvbox bright orange (`#fe8019`) for focus, selection, controls and active workspaces. Gruvbox bright yellow (`#fabd2f`) is the secondary accent for connectivity, displays and links; its muted gold (`#d79921`) supplies darker variants. Gruvbox bright purple (`#d3869b`) accents clipboard, notifications and secondary details. The active window border blends orange into gold. Healthy battery values stay green and errors red, preserving their meaning. Kitty's cyan ANSI slots and the editors' aqua highlights use the same yellow/gold pair. Starship adapts the Tokyo Night preset with rounded, progressively darker Gruvbox gray segments, cream text, and small orange Git/prompt accents. VS Code uses Gruvbox Dark Medium to match the `#282828` backgrounds in Kitty, Neovim, btop and the desktop.

The shared palette reference is `stow/desktop/.local/share/graphite/palette.json`. Native applications keep their own theme files; `docs/test-theme.py`, included in the audit, checks their accent roles against that reference. Changing the reference alone does not update application themes: update their native files together and run the audit. There is no login-time rewrite. Fastfetch and btop use the same orange/gold/purple roles; see [Applications](APPLICATIONS.md).

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
