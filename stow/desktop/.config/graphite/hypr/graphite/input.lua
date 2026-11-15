-- Keep physical keys on US positions; Mozc supplies Japanese conversion.
-- A second physical layout/group shortcut is not needed for Japanese input.
-- Ctrl+Space belongs to Fcitx5/Mozc; do not bind it in Hyprland.
hl.config({ input = { kb_layout = "us", kb_options = "", follow_mouse = 1, sensitivity = 0,
    touchpad = { natural_scroll = true, tap_to_click = true, disable_while_typing = true } } })
