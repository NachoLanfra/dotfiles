#!/usr/bin/env bash
# pantallas.sh: elegir que hacer con una segunda pantalla (proyector, TV, monitor).
# Reemplaza a nwg-displays con las opciones de siempre (duplicar, extender, solo una), como Win+P de Windows.
#
# Uso: pantallas.sh [--menu | --pick | --duplicar | --extender | --extender-izq | --solo-portatil | --solo-externa | --guardado | --restaurar]
#   --menu   (por defecto) abre/cierra la ventana flotante con las opciones
#   --pick   el selector en si (corre dentro de la ventana)
#   el resto aplica la opcion directo (para usarlo desde un atajo o a mano)
#
# En el selector: ↑/↓ mover, Enter elegir, 1-5 elegir directo, Esc salir.
#
# La eleccion queda guardada (~/.local/state/pantallas/modo) y se vuelve a
# aplicar sola cada vez que enchufas una pantalla o abris la sesion.
#   --guardado   aplica lo ultimo que elegiste (lo llaman monitors.lua y autostart.lua)
#   --restaurar  si desenchufas la externa con "solo externa", reenciende la del portatil
#                (si no, quedaria todo negro)
# La pantalla propia (eDP) usa el modo y la escala de monitors.lua. La externa usa
# su modo preferido, a escala 1 (1.5 si es 4K).

set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
MONITORS_LUA="$(dirname "$SELF")/../monitors.lua"
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/pantallas/modo"
QUIET=${QUIET:-0}   # 1 = sin notificaciones (cuando lo aplica un evento y no vos)

notify() { (( QUIET )) || notify-send -a pantallas -u "${3:-low}" -t 3000 "$1" "${2:-}"; }

# ------------------------------------------------------------------ estado
INTERNAL="" EXTERNALS=()
detect() {
    local json name
    json="$(hyprctl monitors all -j)"
    INTERNAL="" EXTERNALS=()
    while IFS= read -r name; do
        if [[ -z "$INTERNAL" && "$name" =~ ^(eDP|LVDS|DSI) ]]; then INTERNAL="$name"; else EXTERNALS+=("$name"); fi
    done < <(jq -r '.[].name' <<<"$json")
    MONITORS_JSON="$json"
}

# mon_field <monitor> <campo>
mon_field() { jq -r --arg n "$1" '.[] | select(.name == $n) | .'"$2" <<<"$MONITORS_JSON"; }

# modo actual de una opcion: duplicar | extender | solo-portatil | solo-externa
current_mode() {
    local ext=${EXTERNALS[0]:-}
    [[ -z "$ext" ]] && { echo solo-portatil; return; }
    [[ "$(mon_field "$ext" disabled)" == true ]] && { echo solo-portatil; return; }
    [[ "$(mon_field "$INTERNAL" disabled)" == true ]] && { echo solo-externa; return; }
    [[ "$(mon_field "$ext" mirrorOf)" != none ]] && { echo duplicar; return; }
    echo extender
}

# ----------------------------------------------------- especificacion de modos
# first_mode <monitor>: el modo preferido, tal cual lo da Hyprland (sin "Hz")
first_mode() {
    local m
    m="$(jq -r --arg n "$1" '.[] | select(.name == $n) | .availableModes[0]' <<<"$MONITORS_JSON")"
    echo "${m%Hz}"
}

