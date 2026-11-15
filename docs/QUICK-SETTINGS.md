# Quick settings

Click Wi-Fi, Bluetooth, audio, brightness, battery or clipboard in Waybar to open that page. Another icon changes the content in the same window; the same icon closes it. Escape, Close and an outside click dismiss it. The first outside click is consumed. Display arrangements use Super+Shift+P; notifications use their separate SwayNC surface. The bell is crossed while Do Not Disturb is on; right-click toggles it, and the icon follows changes made through SwayNC or the keyboard shortcut too.

Notifications are listed individually rather than collapsed into application groups. Clicking a notification invokes the sender's default action, when supplied; the sender decides whether this opens a window, conversation or file. The notification center closes after an action. Messages without an application action cannot reliably jump to an originating window. After editing notification settings, run `swaync-client --reload-config` to apply them without restarting the session.

- Wi-Fi: power switch, current connection and network list; saved/personal-network authentication. Enterprise and hidden networks use the labeled external setup tool.
- Bluetooth: power, scanning and device actions. Authenticated pairing uses BlueDevil after closing settings; no duplicate pairing agent is started.
- Audio: output/input selection, real mute controls and volume sliders. Application mixer is a separate page with arrow-back navigation. Advanced hardware profiles remain in pavucontrol.
- Brightness and Night Light: detected backlight, coalesced writes and live reads. Missing backlight hardware disables only its slider; this panel remains available on desktops for Night Light. Hyprsunset starts with the filter off. Toggle warmer screen colors and adjust warmth from 2500–6500 K; changes apply on slider release. Its separate `graphite-night-light.service` stops with the Graphite session, and an existing Hyprsunset instance is preserved.
- Clipboard: search previews, select to restore text/images, then paste. Refresh reloads history. Clear history asks for confirmation and removes Graphite's saved entries while keeping the current clipboard. Super+Shift+V uses the same database through Fuzzel. No new watchers are created.
- Battery and power: live charge, charging status, remaining time and power draw through UPower. Power modes appear only when `powerprofilesctl` and an already running power profile service are available. Settings opens Graphite's own idle-policy page in the same popup, with a back arrow. KDE's PowerDevil is not required. See [Power settings](POWER.md).

All device states come from the existing services. Only page changes animate; slider updates do not reload the page. The temporary dismissal layer excludes the top Waybar and uses OnDemand keyboard focus. Side/bottom bars require geometry adaptation. Third-party tray menus manage their own surfaces.

After changing Waybar's configuration or styling, refresh only the bar:

```bash
bash ~/.local/lib/graphite/waybar.sh reload
```

This keeps Fcitx and the other session helpers running. The generated Waybar configuration includes the source file so future SIGUSR2 reloads also read updated module settings.

[Testing](TESTING.md) ? [QML compatibility](QUICKSHELL-COMPATIBILITY.md)
