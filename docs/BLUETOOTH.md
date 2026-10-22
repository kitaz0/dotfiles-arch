# Bluetooth

Click the Bluetooth bar icon to open the device page. Its title-row switch changes radio power. Live BlueZ state supplies adapter power, device connection/pairing/block status, addresses and available battery data.

Details supports scanning, connecting/disconnecting and forgetting paired devices. Forget requires a second confirmation click. Leaving the page releases scans initiated by it; another application's scan is not stopped. No background scanner or permanent extra pairing agent is installed. Multiple adapters get separate controls in the popup. Waybar displays one controller; explicitly set its `controller` option if the default is not the one you want to monitor.

**Pair... opens BlueDevil's authenticated wizard**, closing the popup first. Select the device again there and confirm its PIN. Quickshell's device API has pairing methods but no PIN/confirmation-agent UI; implementing a second BlueZ agent would add substantial authentication infrastructure. This remains a deliberate external handoff, not a claim of fully embedded pairing. Unsolicited incoming pairing is not provided. Advanced adapter settings remain accessible through `kcmshell6 kcm_bluetooth` if needed.

## Check on Arch

```bash
pacman -Q bluez bluez-utils bluedevil kde-cli-tools
systemctl status bluetooth.service --no-pager
rfkill list bluetooth
timeout --kill-after=1s 5s bluetoothctl list
```

Review packages with the dependency script; it installs nothing. If you choose to activate an inactive service, the manual system-level command is:

```bash
sudo systemctl enable --now bluetooth.service
```

This is system-wide. The installer and popup never activate or enable this service. Hardware radio blocks need the physical switch or an explicit user decision. Pairing records and power state belong to BlueZ and are shared between desktops.

Connect/power/forget commands use validated BlueZ object paths and bounded asynchronous busctl calls. Errors stay visible. Scan state comes from BlueZ; a failed native discovery request may only be explained in Quickshell's terminal log. Successful requests do not wait for an arbitrary bluetoothctl timer. Out-of-range devices can take up to 20 seconds to fail; the UI remains responsive.

Test power state, scan cancellation, pairing/PIN, reconnect, forget, powered-off devices and missing adapters. For headphones, use Audio Details to choose the output, test playback and check other sessions if used. Local command mocks cannot establish radio, authentication, audio-profile or GUI behavior.

Sources: [BlueZ adapter API](https://github.com/bluez/bluez/blob/master/doc/org.bluez.Adapter.rst), [device API](https://github.com/bluez/bluez/blob/master/doc/org.bluez.Device.rst), [Quickshell Bluetooth](https://quickshell.org/docs/v0.3.2/types/Quickshell.Bluetooth/), [BlueDevil authentication agent](https://github.com/KDE/bluedevil/blob/master/src/wizard/wizardagent.cpp).