# internal_spec: "modo escala" de la pantalla propia, segun monitors.lua
internal_spec() {
    local block mode scale
    block="$(grep -A5 "output *= *\"$INTERNAL\"" "$MONITORS_LUA" 2>/dev/null | head -6)"
    mode="$(sed -n 's/.*mode *= *"\([^"]*\)".*/\1/p' <<<"$block" | head -1)"
    scale="$(sed -n 's/.*scale *= *"\?\([0-9.]*\)"\?.*/\1/p' <<<"$block" | head -1)"
    [[ -z "$mode" || "$mode" == preferred ]] && mode="$(first_mode "$INTERNAL")"
    echo "$mode ${scale:-1}"
}

# external_spec <monitor>: "modo escala" de la externa (preferido; 1.5 si es 4K)
external_spec() {
    local mode w
    mode="$(first_mode "$1")"
    w="${mode%%x*}"
    if (( w >= 3000 )); then echo "$mode 1.5"; else echo "$mode 1"; fi
}

# logical_width "<modo escala>": ancho en px logicos (ya dividido por la escala)
logical_width() {
    local mode=${1%% *} scale=${1##* }
    awk -v w="${mode%%x*}" -v s="$scale" 'BEGIN { printf "%d", w / s }'
}

# ------------------------------------------------------------------ aplicar
lua() { hyprctl eval "$1" 2>&1; }

mon_lua() { # <salida> <modo> <posicion> <escala> [espejo-de]
    local extra=""
    [[ -n "${5:-}" ]] && extra=", mirror = \"$5\""
    printf 'hl.monitor({ output = "%s", mode = "%s", position = "%s", scale = %s%s })' "$1" "$2" "$3" "$4" "$extra"
}
off_lua() { printf 'hl.monitor({ output = "%s", disabled = true })' "$1"; }

apply() {
    local what="$1" ext int_spec ext_spec iw ew code="" out e
    detect
    if [[ -z "$INTERNAL" ]]; then notify "Pantallas" "No encuentro la pantalla del portatil" normal; return 1; fi
    ext=${EXTERNALS[0]:-}
    if [[ -z "$ext" && "$what" != solo-portatil ]]; then
        notify "No hay otra pantalla conectada" "Conecta el cable (HDMI / USB-C) y proba de nuevo" normal
        return 1
    fi

    int_spec="$(internal_spec)"
    # shellcheck disable=SC2086
    set -- $int_spec; local imode=$1 iscale=$2
    local emode="" escale=""
    if [[ -n "$ext" ]]; then
        ext_spec="$(external_spec "$ext")"
        # shellcheck disable=SC2086
        set -- $ext_spec; emode=$1; escale=$2
    fi
    iw="$(logical_width "$int_spec")"
    [[ -n "$ext" ]] && ew="$(logical_width "$ext_spec")"

    case "$what" in
        solo-portatil)
            code="$(mon_lua "$INTERNAL" "$imode" "0x0" "$iscale")"
            for e in "${EXTERNALS[@]}"; do code+=$'\n'"$(off_lua "$e")"; done
            msg="Solo la pantalla del portatil" ;;
        duplicar)
            code="$(mon_lua "$INTERNAL" "$imode" "0x0" "$iscale")"$'\n'"$(mon_lua "$ext" "$emode" "auto" "$escale" "$INTERNAL")"
            msg="Duplicando la pantalla" ;;
        extender)
            code="$(mon_lua "$INTERNAL" "$imode" "0x0" "$iscale")"$'\n'"$(mon_lua "$ext" "$emode" "${iw}x0" "$escale")"
            msg="Pantalla extendida: la otra queda a la derecha" ;;
        extender-izq)
            code="$(mon_lua "$ext" "$emode" "0x0" "$escale")"$'\n'"$(mon_lua "$INTERNAL" "$imode" "${ew}x0" "$iscale")"
            msg="Pantalla extendida: la otra queda a la izquierda" ;;
        solo-externa)
            code="$(mon_lua "$ext" "$emode" "0x0" "$escale")"$'\n'"$(off_lua "$INTERNAL")"
            msg="Solo la pantalla externa" ;;
        *) echo "opcion desconocida: $what" >&2; return 1 ;;
    esac

    # una sentencia por llamada, asi un error no deja la mitad aplicada sin avisar
    local line
    while IFS= read -r line; do
        out="$(lua "$line")"
        if [[ -n "$out" && "$out" != ok ]]; then
            notify "No pude cambiar las pantallas" "$out" critical
            return 1
        fi
    done <<<"$code"
    mkdir -p "$(dirname "$STATE_FILE")" && echo "$what" >"$STATE_FILE"
    notify "$msg"
}

