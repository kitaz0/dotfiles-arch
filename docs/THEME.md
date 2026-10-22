# Appearance

Graphite uses the **Gruvbox Dark palette** for its bar, settings, terminal, launcher, notifications, wallpaper, lock screen and private Dolphin profile. The technical `graphite` paths and service names remain stable for upgrades. The public name is Graphite / Gruvbox.

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
