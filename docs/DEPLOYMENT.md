# Deployment and recovery

GNU Stow owns the symlinks. Git owns configuration history. The installer has no deployment snapshots, rollback stack or redo command. `--rollback`, `--uninstall` and `--replace-existing` are no longer accepted.

## Preview and link

```bash
bash apply-config.sh --dry-run
bash apply-config.sh --apply
```

Default packages: `desktop kitty starship nvim vscode`. Add `--desktop-only` to select just `desktop`. The wrapper uses `stow --dir=stow --target="$HOME" --no-folding --restow`. It seeds local Fcitx settings separately and backs up files that would block links. Reapplying correct links creates no backup.

For plain GNU Stow usage, use absolute paths for the package and target directories:

```bash
stow --dir="$PWD/stow" --target="$HOME" --no-folding --simulate desktop kitty starship nvim vscode
stow --dir="$PWD/stow" --target="$HOME" --no-folding desktop kitty starship nvim vscode
```

Direct Stow usage refuses conflicting ordinary files and does not seed Fcitx settings. Use the wrapper for first installation/migration. Avoid `stow --adopt`: it changes repository files from home contents without the import review used by this project.

## Git history

Commit working configurations before experimenting. To undo a committed change, review `git log`, revert the selected commit, and refresh links if file paths changed:

```bash
git revert <commit>
bash apply-config.sh --dry-run
bash apply-config.sh --apply
```

Do this outside Graphite when changing its session configuration. Uncommitted edits need their own deliberate Git restore/stash decision. Git does not capture old files that existed before installation, plugin downloads, packages, application state or system changes. File edits become live through symlinks; restart/reload the affected programs.

## Unlink

Exit Graphite before unlinking its configuration:

```bash
bash apply-config.sh --unstow
bash apply-config.sh --unstow --apply
```

Use `--desktop-only` to unlink only desktop files. Unstowing removes owned links, not repository contents. It does not remove applications, login entries, local Fcitx settings, recordings or backups. It does not automatically restore the previous configuration. If you enabled the user-wide dark preference, run `bash ~/.local/lib/graphite/appearance.sh restore` before unlinking.

## Restore pre-install files

The wrapper prints a directory under `${XDG_STATE_HOME:-$HOME/.local/state}/graphite/backups/before-stow-*`. It contains original files/symlinks under their home-relative paths. Treat it as private and keep it outside Git. Each folder contains only files displaced by that operation, not a full home snapshot.

Unstow first. Inspect a backup, then restore only the files you want, without overwriting later edits. For example, after checking the exact path:

```bash
# Replace BACKUP with the actual printed directory.
mkdir -p ~/.config
cp -an BACKUP/.config/nvim ~/.config/
```

Inspect any destination already present: `cp -an` preserves it. Do not merge backups blindly into active configuration. A failed Stow invocation leaves any moved originals in the printed backup directory; inspect its error and restore those files if you are abandoning the installation. No automatic transaction rollback is promised.

Old copy-installer deployment records stay on the device, outside this repository, and are no longer consumed. Do not invoke an old rollback script over the new Stow installation.

## Login entry

Home linking does not manage `/usr/share/wayland-sessions/`. Compare the dedicated Graphite entry with `session/graphite-hyprland.desktop` before manually removing it. Preserve the packaged Hyprland and Plasma entries and any entry still used by another user. Package removal is a separate decision.
