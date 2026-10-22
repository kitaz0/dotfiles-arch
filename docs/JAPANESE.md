# Japanese input and layout indicators

Graphite supplies an optional private Fcitx5/Mozc profile. Check your existing input framework before enabling it:

```bash
pacman -Q fcitx5 fcitx5-mozc fcitx5-gtk fcitx5-qt fcitx5-configtool noto-fonts-cjk
pacman -Q ibus fcitx
pgrep -a -u "$UID" -f 'fcitx|ibus'
printf 'GTK=%s QT=%s XMODIFIERS=%s\n' "$GTK_IM_MODULE" "$QT_IM_MODULE" "$XMODIFIERS"
```

Missing-package messages are diagnostic. Review `install-deps.sh --review`; it avoids proposing a competing framework when legacy Fcitx or IBus is installed. No package is installed or removed automatically.

## Configuration and typing

The helper uses `FCITX_CONFIG_HOME=~/.config/graphite/fcitx5`, preserving your existing profile. Existing processes and an occupied Fcitx D-Bus name are respected. An existing instance may not use this profile; fully log out before trying Graphite. Concurrent graphical sessions are unsupported.

Session-local QT_IM_MODULE and XMODIFIERS defaults are supplied. GTK normally uses native Wayland input; legacy GTK applications may need per-application `GTK_IM_MODULE=fcitx`. Conflicting explicit framework settings suppress the helper. No global autostart or system service is installed.

**Ctrl+Space** toggles direct input and Mozc. Type romaji, press Space for conversion candidates, Enter to commit, Escape to cancel; F6/F7 convert composing text to hiragana/katakana. Japanese keyboard triggers remain configured. Open private settings with:

```bash
bash ~/.local/lib/graphite/input-method.sh configure
```

Fcitx saves changes in its local writable profile; these files are not linked into Git. Dictionaries and learning data retain their ordinary storage.

## Two independent states

The Waybar layout label reads Hyprland's actual XKB state. The supplied layouts are **us,jp**; **Alt+Shift** or clicking the label cycles them. Japanese conversion also works with US physical layout. Edit the dedicated input.lua for other layouts. With multiple physical keyboards, set Waybar's keyboard-name from `hyprctl devices` if the default keyboard is not the one you use.

Beside that label, the **native Fcitx tray icon** displays Mozc's reported composition label: hiragana, katakana, half-width katakana or ASCII/full-width ASCII as applicable. The private classicui.conf enables text icons and a CJK font. Mozc supplies the label to Fcitx, which emits StatusNotifierItem icon updates consumed by Waybar.

The labels are deliberately separate: US plus a hiragana glyph means a US physical layout with Japanese composition. A composition glyph distinguishes hiragana from ASCII; it does not describe Mozc's separate *romaji versus direct-kana keystroke mapping* option. The Fcitx menu/configuration is authoritative for that option. A missing Fcitx instance hides its tray item rather than displaying a fabricated mode. Existing foreign profiles may retain a logo icon instead of text; configure that instance explicitly or start a clean Graphite session.

Test changes through Ctrl+Space and Mozc's own mode menu, including changing only composition mode, switching windows and workspaces, and keyboard layouts independently. Fcitx can restore per-window modes, so the label may legitimately change with focus. Test Kitty, GTK, Qt/Dolphin and XWayland text input and candidates, then any fallback session after logout.

Sources: [Fcitx Wayland integration](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland), [Mozc composition labels](https://github.com/fcitx/mozc/blob/fcitx/src/unix/fcitx5/mozc_engine.cc), [Fcitx tray label/icon signals](https://github.com/fcitx/fcitx5/blob/master/src/modules/notificationitem/notificationitem.cpp), [classic UI settings](https://github.com/fcitx/fcitx5/blob/master/src/ui/classic/classicui.h).

Fcitx saves its own private settings. The wrapper seeds missing `profile`, `config`, and `conf/classicui.conf` files from `defaults/fcitx5/` and preserves existing versions. Unstowing leaves them in place. To adopt a new default, compare it manually with your private file after exiting Fcitx. See [deployment](DEPLOYMENT.md).
