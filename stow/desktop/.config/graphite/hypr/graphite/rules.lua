-- Float audio control; leave Dolphin, OBS and editor placement to the user.
hl.window_rule({ name = "graphite-audio", match = { class = "^(org.pulseaudio.pavucontrol|pavucontrol)$" }, float = true })
-- Same policy as the v0.56.2 example: application maximize requests must not
-- cover the other tiled windows. Explicit Super+F fullscreen remains available.
hl.window_rule({ name = "suppress-maximize-events", match = { class = ".*" }, suppress_event = "maximize" })
