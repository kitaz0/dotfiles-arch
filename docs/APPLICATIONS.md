# Application configurations

The default install includes these GNU Stow packages alongside `desktop`:

| Package | Destination | Contents |
| --- | --- | --- |
| `kitty` | `~/.config/kitty/kitty.conf` | Gruvbox palette, Nerd Font and terminal settings |
| `starship` | `~/.config/starship.toml` | Gruvbox prompt with directory, Git, language and time modules |
| `nvim` | `~/.config/nvim/` | LazyVim setup, Gruvbox, Clangd/CMake extras and plugin lockfile |

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
