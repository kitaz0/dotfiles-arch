# Architecture

- SDDM launches a small wrapper using the packaged `start-hyprland` launcher and the dedicated Lua config. No UWSM or global helper services are enabled.
- A transient systemd user service owns Waybar, wallpaper, idle/lock integration, notifications and clipboard watchers. Logout stops recording first, then helpers. Actual suspend/resume and failure cleanup require hardware testing.
- Waybar launches one on-demand Quickshell settings process. IPC changes its page without replacing the window. Outside-click surfaces exclude the bar; OnDemand keyboard focus avoids exclusive pointer redirection. Notifications and external pairing dialogs retain native surfaces.
- Native Quickshell NetworkManager, BlueZ and PipeWire APIs provide device state. Brightness uses the existing helper and asynchronous reads. Clipboard uses one private cliphist database and the existing text/image watchers.
- Desktop configs use a Graphite namespace while Kitty, Starship and Neovim use their normal application paths. XDG lookup remains unchanged for other programs. Portals use desktop-specific GTK Settings/FileChooser and Hyprland ScreenCast/Screenshot backends. No portal process is manually launched.
- GNU Stow links four home-shaped packages: desktop, Kitty, Starship and Neovim. The wrapper backs up conflicting destinations before linking and seeds local Fcitx settings. Git supplies configuration history; no custom deployment ledger is kept. Development scripts and private application state are not linked.

GPU and display discovery belong to Hyprland/Aquamarine. Monitor defaults are preferred mode, automatic position and scale. Logind/existing power policy handles lid and suspend; no custom GPU, lid or power framework is added.

See [Installation](INSTALLATION.md), [Theme](THEME.md), [Testing](TESTING.md) and [Quickshell compatibility](QUICKSHELL-COMPATIBILITY.md).
