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
    name   = "pantallas-float",
    match  = { class = "^pantallas-float$" },
    float  = true,
    size   = "640 300",
    center = true,
})

hl.window_rule({
    name   = "clipboard-float",
    match  = { class = "^clipboard-float$" },
    float  = true,
    size   = "720 440",
    center = true,
})

-- Cualquier ventana a pantalla completa (video, peliculas) impide que
-- hypridle bloquee la sesion o apague la pantalla
hl.window_rule({
    name  = "idle-inhibit-fullscreen",
    match = { class = ".*" },
    idle_inhibit = "fullscreen",
})


hl.window_rule({
    name   = "keybinds-float",
    match  = { class = "^keybinds-float$" },
    float  = true,
    size   = "760 640",
    center = true,
})
