# Application configurations

The default install includes these GNU Stow packages alongside `desktop`:

| Package | Destination | Contents |
| --- | --- | --- |
| `kitty` | `~/.config/kitty/kitty.conf` | Gruvbox palette, Nerd Font and terminal settings |
| `starship` | `~/.config/starship.toml` | Gruvbox prompt with directory, Git, language and time modules |
| `nvim` | `~/.config/nvim/` | LazyVim setup, Gruvbox, Clangd/CMake extras and plugin lockfile |
| `vscode` | `~/.config/Code/User/settings.json` | Gruvbox theme, Nerd Font and portable CMake settings |

These are ordinary application settings and affect their use in every desktop session. `--desktop-only` leaves those paths alone. Graphite's terminal helper launches ordinary Kitty and inherits its configured shell. The normal Hyprland and KDE configuration paths remain independent.

## Starship and shells

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
