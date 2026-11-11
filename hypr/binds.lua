-- Convención: cada atajo lleva al final un comentario "-- descripción".
-- hypr/scripts/keybinds.sh (SUPER+F1) arma la lista de atajos leyendo este
-- archivo: un comentario suelto después de una línea en blanco es un título de
-- sección, y una línea "--@ TECLAS | descripción" agrega un atajo que no se
-- puede leer de una línea (por ejemplo los de un bucle).

local mainMod     = "SUPER"
local runner      = "~/.config/hypr/scripts/ws-run.sh "
local terminal    = "kitty"
local fileManager = "thunar"
local menu        = "hyprlauncher"
local browser     = "firefox"

-- Aplicaciones
hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))                                                   -- Terminal
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(runner .. fileManager))                                      -- Archivos
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))                                                       -- Lanzador de aplicaciones
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(runner .. browser))                                          -- Navegador
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("~/.config/hypr/scripts/theme-switch.sh --menu"))            -- Elegir tema
hl.bind(mainMod .. " + SHIFT + V", hl.dsp.exec_cmd("~/.config/hypr/scripts/clipboard.sh"))              -- Historial del portapapeles
hl.bind(mainMod .. " + F1", hl.dsp.exec_cmd("~/.config/hypr/scripts/keybinds.sh"))                      -- Esta lista de atajos

-- Ventanas
hl.bind(mainMod .. " + C", hl.dsp.window.close())                                                       -- Cerrar ventana
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))                                  -- Flotante / en mosaico
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())                                                      -- Pseudo-mosaico
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit"))                                                -- Cambiar orientación del corte
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen({ mode = "maximized" }))                            -- Maximizar

-- Sistema
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")) -- Cerrar sesión
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))                                                 -- Bloquear pantalla
hl.bind(mainMod .. " + F10", hl.dsp.exec_cmd("~/.config/hypr/scripts/perf-mode.sh"))                    -- Modo rendimiento (sin animaciones ni blur)

-- Capturas
hl.bind("Print",               hl.dsp.exec_cmd("hyprshot -m region -z --clipboard-only"))               -- Captura de región al portapapeles
hl.bind(mainMod .. " + Print", hl.dsp.exec_cmd("hyprshot -m region -z -o ~/Pictures"))                  -- Captura de región a ~/Pictures

-- Mover ventanas dentro del workspace (intercambia lugar con la vecina)
hl.bind(mainMod .. " + SHIFT + left",  hl.dsp.window.move({ direction = "left" }))                      -- Mover ventana a la izquierda
hl.bind(mainMod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))                     -- Mover ventana a la derecha
hl.bind(mainMod .. " + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))                        -- Mover ventana hacia arriba
hl.bind(mainMod .. " + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))                      -- Mover ventana hacia abajo

-- Cambiar tamaño (se repite al mantener apretado)
hl.bind(mainMod .. " + CTRL + left",  hl.dsp.window.resize({ x = -40, y = 0,  relative = true }), { repeating = true }) -- Achicar ancho
hl.bind(mainMod .. " + CTRL + right", hl.dsp.window.resize({ x = 40,  y = 0,  relative = true }), { repeating = true }) -- Agrandar ancho
hl.bind(mainMod .. " + CTRL + up",    hl.dsp.window.resize({ x = 0,   y = -40, relative = true }), { repeating = true }) -- Achicar alto
hl.bind(mainMod .. " + CTRL + down",  hl.dsp.window.resize({ x = 0,   y = 40,  relative = true }), { repeating = true }) -- Agrandar alto

-- Mandar la ventana al workspace anterior o siguiente
-- ALT: te lleva con ella. ALT+SHIFT: te quedas en el workspace actual.
hl.bind(mainMod .. " + ALT + left",          hl.dsp.window.move({ workspace = "r-1", follow = true }))  -- Ventana al workspace anterior (y vas con ella)
hl.bind(mainMod .. " + ALT + right",         hl.dsp.window.move({ workspace = "r+1", follow = true }))  -- Ventana al workspace siguiente (y vas con ella)
hl.bind(mainMod .. " + ALT + SHIFT + left",  hl.dsp.window.move({ workspace = "r-1", follow = false })) -- Ventana al workspace anterior (te quedás)
hl.bind(mainMod .. " + ALT + SHIFT + right", hl.dsp.window.move({ workspace = "r+1", follow = false })) -- Ventana al workspace siguiente (te quedás)

-- Foco con flechas
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))                                    -- Foco a la izquierda
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))                                   -- Foco a la derecha
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))                                      -- Foco hacia arriba
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))                                    -- Foco hacia abajo

-- Workspaces
--@ SUPER + 1 … 0 | Ir al workspace 1 a 10
--@ SUPER + SHIFT + 1 … 0 | Mover la ventana al workspace 1 a 10
for i = 1, 10 do
    local key = i % 10
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad (workspace oculto para guardar ventanas)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))                            -- Mostrar / ocultar el scratchpad
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))                 -- Guardar la ventana en el scratchpad

-- Mouse
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))                                -- Workspace siguiente
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))                                -- Workspace anterior
hl.bind(mainMod .. " + mouse:272",  hl.dsp.window.drag(),   { mouse = true })                           -- Arrastrar ventana
hl.bind(mainMod .. " + mouse:273",  hl.dsp.window.resize(), { mouse = true })                           -- Cambiar tamaño con el mouse

-- Volumen y brillo (con SwayOSD)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("swayosd-client --output-volume raise"), { locked = true, repeating = true }) -- Subir volumen
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("swayosd-client --output-volume lower"), { locked = true, repeating = true }) -- Bajar volumen
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("swayosd-client --output-volume mute-toggle"), { locked = true }) -- Silenciar
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("swayosd-client --brightness raise"), { locked = true, repeating = true })     -- Subir brillo
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("swayosd-client --brightness lower"), { locked = true, repeating = true })   -- Bajar brillo

-- Control de medios (Spotify, navegador, etc.)
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })                    -- Reproducir / pausar
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })                          -- Canción siguiente
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })                      -- Canción anterior

-- Pantallas
hl.bind("XF86Launch2", hl.dsp.exec_cmd("~/.config/hypr/scripts/pantallas.sh"))                          -- Pantallas: duplicar / extender

-- Gestos del touchpad
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
--@ 3 dedos ← → | Cambiar de workspace
