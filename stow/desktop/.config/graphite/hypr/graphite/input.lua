-- Physical XKB layout, independent of the Japanese conversion engine.
-- For US/German switching use kb_layout="us,de", kb_options="grp:alt_shift_toggle".
-- Ctrl+Space belongs to Fcitx5/Mozc; do not bind it in Hyprland.
hl.config({ input = { kb_layout = "us,jp", kb_options = "grp:alt_shift_toggle", follow_mouse = 1, sensitivity = 0,
    touchpad = { natural_scroll = true, tap_to_click = true, disable_while_typing = true } } })
