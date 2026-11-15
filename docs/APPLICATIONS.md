# Application configurations

The default install includes these GNU Stow packages alongside `desktop`:

| Package | Destination | Contents |
| --- | --- | --- |
| `kitty` | `~/.config/kitty/kitty.conf` | Gruvbox palette, Nerd Font and terminal settings |
| `starship` | `~/.config/starship.toml` | Tokyo Night layout with muted Gruvbox segments, directory, Git, language and time modules |
| `nvim` | `~/.config/nvim/` | LazyVim setup, Gruvbox, Clangd/CMake extras and plugin lockfile |
| `vscode` | `~/.config/Code/User/settings.json` | Gruvbox Dark Medium, shared accent overrides, Nerd Font and portable CMake settings |
| `fastfetch` | `~/.config/fastfetch/` | Original warm Arch wordmark/logo and a compact system summary |
| `btop` | `~/.config/btop/` | Graphite theme and GPU detail panels with detected model names |

These are ordinary application settings and affect their use in every desktop session. `--desktop-only` leaves those paths alone. Close btop before the first linking operation; its existing config is backed up using the same Stow workflow as the other apps. Graphite's terminal helper launches ordinary Kitty and inherits its configured shell. The normal Hyprland and KDE configuration paths remain independent.

## Fastfetch and btop

Run `fastfetch` or `btop` normally after linking the application packages. Their executables are recommended app dependencies in `install-deps.sh --review`; no new aliases or shell startup commands are installed.

Fastfetch uses an original block-text Arch silhouette shaded orange, gold and cream. Its compact colored-key layout takes inspiration from [Bina's Arch/Hyprland post on r/unixporn](https://www.reddit.com/r/unixporn/comments/1cqbemu/hyprland_i_made_it_to_fastfetch_finally/) and the author's [minimal preset](https://github.com/LierB/fastfetch/blob/master/presets/minimal.jsonc). No external artwork or executable installer is downloaded. The logo is ordinary UTF-8 text, so screenshots do not depend on Kitty's image protocol.

The default text output shows OS, kernel, desktop, terminal, CPU/GPU models and memory usage. It omits username, hostname, IP addresses, network interfaces, disk paths, display serials and hardware serial numbers. Hardware models are detected at runtime, never copied into this repository. Extra command-line modules or JSON output follow Fastfetch's own rules and can expose additional information. Edit `stow/fastfetch/.config/fastfetch/config.jsonc` to change the displayed modules and `arch.txt` to change the logo.

btop starts with a compact CPU/memory/network/process dashboard that fits a 30-row terminal. Short `GPU0`/`GPU1` utilization labels remain in the CPU box when supported. Use `p`/`Shift+p` to cycle the compact overview, a GPU0-only view and a GPU1-only view. The GPU-only views show the detected model name beside the corresponding index without also requiring space for the regular dashboard. Names come from btop itself, not an assumed DRM `card0` order or a hardcoded machine inventory. Native `5`/`6` toggles can add detail panels when the terminal has room; they are not enabled by default. Unavailable GPUs remain subject to btop's native detection.

The Graphite btop theme assigns Gruvbox orange to CPU/focus, yellow/gold to memory/network, and purple to processes, matching the other application accents. `save_config_on_exit = false` keeps transient UI choices from being written back; edit the linked config deliberately to keep layout changes in Git. The system monitor can display process arguments, usernames and network details, so the public-facing Fastfetch layout is the intended screenshot summary.

## Starship and shells

The prompt adapts [Starship’s Tokyo Night preset](https://starship.rs/presets/tokyo-night) to Gruvbox: rounded separators, neutral warm-gray backgrounds, cream text, orange Git details and an orange prompt marker. Error states remain red. The existing language/environment modules stay available when relevant; the clock uses the darkest segment. Palette values remain aligned with Graphite; the prompt uses a restrained subset of its accents.

The installer does not replace `.zshrc`, `.bashrc` or change your login shell. If Starship is not already initialized, add the appropriate line once near the end of your shell configuration:

```bash
# ~/.zshrc
eval "$(starship init zsh)"

# Or ~/.bashrc
eval "$(starship init bash)"
```

Use just the line matching your shell. Restart the shell. Explicit `STARSHIP_CONFIG` overrides take precedence; remove or adjust one if it points elsewhere. The optional desktop `graphite.zsh` prompt is an alternative; use one prompt initializer at a time.

## LazyVim

Open `nvim` after installing dependencies. The config bootstraps lazy.nvim and downloads plugins into Neovim's data directory. This first launch needs network access and may install language tools. Those downloads, caches, state and histories are not part of this repository. Existing Neovim data/state directories are preserved; test the imported configuration and inspect `:LazyHealth`.

`lazy-lock.json` tracks plugin revisions. Plugin updates and changes to `lazyvim.json` may modify configuration files: review and commit intentional changes. Keep source code under `lua/`; keep API keys and credentials in external environment variables or local secret stores. Do not copy an entire home or editor data directory into the repository.

The config derives from the [LazyVim starter](https://github.com/LazyVim/starter). Its license is retained in [licenses/LazyVim-starter-LICENSE](../licenses/LazyVim-starter-LICENSE). See [upstream requirements](https://www.lazyvim.org/) and [installation guidance](https://www.lazyvim.org/installation).

## VS Code

The `vscode` package targets Microsoft Visual Studio Code's default Linux user profile. It contains only reviewed user settings; accounts, tokens, extension binaries, caches, workspace history and storage remain outside Git. Custom keybindings can be added later if needed. Close VS Code before the first linking operation so it cannot overwrite settings during migration.

The VS Code executable is not installed by this project. Install the build you use separately. Other builds, such as Code OSS, VSCodium or Insiders, use different user directories; adapt the Stow destination before linking those builds. `CODE_BIN` selects a CLI for the extension helper only and does not change configuration destinations.

Configuration linking and extension installation are separate:

```bash
bash apply-config.sh --dry-run
bash apply-config.sh --apply
bash install-vscode-extensions.sh --dry-run
bash install-vscode-extensions.sh
bash install-vscode-extensions.sh --check
```

`--desktop-only` omits the VS Code settings along with other app configs. Applying configurations never downloads extensions. The extension helper explicitly installs missing IDs from `extensions/vscode.txt` into the default profile, leaves installed extensions at their current versions, and does not uninstall unrelated extensions. VS Code may install dependencies or extension-pack members as part of an installation. `--check` lists missing entries without installing and returns 1 if any are missing. `--dry-run` only prints the list and does not invoke VS Code at all. Installation/list-query errors return a failing exit status.

After intentionally changing your extension selection, review an updated list before committing:

```bash
code --list-extensions | LC_ALL=C sort -u > extensions/vscode.txt
git diff -- extensions/vscode.txt
```

The list records IDs, not extension binaries, credentials or pinned versions. It is not an automatic synchronization service: adding an ID enables installation, while removing an ID does not uninstall it from a user's editor. Unstowing removes the settings link and leaves installed extensions alone. See [VS Code CLI documentation](https://code.visualstudio.com/docs/configure/command-line#_working-with-extensions).
