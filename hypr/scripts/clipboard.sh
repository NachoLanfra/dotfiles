#!/usr/bin/env bash
# clipboard.sh: historial del portapapeles (SUPER+SHIFT+V).
# Abre una ventanita flotante con lo ultimo que copiaste; elegis una entrada y
# queda en el portapapeles lista para pegar con Ctrl+V.
# El historial lo llena `wl-paste --watch cliphist store` (ver autostart.lua).
#
# Uso: clipboard.sh [--menu | --pick | --wipe]
#   --menu   (por defecto) abre/cierra la ventana flotante
#   --pick   el selector en si (corre dentro de la ventana)
#   --wipe   borra todo el historial
#
# En el selector: escribi para filtrar, ↑/↓ mover, Enter elegir,
# Ctrl+D borrar la entrada, Esc salir.

set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"

menu() {
    local pid
    pid="$(hyprctl clients -j | jq -r '.[] | select(.class == "clipboard-float") | .pid' | head -n1)"
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null; return 0; fi
    setsid -f kitty --class clipboard-float --title Portapapeles -o background_opacity=0.96 "$SELF" --pick >/dev/null 2>&1
}

pick() {
    local -a ids=() texts=() shown=()
    local line query="" sel=0 key rest i n top=0 rows
    local cols

    load() {
        ids=(); texts=()
        while IFS= read -r line; do
            ids+=("${line%%$'\t'*}")
            texts+=("${line#*$'\t'}")
        done < <(cliphist list)
    }

    # entradas que coinciden con el filtro (sin distinguir mayusculas)
    filter() {
        shown=()
        local q="${query,,}" i
        for ((i = 0; i < ${#ids[@]}; i++)); do
            [[ -z "$q" || "${texts[i],,}" == *"$q"* ]] && shown+=("$i")
        done
        n=${#shown[@]}
        (( sel >= n )) && sel=$(( n > 0 ? n - 1 : 0 ))
    }

    draw() {
        cols=$(tput cols); rows=$(( $(tput lines) - 5 ))
        (( sel < top )) && top=$sel
        (( sel >= top + rows )) && top=$(( sel - rows + 1 ))
        printf '\e[H\e[2J'
        printf '  \e[1mPortapapeles\e[0m  \e[2m(%d)\e[0m\n  \e[2m>\e[0m %s\e[7m \e[0m\n\n' "$n" "$query"
        local i idx t
        for ((i = top; i < n && i < top + rows; i++)); do
            idx=${shown[i]}
            t="${texts[idx]//$'\t'/ }"
            t="${t//$'\n'/ }"
            (( ${#t} > cols - 6 )) && t="${t:0:cols-7}…"
            if (( i == sel )); then printf '  \e[1;7m ❯ %s \e[0m\n' "$t"; else printf '    %s\n' "$t"; fi
        done
        (( n == 0 )) && printf '    \e[2m(vacio)\e[0m\n'
        printf '\e[%d;1H  \e[2m↑↓ mover · Enter elegir · Ctrl+D borrar · Esc salir\e[0m' "$(tput lines)"
    }

    choose() {
        (( n == 0 )) && return 1
        local idx=${shown[sel]}
        # cliphist decode busca el id al principio de la linea
        printf '%s\t%s' "${ids[idx]}" "x" | cliphist decode | setsid -f wl-copy >/dev/null 2>&1
        return 0
    }

    printf '\e[?25l'
    trap 'printf "\e[?25h"' EXIT
    load; filter; draw
    while IFS= read -rsn1 key; do
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 -t 0.05 rest
            case "$rest" in
                '[A') (( sel > 0 )) && (( sel-- )) ;;
                '[B') (( sel < n - 1 )) && (( sel++ )) ;;
                '')   return 0 ;;
            esac
        else
            case "$key" in
                '')       choose && return 0 ;;                     # Enter
                $'\x7f')  query="${query%?}"; sel=0; filter ;;       # Backspace
                $'\x04')  # Ctrl+D: borrar solo la entrada seleccionada
                          if (( n > 0 )); then
                              printf '%s\tx\n' "${ids[${shown[sel]}]}" | cliphist delete
                              load; filter
                          fi ;;
                *)        [[ "$key" =~ [[:print:]] ]] && { query+="$key"; sel=0; filter; } ;;
            esac
        fi
        draw
    done
}

case "${1:---menu}" in
    --menu) menu ;;
    --pick) pick ;;
    --wipe) cliphist wipe && notify-send -u low -t 1800 "Historial del portapapeles borrado" ;;
    *)      echo "uso: ${0##*/} [--menu|--pick|--wipe]" >&2; exit 1 ;;
esac
