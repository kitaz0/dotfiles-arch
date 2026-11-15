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

The launcher applies Graphite's Gruvbox Qt stylesheet only to `fcitx5-config-qt`. It does not change the session's Qt theme or Plasma settings. Close and reopen the input settings window after changing its stylesheet.

## One input-mode indicator

Waybar shows one indicator for the Fcitx input state: **EN** for direct input and **あ** when Mozc is enabled. Ctrl+Space or a left click toggles the input method; right-click opens the private configuration tool. The indicator listens for tray-icon and daemon changes over D-Bus and queries the current state immediately, including per-window mode changes. A 30-second health check covers missed notifications. EN uses proportional Noto Sans at the bar's text size; あ uses Noto Sans CJK JP at the neighboring symbols' visual scale. A failed query displays **?**, and an unrelated active Fcitx engine displays **IM** rather than claiming English or Japanese. Without a running Fcitx daemon the label shows EN for direct input.

Waybar's `ignore-list` removes the duplicate native Fcitx tray entry only from Graphite's bar. Padding is applied to visible tray items rather than the tray container, so an empty tray adds no padded gap between the input indicator and Wi-Fi. Other applications' tray icons and Fcitx's input processing remain enabled. The input label reserves a small, consistent area for both modes to avoid resizing on a switch. Other desktop panels retain their ordinary tray behavior.

EN/あ describes whether the input engine is enabled, not Mozc's hiragana, katakana or ASCII submode. Use Mozc's settings and conversion shortcuts for those choices. The physical XKB layout is fixed to `us` in `hypr/graphite/input.lua`, with no Alt+Shift group switch. Mozc converts romaji to Japanese without changing physical key positions. A `jp` physical layout is for JIS key placement and is not required for Japanese conversion. If changing this configuration from multiple physical layouts, run `hyprctl reload` and `hyprctl switchxkblayout all 0` to reset the active group.

Test Ctrl+Space while a text field is focused, then switch windows and test again. Fcitx can restore per-window modes. Verify candidate windows and text input in Kitty, GTK, Qt/Dolphin and XWayland applications, and check a fallback desktop after logout.

Sources: [Fcitx Wayland integration](https://fcitx-im.org/wiki/Using_Fcitx_5_on_Wayland), [Fcitx tray identity](https://github.com/fcitx/fcitx5/blob/master/src/modules/notificationitem/notificationitem.cpp), [Waybar tray options](https://github.com/Alexays/Waybar/blob/master/man/waybar-tray.5.scd).

Fcitx saves its own private settings. The wrapper seeds missing `profile`, `config`, and `conf/classicui.conf` files from `defaults/fcitx5/` and preserves existing versions. Unstowing leaves them in place. To adopt a new default, compare it manually with your private file after exiting Fcitx. See [deployment](DEPLOYMENT.md).
