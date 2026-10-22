# Documentation

Start with the [project README](../README.md) for commands and shortcuts.

| Guide | Use it for |
| --- | --- |
| [Installation](INSTALLATION.md) | First login, updates and SDDM session name |
| [Deployment](DEPLOYMENT.md) | Stow links, Git history, backups and unlinking |
| [Applications](APPLICATIONS.md) | Kitty, Starship and LazyVim |
| [Keybindings](KEYBINDINGS.md) | Complete shortcut reference |
| [Quick settings](QUICK-SETTINGS.md) | Device pages, popup behavior and clipboard |
| [Theme](THEME.md) | Dark preference, Gruvbox palette and icons |
| [Displays](DISPLAYS.md) | Monitor arrangements and hardware overrides |
| [Bluetooth](BLUETOOTH.md) | Service setup, pairing and device actions |
| [Japanese input](JAPANESE.md) | Fcitx/Mozc and keyboard layout |
| [Recording](OBS.md) | Quick capture and optional OBS |
| [Troubleshooting](TROUBLESHOOTING.md) | Failure diagnostics |
| [Testing](TESTING.md) | First-login and hardware checklist |

For contributors: [Architecture](ARCHITECTURE.md), [Quickshell compatibility](QUICKSHELL-COMPATIBILITY.md), [Testing](TESTING.md) and [file tree](TREE.txt). `audit.py` and `test-*` check Stow integration and runtime behavior using disposable fixtures; they are not installed desktop dependencies.

The audit writes its local report to the ignored `.checks/validation.md` and regenerates the public file tree. Local reports, fixtures, caches and tool metadata are excluded from that tree.
