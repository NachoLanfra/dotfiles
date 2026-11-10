hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

hl.window_rule({
    name  = "move-hyprland-run",
    match = { class = "hyprland-run" },
    move  = "20 monitor_h-120",
    float = true,
})

hl.window_rule({
    name   = "nmtui-float",
    match  = { class = "^nmtui-float$" },
    float  = true,
    size   = "640 420",
    center = true,
})

hl.window_rule({
    name   = "theme-float",
    match  = { class = "^theme-float$" },
    float  = true,
    size   = "440 270",
    center = true,
})

hl.window_rule({
    name   = "clipboard-float",
    match  = { class = "^clipboard-float$" },
    float  = true,
    size   = "720 440",
    center = true,
})
