# Power settings

Click the battery icon, then **Settings**. Choose **On battery** or **Plugged in**, edit the delays and press **Apply**. Each source remembers its own policy. Desktops use the plugged-in policy; the battery tab is hidden when there is no system battery. Without a battery icon, open the page with `bash ~/.local/lib/graphite/quick-settings.sh power-settings`.

| Setting | Default for both sources |
| --- | --- |
| Lock screen after inactivity | 5 minutes |
| Screen off after inactivity | 7 minutes |
| Suspend after inactivity | Never |
| Lock before suspend | Enabled, for both sources |

All delays count from the last activity, rather than from the previous action. Each delay can be Never or one of the offered times from 1 minute to 2 hours. Screen off leaves applications running; suspend puts the computer to sleep. Lock before suspend also applies when logind suspends on lid close. Turning it off does not unlock an already locked screen. Manual locking remains available regardless of the automatic policy.

**Defaults** resets the draft for both power sources; **Apply** saves it. Dismissing the popup discards unsaved changes. Applying an active policy resets the idle timers and wakes the displays while keeping any existing locker running. Wayland/application and logind idle inhibitors remain respected. Lid-close policy stays with logind or an existing power manager. Automatic low-battery mode switching is not included.

## Preferences and session lifetime

Repository defaults live at `stow/desktop/.config/graphite/power/defaults.json`. The UI stores this device's choices in the regular file `~/.config/graphite/power/settings.json`, outside Stow and Git. It is created only on Apply. To share chosen defaults through Git, deliberately copy that JSON into the repository defaults and review the diff. Existing local choices take precedence. Remove the local file and reload the policy to return to repository defaults.

The transient `graphite-power.service` runs Hypridle and watches UPower events for charger changes. When the selected policy changes, it replaces only its own idle process. Hyprlock runs in a separate `graphite-lock.service`, so policy reloads cannot terminate the locker. Both services belong to `graphite-session.service` and stop with Graphite; their policy does not run in Plasma. The generated Hypridle configuration lives under XDG_RUNTIME_DIR and is removed when the power service exits. Without the optional UPower CLI, only explicit reloads update the power source.

The shared hooks remain in `~/.config/graphite/hypr/hypridle.conf`; edit that file for resume-hook customization, and reload afterward. Idle delays belong in the Settings page or its JSON preferences.

After refreshing Stow links, activate the new helper inside an existing Graphite session without restarting the other session helpers:

```bash
bash ~/.local/lib/graphite/power-policy.sh start
```

It replaces only the legacy Hypridle process launched by Graphite with its dedicated config. An unrelated idle daemon is preserved. To apply manual JSON or hook changes later:

```bash
bash ~/.local/lib/graphite/power-policy.sh reload
```

Use `power-policy.sh --help` for the command reference. For diagnostics, run `systemctl --user status graphite-power.service` and `journalctl --user -b -u graphite-power.service`.

## Performance modes

The three hardware performance modes remain independent of the idle settings. They are supplied by the already running power-profiles-daemon or a compatible service. Selecting one changes the shared system profile, which can also affect Plasma. Graphite does not edit the underlying hardware profiles or install/enable a power manager from the popup.

To inspect available modes and the selected profile:

```bash
powerprofilesctl list
powerprofilesctl get
powerprofilesctl list-actions
```

If the panel reports no active profile service, follow the package/service instructions in [Installation](INSTALLATION.md). Battery monitoring and idle policies remain available without that service.
