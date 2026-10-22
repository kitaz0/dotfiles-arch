-- Graphite:Hyprland is intentional desktop-specific portal routing, not a wrong desktop.
hl.config({
    general = { gaps_in = 5, gaps_out = 12, border_size = 2,
        col = { active_border = { colors = {"rgba(b8bb26ff)"}, angle = 0 }, inactive_border = "rgba(665c54ff)" },
        layout = "dwindle", resize_on_border = true, allow_tearing = false },
    decoration = { rounding = 7, active_opacity = 1.0, inactive_opacity = 1.0,
        blur = { enabled = false }, shadow = { enabled = false } },
    -- Keep native animation curves and the example configuration's dwindle splits.
    animations = { enabled = true },
    dwindle = { preserve_split = true },
    misc = { disable_xdg_env_checks = true, disable_hyprland_logo = true, force_default_wallpaper = 0 },
})
hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
