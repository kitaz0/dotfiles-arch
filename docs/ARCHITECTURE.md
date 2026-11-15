# Architecture

- SDDM launches a small wrapper using the packaged `start-hyprland` launcher and the dedicated Lua config. No UWSM or global helper services are enabled.
- A transient systemd user service owns Waybar, wallpaper, idle/lock integration, notifications and clipboard watchers. Logout stops recording first, then helpers. Actual suspend/resume and failure cleanup require hardware testing.
- Waybar launches one on-demand Quickshell settings process. IPC changes its page without replacing the window. Outside-click surfaces exclude the bar; OnDemand keyboard focus avoids exclusive pointer redirection. Notifications and external pairing dialogs retain native surfaces.
- Native Quickshell NetworkManager, BlueZ and PipeWire APIs provide device state. Brightness uses the existing helper and asynchronous reads. Clipboard uses one private cliphist database and the existing text/image watchers.
- Graphite's power settings keep performance profiles separate from idle policy. A transient power service owns Hypridle and watches UPower charger events; a separate lock service preserves the locker during policy reloads. Both stop with the Graphite session. Repository defaults and local writable preferences are separate.
- Desktop configs use a Graphite namespace while Kitty, Starship, Neovim and VS Code use their normal application paths. XDG lookup remains unchanged for other programs. Portals use desktop-specific GTK Settings/FileChooser and Hyprland ScreenCast/Screenshot backends. No portal process is manually launched.
- GNU Stow links eight home-shaped packages: desktop, Kitty, Starship, Neovim, VS Code, Fastfetch, btop and Lazygit. The wrapper backs up conflicting destinations before linking and seeds local Fcitx settings. Git supplies configuration history; no custom deployment ledger is kept. Development scripts and private application state are not linked. The VS Code extension list is applied by a separate explicit CLI helper, without automatic downloads during configuration linking.

GPU and display discovery belong to Hyprland/Aquamarine. Monitor defaults are preferred mode, automatic position and scale. Logind/existing power policy handles lid close; optional inactivity suspend uses logind through systemctl. Hardware tuning remains with the existing power profile service.

See [Installation](INSTALLATION.md), [Theme](THEME.md), [Testing](TESTING.md) and [Quickshell compatibility](QUICKSHELL-COMPATIBILITY.md).
