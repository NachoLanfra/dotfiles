#!/usr/bin/env bash
# ws-run: lanza un comando y deja su ventana en el workspace desde donde lo
# lanzaste, aunque tardes en abrirse y cambies de workspace mientras tanto.
#
# Hyprland (initial_workspace_tracking) no alcanza cuando la app ya estaba
# abierta (ej. `code .`): la ventana nueva la crea el proceso existente y cae
# en el workspace activo. Este wrapper anota el origen, lanza el comando y
# mueve en silencio la primera ventana nueva que aparezca.
#
# Uso: ws-run.sh <comando> [args...]

[[ $# -eq 0 ]] && { echo "uso: ${0##*/} <comando> [args...]" >&2; exit 1; }

windows() { hyprctl clients -j | jq -r '.[].address'; }

origin=$(hyprctl activeworkspace -j | jq -r '.id')
before=$(windows)

# El comando corre desacoplado de esta terminal.
setsid -f "$@" >/dev/null 2>&1

# Espera hasta ~30 s a que aparezca una ventana nueva.
for _ in $(seq 1 150); do
    sleep 0.2
    addr=$(comm -13 <(sort <<<"$before") <(windows | sort) | head -n1)
    [[ -z "$addr" ]] && continue
    current=$(hyprctl clients -j | jq -r --arg a "$addr" '.[]|select(.address==$a).workspace.id')
    if [[ -n "$current" && "$current" != "$origin" ]]; then
        hyprctl dispatch "hl.dsp.window.move({ workspace = $origin, follow = false, window = \"address:$addr\" })" >/dev/null
    fi
    exit 0
done
