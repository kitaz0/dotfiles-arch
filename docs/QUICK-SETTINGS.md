# Quick settings

Click Wi-Fi, Bluetooth, audio, brightness or clipboard in Waybar to open that page. Another icon changes the content in the same window; the same icon closes it. Escape, Close and an outside click dismiss it. The first outside click is consumed. Display arrangements use Super+Shift+P; notifications use their separate SwayNC surface.

- Wi-Fi: power switch, current connection and network list; saved/personal-network authentication. Enterprise and hidden networks use the labeled external setup tool.
- Bluetooth: power, scanning and device actions. Authenticated pairing uses BlueDevil after closing settings; no duplicate pairing agent is started.
- Audio: output/input selection, real mute controls and volume sliders. Application mixer is a separate page with arrow-back navigation. Advanced hardware profiles remain in pavucontrol.
- Brightness: detected backlight, coalesced writes and live reads. Missing hardware disables the control; permissions are never changed.
- Clipboard: search previews, select to restore text/images, then paste. Refresh reloads history. Super+Shift+V uses the same database through Fuzzel. No new watchers are created.

All device states come from the existing services. Only page changes animate; slider updates do not reload the page. The temporary dismissal layer excludes the top Waybar and uses OnDemand keyboard focus. Side/bottom bars require geometry adaptation. Third-party tray menus manage their own surfaces.

[Testing](TESTING.md) ? [QML compatibility](QUICKSHELL-COMPATIBILITY.md)
