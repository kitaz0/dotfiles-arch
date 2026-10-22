# External displays

Open **Super+Shift+P**, or the laptop's display-switch key if it sends `XF86Display`.
Super+P retains its existing pseudo-tiling action. No display control runs while locked.

The separate centered Quickshell chooser shows compact diagrams and actual output state. It is separate from the device settings pages; its bar icon or Super+Shift+P opens it directly. The current arrangement is shaded; keyboard focus has a stronger border. Escape or an outside click cancels without applying. With two connected displays, select the reference connector, then Extend right, Extend left, Mirror, selected display only, or other display only. Use arrow keys to select a card, then Enter or a mouse click to activate immediately. There is no separate Apply button. The other screen is positioned
relative to it, or mirrors it. Both use their preferred modes and automatic scale.
The presets set mode, scale, position, enabled state and mirroring. Other fields
are inherited from an existing rule for that exact output, or use native defaults
when no such rule exists. Use explicit rules for a custom rotated/HDR layout.
Mirroring can stretch the image if the screens have different aspect ratios.

**Graphical arrangement / modes** opens Wdisplays (recommended package `wdisplays`).
Drag screens left/right/above/below, select resolution, scale and rotation, or disable
one output while keeping the other enabled. Review before pressing Apply. It uses
Wayland output management, not KDE's display configuration. Do not enable automatic
apply or save-to-kanshi features: this project does not run kanshi. Keep Wdisplays
open while testing; compositor monitor reloads can restore the saved rules.

These are **session changes**, not saved profiles. Run `hyprctl reload` to restore saved configuration (this also reloads other Hyprland configuration). The legacy text-menu helper retains its restore action; the compact chooser has no automatic save or revert. If a
layout becomes unusable, from a TTY use `hyprctl instances`, then `hyprctl -i 0 reload`
when only one instance is listed. Single-display choices explicitly disable the other output after enabling the retained output. There is no timed revert; keep TTY recovery available.

## Keep a layout

Inspect actual names and modes with:

```bash
hyprctl monitors all
```

Edit `~/.config/graphite/hypr/graphite/monitors.lua`. Keep the existing fallback rule.
Add an `hl.monitor` rule per screen, with its actual name in `output`, `mode = "preferred"`,
`scale = "auto"`, and `position = "0x0"` for the reference screen. For the second rule,
use `position = "auto-right"`, `"auto-left"`, `"auto-up"` or `"auto-down"`.
For mirroring, put the reference screen's name in the second rule's `mirror` field.
Remove that field for an extended desktop. Use only modes shown by the compositor.

Check after editing:

```bash
hyprctl reload
hyprctl configerrors
```

Edits through the linked configuration change the repository. Review and commit
them before pulling updates. This project does not maintain a separate profile
database or generate a copy of your entire Hyprland configuration.

## Laptop Fn key

Fn alone usually does not produce a bindable event. The combination with the
display/projector key commonly produces `XF86Display`, bound to this menu.
Super+Shift+P works independently of firmware. If the laptop combination still does
nothing, use the optional `wev` package, focus its window and press the combination.
The reported keysym is the evidence needed to adjust the binding. If no event arrives,
a compositor binding cannot invent one; inspect the laptop's Fn-lock behavior.
Brightness/audio bindings remain separate and unchanged.

## Validation and limits

Monitor hotplug, Fn keys, mirror modes and layout recovery require testing on actual hardware. Software fixtures cannot establish display routing or suspend/resume reliability. Test layouts before making them persistent.