# aplica lo ultimo que se eligio; sin pantalla externa no hace nada
saved() {
    exec 9>"${XDG_RUNTIME_DIR:-/tmp}/pantallas.lock"
    flock -n 9 || return 0
    sleep 1   # deja que la pantalla recien enchufada termine de aparecer
    detect
    (( ${#EXTERNALS[@]} == 0 )) && return 0
    QUIET=1 apply "$(cat "$STATE_FILE" 2>/dev/null || echo extender)"
}

# si la pantalla del portatil esta apagada y no queda ninguna otra, se reenciende
restore() {
    local e on=0
    detect
    [[ -z "$INTERNAL" ]] && return 0
    [[ "$(mon_field "$INTERNAL" disabled)" == true ]] || return 0
    for e in "${EXTERNALS[@]}"; do [[ "$(mon_field "$e" disabled)" == true ]] || on=1; done
    (( on )) && return 0
    # shellcheck disable=SC2046
    set -- $(internal_spec)
    lua "$(mon_lua "$INTERNAL" "$1" "0x0" "$2")" >/dev/null
    notify "Pantallas" "Se desconecto la externa: volvio la pantalla del portatil"
}

# ----------------------------------------------------------------- ventana
menu() {
    local pid
    pid="$(hyprctl clients -j | jq -r '.[] | select(.class == "pantallas-float") | .pid' | head -n1)"
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null; return 0; fi
    setsid -f kitty --class pantallas-float --title Pantallas -o background_opacity=0.96 "$SELF" --pick >/dev/null 2>&1
}

pick() {
    local ids=(duplicar extender extender-izq solo-portatil solo-externa)
    local titles=("Duplicar" "Extender a la derecha" "Extender a la izquierda" "Solo el portatil" "Solo la pantalla externa")
    local helps=("la misma imagen en las dos pantallas" "la otra pantalla es la continuacion, a la derecha" "la otra pantalla es la continuacion, a la izquierda" "apaga la otra pantalla" "apaga la pantalla del portatil")
    local n=${#ids[@]} sel=0 key rest cur i

    detect
    cur="$(current_mode)"
    for ((i = 0; i < n; i++)); do [[ "${ids[i]}" == "$cur" ]] && sel=$i; done

    draw() {
        local i
        printf '\e[H\e[2J\n  \e[1mPantallas\e[0m'
        if (( ${#EXTERNALS[@]} == 0 )); then
            printf '\n\n  \e[33mNo hay otra pantalla conectada.\e[0m\n  \e[2mConecta el cable (HDMI / USB-C) y vuelve a abrir esto.\e[0m\n'
            printf '\n  \e[2mEsc para salir\e[0m\n'
            return
        fi
        printf '  \e[2m(%s + %s)\e[0m\n\n' "$INTERNAL" "${EXTERNALS[0]}"
        for ((i = 0; i < n; i++)); do
            if (( i == sel )); then
                printf '  \e[1;7m ❯ %d  %-26s \e[0m \e[2m%s\e[0m' "$((i + 1))" "${titles[i]}" "${helps[i]}"
            else
                printf '    %d  %-26s  \e[2m%s\e[0m' "$((i + 1))" "${titles[i]}" "${helps[i]}"
            fi
            [[ "${ids[i]}" == "$cur" ]] && printf ' \e[2m(actual)\e[0m'
            printf '\n'
        done
        printf '\n  \e[2m↑↓ mover · Enter elegir · 1-5 directo · Esc salir\e[0m\n'
    }

    printf '\e[?25l'
    trap 'printf "\e[?25h"' EXIT
    draw
    while IFS= read -rsn1 key; do
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 -t 0.05 rest
            case "$rest" in
                '[A') (( sel = (sel + n - 1) % n )) ;;
                '[B') (( sel = (sel + 1) % n )) ;;
                '')   return 0 ;;
            esac
        else
            (( ${#EXTERNALS[@]} == 0 )) && return 0
            case "$key" in
                k) (( sel = (sel + n - 1) % n )) ;;
                j) (( sel = (sel + 1) % n )) ;;
                q) return 0 ;;
                [1-5]) apply "${ids[key - 1]}"; return 0 ;;
                '')    apply "${ids[sel]}"; return 0 ;;
            esac
        fi
        draw
    done
}

case "${1:---menu}" in
    --menu)           menu ;;
    --pick)           pick ;;
    --duplicar)       apply duplicar ;;
    --extender)       apply extender ;;
    --extender-izq)   apply extender-izq ;;
    --solo-portatil)  apply solo-portatil ;;
    --solo-externa)   apply solo-externa ;;
    --guardado)       saved ;;
    --restaurar)      restore ;;
    *) echo "uso: ${0##*/} [--menu|--pick|--duplicar|--extender|--extender-izq|--solo-portatil|--solo-externa|--guardado|--restaurar]" >&2; exit 1 ;;
esac
