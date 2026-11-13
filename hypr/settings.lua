-- Entorno y apariencia visual
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
-- Colores del tema (generado por theme-switch.sh); si falta, usa Gruvbox
local ok, theme = pcall(dofile, os.getenv("HOME") .. "/.config/theme/hypr.lua")
if not ok then
    theme = { active_border = "rgba(d79921ee)", inactive_border = "rgba(3c3836aa)", shadow = 0xee1d2021 }
end
hl.config({
    general = {
        gaps_in  = 3,
        gaps_out = 2,
        border_size = 2,
        col = {
            active_border   = theme.active_border,
            inactive_border = theme.inactive_border,
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
            color        = theme.shadow,
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
    misc = {
        -- las ventanas nuevas abren en el workspace donde lanzaste la app,
        -- aunque cambies de workspace mientras carga
        initial_workspace_tracking = 2,
        -- swallowing: si abris una app grafica desde kitty (zathura, mpv...),
        -- su ventana reemplaza a la terminal y al cerrarla la terminal vuelve
        enable_swallow = true,
        -- sin el fondo (y el logo) que trae Hyprland: se veia la chica en el subte
        -- cuando una pantalla todavia no tenia el wallpaper de awww
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
        swallow_regex  = "^(kitty)$",
        -- el click del medio (apretar el pad con 3 dedos) no pega el portapapeles
        middle_click_paste = false,
    },
    input = {
        kb_layout  = "us",
        kb_variant = "intl",
        follow_mouse = 1,
        touchpad = {
            natural_scroll = false,
            -- el click depende de cuantos dedos apoyas (2 = derecho, 3 = medio) y no de la
            -- zona del pad; sin esto, apretar con dos dedos caia en la zona central = click
            -- del medio = pegaba el portapapeles
            clickfinger_behavior = true,
        },
    },
})
