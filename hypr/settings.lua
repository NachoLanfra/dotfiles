-- Entorno y apariencia visual
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 2,
        border_size = 2,
        col = {
            active_border   = "rgba(d79921ee)",  -- amarillo gruvbox
            inactive_border = "rgba(3c3836aa)",  -- bg2 gruvbox
        },
        resize_on_border = false,
        allow_tearing = false,
        layout = "dwindle",
    },
    xwayland = {
            force_zero_scaling  = true,
            use_nearest_neighbor = false,
        },
    decoration = {
        rounding       = 10,
        rounding_power = 2,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = 0xee1d2021,  -- bg base gruvbox
        },
        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
            vibrancy  = 0.1696,
        },
    },
    animations = {
        enabled = true,
    },
    input = {
        kb_layout  = "us",
        kb_variant = "intl",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = false,
        },
    },
})
